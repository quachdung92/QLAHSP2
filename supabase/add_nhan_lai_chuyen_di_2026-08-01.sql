-- ============================================================================
-- QLVA — Mở rộng CHECK constraint "loaiSuKien" trên "lichsuChuyenGiaiDoan" (2026-08-01)
--
-- BỐI CẢNH: tính năng mới "Nhận lại vụ đã Chuyển đi" (NhanLaiChuyenDiModal, qlahs-sup.html) ghi
-- 1 sự kiện log mới loaiSuKien="nhan_lai_chuyen_di" — CỘT NÀY có CHECK constraint cố định danh
-- sách giá trị hợp lệ (không dùng native ENUM, xem ghi chú đầu supabase/schema.sql). Phát hiện
-- THẬT qua kiểm chứng bằng UI thật trên production: bấm "Xác nhận" ở modal mới báo lỗi
-- `new row for relation "lichsuChuyenGiaiDoan" violates check constraint
-- "lichsuChuyenGiaiDoan_loaiSuKien_check"` — đúng loại lỗi PHẢI mở rộng CHECK constraint trước khi
-- dùng được trên dữ liệu thật (khác lỗi "column not found" đã gặp nhiều lần với các cột mới khác —
-- ở đây CỘT đã tồn tại sẵn từ đầu (loaiSuKien/denGiaiDoan chung 1 bảng dùng cho mọi sự kiện), chỉ
-- riêng GIÁ TRỊ CHO PHÉP là chưa đủ).
--
-- AN TOÀN: CHỈ nới lỏng CHECK constraint (thêm 1 giá trị được phép), không đụng dữ liệu/cột nào
-- có sẵn, không ảnh hưởng các dòng log hiện có.
--
-- CHẠY QUA Session pooler (xem supabase/README.md) hoặc Supabase Dashboard → SQL Editor (project
-- eutatszoaseixchvjbtg).
-- ============================================================================

alter table "lichsuChuyenGiaiDoan" drop constraint if exists "lichsuChuyenGiaiDoan_loaiSuKien_check";

alter table "lichsuChuyenGiaiDoan" add constraint "lichsuChuyenGiaiDoan_loaiSuKien_check"
  check ("loaiSuKien" in (
    'khoi_to_vu','khoi_to_bican','chuyen_giai_doan','tra_ho_so',
    'gia_han_dieu_tra','phuc_hoi','hoan_thanh','tach_vu','nhap_vu',
    'duoc_nhap_vu','giao_nhan_ho_so','sua_thong_tin',
    'nhan_lai_chuyen_di'
  ));

notify pgrst, 'reload schema';
