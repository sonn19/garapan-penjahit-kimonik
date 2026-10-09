-- Jalankan di Supabase SQL Editor. Status verifikasi Qty hanya dapat diubah Owner.
alter table public.shopee_item_produk add column if not exists qty_diverifikasi_pada timestamptz;
alter table public.shopee_item_produk add column if not exists qty_diverifikasi_oleh uuid references auth.users(id);
create or replace function public.verifikasi_qty_shopee(p_item_id bigint,p_verifikasi boolean default true)
returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare v_row public.shopee_item_produk%rowtype;
begin
 if auth.uid() is null or not exists(select 1 from public.profiles where id=auth.uid() and lower(role)='owner') then raise exception 'Hanya Owner'; end if;
 update public.shopee_item_produk
 set qty_diverifikasi_pada=case when p_verifikasi then now() else null end,
     qty_diverifikasi_oleh=case when p_verifikasi then auth.uid() else null end,
     updated_at=now()
 where id=p_item_id and jumlah>=1 returning * into v_row;
 if not found then raise exception 'Item tidak ditemukan atau Qty tidak valid'; end if;
 return jsonb_build_object('id',v_row.id,'qty_diverifikasi_pada',v_row.qty_diverifikasi_pada);
end $$;
revoke all on function public.verifikasi_qty_shopee(bigint,boolean) from public;
grant execute on function public.verifikasi_qty_shopee(bigint,boolean) to authenticated;
-- Saat Qty diedit, status verifikasi dibatalkan otomatis.
create or replace function public.reset_verifikasi_qty_shopee()
returns trigger language plpgsql set search_path=public,pg_temp as $$
begin
 if new.jumlah is distinct from old.jumlah then
   new.qty_diverifikasi_pada=null;
   new.qty_diverifikasi_oleh=null;
 end if;
 return new;
end $$;
drop trigger if exists trg_reset_verifikasi_qty_shopee on public.shopee_item_produk;
create trigger trg_reset_verifikasi_qty_shopee before update of jumlah on public.shopee_item_produk
for each row execute function public.reset_verifikasi_qty_shopee();
