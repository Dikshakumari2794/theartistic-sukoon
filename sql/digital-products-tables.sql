-- ============================================================
-- The Artistic Sukoon — Digital Products (downloadable art photos)
-- Run this in Supabase Dashboard -> SQL Editor -> New query
-- Safe to run multiple times (old policies are dropped and recreated)
-- ============================================================

-- ---------- TABLE: digital_products ----------
-- Each row = one digital artwork photo for sale
create table if not exists public.digital_products (
    id bigint generated always as identity primary key,
    name text not null,
    description text,
    price numeric not null,
    preview_image_url text not null,   -- public, watermarked low-res preview
    file_path text not null,           -- private bucket path to the real high-res file
    category text,
    created_at timestamptz default now()
);

alter table public.digital_products enable row level security;

drop policy if exists "Public can view digital products" on public.digital_products;
drop policy if exists "Admin can manage digital products" on public.digital_products;

-- Anyone can view the product list (preview only, not the real file)
create policy "Public can view digital products"
on public.digital_products for select
to anon, authenticated
using (true);

-- Only admin can add/edit/delete digital products
create policy "Admin can manage digital products"
on public.digital_products for all
to authenticated
using (exists (select 1 from public.admin_users where user_id = auth.uid()))
with check (exists (select 1 from public.admin_users where user_id = auth.uid()));

grant select on public.digital_products to anon;
grant select, insert, update, delete on public.digital_products to authenticated;


-- ---------- TABLE: digital_product_orders ----------
create table if not exists public.digital_product_orders (
    id bigint generated always as identity primary key,
    product_id bigint references public.digital_products(id),
    product_name text not null,
    price numeric not null,
    buyer_id uuid not null,
    buyer_name text,
    email text,
    status text default 'Awaiting Payment',  -- Awaiting Payment | Paid | Failed
    razorpay_order_id text,
    razorpay_payment_id text,
    created_at timestamptz default now()
);

alter table public.digital_product_orders enable row level security;

drop policy if exists "Buyer can view own digital orders" on public.digital_product_orders;
drop policy if exists "Buyer can create own digital order" on public.digital_product_orders;
drop policy if exists "Admin can manage all digital orders" on public.digital_product_orders;

-- Buyer can see their own orders
create policy "Buyer can view own digital orders"
on public.digital_product_orders for select
to authenticated
using (buyer_id = auth.uid());

-- Buyer can create their own order (status starts as Awaiting Payment)
create policy "Buyer can create own digital order"
on public.digital_product_orders for insert
to authenticated
with check (buyer_id = auth.uid());

-- Admin can view / manage all digital orders
create policy "Admin can manage all digital orders"
on public.digital_product_orders for all
to authenticated
using (exists (select 1 from public.admin_users where user_id = auth.uid()))
with check (exists (select 1 from public.admin_users where user_id = auth.uid()));

grant select, insert on public.digital_product_orders to authenticated;
grant usage, select on all sequences in schema public to authenticated;


-- ---------- STORAGE BUCKET: digital-product-previews (PUBLIC) ----------
insert into storage.buckets (id, name, public)
values ('digital-product-previews', 'digital-product-previews', true)
on conflict (id) do nothing;

drop policy if exists "Public can view digital product previews" on storage.objects;
drop policy if exists "Admin can upload digital product previews" on storage.objects;
drop policy if exists "Admin can delete digital product previews" on storage.objects;

create policy "Public can view digital product previews"
on storage.objects for select
to anon, authenticated
using (bucket_id = 'digital-product-previews');

create policy "Admin can upload digital product previews"
on storage.objects for insert
to authenticated
with check (
    bucket_id = 'digital-product-previews'
    and exists (select 1 from public.admin_users where user_id = auth.uid())
);

create policy "Admin can delete digital product previews"
on storage.objects for delete
to authenticated
using (
    bucket_id = 'digital-product-previews'
    and exists (select 1 from public.admin_users where user_id = auth.uid())
);


-- ---------- STORAGE BUCKET: digital-product-files (PRIVATE) ----------
insert into storage.buckets (id, name, public)
values ('digital-product-files', 'digital-product-files', false)
on conflict (id) do nothing;

drop policy if exists "Admin can upload digital product files" on storage.objects;
drop policy if exists "Admin can delete digital product files" on storage.objects;
drop policy if exists "Admin can view digital product files" on storage.objects;
drop policy if exists "Buyer can view digital file only after paid order" on storage.objects;

-- Admin can upload/delete the real files
create policy "Admin can upload digital product files"
on storage.objects for insert
to authenticated
with check (
    bucket_id = 'digital-product-files'
    and exists (select 1 from public.admin_users where user_id = auth.uid())
);

create policy "Admin can delete digital product files"
on storage.objects for delete
to authenticated
using (
    bucket_id = 'digital-product-files'
    and exists (select 1 from public.admin_users where user_id = auth.uid())
);

-- Admin can also view/download any file (for checking uploads)
create policy "Admin can view digital product files"
on storage.objects for select
to authenticated
using (
    bucket_id = 'digital-product-files'
    and exists (select 1 from public.admin_users where user_id = auth.uid())
);

-- A buyer can ONLY view/download a file if they have a PAID order
-- for a digital_products row whose file_path matches this object's name
create policy "Buyer can view digital file only after paid order"
on storage.objects for select
to authenticated
using (
    bucket_id = 'digital-product-files'
    and exists (
        select 1
        from public.digital_product_orders o
        join public.digital_products p on p.id = o.product_id
        where o.buyer_id = auth.uid()
          and o.status = 'Paid'
          and p.file_path = storage.objects.name
    )
);

-- ============================================================
-- Done. After running this:
-- 1. Go to admin.html and add digital products (preview + real file)
-- 2. Customers can browse digital-products.html and buy
-- 3. Download unlocks in My Orders only once status = 'Paid'
--    (status will be set to 'Paid' once Razorpay payment succeeds)
-- ============================================================
