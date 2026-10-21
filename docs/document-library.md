# Kho tài liệu lâu dài — bước 3

Ứng dụng dùng `LocalDocumentRepository` thay danh sách mẫu. AI vẫn ở chế độ mock và chưa triển khai thêm.

## Hành vi

- Màn hình chính có nút **Nhập DOCX**; chọn file bằng file picker native, sao chép vào Documents riêng của app rồi mở editor.
- Nút mở file trong editor cũng lưu bản nhập vào cùng kho, sau khi xác nhận bỏ thay đổi chưa lưu.
- Khi quay lại thư viện hoặc khởi động app, đọc metadata trên ổ đĩa và hiển thị tên, dung lượng, ngày thêm, mới nhất trước.
- Mỗi lần lưu từ editor tạo một bản mới trong `GenOffice/exports` và thêm metadata để có thể mở lại từ thư viện. Bản nhập gốc không bị thay đổi.
- File trùng tên có ID riêng. Hủy file picker không thêm tài liệu. Lỗi nhập hiện thông báo; lỗi đọc thư viện có nút thử lại.

## Lưu trữ

Trong thư mục do `getApplicationDocumentsDirectory()` cung cấp:

```text
GenOffice/
  documents/<id>/content.docx
  documents/<id>/document.json
  exports/<id>/content.docx
  exports/<id>/document.json
```

Metadata phiên bản 1 chứa ID, tên hiển thị, định dạng, ngày tạo UTC và số byte. Không ghi đường dẫn tuyệt đối của app hay đường dẫn nguồn vào metadata; đường dẫn file được dựng lại khi đọc để hỗ trợ thay đổi đường dẫn container trên iOS. Tên người dùng không được dùng làm đường dẫn file.

Ghi file và metadata vào thư mục tạm cùng ổ đĩa, flush rồi đổi tên cả thư mục để công bố tài liệu. Thư viện bỏ qua thư mục ghi dở. Metadata hỏng báo lỗi thay vì âm thầm ghi đè danh sách hoặc xóa dữ liệu. Không có index dùng chung nên các lần nhập song song không ghi đè metadata của nhau.

Giới hạn nhập 20 MB, xuất 32 MB; bản đã lưu tối đa 32 MB mở lại được. Kho riêng tồn tại khi đóng/mở app nhưng không phải bản sao lưu ngoài ứng dụng; gỡ app hoặc xóa dữ liệu ứng dụng có thể xóa tài liệu.

Các bản xuất từ phiên bản cũ chưa có `document.json` vẫn được giữ nguyên trên ổ đĩa nhưng chưa tự động xuất hiện trong thư viện. Chưa có chức năng xóa/đổi tên, share sheet, chọn nơi xuất hoặc autosave/khôi phục phiên; các phần này ngoài bước 3.

## Kiểm chứng

- Unit test: đọc lại metadata bằng repository mới, giữ bản nhập khi xóa nguồn, file trùng tên, bản xuất không ghi đè bản gốc, thư mục ghi dở, giới hạn nhập, tên chứa đường dẫn, di chuyển thư mục app và metadata hỏng.
- Widget test: thư viện rỗng có nút nhập; tài liệu lưu trên đĩa hiển thị sau khi dựng lại app và repository.
- Integration test đã đạt trên Android emulator `emulator-5554` ngày 21/10/2026: nhập DOCX mẫu vào kho, đọc bằng repository mới rồi mở WebView, sửa, undo/redo, lưu, đọc lại metadata bằng repository mới và mở lại nội dung bản xuất. Kiểm tra bản gốc không đổi. Build 34,5 giây, test 23 giây. Chưa chạy lại luồng mới trên iOS hoặc điện thoại thật; test này không thay thế kiểm tra đóng/mở tiến trình app thực tế.

Nghiệm thu trên điện thoại: nhập DOCX từ ứng dụng Files → chỉnh sửa và lưu → quay lại thư viện → đóng/mở lại app → mở bản nhập và bản lưu → đối chiếu nội dung. Thử thêm hủy chọn file và nhập hai file trùng tên.
