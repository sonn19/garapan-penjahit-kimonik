-- Jalankan sekali di Supabase SQL Editor.
-- Mengisi hanya snapshot HPP Shopee yang masih NULL ketika Master HPP baru disimpan.
-- Snapshot lama tidak pernah ditimpa, dan pasangan produk tidak diubah.
create or replace function public.kimonik_sync_hpp_shopee_after_insert()
returns trigger
language plpgsql
security definer
set search_path=public,pg_temp
as $$
begin
 update public.shopee_item_produk
 set hpp_snapshot=new.total_hpp, updated_at=now()
 where produk_id=new.produk_id
   and hpp_snapshot is null
   and new.total_hpp is not null;
 return new;
end;
$$;
drop trigger if exists trg_kimonik_sync_hpp_shopee on public.master_hpp_produk;
create trigger trg_kimonik_sync_hpp_shopee
after insert on public.master_hpp_produk
for each row execute function public.kimonik_sync_hpp_shopee_after_insert();
-- Lengkapi item lama yang sudah cocok tetapi belum punya HPP,
-- menggunakan versi HPP paling baru untuk masing-masing produk.
with latest as (
 select distinct on (produk_id) produk_id,total_hpp
 from public.master_hpp_produk
 order by produk_id,berlaku_mulai desc,id desc
)
update public.shopee_item_produk i
set hpp_snapshot=l.total_hpp,updated_at=now()
from latest l
where i.produk_id=l.produk_id and i.hpp_snapshot is null and l.total_hpp is not null;
