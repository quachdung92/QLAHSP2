-- ============================================================================
-- QLVA — Postgres functions (RPC) thay thế 4 vị trí db.runTransaction() của Firestore
--
-- 4 hàm này KHÔNG đi qua lớp shim giả lập Firestore API (xem SUPABASE_MIGRATION.md mục 3) —
-- code JS ở 4 nơi tương ứng (sinhMaVuAnMoi, sinhNhieuMaVuAn, tachVuAn, capNhatDieuLuatVaLoaiKhoiTo)
-- sẽ được sửa tay gọi thẳng `supabaseClient.rpc("tenHam", {...})` thay vì
-- `db.runTransaction(...)`. Lý do: bản chất thực thi khác hẳn nhau (Firestore transaction là
-- nhiều round-trip từ trình duyệt; Postgres function chạy nguyên khối, atomic, 1 lần gọi) —
-- giả lập qua shim sẽ chỉ tạo ảo giác tương thích mà không giữ được tính đúng đắn thật.
--
-- Mỗi hàm chạy dưới quyền SECURITY DEFINER (không phải quyền người gọi) vì cần ghi vào
-- "boDemMaVu" — bảng đó CHỦ Ý không cấp quyền ghi trực tiếp cho role authenticated (xem rls.sql).
-- Vì vậy PHẢI giới hạn quyền EXECUTE các hàm này chỉ cho authenticated (revoke/grant ở cuối file)
-- — nếu không, SECURITY DEFINER sẽ vô tình mở quyền ghi gián tiếp cho người chưa đăng nhập.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- sinhMaVuAnMoi: sinh 1 mã vụ án mới, dạng QLVA_E01.53_{YYMM}_{SEQ4}.
-- p_yymm: đã tính sẵn ở phía JS từ ngày QĐ KTVA (VD "2601") — giữ nguyên logic tính YYMM ở JS
-- (không phải business logic cần chuyển vào DB, chỉ là format ngày).
-- ----------------------------------------------------------------------------
create or replace function "sinhMaVuAnMoi"(p_yymm text)
returns text
language plpgsql
security definer
as $$
declare
  v_seq integer;
begin
  insert into "boDemMaVu" ("yymm", "soHienTai") values (p_yymm, 1)
  on conflict ("yymm") do update set "soHienTai" = "boDemMaVu"."soHienTai" + 1
  returning "soHienTai" into v_seq;

  return 'QLVA_E01.53_' || p_yymm || '_' || lpad(v_seq::text, 4, '0');
end;
$$;

-- ----------------------------------------------------------------------------
-- sinhNhieuMaVuAn: bản hàng loạt dùng lúc Import Excel — nhận mảng YYMM (1 phần tử/vụ, ĐÚNG thứ
-- tự vụ cần sinh mã), trả về mảng mã tương ứng CÙNG THỨ TỰ. Gộp theo từng YYMM để chỉ cần 1 lần
-- UPDATE...RETURNING/nhóm (thay vì 1 lần gọi hàm/vụ) — giữ đúng tinh thần "sinh hàng loạt rẻ hơn
-- sinh từng cái" của bản JS gốc (dùng 1 transaction/tháng thay vì 1 transaction/vụ).
-- ----------------------------------------------------------------------------
create or replace function "sinhNhieuMaVuAn"(p_yymm_list text[])
returns text[]
language plpgsql
security definer
as $$
declare
  v_distinct_yymm text[];
  v_yymm text;
  v_count integer;
  v_end integer;
  v_start integer;
  v_result text[] := array_fill(null::text, array[array_length(p_yymm_list, 1)]);
  v_idx integer;
  v_seq integer;
begin
  select array_agg(distinct y) into v_distinct_yymm from unnest(p_yymm_list) as y;

  foreach v_yymm in array v_distinct_yymm loop
    v_count := (select count(*) from unnest(p_yymm_list) as y where y = v_yymm);

    insert into "boDemMaVu" ("yymm", "soHienTai") values (v_yymm, v_count)
    on conflict ("yymm") do update set "soHienTai" = "boDemMaVu"."soHienTai" + v_count
    returning "soHienTai" into v_end;
    v_start := v_end - v_count;  -- số cuối cùng đã dùng TRƯỚC khi cộng block này

    v_seq := 0;
    for v_idx in 1 .. array_length(p_yymm_list, 1) loop
      if p_yymm_list[v_idx] = v_yymm then
        v_seq := v_seq + 1;
        v_result[v_idx] := 'QLVA_E01.53_' || v_yymm || '_' || lpad((v_start + v_seq)::text, 4, '0');
      end if;
    end loop;
  end loop;

  return v_result;
end;
$$;

