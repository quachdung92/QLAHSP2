-- Nguồn = "Phục hồi điều tra" (vuan.nguon = 'phuc_hoi_dieu_tra') — thêm 2 field để tính "Hạn điều
-- tra" đúng theo Điều 174 khoản 1 BLHS 2025 (thời hạn điều tra TIẾP kể từ khi có QĐ phục hồi điều
-- tra, KHÁC bảng cơ bản Điều 172 khoản 1 vốn tính từ Ngày QĐ khởi tố VA). Trước đây "Nguồn = Phục
-- hồi điều tra" chỉ là 1 nhãn phân loại (1 trong 4 nguồn "Khởi tố mới" theo mẫu ngành B10), không có
-- chỗ ghi Số QĐ/Ngày phục hồi thật — nên "Hạn điều tra" của các vụ này luôn bị tính SAI (dùng nhầm
-- Điều 172.1 từ Ngày QĐ KTVA, dù thực tế vụ đã được phục hồi điều tra trước khi nhập vào hệ thống).
alter table "vuan" add column if not exists "soQdPhucHoiDieuTra" text;
alter table "vuan" add column if not exists "ngayPhucHoiDieuTra" timestamptz;

notify pgrst, 'reload schema';
