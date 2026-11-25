-- ============================================================
-- Fix: give the service_role (used by our Edge Functions) full
-- access to these tables, so verify-razorpay-payment can read
-- and update orders after checking the Razorpay signature.
-- Safe to run multiple times.
-- ============================================================

grant select, insert, update, delete on public.digital_products to service_role;
grant select, insert, update, delete on public.digital_product_orders to service_role;
grant select, insert, update, delete on public.artwork_orders to service_role;
grant usage, select on all sequences in schema public to service_role;
