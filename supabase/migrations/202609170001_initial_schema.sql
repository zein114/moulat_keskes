-- Moulat Keskes: apply once to a new Supabase project as the database owner.
-- All amounts are whole Mauritanian ouguiya (MRU). Never embed a service key in Flutter.
begin;

create type public.account_role as enum ('customer', 'seller');
create type public.meal_category as enum ('الكسكس', 'الباسي', 'العيش');
create type public.order_status as enum ('pending', 'preparing', 'ready', 'delivered');
create type public.fulfillment_method as enum ('pickup', 'delivery');

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  name text not null check (char_length(btrim(name)) between 1 and 100),
  role public.account_role not null default 'customer',
  created_at timestamptz not null default now()
);

create table public.sellers (
  id uuid primary key references public.profiles(id) on delete cascade,
  name text not null check (char_length(btrim(name)) between 1 and 100),
  area text not null check (char_length(btrim(area)) between 1 and 200),
  bio text not null default '' check (char_length(bio) <= 2000),
  -- These are public business contact/location fields, not private account details.
  phone text not null default '' check (char_length(phone) <= 32),
  latitude double precision not null default 18.0735 check (latitude between -90 and 90),
  longitude double precision not null default -15.9582 check (longitude between -180 and 180),
  is_open boolean not null default true,
  hours text not null default '18:00 – 00:00' check (char_length(hours) <= 100),
  rating numeric(3,2) not null default 0 check (rating between 0 and 5),
  created_at timestamptz not null default now()
);

create table public.meals (
  id uuid primary key default gen_random_uuid(),
  seller_id uuid not null references public.sellers(id) on delete cascade,
  name text not null check (char_length(btrim(name)) between 1 and 150),
  category public.meal_category not null,
  price integer not null check (price between 1 and 1000000),
  stock integer not null default 0 check (stock between 0 and 1000000),
  description text not null default '' check (char_length(description) <= 2000),
  image_url text not null default '' check (
    char_length(image_url) <= 2048 and (image_url = '' or image_url ~ '^https://[^[:space:]]+$')
  ),
  created_at timestamptz not null default now()
);
create index meals_seller_id_idx on public.meals(seller_id);
create index meals_category_idx on public.meals(category);

create table public.orders (
  id uuid primary key default gen_random_uuid(),
  customer_id uuid not null references public.profiles(id),
  seller_id uuid not null references public.sellers(id),
  total integer not null check (total > 0),
  -- Immutable purchase snapshot; prices/names remain accurate after meal edits/deletion.
  items jsonb not null check (jsonb_typeof(items) = 'array' and jsonb_array_length(items) > 0),
  status public.order_status not null default 'pending',
  fulfillment public.fulfillment_method not null default 'pickup',
  address text not null default '' check (char_length(address) <= 1000),
  customer_name text not null check (char_length(btrim(customer_name)) between 1 and 100),
  created_at timestamptz not null default now(),
  check (customer_id <> seller_id),
  check (fulfillment <> 'delivery' or char_length(btrim(address)) > 0)
);
create index orders_customer_created_idx on public.orders(customer_id, created_at desc);
create index orders_seller_created_idx on public.orders(seller_id, created_at desc);

create table public.messages (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references public.orders(id) on delete cascade,
  sender_id uuid not null default auth.uid() references public.profiles(id),
  body text not null check (char_length(btrim(body)) between 1 and 2000),
  created_at timestamptz not null default now()
);
create index messages_order_created_idx on public.messages(order_id, created_at);

create table public.reviews (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null unique references public.orders(id) on delete cascade,
  customer_id uuid not null default auth.uid() references public.profiles(id),
  seller_id uuid not null references public.sellers(id),
  rating integer not null check (rating between 1 and 5),
  comment text not null default '' check (char_length(comment) <= 1000),
  created_at timestamptz not null default now()
);
create index reviews_seller_id_idx on public.reviews(seller_id);

-- Trigger-only helpers live outside the exposed public API schema.
create schema if not exists private;
revoke all on schema private from public, anon, authenticated;

create function private.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.profiles(id, name, role)
  values (
    new.id,
    left(coalesce(nullif(btrim(new.raw_user_meta_data ->> 'name'), ''), 'مستخدم جديد'), 100),
    case when new.raw_user_meta_data ->> 'role' = 'seller'
      then 'seller'::public.account_role else 'customer'::public.account_role end
  );
  return new;
end;
$$;
revoke all on function private.handle_new_user() from public, anon, authenticated;
create trigger on_auth_user_created after insert on auth.users
for each row execute function private.handle_new_user();

