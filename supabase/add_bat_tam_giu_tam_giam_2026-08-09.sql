-- ============================================================================
-- Biểu 2 — bổ sung thông tin bắt/tạm giữ/tạm giam cho bị can (2026-08-09, theo yêu cầu Dũng).
-- Đây là các FIELD ĐƠN (không phải sự kiện log) ghi nhận LẦN ĐẦU TIÊN phát sinh — không tính lại
-- khi gia hạn tạm giam (gia hạn chỉ sửa "hanTamGiam", không đụng các field này). Chỉ áp dụng khi
-- "bienPhapNganChan" khác "tai_ngoai" (đã bị bắt/tạm giữ/tạm giam), xem qlahs-sup.html.
-- ============================================================================

-- Mở rộng CHECK constraint "bienPhapNganChan" — thêm "tam_giu" (giữ nguyên "giam"=Tạm giam,
-- "tai_ngoai" như cũ, không đổi tên field/giá trị đã có để không phải sửa dữ liệu cũ). Tự tìm ĐÚNG
-- tên constraint hiện có qua pg_constraint thay vì đoán tên (Postgres tự đặt tên theo quy ước
-- "<bảng>_<cột>_check" khi không đặt tên tường minh lúc CREATE TABLE — không chắc chắn 100% nếu
-- bảng từng được tạo/sửa qua đường khác).
do $$
declare
  v_conname text;
begin
  select conname into v_conname
    from pg_constraint
    where conrelid = '"bican"'::regclass
      and contype = 'c'
      and pg_get_constraintdef(oid) ilike '%bienPhapNganChan%';
  if v_conname is not null then
    execute format('alter table "bican" drop constraint %I', v_conname);
  end if;
end $$;

alter table "bican" add constraint "bican_bienPhapNganChan_check"
  check ("bienPhapNganChan" in ('tai_ngoai', 'tam_giu', 'giam'));

-- Loại bắt (Biểu 2, dòng 4-8 "Trong đó") — trống = chưa rõ/không áp dụng.
alter table "bican" add column if not exists "loaiBat" text not null default ''
  check ("loaiBat" in ('', 'khan_cap', 'qua_tang', 'truy_na', 'dau_thu', 'tu_thu'));

-- Ngày bắt/tạm giữ/tạm giam lần đầu tiên (Biểu 2, dùng để xác định kỳ thống kê "Số người bị bắt").
alter table "bican" add column if not exists "ngayBat" timestamptz;

-- Nguồn gốc tạm giam (2026-08-09, SỬA LẠI theo phản hồi Dũng ngay sau khi thiết kế lần đầu) — quy
-- trình bình thường tạm giữ rồi chuyển tạm giam, HOẶC bắt tạm giam trực tiếp (không qua tạm giữ) —
-- chỉ có ý nghĩa khi "bienPhapNganChan" = 'giam'.
alter table "bican" add column if not exists "nguonGocTamGiam" text not null default ''
  check ("nguonGocTamGiam" in ('', 'tu_tam_giu', 'bat_truc_tiep'));

-- VKS không phê chuẩn — Dũng yêu cầu ĐƠN GIẢN thành 1 CỜ boolean (không cho chọn tay "loại lệnh"
-- dòng 10-12 qua dropdown, dễ rối) — loại lệnh tự SUY RA từ bienPhapNganChan+nguonGocTamGiam lúc
-- tính báo cáo (xem hàm `suyLoaiLenhKhongPheChuan` trong qlahs-sup.html), không lưu trực tiếp.
alter table "bican" add column if not exists "vksKhongPheChuan" boolean not null default false;

notify pgrst, 'reload schema';
