-- SQL Script to create your schemas, tables, and views in Supabase
-- Run this in your Supabase SQL Editor (https://supabase.com/dashboard)

-- Create the FBA schema for Amazon data
CREATE SCHEMA IF NOT EXISTS fba;

-- =========================================================================
-- 1) Base tables
-- =========================================================================

-- In-house packlist
CREATE TABLE IF NOT EXISTS public.packlist (
  id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  shipment_id TEXT NOT NULL,
  created_date TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  shipped_qty INTEGER NOT NULL CHECK (shipped_qty >= 0),
  fnsku TEXT,
  asin TEXT,
  sku TEXT,
  item_identifier TEXT GENERATED ALWAYS AS (COALESCE(sku, fnsku, asin, 'unknown')) STORED,
  created_by UUID NOT NULL DEFAULT auth.uid(),
  UNIQUE (shipment_id, item_identifier)
);

-- Amazon shipping queue
CREATE TABLE IF NOT EXISTS fba.shipping_queue (
  id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  "Shipment name" TEXT,
  "Shipment ID" TEXT NOT NULL,
  "Reference ID" TEXT,
  "Status" TEXT,
  "Created at" TEXT,
  "Last updated" TEXT,
  "Ship to" TEXT,
  "SKUs" TEXT NOT NULL,
  "Units expected" INTEGER NOT NULL CHECK ("Units expected" >= 0),
  "Units located" INTEGER,
  "Difference" INTEGER,
  created_by UUID NOT NULL DEFAULT auth.uid(),
  UNIQUE ("Shipment ID", "SKUs")
);

-- Join table: links packlist rows to shipping_queue rows
CREATE TABLE IF NOT EXISTS public.shipment_item_join (
  id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  packlist_id BIGINT NOT NULL REFERENCES public.packlist(id) ON DELETE CASCADE,
  shipping_queue_id BIGINT NOT NULL REFERENCES fba.shipping_queue(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_by UUID NOT NULL DEFAULT auth.uid(),
  UNIQUE (packlist_id, shipping_queue_id)
);

-- Product mapping table to resolve SKU/FNSKU/ASIN to a Canonical SKU
CREATE TABLE IF NOT EXISTS public.product_mapping (
  source_identifier TEXT PRIMARY KEY, -- SKU, FNSKU, or ASIN
  canonical_sku TEXT NOT NULL,         -- The unified master SKU in the COGS table
  created_by UUID NOT NULL DEFAULT auth.uid()
);

-- COGS table
CREATE TABLE IF NOT EXISTS public.cogs (
  sku TEXT PRIMARY KEY,
  latest_accepted NUMERIC(10, 2) DEFAULT 0.00,
  amazon_proposed NUMERIC(10, 2) DEFAULT 0.00,
  luminize_cogs NUMERIC(10, 2) DEFAULT 0.00,
  mvd_cogs NUMERIC(10, 2) DEFAULT 0.00,
  created_by UUID NOT NULL DEFAULT auth.uid()
);

-- Helpful indexes for RLS predicates
CREATE INDEX IF NOT EXISTS idx_packlist_created_by ON public.packlist(created_by);
CREATE INDEX IF NOT EXISTS idx_shipping_queue_created_by ON fba.shipping_queue(created_by);
CREATE INDEX IF NOT EXISTS idx_shipment_item_join_created_by ON public.shipment_item_join(created_by);
CREATE INDEX IF NOT EXISTS idx_product_mapping_created_by ON public.product_mapping(created_by);
CREATE INDEX IF NOT EXISTS idx_cogs_created_by ON public.cogs(created_by);

-- =========================================================================
-- 2) Views (Calculated cross-schema values for Asana)
-- =========================================================================

-- Unified view merging both sources
CREATE OR REPLACE VIEW public.unified_shipment_items AS
  -- In-house packlist shipments
  SELECT 
    'in-house' AS source_type,
    shipment_id,
    item_identifier,
    shipped_qty AS quantity
  FROM public.packlist
  
  UNION ALL
  
  -- Amazon shipping queue shipments
  SELECT 
    'amazon' AS source_type,
    "Shipment ID" AS shipment_id,
    "SKUs" AS item_identifier,
    "Units expected" AS quantity
  FROM fba.shipping_queue;

-- Valuation and summary view
CREATE OR REPLACE VIEW public.shipment_cogs_summary AS
  SELECT 
    u.shipment_id,
    u.source_type,
    COUNT(DISTINCT u.item_identifier) as total_items,
    SUM(u.quantity) as total_quantity,
    
    -- Amazon proposed value
    SUM(u.quantity * COALESCE(c.amazon_proposed, 0)) AS shipment_value_amz,
    
    -- Luminize COGS value (latest_accepted or fallback to luminize_cogs)
    SUM(u.quantity * COALESCE(c.latest_accepted, c.luminize_cogs, 0)) AS shipment_value_lmz,
    
    -- Difference (AMZ - LMZ)
    SUM(u.quantity * COALESCE(c.amazon_proposed, 0)) - SUM(u.quantity * COALESCE(c.latest_accepted, c.luminize_cogs, 0)) AS shipment_value_dif
  FROM public.unified_shipment_items u
  LEFT JOIN public.product_mapping pm ON (u.item_identifier = pm.source_identifier)
  LEFT JOIN public.cogs c ON (COALESCE(pm.canonical_sku, u.item_identifier) = c.sku)
  GROUP BY u.shipment_id, u.source_type;

-- =========================================================================
-- 3) Grants (for Data API access)
-- =========================================================================