-- Also support accounts created before this initial migration was installed.
insert into public.profiles(id, name, role)
select u.id,
  left(coalesce(nullif(btrim(u.raw_user_meta_data ->> 'name'), ''), 'مستخدم جديد'), 100),
  case when u.raw_user_meta_data ->> 'role' = 'seller'
    then 'seller'::public.account_role else 'customer'::public.account_role end
from auth.users u
on conflict (id) do nothing;

create function private.refresh_seller_rating()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_seller_id uuid;
begin
  v_seller_id := case when tg_op = 'DELETE' then old.seller_id else new.seller_id end;
  -- Serialize aggregate updates for the same seller so simultaneous reviews don't lose a rating.
  perform 1 from public.sellers where id = v_seller_id for update;
  update public.sellers
  set rating = coalesce((select round(avg(r.rating), 2) from public.reviews r
    where r.seller_id = v_seller_id), 0)
  where id = v_seller_id;
  if tg_op = 'UPDATE' and old.seller_id <> new.seller_id then
    update public.sellers
    set rating = coalesce((select round(avg(r.rating), 2) from public.reviews r
      where r.seller_id = old.seller_id), 0)
    where id = old.seller_id;
  end if;
  return null;
end;
$$;
revoke all on function private.refresh_seller_rating() from public, anon, authenticated;
create trigger reviews_refresh_rating after insert or update or delete on public.reviews
for each row execute function private.refresh_seller_rating();

alter table public.profiles enable row level security;
alter table public.sellers enable row level security;
alter table public.meals enable row level security;
alter table public.orders enable row level security;
alter table public.messages enable row level security;
alter table public.reviews enable row level security;

-- Explicit grants matter as much as policies. Remove Supabase's legacy default table grants.
revoke all on public.profiles, public.sellers, public.meals, public.orders,
  public.messages, public.reviews from public, anon, authenticated;
grant usage on schema public to anon, authenticated;
grant usage on type public.account_role, public.meal_category,
  public.order_status, public.fulfillment_method to anon, authenticated;
grant select on public.sellers, public.meals to anon, authenticated;
grant select on public.profiles, public.orders, public.messages, public.reviews to authenticated;
grant update(name) on public.profiles to authenticated;
grant insert(id, name, area, bio, phone, latitude, longitude, is_open, hours)
  on public.sellers to authenticated;
grant update(name, area, bio, phone, latitude, longitude, is_open, hours)
  on public.sellers to authenticated;
grant insert(seller_id, name, category, price, stock, description, image_url)
  on public.meals to authenticated;
grant update(name, category, price, stock, description, image_url) on public.meals to authenticated;
grant delete on public.meals to authenticated;
grant insert(order_id, sender_id, body) on public.messages to authenticated;
grant insert(order_id, customer_id, seller_id, rating, comment) on public.reviews to authenticated;

create policy profiles_read_self on public.profiles for select to authenticated
using (id = (select auth.uid()));
create policy profiles_edit_name on public.profiles for update to authenticated
using (id = (select auth.uid())) with check (id = (select auth.uid()));

create policy sellers_public_read on public.sellers for select to anon, authenticated using (true);
create policy sellers_create_own on public.sellers for insert to authenticated
with check (id = (select auth.uid()) and exists (
  select 1 from public.profiles p where p.id = (select auth.uid()) and p.role = 'seller'
));
create policy sellers_edit_own on public.sellers for update to authenticated
using (id = (select auth.uid()) and exists (
  select 1 from public.profiles p where p.id = (select auth.uid()) and p.role = 'seller'
))
with check (id = (select auth.uid()) and exists (
  select 1 from public.profiles p where p.id = (select auth.uid()) and p.role = 'seller'
));

create policy meals_public_read on public.meals for select to anon, authenticated using (true);
create policy meals_create_own on public.meals for insert to authenticated
with check (seller_id = (select auth.uid()) and exists (
  select 1 from public.profiles p where p.id = (select auth.uid()) and p.role = 'seller'
));
create policy meals_edit_own on public.meals for update to authenticated
using (seller_id = (select auth.uid()) and exists (
  select 1 from public.profiles p where p.id = (select auth.uid()) and p.role = 'seller'
))
with check (seller_id = (select auth.uid()) and exists (
  select 1 from public.profiles p where p.id = (select auth.uid()) and p.role = 'seller'
));
create policy meals_delete_own on public.meals for delete to authenticated
using (seller_id = (select auth.uid()) and exists (
  select 1 from public.profiles p where p.id = (select auth.uid()) and p.role = 'seller'
));

