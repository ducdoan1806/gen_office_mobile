# Sheets và Slides trên Android

Source: https://github.com/genspark-ai/genoffice — commit `1cb2925afe173b266c1545a3871a397429e11b7e`, cùng phiên bản với DOCX.

## Giao diện gốc GenOffice

Bản Android tải trực tiếp `App`, entrypoint React, CSS, ribbon và các thành phần renderer của **Sheets**, **Slides** và **PDF** từ source gốc. Không dùng màn hình XLSX/PPTX rút gọn trước đây. Giữ màu ứng dụng, thanh công thức/lưới/sheet tabs của Sheets, canvas/danh sách slide/ghi chú của Slides và thumbnail/tìm kiếm/điều hướng của PDF. Thanh tab và công cụ hỗ trợ vuốt ngang trên điện thoại; AI tiếp tục được ẩn theo phạm vi đã hoãn.

- XLSX dùng lưới/công thức Univer, journal và các handler định dạng/lưu của nguyên App; đọc OOXML bằng gateway, cung cấp metadata cho renderer qua adapter trình duyệt. Lưu sử dụng ánh xạ `writeWorkbookTo` và planner/assembler gốc của `xlsx-gateway`.
- PPTX dùng toàn bộ App/SlideCanvas/TextEditOverlay gốc, cùng `pptx-engine`, `pptx-ops` và `pptx-render`. Adapter chuyển thao tác từ API desktop thành transaction engine và quản lý lịch sử trong bộ nhớ.
- PDF dùng App/ribbon/thumbnail/search gốc và PDF.js offline; vẫn chỉ đọc. Endpoint lưu PDF tiếp tục bị từ chối.
- Không chạy Electron hoặc Rust sidecar. Filesystem và Lưu/Lưu thành bản mới đi qua Flutter → SAF Android. Các lệnh desktop chưa có adapter báo chưa hỗ trợ; không giả lập lưu thành công.

## Luồng tài liệu

Một nút **Mở tài liệu** nhận DOC/DOCX/PDF/XLS/XLSX/PPT/PPTX/CSV. Xem [định dạng cũ và CSV](legacy-office-formats.md). Lưu ghi đè URI nguồn đang mở; Lưu thành bản mới chọn đích bằng Android. XLSX/PPTX giữ định dạng, có undo/redo và bản tạm phục hồi. Với XLSX/PPTX, Lưu không thay đổi giữ byte gốc; XLS/PPT dùng chuyển đổi định dạng. Chưa hỗ trợ tạo một tài liệu XLSX/PPTX mới từ menu desktop; không dùng thao tác này để ghi đè tài liệu nguồn đang mở.

Đây là port giao diện gốc, chưa phải toàn bộ dịch vụ desktop: chưa có Rust streaming/IronCalc fallback, importer metadata XLSX nâng cao (biểu đồ, pivot, điều kiện, validation, liên kết và theme) chưa đầy đủ; các phần ZIP không sửa được giữ lại khi lưu. Các công cụ hình ảnh/biểu đồ/animation/xuất/in và tích hợp hệ điều hành chưa được nghiệm thu đầy đủ. AI và iOS tiếp tục hoãn.

## Kiểm thử

22/10/2026: bộ kiểm thử trình duyệt cho giao diện gốc kiểm tra sửa B2, tính công thức D2, định dạng qua ribbon, lưu/mở lại XLSX; sửa chữ qua overlay canvas, thêm slide, undo/redo, lưu PPTX; tìm kiếm PDF và vuốt thanh tab ở kích thước điện thoại. Các phần biểu đồ/ảnh/ghi chú không sửa được đối chiếu ZIP. Unit test kiểm tra dữ liệu adapter theo schema preload gốc và pipeline lưu XLSX.

Sau đổi giao diện, 9 ca riêng biệt trên Samsung Android 16 đạt: 2 XLSX/PPTX, 3 PDF, 4 DOCX hồi quy. Bản phục hồi PowerPoint chốt đúng đoạn chữ còn trong overlay. Kết quả kiểm thử Samsung trước lần đổi giao diện: 43 Flutter test, 2 integration XLSX/PPTX và SAF native (4 phase) đạt; xem [QA Android](android-device-qa.md). Các kiểm thử tự động không thay thế nghiệm thu bàn phím tiếng Việt, chọn chữ và cảm ứng bằng tay.

## Nguồn và giấy phép

Source vendored giữ Apache-2.0, NOTICE và Unicode license trong `editor_web/vendor`. Các patch tích hợp được ghi trong [VENDOR.md](../editor_web/VENDOR.md). `assets/editor/THIRD-PARTY-LICENSES.txt` được tạo lại khi đóng gói. Runtime, worker, font, CMap và WASM nằm trong APK; không tải thư viện từ CDN.

23/10/2026: bộ cảm ứng và XLS/PPT/CSV đã bổ sung; xem [luồng định dạng và cảm ứng](legacy-office-formats.md). Bộ tổng hợp Android đạt 13 ca, gồm ba định dạng mới và DOC/DOCX/PDF hồi quy; 51 test Flutter, 8 web/engine, 5 trình duyệt production và analyze đạt. Các giới hạn nâng cao/đối chiếu Office vẫn giữ nguyên.
