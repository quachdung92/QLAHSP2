# Schema CSDL — Hệ thống quản lý án (Firestore) — bản chốt

Thay thế hoàn toàn bản trước. Nguyên tắc xuyên suốt: **log (`lichsuChuyenGiaiDoan`) là nguồn sự thật duy nhất để đếm số liệu theo kỳ**; các field trạng thái trên `vuan`/`bican` chỉ phục vụ hiển thị "hiện đang ở đâu", không dùng để tính báo cáo.

---

## 1. `vuan` — Vụ án

Document ID = `maNoiSinh` (mã tự sinh, luôn có ngay khi tạo — xem mục 7). Mã ngành cấp có thể chưa có lúc tạo nên không dùng làm ID.

| Trường | Kiểu | Mặc định | Ghi chú |
|---|---|---|---|
| `maNoiSinh` | string | tự sinh | VD `QLVA_E01.53_2601_1456` — xem mục 7 |
| `maNganhCap` | string \| null | `null` | VD `VA_E01.53_2601_1456`, nhập tay khi ngành cấp mã về. **Ưu tiên hiển thị mã này nếu có**, ngược lại hiển thị `maNoiSinh` |
| `tenVu` | string | — | |
| `nguon` | enum | `an_khoi_to_moi` | `an_khoi_to_moi` / `tin_bao_khoi_to_len` / `an_noi_khac_chuyen_den` / `phuc_hoi_dieu_tra` |
| `nguonChiTiet` | string | `""` | chỉ khi `nguon = an_noi_khac_chuyen_den` |
| `hanDieuTra` | date | — | hạn **hiện hành** — mỗi lần gia hạn cập nhật field này, còn lịch sử gia hạn nằm ở log (mục 3) |
| `soQdKtva` / `ngayQdKtva` | string / date | — | |
| `ksvChinh` | ref → `canbo` | — | |
| `ksvHoTro` | array<ref → `canbo`> | `[]` | |
| `dtvCbdt` | ref → `canbo` \| string | `""` | điều tra viên/cán bộ điều tra |
| `donViThuLy` | string | `""` | VD "PC02", "Hà Đông"... |
| `dieuLuat` | string | — | Nếu vụ đã có ≥1 bị can: **tự tính**, gộp toàn bộ phần tử trong `toiDanh` (kể cả tội chính + tội bổ sung) của mọi bị can, loại trùng lặp, VD `"174; 318; 232"`, không cho sửa tay. Nếu vụ **chưa có bị can nào**: cho nhập tay trực tiếp. Field tự chuyển từ "nhập tay" sang "tự tính, khoá" ngay khi thêm bị can đầu tiên |
| `coQuanThuLy` | enum | `dieu_tra` | `dieu_tra` / `truy_to` / `xet_xu` |
| `trangThai` | enum | `dang_giai_quyet` | `dang_giai_quyet` / `da_xet_xu` / `an_huy` / `chuyen_di` / `tam_dinh_chi` / `dinh_chi` / `da_nhap` |
| `noiChuyenDen` | string | `""` | khi `trangThai = chuyen_di` |
| `nhapVaoVu` | ref → `vuan` \| null | `null` | khi `trangThai = da_nhap` — trỏ tới vụ đích |
| `vuGoc` | ref → `vuan` \| null | `null` | nếu vụ này được tách ra từ vụ khác |
| `anDiem` | boolean | `false` | án trọng điểm |
| `uyQuyenXetXu` | string | `""` | ghi khu vực/tối cao nếu có |
| `phienToaRutKN` | boolean | `false` | |
| `ghiChu` | string | `""` | |
| `ngayTao` / `nguoiTao` | date / ref → `canbo` | — | |
| `ngayCapNhat` / `nguoiCapNhatCuoi` | date / ref → `canbo` | — | |

**Bỏ hẳn** trạng thái ở cấp bị can — TĐC/ĐC không tồn tại độc lập theo bị can (xem mục 4).

---

## 2. `bican` — Bị can

| Trường | Kiểu | Mặc định | Ghi chú |
|---|---|---|---|
| `maVuAn` | ref → `vuan` | — | |
| `hoTen` | string | — | |
| `namSinh` | number | — | |
| `gioiTinh` | enum | `nam` | `nam` / `nu` |
| `toiDanh` | array<string> | `[""]` | mảng điều luật, **phần tử đầu = tội chính** (dùng tính thống kê), các phần tử sau là tội bổ sung nếu phạm nhiều tội |
| `dangVien` | enum | `khong` | `khong` / `co` |
| `diaChi` | string | `""` | |
| `bienPhapNganChan` | enum | — | `giam` / `tai_ngoai` |
| `hanTamGiam` | date \| null | `null` | ngày **hết hạn** tạm giam, chỉ khi `giam` |
| `danToc` | string | `"Kinh"` | tên dân tộc; `danTocThieuSo` (runtime, không lưu) = `danToc != "Kinh"` |
| `ngayKhoiTo` | date | — | |
| `loaiKhoiTo` | enum (tự tính) | — | `ban_dau` nếu = MIN(`ngayKhoiTo` cùng `maVuAn`), ngược lại `bo_sung` |
| `kyThongKeKhoiTo` | ref → `kybaocao` | — | gán qua modal xác nhận kỳ, sửa được sau (có audit) |

