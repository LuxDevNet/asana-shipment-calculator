-- SQL Script to set up your Shipments table in Supabase
-- Run this in your Supabase SQL Editor (https://supabase.com/dashboard)

CREATE TABLE IF NOT EXISTS shipments (
  id TEXT PRIMARY KEY,
  cogs NUMERIC(10, 2) NOT NULL DEFAULT 0.00,
  carrier TEXT,
  status TEXT DEFAULT 'Processing'
);

-- Insert some sample shipments to test the Asana integration
INSERT INTO shipments (id, cogs, carrier, status) VALUES
  ('SH-1001', 120.50, 'FedEx', 'Delivered'),
  ('SH-1002', 85.00, 'UPS', 'In Transit'),
  ('SH-1003', 340.00, 'DHL', 'Shipped'),
  ('SH-1004', 15.75, 'USPS', 'Processing')
ON CONFLICT (id) DO NOTHING;
