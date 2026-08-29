# Đặc tả Biểu B10 — Thống kê kết quả điều tra, truy tố, xét xử sơ thẩm
## (Hướng dẫn triển khai cho Claude Code — có bảng chi tiết từng cột A–BT)

Nguồn: `B10_2025.xlsx` (mẫu bắt buộc của ngành, đã upload). Đối chiếu trực tiếp với code thật trong
`qlva.html` (`tinhBaoCaoKyTuLog`, `chotKyBaoCao`, `tinhTonHienTaiTheoGD`).

---

## 1. Số dòng xuất ra là ĐỘNG, không cố định

File mẫu gốc liệt kê toàn bộ danh mục điều luật hiện hành (dùng làm khung hiển thị/thứ tự), nhưng khi
**xuất báo cáo cho 1 kỳ cụ thể**, chỉ in ra những dòng tội danh THỰC SỰ có phát sinh hoặc đang thụ lý
trong kỳ đó:

1. Tính đủ 72 cột cho từng điều luật xuất hiện ở bất kỳ vụ án/bị can nào thuộc phạm vi kỳ đang xuất
   (kể cả vụ tồn từ kỳ trước, không chỉ vụ mới phát sinh).
2. Dòng toàn số 0 ở mọi cột thì bỏ, không in.
3. Thứ tự các dòng còn lại theo `thuTuHienThi` của module Danh mục tội danh (mục 7).
4. Dòng "Tổng" cuối bảng cộng đúng các dòng đã in ra.

---

## 2. Hai khái niệm khác nhau, không được nhầm lẫn: "Tổng thụ lý" và "Tồn"

- **Tổng thụ lý** = tổng gộp số vụ/bị can đã VÀ đang được xử lý tại giai đoạn G trong kỳ K (gồm cả
  phần sau đó đã đi tiếp sang giai đoạn khác hoặc đã giải quyết xong ngay trong kỳ). Đây là 1 cột có
  sẵn trong biểu B10.
- **Tồn** = số vụ/bị can THỰC SỰ còn đang nằm ở giai đoạn G tại 1 thời điểm (đầu kỳ hoặc cuối kỳ).
  Biểu B10 gốc **không có cột này** cho từng điều luật — đây chính là chỗ "khó tính toán" cần bổ sung
  thêm cột phụ (mục 5).

Hệ thống hiện tại (`chotKyBaoCao`) luôn tính **Tồn** bằng truy vấn trực tiếp, không suy luận:
```
Tồn (giai đoạn G, tại 1 thời điểm) = COUNT(vuan WHERE coQuanThuLy=G AND trangThai="dang_giai_quyet")
```
Áp dụng cho B10, lọc thêm theo điều luật:
```
Tồn (điều luật Đ, giai đoạn G) = COUNT(vuan WHERE coQuanThuLy=G AND trangThai="dang_giai_quyet"
                                       AND dieuLuat chứa Đ)
```

---

## 3. Công thức tổng quát (theo đúng cách người dùng mô tả, áp dụng cho cả 3 giai đoạn)

### 3.1. "Số khởi tố mới" (C6 — chỉ áp dụng cho giai đoạn Điều tra)

**SỬA 2026-08-30 (đối chiếu file ngành thật `10238.xlsx`/`10173.xlsx`): C6 CHỈ gồm 2 nguồn "mới
thật".** File ngành: `D71_10238 = C6 = 48`, TÁCH RIÊNG với `D73` "nơi khác chuyển đến" = 28 và
`D62` "phục hồi điều tra" = 7 (nếu C6 gồm 4 nguồn thì C6 ≠ D71). Bản mô tả cũ dưới đây ("4 nguồn")
là SAI.

```
C6 (Số khởi tố mới) = Số VA nguồn "an_khoi_to_moi" + Số VA nguồn "tin_bao_khoi_to_len"
```
`phuc_hoi_dieu_tra` và `an_noi_khac_chuyen_den` là các dòng RIÊNG của Biểu 2 (D62, D73) và được
cộng vào "Tổng thụ lý" (C3 / D77) qua đường khác — KHÔNG nằm trong C6. Code: `tinhBieu10`
`dtKhoiToMoiThat_b10`; `B10_FORMULA[7]` = SUMIFS "DS khởi tố ĐT" lọc cột Nguồn (AH) theo 2 nhãn.

