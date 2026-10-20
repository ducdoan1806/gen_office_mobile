# Bundled editor

Generated production assets from editor_web/dist, served only inside the device through EditorAssetServer. Rebuild with `node tool/bundle_editor.mjs` from the project root. Do not manually edit assets/; stale generated files are removed by the bundler.

build-manifest.json records upstream revision and SHA-256 of generated assets. Upstream LICENSE/NOTICE and font notices are copied alongside the runtime assets. See editor_web/VENDOR.md for source integration changes.
