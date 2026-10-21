# Checklist GenOffice Mobile

Cập nhật: 21/10/2026. Giữ đúng lộ trình 9 bước đã thống nhất sau khi tạm hoãn AI. Bước chưa đánh dấu có thể đã làm một phần; chỉ đánh dấu hoàn tất khi đủ các mục con.

Tài liệu theo dõi tiến độ được lưu cùng source Flutter. Phát triển trên nhánh `dev`; chỉ merge sang nhánh chính khi chủ dự án chấp thuận.

## Lộ trình đã thống nhất

- [x] **Bước 1. Tách editor DOCX khỏi Electron**
  - [x] Tái sử dụng editor React/Tiptap và engine DOCX của GenOffice.
  - [x] Chuyển phụ thuộc IPC, Node và filesystem thành adapter trình duyệt.
  - [x] Kiểm thử editor độc lập: mở, chỉnh sửa, định dạng, bảng, undo/redo, xuất và mở lại DOCX.

- [ ] **Bước 2. Nhúng editor vào Flutter bằng WebView**
  - [x] Đóng gói editor, font và worker trong ứng dụng.
  - [x] Nối bridge Flutter ↔ editor cho mở/lưu/undo/redo/trạng thái.
  - [x] Kiểm thử luồng DOCX trên Android emulator và iOS Simulator.
  - [x] Sửa menu cuộn ngang, nhãn nằm trên một dòng.
  - [ ] Kiểm tra bàn phím tiếng Việt, chọn chữ, cảm ứng, cuộn và zoom trên điện thoại thật.

- [x] **Bước 3. Thêm chọn và mở file DOCX thật**
  - [x] Chọn DOCX bằng file picker native và mở trong editor.
  - [x] Sao chép file import vào kho tài liệu lâu dài của app.
  - [x] Lưu metadata và hiển thị lại tài liệu sau khi khởi động app; thay danh sách mẫu bằng thư viện thật, có nút nhập DOCX.
  - Bản lưu mới cũng được đưa vào thư viện; không ghi đè file gốc. Đã kiểm thử tự động lưu trữ và dựng lại thư viện; integration test mở/sửa/undo/redo/lưu/mở lại bản lưu và giữ nguyên bản gốc đạt trên Android emulator `emulator-5554` ngày 21/10/2026. Cần nghiệm thu điện thoại thật ở bước 2/8. Xem [kho tài liệu](document-library.md).

- [ ] **Bước 4. Hoàn thiện chỉnh sửa cơ bản**
  - [x] Tích hợp sửa nội dung, định dạng chữ, đoạn và bảng từ editor gốc.
  - [x] Có kiểm thử engine/browser cho định dạng và bảng, kiểm thử mobile cho sửa nội dung.
  - [ ] Nghiệm thu đầy đủ trên điện thoại thật với bộ DOCX nhà máy, đối chiếu định dạng Word.

- [ ] **Bước 5. Lưu, xuất và chia sẻ DOCX**
  - [x] Lưu thành DOCX mới trong Documents riêng của app, dưới `GenOffice/exports`.
  - [x] Kiểm thử lưu native và mở lại file kết quả.
  - [x] Cảnh báo thay đổi chưa lưu khi quay lại/mở file khác.
  - [ ] Thêm chọn nơi xuất và chia sẻ qua share sheet.
  - [ ] Kiểm tra file kết quả bằng Microsoft Word với tài liệu thực tế.

- [ ] **Bước 6. Thêm undo/redo và khôi phục phiên**
  - [x] Nối và kiểm thử undo/redo.
  - [x] Giữ file gốc bằng cách lưu thành bản mới.
  - [ ] Thêm snapshot/tự động lưu và khôi phục khi app đóng đột ngột.
  - [ ] Kiểm thử phục hồi sau crash hoặc hệ điều hành thu hồi app.

- [ ] **Bước 7. Tích hợp PDF viewer**
  - [ ] Mở và hiển thị PDF thật.
  - [ ] Tìm kiếm và điều hướng trang.

- [ ] **Bước 8. Kiểm thử trên Android thực tế**
  - [x] Build APK và kiểm thử DOCX trên emulator.
  - [ ] Kiểm thử điện thoại thật: file lớn, bàn phím tiếng Việt, bộ nhớ và chuyển nền.
  - [ ] Xử lý lỗi trên thiết bị mục tiêu và nghiệm thu.

- [ ] **Bước 9. Mở rộng Sheets, Slides và iOS sau khi luồng DOCX ổn định**
  - [ ] Tích hợp Sheets/XLSX thực tế.
  - [ ] Tích hợp Slides/PPTX thực tế.
  - [x] Cấu hình và sửa build iOS với Flutter 3.35.3 / Xcode 27, deployment target iOS 15.
  - [x] Build Debug và kiểm thử DOCX trên iPhone 18 Pro Simulator / iOS 27.
  - [x] Build iOS Release không ký (`--no-codesign`).
  - [ ] Thiết lập signing, cài và kiểm thử iPhone thật.

## Mốc DOCX đầu tiên

- [x] Mở → sửa → lưu → mở lại đạt trong integration test Android emulator và iOS Simulator.
- [ ] Nghiệm thu cùng luồng trên điện thoại thật với file nhà máy và đối chiếu Microsoft Word.

## AI — tạm hoãn theo yêu cầu

Giữ interface/mock/API stub hiện có. Chưa nối API và chưa triển khai AI thao tác tài liệu. AI sẽ chạy trên máy chủ nội bộ nhà máy, mobile gọi API; không chạy model trên điện thoại. Chỉ tiếp tục khi chủ dự án yêu cầu.

## Công việc bổ sung đã làm

- [x] Tạo cấu trúc dự án Flutter.
- [x] Đưa source lên GitHub, thêm `.gitignore` và README hướng dẫn clone/cài/chạy/build.
- [x] Thiết lập nhánh `dev`; chỉ đưa lên nhánh chính khi chủ dự án chấp thuận.
- [x] Merge PR #1 và [PR #2 sửa iOS](https://github.com/ducdoan1806/gen_office_mobile/pull/2) theo yêu cầu.

## Điểm tiếp tục

Nghiệm thu luồng nhập → đóng/mở lại app → mở từ thư viện trên điện thoại thật ở bước 2/8, rồi hoàn thiện các mục thiếu của bước 4–6. Bước 3 đã có lưu trữ lâu dài và metadata. Giữ nguyên số bước dù một số phần đã được làm sớm, chẳng hạn iOS.

Đây là tổng hợp kết quả kiểm thử đã ghi nhận, không phải lần chạy lại test. Xem thêm [README](../README.md), [tách editor](docx-web-extraction.md), [WebView mobile](mobile-webview.md) và [build iOS](ios-build.md).
