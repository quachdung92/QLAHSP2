# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Port 2 bug fix từ nhánh `bang-excel-cai-dat` vào `main` (2026-07-18)

Nhánh `bang-excel-cai-dat` (tính năng Cài đặt → "Bảng dữ liệu" kiểu Excel, xem mục riêng ở "Tiến độ
đã code") có 2 commit sửa bug THẬT không liên quan gì tới tính năng Bảng dữ liệu — **chỉ port đúng 2
bug fix này vào `main` qua `git cherry-pick`, KHÔNG merge toàn bộ tính năng Bảng dữ liệu** (theo yêu
cầu người dùng, tính năng đó để merge riêng sau — xem "Cài đặt → 'Bảng dữ liệu' (2026-07-17)" ở dưới,
hiện chỉ tồn tại trên `bang-excel-cai-dat`, chưa có trên `main`/production):
- **Thời hạn bảo quản floor-lookup** (commit gốc `1344097`) — xem chi tiết đầy đủ ở mục "Nộp hồ sơ
  lưu trữ + cột 'Thời hạn bảo quản'" bên dưới, đoạn "Bug đã sửa (2026-07-16...) — bảng gốc là HÀM
  BẬC THANG".
- **Race condition lost-update khi sửa bị can** (commit gốc `b976726`) — xem mục "Audit 'tối ưu hệ
  thống'" bên dưới.

Cherry-pick trên nhánh tạm `fix-race-thoihan` (đã xoá sau khi merge xong), có xung đột thủ công ở
`DongGiaoNhan`/`ghiNhanVuVaoPhien` (field `mucAnThang` mới va chạm với field `khongTiepNhan`/
`lyDoKhongTiepNhan` thêm sau trên `main` — đã gộp cả 2, không mất field nào) và ở `SuaBiCanForm`/
`ThemBiCanForm` (đổi `batch.commit()` cũ sang gọi `capNhatDieuLuatVaLoaiKhoiTo` mới). CLAUDE.md cũng
xung đột ở 2 chỗ chèn nội dung cùng vị trí — gộp cả 2 phía, không bỏ nội dung nào.

**Đã kiểm chứng lại SAU KHI merge bằng Playwright thật qua UI** (không chỉ tin tưởng merge tự động
đúng) — kịch bản: (1) bắt đầu phiên Nhận + bật "Nộp hồ sơ lưu trữ", quét 1 vụ Đã xét xử, nhập mức án
"3 năm 5 tháng" ngay tại dòng, xác nhận cột Thời hạn bảo quản hiện đúng **"19 năm"** (mốc floor "3",
không phải `null`/không phải chỉ chấp nhận giá trị khớp tuyệt đối); (2) mở 1 vụ có 2 bị can, sửa 1 bị
can qua nút "Sửa" của đúng dòng bị can, xác nhận ghi cả `bican.update` LẪN `vuan.update` (bằng chứng
`capNhatDieuLuatVaLoaiKhoiTo` chạy qua transaction, không còn `batch.commit()` cũ) — cả 2 kịch bản
PASS trên cả `qlva.html` VÀ `qlva-dev.html`, 0 lỗi console.

**Đã deploy lên cả `qlahs-test.web.app` VÀ `qlahsp2.web.app` (production)** qua `./deploy.sh test`
rồi `./deploy.sh prod`, cộng thêm `firebase deploy --only firestore:indexes` cho cả 2 project (index
`lichsuChuyenGiaiDoan: kyThongKe+loaiSuKien+tuGiaiDoan` mới từ `b976726`). Smoke test bằng Playwright
sau deploy (không đăng nhập) trên cả 2 URL — trang tải đúng, 0 lỗi console.

## Tối ưu Firestore ĐÃ LÊN PRODUCTION (2026-07-18)

Toàn bộ kế hoạch tối ưu Firestore (Đợt 1 gộp listener, Đợt 2 Thùng rác + cache lạnh IndexedDB, hot
data sentinel `meta/vuAnMoiNhat`) — xem đầy đủ ở các mục "Tối ưu Firestore..." bên dưới — **đã
deploy lên CẢ `qlahs-test.web.app` VÀ `qlahsp2.web.app` (production, dữ liệu thật)** qua
`./deploy.sh test` rồi `./deploy.sh prod`, dựa trên code của nhánh `toi-uu-firestore-read` (bản
thân nhánh git vẫn CHƯA merge vào `main` — hosting deploy độc lập với việc merge, chỉ copy nguyên
`qlva.html` hiện có trong thư mục làm việc lúc chạy `deploy.sh`, không quan tâm branch). Đã kiểm tra
lại production sau deploy bằng Playwright (không đăng nhập, không có tài khoản thật) — trang tải
đúng, màn hình đăng nhập hiện sạch, 0 lỗi console.
**Lưu ý cho phiên sau**: nếu merge nhánh `toi-uu-firestore-read` vào `main`, nhớ đối chiếu `main`
đã khớp đúng nội dung đã lên production hay chưa (deploy trước, merge sau — thứ tự ngược với quy
trình thông thường merge-rồi-mới-deploy) để tránh `main` và production lệch nhau về sau.
**Ý tưởng đã cân nhắc rồi CHỦ ĐỘNG bỏ**: timer đồng bộ định kỳ 60s cho cache lạnh "Án đã giải
quyết" — xem bộ nhớ dài hạn `toi-uu-firestore-effectiveness` (lý do: remount tự nhiên đã đủ cho hệ
thống ít user, chủ yếu xem/trích xuất).

## Tối ưu Firestore — "hot data" (vụ ĐANG giải quyết): bỏ live, dùng sentinel "có vụ mới" (2026-07-18)

Tiếp theo các mục "Tối ưu Firestore" bên dưới (Đợt 1: gộp listener; Đợt 2: Thùng rác + cache lạnh
cho vụ ĐÃ giải quyết) — mục này xử lý phần còn lại: vụ **ĐANG** giải quyết ("hot data"). Quyết định
thiết kế đã thống nhất với người dùng (hệ thống ít user, chủ yếu dùng để xem/trích xuất dữ liệu, ưu
tiên tiết kiệm đọc hơn độ mới tức thời): **danh sách "đang giải quyết" bỏ hẳn `onSnapshot` sống**,
chỉ tải 1 lần — CHỈ vụ án MỚI TẠO mới cần biết ngay, mọi thay đổi KHÁC của vụ đã có sẵn (đổi KSV,
chuyển giai đoạn, hoàn thành...) chấp nhận cũ, tự làm mới khi component remount (chuyển tab đi rồi
quay lại). `ChiTietPanel` (đang sửa 1 vụ cụ thể) KHÔNG đổi — vẫn `onSnapshot` riêng theo đúng 1 doc.

**Cơ chế sentinel** (`dsDangGiaiQuyetRegistry`/`dongBoDsDangGiaiQuyet`/`useDanhSachDangGiaiQuyet`,
đặt cạnh các cache khác ở đầu file) — 1 document cảm biến bé xíu `meta/vuAnMoiNhat` (field
`capNhatLuc`) được cập nhật kèm theo trong CÙNG batch ở **đúng 3 nơi tạo `vuan` mới**:
`ThemVuAnForm`, `ImportExcelModule`, `tachVuAn` (vụ tách ra cũng là 1 vụ "mới"). Mọi client chỉ giữ
**đúng 1 listener rẻ** trên sentinel này (không unsub — chi phí 1 document gần như bằng 0) thay vì
theo dõi cả danh sách; hễ đổi thì chạy 1 query nhỏ `where("trangThai","==","dang_giai_quyet")
.where("ngayTao", ">", lầnBiếtGầnNhất)` bổ sung đúng (các) vụ mới, không tải lại toàn bộ. Lần đầu
(chưa có cache) tải trọn 1 lần bằng `.where("trangThai","==","dang_giai_quyet")` không kèm điều
kiện `ngayTao`.

**`DanhSachPanel`** (Danh sách vụ án) tách 2 nhánh rõ ràng: tab "Đang giải quyết" dùng
`useDanhSachDangGiaiQuyet()` (nguồn mới), tab "Tất cả" GIỮ NGUYÊN `onSnapshot` có giới hạn như cũ
(trộn hot+cold, chưa áp dụng sentinel — xem "Ngoài phạm vi" ở mục cache lạnh). **`fetchWithTtlCache`
ban đầu dùng cho "Tìm thủ công" ở `GiaoNhanHoSoModule` đã bị TRIM/thay bằng chính
`useDanhSachDangGiaiQuyet()`** — 2 nơi cùng cần ĐÚNG 1 tập dữ liệu, gộp lại tránh 2 cơ chế cache
khác nhau tồn tại song song cho cùng 1 dữ liệu (dễ lệch nhau/khó hiểu về sau, đúng yêu cầu người
dùng "trim mọi phương án thừa và có khả năng gây conflict"). `fetchWithTtlCache` vẫn giữ lại, dùng
cho `NhapVuModal` (query khác hẳn — 300 vụ gần nhất theo `ngayTao`, không lọc `trangThai` trước).

**Cập nhật cục bộ cho đúng thao tác của CHÍNH người dùng** (`capNhatCucBoDsDangGiaiQuyet`) — phát
hiện qua test: "Đưa vào thùng rác"/"Khôi phục" 1 vụ đang có sẵn trong danh sách KHÔNG kích hoạt
sentinel (không phải vụ mới) — nếu không xử lý riêng, vụ vừa bị chính người dùng xoá vẫn nằm y
nguyên trước mắt họ cho tới khi remount, gây khó hiểu dù dữ liệu Firestore đã đúng. Đã thêm cập
nhật trực tiếp vào bộ nhớ (không qua Firestore) ngay sau khi `XoaVuAnModal`/`ThungRacModule.khoiPhuc`
ghi thành công — chỉ ảnh hưởng đúng trình duyệt của người vừa thao tác, người khác vẫn chờ remount
tự nhiên như thiết kế ban đầu (không phá vỡ nguyên tắc "hot data không cần live").

**Bug tự phát hiện + tự sửa trong lúc viết test (không phải giả thuyết suông)**: bản đầu tiên của
sentinel listener bị bắn **2 lần** ngay lúc khởi tạo (1 lần do gọi trực tiếp `dongBoDsDangGiaiQuyet()`
lúc mount, 1 lần do chính `onSnapshot` của sentinel tự bắn lại giá trị HIỆN CÓ ngay khi vừa subscribe
— hành vi chuẩn của Firestore, không phải lỗi) → tốn gấp đôi số `.get()` mỗi lần tải trang so với dự
kiến. Sửa bằng cách bỏ qua đúng lần bắn đầu tiên của sentinel (`laLanBanDau` flag).

**Composite index MỚI cần thiết** (đã thêm vào `firestore.indexes.json`, **đã deploy CẢ HAI**
`qlahs-test` VÀ `qlahsp2` production — an toàn vì chỉ thêm index, không đụng code/dữ liệu, và
`qlva.html` production hiện tại chưa có code dùng tới nên không ảnh hưởng gì tới người dùng thật
đang chạy): `vuan: trangThai ASC + ngayTao ASC` — Firestore yêu cầu vì query delta kết hợp 1 field
bằng (`trangThai`) với 1 field khoảng/bất đẳng thức khác (`ngayTao`). Phát hiện qua test dữ liệu
Firestore thật (mock không mô phỏng ràng buộc index nên không phát hiện được) — lúc index đang
build, sentinel tạm thời "lặng lẽ" không bổ sung được vụ mới (lỗi bị `catch` + `console.error`,
không crash UI) — tự khỏi khi build xong, không cần can thiệp gì thêm.

**Đã kiểm chứng bằng Playwright thật** (bộ mock: 9/9 assertion pass riêng cho sentinel + 26/26 pass
hồi quy toàn bộ Đợt 1/2 sau khi tích hợp — không có gì bị phá vỡ) VÀ **dữ liệu Firestore thật trên
`qlva-dev.html`** (project `qlahs-test`, 55 vụ đang giải quyết thật) — tạo 1 vụ án test thật, xác
nhận xuất hiện ngay qua sentinel SAU KHI index build xong (đã tự xác nhận lại bằng cách chạy lại
test — trước khi build xong sentinel bỏ qua vụ mới, không crash; sau khi build xong hoạt động đúng
100%), dọn dẹp sạch sau test. Trong lúc viết test mock cũng tự bổ sung `mock-firebase.js` (đếm
listener theo document riêng biệt với theo query, thêm `.add()`) — 2 chỗ mock thiếu, không phải bug
thật của app. Đã rà thêm các trường hợp biên qua suy luận (không chỉ test tự động): 2 vụ mới tạo sát
nhau nếu làm "nuốt" 1 tín hiệu sentinel thì lần đồng bộ kế tiếp (remount tự nhiên hoặc tín hiệu sau)
vẫn tự vét đủ nhờ query delta luôn hỏi "mọi thứ mới hơn mốc đã biết" chứ không phải "đúng 1 sự kiện
vừa báo" — tự lành, không mất dữ liệu vĩnh viễn.

