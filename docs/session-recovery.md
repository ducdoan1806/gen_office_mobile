# Bước 6 — bản tạm và khôi phục phiên DOCX

## Hành vi

- Với DOCX đã mở, Flutter yêu cầu checkpoint mỗi 5 giây khi editor sẵn sàng; khi app chuyển nền cũng thử tạo checkpoint. Chỉ tài liệu có thay đổi mới được serialize.
- Bản tạm là DOCX đầy đủ, dùng cùng engine serialize với Lưu, gồm nội dung, định dạng, bảng và các phần OOXML được giữ lại. Không gọi luồng Save/reparse và không xóa trạng thái dirty hay ghi vào file nguồn.
- Màn hình chính hiển thị **Có tài liệu chưa lưu** cùng tên, thời gian và nút **Khôi phục**/**Bỏ bản tạm**. Mở một tài liệu đang có bản tạm cũng hỏi khôi phục, bỏ bản tạm để mở gốc hoặc để sau.
- Khôi phục mở bản tạm với trạng thái chưa lưu. Bấm **Lưu** mới cập nhật file gốc đang liên kết. Nếu lúc khôi phục phát hiện nguồn khác hash ban đầu hoặc không đọc được nguồn, Lưu yêu cầu xác nhận ghi đè; có thể dùng Lưu thành bản mới để giữ cả hai.
- Lưu thành công dọn bản tạm tương ứng. Lưu bị lỗi/hủy vẫn giữ bản tạm và dirty. Đóng/mở tài liệu khác bằng lựa chọn **Bỏ thay đổi** dọn bản tạm; hủy hộp thoại giữ nguyên dữ liệu. Chuyển tài liệu và lưu được điều phối với checkpoint để tránh ghi nhầm đích hoặc tạo lại bản tạm sau khi đã bỏ.

## Lưu trữ và giới hạn

Kho riêng: `Documents/GenOffice/recovery/<SHA256(documentId)>/<revision>/`. Mỗi revision gồm `content.docx` và `snapshot.json`; metadata giữ ID, tên, tham chiếu nguồn/cache, hash nguồn ban đầu, hash nội dung và thời gian.

Ghi vào thư mục staging, flush cả file và metadata rồi rename để công bố. Bản ghi dở không xuất hiện trong danh sách. Giữ hai revision hoàn chỉnh; khi bản mới nhất hỏng checksum/metadata, thử bản trước đó. Khi không đọc được revision nào, báo lỗi và giữ dữ liệu; khi mở tài liệu, có thể chọn rõ ràng bỏ bản tạm hỏng để mở file gốc. Bỏ bản tạm rename nhóm ra ngoài danh sách trước khi dọn file, tránh bản đã bỏ xuất hiện lại nếu bị dừng giữa chừng. Tên tài liệu và đường dẫn từ metadata không được dùng để xóa file nguồn.

Giới hạn mỗi snapshot 32 MB. Snapshot là bản gần nhất đã ghi hoàn chỉnh: các thay đổi sau checkpoint cuối, trong lúc nhập IME, đang tải tài liệu theo từng phần hoặc khi lưu tạm lỗi có thể chưa được bảo vệ. Chuyển nền chỉ là best effort; force-stop không cho app cơ hội ghi thêm. File trắng mới chưa được lưu lần đầu không nằm trong luồng phục hồi này. Undo history, vị trí con trỏ và cuộn không được giữ qua lần khôi phục.

Đây là dữ liệu riêng của app, có thể mất khi gỡ app/xóa dữ liệu. Không tự động ghi file nguồn, không đồng bộ đám mây và không thay thế sao lưu bên ngoài.

## Kiểm chứng ngày 21/10/2026

- 33 unit/widget test đạt, gồm restart repository, staging ghi dở, checksum hỏng và fallback, metadata hỏng, giới hạn, trùng tên, hàng đợi ghi/bỏ giữa các store, UI khôi phục/bỏ/hủy và bảo vệ endpoint phục hồi. HTTP recovery thành công không tăng revision Lưu và không gọi bộ ghi file nguồn.
- Bài integration hai tiến trình trên Android emulator đạt: tạo snapshot bằng timer thật, kiểm tra nguồn chưa đổi; host gọi `adb shell am force-stop com.example.gen_office_mobile`; chạy tiến trình mới và khôi phục qua màn hình chính. Đối chiếu nội dung DOCX, dirty/close guard, nguồn bị sửa bên ngoài, hủy ghi đè, lỗi ghi giữ bản tạm, Lưu thành công cập nhật nguồn rồi xóa bản tạm. Nguồn bài test được mô phỏng qua platform channel bằng file fixture riêng, không sửa tài liệu người dùng. Force-stop mô phỏng mất tiến trình; chưa ép LMK hoặc crash native thật.
- Bốn bài WebView đạt qua các lượt chạy: ba bài hồi quy mở/sửa/định dạng/bảng/undo/redo/Lưu/chuyển tài liệu/Save As và một bài kiểm tra bản tạm hỏng phải được người dùng bỏ rõ ràng trước khi mở gốc.
- Chưa chạy lại chức năng phục hồi trên iOS hoặc điện thoại thật; các phần nghiệm thu này tiếp tục hoãn.

## Chạy lại bài mất tiến trình

Dùng emulator phát triển, không gỡ app hoặc dùng `connectedDebugAndroidTest`. Thay `<run-id>` bằng ID mới mỗi lần để tách fixture:

```powershell
flutter test integration_test/recovery_process_test.dart -d emulator-5554 --dart-define=RECOVERY_PHASE=prepare --dart-define=RECOVERY_TEST_RUN=<run-id>
```

Khi log hiện `GENOFFICE_RECOVERY_PREPARED`, ở terminal khác chạy:

```powershell
adb shell am force-stop com.example.gen_office_mobile
```

Lệnh prepare báo lost connection/did not complete là chủ ý vì tiến trình bị dừng. Sau đó chạy:

```powershell
flutter test integration_test/recovery_process_test.dart -d emulator-5554 --dart-define=RECOVERY_PHASE=restore --dart-define=RECOVERY_TEST_RUN=<run-id>
```

Restore phải đạt và tự dọn thư mục fixture riêng. Bài này được bỏ qua khi không truyền phase để không làm hỏng lượt chạy integration thông thường. Sau khi kiểm thử, chạy `flutter run -d emulator-5554` để mở lại app bình thường.
