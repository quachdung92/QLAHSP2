# `supabase/` — schema Postgres cho QLVA (nhánh `supabase-migration`)

Xem `SUPABASE_MIGRATION.md` ở gốc repo để biết bối cảnh/lộ trình đầy đủ. **ĐÃ áp dụng thành công
lên Supabase thật** (project `eutatszoaseixchvjbtg`, xem `SUPABASE_MIGRATION.md` mục 4c) — không
còn ở trạng thái "chỉ là bản nháp chờ env" nữa.

## Nội dung

- `schema.sql` — `CREATE TABLE`/`CREATE INDEX` cho 7 bảng nghiệp vụ + `boDemMaVu` (đếm nội bộ) +
  `meta` (sentinel "vuAnMoiNhat" — ban đầu định không tạo, phải thêm khi viết shim vì code thật
  vẫn ghi vào đó, xem SUPABASE_MIGRATION.md mục 5 ghi chú 5 và mục 4d). Đọc phần comment đầu file
  trước khi sửa — có 6 quyết định thiết kế quan trọng (tên cột camelCase có quote, enum dùng CHECK
  không dùng native ENUM, mảng song song giữ nguyên dạng cột `text[]` không tách bảng con...).
- `rls.sql` — bật Row Level Security + 1 policy "authenticated đọc/ghi mọi thứ" cho mỗi bảng,
  mirror đúng `firestore.rules` hiện tại (không phân quyền theo role/field).
- `functions.sql` — 4 hàm RPC thay 4 vị trí `db.runTransaction()` của Firestore (sinh mã vụ án,
  sinh mã hàng loạt, sinh mã vụ tách, tính lại điều luật/loại khởi tố). Các hàm này sẽ được gọi
  thẳng qua `.rpc(...)` từ JS, KHÔNG đi qua lớp shim giả lập Firestore API.

## Backup tự động hàng ngày + cách khôi phục (2026-08-01)

Supabase gói Free KHÔNG có backup/point-in-time-recovery tự động. `.github/workflows/
backup-supabase.yml` tự `pg_dump` schema `public` + `extensions` (đủ 9 bảng nghiệp vụ + `pgcrypto`
mà `public.vuan`... phụ thuộc qua `gen_random_uuid()` — KHÔNG dump `auth`/`storage`/`realtime`/
`vault` nội bộ Supabase, không phải dữ liệu nghiệp vụ) mỗi ngày lúc 02:00 sáng giờ VN (19:00 UTC),
TỰ KIỂM CHỨNG bằng
cách phục hồi thử vào 1 Postgres tạm ngay trong job trước khi mã hoá (GPG, bắt buộc vì repo
public) + lưu artifact — dump lỗi thì job tự fail, không lưu bản backup hỏng. Giữ 7 bản gần nhất
(`retention-days: 7`, tự hết hạn, không tích luỹ mãi — dữ liệu hiện ~15k dòng nén chỉ ~0.8MB nên
backup hàng ngày vẫn rẻ hơn nhiều so với 1 lần khôi phục thất bại).

**Bấm backup thủ công TRƯỚC khi chạy công cụ audit/backfill/xoá hàng loạt trên dữ liệu THẬT**
(áp dụng cho cả Dũng lẫn các phiên Claude Code sau này):
```bash
gh workflow run backup-supabase.yml -f reason="mo-ta-ngan-gon-viec-sap-lam"
gh run watch <run-id-in-ra-từ-lệnh-trên>   # đợi "success" rồi mới tiến hành thao tác rủi ro
```

**Cách khôi phục khi cần** (chỉ dùng khi thật sự mất/hỏng dữ liệu — không thử trên project đang
chạy thật nếu chưa chắc chắn):
1. Tab **Actions** trên GitHub → chọn đúng lần chạy (hoặc `gh run download <run-id>`) → tải file
   `*.dump.gpg`.
2. Giải mã: `gpg --decrypt --batch --yes --passphrase "<BACKUP_ENCRYPT_PASSPHRASE>" -o backup.dump
   backup.dump.gpg` (passphrase Dũng tự lưu ngoài GitHub lúc thiết lập — KHÔNG lưu trong repo).
3. Phục hồi vào project Supabase (project mới, hoặc project cũ SAU KHI đã xoá sạch dữ liệu hỏng —
   `pg_restore` không tự xoá dữ liệu hiện có, chạy vào DB còn dữ liệu cũ sẽ báo lỗi trùng khoá):
   `pg_restore -h aws-0-ap-southeast-1.pooler.supabase.com -p 5432 -U postgres.<ref> -d postgres
   --no-owner --no-privileges backup.dump` (cần bản `pg_dump`/`pg_restore` **đúng major version**
   với server đích — Supabase hiện chạy Postgres 17, bản 16 sẽ báo lỗi "server version mismatch",
   xem cách cài bản 17 qua PGDG trong chính file workflow).