**Ngoài phạm vi (chưa làm, chấp nhận là giới hạn hiện tại)**: tab "Tất cả" của Danh sách vụ án (trộn
hot+cold) chưa áp dụng cơ chế này. Khoá tránh xung đột sửa đồng thời ("ấn vào vụ X thì khoá cảnh báo
tài khoản khác") đã bàn và CHỦ ĐỘNG loại khỏi phạm vi tối ưu Firestore — dự án đã chọn hướng
transaction optimistic concurrency (xem "Audit tối ưu hệ thống") thay vì khoá thủ công.


## Tối ưu Firestore Đợt 1+2 — đã kiểm chứng bằng dữ liệu Firestore THẬT trên `qlva-dev.html` (2026-07-17)

Tiếp theo 2 mục "Tối ưu Firestore" bên dưới (Đợt 1: gộp listener + `ngayCapNhat`; Đợt 2: Thùng rác +
cache lạnh IndexedDB) — cả 2 trước đó mới chỉ kiểm chứng bằng mock Firestore trong bộ nhớ. Đã đăng
nhập THẬT vào `qlva-dev.html` (tài khoản có sẵn từ `seed-tool.html`: `admintest@local.com` /
`12345678`, project `qlahs-test`) qua Playwright tự dựng, thao tác trên dữ liệu thật (54 vụ đang
giải quyết, 1331 vụ đã giải quyết) — không phải bản mô phỏng nhỏ.

**Kết quả**: cache lạnh IndexedDB lưu đúng **1331 document thật** (không phải vài document giả lập),
field ngày tháng chuyển đúng sang `Date` gốc hợp lệ ở quy mô thật. Thùng rác test trọn vòng đời trên
2 vụ án tự tạo (tạo → đưa vào thùng rác → biến mất khỏi Danh sách vụ án trong vòng ~0.5s → hiện đúng
trong Thùng rác → Xoá vĩnh viễn → dọn sạch, không để lại rác trên `qlahs-test`) — đúng hoàn toàn,
không phát sinh lỗi console nào do các thay đổi Đợt 1/2 gây ra.

**Phát hiện 1 lỗi CÓ SẴN TỪ TRƯỚC, không liên quan tối ưu Firestore**: mở panel chi tiết bất kỳ vụ
án nào báo lỗi console thật `FirebaseError: The query requires an index` cho query
`lichsuChuyenGiaiDoan` (`maVuAn`+`thoiDiemGhi`). Index này **đã có sẵn đúng trong
`firestore.indexes.json`** (dòng 13-19) nhưng chưa từng được deploy lên project `qlahs-test` (có lẽ
chỉ deploy lên production `qlahsp2` trước đây) — nghĩa là tab "Lịch sử" trong panel chi tiết đã bị
lỗi thật trên môi trường test trong 1 khoảng thời gian không rõ từ khi nào. Đã chạy `firebase deploy
--only firestore:indexes --project test` để sửa — Firestore cần vài phút để build xong index mới
trên collection đã có nhiều document, nên lỗi có thể còn thấy tạm thời ngay sau khi deploy, tự hết
khi build xong (không cần làm gì thêm, kiểm tra lại sau vài phút nếu còn thấy lỗi này).

**Kết luận**: Đợt 1+2 tối ưu Firestore sẵn sàng cân nhắc đưa lên `qlva.html` production — đã qua đủ
2 lớp kiểm chứng (mock cô lập + dữ liệu Firestore thật quy mô lớn), không phát hiện lỗi nào do chính
các thay đổi này gây ra.

## Tối ưu Firestore — Đợt 2 (phần 2): Cache lạnh IndexedDB cho vụ án ĐÃ GIẢI QUYẾT (2026-07-17)

Mảnh cuối của kế hoạch tối ưu Firestore 4 giai đoạn — mục tiêu: vụ đã giải quyết gần như bất biến
nên lưu VĨNH VIỄN trên máy người dùng qua IndexedDB, chỉ hỏi lại Firestore đúng phần THAY ĐỔI thay
vì tải lại toàn bộ mỗi lần mở "Án đã giải quyết" — chi phí đồng bộ tỉ lệ với SỐ THAY ĐỔI THẬT, không
tỉ lệ với tổng số vụ đã giải quyết tích luỹ từ trước (sẽ càng quan trọng khi dữ liệu nhiều năm).

**Cơ chế (`dongBoColdCacheVuAnDaGiaiQuyet`, đặt cạnh `AnDaGiaiQuyetModule`)**: lần đầu (chưa có
cache) tải trọn 1 lần bằng `where("trangThai", "!=", "dang_giai_quyet")` — hợp lệ vì chỉ 1 field bất
đẳng thức. Lần sau, **Firestore KHÔNG cho kết hợp 2 field bất đẳng thức khác nhau trong 1 query**
(không thể vừa `trangThai != X` vừa `ngayCapNhat > Y`), nên đồng bộ tăng dần dùng ĐÚNG 1 field bất
đẳng thức duy nhất — `where("ngayCapNhat", ">", lầnSyncTrước)` cho MỌI vụ bất kể trạng thái — rồi tự
phân loại lại ở phía client: vụ vừa chuyển SANG "đã giải quyết" thì thêm/cập nhật vào cache; vụ vừa
chuyển VỀ "đang giải quyết" (Phục hồi/"Xoá hình thức giải quyết") thì xoá khỏi cache lạnh (không còn
lạnh nữa). Nhờ vậy các trường hợp đặc biệt (Phục hồi, nhập mức án lúc nộp lưu trữ...) tự động được
xử lý đúng mà không cần code riêng — cả 2 đều là 1 lần GHI vào `vuan`, tự cập nhật `ngayCapNhat`.

**Lưu ý kỹ thuật quan trọng phát hiện lúc code (không phải lý thuyết suông)**: Firestore `Timestamp`
là 1 class riêng, KHÔNG phải kiểu dữ liệu gốc trình duyệt — thuật toán "structured clone" mà
IndexedDB dùng để lưu dữ liệu không đảm bảo giữ nguyên prototype của class tự định nghĩa (khác
`Date` gốc — được hỗ trợ đúng, giữ nguyên `.getTime()`). Lưu thẳng `Timestamp` vào IndexedDB sẽ mất
`.toDate()`/`.toMillis()` khi đọc lại, làm hỏng MỌI chỗ hiển thị ngày tháng của dữ liệu lấy từ cache
— đã thêm `sanitizeChoIndexedDb(doc)` chuyển các field dạng Timestamp sang `Date` gốc TRƯỚC khi ghi
(an toàn vì `fmtDate`/`fmtNgayGio`/mọi so sánh ngày trong app đều đã viết theo kiểu
`x?.toDate?.() ?? (x instanceof Date ? x : new Date(x))` — tương thích sẵn cả 2 dạng).

**`AnDaGiaiQuyetModule` đấu nối vào cache lạnh** — bỏ hẳn `onSnapshot` theo TỪNG hình thức giải
quyết (5 listener khác nhau tuỳ tab, tải lại Firestore mỗi lần đổi tab); giờ đồng bộ 1 lần lúc mount
(toàn bộ vụ đã giải quyết mọi hình thức), 5 tab chuyển đổi CHỈ lọc lại phía client
(`listTheoHinhThuc`), **không gọi Firestore nữa khi đổi tab** — tác dụng phụ tốt: chuyển tab giờ tức
thời. Đánh đổi: không còn realtime — chấp nhận vì đúng tiền đề "gần như bất biến" của cache lạnh.
Vá 1 khe hở còn lại: nếu người dùng thao tác (Phục hồi/Xoá hình thức giải quyết) NGAY TẠI
`ChiTietPanel` bên phải của chính module này (không phải remount cả module) — bọc `onDoiSelected`
để tự đồng bộ lại (delta, rẻ) ngay sau đó, tránh danh sách bên trái vênh với trạng thái mới nhất.

**Đã kiểm chứng bằng Playwright thật + IndexedDB thật của trình duyệt** (không mock IndexedDB — dùng
API `indexedDB` thật trong Chromium headless) — 26/26 assertion pass tổng cộng cho cả Đợt 1+2, riêng
phần cache lạnh: xác nhận IndexedDB lưu đúng 1 document, field ngày là `Date` gốc hợp lệ (không phải
Timestamp hỏng/Invalid Date); lần mount tiếp theo KHÔNG lặp lại full-sync mà dùng đúng đường delta;
dữ liệu vẫn hiển thị đúng sau khi chuyển từ full-sync sang delta-sync. **Sự cố gặp phải khi tự viết
test (đã tự phát hiện và sửa, không phải bug thật của app)**: quên mirror thay đổi từ `qlva.html`
sang `qlva-dev.html` trước khi chạy test lần đầu — test "im lặng" báo 0 lượt gọi Firestore vì code
mới chưa tồn tại ở file đang test; sau khi mirror đúng thì pass sạch — bài học: LUÔN mirror trước
khi test, không chỉ trước khi commit.
**Còn lại chưa kiểm chứng**: dữ liệu Firestore THẬT trên `qlva-dev.html` (project `qlahs-test`) —
nên mở thử ít nhất 1 lần, xem "Án đã giải quyết" tải đúng, chuyển tab tức thời, và F12 → Application
→ IndexedDB xác nhận thấy đúng database `qlva_cold_cache_v1` trước khi tin tưởng lên production.

**Ngoài phạm vi Đợt 2 (không làm, chấp nhận là giới hạn hiện tại)**: cache lạnh CHƯA áp dụng cho
`baoCaoLuu` của kỳ báo cáo đã chốt (mục tiêu ban đầu có nhắc tới) — phần lớn lợi ích thực tế đã đạt
được gián tiếp qua Đợt 1 (cache `kybaocao` dùng chung, tránh đọc lặp `baoCaoLuu` giữa nhiều
component), phần còn thiếu chỉ là bền vững qua LẦN TẢI TRANG MỚI — giá trị tăng thêm nhỏ so với rủi
ro đụng vào logic Biểu B10 đã audit kỹ nhiều lần, nên dừng lại ở đây. Cache lạnh cũng CHƯA áp dụng
cho tab "Tất cả" của Danh sách vụ án (trộn lẫn vụ đang + đã giải quyết, khó tách hot/cold sạch như
`AnDaGiaiQuyetModule` — module dành riêng cho dữ liệu lạnh nên là ứng viên tự nhiên nhất).

## Tối ưu Firestore — Đợt 2 (phần 1): Thùng rác — xoá vụ án đổi từ xoá cứng sang soft-delete (2026-07-17)

Nền tảng bắt buộc cho cache lạnh IndexedDB (xem "Ngoài phạm vi Đợt 1" ở mục Đợt 1 bên dưới) —
query kiểu `where(ngayCapNhat > lầnSyncTrước)` không bao giờ thấy được việc XOÁ document, nên phải
biến "xoá" thành "ghi" trước khi cache lạnh có thể tin tưởng dùng delta-check.

**`XoaVuAnModal` đổi hẳn từ cascade xoá cứng sang đặt cờ** — không còn `batch.delete` lên
`bican`/`lichsuChuyenGiaiDoan`/`vuan`, chỉ `update({ daXoa: true, ngayXoaMem, nguoiXoaMem,
ngayCapNhat, nguoiCapNhatCuoi })` lên đúng `vuan`. Giữ nguyên `bican`/log để: (1) Khôi phục chỉ cần
gỡ cờ, không mất gì; (2) số liệu báo cáo kỳ (tính từ log) không bị ảnh hưởng cho tới khi thật sự
"Xoá vĩnh viễn". Xác nhận đổi từ "gõ lại đúng mã vụ" sang gõ lại **1 mã 4 ký tự SINH NGẪU NHIÊN**
hiển thị ngay trên màn hình (`taoMaXacNhanNgauNhien`, bộ ký tự `BO_KY_TU_MA_XAC_NHAN` loại bỏ
0/O/1/l/I để tránh gõ nhầm vì đọc nhầm) — vì giờ thao tác này CÓ THỂ hoàn tác, không cần mức xác
nhận chặt như trước. Giữ nguyên guard chặn xoá nếu còn vụ con tách ra từ vụ này (`vuGoc`).

**Module mới "Thùng rác"** (`ThungRacModule`, tab thứ 5 trong `CaiDatModule`, sau "Import Excel") —
liệt kê `vuan` có `daXoa == true` (query trực tiếp qua Firestore, KHÔNG có vấn đề như `!=` vì đây là
so khớp `==true`), mỗi dòng có 2 nút: **"Khôi phục"** (gỡ cờ `daXoa`/`ngayXoaMem`/`nguoiXoaMem`) và
**"Xoá vĩnh viễn"** (mở `XoaVinhVienModal` — logic cascade xoá y hệt `XoaVuAnModal` bản CŨ, giữ
nguyên mức xác nhận chặt "gõ lại đúng mã vụ" vì đây mới là hành động thật sự không thể hoàn tác).

**Lọc `daXoa` khỏi mọi nơi liệt kê `vuan` cho người dùng xem** — cố tình lọc phía **CLIENT**
(`.filter(v => !v.daXoa)` sau khi map dữ liệu), **KHÔNG dùng Firestore `where("daXoa","!=",true)`**:
query `!=` bỏ qua LUÔN mọi document không có field đó, mà toàn bộ dữ liệu cũ chưa từng có field
`daXoa` — lọc ở tầng Firestore sẽ làm mất trắng danh sách. Đã áp dụng ở: `DanhSachPanel` (cả query
chính lẫn `dsTimKiemDayDu`), `AnDaGiaiQuyetModule`, `DashboardModule` (2 nơi: đếm theo giai đoạn +
cảnh báo hạn điều tra), `tinhSnapTonTheoTD`/`tinhTonHienTaiTheoGD`/`tinhBaoCaoKyTuLog` (3 hàm tính
"tồn" của Kỳ báo cáo — dùng biến trung gian `demsDocs` để không phải sửa rải rác nhiều chỗ dùng lại
cùng 1 mảng snapshot), `GiaoNhanHoSoModule` (Tìm thủ công), `NhapVuModal` (tìm vụ đích), `xuatExcel`,
`ImportExcelModule` (đối chiếu trùng — vụ đã trashed KHÔNG tính là trùng, vì trash dùng để sửa sai
sót nên import lại đúng dữ liệu phải được cho phép).
**Cố tình CHƯA lọc** `vuAnTuLogDocs` (dùng bởi `tinhBaoCaoKyTuLog` để dựng các mảng `ds` xuất ra
sheet Excel báo cáo tháng, ảnh hưởng trực tiếp tới công thức SUMIF/COUNTIF của Biểu B10) — rủi ro
cao hơn hẳn các nơi trên vì đụng vào logic đã được audit kỹ nhiều lần trước đây (xem "Trạng thái
Biểu B10"), cần cân nhắc riêng nếu có nhu cầu thực tế (hiện chưa có vụ nào bị trash trên production).

**Đã kiểm chứng bằng Playwright thật** (cùng bộ mock Firestore/Auth dựng ở Đợt 1) — 18/18 assertion
pass, gồm cả kịch bản end-to-end đầy đủ: mở panel chi tiết → bấm "Đưa vào thùng rác" → xác nhận mã
ngẫu nhiên đúng định dạng 4 ký tự → gõ đúng mã → xác nhận vụ biến mất khỏi Danh sách vụ án → xác
nhận vụ hiện đúng trong tab Thùng rác → bấm "Khôi phục" → xác nhận vụ biến mất khỏi Thùng rác VÀ
hiện lại đúng trong Danh sách vụ án → xác nhận cả 2 lần ghi (`daXoa:true` lúc xoá, `daXoa:false` lúc
khôi phục) đều đúng field, lần xoá có kèm `ngayCapNhat`. **Còn lại chưa kiểm chứng**: dữ liệu
Firestore thật trên `qlva-dev.html` (project `qlahs-test`) — nên thử ít nhất 1 lần trước khi tin
tưởng lên `qlva.html` production, đặc biệt xác nhận Security Rules hiện tại (chỉ chặn theo
`request.auth != null`) không cần sửa gì để `update` field `daXoa` hoạt động (không có rule riêng
theo field nên nhiều khả năng không cần, nhưng chưa xác nhận thật).

## Tối ưu Firestore — Đợt 1: gộp listener trùng + chuẩn bị nền cho cache lạnh (2026-07-17)

Audit theo yêu cầu người dùng: tài khoản Firebase hết quota nhanh vì "bất kỳ thao tác nào cũng
truy vấn lại từ đầu". Đếm trực tiếp trong code xác nhận cụ thể (không phải áng chừng): `canbo` bị
gắn **6 listener độc lập** (`useDanhSachCanBo()` gọi ở `ThemVuAnForm`/`SuaVuAnForm`/`DanhSachPanel`/
`ChiTietVuAnModal`/`GiaoNhanHoSoModule` + 1 nơi riêng ở `CanBoModule`), `kybaocao` bị gắn **6 nơi
tốn đọc độc lập** (5 `onSnapshot` ở `DanhSachPanel`/`KyBaoCaoModule`/`AnDaGiaiQuyetModule`/
`DashboardModule`/`NhatKyModule`, **cộng thêm `ModalXacNhanKy` tự `.get()` lại TOÀN BỘ collection
MỖI LẦN MỞ** — modal này mở ở MỌI thao tác nghiệp vụ nên đây mới là điểm tốn quota nhiều nhất, dù
không lộ ra qua `onSnapshot` lúc grep ban đầu), `danhMucToiDanh` bị gắn 2 listener độc lập.

**Thiết kế: lớp cache/listener dùng chung** (`useFirestoreCollectionCache`/`useFirestoreCacheLoaded`,
đặt đầu file cạnh các hook dùng chung khác, dòng ~1129) — registry toàn cục (`firestoreCacheRegistry`,
ngoài React) giữ ĐÚNG 1 listener Firestore sống cho mỗi `cacheKey`, chia sẻ dữ liệu cho mọi hook
đang subscribe qua 1 tập callback nội bộ; giữ listener sống thêm 3 phút (`FIRESTORE_CACHE_GRACE_MS`)
sau khi subscriber cuối unmount (chuyển tab/mở-đóng form nhanh không phá rồi dựng lại từ đầu), chỉ
huỷ hẳn khi hết grace period mà không ai subscribe lại. Cleanup được gom vào 1 hàm dùng chung
(`lichHuyNeuKhongAiDung`) gọi từ CẢ 2 hook (dữ liệu lẫn "loaded") — cố tình không đặt logic này chỉ
trong 1 hook vì thứ tự chạy cleanup giữa nhiều hook cùng component lúc unmount không đảm bảo cố
định, đã viết test riêng xác nhận cả 2 thứ tự khai báo hook đều dọn dẹp đúng, không rò rỉ.

**Áp dụng**: `useDanhSachCanBo()`/`useDanhMucToiDanh()` (fallback về `DANH_MUC_TOI_DANH_MAM` khi
Firestore rỗng — giữ nguyên hành vi cũ, chỉ đổi cách lấy dữ liệu) đổi sang dùng cache, KHÔNG cần sửa
5+ call site vì đã là hook dùng chung. `CanBoModule` (dòng cũ tự mở listener riêng thay vì gọi hook)
đổi sang gọi thẳng hook. `kybaocao` **KHÔNG gộp về 1 query duy nhất kèm sort lại phía client** như
dự định ban đầu — phát hiện lúc code: `timKyTruoc` (dùng ở `KyBaoCaoModule`) có comment rõ ràng
"Không dùng so sánh timestamp để tránh bug khi data có format không đồng nhất", dựa hẳn vào thứ tự
Firestore trả về từ `orderBy` server-side. Sort lại phía client sẽ tái lập đúng lớp bug đó đã né
trước đây — thay vào đó dùng ĐÚNG 2 cacheKey khớp 2 query thật sự khác nhau: `"kybaocao:desc"`
(orderBy desc — dùng bởi `DanhSachPanel`/`KyBaoCaoModule`/`AnDaGiaiQuyetModule`/`NhatKyModule`/
**`ModalXacNhanKy`**, gộp 6 nơi thành 1 listener) và `"kybaocao:asc"` (orderBy asc — riêng
`DashboardModule` cần đúng chiều thời gian cho biểu đồ). `ModalXacNhanKy` đổi từ `.get()` một lần
sang cache sống, nhưng vẫn giữ đúng hành vi "chỉ tự đặt `kyChon` mặc định 1 LẦN mỗi lần mở modal"
qua 1 `useRef` cờ đánh dấu — tránh cache cập nhật sống trong lúc modal đang mở làm mất lựa chọn tay
của người dùng.

**Giai đoạn 2 — thêm `ngayCapNhat`/`nguoiCapNhatCuoi` vào toàn bộ 13 nơi ghi `bican`** (rà soát xác
nhận `bican` trước đây HOÀN TOÀN không có field mốc thời gian nào, khác `vuan` đã dùng nhất quán) —
điều kiện tiên quyết bắt buộc cho cache lạnh dựa trên delta ở Đợt 2 sau này (xem "Ngoài phạm vi Đợt
1" bên dưới): `tachVuAn` (3 chỗ), `BackfillDieuLuatBCTool`, `BackfillLoaiKhoiToTool`,
`ImportExcelModule`, `NhapVuModal` (2 chỗ), `ThemVuAnForm`, `SuaBiCanForm` (2 chỗ — quan trọng nhất
vì đây là chỗ sửa bị can điển hình nhất), `ThemBiCanForm` (2 chỗ). Không sửa `XoaVuAnModal` (chỉ
`batch.delete`, không phải create/update).

**Đã kiểm chứng**: (1) biên dịch cú pháp cả `qlva.html`/`qlva-dev.html` qua `esbuild` (JSX) — sạch,
không lỗi; (2) test độc lập bằng `react-test-renderer` + Firestore giả lập cho đúng cơ chế cache
dùng chung — 5 kịch bản/11 assertion pass (dedupe đúng 1 listener dù nhiều component subscribe,
remount trong grace period không tạo listener mới, unmount hẳn quá grace period thì huỷ đúng —
không rò rỉ, thứ tự khai báo 2 hook dữ liệu/loaded đảo ngược nhau vẫn dọn dẹp đúng, dữ liệu đúng
nội dung); (3) **test bằng Playwright THẬT trên `qlva-dev.html`** (không có tài khoản Firebase test
thật/MCP trình duyệt trong phiên này, nên tự dựng: chặn 3 script CDN Firebase compat qua
`page.route()`, thay bằng 1 file mock Firestore/Auth trong bộ nhớ — bypass đăng nhập, có
`.collection().where().orderBy().limit().onSnapshot()/.get()`, `batch()`, đếm số lần `onSnapshot()`
THẬT được gọi theo từng chữ ký query — chạy app THẬT qua Babel-in-browser thật, không phải mock cô
lập) — 6/6 assertion pass: không lỗi console (ngoại trừ 1 cảnh báo Babel vô hại về kích thước file,
không liên quan); **chuyển qua lại đúng 18 lần (3 vòng × 6 tab) chỉ tạo ĐÚNG 2 listener thật cho
`kybaocao` và 1 cho `canbo`** (không tăng theo số lần chuyển tab — xác nhận cơ chế gộp hoạt động
đúng trong runtime thật); mở lại form "Thêm vụ án" 3 lần không tạo thêm listener `canbo`; thực hiện
trọn luồng "Thêm bị can" thật qua UI — xác nhận CẢ 2 lần ghi `bican` do luồng này gây ra (tạo mới +
cập nhật lại `loaiKhoiTo` cho vụ) đều có đúng field `ngayCapNhat`/`nguoiCapNhatCuoi`.
**Còn lại chưa kiểm chứng**: dữ liệu Firestore THẬT (project `qlahs-test`) — test trên chỉ dùng mock
trong bộ nhớ, chưa xác nhận với rules/index/latency thật của Firestore. Nên mở thử `qlva-dev.html`
thật ít nhất 1 lần (đăng nhập thật, thao tác vài nghiệp vụ) trước khi tin tưởng tuyệt đối lên
`qlva.html` production.

**Ngoài phạm vi Đợt 1 (để dành phiên sau, xem plan gốc đã thống nhất với người dùng)**: Thùng rác
(soft-delete cho `XoaVuAnModal` — đổi `batch.delete` thành đặt cờ `daXoa`/`ngayXoa`, tab "Thùng rác"
mới trong `CaiDatModule`, lọc `daXoa` ở mọi nơi liệt kê `vuan` — bao gồm `xuatExcel`/
`ImportExcelModule` đối chiếu trùng/`NhapVuModal` tìm vụ đích) và cache lạnh IndexedDB (dựa trên
`ngayCapNhat` vừa thêm ở Giai đoạn 2) cho vụ đã giải quyết + `baoCaoLuu` của kỳ đã chốt — mục tiêu
cuối cùng đã thống nhất: vụ đã giải quyết gần như bất biến (trừ Tạm đình chỉ → Phục hồi, hoặc nhập
mức án lúc nộp lưu trữ — cả 2 đều là 1 lần GHI vào `vuan` nên tự động lọt vào delta-check theo
`ngayCapNhat`, không cần code riêng từng ngoại lệ) nên chỉ cần tải 1 lần, chỉ đồng bộ lại đúng phần
đổi qua query rẻ `where(ngayCapNhat > lầnSyncTrước)` thay vì tải lại toàn bộ mỗi lần.

## Kế hoạch tiếp theo (ghi lúc checkout nhánh `toi-uu-firestore-read`, 2026-07-17)

Đang đứng ở nhánh **`toi-uu-firestore-read`** (branch mới nhất trên remote, commit cuối `e09e53c`
lúc 15:50 17/07) — **CHƯA gộp với nhánh `bang-excel-cai-dat`** (đứng trước đó, có tính năng Cài
đặt → "Bảng dữ liệu" kiểu Excel mà nhánh này KHÔNG có, vì 2 nhánh tách nhau từ trước rồi phát
triển song song). Cần merge lại với nhau (hoặc cả 2 vào `main`) trước khi coi 1 trong 2 là đầy đủ.

**5 commit của nhánh này (toàn bộ đều CHƯA kiểm chứng bằng dữ liệu Firestore thật trên
`qlva-dev.html`, chỉ mới compile-check)**, đều thuộc module Giao nhận hồ sơ: "Không tiếp nhận" kèm
lý do, danh sách "Phiên gần đây" (mở lại phiên dở/đã lưu), fix in A4 bị cắt khi dài hơn 1 trang,
đặt tên phiên tự động theo ĐTV/KSV sau khi quét hồ sơ đầu, nút "Xoá hình thức giải quyết" (sửa lỗi
chọn nhầm hình thức Hoàn thành vụ án), ràng buộc "Đã xét xử" chỉ chọn được ở giai đoạn Xét xử. Chi
tiết đầy đủ nằm trong đúng các mục tương ứng bên dưới (tìm theo ngày `2026-07-17`).

**Việc cần làm tiếp theo (theo yêu cầu người dùng), gộp chung 2 việc**:
1. Kiểm chứng 5 commit trên bằng dữ liệu Firestore thật (`qlva-dev.html`), rồi merge nhánh này
   với `bang-excel-cai-dat` (hoặc vào `main`) để không mất tính năng "Bảng dữ liệu" đang có riêng
   ở nhánh kia.
2. **Phát triển lại phần Báo cáo** (module Kỳ báo cáo — hiện vẫn còn nhãn "🚧 Đang xây dựng" cạnh
   tiêu đề, xem mục "Trạng thái Biểu B10" ngay dưới đây và mục "Kỳ báo cáo" ở "Tiến độ đã code") —
   người dùng muốn làm lại phần này, chưa nói rõ phạm vi cụ thể (sửa tiếp bug còn tồn đọng ở B10 hay
   thiết kế lại toàn bộ UI/luồng) — **hỏi lại người dùng để làm rõ phạm vi trước khi bắt tay code**,
   đừng tự suy đoán quy mô thay đổi.

## Audit "tối ưu hệ thống" (nhánh `toi-uu-he-thong`, 2026-07-16)

Rà soát toàn bộ logic hệ thống theo yêu cầu người dùng — tìm vùng dễ xung đột (race condition khi
nhiều người dùng cùng lúc), rà lại CLAUDE.md/schema doc xem có chỗ nào lỗi thời không còn khớp
code thật. Dùng agent Explore quét toàn bộ file + tự kiểm chứng lại các claim quan trọng trước khi
sửa (không tin ngay báo cáo agent, đối chiếu code thật).

**Đã sửa — lost-update race condition thật (không phải lý thuyết) ở 3 nơi cùng 1 pattern:**
`SuaBiCanForm`, `ThemBiCanForm`, `NhapVuModal` đều đọc TOÀN BỘ bị can của 1 vụ, tính lại
`dieuLuat`/`loaiKhoiTo` ở phía client, rồi ghi lại bằng `batch.commit()` thường — không có gì đảm
bảo dữ liệu đọc được còn mới khi ghi, nếu 2 người cùng sửa bị can của CÙNG 1 vụ gần như đồng thời
thì người ghi sau (dựa trên dữ liệu đã cũ) sẽ ÂM THẦM ĐÈ MẤT kết quả của người ghi trước — không
báo lỗi, không ai biết. Gộp cả 3 nơi thành 1 hàm dùng chung `capNhatDieuLuatVaLoaiKhoiTo(maVuAn)`
(định nghĩa cạnh `tinhLoaiKhoiTo`), bọc trong `db.runTransaction` đúng cách: query lấy DANH SÁCH ID
bị can NGOÀI transaction (SDK compat đang dùng không hỗ trợ query trực tiếp trong transaction), rồi
đọc lại TỪNG bị can bằng `tx.get()` theo đúng ID đó BÊN TRONG transaction — Firestore tự phát hiện
nếu có doc nào bị đổi trước khi commit và tự động thử lại toàn bộ callback. Giới hạn còn lại (chấp
nhận được): bị can MỚI thêm vào đúng lúc giữa 2 bước không được tính vào lần gọi này — không sao vì
chính thao tác thêm đó cũng gọi lại hàm này ngay sau.
**Tiện thể sửa luôn 1 bug liên quan phát hiện trong lúc audit**: `NhapVuModal` trước đây CHỈ tính
lại `dieuLuat` cho vụ đích, bỏ sót `loaiKhoiTo` — bị can nhập vào có ngày khởi tố sớm hơn mọi bị
can sẵn có của vụ đích thì đúng ra phải đổi lại ai là "ban đầu"/"bổ sung", trước đây không tính.
Dùng chung `capNhatDieuLuatVaLoaiKhoiTo` nên tự động được sửa luôn.
**Đã kiểm chứng bằng 2 lớp test thật** (không chỉ đọc code): (1) mock Firestore có `runTransaction`
thật với version-check + tự động retry khi phát hiện xung đột (đúng ngữ nghĩa Firestore optimistic
concurrency) — mô phỏng đúng kịch bản race (client B ghi đè bị can B ngay giữa lúc client A đang
trong transaction), xác nhận transaction TỰ ĐỘNG THỬ LẠI (2 lần) và kết quả cuối cùng KHÔNG mất
thay đổi của B; (2) test tích hợp qua Playwright chạy thẳng `ThemBiCanForm` thật (component thật
trong `qlva.html`, không phải bản copy logic) với mock Firestore tương tự — xác nhận thêm 1 bị can
có ngày khởi tố sớm hơn khiến `loaiKhoiTo` được tính lại đúng cho CẢ HAI bị can (bị can cũ đổi từ
"ban_dau" sang "bo_sung", bị can mới thành "ban_dau") và `dieuLuat` gộp đúng tội danh cả 2.

**Đã thêm 1 composite index phòng ngừa** vào `firestore.indexes.json`:
`lichsuChuyenGiaiDoan: kyThongKe+loaiSuKien+tuGiaiDoan` (song song với index đã có
`kyThongKe+loaiSuKien+denGiaiDoan`) — Firestore có thể không thực sự cần index này cho truy vấn
chỉ toàn điều kiện bằng nhau (`==`), nhưng thêm vào không có mặt trái, còn nếu thiếu mà thật sự cần
thì sẽ gây lỗi runtime khi tra cứu ở module Kỳ báo cáo (`tinhBaoCaoKyTuLog`).

**Đã sửa 2 tài liệu lỗi thời:**
- CLAUDE.md dòng "nay 7 module" (mục Tiến độ đã code) — thực tế mảng `MODULES` chỉ có 5 phần tử,
  cộng thêm tab "Cài đặt" gắn cứng ngoài mảng (không tính trong `MODULES`) mới ra 6 tab hiển thị.
- `schema_csdl_he_thong_quan_ly_an_v2.md` — thêm ghi chú đầu file nói rõ đây là khung sườn cốt lõi,
  không liệt kê đầy đủ mọi field thêm sau này (tra CLAUDE.md để biết field/enum mới nhất); bổ sung
  field `nhomBiCanId` (mục 2) và 2 `loaiSuKien` còn thiếu là `giao_nhan_ho_so`/`duoc_nhap_vu` (mục
  3); sửa lại hẳn mục "Index cần tạo trước" (bản cũ liệt kê 2 index KHÔNG hề tồn tại trong
  `firestore.indexes.json` thật — `bican: maVuAn+ngayKhoiTo` và `vuan: maNganhCap` — cả 2 đều
  không có query nào trong code cần đến; đồng thời thiếu 3 index mới đã thêm cho tối ưu hiệu năng
  Danh sách vụ án/Án đã giải quyết/Giao nhận hồ sơ).

**Đã đối chiếu, xác nhận KHÔNG có vấn đề (không cần sửa)**: `qlva.html`/`qlva-dev.html` vẫn đồng bộ
hoàn toàn (chỉ khác đúng phần cấu hình Firebase + nhãn `[TEST]` cố ý); mọi composite query khác
trong code đều có index khớp trong `firestore.indexes.json`; không tìm thấy dead code khi lấy mẫu
ngẫu nhiên nhiều hàm giữa file; các nhánh git khác (`main`, `test-fix`, `bieu-10-audit`,
`bieu-10-tk`, `feature/hoan-tac-nhat-ky`, `feature/ky-baocao-excel`, `offline-indexeddb`,
`import-excel-fix`) đều đã nằm trọn trong lịch sử nhánh này qua các lần merge trước đó — không còn
rủi ro xung đột git giữa các nhánh tính năng. Riêng nhánh `mockdata` lệch xa (thiếu tới ~1600 dòng
so với hiện tại) — là nhánh thử nghiệm cũ bị bỏ dở, KHÔNG phải nhánh cần merge, cố tình bỏ qua.

**CHƯA kiểm chứng bằng dữ liệu Firestore thật** — mọi thứ ở trên mới kiểm chứng bằng mock trong bộ
nhớ (dù đã mô phỏng đúng ngữ nghĩa transaction/optimistic-concurrency của Firestore), chưa chạy thử
trên `qlva-dev.html` với project `qlahs-test` thật. Nên thử tạo 2 tab trình duyệt cùng sửa bị can
của 1 vụ gần như đồng thời trên `qlva-dev.html` trước khi hoàn toàn yên tâm.

## Trạng thái Biểu B10 (audit 2026-07-13 → đã sửa xong, để tham khảo lịch sử)

Nhánh `bieu-10-audit` từng audit ra 3 bug ở Biểu B10 (loaiKhoiTo import hardcode sai, thiếu xử lý
`an_huy`, sheet "TK tội danh" nhóm tội danh không đồng bộ với B10). Cả 3 đã được sửa và commit:
`1e87144` (loaiKhoiTo import + an_huy thiếu trong C3/C33/C60), `57ef5bb` (C4/C34/C61 thiếu an_huy
+ chuẩn hoá nhóm tội danh sheet TK tội danh qua `getDL()`/`normDL()`), `b8f3fdd` (B10 đếm vụ theo
tội danh CHÍNH — 1 vụ = 1 dòng), `d73c384` (tội danh chính của vụ dùng BC `loaiKhoiTo ===
"ban_dau"` thay vì `BC[0]`, đồng bộ giữa B10 và TK tội danh). Sau đó còn tái cấu trúc thêm: mỗi
loại sự kiện × giai đoạn thành 1 sheet riêng trong Xuất Excel báo cáo tháng (`531e4f0`), thêm cột
Đếm vụ (`465e0e6`), thêm 4 sheet RA chuyển giai đoạn + sheet Cân đối số liệu (`4a8e9eb`), thêm cột
Kỳ TK vào các sheet DS vào/ra (`6370775`) — xem "Xuất Excel báo cáo tháng" bên dưới cho mô tả hiện
tại của các sheet này.

Công cụ `TaiTaoTonTheoTDTool` ("Sửa lại tồn cuối kỳ theo tội danh (Biểu B10)" trong Cài đặt →
Import Excel, xem mục "Kỳ báo cáo") — **chưa xác nhận đã kiểm chứng bằng dữ liệu Firestore thật
trên `qlva-dev.html`** (không có commit nào ghi lại việc này vì bấm nút không tạo ra thay đổi
code). Nếu số liệu tồn cuối kỳ theo tội danh trên B10 còn nghi ngờ sai, kiểm chứng công cụ này
trước khi tin tưởng số liệu xuất ra từ nút đó trên `qlva.html` (production).

**Nhánh `fix-bao-cao` (2026-07-15, tiếp tục sau khi merge `bieu-10-audit` vào `main`)** — audit
tiếp bằng cách xem trực tiếp file Excel xuất ra: số vụ mới (C6 "ĐT khởi tố vụ") khớp đúng số dòng
sheet "DS khởi tố ĐT", nhưng khối nhân khẩu học C7-C24 (tuổi/trình độ/dân tộc...) ra 0/rỗng dù
vụ có bị can. Nguyên nhân: `seed-tool.html` (dùng để seed dữ liệu `qlva-dev.html`) có CÙNG bug
`loaiKhoiTo` hardcode sai đã audit ở `bieu-10-audit` (đã sửa `qlva.html`/`ImportExcelModule` từ
`1e87144`, nhưng chưa bao giờ sửa file seed riêng này) — bị can seed ra không bao giờ có
`loaiKhoiTo === "ban_dau"` nên bị lọc mất hết khỏi C7-C24. Đã sửa `seed-tool.html`, VÀ vì bug gốc
(`ImportExcelModule` trước `1e87144`) chỉ được chặn cho import MỚI chứ không backfill dữ liệu ĐÃ
import trước đó (kể cả production), nên đã thêm `BackfillLoaiKhoiToTool` (Cài đặt → Import Excel)
tính lại đúng `loaiKhoiTo` cho toàn bộ bị can hiện có, gom theo vụ, dùng đúng hàm
`tinhLoaiKhoiToTheoNgay` app đã dùng khi thêm/sửa bị can.

**Thiết kế lại khối C7-C24: bỏ hẳn tiêu chí `loaiKhoiTo` (2026-07-15)** — trong lúc thảo luận về
bug trên, người dùng đặt câu hỏi đúng trọng tâm: tại sao khối C7-C24 cần phân biệt "ban đầu"/
"bổ sung" theo `loaiKhoiTo`, trong khi hệ thống đã hỏi "tính vào kỳ thống kê nào" ngay lúc thêm
bị can (`ThemBiCanForm`/`ThemVuAnForm`/Import Excel) rồi? Đã xác nhận: (1) số vụ mới (C3/C6...)
hoàn toàn độc lập với sự kiện `khoi_to_bican` — chỉ phụ thuộc `khoi_to_vu`/`tach_vu`/
`chuyen_giai_doan`/`tra_ho_so`, nên thêm bị can bổ sung vào 1 vụ cũ KHÔNG làm đổi kỳ "vụ mới" của
vụ đó; (2) `loaiKhoiTo` chỉ được dùng để lọc BC ở ĐÚNG 1 khối duy nhất (C7-C24 "ĐT khởi tố mới")
— khối TT/XX tương ứng (C43-C52, C64...) đã đếm mọi BC của vụ, không lọc `loaiKhoiTo` từ trước.
Kết luận: thay `bc.loaiKhoiTo === "ban_dau"` bằng tiêu chí đúng bản chất hơn — **BC nào có sự
kiện `khoi_to_bican` với `kyThongKe` khớp đúng kỳ đang tính báo cáo thì mới đếm vào C7-C24 của kỳ
đó**, bất kể `loaiKhoiTo`. Nhờ vậy BC bổ sung thêm vào 1 vụ cũ ở kỳ SAU không còn bị đếm nhầm vào
kỳ vụ khởi tố (đằng nào cũng không nên tính, vì đó là BC "mới" của kỳ sau chứ không phải kỳ vụ
được mở). Chỉ áp dụng cho khối C7-C24 — usage KHÁC của `loaiKhoiTo` (`vuPrimaryDL`: chọn BC nào
đại diện tội danh chính của 1 vụ nhiều bị can/nhiều tội, dùng để nhóm B10/TK tội danh theo điều
luật) giữ nguyên, không liên quan gì tới câu hỏi này.
Triển khai: `tinhBieu10` nhận thêm `bcKyKhoiToMap` (Map BC id → kỳ id, từ hàm mới
`fetchKyKhoiToBiCan` — quét log `khoi_to_bican`, KHÔNG dùng field cache trên `bican` vì log là
nguồn sự thật duy nhất và có thể bị "Sửa kỳ" cập nhật sau) + `kyIdSetTrongBaoCao` (mặc định
`{ky.id}`, nhưng báo cáo TỔNG HỢP NHIỀU KỲ — `TongHopNhieuKyModal` — truyền cả set kỳ đã gộp, nếu
không sẽ luôn ra 0 vì `ky` của báo cáo gộp là object giả `{tenKy}` không có `id` thật). Biến
`dt_ktBcBanDau` đổi tên thành `dt_ktBcMoiKy` cho đúng ý nghĩa mới.
Phía Excel: thêm cột **"Kỳ TK BC"** (cột AF, cuối `BC_H`, 21 cột thay vì 20 — KHÁC cột "Kỳ TK"
cấp vụ đã có ở `extraHeaders`, vì cột đó lấy kỳ của chính VỤ, giống nhau cho mọi dòng BC của cùng
1 vụ, không phản ánh đúng BC bổ sung thêm ở kỳ khác) ghi qua `tenKyBcRieng(bc)`. Công thức COUNTIFS
của C7-C24 đổi từ tiêu chí cột W (`"ban_dau"`) sang cột AF khớp tên kỳ hiện tại — helper mới
`mkCfBcKy(sheets, r, dsKyTen, ...extra)` tự OR-sum COUNTIFS qua từng kỳ trong `dsKyTen` (đáp ứng cả
báo cáo gộp nhiều kỳ, không chỉ 1 kỳ). Đã viết test độc lập kiểm chứng cả sinh công thức lẫn logic
lọc theo tập kỳ (đơn kỳ / gộp nhiều kỳ / BC không có kỳ do dữ liệu cũ dựng lại lịch sử) trước khi
mirror sang `qlva-dev.html` — CHƯA kiểm chứng bằng dữ liệu Firestore thật, cần seed lại hoặc chạy
`BackfillLoaiKhoiToTool` trên `qlva-dev.html` rồi xem thử trước khi tin tưởng số liệu trên
`qlva.html` (production).

# QLVA — Quản lý vụ án Phòng 2, VKSND Hà Nội

## Bối cảnh

Ứng dụng quản lý vụ án hình sự thay thế file Excel thủ công (`Số_liệu_án_năm_2026...xlsx`).
Yêu cầu bắt buộc: **1 file HTML duy nhất**, mở thẳng bằng trình duyệt, không cần cài đặt,
nhiều người dùng cùng lúc (đồng bộ qua Firebase Firestore).

File chính: `qlva.html` (React 18 UMD + Babel standalone qua CDN, Tailwind CDN, Firebase compat SDK,
SheetJS để đọc/ghi Excel — tất cả nhúng trong 1 file, không có bước build).

Firebase project: `qlahsp2` (config đã có sẵn trong `qlva.html`). Firestore + Authentication
(Email/Password) đã được bật.

## Schema Firestore — xem chi tiết đầy đủ trong `schema_csdl_he_thong_quan_ly_an_v2.md`

Tóm tắt nhanh 7 collection: `vuan`, `bican`, `lichsuChuyenGiaiDoan` (log sự kiện, append-only —
nguồn sự thật duy nhất để đếm số liệu theo kỳ), `kybaocao`, `canbo`, `boDemMaVu` (bộ đếm sinh mã),
`phienGiaoNhan` (phiên giao/nhận hồ sơ — xem module Giao nhận hồ sơ bên dưới).

## Nguyên tắc thiết kế cốt lõi (đã thống nhất qua nhiều vòng, KHÔNG tự ý đổi)

1. **Log là nguồn sự thật duy nhất** để tính số liệu theo kỳ — không bao giờ suy ra số liệu
   từ trạng thái hiện tại (`coQuanThuLy`/`trangThai`) của `vuan`.
2. **Kỳ báo cáo do cán bộ thống kê tự quyết định** ngày chốt (không cố định 15 hay 16, có tháng
   chốt 26, có tháng chốt 30) — lưu trong collection `kybaocao`, không hardcode ngày.
3. **Mỗi thao tác nghiệp vụ đều hỏi "tính vào kỳ nào"** qua 1 modal dùng chung (mặc định = kỳ
   đang mở, sửa được sau, có audit trail `lichSuSuaKy`).
4. **Giai đoạn** chỉ 3 giá trị tuần tự Điều tra → Truy tố → Xét xử, chuyển lùi (trả hồ sơ) chỉ
   được đúng 1 bước mỗi lần, mỗi lần trả là 1 sự kiện log riêng.
5. **Tạm đình chỉ / Đình chỉ không tồn tại độc lập theo bị can.** Nếu chỉ áp dụng cho 1 phần bị
   can của vụ nhiều bị can → hệ thống **tự động tách vụ trước**, rồi áp trạng thái lên vụ mới
   tách. Chọn toàn bộ bị can thì áp thẳng lên vụ hiện tại, không tách.
   **Tách vụ án nói chung** (thủ công hoặc tự động ở trên) áp dụng được cho MỌI vụ đang giải
   quyết, kể cả 0 hoặc 1 bị can — vì 1 vụ có thể có nhiều hành vi cần tách xử lý độc lập dù chỉ
   1 bị can (hoặc hành vi chưa xác định được đối tượng). Khi tách, mỗi bị can chọn 1 trong 3:
   ở lại vụ gốc / chuyển hẳn sang vụ mới / **ở cả 2 vụ** (sao chép, hiếm dùng — cho trường hợp 1
   người có nhiều hành vi, chỉ tách 1 hành vi ra xử lý riêng). Bản sao liên kết với bản gốc qua
   `nhomBiCanId` để **Nhập vụ** sau này nhận ra là cùng 1 người và gộp lại thay vì tạo trùng.
6. **Mã vụ án tự sinh** — 2 loại:
   - Vụ mới: `QLVA_E01.53_{YYMM theo ngày QĐ KTVA}_{SEQ 4 số, reset mỗi tháng}`.
   - Vụ tách ra: kế thừa mã vụ gốc + hậu tố `_{n}` (n = số lần tách từ chính vụ gốc đó, đếm
     riêng qua field `soDemTach`, không dùng bộ đếm tháng). Tách nhiều tầng ra dạng `..._1_1`.
   - `maNganhCap` (mã do ngành cấp) ưu tiên hiển thị nếu có, `maNoiSinh` chỉ hiển thị khi chưa có.
   - Cả 2 loại sinh mã đều dùng Firestore transaction để tránh trùng khi nhiều người tạo cùng lúc.
7. **Tội danh (`toiDanh`) là mảng ở cấp bị can**, phần tử đầu = tội chính (dùng tính thống kê).
   Điều luật cấp vụ án (`dieuLuat`) tự gộp từ toàn bộ bị can nếu đã có bị can, chỉ cho nhập tay
   khi vụ chưa có bị can nào.
8. Mặc định: `gioiTinh = nam`, `danToc = "Kinh"`, `dangVien = "khong"`.
9. **Nhập vụ (`nhap_vu`)** dùng chung cho cả 2 trường hợp: nhập 2 vụ độc lập, và nhập ngược lại
   vụ gốc sau khi 1 vụ đã tách ra rồi được phục hồi.
10. Khi **chốt kỳ báo cáo**, hệ thống tự chụp (snapshot) số dư "Còn" của từng cơ quan
    (Điều tra/Truy tố/Xét xử) vào chính `kybaocao.tonCuoiKy`, để làm "Án cũ" cho kỳ sau — vì đây
    là dữ liệu không tính được từ log của riêng 1 kỳ.

## Tiến độ đã code

- [x] `qlva.html`: đăng nhập Firebase Auth + khung sidebar (5 module trong mảng `MODULES`: Danh
      sách vụ án/Án đã giải quyết/Giao nhận hồ sơ/Kỳ báo cáo/Dashboard — cộng thêm tab "Cài đặt"
      gắn cứng ngoài mảng này, xem `CaiDatModule`, tổng cộng 6 tab hiển thị; đã sửa lại từ nhãn "7
      module" cũ không khớp thực tế nữa, audit 2026-07-16) +
      **Import Excel** (đọc sheet "Danh sách án", xem trước, tự nhận diện trùng, ghi Firestore
      bằng batch — xem mục riêng "Import Excel — mẫu 'Danh sách án'" bên dưới, đã thay thế hẳn
      mẫu DSAT/DSBCT cũ) + công cụ dựng lại lịch sử cho dữ liệu import cũ (xem mục riêng bên dưới,
      chỉ còn cần cho dữ liệu import bằng mẫu DSAT/DSBCT trước đây — import bằng mẫu mới tự ghi
      log ngay, không cần công cụ này nữa).
- [x] Module Danh sách & chi tiết vụ án: 2 cột — danh sách là panel CHÍNH (`flex-1`, chiếm phần
      lớn chiều rộng), chi tiết là panel PHỤ cố định `w-[420px]` bên phải (đảo ngược so với thiết
      kế ban đầu theo yêu cầu người dùng). Danh sách có: ô tìm kiếm khớp cả mã vụ/tên vụ/điều
      luật/số QĐ KTVA (`soQdKtva`, thêm 2026-07-13)/tên bị can, **toggle "Đang giải quyết" / "Tất
      cả"** (`chiDangGiaiQuyet`, mặc định
      `true` — thay thế hẳn module "Án tồn theo giai đoạn" cũ đã bị xoá, kết hợp với tab lọc
      giai đoạn/KSV sẵn có là đủ vai trò của module đó), cột **Bị can** (mặc định chỉ hiện bị
      can đầu + link "+N bị can khác" để mở rộng, state `moRongBiCan`), cột **Kỳ mới**/**Kỳ giải
      quyết** (tính qua `tinhKyTheoVuAn` — kỳ mới lấy từ sự kiện `khoi_to_vu`, kỳ giải quyết lấy
      từ `hoan_thanh` GẦN NHẤT vì vụ có thể phục hồi rồi giải quyết lại; vụ tách ra không có "kỳ
      mới" vì không có sự kiện `khoi_to_vu` riêng — đúng, không phải vụ mới thật), cột **Số QĐ
      KTVA**/**Ngày KTVA**, 2 nút thao tác **Chuyển giai đoạn**/**Hoàn thành** hiện trực tiếp
      trên mỗi dòng (không phải menu `⋯` ẩn như trước). **Sắp xếp**: bấm tiêu đề cột để sort
      tăng/giảm (component dùng chung `ThSort`, mũi tên ▲/▼ chỉ chiều) — chỉ áp dụng cho Mã
      vụ/Ngày KTVA/Hạn ĐT (giá trị so sánh rõ ràng); KHÔNG làm sort cho Kỳ mới/Kỳ giải quyết vì
      đó là chuỗi hiển thị "Tháng N/YYYY", sort theo chuỗi sẽ sai thứ tự thời gian (VD "Tháng
      10" < "Tháng 2"). Đầu trang có `ThongKeKyHienTai` — thẻ nhỏ đếm nhanh số vụ mới/đã giải
      quyết trong kỳ đang mở, để tiện theo dõi mà không cần mở riêng module Kỳ báo cáo. Panel
      (2026-07-11) **Bấm vào ô kỳ để sửa ngay tại danh sách** — cột Kỳ mới/Kỳ giải quyết giờ
      bấm được (component `OKy` dùng chung), cộng thêm 2 cột mới **Kỳ vào Truy tố**/**Kỳ chuyển
      Xét xử** (kỳ của sự kiện GẦN NHẤT đưa vụ vào giai đoạn đó — vì đây cũng là mốc tính vào số
      liệu báo cáo kỳ, VD tháng 8 có 3 vụ kết thúc điều tra chuyển Truy tố, tháng 9 có 2 vụ
      chuyển Xét xử; giữ "gần nhất" vì 1 vụ có thể bị trả hồ sơ rồi chuyển giai đoạn lại nhiều
      lần). Bấm vào 1 ô kỳ (nếu vụ đã có sự kiện tương ứng, không phải "—") mở thẳng `SuaKyModal`
      (dùng chung với Nhật ký thao tác, xem mục Module Nhật ký thao tác) để sửa kỳ ngay, không
      cần qua Nhật ký thao tác tìm đúng dòng — tiện hơn cho cán bộ thống kê. Dùng hàm
      `timSuKienKyTheoVuAn` (khác `tinhKyTheoVuAn` cũ vẫn giữ nguyên cho Xuất Excel — hàm cũ trả
      về CHUỖI TÊN kỳ, hàm mới trả về CHÍNH sự kiện log kèm `id` vì `SuaKyModal` cần `id` để biết
      sửa đúng dòng nào). KHÔNG sort được các cột Kỳ này (như đã quyết định trước đây với Kỳ
      mới/Kỳ giải quyết — hiển thị dạng chuỗi "Tháng N/YYYY" nên sort chuỗi sẽ sai thứ tự thời
      gian); ai cần sort theo kỳ thì dùng module Nhật ký thao tác (đã hỗ trợ sort đúng theo thời
      gian thực của kỳ). **Ghi chú "↩ Trả bổ sung"** (2026-07-11) — giai đoạn Điều tra/Truy tố
      còn vào được qua đường **trả hồ sơ** (`tra_ho_so`, không chỉ qua khởi tố mới/chuyển giai
      đoạn tới), và đây vẫn tính vào số liệu báo cáo kỳ y hệt (sheet "DS viện trả DTBS"/"DS toà
      trả DTBS" của Xuất Excel báo cáo tháng), nên: (1) "Kỳ vào Truy tố" GỘP cả sự kiện
      `chuyen_giai_doan` (viện nhận từ điều tra) LẪN `tra_ho_so` có `denGiaiDoan: "truy_to"`
      (toà trả hồ sơ về truy tố) — giữ sự kiện gần nhất trong cả 2 loại; nếu sự kiện thắng là
      `tra_ho_so` thì hiện thêm dòng nhỏ màu vàng "↩ Trả bổ sung" ngay dưới tên kỳ để phân biệt
      với chuyển giai đoạn thông thường; (2) riêng **Điều tra** không có cột "kỳ vào" kiểu này
      (giai đoạn đầu, không có "chuyển giai đoạn tới") nên thêm 1 dòng phụ riêng dưới ô **Kỳ
      mới** — chỉ hiện khi vụ có sự kiện `tra_ho_so` với `denGiaiDoan: "dieu_tra"` (viện trả hồ
      sơ điều tra bổ sung), bấm vào dòng đó cũng mở `SuaKyModal` sửa được. Không đụng tới "Kỳ mới"
      gốc (`khoi_to_vu`) — 2 khái niệm tách biệt, không gộp chung 1 ô.
      **Ẩn/hiện cột (2026-07-11)** — danh sách đã lên 13 cột, nút **"Cột hiển thị"** (component
      `ChonCotHienThi`, popover checkbox, đóng khi click ra ngoài qua 1 backdrop `fixed inset-0`)
      cho ẩn bớt các cột KHÔNG PHẢI định danh chính (Mã vụ/Tên vụ/thao tác luôn hiện, không cho
      ẩn — xem mảng `DS_COT_TUY_CHON`). Lựa chọn lưu vào `localStorage` (khoá `qlva_danhsach_cotAn`)
      nên nhớ giữa các lần mở lại trang, không cần đăng nhập lại mỗi lần chọn.
      Panel chi tiết dùng bảng key-value **1 cột/hàng** (không phải 2 cột/hàng như thiết kế cũ) để
      không bị tràn chữ với bề rộng 420px, có gridline/zebra-row/badge màu theo giai đoạn-trạng
      thái — xem `MAU_GIAI_DOAN`/`MAU_TRANG_THAI`/`Badge`. Form **Thêm vụ án** (vụ + nhiều bị can
      trong 1 form, tội danh nhiều dòng Tội chính/Bổ sung), sinh `maNoiSinh` tự động qua
      transaction, tự tính `dieuLuat`/`loaiKhoiTo`. Nút **Sửa thông tin vụ án** và **Sửa** trên
      từng dòng bị can (sửa lỗi nhập liệu thường — không ghi log, không hỏi kỳ, khác với các
      hành động nghiệp vụ). KSV/ĐTV vẫn là ô nhập tay nhưng có gợi ý (`<datalist>`) từ danh sách
      `canbo` — xem module Cán bộ bên dưới.
      **Tối ưu cho dữ liệu lớn (10k+ dòng, 2026-07-16, nhánh `giao-nhan-ho-so`)** — `DanhSachPanel`
      trước đây mở real-time listener trên TOÀN BỘ 4 collection (`vuan`, `bican`, `kybaocao`, và
      `lichsuChuyenGiaiDoan` lọc theo loại sự kiện nhưng vẫn không giới hạn số dòng), rồi mới lọc/
      tìm kiếm ở phía trình duyệt — càng nhiều năm dữ liệu tích luỹ, càng phải tải và giữ sống
      càng nhiều dữ liệu mỗi lần mở màn hình, dù người dùng chỉ cần xem "đang giải quyết". Đã sửa
      thành 2 phần, KHÔNG đụng tới bất kỳ nơi ghi dữ liệu nào (chỉ đổi cách đọc, không rủi ro cho
      tính đúng đắn của số liệu):
      (1) **`vuan` lọc/giới hạn ngay ở Firestore** — toggle "Đang giải quyết" (mặc định) giờ dùng
      `.where("trangThai","==","dang_giai_quyet")` thay vì tải hết rồi lọc client (tập này tự
      nhiên bị chặn, không tăng vô hạn vì vụ giải quyết xong sẽ rời khỏi tập). Tab "Tất cả" thêm
      giới hạn an toàn `gioiHanTatCa` (mặc định 500, tăng dần qua nút "Tải thêm 500" — không phải
      cursor pagination thật, chỉ tăng `.limit()` rồi tải lại, đơn giản hơn nhiều và đủ dùng ở quy
      mô hiện tại). Cần index mới `vuan(trangThai ASC, ngayTao DESC)` — đã thêm vào
      `firestore.indexes.json`, PHẢI deploy (`firebase deploy --only firestore:indexes`) trước khi
      bật toggle này trên dữ liệu thật, nếu không Firestore sẽ báo lỗi thiếu index kèm link tạo.
      (2) **`bican`/`lichsuChuyenGiaiDoan` (cột Bị can + Kỳ mới/Kỳ giải quyết/Kỳ vào Truy tố/Kỳ
      chuyển Xét xử) đổi từ tải nguyên collection sang chia lô theo id (`chiaNhoDsId`, lô 30 —
      đúng giới hạn mệnh đề `in` của Firestore, cùng cỡ lô đã dùng ở `batchLayBiCanList` có sẵn từ
      trước) chỉ hỏi ĐÚNG những vụ đang hiển thị (`idsHienTaiKey`)** — không còn tải bị can/log của
      những vụ không nằm trong danh sách đang xem. Bỏ hẳn mệnh đề `where("loaiSuKien","in",[...])`
      trên query log (Firestore giới hạn tổng số nhánh khi kết hợp 2 mệnh đề `in` cùng lúc — lô 30
      id × 4 loại sự kiện = 120 nhánh, vượt quá giới hạn 30), lọc loại sự kiện ở phía client
      (`timSuKienKyTheoVuAn`) như cũ, rẻ vì đã được thu hẹp đúng theo các vụ cần hiển thị.
      **Tìm kiếm vẫn đầy đủ dù đã giới hạn/phân trang** — nếu đang ở tab "Tất cả" VÀ đã vượt
      `gioiHanTatCa` VÀ có gõ từ khoá, tự động tải bù 1 lần (`.get()`, KHÔNG realtime, không giữ
      sống liên tục) toàn bộ `vuan` vào `dsTimKiemDayDu`, dùng thay cho bản đã giới hạn cho tới
      khi xoá từ khoá — tránh bỏ sót kết quả nằm ngoài giới hạn hiển thị mặc định. "Đang giải
      quyết" không cần bước này vì tập đó vốn đã đầy đủ (không bị giới hạn). Bị can dùng cho tìm
      kiếm theo tên vẫn qua đúng cơ chế chia lô ở (2) (chia lô theo `dsTimKiemDayDu` khi đang tìm
      kiếm đầy đủ), không cần tải riêng.
      Tác dụng phụ nhỏ: sắp xếp theo cột (bấm tiêu đề Mã vụ/Ngày KTVA/Hạn ĐT) giờ CHỈ sắp xếp các
      dòng đang tải (`nguonDanhSach`) — ở tab "Tất cả" khi đã vượt `gioiHanTatCa`, các dòng ngoài
      giới hạn chưa tải sẽ không tham gia sắp xếp cho tới khi bấm "Tải thêm" hoặc gõ tìm kiếm. Ô
      lọc KSV đổi nguồn: gộp roster `canbo` (vai trò KSV, luôn đầy đủ, không phụ thuộc số dòng
      đang tải) với các tên KSV thấy được trong dữ liệu đang hiển thị (phòng dữ liệu cũ/nhập tay
      có tên KSV không có trong danh mục Cán bộ) — tránh mất tên KSV khỏi ô lọc khi bị giới hạn.
      **CHƯA kiểm chứng bằng dữ liệu Firestore thật** (chỉ mới kiểm tra cú pháp bằng cách biên
      dịch qua đúng bản `@babel/standalone@7.25.6` app đang dùng) — cần mở thử `qlva-dev.html`
      (sau khi deploy lại `firestore.indexes.json` cho project `qlahs-test`), thử cả 2 tab "Đang
      giải quyết"/"Tất cả", bấm "Tải thêm", gõ tìm kiếm ở cả 2 tab, trước khi tin tưởng và đưa lên
      `qlva.html` production.
- [x] Module Cán bộ: thêm/sửa KSV, ĐTV, cán bộ thống kê (collection `canbo`). Các ô KSV
      chính/KSV hỗ trợ/ĐTV ở form Thêm vụ án và Sửa thông tin vụ án vẫn lưu **tên dạng chuỗi**
      (không phải ref cứng tới `canbo`) — lựa chọn có chủ đích để tương thích dữ liệu đã có
      sẵn (từ Import Excel và các vụ tạo trước khi có module này), `<datalist>` chỉ gợi ý.
- [x] Module **Giao nhận hồ sơ** (`GiaoNhanHoSoModule`) — thiết kế để dùng với đầu đọc mã QR
      không dây 2.4GHz kiểu "giả lập bàn phím" (cắm đầu thu USB, không cần driver/app riêng —
      quét là gõ thẳng chuỗi mã vụ + Enter vào ô đang focus, y hệt gõ tay). Luồng: chọn loại
      giao dịch (Giao/Nhận) → tạo 1 `phienGiaoNhan` (trạng thái `dang_mo`) → ô input luôn
      auto-focus, mỗi lần nhận sự kiện `submit` (Enter) ghi NGAY 1 sự kiện `giao_nhan_ho_so` vào
      `lichsuChuyenGiaiDoan` (không hỏi kỳ báo cáo — giống "Sửa thông tin", đây là log hành
      chính lưu vết ai giữ hồ sơ, không phải sự kiện nghiệp vụ đổi giai đoạn/trạng thái, không
      ảnh hưởng số liệu báo cáo kỳ) → hiện ngay trong bảng "đã quét trong phiên", sửa/xoá được
      từng dòng tại chỗ cho tới khi bấm **"Lưu phiên"** (khoá lại, không sửa/quét thêm được nữa).
      Mỗi dòng có 3 trường người liên quan (field Firestore giữ tên cũ, chỉ đổi Ý NGHĨA + nhãn
      hiển thị so với bản đầu tiên): **KSV** (field `nguoiGiao`, mặc định `vuAn.ksvChinh`) và
      **ĐTV** (field `nguoiNhan`, mặc định `vuAn.dtvCbdt`) chỉ để THỂ HIỆN hồ sơ của ai — không
      phải người thực giao/nhận; **Người nhận thực tế** (`nguoiNhanThucTe`, để trống mặc định) —
      vì người thực tế cầm/ký nhận hồ sơ có thể khác (đi nhận thay). Cả 3 sửa tự do được (input +
      `<datalist>` gợi ý từ `canbo`, không ép buộc) — **bấm vào bất kỳ đâu trên cả dòng** (2026-
      07-13, không chỉ đúng chữ "Sửa" nhỏ) là vào chế độ sửa ngay (`DongGiaoNhan`'s `batDauSua`),
      vì thao tác giao nhận diễn ra nhanh/liên tục theo nhịp quét QR, không nên bắt rê chuột chính
      xác vào 1 link nhỏ. Cell nào có nút bấm/input khi đang sửa đều `stopPropagation` để không tự
      kích hoạt lại chế độ sửa hoặc lẫn với việc bấm Xoá. Không có ràng buộc thứ tự giao/nhận (quét là
      ghi, không kiểm tra hồ sơ đang "ở đâu" trước đó) — quyết định có chủ đích để giữ thao tác
      quét nhanh, đơn giản như sổ giao nhận giấy truyền thống. **"In phiên"** xuất "Biên bản giao
      nhận hồ sơ" khổ A4 qua cùng cơ chế portal `#qr-print-root` đã dùng cho In mã QR (xem
      `BienBanGiaoNhanIn`) — mỗi vụ 1 dòng riêng: mã vụ (cột hẹp) + tên vụ 2 dòng (tên vụ/số-ngày
      QĐ KTVA) + KSV + ĐTV + cột "Người nhận thực tế / Ký tên" ngay tại dòng đó (không dùng 1
      khối ký tên chung cuối trang — vì 1 phiên có thể giao cho nhiều người khác nhau theo từng
      vụ, phải ký ngay cạnh đúng vụ đó).
      **Tìm thủ công khi không có mã QR (2026-07-13)** — luồng gốc chỉ nhận vào đúng 1 mã vụ án
      chính xác (đọc thẳng `db.collection("vuan").doc(ma)`), không có cách nào thêm 1 dòng vào
      phiên nếu không cầm mã vụ trong tay. Thêm link nhỏ "Không có mã QR? Tìm thủ công..." dưới ô
      quét, mở ra 1 ô tìm kèm danh sách kết quả bấm chọn để ghi nhận — cùng chỗ dùng chung logic
      ghi sự kiện `giao_nhan_ho_so` với đường quét mã (tách hàm `ghiNhanVuVaoPhien`, cả 2 đường
      vào đều gọi hàm này để không lệch nhau field nào). Tìm theo tên vụ/KSV chính/tội danh (proxy
      qua field `dieuLuat` cấp `vuan`, giống lý do đã dùng ở Án đã giải quyết/Giao nhận không có
      bị can join)/số QĐ KTVA — lọc phía client trên 1 lần tải toàn bộ vụ **đang giải quyết** (không
      tìm cả vụ đã xong, vì hồ sơ giao nhận thực tế chỉ xoay quanh vụ đang thụ lý), tải 1 lần lúc
      mở panel (không realtime — đây là công cụ tra cứu để CHỌN, không phải danh sách cần luôn mới
      nhất).
      **Sửa thông tin vụ án ngay từ dòng giao nhận (2026-07-13)** — lý do thực tế: rất nhiều vụ
      lúc nhập ban đầu (import/tạo tay) chưa đủ thông tin, chỉ khi thực tế CẦM hồ sơ lúc giao/nhận
      mới biết rõ để bổ sung (VD đơn vị thụ lý, điều luật, KSV hỗ trợ...). Nút "✎ Sửa thông tin
      vụ án" nhỏ dưới tên vụ trong mỗi dòng (`DongGiaoNhan`) — bấm vào tải nguyên `vuan` doc hiện
      tại (log giao nhận chỉ lưu snapshot vài field, không đủ để mở form sửa) rồi mở thẳng
      `SuaVuAnForm` — DÙNG LẠI y nguyên component đã có ở panel chi tiết Danh sách vụ án, không
      viết lại logic sửa. KHÁC HẲN với việc bấm cả dòng để sửa (mục ngay trên) — bấm cả dòng chỉ
      sửa 3 field snapshot của DÒNG log (KSV/ĐTV/người nhận thực tế hiển thị lúc giao nhận), còn
      nút này sửa thẳng vào chính `vuan`, ảnh hưởng dữ liệu gốc dùng ở mọi module khác. Luôn hiện
      được kể cả khi phiên đã "Lưu phiên" (`khoaSua`) — khoá phiên chỉ chặn sửa dòng log, không
      liên quan gì tới sửa thông tin vụ án.
      **Chặn quét trùng trong cùng 1 phiên (2026-07-15, nhánh `giao-nhan-ho-so`)** — trước đây
      quét/chọn lại 1 vụ ĐÃ có sẵn trong phiên sẽ ghi thêm 1 dòng `giao_nhan_ho_so` mới (trùng),
      thường do quét nhầm/quét đi quét lại. `xuLyQuet` và `chonVuThuCong` giờ kiểm tra
      `dsQuet.some(d => d.maVuAn === ma)` (dữ liệu đã có sẵn qua `onSnapshot` theo `phien.id`,
      không cần query thêm) trước khi ghi — nếu đã có thì chỉ hiện toast cảnh báo (loại `"warn"`,
      màu hổ phách), không ghi gì thêm. Không chặn ở tầng Firestore (không phải constraint cứng)
      — chỉ chặn phía client trong session hiện tại, đúng phạm vi vấn đề thực tế nêu ra (quét
      nhầm trong lúc thao tác, không phải yêu cầu 1 vụ chỉ được giao/nhận đúng 1 lần trong lịch
      sử toàn hệ thống).
      **Tải toàn bộ lịch sử giao nhận ra Excel, cột Mã vụ = ẢNH QR (2026-07-15, cùng nhánh)** —
      nút "⬇ Tải toàn bộ lịch sử" (hiện cả ở màn chưa có phiên lẫn trong phiên đang mở, vì đây là
      lịch sử TOÀN HỆ THỐNG mọi phiên, không phải riêng phiên hiện tại) — `taiLichSuGiaoNhan`
      query thẳng `lichsuChuyenGiaiDoan` where `loaiSuKien == "giao_nhan_ho_so"` (không lọc theo
      `phienGiaoNhanId`, không giới hạn 300 dòng như Nhật ký thao tác vì đây là export file chứ
      không phải bảng hiển thị), `loaiGiaoDich` đọc thẳng từ field đã lưu sẵn trên chính sự kiện
      (không cần join `phienGiaoNhan`). Dùng **ExcelJS** (không phải XLSX/SheetJS — lý do giống
      Xuất Excel báo cáo tháng: cần nhúng ảnh, XLSX bản CDN đang dùng không hỗ trợ). Cột "Mã vụ"
      để trống CHỮ, nhúng đè ảnh QR lên đúng ô đó qua `wb.addImage`/`ws.addImage` (anchor
      `tl:{col,row}` 0-based) — mục đích: sau này chỉ cần quét thẳng từ file/bản in ra là tra
      được vụ ngay, không cần gõ tay. Ảnh QR sinh bằng hàm mới `taoQrDataUrl(text, size)` (cạnh
      `KhoiQR`) — tái dùng `qrcodejs` (`new QRCode(...)`) nhưng vẽ vào 1 `<div>` KHÔNG gắn vào DOM
      thật (canvas 2D vẫn vẽ/đọc `toDataURL()` được dù không attach), khác `KhoiQR` vốn render lên
      màn hình qua `ref`. Đã kiểm chứng riêng phần dựng workbook + nhúng ảnh bằng test Node dùng
      thẳng package `exceljs` thật (ghi buffer xong load lại, xác nhận đúng số ảnh + đúng vị trí
      cột/dòng) — phần sinh ảnh QR qua `qrcodejs` (cần canvas trình duyệt thật) chưa test được
      bằng cách này, chỉ tái dùng nguyên pattern đã chạy ổn định ở `KhoiQR`.
      **Thêm cột "Số bút lục" (2026-07-16)** — field mới `soButLuc` trên sự kiện `giao_nhan_ho_so`,
      cùng nhóm với `nguoiNhanThucTe` (để trống mặc định, ghi tay lúc giao/nhận, KHÔNG bắt buộc,
      không ảnh hưởng số liệu báo cáo kỳ) — dùng để cán bộ ghi lại hồ sơ thực tế có bao nhiêu
      trang/bút lục tại đúng thời điểm giao/nhận, tiện đối chiếu sau này nếu nghi ngờ thất lạc
      trang. Có mặt ở cả 3 chỗ hiển thị dòng giao nhận: bảng "đã quét trong phiên" (sửa được y hệt
      3 field người liên quan, qua `DongGiaoNhan`), "Biên bản giao nhận hồ sơ" bản in A4
      (`BienBanGiaoNhanIn`, cột riêng cạnh "Người nhận thực tế / Ký tên" — đúng chỗ cần nhất vì đây
      là bản có chữ ký, dùng đối chiếu về sau), và Excel "Tải toàn bộ lịch sử" (`taiLichSuGiaoNhan`,
      cột sau "Người nhận thực tế").
      **Thêm cột "Hình thức giải quyết" (2026-07-16, cùng đợt)** — trước khi giao/nhận 1 hồ sơ đã
      có kết quả, cán bộ cần biết ngay đã giải quyết theo hình thức nào (Đã xét xử/Chuyển đi/Tạm
      đình chỉ/Đình chỉ/Án huỷ) kèm số QĐ tương ứng mà không cần mở lại vụ án. KHÁC HẲN "Số bút
      lục"/"Người nhận thực tế" — đây là 2 field MỚI **snapshot tự động** lúc quét/chọn
      (`trangThaiVu` = `vuAn.trangThai`, `soQdGiaiQuyet` = giá trị field tương ứng qua
      `fieldSoQuyetDinhTrenVuAn` đã có sẵn từ module Án đã giải quyết), không phải ô nhập tay —
      hiển thị qua helper dùng chung `moTaHinhThucGiaiQuyet(dong)` ("Đang giải quyết" nếu chưa có
      kết quả, hoặc "<Nhãn> — <Số QĐ>" nếu đã có). Có ở bảng phiên (cột riêng, luôn hiện bất kể
      đang sửa dòng hay không — khác nhóm 4 field editable), Excel lịch sử (cột riêng sau "Tên
      vụ"); riêng **Biên bản in A4** đặt làm dòng phụ trong ô "Tên vụ" (không phải cột riêng) vì
      khổ A4 đã khá chật với 7 cột hiện có.
      **Biên bản in A4: cột Mã vụ đổi thành ảnh QR + tách "Trạng thái HS" thành cột riêng
      (2026-07-16, cùng đợt)** — ban đầu đặt "Hình thức giải quyết" làm dòng phụ trong ô "Tên vụ"
      vì lo khổ A4 chật (xem ngay trên), nhưng theo yêu cầu người dùng đã tách hẳn thành cột riêng
      "Trạng thái HS" (dùng lại đúng `moTaHinhThucGiaiQuyet`) — bù lại, cột "Mã vụ" đổi từ hiện
      chữ sang **ảnh QR** (`taoQrDataUrl(d.maVuAn, 120)`, cùng hàm đã dùng cho Excel "Tải toàn bộ
      lịch sử" — sinh data URL PNG đồng bộ, không cần gắn DOM thật) để tiết kiệm bề ngang, đồng
      thời tiện quét lại thẳng từ bản giấy sau này. Các cột KSV/ĐTV/Số bút lục/Người nhận thực tế
      thu hẹp bớt độ rộng cố định (`w-*`) để nhường chỗ cho cột mới — chưa in giấy thật để xác
      nhận có vừa khổ A4 hay không, nên in thử 1 bản trước khi dùng cho nhiều hồ sơ.
      **Đổi sang khổ ngang/landscape (2026-07-16, cùng đợt)** — theo yêu cầu người dùng sau khi
      bảng lên 8 cột. Đổi container từ `width:210mm;minHeight:297mm` sang `width:297mm;
      minHeight:210mm`, và thêm `<style>{"@page { size: landscape; }"}</style>` NGAY TRONG nội
      dung được portal vào `#qr-print-root` (không sửa khối `@media print` chung trong `<head>`)
      — vì `@page` là at-rule toàn cục, nếu đặt chung sẽ ép cả `InQRModal` (in mã QR, vẫn cần khổ
      dọc) sang ngang theo. Đặt `<style>` bên trong chính component này thì quy tắc chỉ tồn tại
      trong DOM khi ĐÚNG biên bản này đang mở — 2 modal in không portal cùng lúc nên không xung
      đột. Nếu sau này có thêm màn in khác cần khổ riêng, dùng lại đúng pattern này (style cục bộ
      theo từng component in), đừng gộp chung vào khối `@media print` ở `<head>`.
      **Nộp hồ sơ lưu trữ + cột "Thời hạn bảo quản" (2026-07-16, cùng đợt)** — thêm tick "Nộp hồ
      sơ lưu trữ" ở màn bắt đầu phiên (chỉ áp dụng khi bắt đầu phiên **Nhận** — nộp lưu trữ nghĩa
      là bộ phận lưu trữ NHẬN hồ sơ từ KSV/ĐTV), lưu thành field `laLuuTru` trên `phienGiaoNhan`.
      Khi `laLuuTru`, bảng phiên + Biên bản in A4 hiện thêm cột **"Thời hạn bảo quản"** (Excel
      "Tải toàn bộ lịch sử" thì LUÔN có cột này, không điều kiện theo `laLuuTru`, vì đó là dump
      toàn bộ lịch sử mọi phiên, không riêng phiên đang mở).
      **Nguồn tính**: file **`thoi han bao quan.xlsx`** (thư mục gốc dự án, sheet "Bang doi
      chieu") — chép nguyên văn thành 2 hằng số `BANG_THOI_HAN_BAO_QUAN_THEO_NAM` (mức án theo
      năm, key là số năm đã cộng sẵn phần tháng lẻ dạng thập phân — VD `7.5` cho "7 năm 6 tháng")
      và `THOI_HAN_BAO_QUAN_DAC_BIET` (tử hình/chung thân/án treo/phạt tiền).
      **Bug đã sửa (2026-07-16, cùng ngày, phát hiện qua người dùng phản hồi trực tiếp) — bảng gốc
      là HÀM BẬC THANG (mốc → áp dụng cho tới trước mốc kế tiếp), KHÔNG PHẢI danh sách giá trị khớp
      tuyệt đối.** Bản đầu tiên hiểu sai: coi mỗi key trong bảng là 1 giá trị mức án CỐ ĐỊNH duy
      nhất được công nhận (VD chỉ đúng "3 năm" hoặc đúng "3 năm 6 tháng" mới tra được, "3 năm 5
      tháng" hay "4 năm" thì trả `null` vì không khớp key nào) — SAI với ý nghĩa thật của bảng: mốc
      "3" (19 năm) áp dụng cho MỌI mức án từ "3 năm 0 tháng" đến hết "3 năm 5 tháng"; đúng từ "3 năm
      6 tháng" mới chuyển sang mốc "3.5" (23 năm), áp dụng tới hết "4 năm 5 tháng" (mốc kế tiếp là
      "4.5", không phải "4" — bảng gốc không có mốc "4" riêng vì không cần, dùng mốc "3.5" cho cả
      dải đó). Đã sửa `tinhThoiHanBaoQuanTheoMucAn` sang tra theo **mốc LỚN NHẤT không vượt quá
      mức án** (floor lookup qua mảng `MOC_THOI_HAN_BAO_QUAN_NAM` các mốc tăng dần), không còn tra
      khớp tuyệt đối (`BANG[...][n]`). Chỉ trả `null` khi mức án THẤP HƠN mốc nhỏ nhất trong bảng
      (hiện là "3 năm") — bảng gốc không phủ mức án dưới 3 năm, KHÔNG suy đoán/nội suy công thức vì
      đây là hồ sơ pháp lý thật, đoán sai thời hạn bảo quản là sai thật. Đình chỉ/Tạm đình chỉ luôn
      "Vĩnh viễn" theo bảng (không cần mức án). Đang giải quyết/Chuyển đi/Án huỷ/Đã nhập vụ khác
      KHÔNG có dòng tương ứng trong bảng gốc, trả `null` (không tính).
      **⚠ Lưu ý khi mirror/deploy**: lúc đọc file này thấy có `~$thoi han bao quan.xlsx` (file khoá
      tạm của Excel) tồn tại cùng thư mục — dấu hiệu file gốc **đang được mở** trên máy Dũng, có
      thể đang sửa dở. Nếu bảng đối chiếu trong code sai khác với file thật sau này, kiểm tra lại
      file gốc đã lưu (Ctrl+S) chưa trước khi kết luận code sai.
      **Nhập mức án**: thêm field `mucAnLoai`/`mucAnNam`/`mucAnThang` trên `vuan` (`mucAnThang` là
      số THÁNG LẺ 0-11, KHÔNG PHẢI cờ nhị phân +6 tháng — đã đổi thiết kế cùng đợt sửa bug ở trên,
      xem ngay dưới). `ghiNhanVuVaoPhien` snapshot kết quả tính (`thoiHanBaoQuan`) VÀ chính 3 field
      mức án này vào sự kiện `giao_nhan_ho_so` ngay lúc quét/chọn — giống cách
      `trangThaiVu`/`soQdGiaiQuyet` đã làm, KHÔNG tính lại lúc hiển thị/in.
      **Sửa lại (2026-07-16, cùng ngày) — chuyển hẳn việc nhập mức án ra khỏi `SuaVuAnForm`, vào
      thẳng dòng giao nhận** (`DongGiaoNhan`) cho tiện nhập liệu đúng lúc cần (nộp lưu trữ), thay
      vì phải mở riêng modal "Sửa thông tin vụ án" — mức án chỉ thật sự cần biết vào đúng thời điểm
      này. Cột **"Mức án"** đặt giữa "Hình thức giải quyết" và "Thời hạn bảo quản", chỉ hiện khi
      phiên `laLuuTru`; vụ không phải Đã xét xử hiện "—" (không sửa được, vì mức án không áp dụng).
      Sửa dùng chung nút Sửa/Lưu của cả dòng (cùng `dangSua` với KSV/ĐTV/Số bút lục) nhưng khác
      hẳn ở chỗ **ghi vào 2 nơi khi Lưu**: (1) `db.collection("vuan").doc(dong.maVuAn).update(...)`
      — vì mức án là thuộc tính của VỤ ÁN, không phải chỉ của dòng log như KSV/ĐTV/số bút lục; (2)
      `onSua` như cũ để cập nhật lại `mucAnLoai/mucAnNam/mucAnThang` VÀ tính lại `thoiHanBaoQuan`
      ngay trên chính dòng log đang xem — để cột Thời hạn bảo quản đổi ngay tại chỗ, không cần quét
      lại vụ mới thấy số mới. Nếu ghi `vuan` thất bại (lỗi mạng...), dừng lại không gọi `onSua`
      (tránh trạng thái 2 nơi lệch nhau: log nói đã có mức án X nhưng `vuan` thì chưa lưu được).
      **Ô Năm + ô Tháng riêng thay vì checkbox "+6 tháng" (2026-07-16, sửa cùng lúc với bug floor-
      lookup ở trên, theo phản hồi trực tiếp của người dùng)** — bản đầu tiên chỉ cho tick 1
      checkbox "+6 tháng" (nhị phân, cộng đúng 0.5 năm), không nhập được mức án lẻ tháng khác (VD
      "3 năm 5 tháng", "4 năm 11 tháng"). Đổi UI: 2 ô số riêng "... năm" + "... tháng" (0-11), lưu
      thẳng thành field `mucAnThang` (số tháng lẻ), quy đổi sang năm thập phân bằng `+ mucAnThang/12`
      trước khi tra bảng — kết hợp với floor-lookup ở trên cho phép nhập BẤT KỲ mức án lẻ tháng nào
      mà vẫn tra đúng thời hạn bảo quản.
      **Toggle "Nộp hồ sơ lưu trữ" đổi từ checkbox sang công tắc (2026-07-16, cùng ngày)** — thêm
      component dùng chung `CongTac` (nút bo tròn kiểu switch, không phải `<input
      type="checkbox">`) cho "hiện đại" hơn theo yêu cầu người dùng; đồng thời gom nút "Bắt đầu
      phiên — Nhận hồ sơ" + công tắc vào chung 1 khung viền riêng (tách khỏi nút "Giao hồ sơ") để
      rõ ràng công tắc này chỉ áp dụng cho việc bắt đầu phiên Nhận, không phải Giao.
      **Bug đã sửa (2026-07-16, cùng ngày) — bấm nhầm "Lưu phiên" (khoá cả phiên) trong lúc còn
      đang sửa dở 1 dòng làm mất trắng dữ liệu vừa nhập, không cách nào lưu lại.** Phát hiện qua
      Playwright tái hiện thực tế (không chỉ đọc code): nút "Lưu phiên" (to, luôn hiện góc trên) và
      nút "Lưu" của từng dòng (nhỏ, chỉ hiện khi đang sửa) tên gần giống nhau — bấm nhầm "Lưu phiên"
      giữa lúc sửa Mức án sẽ khoá phiên ngay lập tức, dòng đó kẹt lại ở chế độ sửa dở mà KHÔNG CÒN
      nút Lưu/Huỷ để bấm nữa (cột đó chỉ hiện khi phiên chưa khoá). Đã sửa: `GiaoNhanHoSoModule`
      đếm số dòng đang sửa (`soDongDangSua`, `DongGiaoNhan` tự báo qua `onBatDauSua`/`onKetThucSua`)
      và khoá nút "Lưu phiên" trong lúc đó, kèm dòng cảnh báo hướng dẫn.
      **Đã kiểm chứng bằng Playwright + mock Firestore trong bộ nhớ** (không chỉ đọc code, cả 2 bug
      trên đều tái hiện được lỗi TRƯỚC khi sửa và xác nhận hết lỗi SAU khi sửa) — riêng việc chạy
      thật trên `qlva-dev.html` với dữ liệu Firestore thật thì vẫn **CHƯA làm** (nên thử lại các
      kịch bản trên qua UI thật ít nhất 1 lần trước khi tin tưởng tuyệt đối trên `qlva.html` production).
      **CHƯA kiểm chứng bằng dữ liệu Firestore thật** — cần thử trên `qlva-dev.html`: bắt đầu phiên
      Nhận bật công tắc lưu trữ, quét/chọn 1 vụ Đã xét xử chưa có mức án, sửa dòng đó nhập mức án
      ngay tại bảng, xem cột Thời hạn bảo quản cập nhật đúng ngay (không cần quét lại), rồi kiểm
      tra tiếp biên bản in/Excel đều ra đúng số theo bảng gốc.
      **Thêm lựa chọn "Không tiếp nhận" kèm lý do (2026-07-17)** — chỉ áp dụng cho giao dịch NHẬN
      (bên nhận là người quyết định có nhận hồ sơ hay không, VD hồ sơ KSV/ĐTV mang sang còn thiếu
      thông tin), giao dịch Giao không có khái niệm này. Không phải 1 modal chặn ngay lúc quét
      (sẽ phá nhịp quét nhanh của đầu đọc QR) — vẫn quét/ghi nhận bình thường như cũ (mặc định
      `khongTiepNhan: false`), rồi đánh dấu NGAY TẠI DÒNG qua đúng cơ chế "sửa dòng" đã có (bấm cả
      dòng → `dangSua`): thêm 1 cột **"Tiếp nhận"** (chỉ hiện khi `dong.loaiGiaoDich === "nhan"`)
      với `CongTac` "Không tiếp nhận" (đỏ) + ô nhập lý do hiện ra khi bật — **bắt buộc gõ lý do**
      mới lưu được (chặn bằng toast lỗi, khác các trường KSV/ĐTV/số bút lục khác của dòng vốn
      không bắt buộc, vì đánh dấu "không tiếp nhận" mà không rõ lý do thì vô nghĩa). Lưu 2 field
      mới trên chính sự kiện `giao_nhan_ho_so`: `khongTiepNhan`/`lyDoKhongTiepNhan`.
      **Quan trọng: đây chỉ là 1 ghi chú/annotation thêm vào đúng dòng đó, KHÔNG xoá/ẩn dòng khỏi
      phiên, không đổi trạng thái vụ án `vuan`, không ảnh hưởng số liệu báo cáo kỳ** (giống mọi
      field khác của sự kiện `giao_nhan_ho_so` — log hành chính, không phải sự kiện nghiệp vụ) —
      hồ sơ vẫn hiện bình thường ở mọi nơi (bảng phiên, biên bản in, Excel lịch sử), chỉ thêm nội
      dung ghi chú giải thích tại sao chưa được nhận, để bên giao biết mà bổ sung rồi mang lại.
      Helper dùng chung `moTaTiepNhan(dong)` (cùng pattern `moTaHinhThucGiaiQuyet`) áp dụng ở cả 3
      nơi: cột "Tiếp nhận" trong bảng phiên (Badge xanh "✓ Đã tiếp nhận" / đỏ "✗ Không tiếp nhận"
      kèm lý do), cột "Tiếp nhận" trong Biên bản in A4 (chỉ hiện khi `phien.loaiGiaoDich ===
      "nhan"`, dùng chữ "⚠ Không tiếp nhận — <lý do>" thay vì Badge vì bản in không có màu nền),
      và cột "Tiếp nhận" trong Excel "Tải toàn bộ lịch sử" (luôn có cột, rỗng với giao dịch Giao).
      Đã kiểm chứng cú pháp bằng cách biên dịch qua đúng bản `@babel/standalone@7.25.6` app đang
      dùng — **CHƯA kiểm chứng bằng dữ liệu Firestore thật**, cần thử trên `qlva-dev.html`: bắt
      đầu phiên Nhận, quét 1 vụ, sửa dòng bật "Không tiếp nhận" mà bỏ trống lý do (phải bị chặn),
      gõ lý do rồi lưu (phải thành công), kiểm tra cột hiện đúng ở bảng/biên bản in/Excel.
      **Danh sách "Phiên gần đây" để mở lại phiên đã lưu/bỏ dở (2026-07-17)** — trước đây bấm
      "Phiên mới" hoặc lỡ đóng trình duyệt là MẤT hẳn đường vào lại 1 phiên đã có: phiên đã "Lưu
      phiên" chỉ còn xem/in được nhưng không có danh sách nào để bấm vào, phiên "Đang mở" bị bỏ dở
      giữa chừng (đóng nhầm tab, tưởng đã lưu) coi như mất luôn, chỉ tra được qua Nhật ký thao tác
      (liệt kê từng SỰ KIỆN lẻ, không theo phiên) hoặc Excel lịch sử (dump phẳng, không mở lại
      được). Thêm state `dsPhienGanDay` (`onSnapshot` trên `phienGiaoNhan`, `orderBy
      thoiDiemBatDau desc` + `limit(30)` — chỉ 1 field orderBy, KHÔNG kèm `where` nên không cần
      composite index mới) hiện ở màn hình chưa mở phiên, dưới 2 nút "Bắt đầu phiên". Bấm vào 1
      dòng = `setPhien(p)` — tái dùng nguyên state/effect sẵn có (đổi `phien` tự kích hoạt lại
      subscribe `dsQuet` theo `phien.id`), nên phiên "Đang mở" mở lại tiếp tục quét/sửa được ngay
      (đúng UI cũ vì `khoaSua = phien.trangThai !== "dang_mo"`), phiên "Đã lưu" chỉ xem/bấm "In
      phiên" lại (nút này vốn đã không phụ thuộc `trangThai`, chỉ cần `dsQuet.length > 0`) — không
      cần sửa gì thêm ở phần render đã có, chỉ cần đường vào lại phiên.
      **Fix bản in A4 bị cắt mất vụ án khi danh sách dài hơn 1 trang (2026-07-17, cùng đợt)** —
      `BienBanGiaoNhanIn` dùng `fixed inset-0 ... overflow-auto` cho khung xem trước/backdrop
      trên MÀN HÌNH, nhưng lúc IN THẬT, `position:fixed` ép khối cao đúng 1 viewport rồi
      `overflow-auto` chỉ hiện phần cuộn được trong đó — khiến các dòng vụ án vượt quá 1 trang A4
      bị CẮT MẤT khỏi bản in thay vì tự sang trang. Sửa bằng cách thêm biến thể Tailwind
      `print:static print:overflow-visible print:block print:bg-white print:p-0` (chỉ áp dụng khi
      in, giữ nguyên hành vi xem trước trên màn hình) để nội dung tự tràn ra nhiều trang bình
      thường — `<thead>` của bảng tự lặp lại đầu mỗi trang mới (hành vi mặc định trình duyệt với
      bảng HTML, không cần code thêm). Thêm `tr { break-inside: avoid; page-break-inside: avoid; }`
      vào đúng khối `<style>{"@page..."}</style>` cục bộ đã có (xem ghi chú `@page` ở trên) để 1
      dòng vụ án không bị cắt ngang giữa 2 trang. Đã kiểm chứng cú pháp bằng compile qua đúng bản
      `@babel/standalone@7.25.6` — **CHƯA in thử giấy thật với danh sách đủ dài (>1 trang A4
      ngang) để xác nhận việc sang trang + lặp header đúng như mong đợi**, cần thử trên
      `qlva-dev.html` với 1 phiên có nhiều vụ án trước khi tin tưởng trên production.
      **Đặt tên phiên (2026-07-17, cùng đợt) — tự động điền sau khi quét hồ sơ đầu tiên** — field
      mới `tenPhien` trên `phienGiaoNhan`. Bản đầu tiên hỏi tên ngay lúc bắt đầu phiên (trước khi
      quét vụ nào) nhưng người dùng chỉ ra vấn đề: lúc đó CHƯA quét hồ sơ nào nên chưa biết KSV/ĐTV
      là ai để đặt tên có nghĩa — đã đổi hẳn sang **tự động tính ngay sau khi quét/chọn hồ sơ ĐẦU
      TIÊN của phiên** (trong `ghiNhanVuVaoPhien`, điều kiện `!phien.tenPhien && dsQuet.length ===
      0` — chỉ tự đặt khi phiên CHƯA có tên, không ghi đè tên đã sửa tay): `Giao hồ sơ cho <tên>`
      (phiên Giao) hoặc `Nhận hồ sơ của <tên>` (phiên Nhận), với `<tên>` ưu tiên **ĐTV**
      (`vuAn.dtvCbdt`), không có thì **KSV** (`vuAn.ksvChinh`) — theo đúng yêu cầu người dùng. CỐ Ý
      KHÔNG dùng "Người nhận thực tế" (`nguoiNhanThucTe`) làm nguồn vì field đó không tồn tại trên
      `vuan`, chỉ là ghi chú tay thêm SAU trên từng dòng log (`DongGiaoNhan`), luôn rỗng đúng lúc
      quét nên vô nghĩa làm nguồn tự động tại thời điểm này. Cả 2 vụ (nếu vụ không có cả ĐTV lẫn
      KSV) thì bỏ qua, không đặt tên trống nghĩa.
      **CỐ Ý thuần tuý là nhãn để tra cứu** (theo yêu cầu người dùng: "không ảnh hưởng đến
      heading") — `<h2>Giao nhận hồ sơ</h2>` + dòng badge loại giao dịch/lưu trữ/đã lưu giữ nguyên
      y hệt trước, KHÔNG ảnh hưởng field nào khác của phiên hay của từng dòng hồ sơ đã quét, không
      xuất hiện trên biên bản in A4 hay Excel lịch sử. Hiện + **sửa tay được sau đó** (khác bản đầu
      tiên "chỉ đặt được lúc khởi tạo, không sửa được nữa") ở 1 dòng nhỏ ngay dưới "Phiên hiện tại"
      (không phải trong `<h2>`) — bấm vào để bật input inline (`dangSuaTenPhien`/`tenPhienDangSua`),
      Lưu/Huỷ, dùng được bất kể phiên đang mở hay đã lưu (chỉ là nhãn tra cứu, không phải dữ liệu
      nghiệp vụ nên không khoá theo `trangThai` như các dòng log khác) — hữu ích để tự sửa lại nếu
      tên tự động không đúng ý, hoặc đặt tên cho phiên lỡ không tự đặt được (vụ thiếu cả ĐTV/KSV).
      Cũng dùng ở danh sách **"Phiên gần đây"** (đã có sẵn, xem mục ngay trên) — hiện tên (nếu có)
      làm dòng đậm phía trên các Badge của mỗi phiên, kèm 1 ô **tìm theo tên phiên** (`tuKhoaPhien`,
      lọc client-side, case-insensitive) đặt cạnh tiêu đề "Phiên gần đây" — chỉ tìm được trong 30
      phiên gần nhất đã tải sẵn (giới hạn của chính danh sách "Phiên gần đây", không phải hạn chế
      riêng của tìm kiếm; đã ghi rõ trên UI), KHÔNG query full-collection để tìm phiên cũ hơn. Đã
      kiểm chứng cú pháp bằng compile qua đúng bản `@babel/standalone@7.25.6` — **CHƯA kiểm chứng
      bằng dữ liệu Firestore thật**, cần thử trên `qlva-dev.html`: bắt đầu phiên Giao, quét 1 vụ có
      ĐTV, xác nhận tên phiên tự điền đúng "Giao hồ sơ cho <ĐTV>" ngay sau khi quét; thử tiếp 1 vụ
      chỉ có KSV không có ĐTV, xác nhận rơi xuống dùng KSV; bấm sửa tên tại dòng "Tên phiên" dưới
      header, lưu lại, xác nhận cập nhật đúng cả trên UI lẫn khi mở lại từ "Phiên gần đây".
- [x] Dựng lại lịch sử cho dữ liệu import cũ: nút "Dựng lại lịch sử" trong module Import Excel
      (`DungLaiLichSuTool`) — quét `vuan` chưa có dòng `lichsuChuyenGiaiDoan` nào, tự tạo 1 sự
      kiện `khoi_to_vu` + `khoi_to_bican` mỗi bị can theo dữ liệu hiện có. Idempotent (chạy
      lại không tạo trùng, vụ đã có log sẽ bị bỏ qua) nhưng KHÔNG dựng lại được các lần gia
      hạn/trả hồ sơ trước khi import — dữ liệu đó không còn lưu vết trong Excel gốc. Vẫn giữ
      nguyên cho dữ liệu đã import bằng mẫu DSAT/DSBCT cũ; import bằng mẫu "Danh sách án" mới
      (mục dưới) không cần công cụ này vì đã tự ghi log ngay lúc import.
- [x] **Import Excel — đổi hẳn sang mẫu "Danh sách án" (2026-07-13), bỏ mẫu DSAT/DSBCT cũ** theo
      yêu cầu người dùng — mẫu cũ đọc 2 sheet DSAT/DSBCT y hệt cấu trúc file Excel thống kê thủ
      công cũ (nhiều cột cờ không rõ nghĩa, không tạo log, không chống trùng), thay bằng 1 sheet
      duy nhất tên đúng `"Danh sách án"` (hằng số `TEN_SHEET_DANH_SACH_AN`), cấu trúc **1 dòng/bị
      can, thông tin vụ lặp lại từng dòng** — cùng kiểu với các sheet DS mới/DS tồn... mà "Xuất
      Excel báo cáo tháng" (`VU_H`/`BC_H`, xem mục Xuất Excel báo cáo tháng) đã xuất ra, cộng thêm
      các cột bắt buộc để dựng được 1 vụ án hoàn chỉnh mà báo cáo không cần mang theo: Giai đoạn,
      Trạng thái, Ngày/Số quyết định (chỉ bắt buộc khi Trạng thái khác "Đang giải quyết" — dùng
      cho vụ án cũ đã có kết quả), Nguồn, Số/Ngày QĐ KTVA tách 2 cột riêng (bỏ hẳn kiểu ghép chung
      `"108/28.3.23"` của mẫu cũ — `splitSoNgayQuyetDinh` đã xoá vì không còn nơi dùng), và thêm
      cột Giới tính bên bị can (mẫu cũ hardcode cứng `gioiTinh: "nam"` cho mọi bị can vì DSBCT gốc
      không có cột này — nay đọc thật từ file).
      **Hàm đọc mới `parseWorkbookDanhSachAn`** (thay hẳn `parseWorkbook`/`mapNguon` cũ, đã xoá):
      header ở ĐÚNG dòng 1 (không phải dòng 2 như mẫu cũ — để có thể lấy thẳng 1 sheet report đã
      xuất ra làm gốc), dữ liệu từ dòng 2; đọc theo vị trí cột cố định y hệt nguyên tắc cũ. Nhận
      diện Giai đoạn/Trạng thái/Nguồn qua khớp NGƯỢC với chính `NHAN_GIAI_DOAN`/`NHAN_TRANG_THAI`/
      `NHAN_NGUON` (hàm `timTuNhan`, case-insensitive) — không nhận diện được thì mặc định Điều
      tra/Đang giải quyết/Án khởi tố mới kèm cảnh báo trên bảng xem trước, không chặn import.
      **Tự động nhận diện vụ trùng (yêu cầu cốt lõi của bản redesign này) theo đúng thứ tự ưu
      tiên mã vụ án → Số+Ngày QĐ KTVA**: sau khi đọc file, tải toàn bộ `vuan` hiện có 1 lần, dựng
      2 map tra cứu (`byMa` khớp cả `maNganhCap` lẫn `maNoiSinh`; `byQdNgay` khớp cặp
      `soQdKtva`+`ngayQdKtva` qua `fmtDate` làm khoá) — vụ trùng theo 1 trong 2 tiêu chí bị loại
      thẳng, KHÔNG ghi vào hệ thống (tránh xung đột/ghi đè dữ liệu đang có, đúng yêu cầu người
      dùng), hiện trong bảng xem trước riêng "vụ trùng — sẽ bỏ qua" kèm lý do/ID vụ đã có để đối
      chiếu. Vụ thiếu dữ liệu bắt buộc (thiếu Tên vụ/Ngày QĐ KTVA/Ngày quyết định khi đã giải
      quyết) rơi vào nhóm lỗi riêng "vụ thiếu dữ liệu — sẽ bỏ qua", cũng không import, phải sửa
      file rồi tải lại — 3 nhóm moi/trung/loi tính toán ngay khi tải file (không cần bấm gì thêm),
      chỉ nhóm "mới" mới có nút ghi vào hệ thống.
      **Vụ mới được cấp mã hệ thống thật (`maNoiSinh`) thay vì dùng thẳng mã trong file làm ID**
      (khác hẳn cách cũ `db.collection("vuan").doc(va.maNganhCap)` — rủi ro mã trống/trùng giữa
      2 dòng làm mất dữ liệu) — mã trong file giữ lại làm `maNganhCap` (mã tham chiếu), đúng kiểu
      dữ liệu `ThemVuAnForm` tạo ra. Sinh mã theo lô qua `sinhNhieuMaVuAn` (gom theo tháng QĐ
      KTVA, 1 transaction/tháng thay vì 1 transaction/vụ như `sinhMaVuAnMoi` — vì import có thể
      hàng chục/hàng trăm vụ cùng lúc, sinh từng vụ 1 transaction sẽ chậm).
      **Ghi log ngay lúc import (khác hẳn mẫu cũ hoàn toàn không tạo log, phải chạy
      `DungLaiLichSuTool` thủ công sau đó)**: mỗi vụ mới được ghi `khoi_to_vu` + `khoi_to_bican`
      mỗi bị can qua `taoSuKien`, và nếu Trạng thái khác "Đang giải quyết" thì ghi thêm 1 sự kiện
      `hoan_thanh` (kèm `soQuyetDinh`/`ngaySuKien` lấy từ 2 cột Ngày/Số quyết định, và field
      tương ứng trên `vuan` qua `fieldSoQuyetDinhTrenVuAn` — y hệt luồng `HoanThanhVuAnModal`) +
      set `ngayQuyetDinh`/`kyHoanThanh` trên `vuan` (đúng index mà module Án đã giải quyết cần,
      xem mục Án đã giải quyết) — vụ án cũ đã giải quyết import bằng mẫu này lên thẳng "Án đã giải
      quyết" ngay, không cần chạy thêm `BackfillNgayQuyetDinhTool`.
      **Hỏi kỳ báo cáo 1 LẦN cho cả đợt import** (không hỏi riêng từng vụ — 1 file thường là 1 đợt
      nhập cùng nguồn/cùng thời điểm) qua chính `ModalXacNhanKy` dùng chung (nguyên tắc thiết kế
      #3), bật lên khi bấm nút "Ghi ... vụ mới vào hệ thống" — cho chọn 1 kỳ báo cáo bình thường
      (án mới thật sự phát sinh trong kỳ đang làm việc) HOẶC **"Kỳ lưu trữ án cũ"** (`loai:
      "luu_tru"`, khái niệm đã có sẵn từ `MoKyMoiForm`/module Kỳ báo cáo — dùng khi nhập lại án cũ
      cho đủ hồ sơ, sự kiện gán vào kỳ này không tính vào báo cáo tháng nào) — `kyThongKe` của mọi
      sự kiện log VÀ `kyThongKeKhoiTo` trên từng `bican` đều set theo đúng lựa chọn này.
      File mẫu tham khảo: `Mau_Import_DanhSachAn.xlsx` (không phải code của app, tạo 1 lần bằng
      script Python dùng `openpyxl` rồi xoá script — nếu cần sửa mẫu, tạo lại tương tự, đừng coi
      file `.xlsx` này là nguồn sự thật của cấu trúc cột, nguồn thật luôn là
      `parseWorkbookDanhSachAn` trong `qlva.html`).
      **Fix: "Mã vụ" (cột A) không còn bắt buộc (2026-07-13, nhánh `import-excel-fix`)** — bug
      thật gặp phải: người dùng import 1 file 760 dòng đúng mẫu, hệ thống báo "không dòng nào có
      Mã vụ" dù dữ liệu hợp lệ. Nguyên nhân: bản đầu tiên bắt buộc cột A khác rỗng mới coi là 1
      dòng dữ liệu (`rows = rawRows.filter(r => r[0] != null...)`) — sai với đúng nhu cầu thực tế
      là NHẬP ÁN NGUỒN TỪ NGOÀI HỆ THỐNG, tức các vụ CHƯA TỪNG có mã vụ. Đã sửa 2 chỗ:
      (1) tiêu chí "dòng có dữ liệu" đổi thành có Tên vụ HOẶC Ngày QĐ KTVA (không cần cột A);
      (2) khoá NHÓM nhiều dòng bị can về cùng 1 vụ đổi từ luôn dùng `maVu` sang: có Mã vụ thì
      dùng Mã vụ (hành vi cũ, cho vụ đã có mã sẵn), KHÔNG có Mã vụ thì dùng cặp Số+Ngày QĐ KTVA
      giống hệt nhau (đúng yêu cầu nghiệp vụ người dùng nêu rõ: "số QĐ và ngày QĐ KTVA giống nhau
      là 1 vụ nhiều dòng do nhiều bị can"). Dòng vừa thiếu Mã vụ vừa thiếu Ngày QĐ KTVA thì KHÔNG
      gộp chung với dòng khác cũng thiếu (khoá riêng theo index dòng, tránh gộp nhầm 2 vụ không
      liên quan chỉ vì cùng thiếu thông tin). `vuData.maNganhCap = v.maVu || null` ở bước ghi đã
      tự đúng từ trước (không cần sửa) — vụ nhóm theo QĐ KTVA vẫn được `sinhNhieuMaVuAn` cấp
      `maNoiSinh` bình thường, tính năng "tự sinh mã vụ án mới cho vụ chưa có mã" thực chất đã có
      sẵn từ bản đầu, chỉ là dữ liệu chưa bao giờ lọt qua được bước đọc sheet. Bước đối chiếu
      trùng cũng thêm guard `if (v.maVu) {...}` trước khi tra `byMa` để tránh lookup vô nghĩa khi
      `maVu` rỗng. Đã kiểm chứng lại bằng file giả lập thật (Node + thư viện `xlsx` thật, không
      chỉ đọc code) trước khi mirror sang `qlva-dev.html` — xem lịch sử trò chuyện lúc sửa để biết
      cách dựng lại test tương tự nếu cần kiểm tra lại sau này.
      **Nới lỏng tiếp: chỉ bắt buộc Số QĐ KTVA + Ngày QĐ KTVA + KSV chính (2026-07-13, cùng
      nhánh)** — theo yêu cầu người dùng: nhập nhanh án mới với tối thiểu 3 trường này là đủ, các
      trường còn thiếu (Tên vụ, Điều luật, đơn vị thụ lý, Giai đoạn/Trạng thái/Nguồn...) bổ sung
      dần sau qua nút "Sửa thông tin vụ án" (đã có sẵn ở cả panel chi tiết Danh sách vụ án lẫn màn
      Giao nhận hồ sơ — xem 2 mục đó). Bỏ hẳn ràng buộc "thiếu Tên vụ" khỏi `_loi`, thêm ràng buộc
      mới "thiếu Số QĐ KTVA" và "thiếu KSV chính". Tên vụ bỏ trống: sau khi gom xong toàn bộ dòng
      của 1 vụ (vòng `vuMap.forEach` cuối `parseWorkbookDanhSachAn`, chạy SAU vòng nhóm dòng chính
      vì cần biết đủ `biCanList` mới đặt tên được), tự đặt tên tạm `"<tên bị can đầu tiên> và đồng
      phạm"` nếu có >1 bị can, chỉ tên bị can đó nếu đúng 1 bị can — giống hệt quy ước
      "Họ tên bị can đại diện" mà mẫu DSAT cũ dùng để tự đặt tên, chỉ khác là tính lúc đọc file
      thay vì lúc ghi. Vụ hoàn toàn không có bị can VÀ không có Tên vụ thì giữ nguyên rỗng (không
      tính lỗi) — hiển thị "(chưa đặt tên)" như panel chi tiết đã tự xử lý sẵn cho `tenVu` rỗng.
      Đã kiểm chứng lại bằng file giả lập thật (2 vụ: 1 vụ tối giản chỉ có 3 trường bắt buộc + 2 bị
      can → tự đặt tên đúng, không lỗi; 1 vụ thiếu KSV → đúng bị gắn `_loi`) trước khi mirror sang
      `qlva-dev.html`.
      **Vụ đã có kết quả nhưng thiếu Ngày quyết định: hết chặn, tự dùng ngày ước tính (2026-07-13,
      cùng nhánh)** — theo yêu cầu người dùng, cụ thể là dữ liệu Tạm đình chỉ cũ hay thiếu khoản
      này. Bỏ nhánh `thieu.push("Trạng thái ... thiếu Ngày quyết định")` (từng chặn hẳn, đưa vào
      nhóm lỗi) — thay bằng: khi Trạng thái ≠ "Đang giải quyết" VÀ thiếu Ngày quyết định VÀ đã có
      Ngày QĐ KTVA (bắt buộc nên luôn có, trừ khi vụ đã bị `_loi` vì lý do khác) → tự gán
      `ngayQuyetDinh = ngayQdKtva + 4 tháng` (`Date.setMonth`, tự cuốn năm đúng khi tràn tháng),
      gắn field mới `v.ghiChu` (con dấu ⚠ + giải thích rõ đây là ngày ước tính, cần cập nhật lại)
      VÀ đẩy 1 dòng cảnh báo riêng vào `warnings` để hiện ngay trên bảng xem trước trước khi ghi.
      `v.ghiChu` được set vào field `ghiChu` của chính `vuan` doc lúc ghi (`ghiVaoCoSoDuLieu`,
      trước đó hardcode `""`), VÀ nối thêm vào `ghiChu` của sự kiện `hoan_thanh` (nối sau
      `ghiChuNhap` cố định "Nhập qua Import Excel...") — để cả 2 nơi tra cứu (thông tin vụ + lịch
      sử) đều thấy cảnh báo, không chỉ 1 chỗ. CHỈ áp dụng field `ghiChu` mới này cho các vụ THẬT
      SỰ dùng ngày ước tính (rỗng nếu ngày quyết định có sẵn từ file) — không đụng tới field
      `ghiChu` cho các trường hợp khác. Đã kiểm chứng lại bằng file giả lập thật (vụ Tạm đình chỉ,
      QĐ KTVA 01/01/2026, không có Ngày quyết định → tự tính đúng 01/05/2026, không còn `_loi`,
      có cảnh báo trong `warnings`) trước khi mirror sang `qlva-dev.html`.
      **Cờ `ngayQuyetDinhUocTinh` + hiện đỏ trong Án đã giải quyết (2026-07-13, cùng nhánh)** —
      thêm field boolean riêng `v.ngayQuyetDinhUocTinh` lúc parse (tách khỏi việc suy luận từ
      `ghiChu` — rõ ràng hơn, không lệ thuộc string), set `vuData.ngayQuyetDinhUocTinh = true` lúc
      ghi (chỉ set field này khi `true`, không set `false` — field không tồn tại trên các vụ khác,
      tránh rác field cho toàn bộ dữ liệu tạo qua đường khác). `AnDaGiaiQuyetModule` đọc cờ này để
      tô đỏ + thêm icon ⚠ + tooltip ở đúng ô "Ngày quyết định" khi `true`.
      **Sửa được ngay trong `SuaVuAnForm` (2026-07-14)** — thêm khối "Thông tin giải quyết" (chỉ
      hiện khi `vuAn.trangThai !== "dang_giai_quyet"`, đặt ngay dưới ô cảnh báo "chỉ sửa thông tin
      thường" đầu form) gồm **Ngày giải quyết** (`ngayQuyetDinh`) + ô Số QĐ giải quyết có nhãn động
      theo hình thức (dùng lại `NHAN_SO_QUYET_DINH_HOAN_THANH[vuAn.trangThai]`, field ghi qua
      `fieldSoQuyetDinhTrenVuAn(vuAn.trangThai)` — xem mục Án đã giải quyết ở trên). Lưu form này
      **luôn xoá cờ `ngayQuyetDinhUocTinh`** (set `false`) bất kể có đổi ngày hay không — coi việc
      mở form sửa thông tin giải quyết là hành động "đã xác nhận lại" của người dùng, đúng gợi ý
      đã ghi ở đây trước đó.
      **Đổi sang bố cục 2 cột giống hệt Danh sách vụ án (2026-07-13, cùng nhánh)** — thay vì 1
      bảng full-width kèm nút "✎ Sửa thông tin" đơn lẻ (bản chỉ mở được `SuaVuAnForm`), module này
      giờ dùng đúng layout `DanhSachPanel`/`ChiTietPanel` đã có: panel trái `flex-1` là bảng danh
      sách (đổi từ `<table>` full-width `overflow-hidden` sang khung `flex flex-col min-h-0` +
      `<thead className="... sticky top-0 z-10">` bên trong `<div className="flex-1 overflow-auto">`
      — đúng pattern cuộn nội bộ đã dùng ở `DanhSachPanel`, xem mục "Bố cục cuộn trang"), bấm 1
      dòng (`onClick={() => setSelectedId(v.id)}`, style `border-l-4` + `bg-indigo-50` khi đang
      chọn — COPY nguyên pattern từ `DanhSachPanel`) hiện panel phải cố định 420px là **chính
      `ChiTietPanel`** (dùng lại y nguyên component đã có ở Danh sách vụ án, KHÔNG viết lại) — tự
      động có đầy đủ: bảng thông tin, danh sách bị can, lịch sử, nút "In mã QR"/"Sửa thông tin"/
      "Xóa vụ án", VÀ các nút hành động nghiệp vụ phù hợp trạng thái hiện tại của vụ (do
      `ChiTietPanel` tự ẩn/hiện theo `vuAn.trangThai`/`coQuanThuLy` — vụ đã xong hẳn như Đã xét xử
      chỉ còn "In mã QR"/"Sửa thông tin"/"Xóa vụ án", riêng tab Tạm đình chỉ còn thêm cả nút "Phục
      hồi" vì `ChiTietPanel` có điều kiện `vuAn.trangThai === "tam_dinh_chi"` sẵn — đúng ý nghĩa
      nghiệp vụ, không cần code thêm gì). State `vuAnDangSua`/`SuaVuAnForm` gọi trực tiếp của bản
      trước đã bỏ, thay bằng `selectedId` + `<ChiTietPanel vuAnId={selectedId}
      onDoiSelected={setSelectedId} />` y hệt cách `DanhSachVuAnModule` ghép 2 panel.
      **Lọc riêng theo KSV ở mọi nơi có ô tìm kiếm (2026-07-13)** — trước đây chỉ `DanhSachPanel`
      (Danh sách vụ án) có dropdown "Tất cả KSV" riêng, các chỗ khác chỉ tìm KSV được gián tiếp
      qua ô tìm kiếm tự do (phải gõ đúng/gần đúng tên). Đã thêm dropdown KSV (cùng pattern
      `dsKsv = [...new Set(list.map(v => v.ksvChinh).filter(Boolean))].sort()`) vào:
      **Án đã giải quyết** (state `ksv`, kết hợp AND với lọc kỳ + tìm kiếm tự do trong
      `listHienThi`) và **Giao nhận hồ sơ → "Tìm thủ công"** (state `ksvTim` — khác 1 chỗ: panel
      này trước đây CHỈ hiện kết quả khi có gõ từ khoá, nay cho phép chỉ chọn KSV mà KHÔNG cần gõ
      gì cũng ra danh sách, đúng nhu cầu "xem hết hồ sơ đang giải quyết của 1 KSV" — điều kiện ẩn/
      hiện danh sách đổi từ `tuKhoaTim.trim()` sang `tuKhoaTim.trim() || ksvTim !== "tat_ca"`).
      KHÔNG thêm dropdown KSV vào `NhapVuModal` (ô tìm 1 vụ đích để nhập vào — công cụ tìm-chọn 1
      bản ghi, không phải màn danh sách/lọc) hay `DanhMucToiDanhModule` (danh mục tội danh, không
      có field KSV — không có khái niệm để lọc).
      dùng chung + hook `useHanhDongVuAn`): Chuyển giai đoạn, Trả hồ sơ, Gia hạn điều tra,
      Hoàn thành vụ án (gộp cả 5 hình thức da_xet_xu/chuyen_di/tam_dinh_chi/dinh_chi/an_huy —
      tự động tách vụ khi TĐC/ĐC chỉ áp dụng 1 phần bị can, xem hàm `tachVuAn`), **Tách vụ án**
      thủ công (nút hiện với MỌI vụ đang giải quyết, kể cả 0 hoặc 1 bị can — 2026-07-11: bỏ điều
      kiện cũ `biCanList.length >= 2`, vì 1 vụ có thể có nhiều hành vi cần tách xử lý độc lập dù
      chỉ 1 bị can, hoặc hành vi chưa xác định được đối tượng nào — tách vụ 0 bị can tạo 1 vụ mới
      trống). `ChonBiCan` giờ là lựa chọn **3 trạng thái** mỗi bị can thay vì checkbox nhị phân:
      "Ở lại vụ gốc" / "Chuyển hẳn sang vụ mới" / **"Ở cả 2 vụ"** (sao chép — 1 người có nhiều
      hành vi, chỉ 1 hành vi tách ra nhưng người đó vẫn còn liên quan ở vụ gốc). Bản sao được gắn
      `nhomBiCanId` trỏ về ID bị can gốc để đánh dấu "2 bản ghi này là CÙNG 1 người" — dùng khi
      **Nhập vào vụ khác** sau này: nếu bị can vụ nguồn có `nhomBiCanId` trùng với 1 bị can đã có
      sẵn ở vụ đích, hệ thống GỘP tội danh vào bản ghi đích và xoá bản ghi nguồn thay vì tạo bị
      can trùng (đã kiểm chứng qua test: tách "ở cả 2 vụ" rồi nhập lại → vụ gốc vẫn đúng 1 bị
      can, không nhân đôi). **Nhập vào vụ khác** cũng ghi sự kiện `nhap_vu` trên vụ nguồn NHƯ CŨ,
      cộng thêm 1 sự kiện `duoc_nhap_vu` mới trên vụ ĐÍCH — vụ nguồn tuy không xoá (`trangThai:
      "da_nhap"`) nhưng trước đây lịch sử vụ đích không có dấu vết gì về việc đã nhận nhập; giờ
      lưu sẵn mã vụ/tên vụ/KSV của vụ nguồn dạng chuỗi trong `ghiChu` của sự kiện `duoc_nhap_vu`
      để tra soát nhanh ngay trên lịch sử vụ đích. Phục hồi (từ tạm đình chỉ).
      **Xóa vụ án (2026-07-13, `XoaVuAnModal`)** — KHÁC HẲN mọi hành động khác ở trên: đây không
      phải sự kiện nghiệp vụ (không đi qua `ModalXacNhanKy`/hỏi kỳ), mà là xóa vĩnh viễn dùng để
      sửa sai sót tạo nhầm (VD double-click tạo trùng, nhập liệu hoàn toàn sai) — hiếm dùng, KHÔNG
      phải luồng nghiệp vụ bình thường (đã có sẵn Hoàn thành/Trả hồ sơ/Tách vụ cho các trường hợp
      hợp lệ khác, đừng dùng Xóa để "sửa" 1 vụ hợp lệ). Nút đặt tách biệt cuối panel chi tiết (chữ
      đỏ nhỏ, ngoài cụm nút hành động chính phía trên) để tránh bấm nhầm. Bắt gõ lại đúng mã vụ
      hiển thị (`hienThiMa`) để xác nhận mới cho bấm xóa (không có cách hoàn tác). **Chặn hẳn** nếu
      còn vụ án nào có `vuGoc` trỏ về vụ đang xóa (tức đã TÁCH RA từ vụ này và còn tồn tại) — tránh
      để lại dữ liệu mồ côi mất gốc. Xóa cascade đúng 3 collection: doc `vuan`, mọi `bican` có
      `maVuAn` khớp, mọi `lichsuChuyenGiaiDoan` có `maVuAn` khớp (dùng `batch.delete`, chunk 400).
      KHÔNG cập nhật `baoCaoLuu` của kỳ đã chốt (chỉ cảnh báo trong modal, giống mọi thao tác sửa
      dữ liệu thuộc kỳ đã chốt khác) — người dùng tự chạy "Tính lại số liệu" ở Kỳ báo cáo nếu cần.
      KHÔNG xử lý trường hợp bị can của vụ này có bản sao (`nhomBiCanId`) ở vụ khác từ thao tác
      Tách — xóa vụ gốc sẽ làm ID nhóm đó không còn trỏ tới bị can thật nào, nhưng không phá dữ
      liệu bản sao, chỉ mất khả năng "Nhập vụ" nhận diện gộp về sau; chưa cần xử lý vì chưa gặp
      yêu cầu thực tế, nếu phát sinh vấn đề thì bổ sung cảnh báo tương tự cảnh báo vụ tách.
      **Xoá hình thức giải quyết (2026-07-17, `XoaHinhThucGiaiQuyetModal`)** — nhu cầu thực tế:
      chọn NHẦM hình thức lúc bấm "Hoàn thành vụ án" (VD chọn "Đã xét xử" nhưng đúng ra phải là
      "Tạm đình chỉ") — trước đây KHÔNG có cách nào tự sửa, vì 1 khi vụ đã ở trạng thái đã giải
      quyết, panel chi tiết chỉ còn 3 nút (In mã QR/Sửa thông tin/Xóa vụ án), "Sửa thông tin vụ án"
      cố tình chặn sửa giai đoạn/trạng thái, và "Phục hồi" chỉ hiện cho riêng "Tạm đình chỉ". Nút
      mới **"Xoá hình thức giải quyết"** hiện cho cả 5 trạng thái do "Hoàn thành vụ án" tạo ra
      (điều kiện `FIELD_SO_QD_HOAN_THANH[vuAn.trangThai]` — tự động KHÔNG áp dụng cho "Đã nhập vào
      vụ khác" vì trạng thái đó không có entry trong map này, đúng vì đó là luồng khác hẳn, xem
      `NhapVuModal`). **KHÁC HẲN "Phục hồi"** (giữ nguyên như cũ, không đụng vào — theo yêu cầu
      người dùng đây là 1 tính năng riêng sẽ phát triển tiếp sau này): Phục hồi là hành động
      NGHIỆP VỤ chính thức (ghi sự kiện `phuc_hoi` mới, giữ nguyên sự kiện `hoan_thanh` cũ trong
      lịch sử, cần nhập ngày/số quyết định phục hồi điều tra, đi qua `ModalXacNhanKy` hỏi kỳ) —
      còn "Xoá hình thức giải quyết" là công cụ SỬA SAI SÓT thuần tuý (không hỏi kỳ, không ghi sự
      kiện mới): xoá hẳn `ngayQuyetDinh`/`kyHoanThanh`/`ngayQuyetDinhUocTinh`/`noiChuyenDen` + field
      số quyết định tương ứng (qua `fieldSoQuyetDinhTrenVuAn`) trên `vuan`, set `trangThai:
      "dang_giai_quyet"`, VÀ XOÁ LUÔN đúng sự kiện `hoan_thanh` đã gây ra trạng thái hiện tại khỏi
      `lichsuChuyenGiaiDoan` (đúng nguyên tắc thiết kế #1 — nếu không xoá log, số liệu báo cáo kỳ
      vẫn tính vụ này là "đã giải quyết" dù `vuan.trangThai` đã về "đang giải quyết", gây lệch số
      giữa `tinhTonHienTaiTheoGD` (đọc live `vuan`) và `tinhBaoCaoKyTuLog` (đọc log)). Sau khi xoá,
      bấm lại "Hoàn thành vụ án" để nhập đúng hình thức từ đầu.
      Tìm đúng sự kiện `hoan_thanh` cần xoá bằng cách lọc trên `lichSu` **ĐÃ CÓ SẴN** trong
      `ChiTietPanel` (đã tải, sắp xếp `desc` theo `thoiDiemGhi`) — lấy phần tử `hoan_thanh` ĐẦU
      TIÊN gặp trong mảng (= gần nhất), KHÔNG query Firestore riêng để tránh phải thêm composite
      index mới (`maVuAn` + `loaiSuKien` + `orderBy`) chỉ dùng 1 chỗ này. Cách này cũng tự nhiên
      không đụng tới các lần `hoan_thanh` CŨ HƠN nếu vụ từng Phục hồi rồi Hoàn thành lại nhiều lần
      trong lịch sử (chỉ xoá đúng sự kiện gần nhất). Không bắt gõ lại mã vụ để xác nhận như
      `XoaVuAnModal` (ít phá huỷ hơn — chỉ ảnh hưởng 1 vụ, không cascade xoá bị can/toàn bộ lịch
      sử) nhưng vẫn cảnh báo rõ không thể hoàn tác + nhắc "Tính lại số liệu" nếu vụ đã tính vào kỳ
      đã chốt (giống cảnh báo ở `XoaVuAnModal`). Đã kiểm chứng cú pháp bằng compile qua đúng bản
      `@babel/standalone@7.25.6` — **CHƯA kiểm chứng bằng dữ liệu Firestore thật**, cần thử trên
      `qlva-dev.html`: Hoàn thành 1 vụ (chọn nhầm hình thức), bấm "Xoá hình thức giải quyết", xác
      nhận vụ về "Đang giải quyết" đúng, sự kiện `hoan_thanh` cũ biến mất khỏi Lịch sử, rồi bấm lại
      "Hoàn thành vụ án" chọn đúng hình thức xem lưu bình thường không.
      **Ràng buộc "Đã xét xử" chỉ chọn được ở giai đoạn Xét xử (2026-07-17)** — trước đây
      `HoanThanhVuAnModal` cho chọn cả 5 hình thức (`TUY_CHON_HOAN_THANH`) bất kể vụ đang ở giai
      đoạn nào, dẫn tới việc lỡ chọn "Đã xét xử" cho vụ còn ở Điều tra/Truy tố (vô lý về nghiệp vụ
      — chưa ra toà thì chưa thể có bản án). Đã thêm điều kiện lọc: nút "Đã xét xử" chỉ hiện trong
      `HoanThanhVuAnModal` khi `vuAn.coQuanThuLy === "xet_xu"` (biến `tuyChonKhaDung`, lọc từ
      `TUY_CHON_HOAN_THANH` — KHÔNG sửa hằng số gốc vì `ThemVuAnForm` dùng chung hằng số này cho 1
      tình huống khác, xem ngay dưới). Vụ chưa tới giai đoạn Xét xử thì mặc định `hinhThuc` đổi
      sang `"chuyen_di"` (đặt lúc tải xong `vuAn` trong `useEffect`, không phải lúc khởi tạo
      `useState` vì lúc đó chưa biết `coQuanThuLy`), kèm dòng chú thích nhỏ giải thích lý do ẩn.
      Chặn thêm ở `luu()` (phòng trường hợp state cũ còn sót lại) để không lọt xuống Firestore dù
      UI có bị bypass thế nào. **Áp dụng tương tự cho `ThemVuAnForm`** (khối "Vụ án đã có kết quả
      giải quyết" — nhập bổ sung án cũ đã xong ngay lúc tạo vụ, dùng lại `TUY_CHON_HOAN_THANH`):
      dropdown "Hình thức giải quyết" lọc theo `coQuanThuLy` đang CHỌN trên form (khác
      `HoanThanhVuAnModal` — ở đó đọc từ 1 `vuAn` đã lưu, ở đây đọc từ state đang nhập), đổi
      `coQuanThuLy` sang khác "Xét xử" thì tự bỏ chọn "Đã xét xử" nếu đang chọn (tránh kẹt lựa
      chọn không còn hiện trên UI), đổi mặc định `trangThaiKetQua` từ `"da_xet_xu"` sang
      `"chuyen_di"` (khớp mặc định `coQuanThuLy` là Điều tra), và chặn thêm ở `onBamLuu()`. Đã
      kiểm chứng cú pháp bằng compile — **CHƯA kiểm chứng bằng dữ liệu Firestore thật**.
- [x] Module Án đã giải quyết (`AnDaGiaiQuyetModule`) — 5 tab theo `trangThai` cụ thể (Đã xét
      xử/Chuyển đi/Tạm đình chỉ/Đình chỉ/Án huỷ, danh sách `TAB_DA_GIAI_QUYET`), lấy `ngày quyết
      định` từ sự kiện `hoan_thanh` trong log (không phải `ngayCapNhat` của `vuan` — field đó có
      thể bị đổi bởi "Sửa thông tin" sau này nên không đáng tin làm ngày quyết định thật).
      Module **"Án tồn theo giai đoạn" (`AnTonModule`) đã bị XOÁ (2026-07-11)** theo yêu cầu
      người dùng — vai trò của nó (lọc theo giai đoạn + chỉ xem đang giải quyết + cảnh báo màu
      hạn điều tra) nay nằm hoàn toàn trong module Danh sách vụ án (toggle "Đang giải quyết" +
      tab giai đoạn có sẵn), không tạo module riêng nữa. Đừng làm lại module này trừ khi người
      dùng yêu cầu rõ ràng.
      **Lọc theo kỳ gồm cả kỳ lưu trữ án cũ + tìm kiếm (2026-07-13)** — dropdown "Lọc theo kỳ"
      trước đây lọc bỏ kỳ `loai: "luu_tru"` (`.filter(k => k.loai !== "luu_tru")`, sao chép máy
      móc từ `ModalXacNhanKy` — ở đó lọc bỏ vì mục đích khác: chỉ để chọn kỳ MẶC ĐỊNH lúc ghi log
      mới, không nên tự nhảy vào kỳ lưu trữ), khiến vụ án cũ nhập lại qua Import Excel (mẫu "Danh
      sách án", gán vào kỳ lưu trữ) hoặc gán tay vào kỳ lưu trữ không lọc riêng ra xem được ở đây.
      Đã bỏ điều kiện lọc đó — danh sách kỳ giờ gồm đầy đủ, kỳ lưu trữ hiện nhãn `" [Lưu trữ]"`
      (đúng quy ước nhãn đã dùng ở `ModalXacNhanKy`/`SuaKyModal`). Thêm ô **tìm kiếm tự do**
      (`tuKhoa`, đặt cạnh dropdown lọc kỳ) khớp đồng thời mã vụ/tên vụ/điều luật (dùng làm proxy
      tội danh — field `dieuLuat` ở cấp `vuan` đã gộp từ bị can theo nguyên tắc thiết kế #7, module
      này không query thêm `bican` nên không tra được tội danh gốc từng bị can) /KSV chính/KSV hỗ
      trợ/ghi chú — cùng pattern với ô tìm kiếm đã có ở module Danh sách vụ án (`DanhSachVuAnModule`,
      dòng ~3899-3913), lọc qua `useMemo` kết hợp với lọc kỳ hiện có, không thêm query Firestore
      mới (lọc trên `list` đã tải sẵn theo `hinhThuc`). **Thêm 4 cột + tìm theo Số QĐ KTVA
      (2026-07-14)** — bảng giờ có thêm **Số QĐ KTVA**/**Ngày KTVA** (đọc thẳng `v.soQdKtva`/
      `v.ngayQdKtva` có sẵn trên `vuan`) và **Số QĐ giải quyết**/**Ngày giải quyết** (cột "Ngày
      quyết định" cũ đổi tên hiển thị thành "Ngày giải quyết", cùng 1 dữ liệu `v.ngayQuyetDinh`).
      "Số QĐ giải quyết" cần field mới trên `vuan` vì trước đây **chỉ "Đã xét xử" có field riêng
      trên `vuan`** (`soBanAn`, set qua `fieldSoQuyetDinhTrenVuAn`) — 4 hình thức còn lại
      (Chuyển đi/Tạm đình chỉ/Đình chỉ/Án huỷ) chỉ lưu "Số QĐ" trên sự kiện log, không có trên
      `vuan`, nên không đọc thẳng được như cột trong bảng này cần (đọc thẳng `vuan`, không query
      log — xem lý do ở đầu module). Đã tổng quát hoá `fieldSoQuyetDinhTrenVuAn`/thêm hằng
      `FIELD_SO_QD_HOAN_THANH` để **cả 5 hình thức đều có field riêng trên `vuan`**
      (`soBanAn`/`soQuyetDinhChuyenDi`/`soQuyetDinhTamDinhChi`/`soQuyetDinhDinhChi`/
      `soQuyetDinhAnHuy`) — `HoanThanhVuAnModal` và `ImportExcelModule` đều dùng chung hàm này nên
      tự động ghi đúng field cho mọi hình thức từ nay về sau, không cần sửa gì thêm ở 2 nơi đó.
      **Vụ đã hoàn thành TRƯỚC ngày sửa này** (mọi hình thức trừ Đã xét xử) sẽ không có field mới
      → cột "Số QĐ giải quyết" hiện "—", vẫn tra được qua cột "Số QĐ" ở bảng Lịch sử (Nhật ký thao
      tác) của vụ đó như trước — chưa có công cụ backfill hàng loạt cho việc này, nếu cần thì làm
      tương tự cách backfill `ngayQuyetDinh`/`kyHoanThanh` đã có ("Cập nhật index" ở module Cài
      đặt). Ô tìm kiếm tự do thêm khớp `v.soQdKtva`.
- [x] Module Kỳ báo cáo (mở kỳ mới có chặn trùng kỳ đang mở, chốt kỳ tự snapshot tồn cuối kỳ
      theo từng cơ quan vào `tonCuoiKy`). **Có nhãn "🚧 Đang xây dựng" cạnh tiêu đề (2026-07-14)**
      — do B10 vẫn đang trong quá trình sửa/kiểm chứng số liệu (xem mục "Trạng thái Biểu B10" ở
      đầu file), nhắc người dùng số liệu module này có thể còn thay đổi; gỡ nhãn này khi thấy đã
      ổn định. Bấm vào 1 dòng kỳ mở ra **báo cáo chi tiết theo giai
      đoạn** (`KyChiTietModal`/`tinhBaoCaoKy`): tồn đầu kỳ (lấy từ `tonCuoiKy` của kỳ liền
      trước) + số mới + đã giải quyết + tồn cuối kỳ + số vụ/số bị can đang tồn hiện tại — luôn
      tính trực tiếp từ `lichsuChuyenGiaiDoan` theo đúng nguyên tắc "log là nguồn sự thật duy
      nhất", không suy ra từ trạng thái hiện tại. Lưu ý: sự kiện `hoan_thanh` không lưu
      `tuGiaiDoan`, nên hàm dùng `coQuanThuLy` hiện tại của vụ làm proxy xác định đã hoàn thành
      từ giai đoạn nào — an toàn vì hệ thống không đổi `coQuanThuLy` sau khi vụ đã hoàn thành.
      **Công thức "số mới" đã sửa lại (2026-07-11), áp dụng THỐNG NHẤT cho cả 3 giai đoạn** —
      trước đó Điều tra được code riêng (gán mọi sự kiện `khoi_to_vu` vào Điều tra bất kể vụ
      khởi tạo trực tiếp ở giai đoạn nào, và thiếu hẳn "trả về từ giai đoạn sau"), khiến
      `tồn đầu kỳ + mới − giải quyết ≠ tồn cuối kỳ`. Công thức đúng: mới ở 1 giai đoạn = khởi tố
      trực tiếp vào đúng giai đoạn đó (`khoi_to_vu` có `denGiaiDoan` trùng — vụ nhập tay/import
      có thể vào thẳng Truy tố/Xét xử) + **vụ tách ra** (`tach_vu` có `denGiaiDoan` trùng — 1
      bản ghi `vuan` mới xuất hiện ở giai đoạn vụ gốc đang ở lúc tách, PHẢI tính "vào" thì mới
      khớp với việc nó bị tính "ra" nếu giải quyết luôn trong kỳ) + chuyển đến từ giai đoạn trước
      (`chuyen_giai_doan`, không áp dụng cho Điều tra) + trả về từ giai đoạn sau (`tra_ho_so`, CÓ
      áp dụng cho Điều tra — viện trả hồ sơ điều tra bổ sung). Cả `khoi_to_vu` và `tach_vu` đều
      ghi `denGiaiDoan` ngay lúc tạo (`ThemVuAnForm`, `dungLaiLichSu`, `tachVuAn`'s callers) — dữ
      liệu cũ tạo trước ngày sửa không có field này (`null`), đã chạy script backfill 1 lần tính
      lại từ lịch sử chuyển giai đoạn thật của từng vụ (không backfill lại nếu import dữ liệu cũ
      lần nữa thì nhớ set `denGiaiDoan` ngay từ đầu, đừng lặp lại lỗi này). Ngoài `hoan_thanh`,
      vụ bị **nhập vào vụ khác** (`nhap_vu`, `trangThai` → `da_nhap`) cũng RA KHỎI "tồn" và phải
      tính vào "Đã giải quyết / ra khỏi giai đoạn" (`soNhapVu`, dòng "— Nhập vào vụ khác") —
      dùng cùng kiểu proxy `coQuanThuLy` hiện tại như `hoan_thanh`, cùng lý do (không đổi sau khi
      nhập). Thiếu khoản này thì công thức lệch y hệt kiểu lỗi tách vụ đã sửa ở trên.
      **Lưu sẵn báo cáo kỳ đã chốt (2026-07-11)** — trước đây MỖI LẦN bấm xem 1 kỳ (kể cả kỳ đã
      chốt từ lâu, số liệu không đổi) đều quét lại toàn bộ `lichsuChuyenGiaiDoan` (hàng chục
      query + đọc từng doc `vuan` cho mỗi dòng danh sách), rất chậm và tốn Firestore read không
      cần thiết — người dùng yêu cầu lưu lại kết quả. Hàm tính đầy đủ đổi tên thành
      `tinhBaoCaoKyTuLog` (logic không đổi); `tinhBaoCaoKy` (hàm nơi hiển thị gọi) giờ là wrapper:
      kỳ **đã chốt VÀ có `baoCaoLuu`** thì dùng lại thẳng `kybaocao.baoCaoLuu` (ghi lúc chốt qua
      `chotKyBaoCao`), chỉ tính LIVE lại phần "Số tồn hiện tại" (`soVuTon`/`soBiCanTon`/`dsTon`
      qua `tinhTonHienTaiTheoGD`) vì phần đó theo đúng thiết kế cũ luôn phải là số tại-thời-điểm-
      xem, không thuộc riêng về 1 kỳ nào. `tachBaoCaoLuu` tách phần "đông cứng" ra khỏi phần
      live trước khi lưu. Kỳ đang mở hoặc kỳ đã chốt trước khi có tính năng này (chưa có
      `baoCaoLuu`) vẫn tự tính đầy đủ như cũ, không bắt buộc backfill. Nút **"Tính lại số liệu"**
      (chỉ hiện với kỳ đã chốt, gọi `tinhLaiBaoCaoLuu`) cho phép tính lại và ghi đè `baoCaoLuu`
      khi cần — dùng khi có **"Sửa kỳ"** (xem Nhật ký thao tác) tác động tới sự kiện thuộc kỳ đã
      chốt đó, xem cảnh báo ở `SuaKyModal` bên dưới. **KHÔNG** đụng tới `tonCuoiKy`/`tonCuoiBiCan`/
      `tonCuoiKyTheoTD` khi tính lại (số "Còn" chốt là trạng thái `vuan` thật tại thời điểm chốt,
      độc lập với việc gán `kyThongKe` của từng sự kiện log nên "Sửa kỳ" không làm sai số này —
      chỉ làm sai các dòng "số mới"/"đã giải quyết" đếm theo `kyThongKe`).
      **Bug đã sửa (2026-07-13) — B10 hiện "tồn kỳ trước" = "tồn kỳ này"**: `tinhLaiBaoCaoLuu`
      từng VI PHẠM chính bất biến ở trên — nó có ghi đè `tonCuoiKyTheoTD`/`tonCuoiBiCan` (không
      chỉ `tonCuoiKy` mới được bảo vệ) bằng kết quả `tinhSnapTonTheoTD()`, hàm này luôn query
      **LIVE** trạng thái `vuan` **hiện tại lúc gọi**, không biết gì về thời điểm chốt lịch sử của
      kỳ đang tính lại. `chotKyBaoCao()` gọi đúng hàm này lúc CHỐT LẦN ĐẦU thì không sao (thời
      điểm gọi = thời điểm chốt); nhưng "Tính lại số liệu" có thể chạy rất lâu sau, khi live
      `vuan` đã trôi xa khỏi trạng thái lúc kỳ đó thực chốt — ghi đè biến `tonCuoiKyTheoTD` của kỳ
      CŨ thành ảnh chụp HIỆN TẠI. Biểu B10 (`tinhBieu10`, xem mục Xuất Excel Biểu B10 bên dưới)
      đọc "tồn kỳ trước" từ `kyTruoc.tonCuoiKyTheoTD` — nếu `kyTruoc` vừa bị "Tính lại" gần đây,
      cột "tồn kỳ trước" trùng y hệt "tồn kỳ này" dù 2 kỳ cách nhau cả tháng. Đã sửa: bỏ hẳn lệnh
      gọi `tinhSnapTonTheoTD()` khỏi `tinhLaiBaoCaoLuu`, hàm giờ CHỈ ghi `baoCaoLuu` +
      `thoiDiemTinhLai`. Kỳ nào đã bị "Tính lại" trước khi có bản sửa này thì `tonCuoiKyTheoTD`
      của kỳ đó ĐÃ BỊ CORRUPT (mang giá trị live tại thời điểm bấm tính lại, không phải lịch sử
      thật) — sửa code không tự phục hồi được dữ liệu đã ghi sai, chỉ chặn không cho sai thêm.
      **Công cụ sửa dữ liệu đã corrupt (2026-07-13, `taiTaoTonCuoiKyTheoTDTatCa` +
      `TaiTaoTonTheoTDTool`, nút "Sửa lại tồn cuối kỳ theo tội danh (Biểu B10)" trong Cài đặt →
      Import Excel)** — KHÔNG replay điểm-theo-thời-gian từng vụ (quá phức tạp/rủi ro cho báo cáo
      thống kê chính thức) mà dùng cách rẻ hơn nhiều, tái dùng khối xây dựng đã có sẵn và đã kiểm
      chứng: duyệt TẤT CẢ kỳ đã chốt theo thứ tự thời gian (bỏ qua kỳ lưu trữ), với mỗi kỳ K tính
      `tonCuoiKyTheoTD[K] = tonCuoiKyTheoTD[K-1] (đã tính đúng ở bước trước, kỳ đầu tiên = 0) + số
      mới theo tội danh trong K − số đã giải quyết theo tội danh trong K`, cả 2 vế lấy trực tiếp
      từ `tinhBaoCaoKyTuLog(K, ...).ds` (hàm đã lọc đúng theo `kyThongKe==K.id`, KHÔNG đụng gì tới
      `tonCuoiKyTheoTD` cũ nên tái dùng an toàn, không lặp lại lỗi gốc). Vì đi tuần tự theo lịch
      sử, kỳ nào cũng nhận giá trị đã được sửa đúng của kỳ liền trước, không còn phụ thuộc snapshot
      live nào nữa. Đối chiếu tổng theo giai đoạn của kết quả với `tonCuoiKy` (field KHÔNG BAO GIỜ
      bị ghi đè — neo tin cậy tuyệt đối) sau mỗi kỳ: lệch (VD do vụ có `kyThongKe: null` từ "Dựng
      lại lịch sử" cho dữ liệu import cũ, không được đếm vào "số mới" của kỳ nào) thì gom phần
      chênh vào tội danh `"(chưa xác định — chênh lệch dữ liệu cũ)"` để TỔNG luôn khớp con số tin
      cậy, thay vì âm thầm sai không dấu vết. Số âm bất thường (dữ liệu cũ thiếu khiến "đã giải
      quyết" tính ra nhiều hơn "đang có") bị chặn về 0 kèm cảnh báo, không cho lan sang kỳ sau.
      An toàn chạy lại nhiều lần (luôn tính lại từ đầu, không cộng dồn lên kết quả cũ). Đã kiểm
      chứng riêng phần toán tích luỹ + đối chiếu bằng test độc lập (4 kịch bản: kỳ đầu không lệch,
      kỳ giữa vẫn khớp, có vụ ẩn gây lệch dương được gộp đúng, số âm giả bị chặn đúng) trước khi
      viết vào code — phần phụ thuộc Firestore thật (`tinhBaoCaoKyTuLog`, fetch bị can...) chưa
      kiểm chứng bằng dữ liệu thật, cần chạy thử trên `qlva-dev.html` trước khi tin tưởng số liệu
      xuất ra từ nút này trên dữ liệu production.
      **Báo cáo tổng hợp nhiều kỳ (2026-07-11)** — tích chọn (checkbox) nhiều dòng kỳ rồi bấm
      "Xem báo cáo tổng hợp" (VD tích đủ 12 kỳ tháng ra báo cáo năm, đúng yêu cầu người dùng)
      → `TongHopNhieuKyModal`/`tinhBaoCaoTongHopNhieuKy`: gọi lại `tinhBaoCaoKy` cho TỪNG kỳ được
      chọn (nên kỳ đã chốt vẫn dùng cache, tổng hợp cả năm vẫn nhanh) rồi SUM các dòng số mới/đã
      giải quyết, ghép nối các mảng danh sách chi tiết; "Tồn đầu kỳ" lấy từ kỳ SỚM NHẤT được
      chọn, "Tồn cuối kỳ" lấy từ kỳ MUỘN NHẤT — chỉ đúng nghĩa nếu các kỳ chọn liên tiếp nhau,
      không ép buộc bằng code (không chặn chọn kỳ rời rạc), chỉ ghi chú nhắc trên UI. Bảng hiển
      thị dùng chung component `BangBaoCaoChiTiet` (đã tách ra từ `KyChiTietModal` để dùng lại ở
      đây — 2 nơi cùng nhận đúng 1 dạng dữ liệu `baoCao[gd]`), nút xuất Excel cũng dùng lại
      `xuatBaoCaoThangExcel` (chỉ cần field `tenKy` để đặt tên file cho phần thân báo cáo, không
      phụ thuộc gì khác từ `ky` nên tái dùng được thẳng cho báo cáo gộp — LƯU Ý claim này đã sai
      sót với riêng sheet Biểu B10, xem bug fix ngay dưới đây).
      **Bug đã sửa (2026-07-13) — B10 của báo cáo gộp luôn hiện "tồn kỳ trước" = 0**: lúc thêm
      Biểu B10 vào `xuatBaoCaoThangExcel` (nhận thêm tham số thứ 3 `kyTruoc`, xem mục Xuất Excel
      Biểu B10 bên dưới), nút xuất Excel của `TongHopNhieuKyModal` không được cập nhật theo — vẫn
      gọi `xuatBaoCaoThangExcel({tenKy}, baoCao)` thiếu hẳn tham số `kyTruoc`, khiến `tinhBieu10`
      nhận `kyTruoc = null` → mọi cột "tồn kỳ trước" trên B10 của báo cáo gộp luôn ra 0, sai với
      claim cũ "không phụ thuộc gì khác từ ky". Đã sửa: truyền thêm `dsKyChon[0]?.kyTruoc` (kỳ
      liền trước kỳ SỚM NHẤT trong nhóm chọn — đúng quy ước "Tồn đầu kỳ" mà bảng tổng hợp đã dùng
      ở trên) làm tham số thứ 3.
      **Sửa kỳ vào kỳ đã chốt (2026-07-11)** — `SuaKyModal` (module Nhật ký thao tác) giờ kiểm
      tra nếu kỳ CŨ hoặc kỳ MỚI của sự kiện đang sửa đã `da_chot`, hiện cảnh báo đỏ giải thích
      báo cáo đã lưu (`baoCaoLuu`) của kỳ đó sẽ không tự cập nhật, và bắt tick ô "Tôi hiểu và vẫn
      muốn sửa" mới cho bấm Lưu (không chặn hẳn — sửa sai sót sau khi chốt vẫn là nhu cầu hợp lệ,
      chỉ đảm bảo người dùng biết cần vào Kỳ báo cáo bấm "Tính lại số liệu" sau đó).
- [x] **Xuất Excel báo cáo tháng** (nút "Xuất Excel báo cáo tháng" trong `KyChiTietModal`, hàm
      `xuatBaoCaoThangExcel`, **dùng ExcelJS** qua CDN riêng — không dùng `XLSX`/SheetJS như phần
      xuất Excel khác trong app, vì bản SheetJS CDN đang dùng ở đây là bản miễn phí KHÔNG ghi
      được style dù có set `cell.s`/`cellStyles:true` — đã kiểm chứng bằng cách giải nén file
      `.xlsx` xuất ra xem `cellXfs` luôn rỗng. ExcelJS ghi style thật, dùng cho **wrap text mặc
      định trên mọi ô** của báo cáo tháng cho dễ đọc, xem hàm `themSheetDanhSach`) — **~45 sheet
      (2026-07-13/14: tái cấu trúc thành 1 sheet/loại sự kiện/giai đoạn, sau đó bổ sung thêm để
      kiểm chứng chéo được)**: Biểu B10 + TK tội danh + Tổng hợp báo cáo + **Cân đối số liệu**,
      sau đó cho mỗi giai đoạn ĐT/TT/XX: DS khởi tố, DS phục hồi, DS vụ tách, DS chuyển đến
      (TT/XX), DS trả về (ĐT/TT), DS đã xét xử, DS chuyển đi, DS tạm đình chỉ, DS đình chỉ, DS án
      huỷ, DS nhập vụ, DS tồn — cộng thêm **4 sheet RA** nhìn từ giai đoạn nguồn (DS ĐT chuyển TT/
      DS TT chuyển XX/DS TT trả ĐT/DS XX trả TT — cùng dữ liệu với DS chuyển đến/DS trả về của
      giai đoạn NHẬN, chỉ đổi nhãn sang góc nhìn giai đoạn nguồn, để mỗi giai đoạn tự cân đối được
      Vào/Ra của riêng nó). Không còn "DS mới" gộp chung hay "DS giải quyết" gộp chung — mỗi loại
      là 1 sheet riêng, đếm rows của sheet = số liệu của loại đó, giúp kiểm chứng từng con số trên
      sheet Tổng hợp bằng cách đếm trực tiếp trên sheet con.
      Helper nội bộ `addSheetVu(tenSheet, vuArr, extraHeaders, extraFn)` (mọi sheet danh sách có
      cột **"Đếm vụ"** đầu tiên — 1 vụ N bị can = N rows, cột này = 1 ở row BC đầu tiên của mỗi vụ
      và rỗng ở các row sau, nên phải `SUM(cột Đếm vụ)` để đếm số vụ, KHÔNG dùng `COUNTA` toàn
      sheet) và `addSheetVuKy` (bọc thêm cột **"Kỳ TK"** đầu tiên — tên kỳ báo cáo của sự kiện qua
      `tenKyBaoCao()`, áp dụng cho mọi sheet DS vào/ra, KHÔNG áp dụng cho DS tồn vì đó là số live
      không gắn với 1 kỳ). Toàn bộ danh sách dựng từ CHÍNH object `baoCao` mà `tinhBaoCaoKy` đã
      trả về (field `ds` trong mỗi `baoCao[gd]`, thu thập song song lúc tính số liệu qua
      `vuAnTuLogDocs`) — không tính lại riêng — nên số dòng mỗi sheet danh sách LUÔN khớp đúng số
      trên sheet Tổng hợp và trên báo cáo đang xem trên màn hình. Nếu sửa công thức
      `tinhBaoCaoKy` sau này, nhớ cập nhật đồng bộ cả phần `ds` tương ứng, đừng để 2 bên lệch
      nhau. Sheet **"Biểu B10"** có thêm cột ẩn/nhạt **"Mã ĐL"** (điều luật chính chuẩn hoá, dùng
      làm khoá tra cứu) — nhiều cột "Vụ" của B10 dùng công thức Excel `SUMIF` tham chiếu ngược lại
      các sheet danh sách theo cột "Mã ĐL vụ" (thay vì chỉ ghi giá trị JS tĩnh), để người xem có
      thể click-trace trong Excel từ B10 ra đúng danh sách vụ đã cộng vào ô đó. Sheet **"Cân đối
      số liệu"** dùng công thức Excel `SUM` tự kiểm: `Tồn đầu + Σ(DS vào) − Σ(DS ra) = Tồn cuối
      (chốt)` cho mỗi giai đoạn, tô xanh nếu chênh lệch = 0, đỏ nếu ≠ 0 (dấu hiệu có sự kiện log
      với `kyThongKe = null`, thường do dữ liệu cũ dựng lại lịch sử — xem `DungLaiLichSuTool`).
      **Sheet "Tổng hợp báo cáo" — thêm cột BC + hết phụ thuộc số JS xuất thẳng từ hệ thống
      (2026-07-15)** — trước đây mỗi giai đoạn chỉ 1 cột (chỉ có số Vụ, không dòng nào có tổng Bị
      can trừ riêng khối "Tồn" tách thành 2 HÀNG "— Vụ"/"— Bị can"), và nhiều dòng ("Án khởi tố
      mới", "Tin báo khởi tố lên", "Án nơi khác chuyển đến", "Số tồn hiện tại"...) đọc thẳng số JS
      từ `baoCao` dù ĐÃ có DS sheet tương ứng chứa đủ dữ liệu để tính ra cùng con số bằng công
      thức Excel — nghĩa là những dòng đó không tự kiểm chứng được, khác triết lý "công thức Excel"
      áp dụng cho B10/TK tội danh. Đã đổi cấu trúc cột thành **7 cột**: nhãn + `ĐT-Vụ/ĐT-BC/TT-Vụ/
      TT-BC/XX-Vụ/XX-BC` (mỗi giai đoạn 2 cột thay vì 1), và chuyển MỌI ô có DS sheet tương ứng
      sang công thức `SUM`/`COUNTIF`/`COUNTIFS`/`SUMIF` — cột BC đếm bị can THẬT trong sheet qua
      `COUNTIF(sheet!$M:$M,"<>(Chưa có BC)")` (cột M = Họ tên BC, loại trừ dòng giả của vụ 0 BC).
      Khối "Án khởi tố mới/Tin báo/Án nơi khác" lọc thêm theo cột **"Nguồn"** (cột AH của sheet
      "DS khởi tố {gs}", xem `addSheetVuKy`) qua `SUMIF`/`COUNTIF(S)`. **Chỉ còn 2 cặp dòng KHÔNG
      sheet-hoá được** vì bản chất là snapshot tại 1 thời điểm chốt kỳ (không phải danh sách sự
      kiện của kỳ này để đếm lại): "Tồn đầu kỳ" (snapshot `tonCuoiKy`/`tonCuoiBiCan` của KỲ TRƯỚC)
      và "Tồn cuối kỳ" (snapshot của CHÍNH kỳ này) — nhãn dòng đã ghi rõ "(snapshot chốt kỳ
      trước/này)" để không ai tưởng nhầm là thiếu sót. Riêng "Số tồn hiện tại" KHÔNG phải snapshot
      (luôn tính live) nên ĐÃ chuyển sang công thức qua sheet "DS tồn {gs}" có sẵn — trước đây bị
      bỏ sót dù sheet đã tồn tại.
      **Cột BC của khối ĐT "mới" áp dụng đúng nguyên tắc lọc theo kỳ vừa sửa ở B10 (xem "Trạng
      thái Biểu B10" đầu file)** — Điều tra là giai đoạn DUY NHẤT bị can có thể được "Thêm bị can"
      bổ sung vào 1 vụ đã có sẵn ở kỳ SAU kỳ vụ được mở, nên các dòng Án khởi tố mới/Tin báo/Án
      nơi khác/Phục hồi điều tra/Khởi tạo trực tiếp/Tổng số mới ở CỘT ĐT dùng `demBcSheetKy`
      (COUNTIFS theo cột "Kỳ TK BC" khớp đúng kỳ đang tính, dùng chung `bcKyKhoiToMap`/
      `kyIdSetTrongBaoCao`/`dsKyTenTrongBaoCao` đã thêm cho B10) — cột TT/XX của CÙNG các dòng đó
      dùng `demBcSheetM` thường (đếm mọi BC trong sheet, không lọc kỳ), đúng như B10 chưa từng lọc
      loaiKhoiTo cho khối TT/XX. Đã viết test độc lập cho toàn bộ formula helper mới trước khi
      mirror sang `qlva-dev.html` — CHƯA kiểm chứng bằng dữ liệu Firestore thật.
      **Biểu B10 vẫn còn 1 nhóm ô chưa sheet-hoá được audit nhưng CHƯA sửa** (out of scope đợt
      này, cần quyết định riêng nếu muốn làm tiếp) — 2 loại: (1) "Tồn kỳ trước"/"Tồn kỳ này" (vals
      index 0-3, 34-37, 65-68) — snapshot, giống lý do "Tồn đầu/cuối kỳ" ở Tổng hợp báo cáo, không
      sheet-hoá được; (2) "Tổng thụ lý" C3/C4/C33/C34/C60/C61 (vals index 4,5,34,35,65,66... — số
      thực ra là phép cộng/trừ CÁC CỘT B10 KHÁC trong CÙNG dòng, VD C3 = tồn trước + C6 − nhập vụ
      − chuyển đi − án huỷ) — về lý thuyết có thể viết thành công thức Excel tham chiếu chéo cột
      trong cùng 1 dòng (không cần DS sheet mới), nhưng chưa làm vì cần rà soát cẩn thận việc ánh
      xạ từng thành phần C3 sang đúng cột vals[] khác trong cùng hàng, quy mô tương đương lần sửa
      B10 gốc — nếu cần, hỏi lại rõ trước khi làm để tránh sai sót trên báo cáo chính thức.
- [x] Module Dashboard (thẻ số liệu tồn hiện tại, bảng cảnh báo sắp hết hạn, biểu đồ cột chồng
      xu hướng theo kỳ dùng Chart.js — script CDN đã thêm vào `<head>`).
- [x] Module Nhật ký thao tác (feed toàn hệ thống, lọc theo loại sự kiện, giới hạn 300 dòng
      gần nhất — có ghi rõ giới hạn trên UI, không cắt âm thầm). **Sửa kỳ báo cáo cho từng sự
      kiện** (2026-07-11) — trước đây nguyên tắc thiết kế #3 đã nói log "sửa được sau, có audit
      trail `lichSuSuaKy`" nhưng chưa từng có UI thật sự để làm việc đó, field `lichSuSuaKy` chỉ
      là mảng rỗng mặc định không ai ghi vào. Nay có cột **"Kỳ"** hiển thị tên kỳ của từng sự
      kiện (bấm tiêu đề để sort theo thời gian thực của kỳ — dùng `ngayBatDau` của `kybaocao`
      làm giá trị so sánh, KHÔNG sort theo chuỗi tên "Tháng N/YYYY" vì sai thứ tự y hệt lý do đã
      né ở cột Kỳ mới/Kỳ giải quyết của Danh sách vụ án) + bộ lọc riêng theo kỳ (gồm cả lựa chọn
      "Chưa gán kỳ") để tìm nhanh các sự kiện cần chỉnh. Nút **"Sửa kỳ"** trên mỗi dòng (trừ
      `giao_nhan_ho_so` — loại này cố ý không tham gia số liệu theo kỳ nên không cho gán) mở
      `SuaKyModal`: đổi `kyThongKe` của đúng 1 sự kiện, đồng thời `arrayUnion` 1 phần tử vào
      `lichSuSuaKy` (`tuKy`/`denKy`/`lyDo`/`nguoiThucHien`/`thoiDiem`) để giữ vết ai sửa từ kỳ
      nào sang kỳ nào — hiện ngay trong modal ở lần mở sau. Sửa kỳ ở đây tác động trực tiếp tới
      số liệu báo cáo kỳ (Kỳ báo cáo/Dashboard/Xuất Excel đều tính từ `kyThongKe` của
      `lichsuChuyenGiaiDoan`), nên chỉ áp dụng cho các loại sự kiện nghiệp vụ thật, không áp
      dụng cho log hành chính.
- [x] Xuất Excel (nút trong module Danh sách, SheetJS dựng lại DSAT/DSBCT/TỔNG HỢP từ dữ liệu
      hiện tại). **Đã rà soát lại (2026-07-11)** — không có file gốc để so khớp pixel-perfect
      (người dùng xác nhận không có sẵn), nhưng đã đối chiếu logic `xuatExcel` với layout DSAT/
      DSBCT gốc lúc đó và không phát hiện lỗi/lệch dữ liệu — số bị can tính live từ collection
      `bican` (không dùng field cache cũ), mọi field label đều tra đúng qua `NHAN_GIAI_DOAN`/
      `NHAN_TRANG_THAI`/`NHAN_NGUON`. Lưu ý **quan trọng, đừng hiểu nhầm**: đây LÀ bản xem/lưu trữ
      dễ đọc, KHÔNG phải bản mirror 1:1 của DSAT/DSBCT gốc — file gốc DSAT có nhiều cột cờ riêng
      (Điều tra/Truy tố/Xét xử đang thụ lý, tạm đình chỉ, đình chỉ, đã xét xử, án huỷ...) được
      `xuatExcel` GỘP LẠI thành 2 cột text đơn ("Cơ quan đang thụ lý"/"Trạng thái") cho dễ đọc
      trên màn hình — nên file xuất ra KHÔNG dùng để nhập ngược lại qua Import Excel được (cấu
      trúc cột hoàn toàn khác `parseWorkbookDanhSachAn`). **Cập nhật (2026-07-13)**: mẫu Import
      Excel đã đổi hẳn sang sheet "Danh sách án" (xem mục riêng), `parseWorkbook`/DSAT/DSBCT nói
      ở trên đã bị xoá khỏi code — đoạn này giữ lại làm lịch sử rà soát, KHÔNG còn đúng với code
      hiện tại; `xuatExcel` (module "Xuất Excel" trong Danh sách vụ án) vẫn KHÔNG tương thích để
      nhập ngược lại qua mẫu "Danh sách án" mới (cấu trúc cột khác hẳn). "Xuất Excel báo cáo
      tháng" ở Kỳ báo cáo (sheet DS mới/DS tồn..., cấu trúc `VU_H`/`BC_H`, xem mục riêng) GẦN với
      mẫu import mới hơn (cùng nguyên tắc 1 dòng/bị can, vụ 0 bị can vẫn 1 dòng) nhưng KHÔNG
      re-import thẳng được — vẫn thiếu các cột `parseWorkbookDanhSachAn` bắt buộc (Giai đoạn,
      Trạng thái, Nguồn, Số/Ngày QĐ KTVA, Ngày/Số quyết định) và thiếu cột Giới tính bên bị can,
      phải tự thêm các cột đó vào trước khi import lại.
      Nếu sau này có file gốc thật để so khớp pixel-perfect hoặc cần format xuất round-trip được,
      làm rõ với người dùng trước khi đổi cấu trúc cột.
- [x] Sinh mã QR + in A4 (nút "In mã QR" ở panel chi tiết, thư viện `qrcodejs` qua CDN — xem ghi
      chú hạ tầng bên dưới về vụ đổi thư viện). In qua `ReactDOM.createPortal` vào `#qr-print-root`
      (sibling của `#root`, khai báo sẵn trong `<body>`) — khi in, CSS `@media print` chỉ ẩn
      `#root` (`display:none`), không ẩn `#qr-print-root`, nên khối QR không bị nằm ngoài luồng
      của phần app đã ẩn. Nếu 2 vụ có `maNganhCap`, hiện thêm 1 mã QR mã ngành cấp bên trái mã QR
      mã vụ (component `KhoiQR` dùng chung).
- [x] **Số quyết định** (2026-07-11) — mọi modal hành động nghiệp vụ (Chuyển giai đoạn, Trả hồ sơ,
      Gia hạn điều tra, Hoàn thành vụ án, Phục hồi, Tách vụ án, Nhập vụ) đều có thêm 1 ô "Số quyết
      định" để cán bộ ghi số văn bản làm căn cứ, nhãn đổi theo ngữ cảnh: Chuyển giai đoạn Điều
      tra→Truy tố = "Số kết luận điều tra" (`nhanSoQuyetDinhChuyen`), Truy tố→Xét xử = "Số cáo
      trạng", Hoàn thành với hình thức Đã xét xử = "Số bản án" (map nhãn theo `hinhThuc` ở
      `NHAN_SO_QUYET_DINH_HOAN_THANH`), còn lại (Trả hồ sơ/Gia hạn/Phục hồi/Tách vụ/Nhập vụ) nhãn
      cố định mô tả đúng loại quyết định của hành động đó. Lưu 2 chỗ: (1) field `soQuyetDinh` trên
      chính sự kiện log (`taoSuKien`, mặc định `""`) — hiện ở cột **"Số QĐ"** mới trong bảng Lịch
      sử của `ChiTietPanel`; (2) RIÊNG với Chuyển giai đoạn và Hoàn thành/Đã xét xử, còn ghi thêm
      vào field cấp `vuan` (`soKetLuanDieuTra`/`soCaoTrang`/`soBanAn` — dùng
      `fieldSoQuyetDinhTrenVuAn(hinhThuc)` để tra field tương ứng) để tra cứu nhanh không cần lật
      lịch sử. Chỉ lưu số quyết định, KHÔNG bắt buộc nhập (không validate rỗng) — nhiều trường hợp
      cán bộ chưa có số ngay lúc thao tác, điền bổ sung sau qua sửa lịch sử nếu cần.

### Bố cục cuộn trang (đã xử lý, đừng lặp lại)
`AppShell`'s khung ngoài dùng `h-screen overflow-hidden` (KHÔNG phải `min-h-screen`) — bug cũ:
`min-h-screen` chỉ đặt chiều cao TỐI THIỂU, không chặn nội dung cao hơn viewport phát triển thêm,
nên khi 1 module có nội dung dài (ví dụ Danh sách vụ án nhiều dòng) sẽ đẩy toàn bộ trang cuộn
theo trình duyệt (`body` cuộn) thay vì chỉ cuộn bên trong bảng — kéo cả sidebar/tiêu đề/tab lọc/
panel chi tiết trôi mất theo. Với `h-screen`, `<main className="flex-1 p-8 overflow-auto">` mới
thực sự trở thành vùng cuộn giới hạn, và các panel con (`DanhSachPanel`, `ChiTietPanel`) tự cuộn
độc lập bên trong `overflow-auto` + `min-h-0` của chính chúng. Khi thêm module mới có nội dung
có thể dài, đảm bảo toàn bộ chuỗi cha (module → `AppShell` → `<main>`) giữ đúng pattern
`h-full`/`min-h-0`/`overflow-auto` ở đúng tầng cần cuộn, đừng để `overflow-auto` "chết" vì cha nó
dùng `min-h-*` thay vì `h-*`.

### Ghi chú hạ tầng quan trọng (đã xử lý, đừng lặp lại)
- Firestore **database** và **Security Rules** phải được khởi tạo thủ công qua Firebase
  Console — không có cách nào tạo qua REST API/API key công khai. Đã tạo xong; rules hiện tại
  cho phép `request.auth != null` đọc/ghi toàn bộ (không phân quyền theo vai trò).
- CDN `@babel/standalone` phải **ghim version cụ thể** (hiện tại `@7.25.6`) — bản không ghim
  version từng nhảy lên major 8.x không tương thích và làm trắng màn hình toàn bộ app.
- Firestore compat SDK bản đang dùng (10.12.2) **không hỗ trợ `.count()`** (aggregation query)
  — dùng `.get()` rồi lấy `.size` thay thế.
- Query `lichsuChuyenGiaiDoan` lọc theo `maVuAn` + sắp xếp `thoiDiemGhi` cần composite index
  (đã tạo). Nếu thêm query dạng where+orderBy khác field mới sau này, khả năng cũng cần index
  mới — kiểm tra console lỗi Firestore, nó luôn kèm link tạo index trực tiếp.
- CDN QR: package npm `qrcode` (dùng cho `InQRModal`) **không có bản build/UMD sẵn** trong các
  bản publish gần đây — đường dẫn cũ `qrcode@1.5.3/build/qrcode.min.js` trả về 404 (khiến
  `QRCode is not defined`, mã QR không hiện). Đã đổi sang thư viện `qrcodejs`
  (`cdnjs.cloudflare.com/ajax/libs/qrcodejs/1.0.0/qrcode.min.js`) — API khác hẳn: dùng
  `new QRCode(divElement, {text, width, height})` vẽ vào 1 `<div>` chứa canvas tự sinh, không
  phải `QRCode.toCanvas(canvas, text, cb)`. Nếu sau này đổi thư viện QR khác, nhớ kiểm tra CDN
  trả về đúng file JS (không phải 404/HTML) trước khi tin tưởng.
- In A4 (`InQRModal`) từng bị lỗi in ra nhiều trang giống nhau: CSS cũ dùng
  `body * { visibility: hidden }` để ẩn phần app khi in, nhưng `visibility:hidden` vẫn giữ
  nguyên chỗ trong layout — khi danh sách vụ án dài (nhiều dữ liệu), trình duyệt tính ra nhiều
  trang in dựa theo chiều cao ẩn đó, và khối QR (`position:fixed`) bị lặp lại trên mỗi trang.
  Đã sửa bằng `#root { display: none }` (bỏ hẳn khỏi layout) + render khung QR qua
  `ReactDOM.createPortal` vào `#qr-print-root` nằm ngoài `#root` — xem mục Tiến độ đã code ở
  trên. Nếu thêm màn hình in mới sau này, dùng lại đúng pattern này (portal ra ngoài `#root`),
  đừng quay lại kiểu `visibility:hidden`.
- **Offline persistence (2026-07-13, nhánh `offline-indexeddb`)** — bật `db.enablePersistence({
  synchronizeTabs: true })` ngay sau khi khởi tạo `db` (thẻ `<script>` thường, trước cả thẻ
  Babel). Firestore compat SDK tự dùng **IndexedDB** làm cache nội bộ — không phải code tự viết
  tầng lưu trữ riêng. Phạm vi CÓ CHỦ Ý giới hạn: chỉ chống **mất mạng tạm thời trong lúc đang
  dùng** (wifi chập chờn, di chuyển giữa các phòng...) — app tiếp tục đọc dữ liệu đã cache, xếp
  hàng các ghi/sửa/xoá, tự đồng bộ khi có mạng lại. **KHÔNG** phải chế độ hoạt động hoàn toàn
  không cần Internet — trang vẫn cần mạng ở lần tải đầu (và mỗi lần load lại) để lấy các thư viện
  CDN (React/Babel/Tailwind/Firebase SDK...) và đăng nhập; một máy CHƯA TỪNG có mạng thì không mở
  được app, và không đồng bộ được với người dùng khác (Firestore cần mạng để nói chuyện với
  server — đã hỏi rõ người dùng, xác nhận chỉ cần chống rớt mạng tạm thời, KHÔNG cần máy hoàn
  toàn air-gapped — nếu sau này có yêu cầu air-gapped thật, đó là 1 tính năng khác hẳn, cần bundle
  thư viện CDN inline + tách hẳn 1 chế độ dữ liệu cục bộ, đừng nhầm với mục này).
  `OfflineBanner`/`useOnline` (component trong `AppShell`) dùng `navigator.onLine` + sự kiện
  `online`/`offline` của trình duyệt để hiện banner cảnh báo màu vàng cố định đầu trang khi mất
  mạng — tín hiệu này không chính xác 100% (có thể báo "online" dù mạng không thật sự ra được
  Internet) nhưng đủ dùng, không cần ping thật. Banner dùng `fixed` (không chiếm chỗ trong luồng
  layout) để không phá khung `h-screen`/`overflow-auto` đã ghim cẩn thận — xem mục "Bố cục cuộn
  trang" bên dưới, đừng đổi banner này sang layout tĩnh (static/relative).

## Chạy & phát triển

Không có bước build, không có test/lint tự động, không có `package.json` — đây là chủ đích
(xem "Yêu cầu bắt buộc" ở trên), không phải thiếu sót cần bổ sung tooling. Cách kiểm tra thay
đổi: mở trực tiếp `qlva.html` bằng trình duyệt (double-click hoặc `file://`), đăng nhập bằng
tài khoản Firebase Auth thật của project `qlahsp2`. Nếu `file://` gặp lỗi CORS/console im lặng
không tải được, phục vụ qua server tĩnh cục bộ đơn giản (VD `python -m http.server 8765` rồi mở
`http://localhost:8765/qlva.html`) — không cần build, chỉ là HTTP server thô. Babel standalone
compile JSX ngay trong trình duyệt lúc tải trang, nên lỗi cú pháp JSX sẽ hiện ở console (F12),
không có bước biên dịch riêng để bắt lỗi trước.

**Cheat-sheet lệnh hay dùng** (luôn test trên `qlva-dev.html`/project `qlahs-test` trước, đừng
chạy thẳng lên `qlva.html`/production):

```bash
# Mở app cục bộ để test (chọn 1 trong 2)
#   - double-click qlva-dev.html trong File Explorer, HOẶC:
python -m http.server 8765        # rồi mở http://localhost:8765/qlva-dev.html

# Deploy (Bash, dùng chung với deploy.bat mà Dũng double-click trên Windows)
./deploy.sh test                  # đưa lên https://qlahs-test.web.app
./deploy.sh prod                  # đưa lên https://qlahsp2.web.app (dữ liệu thật)
./deploy.sh all                   # test trước, rồi prod

# Deploy riêng Firestore rules/index (không đụng tới hosting)
firebase deploy --only firestore:rules --project test   # hoặc --project prod
firebase deploy --only firestore:indexes --project test # hoặc --project prod
```

## Môi trường dev/test & công cụ hỗ trợ

- **`README.md`** — hướng dẫn nhanh viết cho Dũng (không phải lập trình viên): cách mở app bằng
  double-click, cách deploy qua `deploy.bat`, link production/test. Không lặp lại nội dung đó ở
  đây, chỉ tham khảo nếu cần trả lời câu hỏi kiểu "làm sao để xem thay đổi trên mạng".
- **`mo_qlva.bat`** — launcher Dũng double-click để mở phiên làm việc với Claude Code: tự `git
  pull` rồi chạy `claude "/init"`. Nghĩa là `/init` có thể được gọi lại ở ĐẦU MỖI PHIÊN làm việc,
  không chỉ 1 lần khi khởi tạo repo — khi việc này xảy ra, chỉ nên **bổ sung/tinh chỉnh** file này
  (như đang làm), đừng viết lại toàn bộ hay xoá mất lịch sử quyết định nghiệp vụ đã ghi ở trên.
- **`qlva-dev.html`** — bản sao gần như y hệt `qlva.html`, chỉ khác `firebaseConfig` trỏ sang
  project Firebase riêng **`qlahs-test`** (thay vì `qlahsp2` production). Dùng để thử tính năng
  mới/thao tác phá hoại (xoá, seed dữ liệu giả) mà không đụng dữ liệu thật. Khi sửa `qlva.html`,
  nhớ áp lại thay đổi tương ứng vào `qlva-dev.html` nếu muốn test trên project `qlahs-test` (2
  file không tự đồng bộ, không có build step nào gộp chúng lại — xem "Deploy lên Firebase
  Hosting" bên dưới, `deploy.sh`/`deploy.bat` cũng không tự đồng bộ code, chỉ tự đồng bộ việc
  đưa 2 file này lên đúng chỗ deploy).
- **`seed-tool.html`** — công cụ độc lập (không phải module trong `qlva.html`) để seed dữ liệu
  test hàng loạt hoặc xoá sạch collection, kết nối được tới **cả 2 project** (`qlahsp2` production
  VÀ `qlahs-test`, chọn qua UI). Có hàm `xoaProd()` xoá dữ liệu trên project **production** — mở
  file này cẩn thận, xác nhận đang thao tác đúng project trước khi bấm nút xoá/seed. **Không host
  công khai file này** — xem "Deploy lên Firebase Hosting" bên dưới.
- **`firebase.json`** / **`firestore.indexes.json`** / **`firestore.rules`** — config Firebase
  CLI dùng chung cho cả 2 project khi deploy qua `firebase deploy --only firestore:rules` hoặc
  `--only firestore:indexes` (cần `firebase use <project-id>` trước để chọn đích, hoặc dùng alias
  `prod`/`test` đã khai trong `.firebaserc`). Rules hiện tại chỉ chặn theo `request.auth != null`
  (đã đăng nhập là đọc/ghi được toàn bộ), không phân quyền theo vai trò — xem ghi chú ở mục hạ
  tầng bên dưới. `firebase.json` còn có mục `hosting` (mảng 2 target `prod`/`test`) — xem ngay
  dưới đây.

## Deploy lên Firebase Hosting (2026-07-14)

App được host công khai qua Firebase Hosting, tách biệt 2 project như đã có sẵn cho Firestore ở
trên: **production** (`qlahsp2`) tại **https://qlahsp2.web.app**, và **test** (`qlahs-test`) tại
**https://qlahs-test.web.app**.

**KHÔNG host thẳng thư mục gốc repo** — `seed-tool.html` (có hàm xoá sạch dữ liệu production) và
tài liệu nội bộ (`CLAUDE.md`, `schema_csdl_...md`) sẽ bị lộ công khai qua URL nếu làm vậy. Thay
vào đó dùng 2 thư mục riêng, mỗi thư mục CHỈ chứa đúng 1 file `index.html` — bản sao của app:
- `public-prod/index.html` = bản sao `qlva.html` (trỏ Firebase config production `qlahsp2`)
- `public-test/index.html` = bản sao `qlva-dev.html` (trỏ Firebase config test `qlahs-test`)

Cấu hình 2 hosting target trong `firebase.json` (mảng `hosting`, mỗi phần tử 1 `target`) +
`.firebaserc` (mục `targets` ánh xạ target → project + site, mục `projects` đặt alias `prod`/
`test` để deploy bằng `--project prod`/`--project test` thay vì gõ project ID đầy đủ).

**2 thư mục `public-prod`/`public-test` là bản sao TĨNH sinh ra lúc deploy, KHÔNG commit vào git**
(nằm trong `.gitignore` — tự tạo lại từ `qlva.html`/`qlva-dev.html` mỗi lần chạy script, tránh
commit 2 bản sao ~500KB trùng lặp rồi bị lệch ngay khi sửa file gốc). Dùng script có sẵn thay vì
làm tay từng bước, script tự `mkdir` thư mục nếu chưa có (VD sau khi clone lại repo):
- **`deploy.sh`** (chạy qua Git Bash/terminal, ví dụ Claude Code dùng lệnh này) — `./deploy.sh
  test` / `./deploy.sh prod` / `./deploy.sh all` (all = test trước, production sau). Tự copy đúng
  file nguồn vào đúng thư mục `public-*` rồi gọi `firebase deploy --only hosting:<target>
  --project <alias>` tương ứng — không cần nhớ tên project/target/thư mục mỗi lần.
- **`deploy.bat`** (Dũng dùng — double-click chạy trực tiếp trên Windows, không cần gõ lệnh) —
  hiện menu chọn 1/2/3 (test / production / cả hai), riêng nhánh production bắt gõ `YES` xác nhận
  trước khi deploy vì đây là dữ liệu thật, mọi người đang dùng.

Nếu sau này đổi cấu trúc file (VD app tách thành nhiều file, không còn 1 file HTML duy nhất),
nhớ cập nhật lại logic copy trong cả 2 script, đừng để lệch nhau.

## Tài liệu & dữ liệu tham khảo chưa vào code (chưa commit, ở ngoài `qlva.html`)

Vài file gốc mới thêm vào thư mục, chưa được nhắc tới ở đâu khác trong file này — đọc để biết vì
sao chúng tồn tại trước khi động vào:

- **`bieu_B10_mo_ta.md`** — đặc tả chi tiết từng cột A–BT của Biểu B10 (tài liệu ngành), đối chiếu
  trực tiếp với `tinhBaoCaoKyTuLog`/`chotKyBaoCao`/`tinhTonHienTaiTheoGD` trong `qlva.html`. Đọc
  file này trước khi sửa bất kỳ công thức tính cột nào của B10 — xem thêm mục "Trạng thái Biểu
  B10" ở đầu file.
- **`B10 2025.xlsx`** — file mẫu Biểu B10 gốc của ngành (nguồn cho `bieu_B10_mo_ta.md` ở trên).
- **`danh_muc_toi_danh.js`** — bản sao/nháp của danh mục tội danh, KHÔNG PHẢI nguồn thật đang chạy
  — nguồn thật là hằng số `DANH_MUC_TOI_DANH_MAM` nhúng thẳng trong `qlva.html` (dòng ~527, module
  Danh mục tội danh dùng trực tiếp từ đó; file `.js` này không được `<script src>` nạp vào app).
  **Đang lệch nhau**: `qlva.html` đã cập nhật sang đánh số **BLHS 2025** (thêm field `soDieu`,
  `namBLHS:"2025"`), còn `danh_muc_toi_danh.js` vẫn còn nhãn `namBLHS:"2015"` cũ — có vẻ là bản
  nháp/backup trước khi cập nhật. Đừng copy ngược nội dung file này vào `qlva.html` mà không kiểm
  tra kỹ, sẽ làm mất bản cập nhật BLHS 2025.
- **`BLHS 1999.md`** / **`BLHS 2025.md`** — mục lục điều luật Bộ luật hình sự (trích từ file
  `.docx` gốc, chỉ có tên + số điều, không có nội dung điều luật đầy đủ), dùng để tra cứu/đối
  chiếu số điều khi cập nhật `DANH_MUC_TOI_DANH_MAM`. Tên file dễ gây nhầm — nội dung 2 file có số
  điều khác nhau đáng kể (VD "Điều 9 - Phân loại tội phạm" chỉ có ở 1 trong 2 bản) — đối chiếu kỹ
  đang cập nhật CHIỀU nào trước khi dùng làm căn cứ sửa mã tội danh, đừng suy đoán theo tên file.
- **`mo_qlva.bat`** — launcher Dũng dùng để mở Claude Code (double-click): tự `cd` vào đúng thư
  mục, `git pull` lấy bản mới nhất, rồi chạy `claude "/init"`. Đây là lý do lệnh `/init` được gọi
  lặp lại mỗi lần Dũng mở Claude Code — khi review CLAUDE.md do lệnh này kích hoạt, ưu tiên bổ
  sung/sửa nhỏ (file đã rất đầy đủ), đừng viết lại từ đầu làm mất lịch sử quyết định nghiệp vụ đã
  tích luỹ qua nhiều phiên làm việc.

## Kiến trúc code trong `qlva.html`

Toàn bộ code nằm trong 1 thẻ `<script type="text/babel">`, chia theo khối comment
`// ====== TÊN KHỐI ======` theo thứ tự: tiện ích dùng chung (parse ngày/số Excel) → từng màn
hình đăng nhập/module → khung chính `AppShell` → root `App`. Khi thêm module mới, theo đúng
pattern đã có:

1. Viết component module mới (ví dụ `DanhSachVuAnModule`) ở khối riêng, đặt trước `AppShell`.
2. Thêm 1 dòng vào mảng `MODULES` (đang ở ngay trên `AppShell`) với `ready: true`.
3. Thêm 1 nhánh `{tab === "id" && <ComponentMoi />}` trong `<main>` của `AppShell`.

`auth` và `db` (Firebase Auth/Firestore instance) là biến global khai báo ở thẻ `<script>` thường
phía trên (ngoài khối Babel) — mọi module dùng thẳng, không cần truyền qua props hay context.
Không có router: điều hướng module chỉ là state `tab` trong `AppShell`, không đổi URL.

`parseWorkbookDanhSachAn` (dùng bởi `ImportExcelModule`, xem mục "Import Excel — đổi hẳn sang mẫu
'Danh sách án'" ở Tiến độ đã code) đọc dữ liệu bằng **chỉ số cột cố định** (`r[0]`, `r[1]`...)
khớp đúng layout sheet `"Danh sách án"` (header ở dòng 1, dữ liệu từ dòng 2 — `range: 1` trong
`sheet_to_json`). Nếu sau này đổi cấu trúc cột của mẫu import, phải sửa lại các chỉ số này ở
`parseWorkbookDanhSachAn` VÀ cập nhật file mẫu `Mau_Import_DanhSachAn.xlsx` cho khớp.

## Mockup đã duyệt (mô tả bằng lời — không có file ảnh, tham khảo khi code UI)

- Danh sách vụ án: 2 cột — trái là thẻ danh sách lọc theo giai đoạn/KSV, phải là chi tiết vụ
  đang chọn (thông tin, nút chuyển giai đoạn/trả/đình chỉ/tách, danh sách bị can, lịch sử).
- Form thêm vụ án: bố cục ngang nhiều cột (không xếp chồng dọc), địa chỉ là textarea tự giãn,
  tội danh là danh sách nhiều dòng có nhãn "Tội chính"/"Bổ sung" + nút thêm dòng.
- Dashboard: thẻ số liệu (tồn từng giai đoạn) + bảng cảnh báo sắp hết hạn (đỏ/vàng) + biểu đồ
  cột chồng xu hướng theo kỳ.
- Trang in QR: A4, QR ~5x5cm chỉ chứa chuỗi mã vụ án thuần (tương thích hệ thống giao nhận hồ
  sơ PWA/Firebase khác đã có sẵn của người dùng — KHÔNG liên quan CSDL của dự án này, chỉ mượn
  format QR).

## Lưu ý khi tiếp tục code

- Không sửa lại các quyết định nghiệp vụ ở mục "Nguyên tắc thiết kế cốt lõi" trừ khi người dùng
  yêu cầu rõ ràng — đây là kết quả của nhiều vòng làm rõ nghiệp vụ thực tế với người dùng.
- File vẫn phải giữ nguyên tắc "1 file HTML", mọi thư viện qua CDN, không có bước build.
- Người dùng (Dũng) không phải lập trình viên — luôn giải thích bằng ngôn ngữ nghiệp vụ, không
  chỉ thuật ngữ kỹ thuật, khi hỏi lại hoặc báo tiến độ.
