-- NovaMart production database foundation
-- Run this in Supabase SQL Editor.

create extension if not exists pgcrypto;

do $$ begin
  create type public.user_role as enum ('customer','admin');
exception when duplicate_object then null; end $$;

do $$ begin
  create type public.order_status as enum ('pending','confirmed','processing','shipped','delivered','cancelled');
exception when duplicate_object then null; end $$;

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text,
  phone text,
  role public.user_role not null default 'customer',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.products (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  description text not null default '',
  category text not null default 'General',
  price numeric(12,2) not null check (price >= 0),
  stock integer not null default 0 check (stock >= 0),
  icon text not null default '📦',
  image_url text,
  rating numeric(2,1) not null default 0 check (rating >= 0 and rating <= 5),
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.orders (
  id uuid primary key default gen_random_uuid(),
  customer_id uuid references public.profiles(id) on delete set null,
  customer_name text not null,
  customer_email text not null,
  phone text,
  address text not null,
  city text,
  postal_code text,
  status public.order_status not null default 'pending',
  subtotal numeric(12,2) not null check (subtotal >= 0),
  total numeric(12,2) not null check (total >= 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.order_items (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references public.orders(id) on delete cascade,
  product_id uuid references public.products(id) on delete set null,
  product_name text not null,
  price numeric(12,2) not null check (price >= 0),
  quantity integer not null check (quantity > 0),
  line_total numeric(12,2) not null check (line_total >= 0)
);

create index if not exists products_category_idx on public.products(category);
create index if not exists products_active_idx on public.products(active);
create index if not exists orders_customer_idx on public.orders(customer_id);
create index if not exists orders_created_idx on public.orders(created_at desc);
create index if not exists order_items_order_idx on public.order_items(order_id);

alter table public.profiles enable row level security;
alter table public.products enable row level security;
alter table public.orders enable row level security;
alter table public.order_items enable row level security;

-- Public storefront may read active products.
drop policy if exists "Public can view active products" on public.products;
create policy "Public can view active products" on public.products
for select using (active = true);

-- Signed-in customers can view/update their own profile.
drop policy if exists "Users can view own profile" on public.profiles;
create policy "Users can view own profile" on public.profiles
for select to authenticated using (id = auth.uid());

drop policy if exists "Users can update own profile" on public.profiles;
create policy "Users can update own profile" on public.profiles
for update to authenticated using (id = auth.uid()) with check (id = auth.uid());

-- Customers can see only their own orders/items.
drop policy if exists "Customers can view own orders" on public.orders;
create policy "Customers can view own orders" on public.orders
for select to authenticated using (customer_id = auth.uid());

drop policy if exists "Customers can view own order items" on public.order_items;
create policy "Customers can view own order items" on public.order_items
for select to authenticated using (
  exists (select 1 from public.orders o where o.id = order_id and o.customer_id = auth.uid())
);

-- Admin helper. The role is stored in profiles and should only be changed by an existing admin.
create or replace function public.is_admin()
returns boolean language sql stable security definer set search_path = public
as $$ select exists (select 1 from public.profiles where id = auth.uid() and role = 'admin'); $$;

-- Admin policies.
drop policy if exists "Admins manage products" on public.products;
create policy "Admins manage products" on public.products
for all to authenticated using (public.is_admin()) with check (public.is_admin());

drop policy if exists "Admins manage orders" on public.orders;
create policy "Admins manage orders" on public.orders
for all to authenticated using (public.is_admin()) with check (public.is_admin());

drop policy if exists "Admins manage order items" on public.order_items;
create policy "Admins manage order items" on public.order_items
for all to authenticated using (public.is_admin()) with check (public.is_admin());

-- Create a profile automatically whenever a customer signs up.
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = public
as $$
begin
  insert into public.profiles (id, full_name) values (new.id, coalesce(new.raw_user_meta_data->>'full_name',''))
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
after insert on auth.users
for each row execute procedure public.handle_new_user();

-- Seed the current NovaMart catalog. Safe to run more than once.
insert into public.products (name, description, category, price, stock, icon, rating)
select * from (values
 ('Nova Wireless Headphones','Comfortable wireless headphones with rich sound and all-day battery life.','Electronics',2499,50,'🎧',4.8),
 ('Smart Watch Pro','A modern smartwatch for notifications, activity tracking and everyday use.','Electronics',3299,35,'⌚',4.7),
 ('Everyday Sneakers','Lightweight everyday sneakers designed for comfortable casual wear.','Fashion',1899,40,'👟',4.6),
 ('Minimal Backpack','Clean, practical backpack with room for your daily essentials.','Fashion',1299,60,'🎒',4.5),
 ('Portable Speaker','Compact portable speaker with clear audio for rooms and travel.','Electronics',1599,45,'🔊',4.7),
 ('Desk Lamp','Minimal desk lamp for focused study and work sessions.','Home',899,70,'💡',4.4),
 ('Coffee Maker','Simple coffee maker for quick, convenient home brewing.','Home',2199,25,'☕',4.6),
 ('Fitness Bottle','Reusable bottle made for school, workouts and everyday hydration.','Sports',699,100,'🥤',4.3)
) as v(name,description,category,price,stock,icon,rating)
where not exists (select 1 from public.products p where p.name = v.name);

-- IMPORTANT: after your first account is created, promote your account manually in SQL:
-- update public.profiles set role = 'admin' where id = 'YOUR-AUTH-USER-UUID';
