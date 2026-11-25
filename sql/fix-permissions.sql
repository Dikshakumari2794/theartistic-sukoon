-- ============================================================
-- The Artistic Sukoon — Fix "permission denied" on artworks table
-- Run this in Supabase Dashboard → SQL Editor → New query
-- ============================================================

-- Allow logged-in users (admin check still enforced by RLS policies)
-- to interact with the artworks table
grant select, insert, update, delete on public.artworks to authenticated;
grant select on public.artworks to anon;

-- Allow logged-in users to interact with artwork_orders
-- (RLS policies still restrict buyers to their own orders,
-- and admins to all orders)
grant select, insert, update on public.artwork_orders to authenticated;

-- Needed so new rows can get their auto-generated id
grant usage, select on all sequences in schema public to authenticated;

-- ============================================================
-- Done. After running this, go back to the admin panel and try
-- saving the artwork again.
-- ============================================================