create policy orders_participant_read on public.orders for select to authenticated
using ((select auth.uid()) in (customer_id, seller_id));
-- No INSERT/UPDATE/DELETE policies or grants for orders: mutations use the RPCs below.

create policy messages_participant_read on public.messages for select to authenticated
using (exists (select 1 from public.orders o where o.id = order_id
  and (select auth.uid()) in (o.customer_id, o.seller_id)));
create policy messages_participant_send on public.messages for insert to authenticated
with check (sender_id = (select auth.uid()) and exists (
  select 1 from public.orders o where o.id = order_id
    and (select auth.uid()) in (o.customer_id, o.seller_id)
));

-- Review text/order/customer IDs are private to participants; only the aggregate is public.
create policy reviews_participant_read on public.reviews for select to authenticated
using ((select auth.uid()) in (customer_id, seller_id));
create policy reviews_delivered_customer_create on public.reviews for insert to authenticated
with check (customer_id = (select auth.uid()) and exists (
  select 1 from public.orders o where o.id = order_id
    and o.customer_id = (select auth.uid()) and o.seller_id = reviews.seller_id
    and o.status = 'delivered'
));

create function public.place_order(
  p_items jsonb,
  p_fulfillment text,
  p_address text,
  p_customer_name text
)
returns setof public.orders
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
  v_item jsonb;
  v_requested jsonb;
  v_lines jsonb := '[]'::jsonb;
  v_line record;
  v_group record;
  v_seen integer := 0;
begin
  if v_user_id is null then
    raise exception 'Sign in before placing an order' using errcode = '42501';
  end if;
  if not exists (select 1 from public.profiles where id = v_user_id) then
    raise exception 'Complete account setup first' using errcode = '42501';
  end if;
  if p_fulfillment is null or p_fulfillment not in ('pickup', 'delivery') then
    raise exception 'Invalid fulfillment method' using errcode = '22023';
  end if;
  if p_customer_name is null or char_length(btrim(p_customer_name)) not between 1 and 100 then
    raise exception 'Customer name must contain 1 to 100 characters' using errcode = '22023';
  end if;
  if char_length(coalesce(p_address, '')) > 1000 or
    (p_fulfillment = 'delivery' and coalesce(btrim(p_address), '') = '') then
    raise exception 'Provide a delivery address of at most 1000 characters' using errcode = '22023';
  end if;
  if p_items is null or jsonb_typeof(p_items) <> 'array' then
    raise exception 'Items must be a JSON array' using errcode = '22023';
  end if;
  if jsonb_array_length(p_items) not between 1 and 100 then
    raise exception 'An order must contain 1 to 100 meal lines' using errcode = '22023';
  end if;

  for v_item in select value from jsonb_array_elements(p_items)
  loop
    if jsonb_typeof(v_item) <> 'object'
      or jsonb_typeof(v_item -> 'meal_id') is distinct from 'string'
      or (v_item ->> 'meal_id') !~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
      or jsonb_typeof(v_item -> 'quantity') is distinct from 'number'
      or (v_item ->> 'quantity') !~ '^[1-9][0-9]{0,3}$' then
      raise exception 'Every item needs a meal UUID and a positive integer quantity' using errcode = '22023';
    end if;
    if (v_item ->> 'quantity')::integer > 1000 then
      raise exception 'Maximum quantity per meal is 1000' using errcode = '22023';
    end if;
    if v_item ? 'price' then
      if jsonb_typeof(v_item -> 'price') is distinct from 'number'
        or (v_item ->> 'price') !~ '^[1-9][0-9]{0,6}$' then
        raise exception 'Expected price must be a positive integer' using errcode = '22023';
      end if;
      if (v_item ->> 'price')::integer > 1000000 then
        raise exception 'Expected price is outside the supported range' using errcode = '22023';
      end if;
    end if;
  end loop;

  -- Normalize duplicate IDs before locking. Optional prices are expectations, never authority.
  select jsonb_agg(jsonb_build_object('meal_id', t.meal_id, 'quantity', t.quantity))
  into v_requested
  from (
    select (j.value ->> 'meal_id')::uuid as meal_id,
      sum((j.value ->> 'quantity')::integer)::integer as quantity
    from jsonb_array_elements(p_items) j
    group by (j.value ->> 'meal_id')::uuid
  ) t;
  if exists (select 1 from jsonb_to_recordset(v_requested) as r(meal_id uuid, quantity integer)
    where r.quantity > 1000) then
    raise exception 'Maximum combined quantity per meal is 1000' using errcode = '22023';
  end if;

  -- A single global lock order prevents opposite cart order deadlocks.
  -- Lock all seller rows first so opening hours/state cannot change during checkout.
  perform s.id from public.sellers s
  where s.id in (
    select m.seller_id from public.meals m
    join jsonb_to_recordset(v_requested) as r(meal_id uuid, quantity integer) on r.meal_id = m.id
  )
  order by s.id for update;

  for v_line in
    select m.id, m.seller_id, m.name, m.price, m.stock, r.quantity
    from public.meals m
    join jsonb_to_recordset(v_requested) as r(meal_id uuid, quantity integer) on r.meal_id = m.id
    order by m.id for update of m
  loop
    v_seen := v_seen + 1;
    if v_line.seller_id = v_user_id then
      raise exception 'You cannot order your own meals' using errcode = '22023';
    end if;
    if not exists (select 1 from public.sellers s where s.id = v_line.seller_id and s.is_open) then
      raise exception 'A selected kitchen is closed' using errcode = '22023';
    end if;
    if exists (
      select 1 from jsonb_array_elements(p_items) j
      where (j.value ->> 'meal_id')::uuid = v_line.id
        and j.value ? 'price' and (j.value ->> 'price')::integer <> v_line.price
    ) then
      raise exception 'Meal price changed; refresh cart' using errcode = '22023';
    end if;
    if v_line.stock < v_line.quantity then
      raise exception 'Insufficient stock for %', v_line.name using errcode = '22023';
    end if;
    update public.meals set stock = stock - v_line.quantity where id = v_line.id;
    v_lines := v_lines || jsonb_build_array(jsonb_build_object(
      'meal_id', v_line.id, 'seller_id', v_line.seller_id,
      'name', v_line.name, 'quantity', v_line.quantity, 'price', v_line.price
    ));
  end loop;
  if v_seen <> jsonb_array_length(v_requested) then
    -- Raising aborts all earlier reservations, including a multi-seller cart.
    raise exception 'A selected meal no longer exists' using errcode = '22023';
  end if;

  for v_group in
    select (j.value ->> 'seller_id')::uuid as seller_id,
      jsonb_agg(j.value - 'seller_id' order by j.value ->> 'meal_id') as items,
      sum((j.value ->> 'price')::bigint * (j.value ->> 'quantity')::bigint) as total
    from jsonb_array_elements(v_lines) j
    group by (j.value ->> 'seller_id')::uuid
    order by (j.value ->> 'seller_id')::uuid
  loop
    if v_group.total > 2147483647 then
      raise exception 'Order total is too large' using errcode = '22023';
    end if;
    return query
    insert into public.orders(customer_id, seller_id, total, items, fulfillment, address, customer_name)
    values (v_user_id, v_group.seller_id, v_group.total::integer, v_group.items,
      p_fulfillment::public.fulfillment_method, btrim(coalesce(p_address, '')), btrim(p_customer_name))
    returning *;
  end loop;
