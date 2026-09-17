-- Integration smoke test for a disposable Supabase project AFTER the migration.
-- Run the whole file as the database owner in SQL Editor or with psql -v ON_ERROR_STOP=1.
-- Every fixture and mutation is rolled back. An unexpected result raises an error.
-- This script does not simulate simultaneous connections; see docs/SUPABASE_SETUP.md.
begin;

insert into auth.users(id, aud, role, email, raw_user_meta_data) values
  ('10000000-0000-0000-0000-000000000101', 'authenticated', 'authenticated',
    'seller-a@moulat-test.invalid', '{"name":"Test seller A","role":"seller"}'),
  ('10000000-0000-0000-0000-000000000102', 'authenticated', 'authenticated',
    'seller-b@moulat-test.invalid', '{"name":"Test seller B","role":"seller"}'),
  ('10000000-0000-0000-0000-000000000201', 'authenticated', 'authenticated',
    'customer@moulat-test.invalid', '{"name":"Test customer","role":"customer"}'),
  ('10000000-0000-0000-0000-000000000202', 'authenticated', 'authenticated',
    'stranger@moulat-test.invalid', '{"name":"Test stranger","role":"customer"}');

insert into public.sellers(id, name, area) values
  ('10000000-0000-0000-0000-000000000101', 'Test seller A', 'Test area'),
  ('10000000-0000-0000-0000-000000000102', 'Test seller B', 'Test area');
insert into public.meals(id, seller_id, name, category, price, stock) values
  ('10000000-0000-0000-0000-000000000301', '10000000-0000-0000-0000-000000000101',
    'Meal A', 'الكسكس', 250, 6),
  ('10000000-0000-0000-0000-000000000302', '10000000-0000-0000-0000-000000000102',
    'Meal B', 'الباسي', 200, 2);

set local role authenticated;
select set_config('request.jwt.claim.sub', '10000000-0000-0000-0000-000000000201', true);

-- Duplicate lines normalize; optional expected prices must match, names are ignored.
select * from public.place_order(
  '[{"meal_id":"10000000-0000-0000-0000-000000000301","quantity":1,"price":250,"name":"Fake"},
    {"meal_id":"10000000-0000-0000-0000-000000000301","quantity":1},
    {"meal_id":"10000000-0000-0000-0000-000000000302","quantity":1}]',
  'pickup', '', 'Test customer'
);
select set_config('moulat.test_order_a', (
  select id::text from public.orders where seller_id = '10000000-0000-0000-0000-000000000101'
), true);
select set_config('moulat.test_order_b', (
  select id::text from public.orders where seller_id = '10000000-0000-0000-0000-000000000102'
), true);

do $$
begin
  if (select count(*) from public.profiles) <> 1 then
    raise exception 'FAIL: a customer can read another profile';
  end if;
  if (select count(*) from public.orders) <> 2 then
    raise exception 'FAIL: multi-seller checkout did not create exactly two orders';
  end if;
  if not exists (select 1 from public.orders
    where id = current_setting('moulat.test_order_a')::uuid and total = 500
      and items = '[{"meal_id":"10000000-0000-0000-0000-000000000301","name":"Meal A","quantity":2,"price":250}]'::jsonb
  ) then
    raise exception 'FAIL: the server did not use authoritative prices and normalized quantities';
  end if;
  if (select stock from public.meals where id = '10000000-0000-0000-0000-000000000301') <> 4 then
    raise exception 'FAIL: stock not reserved';
  end if;

  begin
    perform public.place_order(
      '[{"meal_id":"10000000-0000-0000-0000-000000000301","quantity":1,"price":250},
        {"meal_id":"10000000-0000-0000-0000-000000000302","quantity":1,"price":199}]',
      'pickup', '', 'Test customer');
    raise exception 'FAIL: a stale displayed price was accepted';
  exception when invalid_parameter_value then
    if sqlerrm <> 'Meal price changed; refresh cart' then raise; end if;
  end;
  if (select stock from public.meals where id = '10000000-0000-0000-0000-000000000301') <> 4
    or (select stock from public.meals where id = '10000000-0000-0000-0000-000000000302') <> 1
    or (select count(*) from public.orders) <> 2 then
    raise exception 'FAIL: stale-price rejection left partial inventory/orders';
  end if;

  begin
    perform public.place_order(
      '[{"meal_id":"10000000-0000-0000-0000-000000000301","quantity":1},
        {"meal_id":"10000000-0000-0000-0000-000000000302","quantity":2}]',
      'pickup', '', 'Test customer');
    raise exception 'FAIL: insufficient stock was accepted';
  exception when invalid_parameter_value then null;
  end;
  if (select stock from public.meals where id = '10000000-0000-0000-0000-000000000301') <> 4
    or (select count(*) from public.orders) <> 2 then
    raise exception 'FAIL: unsuccessful multi-seller checkout left partial changes';
  end if;

  begin
    perform public.place_order(
      '[{"meal_id":"10000000-0000-0000-0000-000000000301","quantity":-1}]',
      'pickup', '', 'Test customer');
    raise exception 'FAIL: negative quantity accepted';
  exception when invalid_parameter_value then null;
  end;
  begin
    perform public.place_order(
      '[{"meal_id":"10000000-0000-0000-0000-000000000301","quantity":1}]',
      'delivery', '', 'Test customer');
    raise exception 'FAIL: delivery accepted without an address';
  exception when invalid_parameter_value then null;
  end;
  begin
    update public.profiles set role = 'seller' where id = auth.uid();
    raise exception 'FAIL: customer changed their role';
  exception when insufficient_privilege then null;
  end;
  begin
    update public.orders set status = 'delivered' where id = current_setting('moulat.test_order_a')::uuid;
    raise exception 'FAIL: direct order mutation accepted';
  exception when insufficient_privilege then null;
  end;
  begin
    perform public.advance_order(current_setting('moulat.test_order_a')::uuid);
    raise exception 'FAIL: customer advanced seller order';
  exception when insufficient_privilege then null;
  end;
  begin
    insert into public.reviews(order_id, seller_id, rating)
    values (current_setting('moulat.test_order_a')::uuid, '10000000-0000-0000-0000-000000000101', 5);
    raise exception 'FAIL: review accepted before delivery';
  exception when insufficient_privilege then null;
  end;
