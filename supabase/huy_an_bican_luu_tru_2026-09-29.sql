-- ============================================================================
-- 2026-09-29 (Dũng) — "Huỷ án — điều tra lại": bị can cũ nằm ở KỲ LƯU TRỮ được tính lại vào thống kê
-- ============================================================================
-- Bối cảnh: 2 vụ Oh Hyun June / Dương Thanh Hải (nhập bù án cũ vào kỳ lưu trữ "Án lưu 2026") bị huỷ
-- án để điều tra lại ở kỳ 09/2026. Bị can của 2 vụ chỉ có sự kiện khoi_to_bican ở kỳ lưu trữ nên
-- bị LOẠI khỏi mọi số bị can (D65 Biểu 2 + tồn bị can Điều tra) dù thực tế đã quay lại điều tra.
--
-- Quy tắc mới: sự kiện huy_dieu_tra_lai ở 1 kỳ THẬT, KHÔNG tick "Giữ bị can hiện có ở kỳ lưu trữ"
-- (cột mới giuBiCanLuuTru = false, mặc định) ⇒ bị can của vụ đó CHỈ khởi tố ở kỳ lưu trữ (không có
-- khoi_to_bican ở kỳ thật nào) được coi như vào thống kê TỪ kỳ huỷ án đó. Bị can khởi tố ở kỳ thật
-- (kể cả khởi tố thêm sau khi huỷ) giữ nguyên quy tắc cũ. Phải khớp JS fetchKyKhoiToBiCan.
-- ============================================================================

alter table "lichsuChuyenGiaiDoan" add column if not exists "giuBiCanLuuTru" boolean not null default false;

create or replace function "layTrangThaiBiCanTaiKy"(p_ky_id text)
returns table (
  "maBiCan"  text,
  "maVuAn"   text,
  "giaiDoan" text
)
language sql
stable
as $$
  with ky_dich as (
    select "ngayBatDau" as moc from "kybaocao" where "id" = p_ky_id
  ),
  ky_hop_le as (
    select k."id" as ky_id
    from "kybaocao" k, ky_dich
    where k."loai" is null and k."ngayBatDau" <= ky_dich.moc
  ),
  vu_ton as (
    select "maVuAn", "giaiDoan"
    from "layTrangThaiVuTaiKy"(p_ky_id)
    where "dangTon" = true
  ),
  bc_ky_that as (
    select distinct l."maBiCan"
    from "lichsuChuyenGiaiDoan" l
    join "kybaocao" k on k."id" = l."kyThongKe" and k."loai" is null
    where l."loaiSuKien" = 'khoi_to_bican'
  ),
  bc_da_khoi_to as (
    select distinct l."maBiCan"
    from "lichsuChuyenGiaiDoan" l
    join ky_hop_le kh on kh.ky_id = l."kyThongKe"
    where l."loaiSuKien" = 'khoi_to_bican'
  ),
  vu_huy_tinh_lai as (
    select distinct l."maVuAn"
    from "lichsuChuyenGiaiDoan" l
    join ky_hop_le kh on kh.ky_id = l."kyThongKe"
    where l."loaiSuKien" = 'huy_dieu_tra_lai' and l."giuBiCanLuuTru" = false
  ),
  bc_tinh as (
    select "maBiCan" from bc_da_khoi_to
    union
    select b."id"
    from "bican" b
    join vu_huy_tinh_lai h on h."maVuAn" = b."maVuAn"
    where b."id" not in (select "maBiCan" from bc_ky_that where "maBiCan" is not null)
      and exists (select 1 from "lichsuChuyenGiaiDoan" l2
                  where l2."maBiCan" = b."id" and l2."loaiSuKien" = 'khoi_to_bican')
  )
  select
    b."id"      as "maBiCan",
    b."maVuAn",
    vt."giaiDoan"
  from "bican" b
  join vu_ton vt on vt."maVuAn" = b."maVuAn"
  join bc_tinh kt on kt."maBiCan" = b."id";
$$;

grant execute on function "layTrangThaiBiCanTaiKy"(text) to authenticated;

notify pgrst, 'reload schema';
