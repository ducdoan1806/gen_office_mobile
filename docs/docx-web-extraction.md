# Step 1: standalone Docs renderer

The default editor_web page now loads the original React/Tiptap App rather than the paragraph prototype. It includes the upstream schema/extensions, ribbon, rich-text and table controls, pagination preview, worker parsing, conversion and surgical DOCX save pipeline.

BrowserHost installs the legacy renderer host contract using browser APIs. File paths are virtual in-session IDs. Open uses File API and Blob handoff; save downloads DOCX. Lifecycle and menu callbacks use a local event bus. Node/Electron imports are rejected for the app and worker build graphs. No main/preload process or backend is needed.

AI is disabled in the web host and the Flutter AI implementation is unchanged. Native desktop services (filesystem paths, windows, encryption, Zotero, native spellcheck, Electron exporters, MCP and CLI) are unsupported with explicit failures instead of claimed success. AutoSave is initially disabled; no recovery is promised.

Acceptance: original renderer runs in Chrome; a DOCX is opened, formatted, extended with a paragraph, edited in a table, undone/redone, downloaded and reopened. A production build and browser production tests validate module-worker/assets paths. Android/iOS embedding is step 2. Word visual compatibility and touch/device QA remain later verification work.

See editor_web/README.md and VENDOR.md for commands and exact source changes.
