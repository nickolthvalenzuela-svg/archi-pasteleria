-- Ejecutar en SQL Editor como propietario. Sustituir el correo por una cuenta ya registrada y confirmada.
insert into public.admins(user_id)
select id from auth.users where email='CAMBIA_POR_TU_CORREO'
on conflict do nothing;
-- Debe aparecer exactamente la cuenta elegida:
select u.email from public.admins a join auth.users u on u.id=a.user_id;
