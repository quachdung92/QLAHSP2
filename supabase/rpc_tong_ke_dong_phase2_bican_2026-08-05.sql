-- ============================================================================
-- QLVA — Phase 2: RPC tính "bị can nào tồn tại, thuộc vụ nào, giai đoạn nào — TÍNH TỚI 1 KỲ K"
-- — thay thế toàn bộ nỗ lực vá tay `bcKyKhoiToMap`/`vuKyKhoiToMap`/`locBiCanTheoCutoff`/
-- bổ sung-tồn trong `qlahs-sup.html` hôm nay (xem CLAUDE.md). Xây trên `layTrangThaiVuTaiKy`
-- (phase 1) — vụ nào KHÔNG tồn thì bị can của nó cũng không tồn, không cần tính lại.
--
-- **Bài học quan trọng, đã THỬ SAI 1 LẦN trước khi ra bản đúng (kiểm chứng lần đầu, 2026-08-05)**:
-- bản đầu tiên dùng CÙNG cơ chế với vụ-level — so `kyThongKe` của sự kiện "khoi_to_bican" với tập
-- kỳ hợp lệ (≤ K). Kiểm chứng trên kỳ 06/2026 (đã chốt) ra 736 thay vì 738 (con số ĐÃ ĐƯỢC DŨNG XÁC
-- NHẬN đúng trong ngày, qua công cụ `taiTaoTonCuoiKyTheoTDTatCa`). Đào sâu: có bị can (VD "Trần
-- Hùng") có `ngayKhoiTo` = 28/06/2026 (TRƯỚC ngày chốt kỳ06 29/06/2026 — nên VỀ MẶT TỒN TẠI, họ đã
-- có mặt khi kỳ06 kết thúc) nhưng sự kiện `khoi_to_bican` của họ lại gắn `kyThongKe` = kỳ07 (quyết
-- định HÀNH CHÍNH riêng — tính "mới" của họ vào báo cáo FLOW kỳ07, không nhất thiết trùng với thời
-- điểm THẬT họ có mặt). Kết luận: `kyThongKe` trên `khoi_to_bican` chỉ trả lời đúng câu hỏi FLOW
-- ("tính vào báo cáo 'mới' của kỳ nào" — quyết định của cán bộ, có thể khác ngày thật), KHÔNG phải
-- câu hỏi STOCK ("bị can này đã tồn tại tính tới thời điểm này chưa" — phải theo NGÀY THẬT).
-- Đổi hẳn sang so sánh trực tiếp `bican.ngayKhoiTo` với NGÀY KẾT THÚC của kỳ K (không cần đọc
-- `lichsuChuyenGiaiDoan`/`khoi_to_bican` nữa) — khớp ĐÚNG cách hàm JS `locBiCanTheoCutoff` (đã có
-- sẵn, dùng ở nhiều nơi khác) vẫn luôn làm, và tái tạo ĐÚNG 738 khi kiểm chứng lại.
--
-- Ngày kết thúc kỳ K = "ngayChot" nếu đã chốt; nếu chưa chốt (đang mở), dùng "ngayBatDau" của kỳ
-- THẬT (loai IS NULL) kế tiếp GẦN NHẤT nếu đã tồn tại (kỳ sau đã mở thì coi kỳ này đã "khép" tại
-- đó); nếu là kỳ mở gần đây nhất (chưa có kỳ nào sau), dùng NOW() — phản ánh đúng trạng thái sống
-- của kỳ đang mở, khớp tinh thần "kỳ nào cũng ra số ngay" của cả thiết kế này.
--
-- Bị can thiếu "ngayKhoiTo" (dữ liệu cũ/thiếu) MẶC ĐỊNH COI LÀ ĐÃ CÓ TỪ ĐẦU (không loại) — ưu tiên
-- KHÔNG UNDERCOUNT hơn loại bỏ khi thiếu bằng chứng, cùng triết lý với `layTrangThaiVuTaiKy`.
--
-- GIỚI HẠN ĐÃ BIẾT, CHƯA XỬ LÝ (không phải bug, là ranh giới phạm vi phase 2) — chung với hạn chế
-- CÓ SẴN của toàn hệ thống (bican.maVuAn là 1 con trỏ SỐNG duy nhất, không phải lịch sử):
-- 1. Nhập vụ: bị can vụ nguồn bị đổi maVuAn sang vụ đích NGAY LÚC NHẬP — với kỳ K TRƯỚC thời điểm
--    nhập, RPC vẫn tính bị can đó thuộc vụ ĐÍCH (vì maVuAn hiện tại trỏ vậy), dù thực tế lúc đó họ
--    còn thuộc vụ NGUỒN. Muốn đúng tuyệt đối cần dò lại `biCanSnapshot` của sự kiện `nhap_vu` — để
--    dành cho lần mở rộng sau nếu cần truy hồi kỳ TRƯỚC các lần nhập vụ.
-- 2. Tách vụ: tương tự, bị can "chuyển hẳn" sang vụ mới có maVuAn trỏ vụ mới ngay — kỳ K trước lúc
--    tách sẽ tính nhầm họ thuộc vụ mới thay vì vụ gốc.
-- Cả 2 giới hạn này CHỈ ảnh hưởng khi xem lại 1 kỳ CŨ hơn thời điểm Nhập/Tách vụ diễn ra — không
-- ảnh hưởng gì tới kỳ hiện tại/tương lai (trường hợp dùng nhiều nhất).
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
  with vu_ton as (
    select "maVuAn", "giaiDoan" from "layTrangThaiVuTaiKy"(p_ky_id) where "dangTon" = true
  ),
  ky_dich as (
    select "ngayBatDau", "ngayChot" from "kybaocao" where "id" = p_ky_id
  ),
  ky_cutoff as (
    select coalesce(
      kd."ngayChot",
      (select min(k2."ngayBatDau") from "kybaocao" k2
       where k2."loai" is null and k2."ngayBatDau" > kd."ngayBatDau"),
      now()
    ) as moc
    from ky_dich kd
  )
  select
    b."id" as "maBiCan",
    b."maVuAn",
    vt."giaiDoan"
  from "bican" b
  join vu_ton vt on vt."maVuAn" = b."maVuAn"
  cross join ky_cutoff
  where b."ngayKhoiTo" <= ky_cutoff.moc or b."ngayKhoiTo" is null;
$$;

grant execute on function "layTrangThaiBiCanTaiKy"(text) to authenticated;
