-- ⚠ LỖI THỜI (2026-08-28) — hàm này đã được ĐỊNH NGHĨA LẠI ở supabase/rpc_ton_ky_thong_nhat_2026-08-28.sql
-- (thống nhất tồn theo KỲ THỐNG KÊ, bỏ lọc theo ngayKhoiTo). File này giữ làm lịch sử, KHÔNG chạy lại.

-- ============================================================================
-- QLVA — Phase 1: RPC tính "vụ án đang tồn tại giai đoạn nào, TÍNH TỚI 1 KỲ BẤT KỲ K" bằng
-- query động trên toàn bộ lịch sử (lichsuChuyenGiaiDoan) — KHÔNG phụ thuộc snapshot/chốt kỳ
-- trước, KHÔNG cần kỳ nào đứng trước K phải "chốt". Xem CLAUDE.md mục "Chuyển hệ thống thống kê
-- 'tồn' từ snapshot-chốt-kỳ sang query động (as-of) qua RPC Postgres" để biết đầy đủ bối cảnh/
-- lý do (bug thật hôm nay: vụ mở kỳ 1, giải quyết ghi bù ở kỳ 7, các kỳ 2-6 sai vì phụ thuộc
-- chuỗi "kỳ trước phải chốt trước").
--
-- SECURITY INVOKER (mặc định, KHÔNG dùng DEFINER) — đã xác nhận qua rls.sql: mọi user
-- "authenticated" đã có quyền SELECT toàn bộ "lichsuChuyenGiaiDoan"/"kybaocao" qua policy
-- "authenticated_read_write", nên hàm chỉ SELECT này không cần chạy dưới quyền chủ sở hữu.
-- ============================================================================

-- Hỗ trợ đúng kiểu truy vấn "với 1 maVuAn, lấy nhanh mọi dòng theo thứ tự kỳ" — index hiện có
-- (maVuAn,thoiDiemGhi) không đủ vì DISTINCT ON cần lọc/nhóm theo maVuAn RỒI mới xếp theo kỳ.
create index if not exists "lichsuChuyenGiaiDoan_maVuAn_kyThongKe_idx"
  on "lichsuChuyenGiaiDoan" ("maVuAn","kyThongKe");

