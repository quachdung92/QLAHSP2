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

**Cập nhật (cùng ngày, ngay sau khi viết xong shim)**: đã LÀM 2/7 mục checklist ở mục 5 (mục 1 và
2) trong CHÍNH phiên này — ban đầu định để dành hẳn "phiên sau" (xem đoạn dưới, còn giữ nguyên vì lý
do tách bạch rủi ro vẫn đúng cho phần còn lại), nhưng vì `qlahs-sup.html` đã có nền shim chạy ổn
định + bộ test đã dựng sẵn, làm luôn 2 mục có giá trị rõ nhất trong khi bối cảnh còn "nóng" hợp lý
hơn hoãn lại. Kết quả và bug tìm được ghi ở mục 5 (đã đánh dấu `[x]`), không lặp lại ở đây.

Lý do gốc (vẫn áp dụng cho 5 mục còn lại `[ ]`): viết shim là "giữ nguyên hành vi ứng dụng, chỉ đổi
tầng dưới" (rủi ro thấp); checklist mục 5 là "chủ động đổi HÀNH VI ứng dụng" (bỏ live listener đóng
băng, đổi UX phân trang...) — cần tách bạch để dễ khoanh vùng nếu có lỗi phát sinh.

**Cập nhật lần 4 (cùng ngày) — CHECKLIST MỤC 5 ĐÃ RÀ XONG 7/7 MỤC.** Kết quả cuối:
- **2 mục bỏ hẳn** (code đơn giản hoá thật sự): `firestoreCacheRegistry`, sentinel
  `meta/vuAnMoiNhat`.
- **1 mục sửa 1 phần** (bỏ 30-item chunking + lọc filter server-side): kỹ thuật né composite
  index.
- **4 mục rà kỹ rồi QUYẾT ĐỊNH GIỮ NGUYÊN**, mỗi mục có lý do cụ thể độc lập với chi phí Firestore
  (không phải "chưa làm"/bỏ sót — xem chi tiết từng mục ngay dưới): cursor pagination đóng băng
  (tránh race tính đúng đắn), cache lạnh IndexedDB (lý do sản phẩm đã thống nhất từ trước, không
  chỉ chi phí), `fetchWithTtlCache` (hộp thoại tìm-chọn ngắn, không cần realtime),
  `BangBiCanCon`/`BangExcelModule`/cột Kỳ `DanhSachPanel` (công cụ 1 người + giới hạn filter thật
  của Supabase Realtime khiến "khôi phục live" phản tác dụng ở đúng màn hình đông người xem nhất).

**Bài học rút ra sau khi rà hết 7 mục**: không phải MỌI cơ chế "tránh live/tránh đọc lại" trong
code cũ đều thuần tuý vì chi phí Firestore như giả định ban đầu của checklist này — nhiều cơ chế
có LỚP LÝ DO THỨ 2 (tính đúng đắn, UX công cụ 1-người, giới hạn kỹ thuật của chính Realtime) mà chỉ
lộ ra khi đọc kỹ code thay vì suy đoán từ tên gọi. Giá trị thật của checklist này không phải "xoá
càng nhiều càng tốt" mà là XÁC NHẬN LẠI từng quyết định — 2/7 mục xoá được thật, 5/7 còn lại vẫn
đúng và giờ có lý do ghi rõ ràng hơn bản gốc.

### 4e. Phase 4 — export/import dữ liệu thật `qlahs-test` làm mock data — ĐÃ HOÀN TẤT (2026-07-19)

Script nằm ngoài repo (thư mục scratchpad phiên làm việc, không commit — thuần công cụ chạy 1 lần,
không phải phần code sản phẩm): `export_firestore.js` (Playwright, đăng nhập thật
`qlahs-test.web.app`/`admintest@local.com`, đọc qua `db.collection(...).get()` — không cần Admin
SDK/service account), `validate_export.js` (đối chiếu mọi tham chiếu kiểu FK giữa các collection
JSON đã export, chạy TRƯỚC import để biết trước có dữ liệu mồ côi hay không), `import_to_supabase.js`
(transform + insert qua Session pooler, thứ tự bảng đúng `_TABLE_INSERT_ORDER` của shim).

**Export**: 9354 document/7 collection — `vuan`=1386, `bican`=2252, `lichsuChuyenGiaiDoan`=5068,
`kybaocao`=6, `canbo`=10, `danhMucToiDanh`=586, `phienGiaoNhan`=46. `validate_export.js` xác nhận
**0 tham chiếu treo** (mọi `maVuAn`/`maBiCan`/`vuTachRa`/`vuNhapVao`/`kyThongKe`/`phienGiaoNhanId`
đều trỏ tới document còn tồn tại) — dữ liệu nguồn tự nhất quán trước khi import.

**3 lỗi CHECK constraint thật gặp phải khi import** (Postgres ép kiểu/ràng buộc nghiêm ngặt hơn hẳn
Firestore schemaless — mỗi lỗi chỉ lộ ra khi thử import THẬT, không đoán trước được từ đọc code):
1. `vuan.daXoa` NOT NULL nhưng THIẾU HẲN trên toàn bộ 1386 dòng thật (field mới thêm gần đây, dữ
   liệu cũ chưa có) → fallback `false`.
2. `vuan.anDiem`/`nguon` mang giá trị "rác" trên ĐÚNG CÙNG 70/1386 dòng (`anDiem: ""` thay vì
   boolean thật, `nguon: "cq_dieu_tra"` không nằm trong 4 giá trị `NHAN_NGUON` hiện tại của code) —
   rõ ràng cùng 1 nguồn dữ liệu cũ/quirk chung. Ép `""` → `false` cho mọi cột boolean; `nguon` lạ
   map về DEFAULT schema (`an_khoi_to_moi`) — **quyết định CHỈ ĐÚNG cho dữ liệu mock/test này**, dữ
   liệu thật `qlahsp2` ở Phase 6 phải hỏi lại Dũng ý nghĩa thật của `cq_dieu_tra` trước khi map,
   không lặp lại suy đoán này.
3. `bican.bienPhapNganChan` giá trị cũ `"tam_giam"` (91/2252 dòng, tên trước khi đổi mã ngắn
   `"giam"` — khớp 1-1 rõ ràng qua nhãn `<option value="giam">Tạm giam</option>` trong code hiện
   tại, KHÁC hẳn trường hợp `nguon` ở trên vì đây không phải đoán mà là đổi tên field value thuần
   tuý) → rename thẳng.
4. `bican.loaiKhoiTo` giá trị cũ **KHÔNG HỢP LỆ** `"khoi_to_moi"` (123/2252 dòng — đúng bug
   `BackfillLoaiKhoiToTool` trong `qlva.html` đã tài liệu hoá: `ImportExcelModule` cũ từng hardcode
   sai giá trị này). Vì đây là field TỰ TÍNH (không nhập tay), script **tính lại đúng bằng thuật
   toán `tinhLoaiKhoiToTheoNgay` của chính app** (theo từng vụ: bị can có `ngayKhoiTo` NHỎ NHẤT =
   `ban_dau`, còn lại `bo_sung`) thay vì map bừa — áp dụng cho TOÀN BỘ 2252 bị can (không chỉ 123
   dòng sai) để đảm bảo nhất quán theo từng vụ, đúng những gì `BackfillLoaiKhoiToTool` sẽ làm nếu
   chạy trên dữ liệu này. Kết quả: 100% ra `ban_dau` — đã xác nhận đây là ĐÚNG (không phải bug mới):
   kiểm tra riêng cho thấy trong 242 vụ có ≥2 bị can, **0 vụ có `ngayKhoiTo` khác nhau giữa các bị
   can** (mọi bị can cùng vụ luôn bị khởi tố cùng ngày trong tập dữ liệu thật này) — nên
   `tinhLoaiKhoiToTheoNgay` cho ra toàn `ban_dau` là kết quả toán học đúng, không phải lỗi transform.
5. `lichsuChuyenGiaiDoan.lyDoTach` giá trị cũ `"manual"` (1 dòng — code bản cũ trước khi
   `TachVuModal` có dropdown lý do, hiện chỉ `'khac_toi_danh'`/`'khac'`) → map về `"khac"` (không rõ
   lý do cụ thể, cùng nhóm "quyết định chỉ đúng cho mock data" như `nguon` ở trên).

**Import cuối cùng: THÀNH CÔNG 100%, đúng khớp số dòng export** (0 dòng nào bị bỏ qua/rớt):
`kybaocao`=6, `canbo`=10, `danhMucToiDanh`=586, `vuan`=1386, `bican`=2252, `phienGiaoNhan`=46,
`lichsuChuyenGiaiDoan`=5068 — 71 ô tổng cộng bị remap theo whitelist (70 `nguon` + 1 `lyDoTach`,
đúng số dòng "rác" phát hiện ở trên).

**Spot-check dữ liệu sau import** (đúng tinh thần mục 6: kiểm DỮ LIỆU, không phải "đối chiếu B10"):
`canbo.vaiTro` phân bố hợp lý (5 ksv/4 dtv/1 can_bo_thong_ke, không còn field `chucVu` cũ); FK
sanity (`bican`→`vuan`, `lichsuChuyenGiaiDoan`→`vuan`) 0 dòng mồ côi; `vuan.daXoa`/`anDiem` toàn bộ
boolean hợp lệ; `bican.bienPhapNganChan` chỉ còn 2 giá trị hợp lệ (`giam`=722, `tai_ngoai`=1530,
hết `tam_giam`). Ghi chú: dòng `vuan` mới nhất trong mock data là 1 vụ tên "VU TEST PLAYWRIGHT XOA
SAU..." — rác còn sót từ 1 lần test Playwright cũ chạy thẳng trên Firestore `qlahs-test` (không
phải lỗi migration, dữ liệu môi trường test vốn không sạch tuyệt đối — chấp nhận được vì đây đúng
là mock/test data, không phải production).

Toàn bộ 5 quyết định transform ở trên (trừ #3 rename `tam_giam`→`giam`, là đổi tên value 1-1 chắc
chắn) đều là **quyết định phù hợp cho MOCK DATA**, KHÔNG áp dụng máy móc lại cho Phase 6 (dữ liệu
`qlahsp2` thật) — Phase 6 phải hỏi lại Dũng ý nghĩa từng giá trị "rác" cụ thể tìm thấy lúc đó trước
khi quyết định map/backfill/bỏ qua, vì đây là dữ liệu án hình sự thật, không được đoán.

### 4f. Kiểm thử qua UI thật với mock data — phát hiện + sửa 2 bug thật của SHIM (không phải lỗi
dữ liệu) (2026-07-19)

Sau khi import xong (mục 4e), mở `qlahs-sup.html` qua Playwright (đăng nhập thật, không mock) để
xác nhận dữ liệu hiển thị đúng qua UI — đúng bước "Việc tiếp theo #1" đã ghi ở mục 8. Phát hiện 2
lỗi THẬT của lớp shim (Phase 2), cả 2 đều chỉ lộ ra khi test với khối lượng dữ liệu thật đủ lớn
(mock nhỏ ở Phase 2 không đủ để kích hoạt) — đã sửa cả 2 trực tiếp trong `qlahs-sup.html`:

**Bug 1 — PostgREST "Max Rows" cấp project cắt ÂM THẦM mọi query không có `.limit()` tường minh ở
1000 dòng.** Phát hiện qua: tab "Đang giải quyết" đúng 55/55 dòng (khớp DB) nhưng module "Án đã
giải quyết" ban đầu tưởng lỗi (0 dòng) — hoá ra do mặc định lọc theo kỳ hiện tại (đúng thiết kế,
không phải bug) — nhưng khi đổi kỳ lọc sang "Tất cả", `where(trangThai,"!=","dang_giai_quyet")`
(1331 dòng thật trong DB) chỉ trả về **1000** dù đã thử ép `.range(0,1999)`/`.limit(2000)` — xác
nhận qua test trực tiếp: `count` (exact, PostgREST tính đúng) = 1331 nhưng `data.length` luôn dừng
ở 1000 bất kể tham số client gửi lên → là giới hạn **SERVER-SIDE** (cấu hình "Max Rows" của chính
project Supabase, không phải giá trị client có thể vượt qua). Khác hẳn Firestore: `.get()` không
`.limit()` luôn trả về TOÀN BỘ document khớp điều kiện — nhiều nơi trong code gốc (VD
`AnDaGiaiQuyetModule` không giới hạn số vụ đã giải quyết) dựa đúng vào hành vi này.
**Đã sửa** (`qlahs-sup.html`, hàm `get()` trong `_makeQuery`): khi KHÔNG có `.limit()` tường minh,
tự động phân trang qua nhiều lần `.range()` (trang 500 dòng, dưới ngưỡng cắt 1000 đã xác nhận, chừa
biên an toàn) rồi nối kết quả lại — không phụ thuộc con số "Max Rows" cụ thể (an toàn dù cấu hình
server đổi khác sau này, không cần biết trước ngưỡng chính xác). Cần thứ tự ổn định để phân trang
đúng (tránh lặp/bỏ sót dòng giữa các trang) — nếu code gọi không tự `orderBy`, ngầm thêm
`orderBy("id")` chỉ cho việc phân trang, không đổi field lọc/tập kết quả trả về. Tách logic dựng
query PostgREST ra hàm dùng chung `_buildPgQuery` (dùng bởi cả đường `.limit()` tường minh lẫn vòng
lặp phân trang, tránh viết trùng 2 lần).
**Đã kiểm chứng**: query trực tiếp `where(trangThai,"!=","dang_giai_quyet")` sau sửa trả ĐÚNG 1331
dòng, không trùng lặp ID (`1331 unique` trên `1331 tổng`); qua UI thật, 5 tab "Án đã giải quyết"
(kỳ=Tất cả) cộng đúng khớp DB: Đã xét xử=574, Chuyển đi=1, Tạm đình chỉ=752, Đình chỉ=2, Án huỷ=1
(tổng 1330 + 1 vụ `da_nhap` không thuộc tab nào = 1331). Chạy lại TOÀN BỘ 6 file test hồi quy đã có
của Phase 2 (`test_sup_shim`/`test_sup_index_avoid`/`test_sup_e2e`/`test_sup_in_over30`/
`test_sup_realtime_list`/`test_sup_ui_flow`, 32 assertion) — không có gì bị phá vỡ bởi thay đổi này.

**Bug 2 — `boDemMaVu` (bộ đếm sinh mã vụ án mới qua RPC `sinhMaVuAnMoi`) chưa được seed từ dữ liệu
đã import, gây TRÙNG MÃ VỤ khi tạo vụ án mới qua UI.** Phát hiện qua `test_sup_ui_flow.js` (luồng
"Thêm vụ án" thật qua UI) fail với lỗi Postgres `23505 duplicate key value violates unique
constraint "vuan_pkey"`. Nguyên nhân: RPC `sinhMaVuAnMoi(yymm)` sinh SEQ tiếp theo bằng cách
`INSERT ... ON CONFLICT (yymm) DO UPDATE soHienTai+1` — nếu bảng `boDemMaVu` CHƯA có dòng nào cho
`yymm` đó thì bắt đầu từ `0001`, dù dữ liệu import đã có sẵn `QLVA_E01.53_2607_0001`...`_0025` (xác
nhận trực tiếp qua SQL: tháng "2607" có đủ 25 vụ đã import, nhưng `boDemMaVu` chỉ có 2 dòng — leftover
từ các lần test RPC trước đó dùng YYMM ngẫu nhiên, không liên quan tháng thật nào trong mock data).
**Đã sửa 2 nơi**: (1) chạy 1 lần script seed trực tiếp lên DB hiện có — quét mọi `vuan.id` khớp
pattern mã CƠ BẢN (`^QLVA_E01\.53_\d{4}_\d{4}$`, CỐ Ý loại trừ mã có hậu tố tách vụ `_N` — hậu tố đó
dùng field `soDemTach` trên chính vụ gốc, không tiêu tốn số thứ tự của `boDemMaVu`, xem schema.sql),
nhóm theo `yymm`, upsert `soHienTai = GREATEST(hiện có, số lớn nhất tìm thấy)` — an toàn chạy lại
nhiều lần (idempotent, dùng `GREATEST` nên không bao giờ lùi số xuống); (2) thêm CHÍNH logic này vào
cuối `import_to_supabase.js` (sau bước xác nhận số dòng) để mọi lần import sau này (kể cả Phase 6
với dữ liệu `qlahsp2` thật) tự động seed đúng, không lặp lại việc quên bước này.
**Đã kiểm chứng**: seed 1 lần lên DB hiện có (65 tháng có vụ án, VD `2607: soHienTai=25`), chạy lại
`test_sup_ui_flow.js` → PASS 4/4 (trước đó FAIL 3/4 với đúng lỗi `23505`) — vụ án mới tạo qua UI
đúng nhận mã `QLVA_E01.53_2607_0026`, không còn trùng.

