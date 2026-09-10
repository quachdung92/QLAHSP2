-- ============================================================================
-- QLVA — Trường hợp mới "Huỷ án — điều tra lại" (2026-09-10)
--
-- BỐI CẢNH: tính năng mới HuyDieuTraLaiModal (qlahs-sup.html) — 1 vụ đã có KẾT QUẢ giải quyết
-- (đã xét xử / chuyển đi / đình chỉ / án huỷ) bị Toà án cấp trên (giám đốc thẩm / tái thẩm) HUỶ
-- bản án/quyết định ĐỂ ĐIỀU TRA LẠI. Vụ quay LẠI hệ thống ở giai đoạn ĐIỀU TRA (luôn cố định —
-- đúng nghĩa "điều tra lại"). Ghi 1 sự kiện log MỚI loaiSuKien="huy_dieu_tra_lai"
-- (denGiaiDoan="dieu_tra", tuGiaiDoan = giai đoạn vụ đang có lúc bị huỷ).
--
-- KHÁC:
--  - PhucHoiModal (phuc_hoi): chỉ áp dụng vụ ĐANG Tạm đình chỉ, về đúng giai đoạn cũ.
--  - NhanLaiChuyenDiModal (nhan_lai_chuyen_di): vụ ĐÃ Chuyển đi được đơn vị khác trả lại để xử
--    lý TIẾP (cùng giai đoạn/khác giai đoạn tuỳ chọn) — bản án chưa bị huỷ.
--  - "huy_dieu_tra_lai": bản án/QĐ bị HUỶ → phải điều tra lại TỪ ĐẦU (về Điều tra).
--
-- 2 THAY ĐỔI:
--  1. Nới CHECK constraint "lichsuChuyenGiaiDoan_loaiSuKien_check" — thêm 'huy_dieu_tra_lai'
--     (giống hệt add_nhan_lai_chuyen_di_2026-08-01.sql — CỘT đã có sẵn, chỉ thiếu GIÁ TRỊ hợp lệ).
--  2. layTrangThaiVuTaiKy: thêm 'huy_dieu_tra_lai' vào danh sách loaiSuKien "thật sự đổi giai
--     đoạn" trong CTE log_loc. KHÔNG phải sự kiện RA (hoan_thanh/nhap_vu) → vụ được RPC coi là
--     dangTon=true, giaiDoan=denGiaiDoan (='dieu_tra'). BẮT BUỘC: nếu KHÔNG thêm vào đây, RPC vẫn
--     coi sự kiện "hoan_thanh" (đã xét xử...) là mới nhất → vụ huỷ-điều-tra-lại HOÀN TOÀN VÔ HÌNH
--     trong "tồn" (RPC = nguồn số liệu tồn DUY NHẤT — xem CLAUDE.md).
--
-- layTrangThaiBiCanTaiKy: KHÔNG cần đổi — nó chỉ giao vu_ton với bị can có sự kiện khoi_to_bican
-- (vụ đã xét xử thì bị can chắc chắn đã có khoi_to_bican từ lâu). Bị can tự động "sống lại" cùng vụ.
--
-- AN TOÀN: chỉ thêm 1 giá trị enum + 1 nhánh where. Không đụng dữ liệu/cột nào có sẵn. Vụ nào
-- CHƯA có sự kiện huy_dieu_tra_lai → RPC ra kết quả y hệt trước.
--
-- ĐÃ BACKUP TRƯỚC KHI CHẠY (gh workflow run backup-supabase.yml). Chạy qua Session pooler
-- (xem supabase/README.md) hoặc Supabase Dashboard → SQL Editor (project eutatszoaseixchvjbtg).
-- ============================================================================

-- ── 1. CHECK constraint ──────────────────────────────────────────────────────
-- LƯU Ý (2026-09-10): CHECK constraint THẬT trên Supabase lúc kiểm tra CÓ THÊM giá trị
-- 'bo_sung_bican_hoi_to' KHÔNG có trong bất kỳ file migration nào của repo — 1 phiên làm việc
-- khác đã thêm (0 dòng dữ liệu dùng lúc này, nhưng GIỮ LẠI để không phá phiên đó). Danh sách
-- dưới đây = danh sách THẬT hiện hành + 'huy_dieu_tra_lai'.
alter table "lichsuChuyenGiaiDoan" drop constraint if exists "lichsuChuyenGiaiDoan_loaiSuKien_check";

alter table "lichsuChuyenGiaiDoan" add constraint "lichsuChuyenGiaiDoan_loaiSuKien_check"
  check ("loaiSuKien" in (
    'khoi_to_vu','khoi_to_bican','chuyen_giai_doan','tra_ho_so',
    'gia_han_dieu_tra','phuc_hoi','hoan_thanh','tach_vu','nhap_vu',
    'duoc_nhap_vu','giao_nhan_ho_so','sua_thong_tin',
    'nhan_lai_chuyen_di','bo_sung_bican','bo_sung_bican_hoi_to',
    'huy_dieu_tra_lai'
  ));

-- ── 2. layTrangThaiVuTaiKy — thêm 'huy_dieu_tra_lai' vào log_loc ─────────────
-- Bản hiện hành = fix_tach_vu_vutachra_2026-09-06.sql (tach_vu dùng vuTachRa). CHỈ khác đúng
-- 1 dòng: thêm 'huy_dieu_tra_lai' vào mệnh đề IN.
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
    select k."id" as ky_id, k."ngayBatDau" as ky_moc
    from "kybaocao" k, ky_dich
    where k."loai" is null and k."ngayBatDau" <= ky_dich.moc
  ),
  log_loc as (
    select
      -- tach_vu dùng vuTachRa (vụ CON) làm định danh vụ, KHÔNG dùng maVuAn (vụ GỐC).
      case when l."loaiSuKien" = 'tach_vu' then l."vuTachRa" else l."maVuAn" end as "maVuAn",
      l."loaiSuKien",
      l."denGiaiDoan",
      l."kyThongKe",
      kh.ky_moc,
      l."thoiDiemGhi" as tie1
    from "lichsuChuyenGiaiDoan" l
    join ky_hop_le kh on kh.ky_id = l."kyThongKe"
    where l."loaiSuKien" in (
      'khoi_to_vu', 'tach_vu', 'chuyen_giai_doan', 'tra_ho_so',
      'phuc_hoi', 'nhan_lai_chuyen_di', 'huy_dieu_tra_lai', 'hoan_thanh', 'nhap_vu'
    )
    and (l."loaiSuKien" != 'tach_vu' or l."vuTachRa" is not null)
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

notify pgrst, 'reload schema';