-- ----------------------------------------------------------------------------
-- layTrangThaiVuTaiKy(p_ky_id): với MỌI vụ từng chạm ít nhất 1 sự kiện đổi giai đoạn, trả về
-- trạng thái CUỐI CÙNG của vụ đó tính tới hết kỳ p_ky_id (bao gồm cả chính kỳ đó).
--
-- CHỈ 8/14 loaiSuKien thật sự đổi "vụ đang ở giai đoạn nào" — lọc rõ TRƯỚC khi xếp hạng, không
-- lấy nguyên dòng log mới nhất bất kể loại. 6 loại còn lại (khoi_to_bican/bo_sung_bican —
-- bị-can-level; giao_nhan_ho_so/sua_thong_tin — hành chính, cố ý KHÔNG tham gia kyThongKe theo
-- thiết kế; duoc_nhap_vu — annotation phía vụ ĐÍCH, không tự đổi giai đoạn CHÍNH vụ đó;
-- gia_han_dieu_tra — chỉ đổi hạn, không đổi giai đoạn) KHÔNG được coi là "trạng thái mới nhất",
-- nếu không 1 dòng "Giao nhận hồ sơ" ghi SAU "Hoàn thành" (rất hay xảy ra — nộp lưu trữ luôn diễn
-- ra sau khi vụ đã xong) sẽ thắng DISTINCT ON và bị tính nhầm là còn tồn.
--
-- Thứ tự xếp hạng: (1) theo KỲ — kybaocao.ngayBatDau, kỳ loai='luu_tru' LUÔN coi là SỚM NHẤT
-- (-infinity) vì bản chất là backfill dữ liệu cũ, không có vị trí thật trên trục thời gian báo
-- cáo (khớp thiết kế "Kỳ lưu trữ án cũ" đã có — sự kiện gán kỳ này không tính vào báo cáo tháng
-- nào, ở đây coi là "luôn thuộc quá khứ" so với bất kỳ kỳ thật nào); (2) trong CÙNG 1 kỳ, CHỈ dùng
-- "thoiDiemGhi" (thời điểm ghi log THẬT, NOT NULL default now()) — KHÔNG dùng "ngaySuKien" (ngày
-- quyết định tự khai) làm tiêu chí xếp hạng, dù ban đầu tưởng nó "đúng nghiệp vụ hơn".
--
-- **Bài học thật tìm được lúc kiểm chứng lần đầu (2026-08-05, đã thử VÀ SAI 2 lần trước khi ra bản
-- này)**: có những vụ mà "hoan_thanh" VÀ "khoi_to_vu" CÙNG ghi bởi 1 lượt dựng-lại-lịch-sử hàng
-- loạt (thoiDiemGhi giống hệt nhau tới milli-giây, cùng 1 transaction), nhưng "ngaySuKien" của
-- "hoan_thanh" (dữ liệu tự khai, có thể sai/thiếu nhất quán ở dữ liệu cũ) LẠI SỚM HƠN "khoi_to_vu"
-- — vô lý về logic (hoàn thành trước khi khởi tố) nhưng vẫn là dữ liệu đã lưu. Dùng ngaySuKien làm
-- BẤT KỲ tiêu chí xếp hạng nào (kể cả chỉ làm tiêu chí PHỤ sau thoiDiemGhi) đều khiến RPC chọn
-- nhầm "khoi_to_vu" là mới nhất, trong khi "vuan.trangThai" (nguồn live, không qua log) xác nhận
-- các vụ này ĐÃ hoàn thành từ lâu. Kết luận: ngaySuKien KHÔNG đáng tin để xếp hạng thứ tự sự kiện
-- ở hệ thống này (dữ liệu backfill/nhập bù rất phổ biến) — bỏ hẳn khỏi ORDER BY, chỉ dùng
-- thoiDiemGhi + tie-break thứ 3 (exit-wins) khi thoiDiemGhi cũng trùng.
--
-- Giới hạn ĐÃ BIẾT, không phải bug: sự kiện có kyThongKe IS NULL (dữ liệu cũ dựng lại lịch sử
-- chưa gán kỳ — xem CLAUDE.md mục "Cân đối số liệu") bị INNER JOIN loại thẳng, không tham gia kết
-- quả — vụ mà MỌI sự kiện đổi giai đoạn của nó đều thiếu kyThongKe sẽ không xuất hiện trong kết
-- quả (không tính tồn ở đâu cả). Đây là hành vi ĐÃ CÓ TỪ TRƯỚC (Cân đối số liệu hiện tại cũng loại
-- các dòng này khỏi mọi SUMIF theo kỳ) — bước "Data cleansing" (xem CLAUDE.md) phải chạy TRƯỚC khi
-- coi RPC này là nguồn số liệu chính thức, để không undercount vì thiếu gán kỳ.
--
-- CHỈ dùng cho p_ky_id là kỳ báo cáo THẬT (loai IS NULL) — gọi với 1 kỳ loai='luu_tru' (ngayBatDau
-- luôn NULL) sẽ khiến ky_dich.moc = NULL, mọi so sánh "<= NULL" ra NULL (không đúng), chỉ còn các
-- kỳ luu_tru khác được nhận — không có ý nghĩa nghiệp vụ, không cần xử lý riêng cho case này.
-- ----------------------------------------------------------------------------
create or replace function "layTrangThaiVuTaiKy"(p_ky_id text)
returns table (
  "maVuAn"         text,
  "dangTon"        boolean,
  "giaiDoan"       text,
  "loaiSuKienCuoi" text,
  "kyThongKe"      text,
  "moc"            timestamptz
)
language sql
stable
as $$
  with ky_dich as (
    select "ngayBatDau" as moc from "kybaocao" where "id" = p_ky_id
  ),
  ky_hop_le as (
    select
      k."id" as ky_id,
      case when k."loai" = 'luu_tru' then '-infinity'::timestamptz else k."ngayBatDau" end as ky_moc
    from "kybaocao" k, ky_dich
    where k."loai" = 'luu_tru' or k."ngayBatDau" <= ky_dich.moc
  ),
  log_loc as (
    select
      l."maVuAn",
      l."loaiSuKien",
      l."denGiaiDoan",
      l."kyThongKe",
      kh.ky_moc,
      l."thoiDiemGhi" as tie1
    from "lichsuChuyenGiaiDoan" l
    join ky_hop_le kh on kh.ky_id = l."kyThongKe"
    where l."loaiSuKien" in (
      'khoi_to_vu', 'tach_vu', 'chuyen_giai_doan', 'tra_ho_so',
      'phuc_hoi', 'nhan_lai_chuyen_di', 'hoan_thanh', 'nhap_vu'
    )
  ),
  moi_nhat as (
    select distinct on ("maVuAn")
      "maVuAn", "loaiSuKien", "denGiaiDoan", "kyThongKe", ky_moc
    from log_loc
    -- Tie-break thứ 2 (chỉ áp dụng khi CÙNG kỳ + CÙNG thoiDiemGhi hệt nhau — đúng case dựng-lại-
    -- lịch-sử hàng loạt vừa tìm được ở trên): ưu tiên sự kiện RA (hoan_thanh/nhap_vu) thắng — an
    -- toàn hơn ("giả định đã xong" khi không phân biệt được thứ tự thật, tránh tồn ảo), khớp đúng
    -- "vuan.trangThai" (nguồn live không qua log) của mọi trường hợp đã kiểm chứng trên dữ liệu thật.
    order by "maVuAn", ky_moc desc, tie1 desc,
      ("loaiSuKien" in ('hoan_thanh', 'nhap_vu')) desc
  )
  select
    "maVuAn",
    ("loaiSuKien" not in ('hoan_thanh', 'nhap_vu'))                                as "dangTon",
    case when "loaiSuKien" not in ('hoan_thanh', 'nhap_vu') then "denGiaiDoan" end as "giaiDoan",
    "loaiSuKien"                                                                  as "loaiSuKienCuoi",
    "kyThongKe",
    ky_moc                                                                        as "moc"
  from moi_nhat;
$$;

grant execute on function "layTrangThaiVuTaiKy"(text) to authenticated;