`nhomTuoi` tính runtime từ `YEAR(ngayKhoiTo) − namSinh`: `<14` cảnh báo, `14–15` → "14–16", `16–17` → "16–18", `≥18` → ">18".

---

## 3. `lichsuChuyenGiaiDoan` — Log sự kiện (append-only)

| Trường | Kiểu | Ghi chú |
|---|---|---|
| `maVuAn` | ref → `vuan` | |
| `loaiSuKien` | enum | xem danh sách đầy đủ bên dưới |
| `maBiCan` | ref → `bican` \| null | khi liên quan 1 bị can cụ thể (`khoi_to_bican`) |
| `tuGiaiDoan` / `denGiaiDoan` | enum \| null | khi `chuyen_giai_doan` / `tra_ho_so` |
| `hanCu` / `hanMoi` | date \| null | khi `gia_han_dieu_tra` |
| `hinhThucHoanThanh` | enum \| null | khi `hoan_thanh`: `da_xet_xu` / `chuyen_di` / `tam_dinh_chi` / `dinh_chi` / `an_huy` |
| `vuTachRa` | ref → `vuan` \| null | khi `tach_vu` |
| `lyDoTach` | enum \| null | khi `tach_vu`: `khac_toi_danh` / `de_tam_dinh_chi` / `de_dinh_chi` / `khac` |
| `vuNhapVao` | ref → `vuan` \| null | khi `nhap_vu` — vụ đích được gộp vào |
| `ngaySuKien` | date | ngày quyết định thực tế |
| `kyThongKe` | ref → `kybaocao` | mặc định = kỳ đang mở, chọn qua modal xác nhận |
| `lichSuSuaKy` | array<{kyCu, kyMoi, nguoiSua, thoiDiemSua}> | audit trail sửa kỳ sau này |
| `ghiChu` | string | |
| `nguoiThucHien` | ref → `canbo` | |
| `thoiDiemGhi` | timestamp | tự động |

**Danh sách đầy đủ `loaiSuKien`:**
`khoi_to_vu` · `khoi_to_bican` · `chuyen_giai_doan` · `tra_ho_so` · `gia_han_dieu_tra` · `phuc_hoi` · `ket_luan_dieu_tra` · `ket_luan_dieu_tra_bo_sung` · `cao_trang` · `cao_trang_bo_sung` · `hoan_thanh` · `tach_vu` · `nhap_vu`

---

## 4. Luồng nghiệp vụ đặc thù (quan trọng, dễ làm sai)

### Tạm đình chỉ / Đình chỉ — luôn gắn với tách vụ

TĐC/ĐC **không tồn tại độc lập theo bị can**. Khi bấm nút TĐC/ĐC trên 1 vụ:

1. Hiện danh sách bị can, cho chọn ai thuộc diện TĐC/ĐC.
2. **Chọn toàn bộ bị can của vụ** → áp `trangThai` thẳng lên vụ hiện tại. Không tách.
3. **Chỉ chọn 1 phần** → hệ thống tự chạy luồng tách vụ trước (sinh vụ mới, `vuGoc` trỏ vụ cũ, `lyDoTach = "de_tam_dinh_chi"` hoặc `"de_dinh_chi"`), rồi áp `trangThai` lên **vụ mới tách**, vụ gốc tiếp tục xử lý bình thường với các bị can còn lại.
4. Ghi 2 dòng log: 1 dòng `tach_vu` (nếu có tách) + 1 dòng `hoan_thanh` gắn với vụ (mới hoặc cũ tùy trường hợp).

### Phục hồi sau tạm đình chỉ, rồi nhập lại vụ gốc

Sự kiện `phuc_hoi`: đổi `trangThai` vụ (đã tách) từ `tam_dinh_chi` → `dang_giai_quyet`, giữ nguyên `coQuanThuLy` lúc tạm đình chỉ.

Nếu sau đó nhập lại vào vụ gốc: sự kiện `nhap_vu` — set `nhapVaoVu = vuGoc`, `trangThai = da_nhap` cho vụ vừa phục hồi, cập nhật `maVuAn` của các bị can liên quan trỏ về vụ gốc. Nhập 2 vụ độc lập (không có quan hệ tách trước đó) dùng chung cơ chế này, chỉ khác `vuGoc` không có sẵn dữ liệu.

### Đếm số liệu khi 1 vụ tách/nhập/trả nhiều lần

Luôn đếm trên `lichsuChuyenGiaiDoan`, không đếm trên field trạng thái hiện tại:
```
Số lượt trả hồ sơ kỳ X = COUNT(loaiSuKien = tra_ho_so AND kyThongKe = X)
Số vụ tách trong kỳ X   = COUNT(loaiSuKien = tach_vu AND kyThongKe = X)
Số vụ nhập trong kỳ X   = COUNT(loaiSuKien = nhap_vu AND kyThongKe = X)
```
Đúng dù 1 vụ bị trả/tách/nhập bao nhiêu lần — mỗi lần là 1 dòng log độc lập.

