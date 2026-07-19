-- ============================================================================
-- QLVA — Trigger tự động đồng bộ vuan (dieuLuat/soBiCan/biCanDaiDien) + bican.loaiKhoiTo mỗi khi
-- bảng "bican" thay đổi (INSERT/UPDATE/DELETE) — thay cho việc code JS phải tự NHỚ gọi RPC
-- "capNhatDieuLuatVaLoaiKhoiTo" sau MỌI thao tác ghi bican. (2026-07-19, theo yêu cầu "tối ưu
-- triệt để cho Supabase" — tận dụng TRIGGER, năng lực Firestore không có, thay vì chỉ giả lập
-- hành vi cũ qua shim.)
--
-- LỢI ÍCH:
-- 1. Đúng đắn hơn: BẤT KỲ đường ghi "bican" nào (kể cả script/import trực tiếp sau này, hay 1
--    đường JS mới quên gọi RPC) đều tự động đồng bộ — không còn phụ thuộc code JS "nhớ" gọi đúng
--    chỗ. Loại bỏ hẳn 1 lớp bug tiềm ẩn ("quên gọi hàm cập nhật").
-- 2. Vá 1 lỗ hổng THẬT đang tồn tại trong `tachVuAn` (tách vụ, qlahs-sup.html): hàm này hiện CHỈ
--    tự tính dieuLuat/soBiCan/biCanDaiDien ở phía client (hàm `tomTatBiCan`) rồi ghi thẳng, KHÔNG
--    gọi lại capNhatDieuLuatVaLoaiKhoiTo cho vụ mới lẫn vụ gốc sau khi tách — nghĩa là `loaiKhoiTo`
--    (ban_dau/bo_sung) của bị can KHÔNG được tính lại theo đúng nhóm MỚI sau khi tách (VD 1 bị can
--    vốn "bo_sung" ở vụ gốc, sau khi tách sang vụ mới lại là người có ngày khởi tố sớm nhất trong
--    vụ mới đó — đáng ra phải đổi thành "ban_dau" nhưng hiện không đổi). Trigger này tự động vá
--    lỗ hổng đó cho MỌI lần tách vụ từ nay về sau (không backfill dữ liệu tách vụ cũ ở đây — xem
--    script kiểm tra/backfill riêng nếu cần).
-- 3. Nhanh hơn: trigger chạy TRONG CÙNG transaction ghi bican (1 round-trip) thay vì JS ghi bican
--    xong rồi mới gọi RPC riêng (2 round-trip tuần tự, có khe hở giữa 2 bước).
--
-- AN TOÀN ĐỆ QUY: RPC "capNhatDieuLuatVaLoaiKhoiTo" tự UPDATE "bican" (set loaiKhoiTo/ngayCapNhat)
-- — UPDATE đó sẽ lại kích hoạt CHÍNH trigger này lần nữa nếu không chặn, gây đệ quy. Dùng
-- pg_trigger_depth() > 1 để CHỈ chạy đồng bộ ở lần ghi NGOÀI CÙNG (depth = 1), bỏ qua các lần
-- trigger tự kích hoạt lại do RPC gây ra (depth > 1) — pattern chuẩn của Postgres cho đúng tình
-- huống "trigger gọi hàm mà hàm đó ghi ngược lại vào chính bảng có trigger".
--
-- ĐÁNH ĐỔI CHẤP NHẬN ĐƯỢC: trigger chạy TRÊN TỪNG DÒNG (for each row) — insert N bị can cùng 1 vụ
-- trong 1 câu lệnh sẽ gọi RPC N lần (recompute lặp lại, hội tụ đúng ở lần cuối). Ở quy mô hiện tại
-- (1 vụ thường vài bị can) không đáng kể; nếu sau này cần tối ưu thêm cho batch insert cực lớn, có
-- thể đổi sang statement-level trigger + transition table — chưa cần ở quy mô dữ liệu hiện tại.
-- ============================================================================

create or replace function "trg_syncVuAnSauBiCan"()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if pg_trigger_depth() > 1 then
    return coalesce(NEW, OLD);
  end if;

  if TG_OP = 'DELETE' then
    perform "capNhatDieuLuatVaLoaiKhoiTo"(OLD."maVuAn");
    return OLD;
  end if;

  perform "capNhatDieuLuatVaLoaiKhoiTo"(NEW."maVuAn");
  if TG_OP = 'UPDATE' and OLD."maVuAn" is distinct from NEW."maVuAn" then
    perform "capNhatDieuLuatVaLoaiKhoiTo"(OLD."maVuAn");
  end if;
  return NEW;
end;
$$;

drop trigger if exists "bican_sync_vuan_trg" on "bican";
create trigger "bican_sync_vuan_trg"
  after insert or update or delete on "bican"
  for each row execute function "trg_syncVuAnSauBiCan"();
