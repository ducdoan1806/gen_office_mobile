# GenOffice Docs — standalone React/Tiptap editor

The default page now runs the original GenOffice Docs React/Tiptap renderer, ribbon, document schema, conversion, pagination preview and DOCX patch/save pipeline in a normal browser. Electron main/preload processes are not used.

## Run

```sh
npm ci
npm run dev
```

Open the displayed URL. Use the host file input or Open button to import DOCX. The original ribbon supports editing text, formatting, paragraphs and tables. Use Download DOCX or Ctrl/Cmd+S to export. The browser downloads a copy; it does not overwrite your original file.

```sh
npm test
npm run test:e2e
npm run build
npm run test:e2e:production
```

End-to-end tests use locally installed macOS Chrome by default. Set CHROME_PATH for another executable. Build output is dist/ with relative asset paths, for later WebView integration. Serve dist/ over HTTP using `npm run preview`; loading index.html directly using file:// is not supported by module workers.

## Architecture

- `src/rich-main.ts`: installs the browser host before dynamically loading the original React entrypoint.
- `src/platform/browser-host.ts`: explicit renderer host adapter for file dialogs, virtual document paths, Blob byte handoff, downloads, lifecycle/menu events, browser print and image picking. The legacy `window.desktop` name is only a compatibility contract: it has no IPC, filesystem or Node access.
- `vendor/docs/renderer`: upstream App, ribbon, Tiptap schema/extensions, parsing worker, DOCX↔ProseMirror conversion, formatting, tables, pagination and save pipeline.
- `vendor/docx-engine`: upstream OOXML parser and patch writer.
- `vite.config.ts`: package entrypoint mappings and a Node/Electron rejection guard for both main and worker bundles.
- `prototype.html`: keeps the earlier minimal paragraph prototype separately; this is no longer the default editor.
- `pdf.html` / `src/pdf`: separate read-only PDF.js viewer for the Android host, with full-document search, highlights, page navigation and zoom. Worker/fonts/CMaps/WASM are packaged by `tool/bundle_editor.mjs`; see [PDF viewer](../docs/pdf-viewer.md).

## Browser capabilities and limits

Implemented: DOCX import (20 MB limit), new document, rich-text/paragraph/table editing through the original renderer, undo/redo, image selection, manual DOCX export, in-session recent files and unsaved-change confirmation.

Unsupported desktop integrations return a failure or are unavailable: OS paths/windows, encrypted-file open/save, native spellcheck dictionary controls, Zotero, Electron PDF/image export, MCP server and CLI. Browser print uses window.print; its layout is browser-dependent. Recovery copies are explicitly unavailable and autosave starts off; sessions remain in memory. The full desktop UI is retained, so some desktop-specific commands can still be visible and will report unsupported.

AI is disabled in this web host; no model/API is connected. Flutter's existing FactoryAiService files are unchanged. CSP blocks external HTTP endpoints and remote document resources. No secrets are embedded.

Fonts are bundled with upstream licenses; native desktop font metrics fall back to browser/bundled metrics. This is not a guarantee of pixel-identical Word pagination. Android/iOS WebView embedding, touch optimization and device testing are the next phase, not part of this extraction.

## Verification

Session tests check original bytes, Vietnamese surgical patches, preserved non-document ZIP entries, readonly structures, reset and invalid input. Browser tests exercise the original React editor: italic text, new paragraphs, table-cell editing, undo/redo, DOCX download/reopen, and no external network requests/page errors. Representative upstream mixed-content and multi-section fixtures are included for unchanged export checks.

See VENDOR.md for source revision, licenses and integration patches. `.npmrc` sets legacy-peer-deps to avoid a peer resolver crash in npm 10.9.3.

## Flutter integration

The mobile host in src/platform/mobile-host.ts is activated by `?mobile=1`. `node ../tool/bundle_editor.mjs` from this directory builds and packages the runtime into Flutter assets. See ../docs/mobile-webview.md for the bridge and native platform configuration. The regular browser page retains its standalone behavior.
