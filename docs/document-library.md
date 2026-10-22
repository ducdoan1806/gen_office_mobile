# Mở và lưu tài liệu Android

Yêu cầu hiện tại: mở file trong thư mục trên điện thoại, sửa và **Lưu vào chính file đó**. Luồng này thay thế hành vi chỉ cập nhật bản sao riêng của app.

## Hành vi

- Một nút **Mở tài liệu** dùng ACTION_OPEN_DOCUMENT cho DOCX/DOC/PDF. DOCX/DOC giữ quyền đọc/ghi, PDF chỉ giữ quyền đọc. Nhận diện theo tên file không phân biệt hoa/thường; parser/bộ chuyển đổi kiểm tra dữ liệu trước khi hiển thị.
- **Lưu** ghi nội dung đã serialize vào URI gốc bằng ContentResolver, đóng stream rồi đọc lại xác minh toàn bộ byte. Chỉ sau đó mới cập nhật cache/metadata và báo thành công. Lưu lặp lại giữ một mục gần đây.
- Mở từ danh sách gần đây đọc nội dung hiện tại từ nguồn, kể cả khi file đã được sửa bằng app khác. Chọn lại cùng URI không thêm mục mới; hai file trùng tên có URI khác nhau vẫn riêng biệt.
- Mất quyền, file bị xóa/di chuyển hoặc lỗi ghi: báo lỗi, không báo thành công bằng cách chỉ lưu cache; editor giữ thay đổi chưa lưu. Người dùng có thể mở lại nguồn bằng **Mở tài liệu**. Ghi trực tiếp qua provider không có bảo đảm giao dịch/khôi phục nguyên tử khi thiết bị hoặc provider lỗi giữa chừng; cache nội dung trước đó vẫn được giữ.
- **Lưu thành bản mới** dùng ACTION_CREATE_DOCUMENT để chọn đích; Lưu tiếp theo cập nhật file mới đó. Hủy trình chọn đích không xác nhận đã lưu.
- Các tài liệu cũ chỉ có bản sao riêng chưa biết file nguồn. Lần Lưu đầu yêu cầu chọn file gốc để ghi thay đổi vào; không tự tìm theo tên. Cách đơn giản để bắt đầu lại: **Mở tài liệu** và chọn đúng nguồn.
- Android không cần quyền truy cập toàn bộ bộ nhớ. Nếu gỡ app/xóa dữ liệu thì mất danh sách và quyền đã giữ, file nguồn ngoài app vẫn tồn tại. iOS/macOS chưa chuyển sang ghi file nguồn, vẫn dùng bản sao riêng.

## Cache và metadata

Kho riêng vẫn nằm trong Documents/GenOffice/documents hoặc exports. Metadata phiên bản 1 bổ sung trường tùy chọn sourceUri bên cạnh ID, name, createdAt, updatedAt, sizeBytes và contentFile. Đường dẫn cache là tương đối để tương thích container iOS. sourceUri là liên kết Android, không phải đường dẫn tùy ý do renderer cung cấp.

DOC có thêm `legacyDoc` và `sourceHash`: cache/bản tạm là DOCX dùng nội bộ, tên và URI vẫn là DOC gốc. Lưu chuyển về DOC nhị phân trước khi ghi URI nguồn; giữ bản nhị phân lúc nhập ở `original-source.doc` trong kho riêng. Xem [DOC offline](legacy-doc.md).

Cache được ghi thành revision mới, metadata được thay sau khi nguồn ghi thành công. Giữ nội dung hiện tại và revision trước đó; không tạo dòng gần đây cho revision. Nếu ghi nguồn lỗi, bỏ revision đang staging và giữ metadata đã commit. Tài liệu cũ thiếu sourceUri vẫn đọc được. Giới hạn chọn ban đầu 20 MB; kết quả lưu/mở lại 32 MB.

## Kiểm thử

- Unit/widget: URI, tên và byte qua platform channel; metadata tồn tại qua repository restart; dedupe theo URI; cập nhật nguồn; chọn lại nguồn cho tài liệu cũ; lỗi nguồn giữ cache/metadata. Các ca kho riêng và asset server vẫn giữ lại.
- Android SourceDocumentTest: trình chọn tệp thật, file thử riêng trong Downloads, quyền persisted, ghi đè và cắt ngắn đúng file ngoài app, đọc lại nguồn sau ghi, thu hồi quyền phải báo lỗi. Test xóa file thử khi kết thúc; không sửa DOCX của người dùng.
- Flutter WebView regression: sửa/định dạng/bảng, lưu lặp lại, chuyển tài liệu và Save As; provider được mô phỏng bằng file test riêng để kiểm tra host/editor; lỗi ghi nguồn phải giữ dirty. Đây là bộ khác với test SAF native ở trên.
- Cần nghiệm thu thêm trên điện thoại thật/provider của thiết bị và đối chiếu Microsoft Word; chưa kiểm chứng reboot hoặc khởi động lại tiến trình Android.

Bài SAF cần emulator Android API 31+ để chuẩn bị fixture bằng shell stdin. Chạy mà không để bộ chạy connected-test tự gỡ app sau test (dùng emulator phát triển):

```powershell
cd android
.\gradlew.bat :app:assembleDebug :app:assembleDebugAndroidTest
cd ..
adb install -r build/app/outputs/apk/debug/app-debug.apk
adb install -r build/app/outputs/apk/androidTest/debug/app-debug-androidTest.apk
adb shell am instrument -w -e class com.example.gen_office_mobile.SourceDocumentTest com.example.gen_office_mobile.test/androidx.test.runner.AndroidJUnitRunner
```

Kết quả 21/10/2026: 23 unit/widget test đạt; 1 bài SAF thật trên Android API 37 đạt (ghi đúng file Downloads, xác minh byte, thu hồi quyền báo lỗi); 3 bài Flutter WebView đạt (bao gồm lỗi ghi nguồn giữ dirty). Chưa kiểm thử tiến trình Android khởi động lại/reboot thiết bị với quyền đã giữ; kiểm thử repository dựng lại và kiểm tra persisted grants đã đạt.
