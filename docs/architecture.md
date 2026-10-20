# Architecture

Flutter owns navigation, file lifecycle and AI interaction. A future bundled WebView owns the adapted Office editor. Rust spreadsheet functionality can be exposed as a native library. AI inference stays on factory servers.

## Boundaries

- `DocumentRepository`: replace demo metadata with actual imported files and persistence.
- `DocumentEditorBridge`: implement open/save/undo/close using document sessions. The current UI is a placeholder.
- `FactoryAiService`: one request ID per run; stream status/text/completion and support cancellation. API implementation intentionally returns UnimplementedError until the backend contract is provided.
- `AppDependencies`: explicit constructor injection; mock by default.

## Future edit protocol

Agree on documentId, baseRevision, stable block/cell/slide IDs, allowed operation types, validation errors and source citations. Reject stale revisions, validate every operation, capture a snapshot and show changes before application. The current scaffold only models text events; proposal events must be added together with a validated engine contract.

## Backend integration checklist

Confirm HTTPS base URL, authentication, network/VPN requirements, request and event schemas, cancellation semantics, timeouts, retries, and permitted document context. Configure Android/iOS networking and certificates when the real deployment details are available. Avoid blindly retrying mutating requests.
