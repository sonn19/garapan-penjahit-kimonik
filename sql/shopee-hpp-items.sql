-- Jalankan satu kali di Supabase SQL Editor. Tidak menghapus invoice atau HPP lama.
create table if not exists public.shopee_item_produk (
 id bigint generated always as identity primary key,
 no_pesanan text not null references public.shopee_fee_pesanan(no_pesanan) on delete cascade,
 nama_produk_shopee text not null,
 sku_shopee text not null default '',
 jumlah integer not null default 1 check(jumlah>0),
 produk_id bigint references public.master_produk(id),
 hpp_snapshot numeric(14,2),
 updated_at timestamptz not null default now(),
 unique(no_pesanan,nama_produk_shopee,sku_shopee)
);
alter table public.shopee_item_produk enable row level security;
drop policy if exists "Owner read shopee items" on public.shopee_item_produk;
create policy "Owner read shopee items" on public.shopee_item_produk for select to authenticated
using(exists(select 1 from public.profiles p where p.id=auth.uid() and lower(p.role)='owner'));
revoke insert,update,delete on public.shopee_item_produk from anon,authenticated;
create or replace function public.simpan_item_shopee(p_items jsonb)
returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare v_count int;
begin
 if auth.uid() is null or not exists(select 1 from public.profiles where id=auth.uid() and lower(role)='owner') then raise exception 'Akses hanya Owner';end if;
 if jsonb_typeof(p_items) is distinct from 'array' or jsonb_array_length(p_items)>10000 then raise exception 'Format atau jumlah item tidak valid';end if;
 if exists(select 1 from jsonb_array_elements(p_items) x where length(trim(coalesce(x->>'no_pesanan','')))<5 or length(trim(coalesce(x->>'nama_produk_shopee','')))=0 or coalesce((x->>'jumlah')::integer,0)<1) then raise exception 'Item tidak valid';end if;
 with source as (
 select distinct on (trim(x->>'no_pesanan'),trim(x->>'nama_produk_shopee'),trim(coalesce(x->>'sku_shopee','')))
 trim(x->>'no_pesanan') no_pesanan,trim(x->>'nama_produk_shopee') nama_produk_shopee,
 trim(coalesce(x->>'sku_shopee','')) sku_shopee,(x->>'jumlah')::integer jumlah
 from jsonb_array_elements(p_items) x
 order by trim(x->>'no_pesanan'),trim(x->>'nama_produk_shopee'),trim(coalesce(x->>'sku_shopee',''))
 ), upserted as (
 insert into public.shopee_item_produk(no_pesanan,nama_produk_shopee,sku_shopee,jumlah)
 select s.no_pesanan,s.nama_produk_shopee,s.sku_shopee,s.jumlah from source s
 where exists(select 1 from public.shopee_fee_pesanan f where f.no_pesanan=s.no_pesanan)
 on conflict(no_pesanan,nama_produk_shopee,sku_shopee) do update set jumlah=excluded.jumlah,updated_at=now()
 returning id
 ) select count(*) into v_count from upserted;
 return jsonb_build_object('items_tersimpan',v_count);
end $$;
create or replace function public.pasangkan_item_shopee(p_item_id bigint,p_produk_id bigint)
returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare v_hpp numeric(14,2);v_id bigint;
begin
 if auth.uid() is null or not exists(select 1 from public.profiles where id=auth.uid() and lower(role)='owner') then raise exception 'Akses hanya Owner';end if;
 if p_produk_id is not null then
 if not exists(select 1 from public.master_produk where id=p_produk_id) then raise exception 'Produk tidak ditemukan';end if;
 select total_hpp into v_hpp from public.master_hpp_produk where produk_id=p_produk_id order by berlaku_mulai desc,id desc limit 1;
 end if;
 update public.shopee_item_produk set produk_id=p_produk_id,hpp_snapshot=v_hpp,updated_at=now()
 where id=p_item_id returning id into v_id;
 if v_id is null then raise exception 'Item tidak ditemukan';end if;
 return jsonb_build_object('id',v_id,'hpp_snapshot',v_hpp);
end $$;
revoke all on function public.simpan_item_shopee(jsonb) from public;
revoke all on function public.pasangkan_item_shopee(bigint,bigint) from public;
grant execute on function public.simpan_item_shopee(jsonb) to authenticated;
grant execute on function public.pasangkan_item_shopee(bigint,bigint) to authenticated;
