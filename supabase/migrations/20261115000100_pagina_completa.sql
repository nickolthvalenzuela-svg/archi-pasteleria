-- Actualización 2. Ejecutar después de 20261105000100_archi.sql, una sola vez.
begin;
alter table public.profiles add column birth_date date;
alter table public.products add column portions text not null default '',add column size_label text not null default '',add column ingredients text not null default '';
create table public.addresses(id bigint generated always as identity primary key,user_id uuid not null references auth.users on delete cascade,label text not null check(length(label) between 1 and 40),street text not null check(length(street) between 1 and 200),district text not null check(length(district) between 1 and 100),reference text not null default '');
create table public.payment_preferences(id bigint generated always as identity primary key,user_id uuid not null references auth.users on delete cascade,method text not null check(method in('efectivo','yape','tarjeta')),label text not null default '',last4 text not null default '',check((method='tarjeta' and last4 ~ '^[0-9]{4}$') or (method<>'tarjeta' and last4='')));
create table public.gallery(id bigint generated always as identity primary key,title text not null check(length(title) between 1 and 100),description text not null default '',image text not null check(image ~ '^https://'),position integer not null default 0 check(position between 0 and 9999),visible boolean not null default true);
create table public.shop_settings(id integer primary key check(id=1),shop_address text not null default '',hours text not null default '',phone text not null default '',yape_number text not null default '' check(yape_number='' or yape_number ~ '^[0-9]{9}$'),yape_owner text not null default '',delivery_enabled boolean not null default false,delivery_fee numeric(10,2) not null default 0 check(delivery_fee between 0 and 1000));
insert into public.shop_settings(id) values(1);
create table public.notifications(id bigint generated always as identity primary key,user_id uuid not null references auth.users on delete cascade,order_id bigint references public.orders on delete cascade,title text not null,body text not null,created_at timestamptz not null default now(),read_at timestamptz);
alter table public.orders add column delivery_mode text not null default 'pickup' check(delivery_mode in('pickup','delivery')),add column delivery_address text not null default '',add column payment_method text not null default 'efectivo' check(payment_method in('efectivo','yape')),add column note text not null default '',add column delivery_fee numeric(10,2) not null default 0,add column request_key uuid;
create unique index order_request_unique on public.orders(user_id,request_key) where request_key is not null;
alter table public.orders drop constraint orders_status_check;
alter table public.orders add constraint orders_status_check check(status in('pendiente','confirmado','preparando','listo','en_camino','entregado','cancelado'));
alter table public.addresses enable row level security;
alter table public.payment_preferences enable row level security;
alter table public.gallery enable row level security;
alter table public.shop_settings enable row level security;
alter table public.notifications enable row level security;
revoke all on public.addresses,public.payment_preferences,public.gallery,public.shop_settings,public.notifications from anon,authenticated;
grant select,insert,update,delete on public.addresses,public.payment_preferences to authenticated;
grant select on public.gallery,public.shop_settings to anon,authenticated;
grant insert,update,delete on public.gallery to authenticated;
grant update on public.shop_settings to authenticated;
grant select on public.notifications to authenticated;
grant update(read_at) on public.notifications to authenticated;
grant usage,select on sequence public.addresses_id_seq,public.payment_preferences_id_seq,public.gallery_id_seq to authenticated;
create policy addresses_own on public.addresses for all to authenticated using(user_id=auth.uid()) with check(user_id=auth.uid());
create policy payments_own on public.payment_preferences for all to authenticated using(user_id=auth.uid()) with check(user_id=auth.uid());
create policy gallery_view on public.gallery for select using(visible or public.is_admin());
create policy gallery_insert on public.gallery for insert to authenticated with check(public.is_admin());
create policy gallery_update on public.gallery for update to authenticated using(public.is_admin()) with check(public.is_admin());
create policy gallery_delete on public.gallery for delete to authenticated using(public.is_admin());
create policy shop_read on public.shop_settings for select using(true);
create policy shop_update on public.shop_settings for update to authenticated using(public.is_admin()) with check(public.is_admin());
create policy notifications_read on public.notifications for select to authenticated using(user_id=auth.uid());
create policy notifications_mark on public.notifications for update to authenticated using(user_id=auth.uid()) with check(user_id=auth.uid());
create index addresses_owner_idx on public.addresses(user_id);
create index notifications_owner_idx on public.notifications(user_id,created_at desc);
create index orders_owner_idx on public.orders(user_id,created_at desc);
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types) values('gallery','gallery',true,2097152,array['image/jpeg','image/png','image/webp']);
create policy gallery_upload on storage.objects for insert to authenticated with check(bucket_id='gallery' and public.is_admin() and (storage.foldername(name))[1]=auth.uid()::text);
-- Solo se publican imágenes del local. Nunca documentos de clientes.
-- Ocultar/eliminar una ficha no revoca una URL pública previamente compartida.
create function public.notify_order() returns trigger language plpgsql security definer set search_path='' as $$
begin
 if TG_OP='INSERT' then
  insert into public.notifications(user_id,order_id,title,body) values(new.user_id,new.id,'Recibimos tu pedido #A'||new.id,'Tu solicitud está pendiente de confirmación.');
 elsif old.status is distinct from new.status or old.paid is distinct from new.paid then
  insert into public.notifications(user_id,order_id,title,body) values(new.user_id,new.id,'Actualización del pedido #A'||new.id,'Estado: '||new.status||'. Pago: '||case when new.paid then 'validado' else 'pendiente de validación' end||'.');
 end if;
 return new;
