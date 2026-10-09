-- Thêm nguồn 'tach_vu_an' (vụ tách ra từ vụ khác) vào CHECK constraint vuan.nguon.
-- Code tachVuAn() ghi nguon='tach_vu_an' nhưng constraint cũ chỉ cho 4 giá trị => lỗi
-- 'violates check constraint "vuan_nguon_check"' khi Tách vụ án.
alter table "vuan" drop constraint if exists "vuan_nguon_check";
alter table "vuan" add constraint "vuan_nguon_check"
  check ("nguon" in ('an_khoi_to_moi','tin_bao_khoi_to_len','an_noi_khac_chuyen_den','phuc_hoi_dieu_tra','tach_vu_an'));

notify pgrst, 'reload schema';
