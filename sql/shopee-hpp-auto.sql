-- Jalankan setelah sql/shopee-hpp-items.sql.
-- Cocokkan otomatis hanya jika hasil UNIK dan pasti. Tidak menimpa pasangan manual.
create or replace function public.cocokkan_otomatis_hpp_shopee()
returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare v_matched integer:=0;v_pending integer:=0;
begin
 if auth.uid() is null or not exists(select 1 from public.profiles p where p.id=auth.uid() and lower(p.role)='owner') then
 raise exception 'Akses hanya Owner';end if;
 -- Pertama, pakai pasangan manual terdahulu untuk nama produk Shopee yang sama.
 with known as (
 select lower(trim(nama_produk_shopee)) k,min(produk_id) produk_id
 from public.shopee_item_produk where produk_id is not null
 group by lower(trim(nama_produk_shopee))
 having count(distinct produk_id)=1
 ), choices as (
 select i.id,k.produk_id from public.shopee_item_produk i join known k
 on lower(trim(i.nama_produk_shopee))=k.k
 where i.produk_id is null
 ), latest as (
 select distinct on (produk_id) produk_id,total_hpp from public.master_hpp_produk
 order by produk_id,berlaku_mulai desc,id desc
 ), upd as (
 update public.shopee_item_produk i set produk_id=c.produk_id,hpp_snapshot=h.total_hpp,updated_at=now()
 from choices c left join latest h on h.produk_id=c.produk_id where i.id=c.id
 returning i.id
 ) select count(*) into v_matched from upd;
 -- Kedua, SKU Shopee yang identik dengan SKU produk/variasi Kimonik.
 -- ID numerik Shopee tidak dianggap SKU Kimonik.
 with codes as (
 select upper(trim(sku)) code,id produk_id from public.master_produk where nullif(trim(sku),'') is not null
 union all
 select upper(trim(v.sku)),v.produk_id from public.master_produk_variasi v where nullif(trim(v.sku),'') is not null
 ), unique_codes as (
 select code,min(produk_id) produk_id from codes group by code having count(distinct produk_id)=1
 ), choices as (
 select i.id,c.produk_id from public.shopee_item_produk i join unique_codes c
 on upper(trim(i.sku_shopee))=c.code
 where i.produk_id is null and i.sku_shopee ~ '[A-Za-z]'
 ), latest as (
 select distinct on (produk_id) produk_id,total_hpp from public.master_hpp_produk
 order by produk_id,berlaku_mulai desc,id desc
 ), upd as (
 update public.shopee_item_produk i set produk_id=c.produk_id,hpp_snapshot=h.total_hpp,updated_at=now()
 from choices c left join latest h on h.produk_id=c.produk_id where i.id=c.id
 returning i.id
 ) select v_matched+count(*) into v_matched from upd;
 -- Ketiga, nama katalog / nama produk identik, setelah normalisasi spasi dan huruf.
 with names as (
 select lower(regexp_replace(trim(nama_produk),'\\s+',' ','g')) k,id produk_id
 from public.master_produk where nullif(trim(nama_produk),'') is not null
 union all
 select lower(regexp_replace(trim(nama_katalog),'\\s+',' ','g')),id
 from public.master_produk where nullif(trim(nama_katalog),'') is not null
 ), unique_names as (
 select k,min(produk_id) produk_id from names group by k having count(distinct produk_id)=1
 ), choices as (
 select i.id,n.produk_id from public.shopee_item_produk i join unique_names n
 on lower(regexp_replace(trim(i.nama_produk_shopee),'\\s+',' ','g'))=n.k
 where i.produk_id is null
 ), latest as (
 select distinct on (produk_id) produk_id,total_hpp from public.master_hpp_produk
 order by produk_id,berlaku_mulai desc,id desc
 ), upd as (
 update public.shopee_item_produk i set produk_id=c.produk_id,hpp_snapshot=h.total_hpp,updated_at=now()
 from choices c left join latest h on h.produk_id=c.produk_id where i.id=c.id
 returning i.id
 ) select v_matched+count(*) into v_matched from upd;
 select count(*) into v_pending from public.shopee_item_produk where produk_id is null or hpp_snapshot is null;
 return jsonb_build_object('otomatis_dicocokkan',v_matched,'belum_lengkap',v_pending);
end $$;
revoke all on function public.cocokkan_otomatis_hpp_shopee() from public;
grant execute on function public.cocokkan_otomatis_hpp_shopee() to authenticated;