### 3.2. "Tổng thụ lý" (áp dụng cho cả 3 giai đoạn, đổi thành phần "mới" theo từng giai đoạn)

```
Tổng thụ lý (giai đoạn G, kỳ K)
    = Tồn kỳ trước (G)
    + [Mới đến giai đoạn G trong kỳ]
    + Số vụ án được tách ra (đến thẳng G, trong kỳ)
    − Số vụ án được nhập vào vụ khác (đang ở G, trong kỳ)
    − Số vụ án chuyển đi nơi khác (hoàn thành dạng "chuyen_di", đang ở G, trong kỳ)
```

| Giai đoạn G | [Mới đến G] gồm |
|---|---|
| Điều tra | Số khởi tố mới (mục 3.1) **+** Số vụ VKS trả về điều tra bổ sung |
| Truy tố | Số vụ chuyển đến từ Điều tra (Đề nghị truy tố) **+** Số vụ Tòa trả về Truy tố |
| Xét xử | Số vụ chuyển đến từ Truy tố (đã truy tố) *(không có "trả về" vì Xét xử là giai đoạn cuối)* |

### 3.3. Từ "Tổng thụ lý" suy ra "Tồn cuối kỳ"

```
Tồn cuối kỳ (G) = Tổng thụ lý (G)
                 − Đình chỉ (tại G, trong kỳ)
                 − Tạm đình chỉ (tại G, trong kỳ)
                 − [Số vụ đã đi tiếp sang giai đoạn kế trong kỳ]
```
"[Số vụ đã đi tiếp sang giai đoạn kế]" = Đề nghị truy tố (G=Điều tra) / Truy tố (G=Truy tố) / Xét xử
xong (G=Xét xử).

**Trả lời câu hỏi "công thức đã tính ra tồn khớp thực tế chưa":** công thức gốc chỉ ra "Tổng thụ lý",
CHƯA ra "Tồn" — phải cộng thêm bước 3.3 mới ra đúng Tồn. Dù tính đúng lý thuyết, **vẫn bắt buộc đối
chiếu lại với Tồn tính bằng truy vấn trực tiếp** (mục 2) sau khi code xong, vì thiếu 1 sự kiện log nào
đó (VD quên gán `kyThongKe`) sẽ làm 2 cách tính lệch nhau — đó là dấu hiệu lỗi dữ liệu cần dò lại, không
phải chuyện bỏ qua được.

---

## 4. Bảng chi tiết từng cột A–BT (72 cột, đối chiếu trực tiếp file gốc)

