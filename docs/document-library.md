# Kho tài liệu lâu dài — bước 3

Ứng dụng dùng `LocalDocumentRepository` thay danh sách mẫu. AI vẫn ở chế độ mock và chưa triển khai thêm.

## Hành vi

- Màn hình chính có nút **Nhập DOCX**; chọn file bằng file picker native, sao chép vào Documents riêng của app rồi mở editor.
- Nút mở file trong editor cũng lưu bản nhập vào cùng kho, sau khi xác nhận bỏ thay đổi chưa lưu.
- Khi quay lại thư viện hoặc khởi động app, đọc metadata trên ổ đĩa và hiển thị tên, dung lượng, ngày chỉnh sửa, mới nhất trước.
- **Lưu** cập nhật tài liệu đang mở trong thư viện: giữ ID, tên và ngày tạo, cập nhật nội dung, dung lượng và ngày chỉnh sửa. Lưu nhiều lần không tạo thêm dòng.
- **Lưu thành bản mới** tạo ID riêng trong `GenOffice/exports`; các lần Lưu tiếp theo cập nhật bản mới đó. Đây là lựa chọn hành vi mới của chủ dự án; file nguồn ở Downloads hoặc ứng dụng Files không bị ghi đè.
- Mở DOCX khác ngay trong editor sẽ chuyển đích Lưu sang tài liệu vừa mở. Những mục trùng tên đã tạo trước thay đổi này được giữ lại, không tự động gộp/xóa.
- File trùng tên có ID riêng. Hủy file picker không thêm tài liệu. Lỗi nhập hiện thông báo; lỗi đọc thư viện có nút thử lại.

## Lưu trữ

Trong thư mục do `getApplicationDocumentsDirectory()` cung cấp:

```text
GenOffice/
  documents/<id>/content.docx
  documents/<id>/content-<revision>.docx
  documents/<id>/document.json
  exports/<id>/content.docx
  exports/<id>/content-<revision>.docx
  exports/<id>/document.json
```

Metadata phiên bản 1 chứa ID, tên hiển thị, định dạng, ngày tạo UTC và số byte. Thêm hai trường tùy chọn `updatedAt` và `contentFile`: metadata cũ mặc định dùng ngày tạo và `content.docx`, không cần nhập lại tài liệu. `contentFile` chỉ chấp nhận tên file nội bộ hợp lệ. Không ghi đường dẫn tuyệt đối của app hay đường dẫn nguồn vào metadata; đường dẫn file được dựng lại khi đọc để hỗ trợ thay đổi đường dẫn container trên iOS. Tên người dùng không được dùng làm đường dẫn file.

Ghi file và metadata vào thư mục tạm cùng ổ đĩa, flush rồi đổi tên cả thư mục để công bố tài liệu. Thư viện bỏ qua thư mục ghi dở. Metadata hỏng báo lỗi thay vì âm thầm ghi đè danh sách hoặc xóa dữ liệu. Không có index dùng chung nên các lần nhập song song không ghi đè metadata của nhau.

Khi cập nhật, ghi hoàn chỉnh một file nội dung mới rồi thay `document.json` bằng metadata trỏ đến file đó. Không sửa trực tiếp file nội dung đang đọc trước khi commit. Các lần cập nhật cùng tài liệu được xếp hàng trong app isolate. Giữ nội bộ nội dung hiện tại và nội dung ngay trước đó; dọn các file nội dung cũ hơn sau commit, không tạo mục thư viện cho chúng. Đây chưa phải giao diện lịch sử phiên bản hay chức năng autosave/khôi phục phiên.

Giới hạn nhập 20 MB, xuất 32 MB; bản đã lưu tối đa 32 MB mở lại được. Kho riêng tồn tại khi đóng/mở app nhưng không phải bản sao lưu ngoài ứng dụng; gỡ app hoặc xóa dữ liệu ứng dụng có thể xóa tài liệu.

Các bản xuất từ phiên bản cũ chưa có `document.json` vẫn được giữ nguyên trên ổ đĩa nhưng chưa tự động xuất hiện trong thư viện. Chưa có chức năng xóa/đổi tên, share sheet, chọn nơi xuất hoặc autosave/khôi phục phiên; các phần này ngoài bước 3.

## Kiểm chứng

- Unit test: lưu lặp lại giữ một ID, đọc lại sau khởi động, lưu theo ID với các tài liệu trùng tên, tương thích metadata cũ, cập nhật đồng thời, giới hạn/ký tự đường dẫn, lần ghi dở và metadata hỏng. Lưu thành bản mới được kiểm tra tách biệt với Lưu.
- Widget test: thư viện rỗng có nút nhập; tài liệu lưu trên đĩa hiển thị sau khi dựng lại app và repository. Có regression test nhập file → chuyển sang editor → quay lại → tải lại thư viện. Tổng cộng 19 unit/widget test đạt, gồm lưu lặp lại, tương thích dữ liệu cũ, lưu đồng thời và phân biệt Lưu/Lưu thành bản mới.
- Ba ca integration đã đạt trên Android emulator `emulator-5554` ngày 21/10/2026: (1) nhập từ thư viện, mở WebView thật, quay lại và tải lại danh sách; (2) sửa/định dạng/chèn bảng, Lưu nhiều lần vẫn giữ một ID, mở lại đúng nội dung; (3) mở DOCX khác bên trong editor rồi Lưu đúng ID mới, không sửa nhầm ID trước; Lưu thành bản mới tạo bản riêng và Lưu tiếp tục cập nhật bản đó. Các ca này dùng luồng lưu thật của trang editor. Kết quả chọn file được cung cấp qua injection, không tự thao tác hộp thoại file picker Android. Chưa chạy lại luồng mới trên iOS hoặc điện thoại thật; test này không thay thế kiểm tra đóng/mở tiến trình app thực tế.

Nghiệm thu trên điện thoại: nhập DOCX từ ứng dụng Files → chỉnh sửa và lưu nhiều lần → quay lại thư viện (vẫn một mục) → đóng/mở lại app → mở đúng tài liệu và đối chiếu nội dung. Thử thêm mở file khác từ editor rồi Lưu, Lưu thành bản mới, hủy chọn file và nhập hai file trùng tên.
