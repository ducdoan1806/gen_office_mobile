# XLS, PPT, CSV offline trên Android

Ứng dụng dùng chung nút **Mở tài liệu** cho DOC/DOCX/PDF/XLS/XLSX/PPT/PPTX/CSV. `.ptt` không phải phần mở rộng PowerPoint được hỗ trợ; dùng `.ppt` hoặc `.pptx`.

## Mở và lưu nguồn

XLS ↔ XLSX và PPT ↔ PPTX dùng LibreOfficeKit đã đóng gói trong APK, chạy ở process chuyển đổi riêng. Không gọi máy chủ chuyển đổi. Editor vẫn dùng XLSX/PPTX nội bộ, gồm undo/redo và bản tạm khôi phục. **Lưu** chuyển ngược về định dạng nguồn rồi ghi/đọc xác minh đúng URI Android đã chọn; không tạo thêm mục trong thư viện. **Lưu thành bản mới** xuất XLSX/PPTX qua trình chọn nơi lưu Android.

Giới hạn nhập 20 MB, kết quả 32 MB. Bộ chuyển đổi kiểm tra họ tài liệu, chữ ký ZIP/OLE và thời gian chạy. File lỗi, sai họ hoặc chuyển đổi thất bại không được ghi vào nguồn. Chuyển đổi định dạng cũ có thể làm thay đổi bố cục, font và tính năng nâng cao; không cam kết giữ nguyên từng byte hoặc mọi tính năng Office. Chưa nghiệm thu đối chiếu bằng Microsoft Office với bộ XLS/PPT thực tế của nhà máy.

## CSV

CSV được đọc/ghi trực tiếp trên điện thoại bằng codec Dart và chuyển sang một sheet XLSX nội bộ để sửa bằng giao diện Sheets. Hỗ trợ UTF-8 (có/không BOM), UTF-16 LE/BE có BOM, dấu phẩy/chấm phẩy/tab, dòng `sep=`, ô có dấu ngoặc kép và xuống dòng. Giữ dấu phân cách, BOM, mã hóa và kiểu xuống dòng của file lúc nhập. Chưa hỗ trợ mã hóa ANSI/Windows cũ; file không hợp lệ báo lỗi, không tự đoán rồi thay chữ.

Số thập phân thông thường được nhập dạng số để tính toán; mã có số 0 đầu, số quá 15 chữ số, ngày và chuỗi bắt đầu `=` được giữ dạng chữ. Giới hạn 500.000 ô; file rỗng không được nhập.

CSV chỉ giữ giá trị một sheet, không giữ font, màu, đối tượng hay công thức. Lần Lưu đầu trong mỗi phiên có xác nhận hạn chế này. Công thức trong editor được xuất thành kết quả đã tính (giá trị thô, không áp định dạng hiển thị Excel). Nếu chưa có kết quả, Lưu báo lỗi. Nếu thêm nhiều sheet, phải **Lưu thành bản mới** thành XLSX để tránh mất dữ liệu. Bản tạm phục hồi vẫn là XLSX nên còn công thức/định dạng cho đến khi đóng phiên.

## Cuộn lưới Excel

- Vuốt một ngón trong lưới để cuộn ngang hoặc dọc; khóa hướng theo chuyển động ban đầu và cuộn tiếp theo quán tính khi thả tay.
- Chạm chọn ô; chạm hai lần để sửa bằng editor gốc.
- Giữ khoảng 0,4 giây rồi kéo để chọn vùng.
- Thanh công thức, tiêu đề hàng/cột, thanh cuộn và chuột giữ tương tác gốc. Có thể tiếp tục dùng ô địa chỉ để nhảy đến ô xa.

Chỉ bổ sung điều khiển cảm ứng cho lưới chính, không biến thao tác kéo ô thành cuộn trên desktop. Chưa bổ sung pinch zoom; dùng điều khiển zoom sẵn có. Nghiệm thu bàn phím tiếng Việt và cảm ứng bằng tay trên thiết bị mục tiêu vẫn nằm trong checklist bước 8.
