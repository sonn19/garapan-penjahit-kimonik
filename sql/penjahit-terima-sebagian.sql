-- Jalankan sekali di Supabase SQL Editor sebelum memakai tombol Terima Sebagian.
-- Memakai status Disetujui dengan jumlah_diajukan = jumlah diterima.
-- Sisa cacat kembali menjadi kuota garapan yang bisa disetor ulang.
create or replace function public.terima_sebagian_setoran(p_setoran_id bigint,p_jumlah_diterima integer)
returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare v_s public.garapan_setoran%rowtype; v_g public.garapan_penjahit%rowtype;
declare v_total integer; v_awal integer;
begin
 if auth.uid() is null or not exists(select 1 from public.profiles where id=auth.uid() and lower(role) in ('admin','owner')) then
   raise exception 'Hanya Admin/Owner';
 end if;
 select * into v_s from public.garapan_setoran where id=p_setoran_id for update;
 if not found or v_s.status<>'Menunggu' then raise exception 'Setoran tidak ditemukan atau sudah diproses'; end if;
 v_awal:=v_s.jumlah_diajukan;
 if p_jumlah_diterima is null or p_jumlah_diterima<1 or p_jumlah_diterima>=v_awal then raise exception 'Jumlah diterima harus antara 1 dan jumlah setoran dikurangi 1'; end if;
 select * into v_g from public.garapan_penjahit where id=v_s.garapan_id for update;
 if not found then raise exception 'Garapan tidak ditemukan'; end if;
 v_total:=coalesce(v_g.jumlah_selesai,0)+p_jumlah_diterima;
 if v_total>v_g.jumlah then raise exception 'Jumlah diterima melebihi order'; end if;
 update public.garapan_penjahit set jumlah_selesai=v_total,status=case when v_total>=jumlah then 'Selesai' else 'Diproses' end,updated_at=now() where id=v_g.id;
 insert into public.garapan_progress(garapan_id,tambahan_selesai) values(v_g.id,p_jumlah_diterima);
 update public.garapan_setoran set jumlah_diajukan=p_jumlah_diterima,status='Disetujui',approved_by=auth.uid(),approved_at=now() where id=v_s.id;
 return jsonb_build_object('diterima',p_jumlah_diterima,'perbaikan',v_awal-p_jumlah_diterima,'garapan_id',v_g.id);
end $$;
revoke all on function public.terima_sebagian_setoran(bigint,integer) from public;
grant execute on function public.terima_sebagian_setoran(bigint,integer) to authenticated;
