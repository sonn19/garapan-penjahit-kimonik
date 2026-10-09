-- Jalankan sekali di Supabase SQL Editor. Khusus owner Kimonik.
create table if not exists public.shopee_fee_pesanan (
  no_pesanan text primary key,
  biaya_platform numeric(14,2) not null default 0,
  biaya_gratis_ongkir numeric(14,2) not null default 0,
  biaya_layanan numeric(14,2) not null default 0,
  biaya_promosi numeric(14,2) not null default 0,
  biaya_lainnya numeric(14,2) not null default 0,
  tanggal_impor timestamptz not null default now(),
  imported_by uuid not null references auth.users(id)
);
create table if not exists public.shopee_import_batch (
  id bigint generated always as identity primary key,
  periode_awal date,
  periode_akhir date,
  nama_file text not null,
  total_pendapatan numeric(14,2),
  dana_dilepas numeric(14,2),
  jumlah_pesanan_baru integer not null default 0,
  dibuat_pada timestamptz not null default now(),
  imported_by uuid not null references auth.users(id)
);
alter table public.shopee_fee_pesanan enable row level security;
alter table public.shopee_import_batch enable row level security;
drop policy if exists shopee_fee_owner_select on public.shopee_fee_pesanan;
create policy shopee_fee_owner_select on public.shopee_fee_pesanan for select to authenticated using (exists(select 1 from public.profiles p where p.id=auth.uid() and lower(p.role)='owner'));
drop policy if exists shopee_batch_owner_select on public.shopee_import_batch;
create policy shopee_batch_owner_select on public.shopee_import_batch for select to authenticated using (exists(select 1 from public.profiles p where p.id=auth.uid() and lower(p.role)='owner'));
create or replace function public.simpan_import_shopee(
 p_nama_file text,p_awal date,p_akhir date,p_pendapatan numeric,p_dilepas numeric,p_pesanan jsonb
) returns jsonb language plpgsql security definer set search_path = public, pg_temp as $$
declare v_new int := 0; v_total int; v_batch bigint;
begin
 if auth.uid() is null or not exists(select 1 from public.profiles where id=auth.uid() and lower(role)='owner') then
   raise exception 'Akses hanya untuk Owner';
 end if;
 if p_nama_file is null or length(p_nama_file)>255 or p_pesanan is null or jsonb_typeof(p_pesanan)<>'array' then
   raise exception 'Format laporan tidak valid';
 end if;
 v_total := jsonb_array_length(p_pesanan);
 if v_total<1 or v_total>10000 then raise exception 'Jumlah pesanan tidak valid'; end if;
 if exists(select 1 from jsonb_array_elements(p_pesanan) x where length(trim(x->>'no_pesanan'))<5 or length(trim(x->>'no_pesanan'))>100) then
   raise exception 'Nomor pesanan tidak valid';
 end if;
 with inserted as (
 insert into public.shopee_fee_pesanan(no_pesanan,biaya_platform,biaya_gratis_ongkir,biaya_layanan,biaya_promosi,biaya_lainnya,imported_by)
 select trim(x->>'no_pesanan'),(x->>'biaya_platform')::numeric,(x->>'biaya_gratis_ongkir')::numeric,
 (x->>'biaya_layanan')::numeric,(x->>'biaya_promosi')::numeric,(x->>'biaya_lainnya')::numeric,auth.uid()
 from jsonb_array_elements(p_pesanan) x
 on conflict (no_pesanan) do nothing returning no_pesanan
 ) select count(*) into v_new from inserted;
 -- Ringkasan tidak diakumulasikan dari batch yang tumpang tindih; simpan hanya sebagai arsip laporan.
 insert into public.shopee_import_batch(periode_awal,periode_akhir,nama_file,total_pendapatan,dana_dilepas,jumlah_pesanan_baru,imported_by)
 values(p_awal,p_akhir,p_nama_file,p_pendapatan,p_dilepas,v_new,auth.uid()) returning id into v_batch;
 return jsonb_build_object('batch_id',v_batch,'pesanan_baru',v_new,'pesanan_dilewati',v_total-v_new);
end $$;
revoke all on function public.simpan_import_shopee(text,date,date,numeric,numeric,jsonb) from public;
grant execute on function public.simpan_import_shopee(text,date,date,numeric,numeric,jsonb) to authenticated;
grant select on public.shopee_fee_pesanan,public.shopee_import_batch to authenticated;