GRANT USAGE ON SCHEMA public, fba TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.packlist TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON fba.shipping_queue TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.shipment_item_join TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.product_mapping TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.cogs TO authenticated;

-- Grants for views so the Worker (using authenticated/anon role) can access calculations
GRANT SELECT ON public.unified_shipment_items TO authenticated;
GRANT SELECT ON public.shipment_cogs_summary TO authenticated;

-- =========================================================================
-- 4) Enable RLS
-- =========================================================================

ALTER TABLE public.packlist ENABLE ROW LEVEL SECURITY;
ALTER TABLE fba.shipping_queue ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.shipment_item_join ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.product_mapping ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.cogs ENABLE ROW LEVEL SECURITY;

-- =========================================================================
-- 5) Policies (owner-based: users only access their own rows)
-- =========================================================================

-- Packlist policies
DROP POLICY IF EXISTS "packlist_select_own" ON public.packlist;
DROP POLICY IF EXISTS "packlist_insert_own" ON public.packlist;
DROP POLICY IF EXISTS "packlist_update_own" ON public.packlist;
DROP POLICY IF EXISTS "packlist_delete_own" ON public.packlist;

CREATE POLICY "packlist_select_own"
ON public.packlist FOR SELECT TO authenticated
USING (created_by = (SELECT auth.uid()));

CREATE POLICY "packlist_insert_own"
ON public.packlist FOR INSERT TO authenticated
WITH CHECK (created_by = (SELECT auth.uid()));

CREATE POLICY "packlist_update_own"
ON public.packlist FOR UPDATE TO authenticated
USING (created_by = (SELECT auth.uid()))
WITH CHECK (created_by = (SELECT auth.uid()));

CREATE POLICY "packlist_delete_own"
ON public.packlist FOR DELETE TO authenticated
USING (created_by = (SELECT auth.uid()));

-- Shipping queue policies
DROP POLICY IF EXISTS "shipping_queue_select_own" ON fba.shipping_queue;
DROP POLICY IF EXISTS "shipping_queue_insert_own" ON fba.shipping_queue;
DROP POLICY IF EXISTS "shipping_queue_update_own" ON fba.shipping_queue;
DROP POLICY IF EXISTS "shipping_queue_delete_own" ON fba.shipping_queue;

CREATE POLICY "shipping_queue_select_own"
ON fba.shipping_queue FOR SELECT TO authenticated
USING (created_by = (SELECT auth.uid()));

CREATE POLICY "shipping_queue_insert_own"
ON fba.shipping_queue FOR INSERT TO authenticated
WITH CHECK (created_by = (SELECT auth.uid()));

CREATE POLICY "shipping_queue_update_own"
ON fba.shipping_queue FOR UPDATE TO authenticated
USING (created_by = (SELECT auth.uid()))
WITH CHECK (created_by = (SELECT auth.uid()));

CREATE POLICY "shipping_queue_delete_own"
ON fba.shipping_queue FOR DELETE TO authenticated
USING (created_by = (SELECT auth.uid()));

-- Join table policies
DROP POLICY IF EXISTS "shipment_item_join_select_own" ON public.shipment_item_join;
DROP POLICY IF EXISTS "shipment_item_join_insert_own" ON public.shipment_item_join;
DROP POLICY IF EXISTS "shipment_item_join_update_own" ON public.shipment_item_join;
DROP POLICY IF EXISTS "shipment_item_join_delete_own" ON public.shipment_item_join;

CREATE POLICY "shipment_item_join_select_own"
ON public.shipment_item_join FOR SELECT TO authenticated
USING (created_by = (SELECT auth.uid()));

CREATE POLICY "shipment_item_join_insert_own"
ON public.shipment_item_join FOR INSERT TO authenticated
WITH CHECK (created_by = (SELECT auth.uid()));

CREATE POLICY "shipment_item_join_update_own"
ON public.shipment_item_join FOR UPDATE TO authenticated
USING (created_by = (SELECT auth.uid()))
WITH CHECK (created_by = (SELECT auth.uid()));

CREATE POLICY "shipment_item_join_delete_own"
ON public.shipment_item_join FOR DELETE TO authenticated
USING (created_by = (SELECT auth.uid()));

-- =========================================================================
-- 6) Sample Test Data
-- =========================================================================
-- Note: Replace auth.uid() with a default UUID or let it use default
INSERT INTO public.cogs (sku, latest_accepted, amazon_proposed, luminize_cogs) VALUES
  ('PROD-A', 10.00, 12.00, 10.00),
  ('PROD-B', 20.00, 18.00, 20.00)
ON CONFLICT (sku) DO NOTHING;

INSERT INTO public.product_mapping (source_identifier, canonical_sku) VALUES
  ('FNSKU-AMZ-A', 'PROD-A'),
  ('ASIN-B', 'PROD-B')
ON CONFLICT (source_identifier) DO NOTHING;

INSERT INTO public.packlist (shipment_id, sku, shipped_qty) VALUES
  ('SHIP-INHOUSE-01', 'PROD-A', 50),
  ('SHIP-INHOUSE-01', 'PROD-B', 100)
ON CONFLICT DO NOTHING;

INSERT INTO fba.shipping_queue ("Shipment ID", "SKUs", "Units expected") VALUES
  ('SHIP-AMZ-99', 'FNSKU-AMZ-A', 150),
  ('SHIP-AMZ-99', 'ASIN-B', 200)
ON CONFLICT DO NOTHING;
