# Step 2 — Flutter WebView integration

## Runtime

1. Flutter starts a session-scoped HttpServer bound to 127.0.0.1 on a random port.
2. WebView loads `/<token>/index.html?mobile=1` from bundled assets. No external web server, npm process or factory server is required on the phone.
3. The mobile host installs the allowlisted `genOfficeMobile.receive` endpoint before the original renderer loads.
4. The original React lifecycle emits readiness after its editor is mounted. Flutter sends correlated open/save/undo/redo/status commands.
5. DOCX bytes are fetched from a tokenized document URL; no full-document base64 string crosses the JS channel.
6. On save, original ProseMirror→DOCX serialization POSTs bytes to the local export endpoint. Flutter flushes a temporary file and renames it to the final export path before returning success. JS then completes the original save/reparse pipeline and returns the command result.

## Protocol v1

JS to Flutter `GenOfficeHost`: ready {protocol:1}, reply {id,ok,value/error}, saved {name,path}, pickDocument, confirmRequired and error.

Flutter to JS: {id,method,args}; methods are open, save, undo, redo, status and new. Only serialized JSON data is passed to the fixed receive function. No generic filesystem, URL fetch or script execution command is exposed.

The App integration hook reuses loadFile/save/undo/redo and is active only while the real editor is ready. The old window.desktop name remains a compatibility interface, with browser/mobile implementations instead of Electron IPC.

## Platform configuration

Android: INTERNET permission enables loopback access. Network security config permits HTTP only for 127.0.0.1; non-loopback cleartext remains disabled. Existing adjustResize and Flutter resizeToAvoidBottomInset keep the WebView above the keyboard.

iOS: NSAllowsLocalNetworking permits local resources. macOS additionally has client/server and user-selected read-only sandbox entitlements. External navigation is blocked. JS validates document URLs against the session origin/path. CSP restricts remote resources, the loopback server rejects requests without the session token, and exports require a matching Origin.

## Current behavior and limits

- The app opens its persistent document library; both the library import button and editor folder button use native file_selector. Imported DOCX bytes are copied into app-private Documents before opening. Bundled samples remain available to tests.
- Native save creates a new app-private export with library metadata. Imported and newly exported documents are listed after restart. No original file overwrite, user-selected destination or share sheet yet. See [document library](document-library.md).
- Flutter back/open checks the renderer's composite dirty state and asks before discarding.
- Original toolbar download actions use native saving in mobile mode. Desktop print/image-picker integrations remain unavailable in mobile mode.
- Recovery/autosave is not promised. 20 MB import / 32 MB export limits apply; saved files up to 32 MB can reopen from the library. Expanded OOXML memory also depends on upstream parsing.
- Flutter's AI files are unchanged and editor AI remains disabled.
- Original desktop controls need real-device touch and Vietnamese IME QA. The iPhone Simulator running iOS 27 has passed the DOCX roundtrip integration test; physical iOS devices and macOS still need validation.

## Tests

Unit tests exercise private asset/document paths, navigation restriction, persistence-before-acknowledgement and cross-origin write rejection. Native integration_test exercises actual Android WebView, Vietnamese text insertion, undo/redo, saving to native filesystem and reopening exported bytes. Text insertion is automated through the WebView DOM; it is not a substitute for real keyboard/IME testing. Browser tests additionally cover native protocol save failures and external URL rejection.
