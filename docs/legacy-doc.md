# DOC offline trên Android

Một nút **Mở tài liệu** nhận DOCX/DOC/PDF. DOCX và DOC mở editor; PDF mở viewer. Nút thư mục trong editor dùng cùng trình chọn, có kiểm tra thay đổi chưa lưu.

## Mở và lưu DOC

DOC Word 97–2003 là định dạng nhị phân, không phải ZIP/OOXML như DOCX. LibreOfficeKit native chuyển DOC sang DOCX để editor hiện tại xử lý. URI, tên hiển thị và quyền đọc/ghi vẫn gắn với DOC nguồn. **Lưu** chuyển kết quả DOCX ngược về DOC nhị phân rồi ghi/đọc xác minh đúng URI gốc. **Lưu thành bản mới** xuất DOCX theo tên/đích đã chọn.

Cache và checkpoint là DOCX; metadata có `legacyDoc`, `sourceHash`. Hash phục hồi được tính từ DOC nguồn trước chuyển đổi để không báo nhầm xung đột do ZIP/timestamp của bộ chuyển đổi. Bản DOC lúc nhập được giữ riêng trong `original-source.doc`, không tạo thêm mục thư viện. Đây là dữ liệu riêng, mất khi gỡ/xóa app; chưa có giao diện khôi phục bản nhị phân này.

Lỗi chuyển đổi xảy ra trước ghi nguồn; giữ cache/bản tạm và không báo Lưu thành công. Ghi qua SAF vẫn có giới hạn giao dịch của provider như DOCX. Chuyển đổi có thể chuẩn hóa bố cục, font, trường và đối tượng; không bảo đảm mọi DOC có bố cục giống Word. Macro và active content bị tắt trong profile converter. File có mật khẩu chưa được hỗ trợ.

## Runtime

- LibreOfficeKit 26.2.6.3 native từ các APK F-Droid đã chốt SHA-256; không gọi Word/WPS hoặc server.
- Service `:doc_converter` riêng, không export. Binder chỉ chuyển ID công việc; byte lớn đi qua cache riêng, tránh giới hạn giao dịch Binder.
- Một hàng đợi native; giới hạn input/output 32 MB, timeout 180 giây. Khi timeout chỉ dừng process converter. Chọn file ban đầu vẫn giới hạn 20 MB.
- Đang đóng gói ARM64 và x86_64; app DOCX/PDF vẫn dùng nền tảng hiện có. DOC trên CPU 32-bit được báo chưa hỗ trợ. ARM64 chưa chạy nghiệm thu trên máy thật.
- Runtime/font/config đóng gói trong APK nên chạy offline. Đổi lại APK và dữ liệu app lớn hơn đáng kể. Chuẩn bị trên máy build một lần: `powershell -ExecutionPolicy Bypass -File tool/setup_office_runtime.ps1`. PowerShell 7 có thể dùng `pwsh -File ...`.
- `android/office-runtime/` là build dependency đã gitignore; không commit các `.so` cỡ lớn. Không cần tải runtime từ điện thoại. Native bindings, bản sửa Context và thông tin source/license được giữ trong `android/app/src/main/java/org/libreoffice/kit/`; thông báo license nằm trong assets Android.

## Kiểm chứng 22/10/2026

- 39 unit/widget test đạt: nút chung, giữ URI/tên DOC, chuyển đổi trước ghi nguồn, lỗi chuyển đổi giữ nguồn/cache, bản DOC gốc riêng và metadata phục hồi giữ định dạng/hash.
- Integration trên Android emulator: từ nút chung mở DOC nhị phân, sửa tiếng Việt, lưu đúng DOC, đối chiếu chữ/bảng trong kết quả, mở lại nội dung đã sửa; một mục thư viện. Converter là native thật; provider nguồn của bài Flutter được mô phỏng bằng byte fixture riêng.
- Hồi quy trên emulator: 3 bài PDF (gồm mở PDF từ editor bằng nút chung) và 4 bài DOCX đạt; analyze không có lỗi.
- Lặp lại cùng luồng khi tắt cả Wi-Fi và dữ liệu di động đạt; đã khôi phục trạng thái kết nối sau test. Không cần máy chủ chuyển đổi.
- Fixture chuẩn có tiếng Việt, bảng 2×2 và header: `assets/samples/legacy-conversion.docx`. Fixture tối giản `factory-demo.docx` có cấu trúc bảng thiếu thuộc tính mà LibreOffice chuẩn hóa thành đoạn, nên không dùng để khẳng định giữ bảng DOC.
- Native instrumentation: chuyển DOC ↔ DOCX giữ chữ tiếng Việt/bảng, picker hỗn hợp ghi đè DOCX và PDF chỉ đọc đều đạt trên emulator.
- Chưa nghiệm thu bộ DOC thực tế của nhà máy, điện thoại ARM64 hoặc đối chiếu Microsoft Word; iOS tiếp tục hoãn.