---

## 5. `kybaocao` — Kỳ báo cáo

| Trường | Kiểu | Ghi chú |
|---|---|---|
| `tenKy` | string | VD `07/2026` |
| `ngayBatDau` | date | |
| `ngayChot` | date \| null | do cán bộ thống kê quyết định |
| `trangThai` | enum | `dang_mo` / `da_chot` |
| `nguoiChot` / `thoiDiemChot` | ref → `canbo` / timestamp | |

Kỳ đã chốt: không gán sự kiện mới vào, chỉ sửa qua `lichSuSuaKy` có audit.

---

## 6. `canbo` — Cán bộ

| Trường | Kiểu | Ghi chú |
|---|---|---|
| `hoTen` | string | |
| `vaiTro` | enum | `ksv` / `dtv` / `can_bo_thong_ke` / `khac` |
| `trangThai` | enum | `dang_cong_tac` / `da_chuyen_don_vi` |

Nguồn dropdown cho `ksvChinh`, `ksvHoTro`, `dtvCbdt`, `nguoiThucHien`, `nguoiChot`.

---

## 7. Sinh mã vụ án tự động

### 7.1. Vụ án mới (khởi tố mới, phục hồi độc lập, chuyển đến...)

**Định dạng:** `QLVA_E01.53_{YYMM}_{SEQ4}`
- `E01.53`: hằng số cố định của hệ thống, không đổi
- `{YYMM}`: năm + tháng của **ngày QĐ KTVA** (không phải ngày tạo bản ghi)
- `{SEQ4}`: số thứ tự 4 chữ số, **reset về 0001 mỗi khi sang tháng KTVA mới**

**Bộ đếm — collection `boDemMaVu`:**

| Trường | Kiểu | Ghi chú |
|---|---|---|
| Document ID | string | `{YYMM}`, VD `"2601"` |
| `soHienTai` | number | số cuối cùng đã dùng trong tháng đó |

**Quy trình sinh mã (transaction, tránh trùng khi nhiều người tạo cùng lúc):**
1. Từ `ngayQdKtva` → tính `YYMM`.
2. Mở transaction Firestore: đọc `boDemMaVu/{YYMM}`, nếu chưa có thì tạo `soHienTai = 0`.
3. Tăng `soHienTai += 1`, ghi lại trong cùng transaction.
4. `maNoiSinh = "QLVA_E01.53_" + YYMM + "_" + pad4(soHienTai)`.

### 7.2. Vụ tách ra (`tach_vu`) — kế thừa mã vụ gốc, không dùng bộ đếm tháng

Khớp đúng quy ước Excel gốc (`24.0T.1277.1`, `24.0T.1447.9`...). Mã vụ con = `{maNoiSinh của vụ gốc}_{n}`, với `n` là số thứ tự tách, tính riêng theo từng vụ gốc (không liên quan bộ đếm tháng ở 7.1).

**Field bổ sung ở `vuan`:** `soDemTach` (number, mặc định `0`) — đếm số vụ con đã tách ra từ chính vụ này.

**Quy trình (transaction trên document vụ gốc):**
1. Mở transaction: đọc `vuGoc.soDemTach`.
2. Tăng `soDemTach += 1`, ghi lại trong cùng transaction.
3. `maNoiSinh (vụ con) = maNoiSinh (vụ gốc) + "_" + soDemTach`.

Tách nhiều tầng (vụ con lại tiếp tục tách) hoạt động tự nhiên: vụ con có `soDemTach` riêng của nó, nên vụ cháu có mã dạng `..._1_1`, `..._1_2` — vẫn dễ đọc, dễ tìm theo tiền tố, và luôn truy được về đúng vụ cha gần nhất chỉ bằng cách bỏ đuôi cuối cùng.

Dùng transaction ở cả hai mục 7.1 và 7.2 để tránh trùng số khi nhiều người thao tác cùng lúc (đúng yêu cầu multi-user).

**Hiển thị:** mọi nơi trong giao diện ưu tiên hiện `maNganhCap` nếu khác `null`; nếu chưa có thì hiện `maNoiSinh` kèm nhãn nhỏ "(mã nội sinh, chưa có mã ngành cấp)".

---

## Quan hệ tổng quan

```
canbo ──< vuan >── kybaocao
          │
          ├──< bican
          │
          └──< lichsuChuyenGiaiDoan >── kybaocao
boDemMaVu (độc lập, chỉ phục vụ sinh maNoiSinh)
```

## Index cần tạo trước

- `bican`: `maVuAn` + `ngayKhoiTo`
- `vuan`: `coQuanThuLy` + `trangThai`
- `vuan`: `maNganhCap` (tra cứu nhanh khi đã có mã ngành cấp)
- `lichsuChuyenGiaiDoan`: `maVuAn` + `thoiDiemGhi`
- `lichsuChuyenGiaiDoan`: `kyThongKe` + `loaiSuKien`