**Bài học chung cho cả 2 bug**: cả 2 chỉ lộ ra khi test với dữ liệu THẬT ở QUY MÔ THẬT (>1000 dòng
cho bug 1, tháng đã có sẵn nhiều vụ cho bug 2) — bộ test Phase 2 ban đầu (dữ liệu tự tạo, nhỏ, sạch)
không đủ để bắt được, đúng đúng lý do Phase 4 (nạp mock data thật) có giá trị độc lập với việc "chỉ
kiểm dữ liệu đã nạp đúng chưa" như dự tính ban đầu — nó còn lộ ra cả lỗi TẦNG SHIM chưa từng thấy.

### 4g. Phase 3 — Supabase Auth thật cho tài khoản cán bộ — ĐÃ HOÀN TẤT (2026-07-19)

**Danh sách tài khoản Firebase Auth thật** lấy qua `firebase auth:export` (Firebase CLI, đã đăng
nhập sẵn trong môi trường này) — `qlahs-test` chỉ có đúng 1 tài khoản test
(`admintest@local.com`), **`qlahsp2` (production) có 4 tài khoản cán bộ thật**:
`cherry.vnu@gmail.com`, `nguyenphuongnhung2212@gmail.com`, `ntlinhyenbai@gmail.com`,
`admin@qlva.local`. Không migrate được mật khẩu gốc giữa 2 hệ thống (Firebase/Supabase dùng thuật
toán băm khác nhau, export chỉ cho `passwordHash` không tái sử dụng được) — đúng như đã ghi ở mục 7
từ đầu, tạo lại thủ công với **1 mật khẩu chung tạm thời** do Dũng cung cấp trực tiếp (KHÔNG ghi
giá trị mật khẩu vào bất kỳ file nào trong git, cùng nguyên tắc đã áp dụng cho mật khẩu DB ở mục 4c).

**Thử đường `signUp()` phía client (dùng `anon key` đã có sẵn) trước — THẤT BẠI, đúng dự đoán**: bị
chặn bởi (1) yêu cầu xác nhận email trước khi đăng nhập được, (2) giới hạn tốc độ gửi email rất
thấp của dịch vụ email built-in Supabase (`"email rate limit exceeded"` ngay ở lần thử thứ 2) — cả
2 đều không phù hợp để tạo 4 tài khoản thật ngay lập tức mà không chờ cán bộ tự bấm link xác nhận
trong hộp thư.

**Đã dùng Supabase Admin Auth API** (`POST /auth/v1/admin/users`, xác thực bằng key `service_role`
— **KHÁC** `anon key` đã nhúng sẵn trong `qlahs-sup.html`, key này CHỈ dùng tạm trong script ở
scratchpad, KHÔNG được ghi vào bất kỳ file nào trong git, cùng nguyên tắc mật khẩu DB) với
`email_confirm: true` — bỏ qua hẳn bước xác nhận email, tạo xong dùng đăng nhập được ngay. Cả 4
tài khoản tạo thành công (status 200), không tài khoản nào trùng UID/email với tài khoản cũ.

**Đã kiểm chứng bằng đăng nhập THẬT qua UI** (`qlahs-sup.html`, không mock) — cả 4/4 tài khoản đăng
nhập thành công vào đúng màn hình "Danh sách vụ án" với mật khẩu chung mới, 0 lỗi console. Phase 3
coi như hoàn tất — 5 tài khoản Supabase Auth hiện có: `admintest@local.com` (test, từ Phase 1) + 4
tài khoản cán bộ thật ở trên. **Việc còn lại ngoài phạm vi kỹ thuật**: báo cho từng cán bộ mật khẩu
tạm để họ tự đăng nhập và đổi lại mật khẩu riêng (Supabase Auth hỗ trợ đổi mật khẩu qua
`sb.auth.updateUser({password})` sau khi đăng nhập — chưa có UI riêng cho việc này trong
`qlahs-sup.html`, cần làm nếu/khi cắt hẳn sang Supabase ở Phase 6).

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