-- ----------------------------------------------------------------------------
-- tachVuSinhMa: tăng soDemTach của vụ gốc, trả về mã vụ con = {maVuGoc}_{soDemTach mới}.
-- Chỉ thay phần SINH MÃ của tachVuAn (JS) — phần còn lại (tạo vụ mới, phân bổ bị can, ghi log
-- tach_vu...) vẫn là các câu insert/update thường qua lớp shim, không cần atomic với bước này.
-- ----------------------------------------------------------------------------
create or replace function "tachVuSinhMa"(p_vu_goc_id text)
returns text
language plpgsql
security definer
as $$
declare
  v_so_dem_tach integer;
begin
  update "vuan"
    set "soDemTach" = "soDemTach" + 1
    where "id" = p_vu_goc_id
    returning "soDemTach" into v_so_dem_tach;

  if v_so_dem_tach is null then
    raise exception 'Không tìm thấy vụ án gốc để tách: %', p_vu_goc_id;
  end if;

  return p_vu_goc_id || '_' || v_so_dem_tach;
end;
$$;

-- ----------------------------------------------------------------------------
-- capNhatDieuLuatVaLoaiKhoiTo: tính lại "dieuLuat" (vuan, gộp toiDanh mọi bị can, loại trùng) +
-- "loaiKhoiTo" (từng bị can, "ban_dau" nếu ngayKhoiTo = MIN cùng vụ) + cache soBiCan/biCanDaiDien
-- — thay cho hàm JS cùng tên vốn phải tự đọc-lại-từng-bị-can trong runTransaction để né
-- lost-update. Ở đây Postgres cho ACID trong 1 lần gọi hàm; FOR UPDATE khoá dòng vụ án thêm 1
-- lớp an toàn khi 2 lời gọi đến gần như đồng thời cho CÙNG 1 vụ.
--
-- Lưu ý khác biệt nhỏ so với bản JS: "biCanDaiDien" (đại diện hiển thị) chọn theo "ngayTao" sớm
-- nhất thay vì "phần tử đầu mảng cuối cùng tải được" (bản JS không có tiêu chí sắp xếp rõ ràng,
-- phụ thuộc thứ tự Firestore trả về) — cần xác nhận lại với Dũng ở Phase 4 nếu thứ tự hiển thị
-- đại diện có ý nghĩa nghiệp vụ cụ thể nào đó chưa được ghi lại.
-- ----------------------------------------------------------------------------
create or replace function "capNhatDieuLuatVaLoaiKhoiTo"(p_ma_vu_an text)
returns void
language plpgsql
security definer
as $$
declare
  v_dieu_luat text;
  v_min_ngay timestamptz;
  v_so_bi_can integer;
  v_bi_can_dai_dien text;
begin
  perform 1 from "vuan" where "id" = p_ma_vu_an for update;

  select string_agg(distinct t, '; ') into v_dieu_luat
  from "bican", unnest("toiDanh") as t
  where "maVuAn" = p_ma_vu_an and t is not null and trim(t) <> '';

  select min("ngayKhoiTo") into v_min_ngay
  from "bican" where "maVuAn" = p_ma_vu_an and "ngayKhoiTo" is not null;

  update "bican"
    set "loaiKhoiTo" = case
                          when v_min_ngay is null then 'ban_dau'
                          when "ngayKhoiTo" = v_min_ngay then 'ban_dau'
                          else 'bo_sung'
                        end,
        "ngayCapNhat" = now()
    where "maVuAn" = p_ma_vu_an;

  select count(*), (array_agg("hoTen" order by "ngayTao" asc nulls last))[1]
    into v_so_bi_can, v_bi_can_dai_dien
    from "bican" where "maVuAn" = p_ma_vu_an;

  update "vuan"
    set "dieuLuat" = v_dieu_luat,
        "soBiCan" = coalesce(v_so_bi_can, 0),
        "biCanDaiDien" = coalesce(v_bi_can_dai_dien, ''),
        "ngayCapNhat" = now()
    where "id" = p_ma_vu_an;
end;
$$;

-- ----------------------------------------------------------------------------
-- Giới hạn quyền gọi: chỉ role "authenticated" (đúng mô hình bảo mật hiện tại — mọi người dùng
-- đã đăng nhập đều thao tác được, không phân quyền thêm). SECURITY DEFINER nghĩa là các hàm này
-- chạy với quyền chủ sở hữu (thường là bỏ qua RLS) — PHẢI revoke khỏi "anon"/"public" tường minh,
-- nếu không người chưa đăng nhập vẫn gọi được RPC dù không đọc/ghi được bảng trực tiếp.
-- ----------------------------------------------------------------------------
revoke execute on function "sinhMaVuAnMoi"(text) from public;
revoke execute on function "sinhNhieuMaVuAn"(text[]) from public;
revoke execute on function "tachVuSinhMa"(text) from public;
revoke execute on function "capNhatDieuLuatVaLoaiKhoiTo"(text) from public;

grant execute on function "sinhMaVuAnMoi"(text) to authenticated;
grant execute on function "sinhNhieuMaVuAn"(text[]) to authenticated;
grant execute on function "tachVuSinhMa"(text) to authenticated;
grant execute on function "capNhatDieuLuatVaLoaiKhoiTo"(text) to authenticated;