end;
$$;

insert into public.messages(order_id, body)
values (current_setting('moulat.test_order_a')::uuid, 'Test message');

-- An unrelated signed-in account cannot discover orders/chat or impersonate participants.
select set_config('request.jwt.claim.sub', '10000000-0000-0000-0000-000000000202', true);
do $$
begin
  if exists (select 1 from public.orders) or exists (select 1 from public.messages) then
    raise exception 'FAIL: stranger read private orders/messages';
  end if;
  begin
    insert into public.messages(order_id, body)
    values (current_setting('moulat.test_order_a')::uuid, 'Unauthorized');
    raise exception 'FAIL: stranger sent an order message';
  exception when insufficient_privilege then null;
  end;
  begin
    insert into public.sellers(id, name, area) values (auth.uid(), 'Unauthorized', 'Test');
    raise exception 'FAIL: customer created a seller profile';
  exception when insufficient_privilege then null;
  end;
end;
$$;

-- Seller A sees only its order, can edit its meal, cannot edit the other seller's meal.
select set_config('request.jwt.claim.sub', '10000000-0000-0000-0000-000000000101', true);
do $$
declare v_rows integer;
begin
  if (select count(*) from public.orders) <> 1 or (select count(*) from public.messages) <> 1 then
    raise exception 'FAIL: seller participant access';
  end if;
  update public.meals set description = 'Allowed' where id = '10000000-0000-0000-0000-000000000301';
  get diagnostics v_rows = row_count;
  if v_rows <> 1 then raise exception 'FAIL: owner meal edit denied'; end if;
  update public.meals set description = 'Forbidden' where id = '10000000-0000-0000-0000-000000000302';
  get diagnostics v_rows = row_count;
  if v_rows <> 0 then raise exception 'FAIL: other seller meal edited'; end if;
  begin
    update public.sellers set rating = 5 where id = auth.uid();
    raise exception 'FAIL: seller edited derived rating';
  exception when insufficient_privilege then null;
  end;
  begin
    perform public.place_order(
      '[{"meal_id":"10000000-0000-0000-0000-000000000301","quantity":1}]',
      'pickup', '', 'Self order');
    raise exception 'FAIL: seller ordered their own meal';
  exception when invalid_parameter_value then null;
  end;
  if (public.advance_order(current_setting('moulat.test_order_a')::uuid)).status <> 'preparing' then
    raise exception 'FAIL: first state transition';
  end if;
  if (public.advance_order(current_setting('moulat.test_order_a')::uuid)).status <> 'ready' then
    raise exception 'FAIL: second state transition';
  end if;
  if (public.advance_order(current_setting('moulat.test_order_a')::uuid)).status <> 'delivered' then
    raise exception 'FAIL: third state transition';
  end if;
end;
$$;

select set_config('request.jwt.claim.sub', '10000000-0000-0000-0000-000000000201', true);
insert into public.reviews(order_id, seller_id, rating, comment)
values (current_setting('moulat.test_order_a')::uuid, '10000000-0000-0000-0000-000000000101', 4, 'Good');
do $$
begin
  if (select rating from public.sellers where id = '10000000-0000-0000-0000-000000000101') <> 4 then
    raise exception 'FAIL: rating did not reflect verified review';
  end if;
  begin
    insert into public.reviews(order_id, seller_id, rating)
    values (current_setting('moulat.test_order_a')::uuid, '10000000-0000-0000-0000-000000000101', 5);
    raise exception 'FAIL: duplicate review accepted';
  exception when unique_violation then null;
  end;
end;
$$;

reset role;
set local role anon;
select set_config('request.jwt.claim.sub', '', true);
do $$
begin
  if (select count(*) from public.sellers
    where id in ('10000000-0000-0000-0000-000000000101', '10000000-0000-0000-0000-000000000102')) <> 2 then
    raise exception 'FAIL: public catalog unavailable';
  end if;
  begin
    perform id from public.orders limit 1;
    raise exception 'FAIL: anonymous order access';
  exception when insufficient_privilege then null;
  end;
  begin
    perform public.place_order('[]', 'pickup', '', 'Guest');
    raise exception 'FAIL: anonymous checkout access';
  exception when insufficient_privilege then null;
  end;
end;
$$;

reset role;
rollback;
select 'PASS: database smoke test completed; fixtures rolled back' as result;
