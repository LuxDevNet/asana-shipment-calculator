-- SQL Script to set up your Shipments and COGS calculation in Supabase
-- Run this in your Supabase SQL Editor (https://supabase.com/dashboard)

-- =========================================================================
-- 1. Base Tables (Matches your exact schema)
-- =========================================================================

-- In-house generated shipments
CREATE TABLE IF NOT EXISTS packlist (
  shipment_id TEXT NOT NULL,
  created_date TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  shipped_qty INTEGER NOT NULL,
  fnsku TEXT,
  asin TEXT,
  sku TEXT,
  PRIMARY KEY (shipment_id, COALESCE(sku, fnsku, asin, 'unknown'))
);

-- Amazon shipments manually pulled
CREATE TABLE IF NOT EXISTS shipping (
  "Shipment name" TEXT,
  "Shipment ID" TEXT NOT NULL,
  "Reference ID" TEXT,
  "Status" TEXT,
  "Created at" TEXT,
  "Last updated" TEXT,
  "Ship to" TEXT,
  "SKUs" TEXT NOT NULL, -- The item identifier
  "Units expected" INTEGER NOT NULL, -- Quantity
  "Units located" INTEGER,
  "Difference" INTEGER,
  PRIMARY KEY ("Shipment ID", "SKUs")
);

-- Product mapping table to resolve FNSKU, ASIN, or SKU to Canonical SKU
CREATE TABLE IF NOT EXISTS product_mapping (
  source_identifier TEXT PRIMARY KEY, -- SKU, FNSKU, or ASIN
  canonical_sku TEXT NOT NULL         -- The master SKU in the COGS table
);

-- COGS table
CREATE TABLE IF NOT EXISTS cogs (
  sku TEXT PRIMARY KEY,
  latest_accepted NUMERIC(10, 2) DEFAULT 0.00,
  amazon_proposed NUMERIC(10, 2) DEFAULT 0.00,
  luminize_cogs NUMERIC(10, 2) DEFAULT 0.00,
  mvd_cogs NUMERIC(10, 2) DEFAULT 0.00
);

-- =========================================================================
-- 2. Unified Shipment Items View
-- =========================================================================
CREATE OR REPLACE VIEW unified_shipment_items AS
  -- In-house packlist shipments
  SELECT 
    'in-house' AS source_type,
    shipment_id,
    COALESCE(sku, fnsku, asin) AS item_identifier,
    shipped_qty AS quantity
  FROM packlist
  
  UNION ALL
  
  -- Amazon shipping queue shipments
  SELECT 
    'amazon' AS source_type,
    "Shipment ID" AS shipment_id,
    "SKUs" AS item_identifier,
    "Units expected" AS quantity
  FROM shipping;

-- =========================================================================
-- 3. COGS & Valuation Summary View
-- =========================================================================
CREATE OR REPLACE VIEW shipment_cogs_summary AS
  SELECT 
    u.shipment_id,
    u.source_type,
    COUNT(DISTINCT u.item_identifier) as total_items,
    SUM(u.quantity) as total_quantity,
    
    -- Amazon proposed value
    SUM(u.quantity * COALESCE(c.amazon_proposed, 0)) AS shipment_value_amz,
    
    -- Luminize COGS value (using latest_accepted or fallback to luminize_cogs)
    SUM(u.quantity * COALESCE(c.latest_accepted, c.luminize_cogs, 0)) AS shipment_value_lmz,
    
    -- Difference (AMZ - LMZ)
    SUM(u.quantity * COALESCE(c.amazon_proposed, 0)) - SUM(u.quantity * COALESCE(c.latest_accepted, c.luminize_cogs, 0)) AS shipment_value_dif
  FROM unified_shipment_items u
  LEFT JOIN product_mapping pm ON (u.item_identifier = pm.source_identifier)
  LEFT JOIN cogs c ON (COALESCE(pm.canonical_sku, u.item_identifier) = c.sku)
  GROUP BY u.shipment_id, u.source_type;


-- =========================================================================
-- 4. Sample Test Data
-- =========================================================================
INSERT INTO cogs (sku, latest_accepted, amazon_proposed, luminize_cogs) VALUES
  ('PROD-A', 10.00, 12.00, 10.00),
  ('PROD-B', 20.00, 18.00, 20.00)
ON CONFLICT (sku) DO NOTHING;

INSERT INTO product_mapping (source_identifier, canonical_sku) VALUES
  ('FNSKU-AMZ-A', 'PROD-A'),
  ('ASIN-B', 'PROD-B')
ON CONFLICT (source_identifier) DO NOTHING;

INSERT INTO packlist (shipment_id, sku, shipped_qty) VALUES
  ('SHIP-INHOUSE-01', 'PROD-A', 50),
  ('SHIP-INHOUSE-01', 'PROD-B', 100)
ON CONFLICT DO NOTHING;

INSERT INTO shipping ("Shipment ID", "SKUs", "Units expected") VALUES
  ('SHIP-AMZ-99', 'FNSKU-AMZ-A', 150),
  ('SHIP-AMZ-99', 'ASIN-B', 200)
ON CONFLICT DO NOTHING;
