# QLVA — Hướng dẫn nhanh (đọc khi quên cách làm)

Đây là app quản lý vụ án của Phòng 2, VKSND Hà Nội. Toàn bộ app nằm trong **1 file HTML duy
nhất** (`qlva.html` cho dữ liệu thật, `qlva-dev.html` cho dữ liệu thử nghiệm) — không cần cài đặt
gì để chạy, chỉ cần trình duyệt.

## 1. Xem/thử app ngay, KHÔNG cần đưa lên mạng

Chỉ cần **double-click** file là mở được:
- `qlva.html` → dữ liệu **thật** (project Firebase `qlahsp2`) — cẩn thận, đây là dữ liệu mọi người
  đang dùng thật.
- `qlva-dev.html` → dữ liệu **thử nghiệm** (project Firebase `qlahs-test`) — thoải mái bấm thử,
  xoá/sửa gì cũng không ảnh hưởng dữ liệu thật.

Cách này chỉ chạy được trên đúng máy đang mở file, không ai khác truy cập được.

## 2. Đưa thay đổi lên mạng để mọi người cùng dùng (deploy)

Sau khi sửa xong `qlva.html`/`qlva-dev.html` (tự sửa, hoặc nhờ Claude Code sửa), muốn mọi người
thấy thay đổi thì phải **deploy**:

1. Mở thư mục này trong File Explorer.
2. **Double-click file `deploy.bat`.**
3. Một cửa sổ đen (Command Prompt) hiện ra, cho chọn:
   - `1` = chỉ đưa lên bản **TEST** (an toàn, thử trước)
   - `2` = chỉ đưa lên bản **PRODUCTION** (dữ liệu thật — bắt gõ `YES` xác nhận mới chạy)
   - `3` = đưa lên **cả hai** (test trước, xong mới hỏi xác nhận production)
   - `0` = huỷ, không làm gì
4. Gõ số rồi Enter, đợi tới khi thấy dòng **"Deploy complete!"** là xong.
5. Cửa sổ sẽ dừng lại chờ bấm phím bất kỳ để đóng — đọc kỹ trước khi đóng, nếu thấy chữ đỏ/
   `Error` thì báo lại cho Claude Code kiểm tra, đừng deploy production tiếp.

## 3. Link để xem kết quả sau khi deploy

| Bản | Link | Dữ liệu |
|---|---|---|
| **Production** | https://qlahsp2.web.app | Thật — mọi người đang dùng |
| **Test** | https://qlahs-test.web.app | Thử nghiệm — thoải mái bấm thử |

Mở link bằng trình duyệt bất kỳ (điện thoại, máy khác cũng xem được, không cần mở file gì cả).

## 4. Vài điều cần nhớ

- **`public-prod/` và `public-test/`** là 2 thư mục tự sinh ra khi deploy (bản sao tạm để đưa lên
  mạng) — không cần đụng vào, không cần mở, `deploy.bat` tự lo hết.
- **`seed-tool.html`** là công cụ nội bộ để tạo/xoá dữ liệu thử nghiệm hàng loạt — có cả nút xoá
  dữ liệu **production thật**, chỉ dùng khi thật sự hiểu mình đang làm gì. File này **không** và
  **không được** đưa lên mạng công khai.
- Nếu quên hết mọi thứ ở trên: chỉ cần double-click `deploy.bat`, chọn số, đọc kỹ trước khi gõ
  `YES` cho production.
