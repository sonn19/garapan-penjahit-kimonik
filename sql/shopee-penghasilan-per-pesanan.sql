-- Jalankan di Supabase SQL Editor satu kali setelah sql/shopee-import.sql.
alter table public.shopee_fee_pesanan
 add column if not exists penghasilan_awal numeric(14,2),
 add column if not exists penghasilan_akhir numeric(14,2),
 add column if not exists pajak numeric(14,2),
 add column if not exists tanggal_dana_dilepas date;
create or replace function public.lengkapi_penghasilan_shopee(p_pesanan jsonb)
returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare v_updated int:=0;v_total int;
begin
 if auth.uid() is null or not exists(select 1 from public.profiles where id=auth.uid() and lower(role)='owner') then raise exception 'Akses hanya Owner';end if;
 if p_pesanan is null or jsonb_typeof(p_pesanan)<>'array' then raise exception 'Format tidak valid';end if;
 v_total:=jsonb_array_length(p_pesanan);
 if v_total<1 or v_total>10000 then raise exception 'Jumlah pesanan tidak valid';end if;
 if exists(select 1 from jsonb_array_elements(p_pesanan) x where length(trim(coalesce(x->>'no_pesanan','')))<5 or
 (x->>'penghasilan_awal')::numeric<0 or (x->>'penghasilan_akhir')::numeric<0) then raise exception 'Nomor pesanan atau nilai tidak valid';end if;
 with src as (
 select distinct on (trim(x->>'no_pesanan')) trim(x->>'no_pesanan') as no_pesanan,
 (x->>'penghasilan_awal')::numeric as awal,(x->>'penghasilan_akhir')::numeric as akhir,
 nullif(x->>'pajak','')::numeric as pajak,
 nullif(x->>'tanggal_dana_dilepas','')::date as tanggal
 from jsonb_array_elements(p_pesanan) x order by trim(x->>'no_pesanan')
 ), upd as (
 update public.shopee_fee_pesanan p set penghasilan_awal=s.awal,penghasilan_akhir=s.akhir,pajak=s.pajak,tanggal_dana_dilepas=s.tanggal
 from src s where p.no_pesanan=s.no_pesanan
 and (p.penghasilan_awal is distinct from s.awal or p.penghasilan_akhir is distinct from s.akhir or p.pajak is distinct from s.pajak or p.tanggal_dana_dilepas is distinct from s.tanggal)
 returning p.no_pesanan
 ) select count(*) into v_updated from upd;
 return jsonb_build_object('diperbarui',v_updated,'dikirim',v_total);
end $$;
revoke all on function public.lengkapi_penghasilan_shopee(jsonb) from public;
grant execute on function public.lengkapi_penghasilan_shopee(jsonb) to authenticated;
