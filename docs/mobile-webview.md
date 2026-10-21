# Step 2 — Flutter WebView integration

## Runtime

1. Flutter starts a session-scoped HttpServer bound to 127.0.0.1 on a random port.
2. WebView loads `/<token>/index.html?mobile=1` from bundled assets. No external web server, npm process or factory server is required on the phone.
3. The mobile host installs the allowlisted `genOfficeMobile.receive` endpoint before the original renderer loads.
4. The original React lifecycle emits readiness after its editor is mounted. Flutter sends correlated open/save/undo/redo/status commands.
5. DOCX bytes are fetched from a tokenized document URL; no full-document base64 string crosses the JS channel.
6. On save, original ProseMirror→DOCX serialization POSTs bytes to the local export endpoint. On Android Flutter writes the selected source URI through ContentResolver, reads back to verify bytes, then commits cached content and recent-file metadata before acknowledging success. Normal Save updates the current library ID; Save As / a new document sends `mode=copy` to create a separate ID. JS then completes the original save/reparse pipeline and returns the command result.

## Protocol v1

JS to Flutter `GenOfficeHost`: ready {protocol:1}, reply {id,ok,value/error}, saved {name,path}, pickDocument, confirmRequired and error.

Flutter to JS: {id,method,args}; methods are open, save, undo, redo, status and new. Only serialized JSON data is passed to the fixed receive function. No generic filesystem, URL fetch or script execution command is exposed.

The App integration hook reuses loadFile/save/undo/redo and is active only while the real editor is ready. The old window.desktop name remains a compatibility interface, with browser/mobile implementations instead of Electron IPC.

## Platform configuration

Android: INTERNET permission enables loopback access. Network security config permits HTTP only for 127.0.0.1; non-loopback cleartext remains disabled. Existing adjustResize and Flutter resizeToAvoidBottomInset keep the WebView above the keyboard.

iOS: NSAllowsLocalNetworking permits local resources. macOS additionally has client/server and user-selected read-only sandbox entitlements. External navigation is blocked. JS validates document URLs against the session origin/path. CSP restricts remote resources, the loopback server rejects requests without the session token, and exports require a matching Origin.

## Current behavior and limits

- Android uses ACTION_OPEN_DOCUMENT with persisted read/write grants. Recent entries retain the source content URI; opening reads current source bytes. Private storage holds metadata/cache. iOS/macOS continue to use file_selector and private copies. Bundled samples remain available to tests.
- Android Save updates the actual source file; errors keep the renderer dirty and never silently fall back to cache. Legacy entries require selecting their original file once. Save As uses ACTION_CREATE_DOCUMENT and subsequent Save follows that new URI. Source URIs stay in the native host, outside the renderer. No broad storage permission is requested. See [document library](document-library.md).
- Flutter back/open checks the renderer's composite dirty state and asks before discarding.
- Original toolbar download actions use native saving in mobile mode. Desktop print/image-picker integrations remain unavailable in mobile mode.
- Recovery/autosave is not promised. 20 MB import / 32 MB export limits apply; saved files up to 32 MB can reopen from the library. Expanded OOXML memory also depends on upstream parsing.
- Flutter's AI files are unchanged and editor AI remains disabled.
- Original desktop controls need real-device touch and Vietnamese IME QA. The iPhone Simulator running iOS 27 has passed the DOCX roundtrip integration test; physical iOS devices and macOS still need validation.
- Mobile ribbon buttons and table-size grid cells now use 44 px touch targets, with taller ribbon rows and a scrollable table picker. See [basic editing](basic-editing.md) for automated checks and pending real-device/Word acceptance.

## Tests

Unit tests exercise private asset/document paths, navigation restriction, persistence-before-acknowledgement and cross-origin write rejection. Native integration_test exercises actual Android WebView, Vietnamese text insertion, undo/redo, text/paragraph formatting, font size, existing table-cell editing, inserting a 2×2 table, saving to native filesystem and reopening exported bytes. Assertions inspect DOCX ZIP/XML and touch-target sizes. An optional private-corpus test compares untouched OOXML parts on real documents without bundling them into the app. Text selection, input and ribbon clicks are automated through the WebView DOM; they do not replace real touch/keyboard/IME testing. Browser tests additionally cover native protocol save failures and external URL rejection; those browser tests were not rerun successfully in the Windows sandbox. See [basic editing](basic-editing.md).
