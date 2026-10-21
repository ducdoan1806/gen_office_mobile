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
