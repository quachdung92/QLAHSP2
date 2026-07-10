# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

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

Tóm tắt nhanh 6 collection: `vuan`, `bican`, `lichsuChuyenGiaiDoan` (log sự kiện, append-only —
nguồn sự thật duy nhất để đếm số liệu theo kỳ), `kybaocao`, `canbo`, `boDemMaVu` (bộ đếm sinh mã).

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

- [x] `qlva.html`: đăng nhập Firebase Auth + khung sidebar (nay 7 module, xem `MODULES`) +
      **Import Excel** (đọc DSAT/DSBCT, xem trước, ghi Firestore bằng batch) + công cụ dựng
      lại lịch sử cho dữ liệu import cũ (xem mục riêng bên dưới).
- [x] Module Danh sách & chi tiết vụ án: 2 cột (danh sách dạng bảng lọc theo giai đoạn/KSV,
      đủ cột mã vụ/tên vụ/giai đoạn/trạng thái/hạn ĐT + menu hành động nhanh `⋯` mỗi dòng
      (Chuyển giai đoạn/Giải quyết) + chi tiết dạng bảng key-value kiểu Excel, có
      gridline/zebra-row/badge màu theo giai đoạn-trạng thái — xem
      `MAU_GIAI_DOAN`/`MAU_TRANG_THAI`/`Badge`), form **Thêm vụ án** (vụ + nhiều bị can trong 1
      form, tội danh nhiều dòng Tội chính/Bổ sung), sinh `maNoiSinh` tự động qua transaction,
      tự tính `dieuLuat`/`loaiKhoiTo`. Nút **Sửa thông tin vụ án** và **Sửa** trên từng dòng bị
      can (sửa lỗi nhập liệu thường — không ghi log, không hỏi kỳ, khác với các hành động
      nghiệp vụ). KSV/ĐTV vẫn là ô nhập tay nhưng có gợi ý (`<datalist>`) từ danh sách
      `canbo` — xem module Cán bộ bên dưới.
- [x] Module Cán bộ: thêm/sửa KSV, ĐTV, cán bộ thống kê (collection `canbo`). Các ô KSV
      chính/KSV hỗ trợ/ĐTV ở form Thêm vụ án và Sửa thông tin vụ án vẫn lưu **tên dạng chuỗi**
      (không phải ref cứng tới `canbo`) — lựa chọn có chủ đích để tương thích dữ liệu đã có
      sẵn (từ Import Excel và các vụ tạo trước khi có module này), `<datalist>` chỉ gợi ý.
- [x] Dựng lại lịch sử cho dữ liệu import cũ: nút "Dựng lại lịch sử" trong module Import Excel
      (`DungLaiLichSuTool`) — quét `vuan` chưa có dòng `lichsuChuyenGiaiDoan` nào, tự tạo 1 sự
      kiện `khoi_to_vu` + `khoi_to_bican` mỗi bị can theo dữ liệu hiện có. Idempotent (chạy
      lại không tạo trùng, vụ đã có log sẽ bị bỏ qua) nhưng KHÔNG dựng lại được các lần gia
      hạn/trả hồ sơ trước khi import — dữ liệu đó không còn lưu vết trong Excel gốc.
- [x] Các hành động nghiệp vụ trên 1 vụ án (nút ở panel chi tiết, đều qua `ModalXacNhanKy`
      dùng chung + hook `useHanhDongVuAn`): Chuyển giai đoạn, Trả hồ sơ, Gia hạn điều tra,
      Hoàn thành vụ án (gộp cả 5 hình thức da_xet_xu/chuyen_di/tam_dinh_chi/dinh_chi/an_huy —
      tự động tách vụ khi TĐC/ĐC chỉ áp dụng 1 phần bị can, xem hàm `tachVuAn`), Tách vụ án
      thủ công, Nhập vào vụ khác, Phục hồi (từ tạm đình chỉ).
- [x] Module Án tồn theo giai đoạn (3 tab lọc, cảnh báo màu đỏ/vàng theo hạn điều tra).
- [x] Module Kỳ báo cáo (mở kỳ mới có chặn trùng kỳ đang mở, chốt kỳ tự snapshot tồn cuối kỳ
      theo từng cơ quan vào `tonCuoiKy`).
- [x] Module Dashboard (thẻ số liệu tồn hiện tại, bảng cảnh báo sắp hết hạn, biểu đồ cột chồng
      xu hướng theo kỳ dùng Chart.js — script CDN đã thêm vào `<head>`).
- [x] Module Nhật ký thao tác (feed toàn hệ thống, lọc theo loại sự kiện, giới hạn 300 dòng
      gần nhất — có ghi rõ giới hạn trên UI, không cắt âm thầm).
- [x] Xuất Excel (nút trong module Danh sách, SheetJS dựng lại DSAT/DSBCT/TỔNG HỢP từ dữ liệu
      hiện tại) — **cần đối chiếu lại định dạng cột với file gốc**, đây là bản dựng hợp lý dựa
      theo mapping cột lúc import, chưa có file gốc để so khớp pixel-perfect.
- [x] Sinh mã QR + in A4 (nút "In mã QR" ở panel chi tiết, thư viện `qrcode` qua CDN, in qua
      CSS `@media print` ẩn hết phần còn lại của trang — xem `#qr-in-a4`).

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

## Chạy & phát triển

Không có bước build, không có test/lint tự động, không có `package.json` — đây là chủ đích
(xem "Yêu cầu bắt buộc" ở trên), không phải thiếu sót cần bổ sung tooling. Cách kiểm tra thay
đổi: mở trực tiếp `qlva.html` bằng trình duyệt (double-click hoặc `file://`), đăng nhập bằng
tài khoản Firebase Auth thật của project `qlahsp2`. Babel standalone compile JSX ngay trong
trình duyệt lúc tải trang, nên lỗi cú pháp JSX sẽ hiện ở console (F12), không có bước biên dịch
riêng để bắt lỗi trước.

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

`ImportExcelModule` đọc dữ liệu bằng **chỉ số cột cố định** (`r[0]`, `r[1]`...) khớp đúng layout
file Excel gốc (header ở dòng 2, dữ liệu từ dòng 3 — `range: 2` trong `sheet_to_json`). Nếu sau
này đổi cấu trúc cột của file Excel gốc, phải sửa lại các chỉ số này ở `parseWorkbook`.

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
