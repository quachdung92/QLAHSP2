CREATE OR REPLACE FUNCTION public."layTrangThaiVuTaiKy"(p_ky_id text)
 RETURNS TABLE("maVuAn" text, "dangTon" boolean, "giaiDoan" text, "loaiSuKienCuoi" text, "kyThongKe" text, moc timestamp with time zone)
 LANGUAGE sql
 STABLE
AS $function$
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
  from moi_nhat m
  -- Vụ đã vào Thùng rác (daXoa = true) không tính vào tồn (2026-10-28)
  where not exists (select 1 from "vuan" v where v."id" = m."maVuAn" and v."daXoa" = true);
$function$
;

notify pgrst, 'reload schema';