| Cột Excel | Mã | Tên nhóm (cấp cha) | Tên chi tiết | Công thức tính |
|---|---|---|---|---|
| A | C1 | Điều luật / Điều luật | Điều luật | Lấy từ `dieuLuat` trong module Danh mục tội danh (mã điều luật của dòng) |
| B | C2 | Tội danh / Tội danh | Tội danh | Lấy từ `tenToiDanh` trong module Danh mục tội danh |
| C | C3 | Giai đoạn điều tra / Tổng thụ lý | Vụ án | Tổng thụ lý Điều tra — Vụ án. Công thức mục 3.2, G=dieu_tra |
| D | C4 | Giai đoạn điều tra / Tổng thụ lý | Bị can | Tổng thụ lý Điều tra — Bị can. Đếm bị can (không trùng) của các vụ ở C3 |
| E | C5 | Giai đoạn điều tra / Tổng thụ lý | Tr.đó: Pháp nhân | Tổng thụ lý Điều tra — Tr.đó Pháp nhân. Đếm bị can có `loaiBiCan=phap_nhan` trong tập C4 |
| F | C6 | Giai đoạn điều tra / Khởi tố mới | Vụ án | Khởi tố mới Điều tra — Vụ án. Công thức mục 3.1 (4 nguồn cộng lại) |
| G | C7 | Giai đoạn điều tra / Khởi tố mới | Bị can | Khởi tố mới Điều tra — Bị can. Đếm bị can của các vụ ở C6, `loaiKhoiTo=ban_dau` |
| H | C8 | Giai đoạn điều tra / Khởi tố mới | Tr.đó: Pháp nhân | Khởi tố mới Điều tra — Tr.đó Pháp nhân. `loaiBiCan=phap_nhan` trong tập C7 |
| I | C9 | Giai đoạn điều tra / Phân tích số bị can là cá nhân mới khởi tố | Từ 14 tuổi đến đưới 16 tuổi | Độ tuổi 14–16 (bị can mới khởi tố). `nhomTuoi="14_16"` trong tập C7 |
| J | C10 | Giai đoạn điều tra / Phân tích số bị can là cá nhân mới khởi tố | Từ 16 tuổi đến đưới 18 tuổi | Độ tuổi 16–18 (bị can mới khởi tố). `nhomTuoi="16_18"` trong tập C7 |
| K | C11 | Giai đoạn điều tra / Phân tích số bị can là cá nhân mới khởi tố | Từ 18 tuổi đến 30 tuổi | Độ tuổi 18–30 (bị can mới khởi tố). `nhomTuoi="18_30"` trong tập C7 |
| L | C12 | Giai đoạn điều tra / Phân tích số bị can là cá nhân mới khởi tố | Trên 30 tuổi đến 70 tuổi | Độ tuổi 30–70 (bị can mới khởi tố). `nhomTuoi="30_70"` trong tập C7 |
| M | C13 | Giai đoạn điều tra / Phân tích số bị can là cá nhân mới khởi tố | Trên 70 tuổi | Độ tuổi >70 (bị can mới khởi tố). `nhomTuoi=">70"` trong tập C7 |
| N | C14 | Giai đoạn điều tra / Phân tích số bị can là cá nhân mới khởi tố | Không biết chữ | Trình độ Không biết chữ (bị can mới khởi tố). `trinhDo=khong_biet_chu` trong tập C7 |
| O | C15 | Giai đoạn điều tra / Phân tích số bị can là cá nhân mới khởi tố | Tiểu học | Trình độ Tiểu học. `trinhDo=tieu_hoc` trong tập C7 |
| P | C16 | Giai đoạn điều tra / Phân tích số bị can là cá nhân mới khởi tố | Trung học cơ sơ | Trình độ THCS. `trinhDo=thcs` trong tập C7 |
| Q | C17 | Giai đoạn điều tra / Phân tích số bị can là cá nhân mới khởi tố | Trung học phổ thông | Trình độ THPT. `trinhDo=thpt` trong tập C7 |
| R | C18 | Giai đoạn điều tra / Phân tích số bị can là cá nhân mới khởi tố | Đại học và trên Đại học | Trình độ ĐH trở lên. `trinhDo=dh_tro_len` trong tập C7 |
| S | C19 | Giai đoạn điều tra / Phân tích số bị can là cá nhân mới khởi tố | Giới tính nữ | Giới tính nữ (bị can mới khởi tố). `gioiTinh=nu` trong tập C7 |
| T | C20 | Giai đoạn điều tra / Phân tích số bị can là cá nhân mới khởi tố | Là dân tộc thiểu số | Là dân tộc thiểu số. `danToc != "Kinh"` trong tập C7 |
| U | C21 | Giai đoạn điều tra / Phân tích số bị can là cá nhân mới khởi tố | Khi phạm tội là đảng viên | Khi phạm tội là đảng viên. `dangVien=co` trong tập C7 |
| V | C22 | Giai đoạn điều tra / Phân tích số bị can là cá nhân mới khởi tố | Tr/đó: Số bị can là đảng viên đang giữ chức danh quản lý | Tr/đó đảng viên giữ chức danh quản lý. `dangVienGiuChucVu=true` trong tập C7 |
| W | C23 | Giai đoạn điều tra / Phân tích số bị can là cá nhân mới khởi tố | Số bị can là người nước ngoài, người không quốc tịch | Người nước ngoài, không quốc tịch. `quocTich != "Việt Nam"` trong tập C7 |
| X | C24 | Giai đoạn điều tra / Phân tích số bị can là cá nhân mới khởi tố | Tái phạm, tái phạm nguy hiểm | Tái phạm, tái phạm nguy hiểm. `taiPham != khong` trong tập C7 |
| Y | C25 | Giai đoạn điều tra / Đề nghị truy tố | Vụ án | Đề nghị truy tố — Vụ án. Vụ có `chuyen_giai_doan`, `tuGiaiDoan=dieu_tra`, `denGiaiDoan=truy_to`, `kyThongKe=K` |
| Z | C26 | Giai đoạn điều tra / Đề nghị truy tố | Bị can | Đề nghị truy tố — Bị can. Bị can của các vụ ở C25 |
| AA | C27 | Giai đoạn điều tra / Đề nghị truy tố | Tr.đó: Pháp nhân | Đề nghị truy tố — Tr.đó Pháp nhân. `loaiBiCan=phap_nhan` trong tập C26 |
| AB | C28 | Giai đoạn điều tra / Đình chỉ | Vụ án | Đình chỉ (ĐT) — Vụ án. `hoan_thanh`, `hinhThucHoanThanh=dinh_chi`, `coQuanThuLy=dieu_tra` lúc hoàn thành, `kyThongKe=K` |
| AC | C29 | Giai đoạn điều tra / Đình chỉ | Bị can | Đình chỉ (ĐT) — Bị can. Bị can của các vụ ở C28 |
| AD | C30 | Giai đoạn điều tra / Đình chỉ | Tr.đó: Pháp nhân | Đình chỉ (ĐT) — Tr.đó Pháp nhân. `loaiBiCan=phap_nhan` trong tập C29 |
| AE | C31 | Giai đoạn điều tra / Tạm đình chỉ | Vụ án | Tạm đình chỉ (ĐT) — Vụ án. `hoan_thanh`, `hinhThucHoanThanh=tam_dinh_chi`, `coQuanThuLy=dieu_tra`, `kyThongKe=K` |
| AF | C32 | Giai đoạn điều tra / Tạm đình chỉ | Bị can | Tạm đình chỉ (ĐT) — Bị can. Bị can của các vụ ở C31 |
| AG | C33 | Giai đoạn truy tố / Tổng thụ lý | Vụ án | Tổng thụ lý Truy tố — Vụ án. Công thức mục 3.2, G=truy_to |
| AH | C34 | Giai đoạn truy tố / Tổng thụ lý | Bị can | Tổng thụ lý Truy tố — Bị can. Bị can của các vụ ở C33 |
| AI | C35 | Giai đoạn truy tố / Tổng thụ lý | Tr.đó: Pháp nhân | Tổng thụ lý Truy tố — Tr.đó Pháp nhân. `loaiBiCan=phap_nhan` trong tập C34 |
| AJ | C36 | Giai đoạn truy tố / Truy tố | Vụ án | Truy tố — Vụ án. Vụ có `chuyen_giai_doan`, `tuGiaiDoan=truy_to`, `denGiaiDoan=xet_xu`, `kyThongKe=K` |
| AK | C37 | Giai đoạn truy tố / Truy tố | Bị can | Truy tố — Bị can. Bị can của các vụ ở C36 |
| AL | C38 | Giai đoạn truy tố / Truy tố | Tr.đó: Pháp nhân | Truy tố — Tr.đó Pháp nhân. `loaiBiCan=phap_nhan` trong tập C37 |
| AM | C39 | Giai đoạn truy tố / Phân loại tội phạm | ít nghiêm trọng | Phân loại tội phạm: ít nghiêm trọng — **Bị can** (Dũng xác nhận 2026-08-29; quy tắc ngành `C37=C39+C40+C41+C42`). Đếm BỊ CAN trong tập C37 có `mucDoNghiemTrong=it_nghiem_trong` (field bị can, fallback suy theo điều luật chính) |
| AN | C40 | Giai đoạn truy tố / Phân loại tội phạm | Nghiêm trọng | Như C39, `mucDoNghiemTrong=nghiem_trong` |
| AO | C41 | Giai đoạn truy tố / Phân loại tội phạm | Rất nghiêm trọng | Như C39, `mucDoNghiemTrong=rat_nghiem_trong` |
| AP | C42 | Giai đoạn truy tố / Phân loại tội phạm | Đặc biệt nghiêm trọng | Như C39, `mucDoNghiemTrong=dac_biet_nghiem_trong`. Tổng C39+C40+C41+C42 = C37 (mọi bị can rơi đúng 1 mức) |
| AQ | C43 | Giai đoạn truy tố / Phân tích số bị can là cá nhân đã truy tố | Từ 14 tuổi đến đưới 16 tuổi | Độ tuổi 14–16 (bị can đã truy tố). `nhomTuoi="14_16"` trong tập C37 |
| AR | C44 | Giai đoạn truy tố / Phân tích số bị can là cá nhân đã truy tố | Từ 16 tuổi đến đưới 18 tuổi | Độ tuổi 16–18 (bị can đã truy tố). `nhomTuoi="16_18"` trong tập C37 |
| AS | C45 | Giai đoạn truy tố / Phân tích số bị can là cá nhân đã truy tố | Từ 18 tuổi đến 30 tuổi | Độ tuổi 18–30 (bị can đã truy tố). `nhomTuoi="18_30"` trong tập C37 |
| AT | C46 | Giai đoạn truy tố / Phân tích số bị can là cá nhân đã truy tố | Trên 30 tuổi đến 70 tuổi | Độ tuổi 30–70 (bị can đã truy tố). `nhomTuoi="30_70"` trong tập C37 |
| AU | C47 | Giai đoạn truy tố / Phân tích số bị can là cá nhân đã truy tố | Trên 70 tuổi | Độ tuổi >70 (bị can đã truy tố). `nhomTuoi=">70"` trong tập C37 |
| AV | C48 | Giai đoạn truy tố / Phân tích số bị can là cá nhân đã truy tố | Giới tính nữ | Giới tính nữ (bị can đã truy tố). `gioiTinh=nu` trong tập C37 |
| AW | C49 | Giai đoạn truy tố / Phân tích số bị can là cá nhân đã truy tố | Là dân tộc thiểu số | Là dân tộc thiểu số (đã truy tố). `danToc != "Kinh"` trong tập C37 |
| AX | C50 | Giai đoạn truy tố / Phân tích số bị can là cá nhân đã truy tố | Khi phạm tội là đảng viên | Khi phạm tội là đảng viên (đã truy tố). `dangVien=co` trong tập C37 |
| AY | C51 | Giai đoạn truy tố / Phân tích số bị can là cá nhân đã truy tố | Tr/đó: Số bị can là đảng viên đang giữ chức danh quản lý | Tr/đó đảng viên giữ chức danh quản lý (đã truy tố). `dangVienGiuChucVu=true` trong tập C37 |
| AZ | C52 | Giai đoạn truy tố / Phân tích số bị can là cá nhân đã truy tố | Số bị can là người nước ngoài, người không quốc tịch | Người nước ngoài, không quốc tịch (đã truy tố). `quocTich != "Việt Nam"` trong tập C37 |
| BA | C53 | Giai đoạn truy tố / Đình chỉ | Vụ án | Đình chỉ (TT) — Vụ án. `hoan_thanh`, `hinhThucHoanThanh=dinh_chi`, `coQuanThuLy=truy_to`, `kyThongKe=K` |
| BB | C54 | Giai đoạn truy tố / Đình chỉ | Bị can | Đình chỉ (TT) — Bị can. Bị can của các vụ ở C53 |
| BC | C55 | Giai đoạn truy tố / Đình chỉ | Tr.đó: Pháp nhân | Đình chỉ (TT) — Tr.đó Pháp nhân. `loaiBiCan=phap_nhan` trong tập C54 |
| BD | C56 | Giai đoạn truy tố / Tạm đình chỉ | Vụ án | Tạm đình chỉ (TT) — Vụ án. `hoan_thanh`, `hinhThucHoanThanh=tam_dinh_chi`, `coQuanThuLy=truy_to`, `kyThongKe=K` |
| BE | C57 | Giai đoạn truy tố / Tạm đình chỉ | Bị can | Tạm đình chỉ (TT) — Bị can. Bị can của các vụ ở C56 |
| BF | C58 | Giai đoạn truy tố / VKS trả hồ sơ để ĐTBS (CQĐT chấp nhận) | Vụ án | VKS trả hồ sơ để ĐTBS — Vụ án. Vụ có `tra_ho_so`, `tuGiaiDoan=truy_to`, `denGiaiDoan=dieu_tra`, `kyThongKe=K` |
| BG | C59 | Giai đoạn truy tố / VKS trả hồ sơ để ĐTBS (CQĐT chấp nhận) | Bị can | VKS trả hồ sơ để ĐTBS — Bị can. Bị can của các vụ ở C58 |
| BH | C60 | Giai đoạn xét xử sơ thẩm / Tổng thụ lý | Vụ án | Tổng thụ lý Xét xử — Vụ án. Công thức mục 3.2, G=xet_xu |
| BI | C61 | Giai đoạn xét xử sơ thẩm / Tổng thụ lý | Bị cáo | Tổng thụ lý Xét xử — Bị cáo. Bị can (gọi là "bị cáo" ở giai đoạn này) của các vụ ở C60 |
| BJ | C62 | Giai đoạn xét xử sơ thẩm / Tổng thụ lý | Tr.đó: Pháp nhân | Tổng thụ lý Xét xử — Tr.đó Pháp nhân. `loaiBiCan=phap_nhan` trong tập C61 |
| BK | C63 | Giai đoạn xét xử sơ thẩm / Xét xử | Vụ án | Xét xử — Vụ án. `hoan_thanh`, `hinhThucHoanThanh=da_xet_xu`, `coQuanThuLy=xet_xu`, `kyThongKe=K` |
| BL | C64 | Giai đoạn xét xử sơ thẩm / Xét xử | Bị cáo | Xét xử — Bị cáo. Bị can của các vụ ở C63 |
| BM | C65 | Giai đoạn xét xử sơ thẩm / Xét xử | Tr.đó: Pháp nhân | Xét xử — Tr.đó Pháp nhân. `loaiBiCan=phap_nhan` trong tập C64 |
| BN | C66 | Giai đoạn xét xử sơ thẩm / Đình chỉ | Vụ án | Đình chỉ (XX) — Vụ án. `hoan_thanh`, `hinhThucHoanThanh=dinh_chi`, `coQuanThuLy=xet_xu`, `kyThongKe=K` |
| BO | C67 | Giai đoạn xét xử sơ thẩm / Đình chỉ | Bị cáo | Đình chỉ (XX) — Bị cáo. Bị can của các vụ ở C66 |
| BP | C68 | Giai đoạn xét xử sơ thẩm / Đình chỉ | Tr.đó: Pháp nhân | Đình chỉ (XX) — Tr.đó Pháp nhân. `loaiBiCan=phap_nhan` trong tập C67 |
| BQ | C69 | Giai đoạn xét xử sơ thẩm / Tạm đình chỉ | Vụ án | Tạm đình chỉ (XX) — Vụ án. `hoan_thanh`, `hinhThucHoanThanh=tam_dinh_chi`, `coQuanThuLy=xet_xu`, `kyThongKe=K` |
| BR | C70 | Giai đoạn xét xử sơ thẩm / Tạm đình chỉ | Bị cáo | Tạm đình chỉ (XX) — Bị cáo. Bị can của các vụ ở C69 |
| BS | C71 | Giai đoạn xét xử sơ thẩm / Tòa án trả hồ sơ để ĐTBS (VKS chấp nhận | Vụ án | Tòa án trả hồ sơ để ĐTBS — Vụ án. Vụ có `tra_ho_so`, `tuGiaiDoan=xet_xu`, `denGiaiDoan=truy_to`, `kyThongKe=K` |
| BT | C72 | Giai đoạn xét xử sơ thẩm / Tòa án trả hồ sơ để ĐTBS (VKS chấp nhận | Bị can | Tòa án trả hồ sơ để ĐTBS — Bị can. Bị can của các vụ ở C71 |

**Ghi chú áp dụng chung cho toàn bảng:**
- "Bị can"/"Bị cáo" ở mọi cột đều lấy từ cùng 1 collection `bican` — đổi nhãn hiển thị theo giai đoạn
  (Điều tra/Truy tố gọi "Bị can", Xét xử gọi "Bị cáo"), không phải 2 loại dữ liệu khác nhau.
- "Tr.đó: Pháp nhân" luôn là tập con của cột Bị can/Bị cáo liền trước, lọc `loaiBiCan=phap_nhan`
  (field cần bổ sung — mục 6).
- Vì `toiDanh` là mảng, 1 vụ nhiều bị can có thể có nhiều điều luật khác nhau — 1 vụ án có thể được
  đếm ở NHIỀU dòng tội danh khác nhau (đúng bản chất thống kê ngành). Tổng "Vụ án" cộng dồn qua tất cả
  các dòng có thể lớn hơn tổng số vụ án thực đang thụ lý — không phải lỗi.

---

## 5. Bổ sung cột phụ vào CHÍNH BẢN XUẤT (không chỉ tính ngầm nội bộ)

Đặt thêm 4 cột phụ ngay cạnh khối "Tổng thụ lý" của mỗi giai đoạn (Điều tra/Truy tố/Xét xử):

| Cột phụ thêm mới | Nội dung |
|---|---|
| Tồn kỳ trước | Theo công thức mục 2, lọc điều luật + giai đoạn, tại thời điểm đầu kỳ |
| Tồn kỳ này | Theo công thức mục 2, lọc điều luật + giai đoạn, tại thời điểm cuối kỳ |
| Số vụ án nhập vào | Thành phần "Nhập" ở công thức 3.2 |
| Số vụ án chuyển đi | Thành phần "Chuyển đi nơi khác" ở công thức 3.2 |

Nên thêm cả **"Số vụ án được tách ra"** và **"Số vụ VKS/Tòa trả về"** để toàn bộ phép cộng trừ kiểm
tra được bằng mắt thường ngay trên file Excel, không cần mở CSDL.

---

## 6. Field còn thiếu ở `bican`

1. `trinhDo` (enum: `khong_biet_chu / tieu_hoc / thcs / thpt / dh_tro_len`)
2. `dangVienGiuChucVu` (boolean)
3. `quocTich` (string, mặc định `"Việt Nam"`)
4. `taiPham` (enum: `khong / tai_pham / tai_pham_nguy_hiem`)
5. Hàm tính `nhomTuoi` 5 mức (14–16 / 16–18 / 18–30 / 30–70 / >70) — chưa có trong code
6. `loaiBiCan` (enum: `ca_nhan / phap_nhan`, mặc định `ca_nhan`) + `tenPhapNhan`, `maSoThue`

---

## 7. Module riêng: Danh mục tội danh (không dùng file JSON tĩnh)

Collection `danhMucToiDanh`: `dieuLuat`, `tenToiDanh`, `blhsNam` (`1999 / 2015 / 2015_sd_2017`),
`mucDoNghiemTrong` (4 mức, dùng cho cột phân loại tội phạm — cột AM–AP), `thuTuHienThi`. Seed ban đầu
đọc trực tiếp từ `B10_2025.xlsx` (cột A/B, Sheet1, dòng 12–150). Form nhập bị can nên đổi `toiDanh` từ
gõ tay sang chọn từ danh mục này.

---

## 8. Thứ tự triển khai cho Claude Code

1. Module Danh mục tội danh (mục 7).
2. Bổ sung 6 field còn thiếu ở `bican` (mục 6).
3. Viết hàm tính "Tồn theo điều luật" (mục 2) — mở rộng `tinhTonHienTaiTheoGD` có sẵn, thêm lọc điều luật.
4. Viết hàm tính "Tổng thụ lý" + "Tồn cuối kỳ" theo công thức 3.1–3.3, cho từng điều luật.
5. Viết đủ 72 cột theo bảng mục 4.
6. Sinh dòng động (mục 1), bỏ dòng toàn 0, sắp theo `thuTuHienThi`, cộng dòng "Tổng".
7. Thêm các cột phụ vào bản xuất (mục 5).
8. **Bắt buộc**: đối chiếu tổng "Tồn kỳ này" của mọi dòng đã in, theo từng giai đoạn, với
   `ky.tonCuoiKy[gd]` đã có — cảnh báo rõ nếu lệch.
9. Xuất Excel dùng `B10_2025.xlsx` làm template, ghi giá trị vào đúng ô theo cột đã map ở mục 4 + chèn
   cột phụ mục 5.
