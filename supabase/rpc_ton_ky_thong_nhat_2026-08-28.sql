-- ============================================================================
-- QLVA — Thống nhất công thức "tồn" HOÀN TOÀN theo KỲ THỐNG KÊ (2026-08-28)
--
-- THAY HẲN 2 file:
--   - rpc_tong_ke_dong_2026-08-05.sql        (layTrangThaiVuTaiKy)
--   - rpc_tong_ke_dong_phase2_bican_2026-08-05.sql  (layTrangThaiBiCanTaiKy)
-- (2 file cũ giữ lại làm lịch sử — KHÔNG chạy lại chúng nữa, chạy file NÀY là bản hiện hành.)
--
-- Theo yêu cầu trực tiếp của Dũng: "tất cả công thức phải base on kỳ thống kê. Nếu không phát sinh
-- xử lý ở kỳ thống kê thì phải tính là tồn. Cách tính tồn theo ngayKhoiTo <= ngày chốt kỳ là TÀN
-- DƯ của hệ thống Firebase. Loại bỏ tàn dư." + "tất cả bị can, vụ án đều đã được gán kỳ rồi, trừ
-- các bị can tôi cố ý cho vào kỳ lưu trữ (hợp thức số liệu / bổ sung vụ thiếu, KHÔNG muốn tính
-- thống kê — phục vụ lưu trữ về sau)".
--
-- 2 THAY ĐỔI CỐT LÕI so với bản 2026-08-05:
--  1. layTrangThaiVuTaiKy: sự kiện gán vào kỳ `loai='luu_tru'` bị LOẠI HẲN khỏi xếp hạng (trước
--     đây coi là -infinity = "luôn thuộc quá khứ" nên vẫn tính). Vụ mà MỌI sự kiện đổi giai đoạn
--     đều ở kỳ lưu trữ → không xuất hiện trong kết quả (không tính tồn ở đâu). Vụ có ≥1 sự kiện ở
--     kỳ THẬT (VD lưu trữ rồi phục hồi thật) → chỉ các sự kiện kỳ thật quyết định trạng thái.
--     Kiểm chứng trên dữ liệu thật 2026-08-28: 0 tác động (mọi vụ lưu trữ đều khởi tố + hoàn thành
--     cùng trong kỳ lưu trữ → net 0 dù tính kiểu nào; đúng 1 vụ QLVA_E01.53_2511_0018 lưu trữ rồi
--     phục hồi thật kỳ 08/2026 → vẫn tồn Điều tra, đúng).
--  2. layTrangThaiBiCanTaiKy: BỎ HẲN điều kiện `bican.ngayKhoiTo <= ngày chốt kỳ` (tàn dư Firebase).
--     Bị can tồn tính tới hết kỳ K = vụ của họ đang tồn ở K VÀ họ có sự kiện `khoi_to_bican` gán
--     vào 1 kỳ THẬT (loai IS NULL) có thứ tự thời gian ≤ K. Bị can chỉ có khởi tố ở kỳ lưu trữ,
--     hoặc khởi tố ở kỳ thật SAU K → không tính tồn ở K.
--     Kiểm chứng trên dữ liệu thật 2026-08-28: Điều tra–Bị can kỳ 06/2026 741→736, kỳ 07/2026
--     813→811; Truy tố/Xét xử và toàn bộ số VỤ: không đổi ở kỳ nào. Đúng nhóm bị can thêm vào vụ
--     Điều tra đã có, ngày khởi tố sớm nhưng sự kiện gán kỳ 07/08 → thuộc kỳ 07/08, không phải 06.
--
-- Bị can KHÔNG có sự kiện `khoi_to_bican` ở bất kỳ kỳ thật nào (data hole) → KHÔNG tính (strict).
-- Đây là ranh giới CÓ CHỦ Ý: "kỳ thống kê là căn cứ duy nhất" (Dũng). Thiếu gán kỳ là việc VỆ SINH
-- DỮ LIỆU (gán kỳ cho bị can đó), KHÔNG phải việc sửa công thức. Sai lệch kiểu này tự lộ ra ở sheet
-- "Cân đối số liệu" (Chênh lệch ≠ 0) — đúng vai trò lưới an toàn. Dữ liệu thật 2026-08-28: 3757
-- bị can / 3757 sự kiện khoi_to_bican / 0 kyThongKe rỗng → không có case này.
--
-- SECURITY INVOKER (mặc định) — mọi user "authenticated" đã có quyền SELECT lichsuChuyenGiaiDoan/
-- kybaocao/bican qua policy "authenticated_read_write" (xem rls.sql).
-- ============================================================================

-- ----------------------------------------------------------------------------
-- layTrangThaiVuTaiKy(p_ky_id): trạng thái CUỐI CÙNG của mỗi vụ (từng có ≥1 sự kiện đổi giai đoạn
-- ở kỳ THẬT) tính tới hết kỳ p_ky_id.
--
-- CHỈ 8/14 loaiSuKien thật sự đổi "vụ đang ở giai đoạn nào" — lọc rõ TRƯỚC khi xếp hạng.
-- Xếp hạng: (1) theo KỲ (kybaocao.ngayBatDau — kỳ lưu trữ đã bị loại ở ky_hop_le); (2) trong CÙNG
-- kỳ chỉ dùng "thoiDiemGhi" (KHÔNG dùng "ngaySuKien" — dữ liệu backfill/nhập bù có ngaySuKien tự
-- khai sai thứ tự, xem bài học ở file 2026-08-05); (3) khi thoiDiemGhi trùng hệt: sự kiện RA
-- (hoan_thanh/nhap_vu) thắng (an toàn hơn, tránh tồn ảo).
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
  -- Kỳ hợp lệ để tính: CHỈ kỳ THẬT (loai IS NULL) có ngayBatDau <= kỳ đích. Kỳ lưu trữ bị loại hẳn.
  ky_hop_le as (
    select k."id" as ky_id, k."ngayBatDau" as ky_moc
    from "kybaocao" k, ky_dich
    where k."loai" is null and k."ngayBatDau" <= ky_dich.moc
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

-- ----------------------------------------------------------------------------
-- layTrangThaiBiCanTaiKy(p_ky_id): bị can nào tồn (thuộc giai đoạn của vụ họ) tính tới hết kỳ K.
-- = vụ đang tồn ở K (layTrangThaiVuTaiKy) ∩ bị can có sự kiện khoi_to_bican ở kỳ THẬT thứ tự ≤ K.
-- ----------------------------------------------------------------------------
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
  bc_da_khoi_to as (
    select distinct l."maBiCan"
    from "lichsuChuyenGiaiDoan" l
    join ky_hop_le kh on kh.ky_id = l."kyThongKe"
    where l."loaiSuKien" = 'khoi_to_bican'
  )
  select
    b."id"      as "maBiCan",
    b."maVuAn",
    vt."giaiDoan"
  from "bican" b
  join vu_ton vt        on vt."maVuAn" = b."maVuAn"
  join bc_da_khoi_to kt on kt."maBiCan" = b."id";
$$;

grant execute on function "layTrangThaiBiCanTaiKy"(text) to authenticated;
