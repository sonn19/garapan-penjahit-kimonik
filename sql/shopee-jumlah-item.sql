-- Jalankan sekali di Supabase SQL Editor. Hanya Owner dapat mengubah jumlah item.
create or replace function public.ubah_jumlah_item_shopee(p_item_id bigint,p_jumlah integer)
returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare v_count integer;
begin
 if auth.uid() is null or not exists(select 1 from public.profiles where id=auth.uid() and lower(role)='owner') then
  raise exception 'Hanya Owner';
 end if;
 if p_jumlah is null or p_jumlah < 1 or p_jumlah > 100000 then
  raise exception 'Jumlah harus bilangan bulat positif';
 end if;
 update public.shopee_item_produk set jumlah=p_jumlah,updated_at=now() where id=p_item_id;
 get diagnostics v_count=row_count;
 if v_count<>1 then raise exception 'Item tidak ditemukan';end if;
 return jsonb_build_object('id',p_item_id,'jumlah',p_jumlah);
end $$;
revoke all on function public.ubah_jumlah_item_shopee(bigint,integer) from public;
grant execute on function public.ubah_jumlah_item_shopee(bigint,integer) to authenticated;
