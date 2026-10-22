# PDF viewer trên Android

Màn hình chính có nút **Mở PDF**. Chọn file qua trình chọn hệ thống Android; app chỉ yêu cầu và giữ quyền đọc. PDF được ghi vào danh sách gần đây cùng DOCX, có icon và nhãn riêng. Mở lại luôn đọc file nguồn hiện tại; nếu nguồn bị di chuyển hoặc mất quyền, app yêu cầu chọn mở lại, không âm thầm dùng cache cũ.

Trình đọc chạy PDF.js đóng gói offline trong WebView, gồm worker, CMap, font chuẩn và bộ giải mã WASM. Không cần tải thư viện từ CDN. Nguồn PDF được phục vụ qua loopback với token ngẫu nhiên; điều hướng ra ngoài bị chặn, không bật script hoặc biểu mẫu tương tác trong PDF. Chế độ PDF từ chối endpoint lưu/xuất và không có nút sửa/lưu.

## Chức năng

- Cuộn tài liệu nhiều trang; trang trước/sau; nhập số trang cụ thể.
- Phóng to, thu nhỏ, vừa chiều rộng trang.
- Tìm chữ toàn tài liệu, tô sáng kết quả, hiển thị số kết quả và chuyển kết quả trước/sau. Không phân biệt hoa/thường; dùng bộ tìm kiếm và chuẩn hóa Unicode của PDF.js.
- Báo lỗi file hỏng, mất quyền hoặc không đọc được; file có mật khẩu được báo rõ là chưa hỗ trợ.

Giới hạn mở PDF là 20 MB. PDF scan chỉ có ảnh vẫn xem được nhưng không tìm chữ nếu không có lớp text; chưa có OCR. PDF viewer chỉ đọc, chưa có ghi chú, sửa nội dung, điền biểu mẫu, in hoặc xuất PDF. Chưa kiểm thử mọi phiên bản Android/WebView hoặc điện thoại thật; iOS tiếp tục hoãn.

## Kiểm thử

Ngày 22/10/2026: 36 unit/widget test và hai integration test PDF trên Android emulator đạt; `dart analyze` không có lỗi/cảnh báo. APK đã được kiểm tra có đủ 201 tài nguyên PDF phụ trợ, entrypoint và worker offline.

Kiểm thử native `PdfDocumentTest` qua Downloads thật đạt: giữ quyền đọc qua SAF, đọc lại đúng byte, ghi bị từ chối, file gốc không đổi và thu hồi quyền khiến đọc thất bại. Bốn bài hồi quy DOCX WebView và bài native `SourceDocumentTest` ghi đè/đọc lại/thu hồi quyền DOCX cũng đạt sau thay đổi này. Đây là kết quả trên emulator, chưa thay thế nghiệm thu điện thoại thật.

- `test/pdf_repository_test.dart`: lưu và khởi tạo lại repository, trộn PDF/DOCX, chống trùng URI, kiểm tra đầu vào, chặn ghi DOCX vào bản ghi PDF và giữ nguyên byte nguồn/cache.
- `test/pdf_library_test.dart`: luồng nút Mở PDF và mở lại từ danh sách gần đây; dùng repository bộ nhớ để tách UI khỏi filesystem thật.
- `test/pdf_server_test.dart`: trả đúng MIME/nội dung, kiểm tra token/điều hướng và từ chối ghi.
- `integration_test/pdf_viewer_test.dart`: WebView Android thật, PDF mẫu 3 trang có chữ/hình, chuyển trang, tìm toàn tài liệu/tô sáng, không có kết quả, file hỏng và nguồn không bị thay đổi.
- `PdfDocumentTest` (Android instrumentation): trình chọn Downloads thật, quyền đọc được lưu bền, đọc lại, từ chối ghi và từ chối đọc khi bị thu hồi quyền. Chỉ dùng fixture riêng, không sửa tài liệu người dùng.

Chạy kiểm thử native bằng `assembleDebugAndroidTest`, cài APK bằng `adb install -r`, sau đó chạy class `com.example.gen_office_mobile.PdfDocumentTest` qua `am instrument`. Không dùng `connectedDebugAndroidTest` trên bản app đang giữ dữ liệu người dùng vì runner có thể gỡ app.
