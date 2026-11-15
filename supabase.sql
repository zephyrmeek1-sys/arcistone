-- ARCISTONE: Supabase sozlash skripti
-- 1) Quyidagi ADMIN_EMAIL_HERE ni O'ZINGIZNING admin emailingizga almashtiring (kamida bir joyda, funksiyada).
-- 2) Supabase -> SQL Editor -> New query -> shu matnni qo'ying -> Run.

create or replace function public.is_admin() returns boolean
language sql stable security definer set search_path = public as $$
  select coalesce(auth.jwt() ->> 'email', '') = 'ADMIN_EMAIL_HERE'
$$;

create table if not exists public.products (id text primary key, pub int not null default 0, data jsonb not null);
create table if not exists public.settings (id int primary key, data jsonb not null);
create table if not exists public.promos   (code text primary key, data jsonb not null);
create table if not exists public.orders   (id text primary key, data jsonb not null, created_at timestamptz not null default now());

alter table public.products enable row level security;
alter table public.settings enable row level security;
alter table public.promos   enable row level security;
alter table public.orders   enable row level security;

-- mijozlar faqat chop etilgan mahsulotlarni ko'radi; admin hammasini
create policy "products read"  on public.products for select using (pub = 1 or public.is_admin());
create policy "products admin" on public.products for all using (public.is_admin()) with check (public.is_admin());
create policy "settings read"  on public.settings for select using (true);
create policy "settings admin" on public.settings for all using (public.is_admin()) with check (public.is_admin());
-- promokodlar ochiq emas: mijoz faqat kodni tekshiradi
create policy "promos admin"   on public.promos for all using (public.is_admin()) with check (public.is_admin());
-- buyurtmani hamma yaratadi, faqat admin o'qiydi
create policy "orders insert"  on public.orders for insert with check (true);
create policy "orders admin"   on public.orders for all using (public.is_admin()) with check (public.is_admin());

create or replace function public.check_promo(p_code text) returns jsonb
language sql stable security definer set search_path = public as $$
  select data from public.promos where code = upper(p_code) and (data ->> 'on') = '1'
$$;
grant execute on function public.check_promo(text) to anon, authenticated;
grant execute on function public.is_admin() to anon, authenticated;

-- rasmlar uchun ochiq bucket
insert into storage.buckets (id, name, public) values ('images', 'images', true) on conflict (id) do nothing;
create policy "images read"   on storage.objects for select using (bucket_id = 'images');
create policy "images insert" on storage.objects for insert with check (bucket_id = 'images' and public.is_admin());
create policy "images update" on storage.objects for update using (bucket_id = 'images' and public.is_admin());
create policy "images delete" on storage.objects for delete using (bucket_id = 'images' and public.is_admin());