end;$$;
revoke all on function public.notify_order() from public;
create trigger order_notification after insert or update of status,paid on public.orders for each row execute function public.notify_order();
create function public.checkout_order(lines jsonb,mode text,payment text,address_key bigint,customer_note text,request_key uuid) returns bigint language plpgsql security definer set search_path='' as $$
declare line jsonb;p public.products;a public.addresses;s public.shop_settings;qty integer;amount numeric:=0;fee numeric:=0;details jsonb:='[]';result bigint;dest text:='';actor uuid:=auth.uid();
begin
 if actor is null then raise exception 'Inicia sesión';end if;
 if request_key is null then raise exception 'Solicitud inválida';end if;
 perform pg_advisory_xact_lock(hashtextextended(actor::text||request_key::text,0));
 select o.id into result from public.orders o where o.user_id=actor and o.request_key=checkout_order.request_key;
 if result is not null then return result;end if;
 if lines is null or jsonb_typeof(lines)<>'array' then raise exception 'Carrito inválido';end if;
 if jsonb_array_length(lines) not between 1 and 50 then raise exception 'Carrito inválido';end if;
 if mode is null or mode not in('pickup','delivery') or payment is null or payment not in('efectivo','yape') then raise exception 'Entrega o pago inválido';end if;
 if length(coalesce(customer_note,''))>500 then raise exception 'La nota es muy larga';end if;
 select * into strict s from public.shop_settings where id=1;
 if payment='yape' and (s.yape_number='' or s.yape_owner='') then raise exception 'Yape no está disponible';end if;
 if mode='delivery' then
  if not s.delivery_enabled then raise exception 'Entrega a domicilio no disponible';end if;
  select * into a from public.addresses where id=address_key and user_id=actor;
  if not found then raise exception 'Dirección no válida';end if;
  dest:=concat_ws(', ',a.street,a.district,nullif(a.reference,''));fee:=s.delivery_fee;
 end if;
 -- No se aceptan precios, totales, estados o pagos validados desde el cliente.
 for line in select value from jsonb_array_elements(lines) loop
  if coalesce(line->>'quantity','') !~ '^[0-9]{1,2}$' or coalesce(line->>'product_id','') !~ '^[0-9]+$' then raise exception 'Producto o cantidad inválida';end if;
  qty:=(line->>'quantity')::integer;
  if qty not between 1 and 99 then raise exception 'Cantidad inválida';end if;
  select * into p from public.products where id=(line->>'product_id')::bigint and active for share;
  if not found then raise exception 'Producto no disponible';end if;
  amount:=amount+p.price*qty;
  details:=details||jsonb_build_array(jsonb_build_object('id',p.id,'name',p.name,'price',p.price,'quantity',qty));
 end loop;
 insert into public.orders(user_id,items,total,delivery_mode,delivery_address,payment_method,note,delivery_fee,request_key) values(actor,details,amount+fee,mode,dest,payment,coalesce(customer_note,''),fee,checkout_order.request_key) returning id into result;
 return result;
end;$$;
revoke all on function public.checkout_order(jsonb,text,text,bigint,text,uuid) from public;
grant execute on function public.checkout_order(jsonb,text,text,bigint,text,uuid) to authenticated;
-- La versión nueva usa checkout_order; el endpoint antiguo deja de estar expuesto.
revoke execute on function public.place_order(jsonb) from authenticated;
commit;
