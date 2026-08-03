-- ============================================================================
-- QLVA — Mở rộng CHECK constraint "loaiSuKien" trên "lichsuChuyenGiaiDoan" (2026-08-03)
--
-- BỐI CẢNH: sửa lỗ hổng thật đã tìm ra qua audit code (không phải giả thuyết) — "Thêm bị can" vào
-- 1 vụ ĐÃ CÓ SẴN (đã từng được tính "vào" 1 giai đoạn từ trước, VD lúc khởi tố vụ/chuyển giai
-- đoạn/trả hồ sơ...) KHÔNG hề ghi nhận thêm "vào" nào ở tầng thống kê VỤ-LEVEL (Tổng thụ lý
-- C3/C33/C60, sheet "Cân đối số liệu") — hệ thống vẫn hỏi "tính vào kỳ nào" khi thêm bị can, nhưng
-- câu trả lời đó CHỈ được dùng cho khối "Phân tích bị can mới khởi tố" (C7-C24, thống kê nhân khẩu
-- học), không hề cộng vào tổng Vụ/Bị can đang thụ lý. Hậu quả: khi vụ đó sau này RỜI giai đoạn
-- (chuyển đi/trả hồ sơ/hoàn thành), TOÀN BỘ bị can hiện có (kể cả người mới thêm) bị trừ "ra" —
-- trong khi chỉ có số ban đầu từng được cộng "vào" — gây tồn cuối kỳ hụt dần theo thời gian, không
-- tự sửa được. Kịch bản cụ thể phát hiện qua: vụ trả điều tra bổ sung có 4 bị can lúc trả, điều tra
-- bổ sung thêm 2 bị can rồi kết thúc điều tra lại với 6 bị can — nếu không tách riêng, "Tổng thụ
-- lý"/báo cáo gộp nhiều kỳ sẽ lệch âm thầm.
--
-- SỬA: ghi 1 sự kiện log mới `loaiSuKien="bo_sung_bican"` mỗi khi ThemBiCanForm thêm bị can vào vụ
-- đã tồn tại — CỘT NÀY có CHECK constraint cố định danh sách giá trị hợp lệ (không dùng native
-- ENUM, xem ghi chú đầu supabase/schema.sql), phải mở rộng trước khi ghi được, giống bài học đã
-- gặp ở "nhan_lai_chuyen_di" (xem add_nhan_lai_chuyen_di_2026-08-01.sql).
--
-- AN TOÀN: CHỈ nới lỏng CHECK constraint (thêm 1 giá trị được phép), không đụng dữ liệu/cột nào
-- có sẵn, không ảnh hưởng các dòng log hiện có.
--
-- CHẠY QUA Session pooler (xem supabase/README.md) hoặc Supabase Dashboard → SQL Editor (project
-- eutatszoaseixchvjbtg) TRƯỚC KHI merge/deploy nhánh này — nếu không, "Thêm bị can" sẽ lỗi
-- `violates check constraint "lichsuChuyenGiaiDoan_loaiSuKien_check"`, chặn đứng thao tác nghiệp vụ
-- hàng ngày của 4 cán bộ.
-- ============================================================================

alter table "lichsuChuyenGiaiDoan" drop constraint if exists "lichsuChuyenGiaiDoan_loaiSuKien_check";

alter table "lichsuChuyenGiaiDoan" add constraint "lichsuChuyenGiaiDoan_loaiSuKien_check"
  check ("loaiSuKien" in (
    'khoi_to_vu','khoi_to_bican','chuyen_giai_doan','tra_ho_so',
    'gia_han_dieu_tra','phuc_hoi','hoan_thanh','tach_vu','nhap_vu',
    'duoc_nhap_vu','giao_nhan_ho_so','sua_thong_tin',
    'nhan_lai_chuyen_di','bo_sung_bican'
  ));

notify pgrst, 'reload schema';
