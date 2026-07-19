# Kế hoạch chuyển hạ tầng dữ liệu từ Firebase (Firestore) sang Supabase (Postgres)

> Nhánh: `supabase-migration`. Tài liệu này là nguồn tham chiếu chính cho toàn bộ quá trình chuyển
> đổi — giữ cập nhật qua từng phiên làm việc, đừng để lệch với thực tế code trên nhánh này (giống
> cách `CLAUDE.md` được duy trì cho `main`).

## 1. Vì sao chuyển

Firestore tính phí theo **lượt đọc (read)** — mô hình này là nguyên nhân trực tiếp của rất nhiều
đợt "tối ưu Firestore" đã làm trên `main` (gộp listener dùng chung, cache lạnh IndexedDB, sentinel
cho dữ liệu "nóng", cursor pagination thật... — xem các mục "Tối ưu Firestore..." trong
`CLAUDE.md`). Đó là cách chữa triệu chứng: mô hình pricing theo read vẫn còn nguyên, mọi tính năng
mới đều phải cân nhắc thêm chi phí đọc. Mục tiêu của việc chuyển sang Supabase (Postgres, tính phí
theo dung lượng/băng thông/compute, không tính theo từng lượt đọc) là giải quyết dứt điểm gốc rễ,
không phải vá thêm.

**Ràng buộc không đổi**: vẫn giữ nguyên tắc "1 file HTML, mọi thư viện qua CDN, không có bước
build" — Supabase JS client cũng có bản UMD/ESM qua CDN nên khả thi giữ nguyên kiến trúc này.

## 2. Phạm vi hiện trạng Firebase (đã khảo sát trên `qlva.html`, ~11.923 dòng script chính)

### Collection Firestore (9)
- **7 collection nghiệp vụ thật**: `vuan`, `bican`, `lichsuChuyenGiaiDoan` (log append-only —
  nguồn sự thật duy nhất cho số liệu báo cáo), `kybaocao`, `canbo`, `danhMucToiDanh`,
  `phienGiaoNhan`.
- **2 collection thuần kỹ thuật** (sẽ không cần tồn tại riêng ở Postgres): `boDemMaVu` (bộ đếm
  sinh mã vụ án, chỉ đọc/ghi trong transaction, không bao giờ query cả collection) và
  `meta/vuAnMoiNhat` (1 doc sentinel để các client biết có vụ mới mà không cần listener sống trên
  cả danh sách — cơ chế né tránh chi phí Firestore, xem mục 5).

