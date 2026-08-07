-- ============================================================================
-- QLVA — Mở rộng CHECK constraint "loaiSuKien" trên "lichsuChuyenGiaiDoan" (2026-08-07)
--
-- BỐI CẢNH: "Thêm bị can" vào 1 vụ đã RỜI Điều tra (đang ở Truy tố/Xét xử) — theo yêu cầu Dũng,
-- nghiệp vụ thật chỉ thêm/tách bị can khi vụ CÒN Ở Điều tra, nhưng đôi khi sơ xuất thống kê khiến
-- vụ đã bị chuyển giai đoạn trước khi kịp nhập đủ bị can. Vẫn cần "Thêm bị can" ngay tại giai đoạn
-- hiện tại của vụ (không lùi cả vụ về ĐT), nhưng về THỐNG KÊ, bị can đó phải được tính đầy đủ như
-- đã đi qua đúng trình tự: mới khởi tố ĐT → kết thúc ĐT chuyển TT → (nếu vụ đang XX) kết thúc TT
-- chuyển XX — gộp hết vào ĐÚNG 1 kỳ thống kê cán bộ chọn lúc thêm.
--
-- Sự kiện log mới `bo_sung_bican_hoi_to` (bị-can-level, cùng hình dạng `bo_sung_bican` đã có) —
-- ThemBiCanForm ghi 1 BẢN GHI/GIAI ĐOẠN đã "đi qua" (luôn có denGiaiDoan=dieu_tra, thêm truy_to
-- nếu vụ đang ở truy_to/xet_xu, thêm xet_xu nếu vụ đang ở xet_xu), tất cả cùng 1 kyThongKe — để
-- tái dùng đúng pattern query "where kyThongKe==K, loaiSuKien==X, denGiaiDoan==gd" đã có sẵn cho
-- `bo_sung_bican` ở mọi nơi, không cần viết cách fetch mới. Xem CLAUDE.md mục tương ứng để biết
-- đầy đủ thiết kế + các cột B10/Biểu2/3 được cộng thêm.
--
-- Loại sự kiện MỚI, KHÔNG trùng 8 loại mà RPC "layTrangThaiVuTaiKy" lọc
-- (khoi_to_vu/tach_vu/chuyen_giai_doan/tra_ho_so/phuc_hoi/nhan_lai_chuyen_di/hoan_thanh/nhap_vu) —
-- không ảnh hưởng gì tới lớp "Tồn"/RPC hiện có (đã audit kỹ trước khi thiết kế).
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
    'nhan_lai_chuyen_di','bo_sung_bican','bo_sung_bican_hoi_to'
  ));

notify pgrst, 'reload schema';
