# Upstream provenance and integration changes

Source: https://github.com/genspark-ai/genoffice
Commit: 1cb2925afe173b266c1545a3871a397429e11b7e

Snapshots: packages docx-engine, pptx-engine, zip-gate, ui, i18n, agent-core, ai-provider, pptx-render, font-metrics, electron-utils and project-store under vendor/; Docs renderer/shared under vendor/docs/. Supporting provider/agent code is retained only as upstream transitive support; the AI panel is replaced at bundle resolution and no provider runs. Desktop-only source may exist in the snapshot but is not bundled. No ee/ enterprise code is included.

Integration changes to upstream source:

1. `vendor/docs/renderer/App.tsx`: AI sidebar initially closed and disabled for the browser host; allowlisted host command hook calls original open/save/undo/redo and reports readiness.
2. `vendor/docs/renderer/doc-bytes.ts`: release one-shot Blob handoff URLs after fetch.
3. `vendor/docs/renderer/editor/shape-svg.ts`: replace a monorepo-relative import with its package export.
4. `vendor/docs/renderer/components/Ribbon.tsx`: expose pressed states for text marks and paragraph alignment. `ribbon-insert-tab.tsx`: label table-size choices for accessibility.

Build aliases replace the AiPanel module with src/platform/disabled-ai-panel.tsx and select browser-only package exports. Source engine files remain unchanged. The browser host adapter and rich-main entrypoint are new integration code. The original desktop App is used; it is not replaced by a rewritten editor.

Upstream LICENSE (Apache-2.0), NOTICE and LICENSE-UNICODE.txt are retained. Bundled font license files and embedded third-party headers remain in their source locations. tests/fixtures contains two upstream pagination corpus DOCX files from apps/docs/tests/pagination-corpus/docx.

## Android full UI port — 2026-10-22

Additional snapshots: `sheets/src`, `slides/src`, `pdf/src`, `xlsx-gateway/src`, `pptx-ops/src`, plus `pdf2docx/src/script.ts` for PDF Unicode classification, at the same pinned commit above. Only free renderer dependencies are bundled; no enterprise modules, Electron main/preload process or Rust sidecar runs on Android.

- Sheets/Slides `renderer/App.tsx`: stable mobile command boundary calling original open/save/history handlers; expose existing Univer facade for host integration. `renderer/main.tsx`: import scoped mobile CSS.
- PDF `renderer/App.tsx`: force Android read-only mode, label it accurately, report load/error through the existing Flutter channel. The readiness effect is unconditional before early returns. `renderer/main.tsx`: mobile CSS. `view-config.ts`: offline PDF resource base and Android render budget. `ocr-layer.tsx`: relocate Unicode helper import to the vendored location.
- `src/upstream/sheets-save.ts` is extracted from original `sheets-main.ts::writeWorkbookTo`, returning the canonical gateway payload for browser serialization. Other browser host adapters are integration code.
- AI panel imports resolve to the existing disabled panel module. Original UI source is otherwise retained; unsupported desktop service calls fail explicitly. PDF editing/OCR/export remain outside the Android scope.

Mobile focus adaptation: Slides `file-actions.ts::flushActiveEdit` emits a mobile-only flush event and waits for the original overlay commit; `TextEditOverlay.tsx` handles it with its existing commit callback. This preserves pending text when Flutter controls take native focus without a DOM blur and prevents saving stale canvas content. The same path is used by manual Save and recovery snapshots.
PDF mobile scroll tracking also recognizes the bottom scroll limit so a short, fitted last page can become the current page on narrow screens.
