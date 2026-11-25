-- ============================================================
-- The Artistic Sukoon — Razorpay migration
-- Run this in Supabase Dashboard -> SQL Editor -> New query
-- ============================================================

-- Add Razorpay tracking columns to the marketplace orders table
alter table public.artwork_orders
    add column if not exists razorpay_order_id text,
    add column if not exists razorpay_payment_id text;

-- Payment screenshot is no longer required now that Razorpay verifies
-- payments automatically (old manual-UPI orders keep their screenshot)
alter table public.artwork_orders
    alter column payment_screenshot_path drop not null;

-- Same tracking columns were already added for digital_product_orders
-- in digital-products-tables.sql, but this is safe to re-run:
alter table public.digital_product_orders
    add column if not exists razorpay_order_id text,
    add column if not exists razorpay_payment_id text;

-- ============================================================
-- Done.
-- ============================================================
