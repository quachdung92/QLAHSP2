-- ============================================================================
-- 2026-09-29 (Dũng) — mở rộng quy tắc "bị can kỳ lưu trữ được tính lại" sang PHỤC HỒI / NHẬN LẠI
-- ============================================================================
-- Bối cảnh: vụ Nguyễn Quý Dương (QLVA_E01.53_2411_0115) khởi tố + tạm đình chỉ đều ở kỳ lưu trữ
-- "Án lưu 2026", rồi PHỤC HỒI điều tra thật ở kỳ 09/2026 → vụ tồn ĐT nhưng bị can bị loại (chỉ có
-- khoi_to_bican ở kỳ lưu trữ) → tồn cuối kỳ 09 lệch số thực tế 1 bị can.
-- Quy tắc: như huy_an_bican_luu_tru_2026-09-29.sql, thêm sự kiện phuc_hoi / nhan_lai_chuyen_di ở kỳ
-- THẬT cũng đưa bị can chỉ-khởi-tố-ở-kỳ-lưu-trữ của vụ vào thống kê từ kỳ đó. Khớp JS fetchKyKhoiToBiCan.
-- (Không đổi cột; thay thế định nghĩa hàm của file trước.)
-- ============================================================================

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
    where (l."loaiSuKien" = 'huy_dieu_tra_lai' and l."giuBiCanLuuTru" = false)
       or l."loaiSuKien" in ('phuc_hoi', 'nhan_lai_chuyen_di')
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
