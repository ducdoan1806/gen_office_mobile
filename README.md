# GenOffice Mobile

Ứng dụng Flutter chỉnh sửa DOCX, nhúng editor React/Tiptap của [GenOffice](https://github.com/genspark-ai/genoffice) bằng WebView. Editor, font và worker được đóng gói trong ứng dụng; không cần chạy web server bên ngoài.

Android có một nút **Mở tài liệu** cho DOCX, DOC và PDF. DOCX sửa/lưu trực tiếp; DOC dùng LibreOfficeKit offline để chuyển DOC ↔ DOCX khi mở/lưu; PDF có viewer offline để xem, tìm chữ và điều hướng trang. Phần AI vẫn là mock/stub, chưa kết nối API nhà máy. XLSX/PPTX chưa tích hợp thực tế. Ưu tiên Android; iOS hiện tạm hoãn.

## 1. Chuẩn bị môi trường

Cài các công cụ sau trên máy phát triển:

- **Git** để clone source.
- **Flutter SDK 3.47.7 / Dart 3.13.5**: môi trường kiểm thử Android ngày 22/10/2026. Kết quả iOS cũ dùng Flutter 3.35.3 được ghi riêng trong docs/ios-build.md.
- **Android Studio**, Android SDK và một Android emulator hoặc điện thoại Android bật USB debugging.
- Để build iOS: cần **macOS, Xcode và CocoaPods**. Dự án đặt deployment target **iOS 15.0 trở lên**, đồng bộ với Xcode 27. Đã kiểm thử luồng DOCX trên iPhone Simulator iOS 27; iPhone thật vẫn cần thiết lập signing và kiểm thử riêng.

Hướng dẫn chính thức: [cài Flutter](https://docs.flutter.dev/install), [thiết lập Android](https://docs.flutter.dev/platform-integration/android/setup), [thiết lập iOS](https://docs.flutter.dev/platform-integration/ios/setup).

Sau khi cài, thêm Flutter vào PATH rồi chạy:

```sh
flutter --version
flutter doctor -v
flutter doctor --android-licenses
```

Xử lý các mục thiếu liên quan đến nền tảng muốn chạy. Đường dẫn Android SDK riêng của mỗi máy nằm trong `android/local.properties`; file này không đưa lên Git. Flutter/Android Studio sẽ tạo cấu hình local khi thiết lập và chạy dự án.

**Không cần Node.js để chạy app từ source đã clone:** repo có sẵn assets editor đã build. Chỉ cần Node.js khi sửa hoặc build lại phần editor web, xem mục 6.

## 2. Clone dự án và cài dependency

```sh
git clone https://github.com/ducdoan1806/gen_office_mobile.git
cd gen_office_mobile
flutter pub get
```

Giữ nguyên `pubspec.lock` và `editor_web/package-lock.json` để dependency có thể được cài lặp lại. Không cần chạy `flutter create` lại hoặc copy thư mục build từ máy khác.

Chuẩn bị runtime DOC native một lần trước khi build Android (Windows/PowerShell; tải khoảng 174 MiB, kiểm SHA-256):

```powershell
powershell -ExecutionPolicy Bypass -File tool/setup_office_runtime.ps1
```

Runtime ARM64/x86_64 được lưu trong `android/office-runtime/` đã gitignore và được đóng gói vào APK. Chuyển đổi trên điện thoại không tải thêm thư viện, không cần máy chủ; APK lớn hơn do có LibreOfficeKit. Xem [DOC offline](docs/legacy-doc.md).

## 3. Chạy app trên Android

Mở Android Studio → **Device Manager**, tạo và khởi động emulator. Hoặc kết nối điện thoại đã bật USB debugging và chấp nhận quyền debug trên điện thoại.

Kiểm tra danh sách thiết bị:

```sh
flutter devices
```

Chạy trên thiết bị mong muốn, thay `<device-id>` bằng ID thực tế trong danh sách:

```sh
flutter run -d <device-id>
```

Ví dụ ID emulator thường gặp:

```sh
flutter run -d emulator-5554
```

Nếu chỉ kết nối một thiết bị phù hợp, có thể dùng `flutter run`.

### Thử chỉnh sửa DOCX

1. Bấm **Mở tài liệu**, chọn file trong Downloads hoặc thư mục khác bằng trình chọn tệp Android.
2. Dùng biểu tượng **thư mục** trên thanh Flutter để chọn DOCX/DOC/PDF khác từ thiết bị; app tự mở đúng màn hình và hỏi nếu có thay đổi chưa lưu.
3. Chỉnh sửa trong editor; thanh menu có thể cuộn ngang và nhãn không xuống dòng.
4. Dùng các nút **undo/redo** để hoàn tác/làm lại.
5. Bấm biểu tượng **lưu** để cập nhật chính file đã chọn. Dòng trạng thái xác nhận lưu vào file gốc khi ghi và đọc lại xác minh thành công.

Android giữ quyền đọc/ghi của file đã chọn qua Storage Access Framework. Danh sách gần đây lưu liên kết đến file gốc; khi mở lại, app đọc nội dung từ file đó. Các bản sao được nhập bằng phiên bản cũ cần mở lại file gốc bằng **Mở tài liệu**, hoặc chọn lại file gốc ở lần Lưu đầu tiên. **Lưu thành bản mới** mở trình chọn nơi lưu của Android. iOS/macOS vẫn dùng cơ chế bản sao riêng; share sheet chưa triển khai.

App tạo bản tạm cho DOCX đang sửa khoảng mỗi 5 giây. Nếu app bị đóng đột ngột, mở lại sẽ có mục **Khôi phục** để tiếp tục từ bản tạm gần nhất; bấm **Lưu** để cập nhật file gốc. Xem [khôi phục phiên](docs/session-recovery.md) về giới hạn và kiểm thử.

### Thử đọc PDF trên Android

Bấm nút chung **Mở tài liệu**, chọn PDF trong điện thoại (tối đa 20 MB). Dùng trang trước/sau hoặc nhập số trang; nhập chữ và bấm **Tìm**, dùng ↑/↓ để chuyển kết quả. Có nút phóng to/thu nhỏ/vừa trang. File xuất hiện trong danh sách gần đây và được mở lại từ nguồn. PDF chỉ đọc; file scan không có lớp text chưa tìm chữ được, file có mật khẩu chưa hỗ trợ. Xem [PDF viewer](docs/pdf-viewer.md).

## 4. Build APK và cài lên điện thoại

Tạo APK debug phục vụ phát triển/thử nghiệm:

```sh
flutter build apk --debug
```

APK nằm ở:

```text
build/app/outputs/flutter-apk/app-debug.apk
```

Có thể chép APK sang điện thoại để cài thủ công, hoặc dùng Android SDK Platform Tools:

```sh
adb devices
adb -s <device-id> install -r build/app/outputs/flutter-apk/app-debug.apk
```

Sau khi cài, mở **gen_office_mobile** trên điện thoại. Nếu lệnh `adb` không có trong PATH, dùng đường dẫn tới `platform-tools/adb` trong Android SDK của máy.

Để tạo APK release:

```sh
flutter build apk --release
```

**Cấu hình release hiện dùng khóa debug của template Flutter.** Cần thiết lập application ID, version và khóa ký riêng trước khi phân phối chính thức. Không commit keystore, `key.properties` hoặc mật khẩu ký app.

## 5. Chạy trên iOS / macOS

Trên macOS, kiểm tra Xcode/CocoaPods qua `flutter doctor -v`, khởi động iOS Simulator hoặc kết nối iPhone, rồi:

```sh
flutter pub get
flutter devices
flutter run -d <ios-device-id>
```

Nếu CocoaPods yêu cầu cài dependency thủ công:

```sh
cd ios
pod install
cd ..
```

Với iPhone thật, mở `ios/Runner.xcworkspace` trong Xcode và thiết lập **Signing & Capabilities → Team** theo tài khoản của bạn.

Dự án cũng có cấu hình WebView cho macOS: `flutter run -d macos`. iPhone Simulator iOS 27 đã được kiểm thử; iPhone thật và macOS vẫn cần xác nhận riêng. Editor WebView không hỗ trợ Flutter Web, Windows hoặc Linux ở bản tích hợp hiện tại.

## 6. Sửa và build lại editor web

Chỉ cần làm bước này khi thay đổi source trong `editor_web/`. Cài **Node.js 22.19.0 và npm 10.9.3** hoặc bản tương thích; đây là các phiên bản đã dùng trong quá trình phát triển.

Từ thư mục gốc dự án:

```sh
cd editor_web
npm ci
npm run dev
```

Mở URL Vite in ra để phát triển editor độc lập trong trình duyệt. Dừng dev server bằng Ctrl+C khi không dùng.

Sau khi sửa, build và cập nhật assets Flutter:

```sh
cd ..
node tool/bundle_editor.mjs
flutter run -d <device-id>
```

Lệnh đóng gói sẽ build web editor, đồng bộ JS/CSS/font/worker và license sang `assets/editor/`, đồng thời cập nhật `build-manifest.json`. Hãy commit cả source editor và assets mới. Không sửa trực tiếp các file được sinh trong `assets/editor/assets/`.

## 7. Kiểm tra mã và kiểm thử

Từ thư mục gốc:

```sh
flutter analyze
flutter test
```

Kiểm thử WebView thực tế trên Android emulator:

```sh
flutter test integration_test/docx_webview_test.dart -d <device-id> --reporter expanded
```

Kiểm thử editor web (cần cài dependency bằng `npm ci` trước):

```sh
cd editor_web
npm test
npm run build
npm run test:e2e:production
```

Cấu hình Playwright mặc định dùng Chrome tại đường dẫn macOS. Trên máy khác, đặt biến `CHROME_PATH` trỏ tới file thực thi Chrome đã cài, ví dụ trên Linux:

```sh
CHROME_PATH=/usr/bin/google-chrome npm run test:e2e:production
```

Trên PowerShell:

```powershell
$env:CHROME_PATH = 'C:\Program Files\Google\Chrome\Application\chrome.exe'
npm run test:e2e:production
```

Đã kiểm thử trên Android emulator và iPhone Simulator iOS 27: mở DOCX → chèn tiếng Việt → undo/redo → ghi file qua native → mở lại file đã lưu. Việc chèn chữ tự động không thay thế kiểm thử bàn phím/IME tiếng Việt trên điện thoại thật.

## 8. Cấu trúc dự án

```text
lib/
  app/                       # Cấu hình ứng dụng và dependency
  core/config/               # Cấu hình build-time
  features/
    documents/               # Metadata và màn hình thư viện mẫu
    editor/                  # WebView, bridge, transport bytes và lưu DOCX
    ai/                      # FactoryAiService mock/API stub, chưa kết nối
editor_web/
  src/                       # Host adapter trình duyệt/mobile
  vendor/                    # Renderer và engine upstream, kèm license
  tests/                     # Kiểm thử engine
  e2e/                       # Kiểm thử trình duyệt và protocol mobile
assets/editor/               # Runtime editor đã build, được commit
assets/samples/              # DOCX mẫu
integration_test/            # Kiểm thử WebView trên thiết bị
android/ ios/ macos/         # Cấu hình nền tảng native
tool/bundle_editor.mjs       # Build và đóng gói editor vào Flutter
docs/                       # Tài liệu kiến trúc và bridge
```

Chi tiết: [bridge mobile](docs/mobile-webview.md), [tách editor khỏi Electron](docs/docx-web-extraction.md), [editor web](editor_web/README.md), [nguồn upstream và license](editor_web/VENDOR.md).

## 9. Giới hạn hiện tại

- DOCX có chỉnh sửa/lưu; PDF có xem/tìm kiếm/điều hướng trên Android. XLSX/PPTX vẫn là màn hình mẫu.
- Giới hạn import 20 MB và export 32 MB. Bộ nhớ khi giải nén/hiển thị còn tùy nội dung file.
- DOCX đã có bản tạm và phục hồi sau mất tiến trình; chỉ bảo vệ đến checkpoint hoàn chỉnh gần nhất. File nguồn Android được lưu qua SAF; cache và bản tạm riêng có thể mất khi gỡ ứng dụng. Xem [khôi phục phiên](docs/session-recovery.md).
- Ribbon gốc đã hỗ trợ cuộn ngang; vẫn cần tối ưu cảm ứng và kiểm tra trên nhiều điện thoại thật.
- Các tích hợp Electron như Zotero, CLI/MCP, mã hóa file và xuất PDF native chưa được chuyển sang mobile.
- AI chưa kết nối. App dùng loopback trên chính thiết bị để phục vụ editor; không cần API AI hoặc web server bên ngoài cho việc chỉnh sửa DOCX.

## Source control và license

`.gitignore` loại các thư mục build/cache, `node_modules`, output Vite, báo cáo kiểm thử, cấu hình máy và file khóa ký. Assets runtime và hai lockfile vẫn được commit để clone xong có thể cài và chạy.

Source/renderer/engine GenOffice được lấy từ commit `1cb2925afe173b266c1545a3871a397429e11b7e`, với LICENSE/NOTICE và license font được giữ trong `editor_web/vendor/` và `assets/editor/`. Không bao gồm thư mục enterprise `ee/`. Xem [VENDOR.md](editor_web/VENDOR.md) trước khi cập nhật hoặc phân phối phần upstream.

## Quy trình phát triển

- Nhánh `dev`: phát triển, sửa lỗi và kiểm thử.
- Nhánh chính hiện tại `codex/initial-import`: giữ phiên bản đã được chủ dự án chấp thuận.
- Chỉ đưa thay đổi từ `dev` sang nhánh chính khi chủ dự án yêu cầu rõ ràng; build/test thành công chưa phải là chấp thuận merge.

Sau khi clone, chuyển sang nhánh phát triển trước khi sửa code:

```sh
git fetch origin
git switch dev
```

Push công việc phát triển:

```sh
git push origin dev
```

### Lưu ý build iOS với Xcode 27

Dự án yêu cầu deployment target iOS 15.0 cho Runner, Flutter framework và Pods. `pod install` tự đồng bộ target của plugin trong `post_install`; không sửa trực tiếp file trong `ios/Pods/`.

Với Flutter 3.35, Debug Simulator dùng SDK 27 được cấu hình build `arm64` (Xcode 27 chạy trên Apple Silicon) để tránh lỗi `lipo -verify_arch` nhiều kiến trúc của Xcode 27. Cấu hình này không đổi kiến trúc của bản device hoặc Release/Profile. Lỗi upstream: https://github.com/flutter/flutter/issues/188461.

```sh
flutter pub get
cd ios
pod install
cd ..
flutter build ios --simulator --debug
```

Khi chạy bằng Xcode, mở `ios/Runner.xcworkspace` để có đầy đủ CocoaPods.

Ứng dụng cũng đã khai báo `UIApplicationSceneManifest` với `FlutterSceneDelegate`, và `AppDelegate` đăng ký plugin bằng callback `FlutterPluginRegistrant` tương thích Flutter 3.35. Đây là phần cần thiết để app build bằng SDK iOS 27 không crash lúc mở. Xem [hướng dẫn xử lý build iOS](docs/ios-build.md).
