-- Jalankan di Supabase SQL Editor sekali. Tidak menimpa snapshot HPP yang sudah ada.
create or replace function public.lengkapi_hpp_shopee()
returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare v_updated integer;
begin
 if auth.uid() is null or not exists (select 1 from public.profiles where id=auth.uid() and lower(role)='owner') then
  raise exception 'Akses hanya Owner';
 end if;
 with latest as (
  select distinct on (produk_id) produk_id,total_hpp
  from public.master_hpp_produk
  order by produk_id,berlaku_mulai desc,id desc
 ), changed as (
  update public.shopee_item_produk i
  set hpp_snapshot=l.total_hpp,updated_at=now()
  from latest l
  where i.produk_id=l.produk_id and i.hpp_snapshot is null and l.total_hpp is not null
  returning i.id
 )
 select count(*) into v_updated from changed;
 return jsonb_build_object('hpp_dilengkapi',v_updated,
  'belum_ada_hpp',(select count(*) from public.shopee_item_produk where hpp_snapshot is null));
end $$;
revoke all on function public.lengkapi_hpp_shopee() from public;
grant execute on function public.lengkapi_hpp_shopee() to authenticated;