### Realtime & ghi dữ liệu
- **15 vị trí `onSnapshot`** → 9 kiểu subscription khác nhau (4 trong số đó đã gộp qua cơ chế cache
  dùng chung `firestoreCacheRegistry`/`useFirestoreCollectionCache`, xem CLAUDE.md "Tối ưu
  Firestore Đợt 1").
- **4 vị trí `db.runTransaction`**: `sinhMaVuAnMoi` (đếm tăng dần theo tháng để sinh mã vụ án),
  `sinhNhieuMaVuAn` (bản hàng loạt của trên, dùng lúc import Excel), `capNhatDieuLuatVaLoaiKhoiTo`
  (đọc lại toàn bộ bị can của 1 vụ, tính lại rồi ghi — tránh lost-update khi 2 người sửa đồng
  thời), `tachVuAn` (đếm số lần tách để sinh mã vụ con). Cả 4 đều là pattern "optimistic
  concurrency + counter", không phải giao dịch nhiều bước phức tạp.
- **~19 vị trí `batch()`/`commit()`**, vài chỗ chia lô 400 (giới hạn ghi/batch của Firestore) —
  giới hạn này biến mất hoàn toàn ở Postgres.
- **8 composite index** trong `firestore.indexes.json` (3 trên `lichsuChuyenGiaiDoan`, 5 trên
  `vuan`).

### Bảo mật & Auth
- **Security rules**: đúng 1 rule `request.auth != null` cho toàn bộ database — không phân quyền
  theo collection/field/role.
- **Auth**: chỉ email/password, không custom claims/role, `onAuthStateChanged` là cổng duy nhất
  vào toàn bộ UI (`App()`, gần cuối file). `auth.currentUser?.email` được đọc ở ~25 chỗ chỉ để ghi
  audit trail (`nguoiThucHien`/`nguoiCapNhatCuoi`), không đọc property nào khác của user.

### Khoảng trống thật cần lưu ý
- **Offline persistence** (`db.enablePersistence({synchronizeTabs:true})`) — Firestore SDK tự lo
  hàng đợi ghi + cache đọc khi mất mạng tạm thời. Supabase là REST/WebSocket thuần, **không có
  SDK offline-first tương đương sẵn có**. Đây là 1 tính năng thật sẽ mất nếu không tự xây thay thế
  — không chặn việc bắt đầu migrate, nhưng phải quyết định rõ ràng ở Phase 5 (chấp nhận mất tạm
  thời hay tự xây hàng đợi ghi riêng bằng localStorage/IndexedDB).

### Ngoài phạm vi Firestore/Auth (không đổi)
- Không dùng Firebase Storage/Functions/Realtime Database/Analytics/FCM/App Check — xác nhận qua
  grep toàn bộ codebase, không có kết quả nào.
- **Firebase Hosting giữ nguyên** — quyết định đã chốt với Dũng: vấn đề quota là do lượt đọc
  Firestore, không liên quan Hosting (gần miễn phí, không tính theo lượt đọc dữ liệu). `deploy.sh`/
  `deploy.bat`/`firebase.json`/`.firebaserc` không cần đổi gì.
- CDN không liên quan Firebase (React 18 UMD, Babel standalone, Tailwind, SheetJS `xlsx`,
  ExcelJS, Chart.js, qrcodejs) giữ nguyên 100%.

## 3. Chiến lược chuyển đổi code: lớp shim giả lập Firestore API

**Quyết định đã chốt** (thay vì sửa thẳng ~185 vị trí gọi Firestore cùng lúc): dựng 1 lớp trung
gian `db = createFirestoreShim(supabaseClient)` thay cho `db = firebase.firestore()`, giả lập
đúng SUBSET API mà ứng dụng đang thực sự dùng (không cần giả lập toàn bộ Firestore SDK):

- `db.collection(name).where(field, op, value).orderBy(field, dir).limit(n).get()` /
  `.onSnapshot(callback)`
- `db.collection(name).doc(id).get()` / `.set(data)` / `.update(data)` / `.delete()`
- `db.batch()` → `batch.set/update/delete(ref, data)` → `batch.commit()`

Bên trong shim, các thao tác này gọi Supabase (`.from(table).select()/.insert()/.update()/
.delete()`, `.channel().on('postgres_changes', ...)` cho phần realtime). Lợi ích: ứng dụng ở ~90%
vị trí gọi hầu như KHÔNG đổi cú pháp, chỉ đổi phần thân `db` — giảm rủi ro so với sửa thẳng diện
rộng, có thể chuyển từng collection 1 và rollback dễ dàng.

Chi tiết ngữ nghĩa cần giữ khi viết shim:
- `where(field, "in", [...])` → Postgres `= ANY(...)`, **bỏ hết giới hạn/logic chia lô 30 item**
  hiện có (Firestore giới hạn `in` tối đa 30, Postgres không có giới hạn tương tự).
- `FieldValue.arrayUnion` → `array_append` hoặc ghi qua RPC riêng.
- `Timestamp`/`.toDate()` → Postgres `timestamptz`, JS nhận về ISO string hoặc `Date` — cần audit
  lại toàn bộ pattern phòng thủ `d.toDate ? d.toDate() : new Date(d)` đang rải rác nhiều nơi.

**4 vị trí `runTransaction` KHÔNG đi qua shim chung** — viết tay riêng, gọi thẳng `.rpc()` tới các
hàm Postgres function (`plpgsql`) tương ứng, vì bản chất thực thi khác hẳn (Firestore transaction
là nhiều round-trip từ client; Postgres function chạy atomic trong 1 lần gọi). Quy mô nhỏ (4 hàm),
rủi ro thấp, làm riêng ở Phase 1-2.

## 4. Schema Postgres — ĐÃ VIẾT XONG (`supabase/schema.sql`, `rls.sql`, `functions.sql`)

**Quyết định thiết kế đã chốt (khác vài chỗ so với bản nháp ban đầu ở đây, xem comment đầu
`schema.sql` để biết đầy đủ lý do)**:

- **Tên bảng/cột giữ NGUYÊN camelCase, trùng khớp 1:1 tên collection/field Firestore** (VD bảng
  `"vuan"`, cột `"tenVu"`, `"ngayQdKtva"` — identifier có quote kép), KHÔNG đổi sang snake_case
  như bản nháp ban đầu dự tính (`lichsu_chuyen_giai_doan`, `ky_bao_cao`...). Lý do: lớp shim (mục
  3) chỉ thật sự "gần như không cần sửa code ứng dụng" nếu PostgREST trả JSON với đúng tên field
  cũ — đổi tên cột sẽ buộc shim phải có thêm 1 tầng map tên field, đúng thứ rủi ro chiến lược shim
  muốn tránh.
- `toiDanh`/`dieuLuatBC` (bican) và `vuanToiDanh`/`vuanDieuLuat` (vuan) **giữ dạng cột mảng
  `text[]`**, không tách bảng con — đã quyết định dứt điểm (không còn "cân nhắc") sau khi rà lại
  toàn bộ chỗ đọc/ghi: ứng dụng luôn thao tác như mảng đồng bộ theo index, tách bảng con chỉ thêm
  JOIN+GROUP BY mà không phục vụ nhu cầu quan hệ nào thật sự đang có.
- `boDemMaVu` **giữ 1 bảng riêng** (không thay bằng Postgres `sequence` như dự tính ban đầu) —
  sequence phải tạo trước cho từng YYMM, không tiện tạo động an toàn qua RPC; bảng counter nhỏ +
  UPSERT nguyên tử (`INSERT ... ON CONFLICT DO UPDATE RETURNING`) đơn giản/an toàn hơn. Bảng này
  KHÔNG cấp quyền cho role `authenticated` — chỉ được đụng từ bên trong 4 hàm RPC (SECURITY
  DEFINER), ứng dụng phía client không bao giờ gọi thẳng.
- `meta/vuAnMoiNhat` **cố ý không có bảng tương ứng** — xem mục 5.

Bảng tổng quan (đầy đủ ở `supabase/schema.sql`, đã đối chiếu TỪNG FIELD với write-site thật trong
`qlva.html` qua 2 agent Explore, không suy đoán từ tài liệu `schema_csdl_...md` — file đó thừa
nhận đã lỗi thời cho nhiều field thêm sau):

| Bảng Postgres | Nguồn Firestore | PK |
|---|---|---|
| `"vuan"` | `vuan` | `id` TEXT = `maNoiSinh` (business key, không đổi UUID) |
| `"bican"` | `bican` | `id` TEXT, default `gen_random_uuid()::text` |
| `"lichsuChuyenGiaiDoan"` | `lichsuChuyenGiaiDoan` | `id` TEXT, default uuid |
| `"kybaocao"` | `kybaocao` | `id` TEXT, default uuid |
| `"canbo"` | `canbo` | `id` TEXT, default uuid |
| `"danhMucToiDanh"` | `danhMucToiDanh` | `id` TEXT, default uuid |
| `"phienGiaoNhan"` | `phienGiaoNhan` | `id` TEXT, default uuid |
| `"boDemMaVu"` (nội bộ, không qua shim) | `boDemMaVu` | `yymm` TEXT |

**Enum**: dùng CHECK constraint (`CHECK (col IN (...))`), KHÔNG dùng Postgres native ENUM type —
enum nghiệp vụ ở đây đã đổi/thêm giá trị nhiều lần qua các phiên trước (xem mục 4b), native ENUM
khó thêm giá trị an toàn hơn CHECK.

**RLS** (`supabase/rls.sql`): mirror đúng rule hiện tại — 1 policy `USING (auth.role() =
'authenticated')` cho mỗi bảng (trừ `boDemMaVu`, xem trên), không phân quyền field/row.

**4 hàm RPC** (`supabase/functions.sql`, thay 4 `db.runTransaction`): `"sinhMaVuAnMoi"(yymm)`,
`"sinhNhieuMaVuAn"(yymm[])`, `"tachVuSinhMa"(vuGocId)`, `"capNhatDieuLuatVaLoaiKhoiTo"(maVuAn)` —
chạy SECURITY DEFINER, quyền EXECUTE giới hạn riêng cho role `authenticated`.

### 4b. Phát hiện lệch dữ liệu thật cần xử lý ở Phase 4 (export/import)

Qua audit field-level, phát hiện vài điểm KHÔNG khớp giữa tài liệu schema cũ và code/dữ liệu thật
— quan trọng khi viết script transform dữ liệu (mục 6), không phải lỗi cần sửa ngay bây giờ:

- `lichsuChuyenGiaiDoan.loaiSuKien` có giá trị **`sua_thong_tin`** dùng thật trong code (khi bấm
  "Sửa thông tin" 1 vụ án) nhưng KHÔNG có trong enum tài liệu cũ — đã đưa vào CHECK constraint.
  Ngược lại, 4 giá trị tài liệu cũ liệt kê (`ket_luan_dieu_tra`, `ket_luan_dieu_tra_bo_sung`,
  `cao_trang`, `cao_trang_bo_sung`) là **dead — chưa từng được ghi bởi code thật** (thay bằng
  `chuyen_giai_doan` + field `soKetLuanDieuTra`/`soCaoTrang` trên chính `vuan`) — CỐ Ý KHÔNG đưa
  vào CHECK constraint mới, nếu dữ liệu thật export ra có dòng nào mang giá trị này (rất khó xảy
  ra) thì phải map lại trước khi import.
- `lichsuChuyenGiaiDoan.soQuyetDinh` (free text "số QĐ/kết luận/cáo trạng/bản án") hoàn toàn thiếu
  trong tài liệu schema cũ dù có trên 7/12 loại sự kiện — đã thêm vào schema mới.
- `danhMucToiDanh` có **2 field song song chưa từng đồng bộ** cho cùng khái niệm "năm BLHS":
  `namBLHS` (do công cụ seed ghi, dùng thật trong logic tra cứu `taoDanhMucByTen`) và `blhsNam`
  (do form sửa tay UI ghi, giá trị mặc định `"2015_sd_2017"` còn không khớp map hiển thị của chính
  nó). Schema mới CHỈ giữ `"namBLHS"` — script transform (Phase 4) phải chuyển giá trị `blhsNam`
  cũ (nếu có, chỉ ở dòng nhập tay qua UI) sang đúng `namBLHS` tương ứng trước khi import, không
  mang cả 2 field song song sang Postgres.
- `lichsuChuyenGiaiDoan.ngaySuKien`/`thoiDiemGhi` không nhất quán kiểu ở nguồn: đa số ghi
  `new Date()` (client time), riêng sự kiện `sua_thong_tin` ghi `serverTimestamp()`/ISO string —
  script transform chuẩn hoá về `timestamptz` đồng nhất, không mang sự khác biệt kiểu này sang.

### 4c. Đã áp dụng lên Supabase THẬT + kiểm chứng chức năng (2026-07-19)

Project Supabase thật đã được Dũng tạo: ref `eutatszoaseixchvjbtg` (URL
`https://eutatszoaseixchvjbtg.supabase.co`). **Quyết định phạm vi**: đây là project DUY NHẤT dùng
làm môi trường chính (không tách riêng test/prod ở bước này) — sẽ nạp dữ liệu mock kéo từ project
Firestore thật, và **reset lại khi hoàn thiện** trước khi thật sự lên production. Khác nhẹ so với
lộ trình gốc ở mục 7 (dự tính 2 project ngay từ Phase 1) — điều chỉnh vì đơn giản hoá thao tác cho
Dũng, không ảnh hưởng tới thiết kế schema.

**Vấn đề hạ tầng phát hiện khi kết nối**: host kết nối trực tiếp
(`db.eutatszoaseixchvjbtg.supabase.co`) chỉ có bản ghi DNS AAAA (IPv6), không có A (IPv4) — hành vi
mặc định mới của Supabase (gói IPv4 riêng phải trả thêm). Môi trường thực thi lệnh không có route
IPv6 ra ngoài (`ENETUNREACH` khi thử kết nối thẳng IPv6, dù DNS AAAA vẫn phân giải được — 2 việc
khác nhau). **Giải pháp**: dùng **Session pooler** (`aws-0-ap-southeast-1.pooler.supabase.com:5432`,
username `postgres.eutatszoaseixchvjbtg` — khác hẳn Direct connection cả về host lẫn username) —
tương thích IPv4, và đúng loại pooler cần cho việc chạy script quản trị nhiều câu lệnh/hàm
`plpgsql` (Transaction pooler tối ưu cho query ngắn hạn của ứng dụng runtime, KHÔNG hợp cho việc
này). **Lưu ý cho phiên sau**: khi cần chạy thêm script quản trị/import dữ liệu (Phase 4), dùng lại
đúng chuỗi Session pooler này, đừng thử Direct connection lại (sẽ lặp lại đúng lỗi IPv6 này).

**Đã áp dụng thành công cả 3 file** (`schema.sql` → `rls.sql` → `functions.sql`, qua script Node
dùng `pg`, chạy 1 lần không sửa gì) — xác nhận: 8 bảng đúng tên (7 nghiệp vụ + `boDemMaVu`), 7 RLS
policy đúng 1/bảng nghiệp vụ (không có ở `boDemMaVu`, đúng thiết kế), 4 hàm RPC tồn tại và BIÊN
DỊCH ĐÚNG (giải quyết dứt điểm phần "chưa kiểm chứng" ghi ở `supabase/README.md` — trước đó chỉ
parse-check cú pháp ngoài, chưa biết phần thân `plpgsql` có lỗi runtime/biên dịch không).

**Đã kiểm thử CHỨC NĂNG thật (14 assertion, dữ liệu tự tạo rồi dọn sạch ngay sau)**:
- `sinhMaVuAnMoi('9901')` gọi 2 lần liên tiếp → đúng `..._0001` rồi `..._0002`.
- `sinhNhieuMaVuAn(['9902','9902','9903','9902','9903'])` → đúng gộp riêng từng nhóm YYMM, số thứ
  tự liên tục trong CÙNG nhóm bất kể xen kẽ vị trí (`9902` ra `0001/0002/0003`, `9903` ra
  `0001/0002`) — xác nhận logic nhóm theo tháng hoạt động đúng như file gốc Firestore.
- `tachVuSinhMa` gọi 2 lần trên cùng 1 vụ giả → đúng hậu tố `_1` rồi `_2`.
- `capNhatDieuLuatVaLoaiKhoiTo` với 2 bị can giả (1 người khởi tố sớm hơn, tội danh khác nhau) →
  đúng gán `ban_dau`/`bo_sung` theo ngày khởi tố sớm nhất, `vuan.dieuLuat` gộp đúng cả 2 tội danh
  (nối `"; "`), cache `soBiCan`/`biCanDaiDien` cập nhật đúng.

**Đã kiểm chứng RLS qua ĐÚNG cổng ứng dụng thật sẽ dùng** (REST API/PostgREST bằng `curl` +
`anon key`, KHÔNG phải qua kết nối Postgres trực tiếp — kết nối đó chạy role `postgres` (superuser)
nên KHÔNG bị RLS chặn, test qua đó sẽ cho kết quả giả-đúng): `GET /rest/v1/vuan` bằng anon key trả
`200` (bảng đang trống); `POST /rest/v1/vuan` (thử ghi) bằng anon key bị chặn rõ ràng — `HTTP 401`,
lỗi Postgres `42501 "new row violates row-level security policy for table vuan"` — đúng ngữ nghĩa
"chưa đăng nhập (role anon, chưa phải authenticated) thì không ghi được", khớp hành vi
`request.auth != null` của Firestore rules cũ.

**Về credential**: mật khẩu DB (Session pooler) chỉ dùng tạm trong script test/áp dụng schema ở
thư mục scratchpad (ngoài repo), KHÔNG được ghi vào bất kỳ file nào trong git. `anon key` (đã nhận
từ Dũng) là loại key công khai-an-toàn theo thiết kế của Supabase (được RLS bảo vệ, giống hệt vai
trò `apiKey` của Firebase đã nhúng thẳng trong `qlva.html` từ trước) — sẽ nhúng vào `qlahs-sup.html`
khi viết lớp shim ở Phase 2, không cần giữ bí mật ở mức độ như mật khẩu DB.

### 4d. Lớp shim (Phase 2) — ĐÃ VIẾT + KIỂM CHỨNG ĐẦY ĐỦ bằng dữ liệu thật (2026-07-19)

Viết trong `qlahs-sup.html`: bỏ hẳn 3 script CDN Firebase, thay bằng 1 script
`@supabase/supabase-js@2` (UMD). Khối cấu hình cũ (`firebase.initializeApp`, `db.enablePersistence`)
thay bằng lớp shim đầy đủ — chi tiết kỹ thuật đã ghi trong comment đầu khối `<script>` của chính
file đó (không lặp lại ở đây), tóm tắt:
- `db.collection(name).where/orderBy/limit/startAfter().get()/.onSnapshot()`, `.doc(id?)`, `.add()`.
- `db.batch()` → `set/update/delete` → `commit()`.
- `firebase.firestore.FieldValue.{serverTimestamp,arrayUnion}`/`FieldPath.documentId()` giữ nguyên
  API cũ (shim tự định nghĩa lại, không phải SDK Firebase thật) — ~35 chỗ gọi trong code KHÔNG cần
  sửa gì.
- 4 vị trí `db.runTransaction` (sinh mã vụ án, sinh mã hàng loạt, sinh mã tách vụ, tính lại điều
  luật/loại khởi tố) sửa tay gọi thẳng `sb.rpc(...)` — đúng thiết kế mục 3, không đi qua shim chung.

**Bug thật tìm được + đã sửa qua Playwright test** (không phải giả thuyết): `batch.commit()` bản
đầu gộp insert theo BẢNG NÀO GẶP TRƯỚC trong danh sách thao tác — đúng với Firestore (không có FK,
thứ tự không quan trọng) nhưng **SAI với Postgres có FK thật**: `ThemVuAnForm` ghi log
`khoi_to_bican` (tham chiếu `bican.id`) XEN GIỮA các lần `batch.set()` tạo bị can, không phải tạo
hết bị can rồi mới ghi log — batch cũ chèn `lichsuChuyenGiaiDoan` TRƯỚC KHI `bican` tồn tại, lỗi
`23503 FK violation`. Đã sửa: thêm `_TABLE_INSERT_ORDER` (thứ tự phụ thuộc cố định: kybaocao/canbo/
danhMucToiDanh/meta → vuan → bican → phienGiaoNhan → lichsuChuyenGiaiDoan), `commit()` LUÔN insert
theo đúng thứ tự này bất kể thứ tự gọi `.set()` trong code ứng dụng.

**Phát hiện hạ tầng khác**: Supabase Realtime **KHÔNG tự bật cho bảng mới** — phải
`ALTER PUBLICATION supabase_realtime ADD TABLE "..."` cho từng bảng (đã làm cho cả 8 bảng), nếu
không `onSnapshot()` chỉ bắn được lần đầu (từ `.get()`), không bao giờ bắn lại khi có thay đổi.

**Đã kiểm chứng bằng Playwright thật, dữ liệu thật trên project `eutatszoaseixchvjbtg`** (17
assertion qua 3 kịch bản độc lập, không phải mock):
1. Đăng nhập qua shim Auth (Supabase Auth thật, user `admintest@local.com` đã tạo ở Phase 1) → vào
   được màn hình chính.
2. Test trực tiếp các thao tác nguyên thuỷ của shim qua `page.evaluate()` (13 assertion): doc
   set/get/delete; where nhiều điều kiện lọc đúng không lẫn; batch set+update+delete cùng lúc;
   **onSnapshot bắn ngay lần đầu + bắn lại đúng qua Realtime thật sau khi có thay đổi** (xác nhận
   cơ chế "refetch khi có bất kỳ thay đổi nào" hoạt động đúng); RPC `sinhMaVuAnMoi` sinh mã tăng
   dần đúng qua 2 lần gọi liên tiếp với YYMM ngẫu nhiên (tránh đụng dữ liệu cũ giữa các lần chạy
   test).
3. **Luồng UI THẬT đầy đủ** (4 assertion): mở form "Thêm vụ án" → điền Ngày QĐ KTVA + họ tên bị can
   → bấm "Lưu vụ án" → xác nhận modal "Tính vào kỳ báo cáo nào?" → form tự đóng đúng (không kẹt do
   lỗi) → vụ án xuất hiện lại trên Danh sách vụ án. Đối chiếu trực tiếp qua Postgres xác nhận ĐÚNG
   toàn bộ chuỗi dữ liệu: `vuan` (mã đúng định dạng `QLVA_E01.53_2601_0001`, `soBiCan`/
   `biCanDaiDien` cache tính đúng), `bican` (FK đúng), `lichsuChuyenGiaiDoan` (2 sự kiện
   `khoi_to_vu`+`khoi_to_bican`, đúng liên kết), `meta` sentinel (`capNhatLuc` cập nhật đúng qua
   `.set(..., {merge:true})`/upsert).
0 lỗi console thật xuyên suốt cả 3 kịch bản (đã lọc riêng 1 lỗi lệch giờ JWT do đồng hồ hệ thống
sandbox test — xem đoạn dưới — không phải bug code). Toàn bộ dữ liệu test đã dọn sạch sau khi xong
(cả 8 bảng về lại 0 dòng), project sẵn sàng cho bước nạp mock data thật (Phase 4).

**Giới hạn môi trường test đã ghi nhận (không phải bug)**: sandbox chạy Playwright có đồng hồ hệ
thống khớp ngày kịch bản phiên làm việc (`2026-07-19`), sớm/lệch so với giờ thực server Supabase —
occasionally khiến Realtime từ chối JWT với lỗi `PGRST303 "JWT issued at future"` (khắt khe hơn hẳn
REST API/Auth — những API đó không gặp vấn đề này suốt cả phiên). Chạy lại nhiều lần xác nhận đây
là vấn đề BIÊN/không nhất quán (có lần fail có lần pass), không phải lỗi logic — cơ chế refetch
dùng lại đúng code `.get()` đã test PASS ổn định. Nên re-test Realtime 1 lần nữa trên trình duyệt
thường (đồng hồ hệ thống đúng giờ thực) trước khi hoàn toàn tin tưởng, dù bằng chứng hiện tại đã
khá thuyết phục.

**CHƯA làm ở phiên này (cố tình để dành riêng)**: checklist mục 5 (rà lại các cơ chế né-chi-phí-
Firestore) — quyết định KHÔNG làm chung với việc viết shim, vì đây là 2 loại thay đổi khác hẳn nhau
về rủi ro: viết shim là "giữ nguyên hành vi ứng dụng, chỉ đổi tầng dưới" (rủi ro thấp, đã kiểm chứng
kỹ ở trên); còn checklist mục 5 là "chủ động đổi HÀNH VI ứng dụng" (bỏ live listener đóng băng, đổi
UX phân trang...) — trộn chung 2 việc sẽ khó tách bạch khi có lỗi phát sinh là do đâu. Làm riêng ở
phiên sau, với đúng bộ test hồi quy tương ứng cho từng mục.

## 5. Checklist: rà lại các "tinh chỉnh vì Firebase" — KHÔNG mang nguyên xi sang Supabase

**Theo yêu cầu rõ ràng của Dũng** (2026-07-19): đây không còn là gợi ý tuỳ chọn — Phase 2 phải
CHỦ ĐỘNG rà từng cơ chế dưới đây, quyết định giữ/bỏ/đơn giản hoá cho ĐÚNG với mô hình Supabase, chứ
không lặp lại y nguyên các "tinh chỉnh" vốn sinh ra chỉ để né chi phí đọc/listener của Firestore.
Toàn bộ danh sách dưới đây lấy từ lịch sử thật đã ghi trong `CLAUDE.md` (các mục "Tối ưu
Firestore..."), không suy đoán. Với MỖI mục, việc cần làm ở Phase 2 là: đọc lại code hiện tại,
quyết định 1 trong 3 hướng (**bỏ hẳn** quay về cách đơn giản/trực tiếp nhất; **giữ nguyên** nếu vẫn
có lý do chính đáng KHÁC ngoài chi phí Firestore, VD trải nghiệm người dùng; **đơn giản hoá** giữ
lại lợi ích cốt lõi nhưng bỏ phần phức tạp thừa) — rồi TEST LẠI đúng kịch bản Playwright tương ứng
đã có sẵn cho từng tính năng đó trước khi coi là xong.

- [ ] **`firestoreCacheRegistry`/`useFirestoreCollectionCache`** (listener dùng chung, ref-count +
      grace-period 3 phút cho `danhMucToiDanh`/`canbo`/`kybaocao`) — dựng ra CHỈ để gộp nhiều
      component thành 1 listener Firestore duy nhất, né phí nhân theo số component subscribe cùng
      lúc. Supabase Realtime KHÔNG tính phí theo kiểu này — đánh giá bỏ hẳn lớp registry, mỗi
      component tự subscribe thẳng qua shim, đơn giản hoá code đáng kể.
- [ ] **Sentinel `meta/vuAnMoiNhat`** + `dsDangGiaiQuyetRegistry`/`useDanhSachDangGiaiQuyet` (danh
      sách "đang giải quyết" KHÔNG live, chỉ tự làm mới qua tín hiệu sentinel bé xíu) — dựng ra để
      né 1 listener sống trên cả trăm vụ án. Đánh giá bỏ sentinel, subscribe Realtime thẳng trên
      bảng `"vuan"` lọc `trangThai='dang_giai_quyet'` — quay lại đúng UX "live thật" ban đầu mà
      Firestore không cho phép làm rẻ.
- [ ] **Cache lạnh IndexedDB cho "Án đã giải quyết"** (`dongBoColdCacheVuAnDaGiaiQuyet`, đồng bộ
      delta qua `ngayCapNhat > lastSync`, không dùng `onSnapshot`) — cân nhắc RIÊNG với 2 mục trên:
      lợi ích "cache bền qua lần tải trang" của IndexedDB vẫn có giá trị dưới Supabase (giảm round-
      trip mạng, không liên quan gì tới tiền), có thể GIỮ nhưng đơn giản hoá phần đồng bộ delta thủ
      công bằng Realtime subscription thật nếu muốn.
- [ ] **Cursor pagination "đóng băng trang đầu sau khi bấm Tải thêm"** (tab "Tất cả" của Danh sách
      vụ án — chủ động BỎ live update sau lần phân trang đầu, đổi lấy việc không phải đọc lại từ
      đầu) — đây là đánh đổi UX THẬT (mất tính năng) chỉ để né phí, không phải kỹ thuật phân trang
      hiệu quả (kỹ thuật cursor/keyset pagination bản thân nó vẫn nên giữ, chỉ riêng phần "bỏ live"
      là do chi phí). Đánh giá khôi phục live qua Realtime, giữ nguyên cách phân trang.
- [ ] **`fetchWithTtlCache`** (TTL cache 1 lần cho `NhapVuModal` tìm vụ đích) — tương tự cache lạnh
      ở trên, giữ được nếu có lý do UX riêng (tránh đọc lại khi mở/đóng modal nhanh), không bắt
      buộc bỏ.
- [ ] **Loạt quyết định "hot data không cần live" khác** (`BangBiCanCon`, `BangExcelModule`, cột Kỳ
      của `DanhSachPanel`... đổi từ `onSnapshot` sang `.get()` một lần, chấp nhận dữ liệu cũ tới
      khi remount) — rà lại TỪNG cái, hỏi "đây có phải công cụ 1-người-thao-tác-tại-1-thời-điểm
      hay màn hình nhiều người cùng xem" — nếu là loại sau, cân nhắc khôi phục live vì Supabase
      không phạt việc đó về chi phí như Firestore.
- [ ] **Kỹ thuật né composite index thủ công** (VD sort phía client thay vì `orderBy` + index cho
      `phienGiaoNhan`/`lichsuChuyenGiaiDoan`, tránh phải deploy index Firestore mới) — Postgres tạo
      index rẻ, không cần bước "deploy" riêng như Firestore — cân nhắc bỏ hẳn workaround, dùng
      thẳng `ORDER BY` + index Postgres đã có sẵn trong `schema.sql`.

**KHÔNG nằm trong checklist này** (giữ nguyên, không phải "tinh chỉnh vì chi phí"):
`db.enablePersistence` (offline persistence) — đây là tính năng THẬT (chống mất mạng tạm thời),
không phải né chi phí, xử lý riêng ở Phase 5 (mục 7) như đã ghi; giới hạn 30-item của `where(...,
"in", ...)` và batch 400-item — đây là RÀNG BUỘC KỸ THUẬT của Firestore tự biến mất khi qua
Postgres (đã ghi ở mục 3), không phải quyết định thiết kế cần "rà lại", chỉ cần xoá code chia lô
tương ứng trong lớp shim.

## 6. Kế hoạch export/import dữ liệu thật

**Cập nhật phạm vi (xem mục 4c)**: hiện chỉ có 1 project Supabase (`eutatszoaseixchvjbtg`), dự định
nạp dữ liệu MOCK kéo từ Firestore `qlahs-test` trước (không phải dữ liệu thật `qlahsp2`) để phát
triển/kiểm thử shim, rồi **reset lại** project này trước khi thật sự cần dữ liệu production —
nghĩa là bước import "dữ liệu thật `qlahsp2`" chỉ thực hiện 1 LẦN DUY NHẤT, ngay trước khi cắt hẳn
sang Supabase (cuối Phase 6), không lặp lại nhiều vòng test như dự tính ban đầu.

1. **Export**: script đọc toàn bộ 7 collection nghiệp vụ (không cần export `boDemMaVu`/`meta`) →
   dump JSON, 1 file/collection. Làm trên `qlahs-test` trước (làm mock data cho project Supabase
   hiện có).
2. **Transform**: chuẩn hoá kiểu dữ liệu (Timestamp → ISO string cho `timestamptz`), cộng các phép
   chuyển đổi cụ thể phát hiện ở mục 4b (gộp `blhsNam`→`namBLHS`, loại bỏ 4 giá trị `loaiSuKien`
   dead nếu gặp, không cần tách mảng `toiDanh`/`dieuLuatBC` vì schema giữ nguyên dạng cột mảng).
3. **Import**: dùng **Session pooler** (đã xác nhận hoạt động ở mục 4c — Direct connection KHÔNG
   dùng được từ môi trường thực thi hiện tại do chỉ hỗ trợ IPv6) — `psql`/COPY hoặc script Node
   dùng driver `pg`, nhanh hơn nhiều so với qua REST cho khối lượng ~1400 vụ + ~2250 bị can + hàng
   nghìn dòng log.
4. **Đối chiếu**: so số dòng theo từng bảng, VÀ chạy lại các phép kiểm tra nghiệp vụ đã có (VD
   tổng số liệu Biểu B10 của 1 kỳ đã chốt phải khớp giữa Firestore cũ và Postgres mới).
5. **Reset trước khi lên thật**: trước khi import dữ liệu `qlahsp2` thật ở Phase 6, xoá sạch dữ
   liệu mock đã nạp ở bước trên (giữ nguyên schema/RLS/RPC, chỉ xoá rows) — đúng ý định "reset lại
   khi hoàn thiện" Dũng đã nêu.

## 7. Lộ trình theo giai đoạn

- [x] **Phase 0**: tạo nhánh `supabase-migration`, viết tài liệu kế hoạch này. Chưa đụng code ứng
      dụng.
- [x] **Phase 1**: `supabase/schema.sql` + `rls.sql` + `functions.sql` đã viết, ÁP DỤNG THÀNH CÔNG
      lên project Supabase thật (`eutatszoaseixchvjbtg`) và KIỂM CHỨNG chức năng đầy đủ (14
      assertion RPC + RLS xác nhận qua REST API thật) — xem mục 4c. Không còn việc "chưa kiểm
      chứng" nào ở bước schema nữa.
- [~] **Phase 2** (lớp shim ĐÃ VIẾT + KIỂM CHỨNG ĐẦY ĐỦ bằng dữ liệu thật, checklist mục 5 CHƯA
      làm — xem mục 4d bên dưới) — viết trong `qlahs-sup.html`: CDN Firebase (3 script) đổi sang
      1 script `@supabase/supabase-js`, khối cấu hình cũ thay bằng lớp shim đầy đủ (`db`/`auth`
      giả lập, `firebase.firestore.FieldValue/FieldPath` giữ nguyên API cho ~35 chỗ gọi cũ không
      cần sửa), 4 vị trí `db.runTransaction` sửa tay gọi `.rpc(...)`. **Còn thiếu**: checklist mục
      5 (rà lại các cơ chế né-chi-phí-Firestore — sentinel/cache-registry/cursor-pagination-đóng-
      băng...) CHƯA làm ở phiên này, cố tình để dành làm riêng (xem lý do ở mục 4d) — Phase 2 CHƯA
      được coi là xong hoàn toàn cho tới khi checklist đó cũng xong.
- [ ] **Phase 3**: chuyển Auth sang Supabase Auth — tài khoản Firebase Auth hiện có phải tạo lại
      thủ công trên Supabase (không tự động chuyển mật khẩu giữa 2 hệ thống được).
- [ ] **Phase 4**: export dữ liệu thật từ `qlahs-test` (Firestore) → import làm MOCK DATA vào
      project Supabase hiện có (xem mục 6, đã cập nhật phạm vi — không phải "cả 2 project" như bản
      gốc, chỉ 1 project cho tới khi lên thật).
- [ ] **Phase 5**: kiểm thử toàn diện trên project Supabase hiện có (đủ bộ Playwright hồi quy hiện
      có + kịch bản mới cho Realtime/RPC), quyết định hướng xử lý khoảng trống offline persistence.
- [ ] **Phase 6**: **reset project Supabase** (xoá dữ liệu mock, giữ schema/RLS/RPC) → export/import
      dữ liệu thật `qlahsp2`, đối chiếu số liệu kỹ, cắt sang production. Giữ Firestore ở chế độ
      đọc-only 1 thời gian làm lưới an toàn trước khi ngừng hẳn.

## 8. Trạng thái hiện tại

**Phase 1 xong hoàn toàn** (schema/RLS/RPC áp dụng + kiểm chứng thật, mục 4c). **Phase 2 (lớp shim)
đã viết xong + kiểm chứng đầy đủ bằng dữ liệu thật** (17 assertion, gồm 1 luồng UI thật trọn vẹn
"Thêm vụ án" → RPC sinh mã → batch ghi đúng thứ tự phụ thuộc → đọc lại đúng, xem mục 4d) — 1 bug
FK-ordering thật đã tìm ra và sửa qua chính quá trình test này. `qlahs-sup.html` hiện chạy được
đầy đủ trên nền Supabase (KHÔNG còn phụ thuộc Firebase gì, kể cả CDN script). Toàn bộ dữ liệu test
đã dọn sạch — project Supabase đang ở trạng thái sạch (0 dòng mọi bảng), sẵn sàng nạp mock data.

**Còn thiếu để coi Phase 2 xong HOÀN TOÀN**: checklist mục 5 (rà lại các cơ chế né-chi-phí-Firestore
— sentinel/cache-registry/cursor-pagination-đóng-băng...) CHƯA làm, cố tình để riêng (xem lý do ở
cuối mục 4d).

**Việc tiếp theo** (thứ tự khuyến nghị):
1. Chạy checklist mục 5 — rà từng mục, quyết định giữ/bỏ/đơn giản hoá, test lại đúng kịch bản
   tương ứng. Nên làm trên `qlahs-sup.html` (đã có nền shim hoạt động đúng) trước khi coi Phase 2
   xong hẳn.
2. Viết script export Firestore `qlahs-test` → import Supabase làm mock data (Phase 4), dùng lại
   đúng Session pooler đã xác nhận hoạt động (mục 4c) — nhớ `ALTER PUBLICATION supabase_realtime
   ADD TABLE` KHÔNG cần chạy lại (đã bật sẵn cho cả 8 bảng, xem mục 4d).
3. Kiểm thử qua `qlahs-sup.html` với dữ liệu mock đó trước khi tính tới bước reset + dữ liệu thật.
4. Chuyển Auth sang Supabase Auth thật cho toàn bộ tài khoản cán bộ (Phase 3 — hiện chỉ có đúng 1
   tài khoản test `admintest@local.com` phục vụ phát triển/kiểm thử, chưa phải danh sách thật).
