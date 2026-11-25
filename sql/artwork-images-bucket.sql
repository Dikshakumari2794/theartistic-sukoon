-- ============================================================
-- The Artistic Sukoon — Artwork Images storage bucket
-- Run this in Supabase Dashboard → SQL Editor → New query
-- (Run this AFTER artwork-tables.sql, as a separate step)
-- ============================================================

-- PUBLIC bucket: artwork photos must be viewable by every visitor
-- on the Shop page, even if they are not logged in.
insert into storage.buckets (id, name, public)
values ('artwork-images', 'artwork-images', true)
on conflict (id) do nothing;

-- Anyone can VIEW artwork images (needed for the Shop page to show them)
create policy "Public can view artwork images"
on storage.objects
for select
to anon, authenticated
using (bucket_id = 'artwork-images');

-- Only an admin can UPLOAD artwork images
create policy "Admins can upload artwork images"
on storage.objects
for insert
to authenticated
with check (
    bucket_id = 'artwork-images'
    and exists (
        select 1 from public.admin_users
        where admin_users.user_id = auth.uid()
    )
);

-- Only an admin can DELETE artwork images (e.g. when replacing a photo)
create policy "Admins can delete artwork images"
on storage.objects
for delete
to authenticated
using (
    bucket_id = 'artwork-images'
    and exists (
        select 1 from public.admin_users
        where admin_users.user_id = auth.uid()
    )
);

-- ============================================================
-- Done. After running this, replace admin.html with the new
-- version that uploads photos directly instead of asking for a URL.
-- ============================================================
