-- ============================================================================
-- Sửa bug thật trong layTrangThaiVuTaiKy: sự kiện "tach_vu" bị nhóm theo maVuAn
-- (vụ GỐC, nơi lưu sự kiện) thay vì vuTachRa (vụ CON thật sự phát sinh) — khiến
-- vụ con hoàn toàn "vô hình" trong RPC (không bao giờ có mặt trong bất kỳ kỳ nào,
-- ở BẤT KỲ giai đoạn nào), vì không sự kiện nào khác có maVuAn = chính vụ con đó.
--
-- Phát hiện 2026-09-06 khi điều tra yêu cầu của Dũng: "sửa triệt để công thức Biểu 2
-- để D154/D156/D344/D346 khớp tuyệt đối với số tồn RPC ở kỳ 08/2026". Đối chiếu trực
-- tiếp qua Session pooler: RPC trả về [] cho MỌI vụ con tách ra (VD
-- QLVA_E01.53_2603_0011_1) ở CẢ 2 kỳ trước/sau, dù bản thân vụ đó có bản ghi "vuan"
-- hợp lệ (coQuanThuLy=dieu_tra, trangThai=dang_giai_quyet) — nghĩa là mọi báo cáo dựa
-- trên RPC này (Kỳ báo cáo/Dashboard/Biểu 2/3/10 — TỨC LÀ TOÀN BỘ hệ thống thống kê)
-- đã ÂM THẦM THIẾU các vụ tách ra khỏi số "tồn" từ trước tới giờ.
--
-- Kiểm chứng qua pooler (không phá huỷ, chạy hàm test riêng "layTrangThaiVuTaiKy_test"
-- rồi xoá) — số tồn ĐT thay đổi đúng bằng số vụ con đang thực tồn ở giai đoạn đó:
--   kỳ 06/2026: 310 -> 310 (không đổi, chưa có vụ tách nào lúc đó)
--   kỳ 07/2026: 319 -> 320 (+1)
--   kỳ 08/2026: 326 -> 330 (+4)
--   kỳ 09/2026: 330 -> 334 (+4)
-- Truy tố/Xét xử: KHÔNG đổi ở kỳ nào (mọi tach_vu từ trước tới giờ đều denGiaiDoan=
-- dieu_tra — xác nhận qua SELECT "denGiaiDoan" FROM lichsuChuyenGiaiDoan WHERE
-- loaiSuKien='tach_vu' GROUP BY 1, chỉ ra đúng 1 giá trị 'dieu_tra').
--
-- FIX: trong log_loc CTE, dùng CASE để chọn "vuTachRa" làm "maVuAn" hiệu lực khi
-- loaiSuKien='tach_vu' (và loại thẳng các dòng tach_vu thiếu vuTachRa — không nên
-- xảy ra vì tachVuAn() luôn ghi kèm, nhưng phòng dữ liệu hỏng/dựng lại lịch sử cũ).
-- KHÔNG đổi gì khác so với rpc_ton_ky_thong_nhat_2026-08-28.sql.
-- ============================================================================

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
      -- SỬA: tach_vu dùng vuTachRa (vụ CON) làm định danh vụ, KHÔNG dùng maVuAn (vụ GỐC).
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
      'phuc_hoi', 'nhan_lai_chuyen_di', 'hoan_thanh', 'nhap_vu'
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
