-- ============================================================
-- The Artistic Sukoon — Paid Courses (video lessons)
-- Run this in Supabase Dashboard -> SQL Editor -> New query
-- Safe to run multiple times.
-- ============================================================

-- ---------- TABLE: courses ----------
create table if not exists public.courses (
    id bigint generated always as identity primary key,
    title text not null,
    description text,
    price numeric not null,
    thumbnail_url text,
    created_at timestamptz default now()
);

alter table public.courses enable row level security;

drop policy if exists "Public can view courses" on public.courses;
drop policy if exists "Admin can manage courses" on public.courses;

create policy "Public can view courses"
on public.courses for select
to anon, authenticated
using (true);

create policy "Admin can manage courses"
on public.courses for all
to authenticated
using (exists (select 1 from public.admin_users where user_id = auth.uid()))
with check (exists (select 1 from public.admin_users where user_id = auth.uid()));

grant select on public.courses to anon;
grant select, insert, update, delete on public.courses to authenticated, service_role;


-- ---------- TABLE: course_enrollments ----------
-- (created BEFORE course_videos because course_videos' policy below
--  references this table)
create table if not exists public.course_enrollments (
    id bigint generated always as identity primary key,
    course_id bigint not null references public.courses(id) on delete cascade,
    course_title text not null,
    price numeric not null,
    buyer_id uuid not null,
    buyer_name text,
    email text,
    status text default 'Awaiting Payment',  -- Awaiting Payment | Paid | Failed
    razorpay_order_id text,
    razorpay_payment_id text,
    created_at timestamptz default now()
);

alter table public.course_enrollments enable row level security;

drop policy if exists "Buyer can view own course enrollments" on public.course_enrollments;
drop policy if exists "Buyer can create own course enrollment" on public.course_enrollments;
drop policy if exists "Admin can manage all course enrollments" on public.course_enrollments;

create policy "Buyer can view own course enrollments"
on public.course_enrollments for select
to authenticated
using (buyer_id = auth.uid());

create policy "Buyer can create own course enrollment"
on public.course_enrollments for insert
to authenticated
with check (buyer_id = auth.uid());

create policy "Admin can manage all course enrollments"
on public.course_enrollments for all
to authenticated
using (exists (select 1 from public.admin_users where user_id = auth.uid()))
with check (exists (select 1 from public.admin_users where user_id = auth.uid()));

grant select, insert on public.course_enrollments to authenticated;
grant select, insert, update, delete on public.course_enrollments to service_role;
grant usage, select on all sequences in schema public to authenticated, service_role;


-- ---------- TABLE: course_videos ----------
-- Each row = one video lesson belonging to a course
create table if not exists public.course_videos (
    id bigint generated always as identity primary key,
    course_id bigint not null references public.courses(id) on delete cascade,
    title text not null,
    video_path text not null,     -- path inside the private 'course-videos' bucket
    sort_order integer default 0,
    created_at timestamptz default now()
);

alter table public.course_videos enable row level security;

drop policy if exists "Admin can manage course videos" on public.course_videos;
drop policy if exists "Enrolled buyer can view course video rows" on public.course_videos;

create policy "Admin can manage course videos"
on public.course_videos for all
to authenticated
using (exists (select 1 from public.admin_users where user_id = auth.uid()))
with check (exists (select 1 from public.admin_users where user_id = auth.uid()));

-- A logged-in buyer can see the video LIST (title etc.) only for a course
-- they have a Paid enrollment for.
create policy "Enrolled buyer can view course video rows"
on public.course_videos for select
to authenticated
using (
    exists (
        select 1 from public.course_enrollments e
        where e.course_id = course_videos.course_id
          and e.buyer_id = auth.uid()
          and e.status = 'Paid'
    )
);

grant select, insert, update, delete on public.course_videos to authenticated, service_role;


-- ---------- STORAGE BUCKET: course-thumbnails (PUBLIC) ----------
insert into storage.buckets (id, name, public, file_size_limit)
values ('course-thumbnails', 'course-thumbnails', true, 10485760) -- 10 MB
on conflict (id) do nothing;

drop policy if exists "Public can view course thumbnails" on storage.objects;
drop policy if exists "Admin can upload course thumbnails" on storage.objects;
drop policy if exists "Admin can delete course thumbnails" on storage.objects;

create policy "Public can view course thumbnails"
on storage.objects for select
to anon, authenticated
using (bucket_id = 'course-thumbnails');

create policy "Admin can upload course thumbnails"
on storage.objects for insert
to authenticated
with check (
    bucket_id = 'course-thumbnails'
    and exists (select 1 from public.admin_users where user_id = auth.uid())
);

create policy "Admin can delete course thumbnails"
on storage.objects for delete
to authenticated
using (
    bucket_id = 'course-thumbnails'
    and exists (select 1 from public.admin_users where user_id = auth.uid())
);


-- ---------- STORAGE BUCKET: course-videos (PRIVATE) ----------
-- 500 MB per file limit. If a video is bigger, compress it first
-- (Supabase's free plan has a limited total storage quota, so keep
-- videos reasonably compressed/short where possible).
insert into storage.buckets (id, name, public, file_size_limit)
values ('course-videos', 'course-videos', false, 524288000) -- 500 MB
on conflict (id) do update set file_size_limit = 524288000;

drop policy if exists "Admin can upload course videos" on storage.objects;
drop policy if exists "Admin can delete course videos" on storage.objects;
drop policy if exists "Admin can view course videos" on storage.objects;
drop policy if exists "Enrolled buyer can view course video file" on storage.objects;

create policy "Admin can upload course videos"
on storage.objects for insert
to authenticated
with check (
    bucket_id = 'course-videos'
    and exists (select 1 from public.admin_users where user_id = auth.uid())
);

create policy "Admin can delete course videos"
on storage.objects for delete
to authenticated
using (
    bucket_id = 'course-videos'
    and exists (select 1 from public.admin_users where user_id = auth.uid())
);

create policy "Admin can view course videos"
on storage.objects for select
to authenticated
using (
    bucket_id = 'course-videos'
    and exists (select 1 from public.admin_users where user_id = auth.uid())
);

-- A buyer can stream a video file ONLY if they have a Paid enrollment
-- for the course that owns a course_videos row with this exact path.
create policy "Enrolled buyer can view course video file"
on storage.objects for select
to authenticated
using (
    bucket_id = 'course-videos'
    and exists (
        select 1
        from public.course_videos v
        join public.course_enrollments e on e.course_id = v.course_id
        where e.buyer_id = auth.uid()
          and e.status = 'Paid'
          and v.video_path = storage.objects.name
    )
);

-- ============================================================
-- Done. After running this:
-- 1. Go to admin.html and add courses (title, description, price, thumbnail)
-- 2. Add video lessons to each course (upload video files)
-- 3. Customers see courses.html, enroll via Razorpay
-- 4. After payment, they can watch videos in course-player.html
--    (access is enforced by the database, not just the page)
-- ============================================================