end;
$$;

create function public.advance_order(p_order_id uuid)
returns public.orders
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_order public.orders;
  v_next public.order_status;
begin
  if auth.uid() is null then
    raise exception 'Sign in first' using errcode = '42501';
  end if;
  select * into v_order from public.orders
  where id = p_order_id and seller_id = auth.uid() for update;
  if not found then
    raise exception 'Order unavailable or not owned by this seller' using errcode = '42501';
  end if;
  v_next := case v_order.status
    when 'pending' then 'preparing'::public.order_status
    when 'preparing' then 'ready'::public.order_status
    when 'ready' then 'delivered'::public.order_status
    else null end;
  if v_next is null then
    raise exception 'Order is already delivered' using errcode = '22023';
  end if;
  update public.orders set status = v_next where id = v_order.id returning * into v_order;
  return v_order;
end;
$$;

revoke all on function public.place_order(jsonb, text, text, text) from public, anon, authenticated;
revoke all on function public.advance_order(uuid) from public, anon, authenticated;
grant execute on function public.place_order(jsonb, text, text, text) to authenticated;
grant execute on function public.advance_order(uuid) to authenticated;

comment on function public.place_order(jsonb, text, text, text) is
  'Creates one order per seller atomically; reserves stock and snapshots authoritative prices. Auth required.';
comment on column public.profiles.role is
  'Chosen at signup (customer/seller); immutable by app clients. Metadata edits do not change this role.';
comment on column public.sellers.rating is 'Derived from verified, delivered-order reviews; not writable by clients.';
comment on column public.orders.total is 'Whole MRU; computed from server prices, with no online payment capture.';

commit;
