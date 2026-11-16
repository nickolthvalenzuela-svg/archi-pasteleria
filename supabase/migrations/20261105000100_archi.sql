begin;
create table public.profiles(id uuid primary key references auth.users on delete cascade,full_name text not null default '',phone text not null default '',dni text not null default '' check(dni='' or dni ~ '^[0-9]{8}$'),address text not null default '',avatar_path text);
create table public.admins(user_id uuid primary key references auth.users on delete cascade);
create function public.is_admin() returns boolean language sql stable security definer set search_path='' as $$select exists(select 1 from public.admins where user_id=auth.uid());$$;
create function public.new_profile() returns trigger language plpgsql security definer set search_path='' as $$begin insert into public.profiles(id) values(new.id);return new;end;$$;
create trigger create_profile after insert on auth.users for each row execute function public.new_profile();
create table public.products(id bigint generated always as identity primary key,name text not null check(length(name) between 1 and 100),category text not null check(category in ('Panes','Pasteles','Postres','Galletas','Bebidas')),price numeric(10,2) not null check(price>0),description text not null default '',image text not null,active boolean not null default true);
create table public.favorites(user_id uuid references auth.users on delete cascade,product_id bigint references public.products on delete cascade,primary key(user_id,product_id));
create table public.orders(id bigint generated always as identity primary key,user_id uuid not null references auth.users,created_at timestamptz not null default now(),items jsonb not null,total numeric(12,2) not null check(total>0),status text not null default 'pendiente' check(status in('pendiente','confirmado','preparando','listo','entregado','cancelado')),paid boolean not null default false);
alter table public.profiles enable row level security;
alter table public.admins enable row level security;
alter table public.products enable row level security;
alter table public.favorites enable row level security;
alter table public.orders enable row level security;
revoke all on public.admins from anon,authenticated;
revoke all on public.profiles,public.products,public.favorites,public.orders from anon,authenticated;
grant select,update on public.profiles to authenticated;
grant select on public.products to anon,authenticated;
grant insert,update on public.products to authenticated;
grant select,insert,delete on public.favorites to authenticated;
grant select on public.orders to authenticated;
grant update(status,paid) on public.orders to authenticated;
grant usage,select on sequence public.products_id_seq to authenticated;
create policy profiles_read on public.profiles for select to authenticated using(id=auth.uid());
create policy profiles_edit on public.profiles for update to authenticated using(id=auth.uid()) with check(id=auth.uid());
create policy products_read on public.products for select using(active or public.is_admin());
create policy products_insert on public.products for insert to authenticated with check(public.is_admin());
create policy products_edit on public.products for update to authenticated using(public.is_admin()) with check(public.is_admin());
create policy favorites_own on public.favorites for all to authenticated using(user_id=auth.uid()) with check(user_id=auth.uid());
create policy orders_read on public.orders for select to authenticated using(user_id=auth.uid() or public.is_admin());
create policy orders_manage on public.orders for update to authenticated using(public.is_admin()) with check(public.is_admin());
create function public.place_order(lines jsonb) returns bigint language plpgsql security definer set search_path='' as $$
declare line jsonb;p public.products;qty integer;amount numeric:=0;details jsonb:='[]';result bigint;
begin
 if auth.uid() is null then raise exception 'Inicia sesión';end if;
 if jsonb_typeof(lines)<>'array' or jsonb_array_length(lines) not between 1 and 50 then raise exception 'Carrito inválido';end if;
 for line in select value from jsonb_array_elements(lines) loop
  if coalesce(line->>'quantity','') !~ '^[0-9]{1,2}$' then raise exception 'Cantidad inválida';end if;
  qty:=(line->>'quantity')::integer;
  if qty not between 1 and 99 then raise exception 'Cantidad inválida';end if;
  select * into p from public.products where id=(line->>'product_id')::bigint and active for share;
  if not found then raise exception 'Producto no disponible';end if;
  amount:=amount+p.price*qty;
  details:=details||jsonb_build_array(jsonb_build_object('id',p.id,'name',p.name,'price',p.price,'quantity',qty));
 end loop;
 insert into public.orders(user_id,items,total) values(auth.uid(),details,amount) returning id into result;
 return result;
end;$$;
revoke all on function public.new_profile() from public;
revoke all on function public.place_order(jsonb) from public;
grant execute on function public.place_order(jsonb) to authenticated;
revoke all on function public.is_admin() from public;
grant execute on function public.is_admin() to anon,authenticated;
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types) values('avatars','avatars',false,2097152,array['image/jpeg','image/png','image/webp']),('products','products',true,2097152,array['image/jpeg','image/png','image/webp']);
create policy avatar_read on storage.objects for select to authenticated using(bucket_id='avatars' and (storage.foldername(name))[1]=auth.uid()::text);
create policy avatar_upload on storage.objects for insert to authenticated with check(bucket_id='avatars' and (storage.foldername(name))[1]=auth.uid()::text);
create policy product_upload on storage.objects for insert to authenticated with check(bucket_id='products' and public.is_admin() and (storage.foldername(name))[1]=auth.uid()::text);
insert into public.products(name,category,price,image,description) values
('Torta de Chocolate','Pasteles',60,'img/torta_chocolate.png','Una torta para compartir en tus celebraciones.'),
('Torta de Fresa','Pasteles',65,'img/torta_fresa.png','Un detalle dulce para una ocasión especial.'),
('Pan Integral','Panes',2.50,'img/pan_integral.png','Para acompañar tus desayunos y lonches.'),
('Croissant','Panes',3.50,'img/croissant.png','Un clásico para disfrutar en cualquier momento.'),
('Cupcake','Postres',5,'img/cupcake.png','Una porción dulce para alegrar tu día.');
commit;
