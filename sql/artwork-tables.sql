-- ============================================================
-- The Artistic Sukoon — Artworks + Artwork Orders setup
-- Run this ONCE in Supabase Dashboard → SQL Editor → New query
-- ============================================================

-- 1. ARTWORKS TABLE (your admin-managed catalog)
create table if not exists public.artworks (
    id bigint generated always as identity primary key,
    name text not null,
    description text,
    price numeric not null,
    image_url text not null,
    category text not null default 'paintings',
    created_at timestamptz not null default now()
);

alter table public.artworks enable row level security;

-- Anyone (even logged-out visitors) can VIEW artworks
create policy "Public can view artworks"
on public.artworks
for select
to anon, authenticated
using (true);

-- Only an admin (present in admin_users) can ADD artworks
create policy "Admins can insert artworks"
on public.artworks
for insert
to authenticated
with check (
    exists (
        select 1 from public.admin_users
        where admin_users.user_id = auth.uid()
    )
);

-- Only an admin can EDIT artworks
create policy "Admins can update artworks"
on public.artworks
for update
to authenticated
using (
    exists (
        select 1 from public.admin_users
        where admin_users.user_id = auth.uid()
    )
);

-- Only an admin can DELETE artworks
create policy "Admins can delete artworks"
on public.artworks
for delete
to authenticated
using (
    exists (
        select 1 from public.admin_users
        where admin_users.user_id = auth.uid()
    )
);


-- 2. ARTWORK_ORDERS TABLE (Buy Now / UPI purchase requests)
create table if not exists public.artwork_orders (
    id bigint generated always as identity primary key,
    artwork_id bigint references public.artworks(id),
    artwork_name text not null,
    price numeric not null,
    buyer_id uuid not null references auth.users(id),
    buyer_name text not null,
    email text not null,
    phone text,
    address text not null,
    payment_screenshot_path text,
    status text not null default 'Payment Pending',
    created_at timestamptz not null default now()
);

alter table public.artwork_orders enable row level security;

-- A logged-in buyer can create their OWN order
create policy "Buyers can insert their own artwork orders"
on public.artwork_orders
for insert
to authenticated
with check (buyer_id = auth.uid());

-- A buyer can view their OWN orders; an admin can view ALL orders
create policy "Buyers view own orders, admins view all"
on public.artwork_orders
for select
to authenticated
using (
    buyer_id = auth.uid()
    or exists (
        select 1 from public.admin_users
        where admin_users.user_id = auth.uid()
    )
);

-- Only an admin can update order status (e.g. mark Confirmed)
create policy "Admins can update artwork orders"
on public.artwork_orders
for update
to authenticated
using (
    exists (
        select 1 from public.admin_users
        where admin_users.user_id = auth.uid()
    )
);


-- 3. STORAGE BUCKET for payment screenshots
-- Go to Storage in the Supabase dashboard and create a bucket named
-- exactly:  payment-screenshots   (keep it PRIVATE, not public)
-- Then run the policies below.

insert into storage.buckets (id, name, public)
values ('payment-screenshots', 'payment-screenshots', false)
on conflict (id) do nothing;

-- A logged-in buyer can upload a file into their own folder
-- (folder name = their user id, enforced by the app's upload path)
create policy "Buyers can upload their own payment screenshot"
on storage.objects
for insert
to authenticated
with check (
    bucket_id = 'payment-screenshots'
    and (storage.foldername(name))[1] = auth.uid()::text
);

-- A buyer can view their own screenshot; an admin can view all
create policy "Buyers view own screenshot, admins view all"
on storage.objects
for select
to authenticated
using (
    bucket_id = 'payment-screenshots'
    and (
        (storage.foldername(name))[1] = auth.uid()::text
        or exists (
            select 1 from public.admin_users
            where admin_users.user_id = auth.uid()
        )
    )
);

-- ============================================================
-- Done. After running this, come back and tell Claude so the
-- website files (shop.html, product.html, admin.html) can be
-- updated to use these tables.
-- ============================================================