- [x] **`firestoreCacheRegistry`/`useFirestoreCollectionCache`** — **ĐÃ BỎ HẲN** registry toàn cục
      (ref-count + grace-period 3 phút). `useFirestoreCollectionCache`/`useFirestoreCacheLoaded`
      giữ NGUYÊN chữ ký hàm `(cacheKey, queryFn)` → `data`/`loaded` (13 call site KHÔNG cần sửa gì)
      nhưng bên trong giờ mỗi hook instance tự subscribe `onSnapshot` riêng qua shim (Supabase
      Realtime) thay vì tra registry chia sẻ. Đánh đổi CHẤP NHẬN ĐƯỢC: vài nơi 2 hook cùng cacheKey
      (VD `ModalXacNhanKy`'s `danhSachKy`+`dataDaVe`) giờ mở 2 kết nối Realtime thay vì chia sẻ 1 —
      không còn đáng lo dưới mô hình giá Supabase.
- [x] **Sentinel `meta/vuAnMoiNhat`** + `dsDangGiaiQuyetRegistry`/`useDanhSachDangGiaiQuyet` — **ĐÃ
      BỎ HẲN** toàn bộ cơ chế (registry, sentinel document, patch cục bộ tay ở 3 nơi). Bảng `meta`
      **đã XOÁ khỏi schema** (không còn code nào đọc/ghi — xem `schema.sql` ghi chú 5, lịch sử đủ
      3 giai đoạn: dự tính không tạo → tạo tạm lúc viết shim → xoá hẳn ở đây). `useDanhSachDangGiaiQuyet()`
      giữ NGUYÊN chữ ký `[ds, dangTai]` (2 call site không cần sửa) nhưng subscribe Realtime THẲNG
      trên `"vuan"` lọc `trangThai='dang_giai_quyet'`. **Lợi ích PHỤ vượt quá kỳ vọng ban đầu**: bản
      sentinel cũ CHỈ báo được vụ MỚI TẠO (mọi thay đổi khác — xoá mềm, khôi phục, hoàn thành... —
      phải patch tay riêng từng nơi, dễ sót); bản Realtime mới tự phản ánh MỌI thay đổi từ BẤT KỲ
      nguồn nào (không chỉ thao tác của chính người dùng đang xem) mà không cần patch tay ở đâu cả.
      **Đã kiểm chứng riêng bằng Playwright thật** (3 assertion mới, `test_sup_realtime_list.js`):
      tạo 1 vụ THẲNG qua `db.collection("vuan").doc().set()` (không qua nút "Thêm vụ án") → UI đang
      mở sẵn (không remount) tự hiện vụ đó; đánh dấu `daXoa=true` THẲNG qua DB (mô phỏng "nguồn
      khác") → UI tự ẩn vụ đó ngay — đúng chứng minh lợi ích PHỤ nêu trên là có thật, không phải suy
      đoán. Chạy lại toàn bộ 17+4 assertion cũ (`test_sup_shim.js`/`test_sup_ui_flow.js`) sau khi
      xoá 2 cơ chế này — vẫn PASS 100%, không có gì bị phá vỡ.
- [x] **Cache lạnh IndexedDB cho "Án đã giải quyết"** (`dongBoColdCacheVuAnDaGiaiQuyet`, đồng bộ
      delta qua `ngayCapNhat > lastSync`, không dùng `onSnapshot`) — **ĐÃ RÀ, QUYẾT ĐỊNH GIỮ
      NGUYÊN**. Đối chiếu lại với bộ nhớ dài hạn `toi-uu-firestore-effectiveness` (quyết định đã
      thống nhất TRƯỚC ĐÓ với Dũng, không phải suy đoán mới): lý do chấp nhận dữ liệu cũ ở đây
      KHÔNG THUẦN vì chi phí Firestore — có cả lý do sản phẩm thật ("hệ thống ít user, chủ yếu dùng
      để xem/trích xuất, ưu tiên tiết kiệm đọc hơn độ mới tức thời", và ý tưởng thêm timer đồng bộ
      định kỳ đã CHỦ ĐỘNG bị bác bỏ trước đây cùng lý do này — xem bộ nhớ đó). Phần lý do sản phẩm
      vẫn đúng bất kể backend nào — vụ đã giải quyết gần như bất biến, không cần realtime cho use
      case "xem/trích xuất". **Giữ nguyên cơ chế cache lạnh + đồng bộ delta 1 lần lúc mount**,
      không đổi sang Realtime subscription.
- [x] **Cursor pagination "đóng băng trang đầu sau khi bấm Tải thêm"** (tab "Tất cả" của Danh sách
      vụ án) — **ĐÃ RÀ, QUYẾT ĐỊNH GIỮ NGUYÊN** (không phải bỏ qua — đã đánh giá kỹ, không phải
      "chưa làm"). Lý do ban đầu ghi trong checklist ("chỉ để né phí") **không chính xác đầy đủ**:
      đọc lại kỹ code xác nhận việc "đóng băng" tồn tại để tránh 1 vấn đề TÍNH ĐÚNG ĐẮN thật —
      nếu trang 1 vẫn live TRONG LÚC đã phân trang bằng cursor (`startAfter`), bất kỳ thay đổi nào
      trên trang 1 sẽ làm listener bắn lại, ghi đè `cursorRef` về đúng ranh giới trang 1, khiến
      "Tải thêm" kế tiếp coi như không có gì mới (chính code gốc đã phải thêm `dangPhanTrangRef`
      để phòng ngừa 1 dạng race của đúng vấn đề này). Đây là hệ quả của việc KẾT HỢP live-query với
      cursor pagination — tồn tại tương tự dưới BẤT KỲ backend nào hỗ trợ Realtime (Supabase không
      miễn nhiễm), không phải đặc thù chi phí Firestore. Bỏ đóng băng để "khôi phục live" sẽ tái
      lập đúng lớp race này, không mang lại giá trị tương xứng với rủi ro — tab "Tất cả" cũng không
      phải màn hình chính (mặc định là "Đang giải quyết", đã live hoàn toàn qua mục ngay trên).
      **Giữ nguyên hành vi đóng băng**, không sửa gì thêm ở đây.
- [x] **`fetchWithTtlCache`** (TTL cache 1 lần cho `NhapVuModal` tìm vụ đích) — **ĐÃ RÀ, QUYẾT ĐỊNH
      GIỮ NGUYÊN**. Đây là hộp thoại "tìm vụ đích để nhập vào" — mở ra, gõ tìm, chọn, đóng lại;
      không có nhu cầu thấy thay đổi realtime của người khác TRONG lúc đang tìm (phiên thao tác
      ngắn, việc nhập vụ là hành động 1 người thực hiện tại 1 thời điểm). Giữ nguyên.
- [x] **Loạt quyết định "hot data không cần live" khác** (`BangBiCanCon`, `BangExcelModule`, cột Kỳ
      của `DanhSachPanel`) — **ĐÃ RÀ TỪNG CÁI RIÊNG**, quyết định GIỮ NGUYÊN cho cả 3, lý do khác
      nhau cho từng nhóm:
      - `BangBiCanCon`/`BangExcelModule` (Cài đặt → Bảng dữ liệu Excel): comment trong chính code
        đã ghi rõ "công cụ sửa hàng loạt cho 1 người thao tác, không phải màn hình xem chung" —
        lý do sản phẩm, độc lập chi phí backend. Restore live còn có thể PHẢN TÁC DỤNG: refetch
        realtime giữa lúc đang gõ vào 1 ô có thể xoá mất input chưa lưu của chính người dùng.
      - Cột Kỳ của `DanhSachPanel` (màn hình mặc định, nhiều người xem nhất — ứng viên "loại sau"
        rõ nhất trong gợi ý ban đầu của checklist): rà kỹ hơn phát hiện lý do KHÔNG chỉ chi phí —
        Supabase Realtime (`postgres_changes`) chỉ hỗ trợ filter dạng `cột=eq.giá_trị` đơn giản,
        KHÔNG hỗ trợ `in` — nên `onSnapshot` của shim cho query `where("maVuAn","in",[500 id])` sẽ
        phải subscribe KHÔNG LỌC (mọi thay đổi trên `lichsuChuyenGiaiDoan` — bảng ghi nhiều nhất hệ
        thống, theo chính mô tả trong code) rồi refetch lại NGUYÊN batch 500 vụ mỗi lần bất kỳ ai
        trong hệ thống ghi BẤT KỲ sự kiện nào — gây refetch/render nhiễu liên tục trên đúng màn hình
        đông người xem nhất, phản tác dụng ngược với mục tiêu "cải thiện UX". Đây là giới hạn thật
        của Supabase Realtime (filter chỉ hỗ trợ đơn giản), không phải lười rà. **Giữ nguyên cả 3**,
        không sửa code.
- [x] **Kỹ thuật né composite index thủ công** — rà toàn bộ codebase (grep `composite index`), tìm
      đúng **2 chỗ thật sự cần sửa** (1 chỗ khác ở `XoaHinhThucGiaiQuyetModal` tái dùng dữ liệu ĐÃ
      TẢI SẴN thay vì query riêng — đây là thực hành tốt độc lập với backend, không phải "né index",
      giữ nguyên):
      1. `GiaoNhanHoSoModule`'s `dsQuet` — trước đây `where("phienGiaoNhanId","==",...)` KHÔNG kèm
         `orderBy` (né composite index Firestore), tự `.sort()` lại phía client. Đổi sang
         `.orderBy("thoiDiemGhi","desc")` server-side, bỏ dòng `.sort()` thủ công.
      2. `fetchKyKhoiToBiCan` — trước đây `where("maVuAn","in",...)` rồi lọc `loaiSuKien` phía
         CLIENT (né composite index `maVuAn+loaiSuKien`). Đổi sang lọc thẳng trong query
         (`.where("loaiSuKien","==","khoi_to_bican")`) — Postgres không cần index riêng mới CHẠY
         ĐÚNG (chỉ có thể không dùng được index cho phần đó, vẫn ra kết quả đúng), giảm số dòng
         phải tải về so với tải nguyên lịch sử rồi lọc lại.
      **Đã kiểm chứng bằng Playwright thật** (5 assertion mới, `test_sup_index_avoid.js`, có tạo
      dữ liệu FK thật — phát hiện thêm ràng buộc `phienGiaoNhanId`/`maBiCan` là FK thật cần dữ liệu
      hợp lệ, khác Firestore không kiểm tra tham chiếu): 3 sự kiện cùng phiên trả đúng đủ + đúng thứ
      tự `orderBy` server-side; lọc `loaiSuKien` trong query đúng, không lẫn loại sự kiện khác.

**Đã dọn xong (mục kỹ thuật, không phải "chưa làm")**: giới hạn 30-item của `where(..., "in", ...)`
— đã xoá hết `chiaNhoDsId`/chia lô 30 trong `qlahs-sup.html` (7 call site: `batchLayBiCanList`,
`XoaVuAnModal` kiểm tra vụ tách, `DanhSachPanel` (2 nơi: tìm bị can + cột Kỳ), `vuAnTuLogDocs`,
`fetchBiCanTheoVuIds`, `fetchKyKhoiToBiCan`), đổi thành 1 query `"in"` duy nhất mỗi nơi — Postgres
`ANY()` không giới hạn 30 như Firestore. **Đã kiểm chứng bằng Playwright thật** (mảng 45 phần tử,
vượt hẳn giới hạn 30 cũ) xác nhận query trả về đúng đủ 45/45 kết quả. `db.enablePersistence`
(offline persistence) vẫn để riêng — đây là tính năng THẬT (chống mất mạng tạm thời), không phải
né chi phí, xử lý ở Phase 5 (mục 7 của tài liệu này) như đã ghi, không thuộc checklist này.

**Bug thật tìm được + sửa qua chính quá trình dọn 30-item chunking**: `batch.delete()` trong shim
gốc xử lý song song (`Promise.all`) KHÔNG phân biệt bảng nào, trong khi `batch.set()` (insert) đã
được sửa đúng thứ tự phụ thuộc từ trước (Phase 2) — dẫn tới lỗi FK 23503 CÙNG HỌ khi 1 batch xoá
nhiều bảng có quan hệ cha-con cùng lúc (VD script dọn dữ liệu test tự xoá `vuan`+`bican`+
`lichsuChuyenGiaiDoan` trong 1 batch — xoá `vuan` có thể chạy trước khi 2 bảng con xoá xong). Đã
sửa: `commit()` giờ xoá theo thứ tự NGƯỢC LẠI `_TABLE_INSERT_ORDER` (con trước, cha sau), gộp theo
bảng thành 1 lượt `.in('id', ids)` mỗi bảng thay vì N request riêng lẻ (nhanh hơn cả bản cũ).

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
4. **Đối chiếu**: so số dòng theo từng bảng (đúng những gì cần kiểm — export/import có thể sai
   lệch dữ liệu, VD field mảng/ngày tháng convert sai). **KHÔNG cần** so sánh "B10 tính ra có khớp
   giữa Firestore cũ và Postgres mới không" như 1 bước riêng — `tinhBieu10`/`tinhBaoCaoKy` là ĐÚNG
   1 đoạn code JS không đổi gì khi qua shim (chỉ đổi tầng `db` bên dưới), không có chỗ nào để công
   thức tính RA KHÁC ĐI giữa 2 hệ thống. Nếu B10 sai sau migrate thì chỉ có thể do (a) dữ liệu
   export/import sai lệch, hoặc (b) shim trả sai dữ liệu so với Firestore — cả 2 đều là lỗi ở TẦNG
   DỮ LIỆU, không phải lỗi B10. Chạy thử B10 sau khi nạp mock data vẫn có giá trị làm 1 phép thử
   tổng hợp (chạm gần như mọi field/mọi collection cùng lúc, dễ lộ lỗi map dữ liệu hơn test đơn lẻ
   từng bảng) — nhưng đúng bản chất là "kiểm tra dữ liệu qua 1 phép tính phức tạp", không phải
   "đối chiếu logic B10".
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
- [x] **Phase 2**: lớp shim ĐÃ VIẾT + KIỂM CHỨNG ĐẦY ĐỦ bằng dữ liệu thật (mục 4d), VÀ checklist
      mục 5 ĐÃ RÀ XONG 7/7 mục (xem đầu mục 5) — Phase 2 coi như HOÀN TOÀN xong. Tóm tắt: CDN
      Firebase (3 script) đổi sang 1 script `@supabase/supabase-js`, khối cấu hình cũ thay bằng lớp
      shim đầy đủ (`db`/`auth` giả lập, `firebase.firestore.FieldValue/FieldPath` giữ nguyên API
      cho ~35 chỗ gọi cũ không cần sửa), 4 vị trí `db.runTransaction` sửa tay gọi `.rpc(...)`.
      Checklist mục 5: 2 mục bỏ hẳn, 1 mục sửa 1 phần, 4 mục rà kỹ và giữ nguyên có lý do rõ ràng.
- [x] **Phase 3**: chuyển Auth sang Supabase Auth — 4 tài khoản cán bộ thật (lấy qua `firebase
      auth:export` trên `qlahsp2`) tạo lại qua Admin Auth API với mật khẩu chung tạm thời, đã kiểm
      chứng đăng nhập THẬT qua UI (mục 4g). Còn lại ngoài phạm vi kỹ thuật: báo mật khẩu tạm cho
      từng cán bộ + họ tự đổi lại (chưa có UI đổi mật khẩu trong `qlahs-sup.html`).
- [x] **Phase 4**: export dữ liệu thật từ `qlahs-test` (Firestore, 9354 document/7 collection) →
      import làm MOCK DATA vào project Supabase hiện có — THÀNH CÔNG 100%, đúng khớp số dòng, 5
      lỗi CHECK constraint thật gặp phải + đã sửa (mục 4e). Đã kiểm thử qua UI `qlahs-sup.html`
      thật với dữ liệu này, phát hiện + sửa thêm 2 bug thật của SHIM (không phải lỗi dữ liệu) chỉ
      lộ ra ở quy mô dữ liệu thật: PostgREST "Max Rows" cắt query không `.limit()` ở 1000 dòng, và
      `boDemMaVu` chưa seed gây trùng mã vụ khi tạo vụ mới qua UI — cả 2 đã sửa + kiểm chứng đầy đủ
      (mục 4f). Phase 4 coi như HOÀN TẤT.
- [ ] **Phase 5**: kiểm thử toàn diện trên project Supabase hiện có (đủ bộ Playwright hồi quy hiện
      có + kịch bản mới cho Realtime/RPC), quyết định hướng xử lý khoảng trống offline persistence.
- [x] **Phase 6 (phần dữ liệu) ĐÃ HOÀN TẤT (2026-07-19)**: reset Supabase + export/import dữ liệu
      THẬT từ `qlahsp2`, đối chiếu số liệu kỹ, kiểm chứng qua UI thật — xem mục 4n. **CHƯA cắt hẳn
      sang production** (Firestore/`qlva.html` vẫn nguyên trạng, không đụng gì, làm lưới an toàn
      theo đúng yêu cầu Dũng) — việc "ngừng hẳn Firestore" là quyết định RIÊNG, chưa làm.

## 9. Phase 6 — Chuyển dữ liệu thật (2026-07-19)

### 4n. Export/import dữ liệu thật từ `qlahsp2` production — ĐÃ HOÀN TẤT

**Truy cập**: Dũng tạo Service Account key từ Firebase Console (`qlahsp2` → Project Settings →
Service accounts) — dùng `firebase-admin` Node SDK đọc trực tiếp Firestore (không qua UI/Playwright
như đợt mock trước, vì không có tài khoản Auth thật để đăng nhập `qlahsp2.web.app` — đúng cách hợp
lệ hơn cho thao tác admin bất đồng bộ này). Key CHỈ dùng tạm trong scratchpad, **đã xoá ngay sau khi
xong việc** (cả bản trong scratchpad lẫn nhắc Dũng xoá bản gốc trong Downloads) — không commit vào
git, đúng nguyên tắc đã áp dụng cho mọi credential khác trong tài liệu này.

**Export**: 12278 document/7 collection — `vuan`=1987, `bican`=2918, `lichsuChuyenGiaiDoan`=6732,
`kybaocao`=4, `canbo`=34, `danhMucToiDanh`=586, `phienGiaoNhan`=17 — lớn hơn đáng kể so với mock
data (`qlahs-test`, ~9354 document) vì đây là dữ liệu tích luỹ thật nhiều năm.

**Audit trước khi đụng gì (theo đúng yêu cầu "xem lại hệ thống 1 lượt" của Dũng, không tự ý xoá/ghi
đè khi chưa rà)**: quét toàn bộ 12278 document theo đúng checklist đã áp dụng cho mock data (enum/
CHECK constraint, tham chiếu mồ côi FK, field cũ còn sót) — **sạch hơn hẳn mock**: 0 giá trị enum
lạ, 0 tham chiếu mồ côi (có thể vì các công cụ "Chuẩn hoá" đã từng chạy trên chính production
trước đây). Tìm được 2 vấn đề thật, cả 2 đều không mơ hồ:
1. `vuan.daXoa` thiếu ở 1978/1987 dòng (field mới, dữ liệu cũ chưa có) → fallback `false`.
2. `mucAnCoSauThang` (field CŨ, đã ghi trong CLAUDE.md là "cờ nhị phân +6 tháng" trước khi đổi sang
   `mucAnThang` số tháng lẻ) — còn sót trên 7 `vuan` + 125 `lichsuChuyenGiaiDoan` — **toàn bộ 132
   occurrence đều là `false`** (không có `true` nào) → quy đổi `mucAnThang = 0` là CHÍNH XÁC tuyệt
   đối theo đúng ngữ nghĩa gốc của field cũ (không phải suy đoán), giữ đúng dữ liệu bản án thật thay
   vì bỏ qua.
Đã hỏi + được Dũng xác nhận rõ cả 2 điểm trước khi import (không tự quyết định trên dữ liệu án hình
sự thật, khác hẳn cách xử lý "quyết định phù hợp cho MOCK DATA" ở Phase 4).

**Bug thật gặp phải khi import (KHÁC lần trước, mới hoàn toàn)**: `ngayQuyetDinhUocTinh` (boolean
NOT NULL DEFAULT false) làm insert `vuan` fail giữa chừng lô đầu tiên (0 dòng `vuan`/`bican`/... bị
ảnh hưởng — `kybaocao`/`canbo`/`danhMucToiDanh` đã insert xong trước đó, an toàn, idempotent khi
chạy lại). **Nguyên nhân gốc**: script import luôn liệt kê ĐỦ mọi cột trong câu `INSERT`, gán
tường minh `NULL` cho cột thiếu dữ liệu — cách này ĐÈ MẤT `DEFAULT` của Postgres (Postgres chỉ tự
áp `DEFAULT` khi cột đó HOÀN TOÀN vắng mặt khỏi câu lệnh, không phải khi được gán `NULL` tường
minh). Đã rà lại **toàn bộ** cột NOT NULL của cả 7 bảng (không chỉ vá đúng 1 cột vừa lỗi) — tìm
thêm 10 cột nữa cùng loại vấn đề (`soBiCan`/`biCanDaiDien`/`soQdKtBiCan`/`laLuuTru`/`tenPhien`/
`soQuyetDinh`/`nguoiNhanThucTe`/`soButLuc`/`khongTiepNhan`/`lyDoKhongTiepNhan`) — tất cả đều là
field mới hơn hoặc chỉ áp dụng cho 1 loại sự kiện cụ thể (VD 4 field cuối chỉ có ý nghĩa với
`loaiSuKien='giao_nhan_ho_so'`), fallback khớp ĐÚNG giá trị `DEFAULT` ghi trong `schema.sql`, không
suy đoán gì thêm. Sau khi vá đủ 12 cột, chạy lại từ đầu (idempotent) — **import thành công 100%,
khớp CHÍNH XÁC số dòng ở cả 7 bảng**.

**🔴 Bug thật NGHIÊM TRỌNG hơn, do chính trigger `bican_sync_vuan_trg` (mục 4j) gây ra** — phát
hiện qua spot-check sau import, KHÔNG PHẢI từ audit trước: trigger tự tính `vuan.dieuLuat` = gộp
từ `bican.toiDanh` mỗi khi `bican` thay đổi (kể cả INSERT hàng loạt lúc import) — nhưng **TOÀN BỘ
2918 bị can thật đều có `toiDanh` rỗng hoàn toàn** (đúng bug Import Excel cũ đã audit kỹ trong
CLAUDE.md "Audit 'chưa xác định điều luật'..."), nên trigger tính ra `NULL` và **GHI ĐÈ MẤT**
`dieuLuat` hợp lệ vốn có sẵn trên Firestore gốc cho **782/789 vụ có bị can** — dữ liệu quý (điều
luật đã ghi đúng qua nhiều năm) suýt mất vì áp dụng cơ chế MỚI (tin cậy tuyệt đối vào `bican` làm
nguồn sự thật) lên dữ liệu LỊCH SỬ có "vết tích" từ trước khi cơ chế đó tồn tại.
**Đã sửa theo đúng quy trình có sẵn trong app** (KHÔNG viết logic mới, tái dùng 1:1
`BackfillDieuLuatBCTool` đã audit kỹ — xem `qlahs-sup.html` dòng 2126-2242): (1) khôi phục
`vuan.dieuLuat` về đúng giá trị GỐC (từ file export JSON, không suy đoán) cho 782 vụ bị ghi đè mất;
(2) chạy lại ĐÚNG logic backfill (khớp tên tội danh chuẩn hoá bỏ tiền tố "Tội ", khớp số điều, ưu
tiên BLHS 2025, suy luận từ `dieuLuat` cấp vụ khi bị can rỗng hoàn toàn) cho toàn bộ 2918 bị can —
trigger tự chạy lại đúng sau mỗi lần UPDATE `bican`, hội tụ về giá trị chính xác.
**Kết quả cuối cùng: 2910/2918 bị can (99.7%) có `dieuLuatBC` chuẩn** ("Điều N BLHS 2025") — chỉ
còn ĐÚNG 7 vụ (8 bị can) không suy luận được vì bản thân vụ đó cũng không có `dieuLuat` cấp vụ để
tra (thiếu dữ liệu gốc thật, không phải lỗi) — khớp gần như chính xác tỷ lệ đã ghi nhận khi chạy
công cụ này trên mock data trước đây (99.8%), xác nhận tính nhất quán của hệ thống. Lưu ý: field
`vuan.dieuLuat` (cấp vụ) sau khi trigger tính lại hiển thị **TÊN TỘI DANH** gộp (VD "Tội lạm dụng
tín nhiệm chiếm đoạt tài sản") thay vì **MÃ ĐIỀU LUẬT** như dữ liệu gốc Import Excel từng ghi thẳng
("Điều 175 BLHS 2015") — đây là ĐỔI ĐỊNH DẠNG hiển thị (nhất quán với cách MỌI vụ khác trong hệ
thống hiển thị field này từ trước, xem `tinhDieuLuat`), KHÔNG PHẢI mất dữ liệu — trường quan trọng
cho thống kê B10 là `bican.dieuLuatBC` (mã chuẩn cấp bị can), đã điền đúng.
**Bài học cho lần tới**: trigger tự động là "con dao 2 lưỡi" khi áp lên dữ liệu lịch sử tồn tại
TRƯỚC khi trigger được thêm — luôn kiểm tra kỹ các field mà trigger sẽ TÍNH LẠI (không chỉ field
trigger ĐỌC) có đang chứa dữ liệu quý cần bảo toàn hay không, trước khi import hàng loạt.

**Seed lại `boDemMaVu`** theo đúng dữ liệu vuan thật (regex tách YYMM+SEQ từ mã vụ, lấy SEQ lớn
nhất mỗi tháng) — 84 tháng, để tạo vụ án mới qua UI không bị trùng mã (đúng bug đã gặp + sửa ở
Phase 4, mục 4f — lần này áp dụng ngay trong quy trình import, không phải phát hiện sau).

**Đã kiểm chứng toàn diện**:
- Đối chiếu số dòng: khớp CHÍNH XÁC cả 7 bảng (export = database).
- Spot-check: `soBiCan` cache khớp 100% với đếm thật (0 lệch trên toàn bộ 1987 vụ); mọi vụ có bị
  can đều có đúng 1 người `loaiKhoiTo='ban_dau'`; `dieuLuatBC` chuẩn 2910/2918 bị can.
- **Qua UI thật** (Playwright, tài khoản test `b10verify@local.com`): đăng nhập, Danh sách vụ án
  hiện đúng 300 vụ "đang giải quyết" (khớp SQL), mở chi tiết 1 vụ hiện đúng "Tội lạm dụng tín nhiệm
  chiếm đoạt tài sản" (khớp kết quả backfill), Dashboard hiện đúng "300 vụ / 731 bị can" cho Điều
  tra (0 cho Truy tố/Xét xử — **xác nhận qua SQL đây là số liệu THẬT**, toàn bộ vụ đang thụ lý của
  đơn vị này hiện đều ở giai đoạn Điều tra, không phải lỗi), xuất Excel báo cáo tháng cho kỳ thật
  "06/2026" thành công (311KB, không lỗi). "Tồn đầu kỳ" hiện 0/0/0 — **đúng dự kiến**, đây là kỳ
  báo cáo đầu tiên trong hệ thống thật, không có kỳ trước để snapshot.
- 0 lỗi console thật (chỉ 1 lần gặp lại đúng lỗi JWT clock-skew môi trường sandbox đã biết từ mục
  4d, không phải bug — biến mất khi chạy lại).

**CHƯA làm** (ngoài phạm vi đã thống nhất với Dũng ở bước xác nhận trình tự): KHÔNG đụng gì tới
Firestore/`qlva.html` — vẫn chạy nguyên trạng làm lưới an toàn. KHÔNG cập nhật tài khoản 4 cán bộ
thật để bắt đầu dùng Supabase — Supabase hiện có đầy đủ dữ liệu thật + đã kiểm chứng, nhưng việc
"cắt hẳn sang production" (đổi để cán bộ dùng `qlahs-sup.html` thay vì `qlva.html`) là quyết định
RIÊNG, cần Dũng xác nhận thêm khi sẵn sàng.

## 8. Trạng thái hiện tại

**Phase 1 xong hoàn toàn** (schema/RLS/RPC áp dụng + kiểm chứng thật, mục 4c). **Phase 2 (lớp shim)
đã viết xong + kiểm chứng đầy đủ bằng dữ liệu thật** (17 assertion, gồm 1 luồng UI thật trọn vẹn
"Thêm vụ án" → RPC sinh mã → batch ghi đúng thứ tự phụ thuộc → đọc lại đúng, xem mục 4d) — 1 bug
FK-ordering thật đã tìm ra và sửa qua chính quá trình test này. `qlahs-sup.html` hiện chạy được
đầy đủ trên nền Supabase (KHÔNG còn phụ thuộc Firebase gì, kể cả CDN script). Toàn bộ dữ liệu test
đã dọn sạch — project Supabase đang ở trạng thái sạch (0 dòng mọi bảng), sẵn sàng nạp mock data.

**Phase 2 ĐÃ HOÀN TẤT** (shim + checklist mục 5). Bảng `meta` đã xoá khỏi schema thật (DROP TABLE
đã chạy trên project Supabase).

**Phase 4 ĐÃ HOÀN TẤT** (export/import mock data từ `qlahs-test` + kiểm thử qua UI thật + 2 bug shim
đã sửa, xem mục 4e/4f) — project Supabase hiện có đầy đủ 7 bảng nghiệp vụ với dữ liệu thật (đã
transform), đã xác nhận hiển thị/hoạt động đúng qua `qlahs-sup.html` (Danh sách vụ án, Án đã giải
quyết, Kỳ báo cáo, Giao nhận hồ sơ, Dashboard, Cài đặt — 0 lỗi console mới, 32/32 assertion hồi quy
PASS).

**Phase 3 ĐÃ HOÀN TẤT** (4 tài khoản cán bộ thật tạo qua Admin Auth API, kiểm chứng đăng nhập thật —
mục 4g).

### 4h. Xuất Biểu B10 trên mock data — ĐÃ KIỂM CHỨNG, KHÔNG PHÁT HIỆN LỖI MIGRATION (2026-07-19)

Thực hiện đúng việc #1 đã khuyến nghị ở lần cập nhật trước. Tài khoản test `admintest@local.com`
trên Supabase không có mật khẩu lưu trữ được (đúng nguyên tắc bảo mật mục 4c/4g) và bị chặn reset
qua Admin API bởi lớp an toàn của harness làm việc (phân loại "đổi cài đặt tài khoản" cần xác nhận
tường minh) — đã tạo thêm 1 tài khoản test THỨ 2 `b10verify@local.com` (Admin Auth API,
`email_confirm:true`, cùng cách Phase 3 đã làm) thay vì đụng vào tài khoản cũ, sau khi được Dũng xác
nhận trực tiếp trong hội thoại.

**Kịch bản**: đăng nhập thật qua `qlahs-sup.html` (Supabase, Playwright, không mock) → mở Kỳ báo
cáo → chọn kỳ "Tháng 6/2026" (đã chốt, Tồn cuối kỳ 20/9/5) → bấm "Xuất Excel báo cáo tháng" → tải
file thật (105KB, 42 sheet) → mở lại bằng `exceljs` để kiểm tra dữ liệu (không chỉ xác nhận file
tải được).

**Kết quả xuất — không có lỗi console, sheet Biểu B10 có đầy đủ dữ liệu thật** (tội danh/điều luật/
số vụ-số BC theo từng giai đoạn, đúng cấu trúc 2 hàng header + N hàng dữ liệu như thiết kế gốc), đủ
1138 ô công thức Excel (SUMIF/COUNTIF/SUM tham chiếu chéo sang 38 sheet DS con) + 270 ô số tĩnh
(snapshot chốt kỳ) — đúng tỉ lệ công thức/tĩnh như thiết kế đã mô tả trong "Xuất Excel báo cáo
tháng" ở CLAUDE.md.

**Phát hiện ban đầu tưởng là lỗi, đã xác minh KHÔNG PHẢI lỗi migration**: tự tính lại bằng tay công
thức "Cân đối số liệu" (`Tồn đầu + Σ Vào − Σ Ra` so với `Tồn cuối chốt`, đọc trực tiếp cột "Đếm vụ"
của từng sheet DS liên quan bằng `exceljs` — không phụ thuộc Excel tự tính công thức, vì file
`exceljs` xuất ra chỉ ghi CHUỖI công thức, không có kết quả cache sẵn) ra **Chênh lệch ≠ 0 ở cả 3
giai đoạn** (Điều tra +7, Truy tố +2, Xét xử +2). Trước khi kết luận đây là bug, đối chiếu 2 bước:
1. Query trực tiếp Postgres (service_role, bỏ qua RLS): xác nhận đúng **30 sự kiện
   `lichsuChuyenGiaiDoan.kyThongKe IS NULL`** trong toàn bộ 5068 sự kiện — khớp đúng cảnh báo đã in
   sẵn ngay trên sheet ("Chênh lệch ≠ 0 → có sự kiện log chưa gán kỳ") và khớp đặc điểm dữ liệu cũ
   đã tài liệu hoá nhiều lần trong CLAUDE.md (dữ liệu dựng lại lịch sử từ Import Excel cũ không
   phải lúc nào cũng gán được `kyThongKe`).
2. **Đối chứng chéo với chính bản Firestore gốc** (`qlva-dev.html`, cùng dữ liệu nguồn
   `qlahs-test`, đăng nhập thật `admintest@local.com`): xuất lại ĐÚNG kỳ "Tháng 6/2026" — ra
   **ĐÚNG Y HỆT Chênh lệch (+7/+2/+2)**, và so khớp TỪNG Ô một giữa 2 file Biểu B10 (2002 ô, Firestore
   vs Supabase) → **0 ô khác nhau**. Vì `tinhBieu10`/`tinhBaoCaoKyTuLog` là đúng 1 đoạn code JS
   không đổi gì khi qua shim (chỉ đổi tầng `db`), việc 2 bản ra kết quả giống hệt nhau (bao gồm cả
   phần "lỗi" Chênh lệch) là bằng chứng trực tiếp: **shim + dữ liệu import không làm sai lệch bất kỳ
   giá trị nào** — Chênh lệch là thuộc tính CÓ SẴN của dữ liệu mock (30 sự kiện thiếu kỳ), tồn tại
   TRƯỚC migration, không phải lỗi phát sinh do chuyển sang Supabase.

**Kết luận việc #1 đã khuyến nghị**: hoàn tất, không phát hiện lỗi map dữ liệu nào ở tầng Postgres/
shim — phép thử tổng hợp (chạm B10, TK tội danh, Tổng hợp báo cáo, Cân đối số liệu, 38 sheet DS
con) cho kết quả khớp tuyệt đối 100% với bản Firestore gốc.

**Đã dọn dẹp**: 2 file Excel test đã xoá khỏi scratchpad, không commit gì vào repo. Tài khoản
`b10verify@local.com` **CHƯA xoá** (tạo thêm mới, không đụng dữ liệu nghiệp vụ, có thể giữ lại làm
tài khoản test phụ cho phiên sau nếu cần — hoặc xoá qua Supabase Dashboard nếu Dũng muốn dọn sạch).

### 4i. Audit toàn hệ thống lần 1 sau migration — 10 phát hiện, CHƯA SỬA (2026-07-19)

Theo yêu cầu Dũng ("kiểm tra lại toàn bộ hệ thống, xem còn vấn đề gì không, có gì cải tiến hiệu
năng không — note ra"). Rà 4 tầng: lớp shim (`qlahs-sup.html` dòng ~50-430), schema/RLS/RPC
(`supabase/*.sql`), toàn bộ 19 vị trí `onSnapshot`, các query trên bảng lớn. Đây là danh sách
GHI NHẬN — chưa sửa gì, chờ quyết định thứ tự ưu tiên.

**Nhóm A — Hiệu năng (2 vấn đề lớn, 2 nhỏ):**

1. **[LỚN — sửa rẻ] `schema.sql` KHÔNG có một CREATE INDEX nào** (đã xác nhận qua grep — chỉ có
   index ngầm của PRIMARY KEY). Firestore tự đánh index MỌI field; Postgres thì không — kể cả cột
   FK (`REFERENCES`) cũng KHÔNG tự có index. Hậu quả: mọi query lọc đang quét tuần tự toàn bảng —
   `bican.maVuAn` (mỗi lần mở chi tiết vụ án), `lichsuChuyenGiaiDoan.maVuAn`/`kyThongKe`/
   `loaiSuKien`/`phienGiaoNhanId` (bảng lớn nhất, 5068 dòng, TĂNG VÔ HẠN theo năm — mọi báo cáo kỳ
   đều query bảng này), `vuan.trangThai`/`daXoa`/`ngayTao`. Cascade check khi XÓA vụ án cũng quét
   tuần tự các bảng con. Hiện tại vài nghìn dòng thì mỗi lần quét chỉ vài ms (chưa ai cảm nhận
   được), nhưng đây là quả bom nổ chậm — sau vài năm dữ liệu, các màn hình query log sẽ chậm dần
   đều. **Đề xuất**: viết `supabase/indexes.sql` (~10 index khớp đúng các query đang dùng thật,
   vai trò tương đương `firestore.indexes.json` cũ), áp 1 lần qua Session pooler.
2. **[LỚN — sửa rẻ] RLS policy gọi `auth.role()` TỪNG DÒNG** — `rls.sql` dùng
   `using (auth.role() = 'authenticated')` trực tiếp: Postgres gọi lại hàm này cho MỖI DÒNG quét
   qua (5068 lần cho 1 lần đọc bảng log). Khuyến nghị chính thức của Supabase ("RLS performance
   recommendations"): bọc thành `using ((select auth.role()) = 'authenticated')` — Postgres tự
   nhận ra subquery không phụ thuộc dòng, chỉ tính 1 LẦN/query (chênh lệch đo được hàng chục lần
   trên bảng lớn); đồng thời thêm `to authenticated` vào policy để request anon bị loại từ sớm
   không cần chạy policy.
3. **[VỪA] "Refetch storm" khi ghi hàng loạt** — `_subscribe` của shim refetch NGAY mỗi khi nhận 1
   event Realtime, không gộp/debounce. Postgres bắn 1 event/DÒNG thay đổi, kể cả khi 760 dòng được
   insert trong CÙNG 1 câu lệnh (Import Excel) → mỗi client đang mở Danh sách vụ án sẽ refetch
   toàn bộ danh sách ~760 lần liên tiếp trong vài giây. **Đề xuất**: debounce trailing ~300ms
   trong `_subscribe` (gộp mọi event trong cửa sổ đó thành 1 lần refetch duy nhất).
4. **[NHỎ] Batch chunk 400 là di sản Firestore không còn cần** — ~10 chỗ vẫn tự cắt batch thành
   lô 400 op (`if (opsInBatch >= 400) commit...`) vì giới hạn 500 write/batch của Firestore.
   Postgres không có giới hạn này; shim đã tự gộp insert cùng bảng thành 1 request — việc cắt lô
   giờ chỉ làm TĂNG số request (VD seed 586 tội danh thành 2 request thay vì 1) và tăng số khe hở
   không-atomic (xem mục 5). Dọn được nhưng không gấp.

**Nhóm B — Độ bền / tính đúng đắn (4 vấn đề):**

5. **[ĐÁNG CÂN NHẮC NHẤT] `batch.commit()` của shim KHÔNG atomic như Firestore** — Firestore đảm
   bảo tất-cả-hoặc-không-gì; shim hiện commit TUẦN TỰ từng bảng (insert theo `_TABLE_INSERT_ORDER`,
   rồi update, rồi delete) — lỗi mạng/constraint Ở GIỮA chừng để lại dữ liệu nửa vời. Kịch bản
   thật: "Xóa vĩnh viễn" cascade (xoá bican + log trước, vuan sau) — nếu bước cuối fail, vụ án
   thành vỏ rỗng không bị can/không lịch sử; "Thêm vụ án" — vuan ghi xong nhưng bican/log fail thì
   có vụ 0 bị can kèm log thiếu. **Hướng sửa triệt để**: viết 1 RPC `batch_commit(ops jsonb)` chạy
   toàn bộ ops trong 1 transaction Postgres thật (atomic đúng nghĩa, còn TỐT HƠN mô hình cắt lô
   400 của Firestore cũ vốn cũng chỉ atomic TRONG từng lô). Shim `commit()` chỉ cần đổi phần thân
   gọi RPC này — ~185 call site không đổi gì. Cần quyết định trước khi lên production (Phase 6).
6. **[ĐÁNG SỬA] Kênh Realtime chết ÂM THẦM, không tự hồi phục** — `_subscribe` bỏ qua hoàn toàn
   callback status của `.subscribe()` (grep `SUBSCRIBED|CHANNEL_ERROR|TIMED_OUT` = 0 kết quả).
   Máy sleep/đổi mạng wifi/JWT hết hạn giữa chừng → kênh chết → UI đứng im với dữ liệu cũ, KHÔNG
   lỗi console, không ai biết (đúng lớp bug "sentinel lặng lẽ không bắn" từng gặp thời Firestore).
   **Đề xuất**: xử lý status — khi `CHANNEL_ERROR`/`TIMED_OUT` thì refetch + resubscribe; khi
   re-`SUBSCRIBED` sau gián đoạn thì refetch bù.
7. **[NHỎ nhưng thật] Khe hở lúc mở subscribe** — `_subscribe` refetch NGAY rồi mới `.subscribe()`
   (kênh cần vài trăm ms mới thực sự SUBSCRIBED) — thay đổi lọt vào đúng khe đó bị MẤT (không có
   event → không refetch → dữ liệu cũ tới khi có thay đổi kế tiếp). **Đề xuất**: refetch thêm 1
   lần trong callback status khi nhận `SUBSCRIBED` lần đầu (gộp chung với fix mục 6).
8. **[NHỎ nhưng thật] Race 2 refetch chồng nhau ghi đè ngược** — 2 event sát nhau → 2 refetch song
   song; cái CŨ có thể resolve SAU cái mới → kết quả cũ đè kết quả mới, UI hiển thị dữ liệu cũ tới
   event kế tiếp. **Đề xuất**: seq counter trong `_subscribe`, bỏ kết quả của refetch đã bị vượt
   ("latest wins" — gộp chung 1 lần sửa với mục 3/6/7, cùng 1 hàm ~25 dòng).

**Nhóm C — Vá nhỏ (2 vấn đề):**

9. **Phân trang ngầm (Max Rows fix, mục 4f) thiếu tiebreak khi query CÓ orderBy tường minh** —
   hiện chỉ ngầm thêm `orderBy("id")` khi query KHÔNG có orderBy nào; query có orderBy cột
   KHÔNG-duy-nhất (VD `orderBy("thoiDiemGhi")`) mà vượt 500 dòng thì thứ tự các dòng TRÙNG giá trị
   tại ranh giới trang không ổn định giữa 2 lần request → có thể lặp/sót dòng. Chưa xảy ra thật
   (các query dạng này hiện <500 dòng) nhưng sẽ xảy ra khi dữ liệu tăng. **Fix 1 dòng**: LUÔN nối
   thêm `order("id")` làm tiebreak cuối trong đường phân trang ngầm, kể cả khi đã có orderBy.
10. **4 hàm RPC SECURITY DEFINER thiếu `set search_path = ''`** — hardening chuẩn (Supabase
    Security Advisor sẽ cảnh báo "role mutable search_path"). Rủi ro thực tế thấp (chỉ
    authenticated gọi được, user không tạo được object trong schema nào) nhưng sửa chỉ 1 dòng/hàm,
    nên làm cùng đợt áp `indexes.sql`.

**Nhóm D — Đã biết từ trước, KHÔNG phải phát hiện mới (liệt kê lại cho đủ bức tranh)**: offline
persistence chưa có thay thế (quyết định ở Phase 5); `serverTimestamp()` = giờ client;
`arrayUnion` không atomic (1 chỗ dùng hiếm — SuaKyModal); `biCanDaiDien` chọn theo `ngayTao` khác
tiêu chí mơ hồ của bản JS (đã ghi chú trong functions.sql, cần xác nhận với Dũng).

**Thứ tự ưu tiên đề xuất**: (1)+(2)+(10) trước — thuần SQL, không đụng code app, lợi ích lớn nhất;
rồi (3)+(6)+(7)+(8) — cùng 1 hàm `_subscribe` ~25 dòng, sửa 1 lần test 1 lần; rồi (9) — 1 dòng;
(5) cần quyết định riêng trước Phase 6; (4) dọn lúc nào rảnh.

**⚠ SỬA LẠI finding #1 của chính audit này (2026-07-19, ngay sau khi viết)**: "schema.sql KHÔNG có
một CREATE INDEX nào" là **KẾT LUẬN SAI** — do dùng `grep "CREATE INDEX"` (viết hoa) trong khi file
SQL viết thường `create index`, ra kết quả rỗng và kết luận nhầm mà không đối chiếu lại. Thực tế
`schema.sql` đã có sẵn **16 index**. Đối chiếu lại cẩn thận từng `.where()` thật trong
`qlahs-sup.html` với 16 index đó, tìm ra đúng **3 chỗ thiếu index thật** (không phải "toàn hệ thống
thiếu index"): `lichsuChuyenGiaiDoan.loaiSuKien` đứng riêng (dùng ở "Tải toàn bộ lịch sử giao nhận"
+ vài công cụ backfill — 2 composite index sẵn có đều có `kyThongKe` làm cột đầu nên không phục vụ
được), `vuan.vuGoc` (kiểm tra "vụ có con tách ra"), `vuan.ngayCapNhat` (đồng bộ delta cache lạnh).

### 4j. Đã sửa 9/10 phát hiện của mục 4i (2026-07-19, cùng ngày)

**Nhóm A — SQL** (`supabase/perf_fixes_2026-07-19.sql`, áp qua Session pooler với mật khẩu Dũng
cung cấp trực tiếp trong chat — KHÔNG ghi vào file nào trong git, cùng nguyên tắc mục 4c):
- 3 index thật thiếu (đã sửa lại số liệu ở trên) — đã tạo, xác nhận tồn tại qua `pg_indexes`.
- RLS: bọc `auth.role()` trong subquery + thêm `to authenticated` tường minh cho cả 7 bảng nghiệp
  vụ — xác nhận qua `pg_policies.qual` đã đổi đúng thành
  `(( SELECT auth.role() AS role) = 'authenticated'::text)`.
- 4 hàm RPC: `set search_path = public` — xác nhận qua `pg_proc.proconfig` đã có
  `["search_path=public"]` cho cả 4 hàm.
- **#10 (search_path RPC) coi như đã gộp vào bước này** — cùng 1 file SQL.

**Nhóm B — `_subscribe` trong `qlahs-sup.html`** (gộp cả 4 phát hiện #3/#6/#7/#8 vào 1 lần viết
lại hàm, đúng đề xuất ban đầu): đổi chữ ký `fetchFn` trả về snapshot thay vì tự gọi `onNext` bên
trong (để `_subscribe` tự quyết định lúc nào áp dụng kết quả) — chỉ cần sửa đúng 2 nơi gọi nội bộ
(`_makeDocRef.onSnapshot`, `_makeQuery.onSnapshot`), không đụng 19 vị trí `.onSnapshot()` ở tầng
code ứng dụng. Thêm: debounce trailing 300ms cho event Realtime (lần fetch đầu tiên KHÔNG debounce);
seq counter "kết quả mới nhất thắng" (bỏ kết quả của lần fetch không còn là lần mới nhất khi nó
resolve xong); fetch bù ngay khi (re)`SUBSCRIBED` (đóng khe hở đầu + đóng vai trò "refetch khi phục
hồi" luôn, không cần code riêng cho reconnect); tự `removeChannel` + mở lại kênh sau 2s khi gặp
`CHANNEL_ERROR`/`TIMED_OUT` (không dựa vào auto-reconnect ngầm của client — chủ động, không đảm bảo
sai).

**Nhóm C — pagination tiebreak (#9)**: đường phân trang ngầm (fix "Max Rows" ở mục 4f) giờ LUÔN
đảm bảo có `id` làm cột sort cuối — nếu query đã có `orderBy` khác mà chưa có `id`, tự nối thêm
`{field:"id", dir:"asc"}` vào cuối danh sách order thay vì chỉ áp dụng khi hoàn toàn không có
orderBy nào như bản cũ.

**Đã kiểm chứng bằng Playwright thật, dữ liệu thật trên `eutatszoaseixchvjbtg`** (không phải mock,
3 kịch bản độc lập):
1. Cú pháp sạch (mở trang, tới màn đăng nhập, 0 lỗi console ngoài cảnh báo Babel đã biết).
2. **Xuất Biểu B10 lại 1 lần nữa** (đúng kịch bản mục 4h) sau khi viết lại `_subscribe` — kết quả
   giống hệt lần trước (42 sheet, Biểu B10 đủ dữ liệu, 0 lỗi console) — xác nhận đường `.get()`
   không bị ảnh hưởng bởi việc viết lại `_subscribe`.
3. **Test riêng đường Realtime** (trước đây CHƯA test lại sau khi sửa `_subscribe`) — tạo 1 vụ
   THẲNG qua REST (service_role, mô phỏng "nguồn khác", bỏ qua UI) trong lúc UI đang mở "Danh sách
   vụ án" (tab mặc định, đang dùng `useDanhSachDangGiaiQuyet` → `onSnapshot` thật) → xác nhận UI tự
   hiện vụ mới trong vòng 3s (debounce 300ms + độ trễ Realtime); đánh dấu `daXoa=true` THẲNG qua
   REST → xác nhận UI tự ẩn vụ đó — cả 2 chiều đều đúng, 0 lỗi console.
4. **Luồng "Thêm vụ án" qua UI thật, đầy đủ** (chạy SAU KHI áp SQL fix — quan trọng nhất vì đây là
   phép thử RLS + RPC `search_path=public` mới không phá vỡ 2 hàm RPC then chốt nhất hệ thống): mở
   form, điền Ngày QĐ KTVA + họ tên bị can, bấm Lưu → modal "Tính vào kỳ báo cáo nào?" hiện đúng
   (bằng chứng RPC `sinhMaVuAnMoi` chạy thành công dưới RLS/search_path mới) → xác nhận vụ mới xuất
   hiện trên danh sách, 0 lỗi console. Đã dọn sạch dữ liệu test (cascade xoá `lichsuChuyenGiaiDoan`/
   `bican`/`vuan` qua service_role) sau khi xong.

**Còn lại CHƯA sửa** (theo đúng thứ tự ưu tiên đã đề xuất — cố ý để lại, cần quyết định riêng):
- ~~**#5 (batch không atomic)**~~ — **ĐÃ SỬA (2026-07-20), xem mục 12.**
- **#4 (dọn chunk 400 di sản Firestore)** — dọn lúc rảnh, không gấp, không ảnh hưởng đúng/sai.

### 4k. Dọn sạch tàn dư Firebase trong `qlahs-sup.html` — "Firebase chỉ còn vai trò Hosting" (2026-07-19)

Theo yêu cầu Dũng ("đảm bảo hệ thống đã triệt để hỗ trợ Supabase, bỏ hết những gì Firebase không
cần thiết đi, Firebase giờ chủ yếu dùng để deploy"). Đã hỏi rõ phạm vi trước khi làm (xác nhận qua
`AskUserQuestion`): **CHỈ** `qlahs-sup.html` (nhánh migration) — **KHÔNG** đụng `qlva.html`/
`qlva-dev.html`/`firestore.rules`/`firestore.indexes.json`, vì đó vẫn là production Firestore thật
đang phục vụ 4 cán bộ, Phase 6 (chuyển dữ liệu thật + cắt hẳn) chưa làm. Cũng xác nhận **chưa
deploy** `qlahs-sup.html` lên bất kỳ URL Firebase Hosting nào ở phiên này (chỉ dọn code, test bằng
`http.server` cục bộ như mọi phiên trước).

**Rà toàn bộ file bằng grep (không suy đoán) — tìm 6 chỗ THẬT cần sửa**, 2 trong đó là **bug thật
hiển thị cho người dùng** (không phải chỉ tồn tại trong comment):
1. **Bug thật #1** — màn đăng nhập chỉ dẫn "Chưa có tài khoản? Liên hệ quản trị để được tạo trong
   **Firebase Console** → Authentication → Users" — SAI, 5 tài khoản hiện có (`admintest@local.com`
   + 4 cán bộ thật, xem mục 4g) đều tạo qua **Supabase** Admin Auth API, không còn Firebase Auth
   nào để tạo thêm tài khoản qua đường đó nữa. Đã sửa thành "Supabase Dashboard → Authentication →
   Users" — đúng nơi thật sự cần vào.
2. **Bug thật #2** — thông báo lỗi khi ghi Excel import thất bại hiện "Lỗi khi ghi vào **Firestore**:
   ..." — sai tên database, gây khó hiểu khi debug/báo lỗi cho quản trị viên (nhìn vào thông báo sẽ
   tưởng vẫn còn Firestore). Đã sửa thành "Lỗi khi ghi vào cơ sở dữ liệu: ...".
3. **3 chỗ dùng nhầm thuật ngữ "collection"** (khái niệm Firestore) trong text hiển thị ở 2 công cụ
   "Cài đặt" (thông báo kết quả + mô tả "Seed danh mục tội danh", mô tả tool "Cập nhật số bị can lên
   vụ án") — đổi thành "bảng" (đúng khái niệm Postgres).
4. **Comment top-of-file lỗi thời** — bản gốc ghi "copy nguyên văn từ qlva.html... sẽ dần đổi db
   Firestore sang lớp shim... file này vẫn còn nguyên logic Firebase y hệt 2 file kia" — đúng lúc
   file MỚI TẠO (trước Phase 2), giờ SAI vì shim đã viết xong từ lâu (Phase 2 hoàn tất, xem mục 8).
   Viết lại phản ánh đúng trạng thái hiện tại: backend hoàn toàn Postgres/Supabase, `<head>` không
   còn CDN/SDK Firebase nào, Firebase (nếu dùng) chỉ còn vai trò lưu trữ tĩnh cho file HTML.
5. **1 comment nội bộ nhắc "Firebase" sai ngữ cảnh** (`useDanhMucToiDanh`: "nếu Firebase đã seed thì
   dùng Firebase") — đổi thành "nếu đã seed vào database thì dùng bản đó".
6. **Đổi tên 2 hook nội bộ** `useFirestoreCollectionCache`/`useFirestoreCacheLoaded` (12+4 lần gọi)
   thành `useCollectionCache`/`useCacheLoaded` — tên cũ mang chữ "Firestore" dù hành vi bên trong đã
   hoàn toàn chạy qua Supabase Realtime từ Phase 2 (không còn đụng gì tới Firestore) — tên cũ là
   1 "tàn dư Firebase không cần thiết" đúng nghĩa đen theo yêu cầu, dù không gây lỗi chức năng nào.
   Đổi bằng `sed` (rename thuần, không đổi logic) — an toàn vì 2 tên hàm là chuỗi duy nhất, không
   trùng với bất kỳ định danh nào khác trong file.

**CHỦ ĐỘNG KHÔNG đụng** (đã rà, xác nhận là hợp lệ — không phải Firebase thật, chỉ đặt tên giống để
tương thích API): object `firebase.firestore.{FieldValue,FieldPath}` (shim tự định nghĩa, có comment
rõ ràng ngay cạnh giải thích đây KHÔNG phải SDK Firebase thật, ~35 chỗ gọi trong code dựa vào tên
này để không phải sửa cú pháp — đổi tên sẽ phá vỡ đúng lợi ích cốt lõi của chiến lược "shim giả lập
API" đã chốt từ mục 3); comment khối "LỚP SHIM: GIẢ LẬP FIRESTORE API TRÊN NỀN SUPABASE" (giải thích
ĐÚNG lý do code vẫn gọi `db.collection(...)` — lựa chọn hình dạng API, không phải phụ thuộc thật);
mọi comment lịch sử nhắc "Firestore"/"Tối ưu Firestore Đợt..." khi đang GIẢI THÍCH bối cảnh 1 quyết
định thiết kế từ thời còn Firestore (VD tại sao có field cache `soBiCan`) — xoá sẽ mất ngữ cảnh hữu
ích, không phải tàn dư cần dọn. Xác nhận qua grep: `<head>` không có bất kỳ script CDN Firebase nào
(chỉ Tailwind/React/Babel/xlsx/exceljs/chart.js/qrcodejs/`@supabase/supabase-js`) — đã đúng từ Phase
2, không có gì để dọn thêm ở tầng này.

**Đã kiểm chứng bằng Playwright thật, dữ liệu thật** (chạy lại đủ 3 kịch bản đã có từ trước, xác
nhận đổi tên hook + sửa text không phá vỡ gì): cú pháp sạch (0 lỗi ngoài cảnh báo Babel đã biết);
xuất Biểu B10 lại — kết quả giống hệt các lần trước (42 sheet, đủ dữ liệu); test Realtime (tạo/xoá
vụ qua REST, UI tự cập nhật đúng cả 2 chiều); luồng "Thêm vụ án" đầy đủ qua UI (RPC vẫn chạy đúng).
Đã dọn sạch dữ liệu test sau khi xong.

**Kết luận**: `qlahs-sup.html` giờ không còn bất kỳ tham chiếu Firebase nào gây nhầm lẫn cho người
dùng/quản trị viên — mọi mention "Firebase" còn lại đều là shim API-compat có ghi chú rõ hoặc
comment lịch sử hợp lệ. File đã sẵn sàng để Firebase (khi deploy) chỉ đóng vai trò Hosting tĩnh,
đúng định hướng đã chốt từ đầu dự án migration (mục 2 "Ngoài phạm vi Firestore/Auth (không đổi)").
**Chưa deploy** — theo đúng phạm vi đã xác nhận với Dũng, việc deploy lên 1 URL Firebase Hosting mới
(không đụng URL production hiện có) để dành cho phiên sau nếu cần xem thử từ xa.

### 4l. "Tối ưu triệt để cho Supabase" — tận dụng năng lực Postgres thật, không chỉ giả lập Firestore (2026-07-19)

Dũng hỏi thẳng: do cấu trúc lưu trữ Firebase (NoSQL, document) và Supabase (Postgres, quan hệ) khác
nhau, hệ thống đã thực sự tối ưu cho Supabase chưa, hay chỉ đang "chạy đúng" nhờ lớp shim? Trả lời
trung thực: **shim là chiến lược GIẢM RỦI RO migration (mục 3), không phải chiến lược TỐI ƯU** —
2 mục tiêu khác nhau. Đã rà lại code, tìm 3 điểm THẬT chưa tận dụng đúng thế mạnh Postgres, xác nhận
với Dũng phạm vi/mức độ rủi ro từng điểm trước khi làm (không tự ý làm hết, 1 trong 3 điểm — sửa
logic B10 — có rủi ro thật với báo cáo chính thức nên đã đổi hướng sau khi hỏi).

**#1 — Trigger tự động đồng bộ `vuan`/`bican` (ĐÃ LÀM, giá trị cao nhất)**: xem
`supabase/trigger_sync_vuan_2026-07-19.sql` — thêm trigger `bican_sync_vuan_trg` (AFTER INSERT/
UPDATE/DELETE trên `bican`) tự gọi RPC `capNhatDieuLuatVaLoaiKhoiTo` — thay cho việc code JS phải tự
NHỚ gọi RPC này sau MỌI thao tác ghi `bican` (5-6 call site rải rác: `SuaBiCanForm`, `ThemBiCanForm`,
`NhapVuModal`, `BangBiCanCon` x2). Dùng `pg_trigger_depth() > 1` để chặn đệ quy vô hạn (RPC tự
UPDATE lại `bican`, UPDATE đó lại kích hoạt chính trigger — pattern chuẩn của Postgres cho tình
huống này). **Lợi ích PHỤ quan trọng hơn cả lợi ích chính**: phát hiện + tự sửa 1 lỗ hổng THẬT đang
tồn tại — `tachVuAn` (tách vụ) chỉ tự tính `dieuLuat`/`soBiCan`/`biCanDaiDien` ở client
(`tomTatBiCan`) mà KHÔNG tính lại `loaiKhoiTo` (ban_dau/bo_sung) cho đúng nhóm bị can MỚI sau khi
tách — trigger tự vá lỗ hổng này cho MỌI lần tách vụ từ nay. Đã xoá hẳn wrapper JS
`capNhatDieuLuatVaLoaiKhoiTo` (dead code, không còn ai gọi) + đơn giản hoá `BangBiCanCon`: bỏ tham
số `canTinhLaiDieuLuat`/whitelist `CAC_TRUONG_ANH_HUONG_DIEU_LUAT` (chỉ lọc `ngayKhoiTo`/
`toiDanhChinh`), `onVuAnCoTheDoi` giờ gọi UNCONDITIONAL sau MỌI lần ghi — sửa đúng 1 gap khác: trước
đây sửa `hoTen` của bị can đang là `biCanDaiDien` không báo module cha refetch, để UI hiện tên cũ.
**Đã kiểm chứng 3 lớp**: (1) SQL cách ly (`test_trigger_sql.js`) — insert/update trực tiếp, xác nhận
không đệ quy vô hạn (dưới 100ms), `loaiKhoiTo` tự đảo đúng khi thêm bị can có ngày khởi tố sớm hơn;
(2) UI thật (`test_trigger_via_ui.js`) — "Thêm vụ án" qua form thật, đối chiếu DB trực tiếp sau đó,
JS không gọi RPC thủ công nào; (3) `BangBiCanCon` (Bảng dữ liệu Excel) qua UI thật, sửa 1 ô, 0 lỗi.
Chạy lại B10/realtime/add-vụ-án — không có gì bị phá vỡ.

**#2 — Gộp query "tải rồi join JS" thành PostgREST embed JOIN (ĐÃ RÀ, QUYẾT ĐỊNH KHÔNG LÀM)**: đếm
được 18 vị trí `Promise.all([...get(), ...get()])` kiểu tải nguyên 2 bảng rồi tự nối bằng JS (mẫu
hình gốc từ thời Firestore, nơi không có JOIN). Đối chiếu kỹ từng vị trí: **gần như toàn bộ nằm
trong công cụ quản trị/hiếm dùng** (`ImportExcelModule` đối chiếu trùng, `BackfillDieuLuatBCTool`,
`dungLaiLichSu`, `xuatExcel`) — admin bấm 1 lần, chịu thêm vài trăm ms không đáng kể, hoàn toàn khác
bối cảnh Firestore (nơi mỗi lượt đọc tốn tiền thật). Màn hình DUY NHẤT mở thường xuyên
(`DanhSachPanel`) **đã tối ưu sẵn từ thời Firestore** (cache `soBiCan`/`biCanDaiDien` ngay trên
`vuan`, chỉ tải `bican` cho đúng các dòng đang mở rộng qua `in` filter có giới hạn — không phải N+1
thật) — sửa thêm ở đây sẽ đụng vào cơ chế cursor pagination + Realtime đã tinh chỉnh cẩn thận (xem
mục 5 checklist, lý do "đóng băng trang đầu"), rủi ro thật KHÔNG tương xứng lợi ích gần như không đo
được. Đã trình bày rõ với Dũng, **xác nhận bỏ qua** — giữ nguyên 18 vị trí này, không sửa.

**#3 — Chuyển tính báo cáo sang SQL aggregation (ĐÃ THU HẸP PHẠM VI SAU KHI CẢNH BÁO RỦI RO)**: logic
gốc `tinhBieu10`/`tinhBaoCaoKyTuLog` (báo cáo thống kê CHÍNH THỨC nộp ngành, đã audit qua RẤT NHIỀU
vòng trong lịch sử dự án — xem "Trạng thái Biểu B10" ở CLAUDE.md, và vừa đối chiếu cell-by-cell 2002
ô Firestore vs Supabase ở mục 4h) **CỐ TÌNH KHÔNG ĐỤNG TỚI** — đã giải thích rõ rủi ro với Dũng
(viết lại sang SQL cần audit lại từ đầu với khối lượng tương đương lịch sử đã làm, rủi ro sai 1 con
số trên báo cáo chính thức), Dũng vẫn xác nhận muốn làm — nhưng đã chọn hướng AN TOÀN HƠN thay vì
làm y hệt yêu cầu ban đầu: tìm 1 điểm tính tổng THẬT SỰ TÁCH BIỆT khỏi pipeline B10, không phải viết
lại B10.

Tìm được: **Dashboard** (`DashboardModule`, 3 thẻ số liệu "Đang tồn") trước đây tải NGUYÊN 3 danh
sách "đang giải quyết" đầy đủ (có thể hàng trăm/nghìn dòng) chỉ để lấy `.length` — vì Firestore SDK
bản compat 10.12.2 app đang dùng KHÔNG hỗ trợ `.count()` (đã ghi ở CLAUDE.md "Ghi chú hạ tầng" từ
trước, một hạn chế lịch sử của Firestore, không phải Postgres). Đã thêm `.count()` vào lớp shim
(`_makeQuery`, dùng `sb.from(table).select("*", {count:"exact", head:true})` — PostgREST trả ĐÚNG
1 con số, KHÔNG trả rows nào) — năng lực HOÀN TOÀN MỚI so với app gốc, không tồn tại ở bản Firestore.
`DashboardModule` đổi 3 lần `.get()...length` thành 3 lần `.count()`, lọc `daXoa` NGAY TRONG QUERY
(an toàn trên Postgres vì cột `NOT NULL DEFAULT false` — khác hẳn lý do Firestore từng né
`where(daXoa,"!=",true)` vì bỏ sót document thiếu field, ghi chú rõ trong code để không ai hiểu nhầm
2 tình huống là giống nhau).
**Đã kiểm chứng bằng Playwright thật + đối chiếu SQL trực tiếp**: mở Dashboard, đọc 3 số trên UI
(36/12/7) — khớp TUYỆT ĐỐI với `SELECT coQuanThuLy, COUNT(*) FROM vuan WHERE trangThai=... GROUP BY
...` chạy thẳng qua Postgres; xác nhận qua network request thật — cả 3 request đều có header
`Prefer: count=exact`, không đường nào tải dữ liệu vụ án đầy đủ nữa (khác 2 request KHÔNG count()
còn lại của khối "cảnh báo hạn điều tra" — ĐÚNG, vì khối đó cần dữ liệu thật để tính `conLai`, không
phải ứng viên `.count()`). 0 lỗi console.

**CỐ TÌNH KHÔNG đụng B10/tinhBaoCaoKyTuLog/xuatBaoCaoThangExcel** — logic đó vẫn cần tải TOÀN BỘ
row-level data (kể cả nếu chuyển "số tổng" sang SQL, các sheet "DS ..." trong Excel vẫn là DANH SÁCH
liệt kê từng vụ/bị can, không phải chỉ 1 con số — không có cách nào tránh tải dữ liệu chi tiết cho
mục đích đó), nên "tối ưu SQL" ở đây thực chất không mang lại lợi ích tương xứng với rủi ro audit
lại. `.count()` mới thêm vào shim CÓ THỂ dùng lại sau này cho các nhu cầu "chỉ cần 1 con số" khác
(nếu phát sinh), nhưng KHÔNG áp dụng cho pipeline B10.

### 4m. Audit "2 trọng số vụ án + bị can" trên mọi phần thống kê (2026-07-19, cùng ngày)

Dũng yêu cầu rà lại TOÀN BỘ phần thống kê/báo cáo — bất kỳ chỗ nào chỉ hiện "số vụ" mà thiếu "số bị
can" đi kèm thì phải bổ sung. Đã rà bằng cách đối chiếu từng khối hiển thị số liệu, tìm được **3 chỗ
thật sự chỉ có 1 trọng số** (những chỗ khác — `KyChiTietModal`/`BangBaoCaoChiTiet` trên màn hình,
Biểu B10, TK tội danh, Tổng hợp báo cáo — đã có sẵn cả 2 trọng số từ trước, xác nhận qua code, không
cần sửa):

1. **Dashboard — 3 thẻ "Đang tồn"**: trước chỉ hiện số vụ, đổi sang tải `.get()` (thay vì `.count()`
   vừa thêm ở mục 4l — vì giờ cần cả field `soBiCan`, không chỉ đếm số dòng) rồi tính CẢ 2 số từ
   đúng 1 lượt gọi/giai đoạn: `res.docs.length` (vụ) + `sum(soBiCan)` (bị can, dùng lại cache đã
   được trigger `bican_sync_vuan_trg` giữ đúng liên tục — mục 4l). UI hiện "36 vụ / 47 bị can".
2. **Dashboard — biểu đồ "Xu hướng tồn theo kỳ"**: trước chỉ vẽ theo vụ (`tonCuoiKy`). Thêm toggle
   "Theo vụ / Theo bị can" chuyển dữ liệu biểu đồ sang `tonCuoiBiCan` (field đã có sẵn trong
   `kybaocao`, cùng hình dạng `tonCuoiKy`, chỉ chưa từng được dùng ở đây) — không cần query mới.
3. **`ThongKeKyHienTai`** (thẻ nhanh trên đầu "Danh sách vụ án", màn hình mặc định): "Mới trong
   kỳ"/"Đã giải quyết trong kỳ" trước chỉ đếm SỐ SỰ KIỆN log (= số vụ). Thêm "BC mới" = đếm sự kiện
   `khoi_to_bican` khớp `kyThongKe` — **CỐ Ý dùng ĐÚNG tiêu chí đã audit cho khối C7-C24 của Biểu
   B10** (xem CLAUDE.md "Thiết kế lại khối C7-C24"), không phát minh tiêu chí đếm mới để tránh 2 con
   số "mới trong kỳ" ở 2 nơi khác nhau của hệ thống lệch nhau vì khác phương pháp đếm. "BC giải
   quyết" = tổng `soBiCan` (cache) của các vụ vừa có sự kiện `hoan_thanh` trong kỳ.

**Chỗ RỦI RO NHẤT, xử lý cẩn thận nhất — sheet "Cân đối số liệu" trong Excel báo cáo tháng**: đây là
phần "gần B10" nhất trong 3 chỗ (cùng hàm `xuatBaoCaoThangExcel`), ban đầu cân nhắc có nên đụng vào
không (đúng tinh thần thận trọng đã áp dụng cho B10 ở mục 4l), nhưng khác hẳn "viết lại B10" —
đây là THÊM MỚI thuần tuý (không sửa/xoá bất kỳ công thức/giá trị nào của phần "Vụ" đã có), và tái
dùng NGUYÊN VẸN 2 thứ đã tồn tại/đã kiểm chứng trước đó: công thức `COUNTIF(sheet!$M:$M,"<>(Chưa có
BC)")` (đã dùng ở sheet "Tổng hợp báo cáo" từ 2026-07-15) và hàm JS `bcCountVuArr` (cache "result"
cho công thức, cũng đã có sẵn) — không phát minh logic đếm BC mới nào. Đổi cấu trúc bảng từ "3 dòng
giai đoạn" sang "6 dòng (mỗi giai đoạn 2 dòng Vụ/Bị can)", thêm cột "Loại" làm khoá phân biệt.
**Đã kiểm chứng độc lập bằng Node** (không tin công thức Excel, tự đếm lại trực tiếp cột M của từng
sheet DS): cả 3 giai đoạn hàng "Bị can" ra **Chênh lệch = 0 tuyệt đối** (khớp 100% giữa số tự đếm và
cache JS) — khác với hàng "Vụ" vẫn giữ nguyên +7/+2/+2 như trước (đúng dự kiến, do 30 sự kiện thiếu
kỳ đã biết từ mục 4h — không ảnh hưởng gì tới việc thêm hàng Bị can, xác nhận việc thêm mới không
phá vỡ tính toán "Vụ" đã có).

**Phạm vi**: chỉ áp dụng cho `qlahs-sup.html` (nhánh `supabase-migration`, đúng phạm vi làm việc
của session này) — KHÔNG mirror sang `qlva.html`/`qlva-dev.html` (production Firestore, ngoài phạm
vi nhánh này). Nếu Dũng muốn áp dụng cả cho bản Firestore, cần làm riêng ở nhánh `main`.

**Bug thật phát hiện qua ảnh chụp màn hình Dũng gửi (2026-07-19, ngay sau mục 4m)**: modal "Báo cáo
kỳ" (`KyChiTietModal`/`BangBaoCaoChiTiet`, xem trên UI) — dòng "Tồn đầu kỳ"/"Tồn cuối kỳ" hiện chỉ
1 số (VD "12"), không có "vụ/BC" như mọi dòng khác. Audit trước đó (mục 4m) đã KẾT LUẬN SAI rằng
2 dòng này "đã có sẵn cả 2 trọng số" — chỉ grep thấy `layBiCan={b => b.tonDauBiCan}` tồn tại ở lời
gọi `<H>` mà KHÔNG lần theo hết đường dây prop. Nguyên nhân thật: component `HangBaoCao` (dòng vẽ
thật) đã hỗ trợ ĐẦY ĐỦ `layBiCan` từ trước (có hẳn comment "dùng cho tồn đầu/cuối kỳ"), nhưng
wrapper `H` bên trong `BangBaoCaoChiTiet` chỉ destructure `{ nhan, lay, layDs, damNet }` — THIẾU
`layBiCan` — nên prop bị rớt mất ở tầng trung gian, không bao giờ tới được `HangBaoCao`. Sửa 1 dòng:
thêm `layBiCan` vào destructure + forward. Tiện thể dọn dòng "— Số bị can" riêng ngay dưới "— Số vụ"
(giờ đổi tên "— Số tồn hiện tại") — dòng đó vốn TRÙNG LẶP con số với chính dòng "— Số vụ" (vì dòng
đó đã dùng `layDs` nên `HangBaoCao` tự tính "vụ/BC" từ mảng — xem dòng ~7205), gây rối mắt khi nhìn
2 dòng cạnh nhau cùng hiện đúng 1 con số BC.
**Đã kiểm chứng qua UI thật**: mở đúng kỳ "Tháng 6/2026", xác nhận "Tồn đầu kỳ" hiện "12 vụ / 6 BC /
7 vụ / 5 BC / 4 vụ / 3 BC", "Tồn cuối kỳ" hiện "20 vụ / 28 BC / 9 vụ / 12 BC / 5 vụ / 6 BC" — khớp
CHÍNH XÁC với số đã tự kiểm chứng độc lập ở sheet "Cân đối số liệu" Excel (mục 4m, script
`verify_candoi_bican.js`) — 2 nơi cùng đọc `tonDauBiCan`/`tonCuoiBiCanKy`, ra cùng 1 số, xác nhận
nhất quán. Dòng "— Số bị can" riêng đã biến mất đúng như dự kiến. 0 lỗi console.
**Bài học cho lần audit sau**: khi xác nhận 1 vùng UI "đã đủ 2 trọng số", phải xác nhận qua ẢNH CHỤP/
chạy UI thật, không dừng ở việc grep thấy prop có mặt trong code — prop có mặt ở lời gọi không đảm
bảo nó THỰC SỰ được dùng tới nếu đi qua nhiều tầng component trung gian.

**Việc tiếp theo** (thứ tự khuyến nghị):
1. ~~Thử "Xuất Excel báo cáo tháng" (Biểu B10) trên ít nhất 1 kỳ đã chốt với dữ liệu mock~~ — **ĐÃ
   LÀM, xem mục 4h**. Không phát hiện lỗi migration.
2. ~~Sửa các phát hiện audit mục 4i~~ — **ĐÃ LÀM 9/10, xem mục 4j**. Còn lại #5 (batch không
   atomic) cần quyết định riêng: viết RPC `batch_commit` chạy atomic thật trong Postgres, hay chấp
   nhận rủi ro hiện tại (mất mạng giữa chừng có thể để lại dữ liệu nửa vời) tới khi có sự cố thật.
3. Phase 5 (kiểm thử toàn diện) — rà lại khoảng trống offline persistence, viết thêm kịch bản
   Playwright cho các luồng nghiệp vụ chưa test qua Supabase (Tách vụ/Nhập vụ/Xoá vụ.../Thùng rác).
4. Cân nhắc thêm UI đổi mật khẩu trong `qlahs-sup.html` trước khi 4 cán bộ thật bắt đầu dùng — hiện
   họ đang dùng chung 1 mật khẩu tạm, cần tự đổi lại mật khẩu riêng.

## 10. Nhánh `bieu-10-cong-thuc-day-du` — sheet-hoá nốt cột "Tổng thụ lý" của Biểu B10

Nhánh riêng (tách từ `supabase-migration`, theo yêu cầu Dũng "cẩn thận" trước khi đụng vào báo cáo
chính thức). Vấn đề Dũng nêu: cột "Tồn kỳ trước/kỳ này" và "Tổng thụ lý" (C3/C4, C33/C34, C60/C61)
trong sheet "Biểu B10" vẫn ghi số JS tĩnh, không có công thức Excel như các cột trọng số khác — khác
đúng vấn đề đã ghi ở CLAUDE.md ("Biểu B10 vẫn còn 1 nhóm ô chưa sheet-hoá") từ trước.

**Đã làm rõ 2 loại, chỉ sửa 1 loại**:
- **"Tồn kỳ trước/kỳ này"** (12 cột: vals[0-3, 34-37, 65-68]) — SNAPSHOT tại 1 thời điểm (từ
  `kybaocao.tonCuoiKyTheoTD` của kỳ trước/kỳ này), không phải danh sách sự kiện trong kỳ này — KHÔNG
  có DS sheet nào để SUM/COUNTIF ra, giống hệt lý do "Tồn đầu/cuối kỳ" ở sheet "Tổng hợp báo cáo"
  không sheet-hoá được. Giữ nguyên số tĩnh, đúng bản chất dữ liệu (đọc từ đâu: JSONB `tonCuoiKyTheoTD`
  lưu trong `kybaocao` lúc chốt kỳ, KHÔNG phải "không biết lấy từ đâu" — chỉ là không có sheet chi
  tiết nào tương ứng để trace).
- **"Tổng thụ lý"** (6 cột: C3/C4, C33/C34, C60/C61) — SHEET-HOÁ ĐƯỢC, vì công thức (theo đúng
  `bieu_B10_mo_ta.md` mục 3.2, đối chiếu khớp với code `tinhBieu10` đã audit từ trước) = Tồn kỳ
  trước (ô CÙNG DÒNG) + Σ(DS khởi tố+phục hồi+tách+chuyển đến+trả về của giai đoạn đó) − Σ(DS nhập
  vụ + DS chuyển đi + DS án huỷ của giai đoạn đó) — mọi thành phần đều có DS sheet sẵn có, tái dùng
  nguyên vẹn `DT_VAO`/`TT_VAO`/`XX_VAO` đã định nghĩa cho các cột khác, chỉ thêm 2 helper
  `mkThuLyVu`/`mkThuLyBc` + 6 entry mới vào `B10_FORMULA`. KHÔNG đổi GIÁ TRỊ (result vẫn = đúng số
  JS đã audit nhiều lần trước đây) — chỉ thêm formula để click-trace được trong Excel.

**Bug tự phát hiện + tự sửa trong lúc viết** (không phải giả thuyết suông): bản đầu quên trừ "DS án
huỷ {gs}" trong công thức trừ (chỉ có nhập vụ + chuyển đi) — `bieu_B10_mo_ta.md` mục 3.2 mô tả rút
gọn chỉ nêu 2 vế, nhưng code `tinhBieu10` thật (C3/C33/C60) LUÔN trừ thêm án huỷ — đối chiếu lại
đúng theo code (nguồn tin cậy đã audit nhiều lần), không theo mô tả rút gọn, tránh đổi giá trị đã có.

**Quirk hạ tầng phát hiện qua chính quá trình kiểm chứng (không phải bug của code này)**: ExcelJS
KHÔNG lưu field `result` khi giá trị = 0 (đã tự viết test cô lập xác nhận: `{formula:"1-1",
result:0}` ghi-đọc lại chỉ còn `{formula:"1-1"}`, mất `result`) — ảnh hưởng MỌI ô công thức có kết
quả 0 trong toàn bộ file (kể cả các ô ĐÃ CÓ SẴN từ trước, không riêng 6 ô mới), không phải lỗi mới
gây ra. Excel/LibreOffice thật vẫn tính đúng khi mở file thật (tự động recalculate on open, không
phụ thuộc cache) — chỉ ảnh hưởng công cụ ExcelJS dùng để KIỂM TRA lại (không đọc lại được cache=0),
không ảnh hưởng người dùng cuối. Đã điều chỉnh cách kiểm chứng để né đúng quirk này (xem dưới).

**Đã kiểm chứng 3 lớp, không chỉ tin số liệu trùng khớp ngẫu nhiên**:
1. Đối chiếu CODE trực tiếp — từng thành phần cộng/trừ trong `mkThuLyVu`/`mkThuLyBc` so khớp
   term-by-term với chính biểu thức JS tính C3/C4/C33/C34/C60/C61 trong `tinhBieu10` (phát hiện bug
   thiếu án huỷ chính từ bước này).
2. Xuất Biểu B10 thật trên dữ liệu thật hiện có (300 vụ Điều tra) — mọi ô C3/C4 có formula VÀ result
   khác 0 (VD "Điều 174 BLHS 2025" C3=171, C4=230), khớp đúng số liệu vốn đã hiển thị trước đây.
3. **Test số khác 0 riêng cho Truy tố** (dữ liệu thật hiện tại 0 vụ ở Truy tố/Xét xử nên không tự
   nhiên có ca thật để test C33/C34) — tạo 1 vụ TẠM (khởi tố mới trực tiếp tại Truy tố, kỳ "06/2026")
   qua service_role, xuất lại B10: **C33=1, C34=1 — khớp CHÍNH XÁC**, công thức tham chiếu đúng ô
   "Tồn trước" CÙNG DÒNG (`AL9`/`AM9`) + đủ 5 thành phần cộng + đủ 3 thành phần trừ. Đã xoá sạch vụ
   test ngay sau đó, xác nhận dữ liệu về lại đúng trạng thái ban đầu (300/0/0, 0 lỗi console).

**Chưa commit lên nhánh** tại thời điểm ghi chú này — sẽ commit ngay sau, xem lịch sử git để biết
hash chính xác. Phạm vi CHỈ `qlahs-sup.html` (theo yêu cầu Dũng xác nhận đầu phiên) — chưa mirror
sang `qlva.html`/`qlva-dev.html`.

## 11. Sheet-hoá nốt "Tồn kỳ trước/kỳ này" — nâng cấp quyết định ở mục 10 (2026-07-19)

Mục 10 ở trên (cùng ngày, phiên trước) đã audit và **CHỦ ĐỘNG quyết định giữ nguyên số tĩnh** cho
12 cột "Tồn kỳ trước/kỳ này" — lý do: đây là SNAPSHOT tại 1 thời điểm chốt (`kybaocao.tonCuoiKyTheoTD`),
không có DS sheet danh sách vụ nào để SUMIF/COUNTIFS ra đúng con số đó. Quyết định đó vẫn đúng theo
đúng nghĩa hẹp "không có danh sách chi tiết để SUM" — nhưng phiên này (Dũng hỏi lại, muốn xem có
công thức không) tìm ra cách vẫn **click-trace được** dù không có danh sách chi tiết: materialize
chính con số snapshot đó ra 1 sheet phụ, rồi B10 tra bằng `VLOOKUP` — không phải "true SUMIF từ
danh sách", nhưng không còn "giấu cứng" trong ô như trước.

**Lưu ý quan trọng về vị trí làm việc (Dũng nhắc trực tiếp trong phiên)**: bản nháp ĐẦU TIÊN của
sửa đổi này bị làm NHẦM trên `qlva.html`/`qlva-dev.html` (nhánh Firestore, đã lỗi thời về định
hướng — xem [[qlahsp2_supabase_future_direction]]) thay vì `qlahs-sup.html`. Đã revert sạch 2 file
đó (`git checkout --`) và làm lại đúng trên `qlahs-sup.html`, đúng file/nhánh mà mục 10 ở trên cũng
đang làm.

**Đã thêm**:
- Sheet mới **"Tồn theo ĐL (snapshot)"** — 1 dòng/điều luật, cột A=Mã ĐL (khoá tra cứu) + 12 cột số:
  6 cột `ĐT/TT/XX-Vụ/BC (trước)` LUÔN điền từ `kyTruoc.tonCuoiKyTheoTD`; 6 cột `(này)` CHỈ điền khi
  kỳ này đã chốt (`ky.tonCuoiKyTheoTD` có sẵn), để trống + 1 dòng chú thích cuối sheet nếu chưa chốt.
  `tinhBieu10` trả kèm ra ngoài 2 map đã chuẩn hoá `tonTD_truoc`/`kyTonTD` để dựng sheet này bằng
  ĐÚNG cùng dữ liệu đã dùng tính `vals[]`, tránh lệch.
- B10 tra: **"Tồn kỳ trước"** (vals[0,1,34,35,65,66]) LUÔN `IFERROR(VLOOKUP(...sheet snapshot...),0)`.
  **"Tồn kỳ này"** (vals[2,3,36,37,67,68]) VLOOKUP sheet snapshot nếu kỳ đã chốt, hoặc SUMIF/COUNTIFS
  thẳng vào "DS tồn ĐT/TT/XX" (đã có sẵn từ trước, đúng pattern các cột Vụ/BC-level khác) nếu kỳ
  chưa chốt — vì lúc đó số "này" LIVE trùng hệt dữ liệu trong chính sheet đó.
- Tương thích ngược HOÀN TOÀN với công thức "Tổng thụ lý" đã thêm ở mục 10 (`mkThuLyVu`/`mkThuLyBc`
  tham chiếu Ô CÙNG DÒNG của "Tồn kỳ trước" qua cell reference, VD `AL9`) — Excel không quan tâm ô
  được tham chiếu là giá trị tĩnh hay công thức, nên chuỗi công thức "Tồn kỳ trước → Tổng thụ lý"
  giờ đều là công thức nối tiếp nhau, không cần sửa `mkThuLyVu`/`mkThuLyBc`.
- Tiện thể sửa 1 bug có sẵn phát hiện khi audit lại đúng hàm này: `IDX_TON_NAY_VU` (dùng trong khối
  cảnh báo `canhBao`) ghi nhầm `xet_xu: 70` — đếm thủ công lại đúng 88 phần tử mảng `vals[]` xác
  nhận `xx_tn_vu` nằm ở index **67** (70 là `C61`, hoàn toàn khác ý nghĩa). Chỉ ảnh hưởng dòng cảnh
  báo chẩn đoán hiển thị khi xuất Excel, KHÔNG ảnh hưởng số liệu thật ghi ra sheet B10.

**Đã kiểm chứng bằng Node + package `exceljs` THẬT** (không chỉ đọc code) — copy nguyên văn
`tinhBieu10` (bản trước khi port sang `qlahs-sup.html`, logic giống hệt — đã diff xác nhận chỉ khác
đúng 1 chỗ là bản vá `IDX_TON_NAY_VU`) chạy thật trong Node, dựng 2 kịch bản (kỳ ĐÃ chốt / kỳ CHƯA
chốt) qua `ExcelJS.Workbook` thật, ghi file `.xlsx` ra đĩa rồi ĐỌC LẠI: sheet "Tồn theo ĐL
(snapshot)" đúng dữ liệu; ô B10 "Tồn kỳ trước" luôn `VLOOKUP`; ô "Tồn kỳ này" dùng `VLOOKUP` khi
kỳ đã chốt, `SUMIF`/`COUNTIFS` vào đúng sheet "DS tồn ĐT" khi kỳ chưa chốt; tự mô phỏng lại đúng
ngữ nghĩa VLOOKUP/SUMIF/COUNTIFS của Excel bằng tay trên dữ liệu THẬT đã ghi trong file (ExcelJS
không tự eval công thức) để xác nhận công thức sinh ra SẼ trả đúng giá trị nếu mở bằng Excel thật —
18/18 assertion PASS. `qlahs-sup.html` biên dịch sạch qua `@babel/standalone@7.25.6`.
**CHƯA mở thử bằng Excel/LibreOffice thật** và **CHƯA xuất thử trên dữ liệu Supabase thật** — nên
xuất 1 báo cáo tháng thật (cả kỳ đã chốt và kỳ đang mở) trên `qlahs-sup.html`, mở bằng Excel thật,
xác nhận không báo lỗi `#REF!`/`#N/A` trước khi coi là hoàn tất.

## 12. `batch_commit` RPC — sửa #5 (ghi không atomic), theo yêu cầu Dũng trước khi "chính thức chuyển" (2026-07-20)

Dũng hỏi "kiểm tra lại lần cuối hệ thống ổn định chưa rồi chính thức chuyển sang Supabase". Trước khi
làm gì tiếp, đã đối chiếu lại roadmap (mục 7/8) và báo Dũng 4 khoảng trống còn CHƯA xong: #5 (ghi
không atomic), chưa có UI đổi mật khẩu, chưa quyết định offline persistence, Phase 5 (kiểm thử toàn
diện) chưa làm. Dũng chọn: sửa #5 trước (rủi ro dữ liệu thật nhất), 3 việc còn lại tạm chấp nhận.

**Thiết kế**: `supabase/batch_commit_2026-07-20.sql` — hàm `batch_commit(p_ops jsonb)` nhận mảng thao
tác ĐÃ được lớp shim JS gộp+sắp đúng thứ tự phụ thuộc FK (logic sắp xếp `_sapXepTheoPhuThuoc`/
`_TABLE_INSERT_ORDER` giữ NGUYÊN, không chuyển vào SQL — chỉ đổi "N request REST tuần tự" thành "1
mảng ops, gọi RPC 1 lần"), chạy trọn trong 1 lần gọi hàm = 1 transaction Postgres thật. `_batch()
.commit()` trong `qlahs-sup.html` đổi theo — dựng `rpcOps` rồi gọi `sb.rpc("batch_commit", {p_ops})`
1 lần duy nhất thay vì nhiều `sb.from(table).insert/update/delete(...)`.

Từng dòng ghi qua `jsonb_populate_record(null::"table", data)` + build cột động từ ĐÚNG các key có
mặt trong `data` (đối chiếu `information_schema.columns`, vừa chặn injection qua key lạ vừa giữ
đúng ngữ nghĩa "field không đụng thì giữ nguyên/dùng DEFAULT" — không ghi đè NULL tường minh, đúng
bài học Phase 6 mục 9). Xử lý TỪNG DÒNG riêng (không gộp nhiều dòng cùng bảng thành 1 INSERT nhiều
VALUES) — né luôn 1 gotcha PostgREST đã biết (dòng thiếu field so với dòng khác trong cùng mảng bị
gán NULL tường minh thay vì DEFAULT) mà KHÔNG tốn thêm round-trip nào (mọi dòng vẫn chạy trong CÙNG
1 lần gọi hàm). `SECURITY INVOKER` (khác 4 hàm cũ trong `functions.sql` là `DEFINER`) — hàm này chỉ
đụng 7 bảng đã có RLS "authenticated đọc/ghi toàn bộ", không cần bỏ qua RLS như 4 hàm kia (chỉ cần
DEFINER vì phải ghi `boDemMaVu`, bảng client không được đụng trực tiếp).

**2 bug thật tự phát hiện qua kiểm thử trên Supabase THẬT (không phải giả thuyết suông), cả 2 đều
đã sửa trước khi coi là xong**:
1. Bản đầu dùng `INSERT ... ON CONFLICT (id) DO UPDATE SET <cột có trong data>` cho "upsert" (=
   Firestore `set(merge:true)`). **SAI**: Postgres validate NOT NULL của TOÀN BỘ cột trong câu
   INSERT (kể cả cột không liệt kê, tự dùng DEFAULT) TRƯỚC KHI biết có conflict hay không — cột
   NOT NULL không có DEFAULT (VD `vuan.maNoiSinh`) làm insert "thăm dò" này LUÔN lỗi 23502 dù dòng
   đã tồn tại và chỉ cần UPDATE. Bắt được qua kịch bản test "upsert lần 2 vào dòng đã có, chỉ truyền
   đúng 1 field cần đổi" — lỗi thật, không phải lý thuyết. **Đã sửa**: "upsert" tự kiểm tra tồn tại
   trước (`SELECT ... FOR UPDATE`, vừa xác định vừa khoá dòng chống race), rẽ sang ĐÚNG 1 trong 2
   nhánh insert/update THUẦN (dùng chung code với type "insert"/"update" gốc, không viết logic
   riêng dễ lệch).
2. Bước kiểm tra tồn tại ở trên ban đầu dùng biến `FOUND` sau `EXECUTE ... INTO` động — **SAI**:
   kiểm chứng thật bằng 1 hàm test cô lập trên chính Supabase xác nhận `FOUND` LUÔN ra `false` sau
   dạng `EXECUTE` này (kể cả khi có kết quả thật), không đáng tin. **Đã sửa**: dùng
   `GET DIAGNOSTICS v_row_count = ROW_COUNT` thay thế — kiểm chứng lại bằng hàm test cô lập tương tự,
   ra đúng 0/1 như kỳ vọng.

**Phát hiện phụ (KHÔNG sửa, ngoài phạm vi đã thống nhất — chỉ ghi lại cho phiên sau quyết định)**:
Supabase TỰ ĐỘNG cấp `EXECUTE` cho role `anon` (chưa đăng nhập) ngay lúc `CREATE FUNCTION` (default
privileges của project) — `revoke ... from public` (đúng như 4 hàm cũ trong `functions.sql` đang
làm) KHÔNG đụng tới quyền đã cấp THẲNG cho `anon`, phải `revoke ... from anon` TƯỜNG MINH mới chặn
được (đã làm cho `batch_commit`, xác nhận qua `information_schema.routine_privileges` + gọi thật qua
REST bằng anon key: trước khi thêm revoke này ra `HTTP 401` nhưng do RLS chặn ghi (`42501 - new row
violates row-level security policy`, hàm VẪN gọi được); sau khi thêm revoke ra đúng `HTTP 401`
`permission denied for function batch_commit` — chặn sớm hơn, sạch hơn). **Cùng lỗ hổng grant này
ĐANG tồn tại trên cả 4 hàm `SECURITY DEFINER` gốc trong `functions.sql`** (`sinhMaVuAnMoi`,
`sinhNhieuMaVuAn`, `tachVuSinhMa`, `capNhatDieuLuatVaLoaiKhoiTo`) — xác nhận qua
`information_schema.routine_privileges` thấy `anon` vẫn có `EXECUTE` trên cả 4 hàm này dù file đã có
`revoke ... from public`. Vì các hàm đó là DEFINER (bỏ qua RLS), đây là lỗ hổng THẬT: người **chưa
đăng nhập** hiện gọi được `sinhMaVuAnMoi`/`sinhNhieuMaVuAn` (tốn bộ đếm `boDemMaVu`) và
`tachVuSinhMa` (tăng `soDemTach` của BẤT KỲ `vuan` nào, không cần đăng nhập) qua REST. Rủi ro thực tế
thấp (không đọc/sửa được dữ liệu nghiệp vụ thật, RLS vẫn chặn mọi bảng khác), nhưng là lỗ hổng thật
cần vá (`revoke execute on function ... from anon;` cho cả 4 hàm) — CHƯA làm trong phiên này (ngoài
phạm vi Dũng đã chọn), để dành quyết định riêng.

**Đã kiểm chứng đầy đủ trên Supabase THẬT** (project `eutatszoaseixchvjbtg`, qua Session pooler, script
Node dùng package `pg` — không qua UI/đăng nhập, vì không tự nhập mật khẩu tài khoản người dùng được):
áp dụng SQL thành công; **14/14 assertion PASS** — insert/update/upsert (cả 2 lần: chưa tồn tại +
đã tồn tại) đúng ngữ nghĩa partial-write; **rollback ATOMIC THẬT** (1 op insert hợp lệ đứng TRƯỚC 1
op gây lỗi FK trong CÙNG batch → xác nhận op hợp lệ KHÔNG bị ghi lại, đúng vấn đề #5 cần sửa); chặn
đúng bảng ngoài whitelist (`boDemMaVu`); xoá đúng. Test JS-only riêng (mock `sb.rpc`, không đụng
Supabase thật) xác nhận 12/12 assertion về thứ tự `rpcOps` (insert theo đúng thứ tự phụ thuộc FK,
delete theo thứ tự ngược, `set(merge:true)` map đúng sang `upsert`, batch rỗng không gọi RPC thừa).
Biên dịch Babel sạch. Dọn sạch toàn bộ dữ liệu test trên Supabase sau khi xong.

**CHƯA làm/CHƯA commit tại thời điểm ghi chú này**: chưa mirror gì (đúng phạm vi chỉ `qlahs-sup.html`
+ `supabase/`). Chưa test qua UI thật (đăng nhập + thao tác nghiệp vụ thật, VD "Thêm vụ án"/"Xoá
vĩnh viễn"/Import Excel) — mới kiểm chứng ở tầng RPC/SQL trực tiếp, chưa chạy qua đúng luồng
`_batch().commit()` mới từ trình duyệt thật. Còn 3 khoảng trống Dũng đã chấp nhận tạm gác (UI đổi
mật khẩu, offline persistence, Phase 5) + phát hiện phụ "anon gọi được 4 hàm DEFINER cũ" ở trên —
CHƯA "chính thức chuyển sang Supabase" (chưa đổi 4 cán bộ thật sang dùng `qlahs-sup.html`), chờ
Dũng xác nhận sau khi cân nhắc các điểm còn lại.

**Cập nhật 2026-07-20 (ngay sau đó) — ĐÃ "CHÍNH THỨC CHUYỂN SANG SUPABASE" thật**: Dũng xác nhận
merge `bieu-10-cong-thuc-day-du` vào `main`, push (`v1.2`); deploy `qlahs-sup.html` lên site test
riêng `qlahs-sup.web.app` (`v1.3`); sau đó **đổi thẳng `qlahsp2.web.app` (production, 4 cán bộ thật)
sang chạy `qlahs-sup.html`** (`v2.0`, `./deploy.sh prod` đổi nghĩa từ deploy `qlva.html` sang
`qlahs-sup.html` — xem comment đầu `deploy.sh` để biết cách rollback khẩn cấp về `qlva.html` nếu
cần). `qlva.html`/Firestore KHÔNG bị xoá, chỉ không còn được deploy production nữa.

## 13. Offline read cache — giải quyết 1 phần khoảng trống "offline persistence" (2026-07-20)

Sau khi cắt production sang Supabase (mục 12 cập nhật), Dũng yêu cầu xử lý tiếp khoảng trống
"offline persistence" (mục "Còn treo" đã báo trước khi deploy) — nhánh riêng `offline-read-cache`
(tách từ `main`, đã chứa toàn bộ Phase 1-4/6 + batch_commit).

**Phạm vi đã bàn với Dũng trước khi làm (đề xuất, không tự quyết định 1 mình)**: CHỈ giữ **đọc**
(`.get()`/`.onSnapshot()`/`.count()`) hoạt động được bằng dữ liệu đã tải trước đó khi mất mạng GIỮA
LÚC đang dùng (đúng nhu cầu gốc đã ghi ở mục 2 "chống mất mạng tạm thời khi đang dùng", KHÔNG phải
offline-first thật). **CỐ TÌNH KHÔNG** xếp hàng/gửi lại các lượt **ghi** khi mất mạng — lý do: hồ sơ
án hình sự thật, nhiều người cùng sửa 1 vụ, gửi lại 1 lượt ghi "trễ" sau khi có mạng lại có rủi ro
ghi đè lên thay đổi của người khác xảy ra ĐÚNG TRONG LÚC mất mạng mà không ai biết — thà báo lỗi
ngay lúc ghi (hành vi ĐÃ CÓ SẴN ở mọi nơi gọi set/update/delete/batch_commit, không cần sửa) còn
hơn âm thầm ghi sai lên báo cáo/vụ án thật. Cache CHỈ ở bộ nhớ (không IndexedDB/localStorage, mất
khi tải lại trang) — dữ liệu án cũ tồn tại qua nhiều ngày trong cache đĩa không kiểm soát được có
thể gây hiểu nhầm nghiêm trọng hơn lợi ích, khác hẳn cache lạnh IndexedDB đã làm cho "Án đã giải
quyết" thời Firestore (đó là dữ liệu GẦN NHƯ BẤT BIẾN, không phải dữ liệu đang thay đổi liên tục).

**Thiết kế** (`_getWithFallback`/`_readCacheStore`/`_isLikelyNetworkError`, đặt cạnh `_makeDocSnapshot`
đầu lớp shim): mọi lần `.get()`/`.count()` thành công tự lưu kết quả vào 1 `Map` trong bộ nhớ theo
`cacheKey` (dạng `"doc:<table>:<id>"` hoặc `"query:<table>:<JSON.stringify(state)>"`). Khi 1 lần gọi
LỖI, chỉ dùng cache thay thế nếu lỗi **trông giống mất kết nối thật** (`_isLikelyNetworkError`: lỗi
KHÔNG có field `code` — mọi lỗi PostgREST trả về đều CÓ `code`/`details`/`hint`, chỉ lỗi `fetch()` tự
ném (mất mạng/DNS/timeout) mới thiếu field này) — cố tình **KHÔNG** dùng cache để che giấu lỗi
permission/RLS/query sai thật (những lỗi đó phải hiện ra ngay, giấu đi sẽ biến bug thật thành
"tưởng đang mất mạng"). Doc/query CHƯA từng tải thành công lần nào thì vẫn ném lỗi bình thường (không
có gì để dùng tạm). Áp dụng ở đúng 3 nơi: `_makeDocRef.get()`, `_makeQuery.get()` (cả 2 nhánh phân
trang/không phân trang), `_makeQuery.count()` — **`.onSnapshot()` tự động hưởng lợi** vì `_subscribe`
gọi lại chính `.get()` làm `fetchFn`, không cần sửa gì thêm ở đó. Cache giới hạn 300 entry (LRU thô
qua thứ tự chèn của `Map`), tránh phình vô hạn qua 1 phiên dùng rất dài.

Banner cảnh báo mất mạng (`OfflineBanner`/`useOnline`) đã có sẵn từ trước (sót lại từ bản Firestore,
không bị dọn trong đợt "dọn tàn dư Firebase" — xem mục 4k) — không cần thêm UI mới, chỉ thêm
`console.warn` khi cache được dùng để dễ chẩn đoán lúc debug.

**Đã kiểm chứng bằng test Node cô lập** (`vm` module, mock `sb.from()`/`.channel()`, không đụng
Supabase thật — đúng cách đã dùng để test thứ tự `batch_commit` ở mục 12): 8/8 assertion PASS — đọc
thành công rồi mất mạng trả đúng dữ liệu cũ (doc lẫn query); doc/query CHƯA từng tải thành công vẫn
ném lỗi đúng khi mất mạng; lỗi PostgREST thật (có `code`) KHÔNG bị cache che giấu dù đã có cache sẵn;
`onSnapshot()` tự động hưởng lợi qua đường gọi lại `get()`. Biên dịch Babel sạch. Test qua trình
duyệt thật (server cục bộ, chưa đăng nhập — không tự nhập mật khẩu được) xác nhận màn đăng nhập tải
sạch, 0 lỗi console.

**CHƯA kiểm chứng**: test qua UI thật CÓ đăng nhập (mô phỏng mất mạng thật giữa lúc xem dữ liệu qua
DevTools "offline" hoặc rút wifi) — cùng giới hạn không tự đăng nhập được đã gặp ở các phần trước.
Nên tự thử 1 lần: mở 1 màn có dữ liệu (VD Danh sách vụ án), bật chế độ "Offline" trong DevTools, thao
tác lại (chuyển tab/tìm kiếm) — xác nhận dữ liệu đã tải vẫn hiện được, không trắng màn hình/không báo
lỗi vô nghĩa; thử LƯU 1 thay đổi trong lúc offline — xác nhận báo lỗi rõ ràng (không âm thầm mất/
không tự động gửi lại khi có mạng).