2 GitHub Secret cần cho workflow này (`gh secret set`, không hiện lại được sau khi lưu):
`SUPABASE_DB_PASSWORD` (mật khẩu DB, dùng để `pg_dump`) và `BACKUP_ENCRYPT_PASSPHRASE` (passphrase
mã hoá file backup, KHÁC mật khẩu DB — Dũng tự lưu bản sao ở nơi an toàn ngoài GitHub).

## Kết nối Supabase project hiện có (ref `eutatszoaseixchvjbtg`)

**Kết nối trực tiếp (`db.eutatszoaseixchvjbtg.supabase.co`) KHÔNG dùng được** từ môi trường thực
thi lệnh hiện tại — host đó chỉ có bản ghi DNS IPv6 (AAAA), không có IPv4, và môi trường này không
có route IPv6 ra ngoài (`ENETUNREACH` khi thử thẳng). Luôn dùng **Session pooler** cho mọi việc
quản trị/import dữ liệu (KHÔNG dùng Transaction pooler — pooler đó tối ưu cho query ngắn hạn của
ứng dụng runtime, không hợp cho script chạy nhiều câu lệnh/hàm `plpgsql`):

```
host: aws-0-ap-southeast-1.pooler.supabase.com
port: 5432
user: postgres.eutatszoaseixchvjbtg
database: postgres
```

Mật khẩu DB **không được ghi vào file nào trong repo** — chỉ truyền qua biến môi trường lúc chạy
script tạm trong thư mục scratchpad (ngoài git), hỏi lại Dũng nếu phiên sau cần dùng lại.

## Đã kiểm chứng (2026-07-19 — đầy đủ, không còn khoảng trống)

1. **Cú pháp**: parse-check sạch qua `libpg-query` (bộ phân tích cú pháp Postgres thật).
2. **Áp dụng thật**: cả 3 file chạy thành công lên project Supabase thật qua Session pooler, không
   sửa gì — 8 bảng + 7 RLS policy + 4 hàm RPC đều tạo đúng, xác nhận `CREATE FUNCTION` biên dịch
   sạch phần thân `plpgsql` (khoảng trống lớn nhất trước đó, giờ đã hết).
3. **Chức năng RPC** (14 assertion, dữ liệu test tự tạo rồi dọn sạch): `sinhMaVuAnMoi`,
   `sinhNhieuMaVuAn` (gộp đúng theo nhóm YYMM), `tachVuSinhMa`, `capNhatDieuLuatVaLoaiKhoiTo` (tính
   đúng `loaiKhoiTo`/`dieuLuat`/cache `soBiCan`+`biCanDaiDien`) — đều PASS.
4. **RLS qua REST API thật** (không phải qua kết nối Postgres trực tiếp — kết nối đó chạy role
   `postgres` superuser nên KHÔNG bị RLS chặn): `POST /rest/v1/vuan` bằng `anon key` bị chặn đúng
   (`HTTP 401`, `42501 - new row violates row-level security policy`).
5. `pgcrypto` có sẵn trên project (không cần cài thêm — `create extension if not exists pgcrypto`
   trong `schema.sql` chạy không lỗi).
6. **Realtime replication đã bật cho cả 9 bảng** (`ALTER PUBLICATION supabase_realtime ADD TABLE
   "..."`) — Supabase KHÔNG tự bật cho bảng mới tạo, thiếu bước này thì `onSnapshot()` phía shim
   chỉ bắn được đúng 1 lần (từ `.get()` ban đầu), không bao giờ nhận cập nhật realtime sau đó. Nếu
   tạo THÊM bảng mới sau này, nhớ chạy lại lệnh này cho bảng đó.

## Phase 2 (lớp shim) — ĐÃ VIẾT + KIỂM CHỨNG (xem `SUPABASE_MIGRATION.md` mục 4d)

`qlahs-sup.html` đã có lớp shim đầy đủ chạy trên nền project này, kiểm chứng bằng Playwright thật
qua 3 kịch bản (đăng nhập, thao tác nguyên thuỷ của shim, luồng UI "Thêm vụ án" trọn vẹn) — 17
assertion, PASS. 1 bug FK-ordering thật đã tìm và sửa trong lúc test (xem `_TABLE_INSERT_ORDER`
trong chính file `qlahs-sup.html`). Việc còn lại: checklist "rà lại tinh chỉnh vì Firebase"
(`SUPABASE_MIGRATION.md` mục 5) CHƯA làm — xem mục 8 "Trạng thái hiện tại" của file đó để biết thứ
tự việc tiếp theo.
