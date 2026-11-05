-- Nguồn vụ án = "Huỷ điều tra lại" (vuan.nguon = 'huy_dieu_tra_lai') — nhập mới vụ cũ đã bị Toà cấp
-- trên huỷ để điều tra lại, kèm Số/Ngày QĐ huỷ. Sự kiện huy_dieu_tra_lai tạo cùng lúc có cờ
-- "huyKhiTaoVu" để báo cáo chia bị can theo Ngày KTBC so với Ngày QĐ huỷ. Chạy qua Session pooler
-- (xem supabase/README.md), BACKUP trước (gh workflow run backup-supabase.yml).

alter table "vuan" drop constraint if exists "vuan_nguon_check";
alter table "vuan" add constraint "vuan_nguon_check"
  check ("nguon" in ('an_khoi_to_moi','tin_bao_khoi_to_len','an_noi_khac_chuyen_den','phuc_hoi_dieu_tra','tach_vu_an','huy_dieu_tra_lai'));

alter table "vuan" add column if not exists "soQdHuyDieuTra" text;
alter table "vuan" add column if not exists "ngayHuyDieuTra" timestamptz;

alter table "lichsuChuyenGiaiDoan" add column if not exists "huyKhiTaoVu" boolean not null default false;

notify pgrst, 'reload schema';

-- Phục hồi điều tra (nhập mới): cờ để báo cáo chia bị can theo Ngày KTBC so với Ngày phục hồi.
alter table "lichsuChuyenGiaiDoan" add column if not exists "phucHoiKhiTaoVu" boolean not null default false;
notify pgrst, 'reload schema';
