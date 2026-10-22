# LibreOfficeKit Java bindings and native runtime

Bindings: LibreOffice/core tag `libreoffice-26.2.6.3`, `android/Bootstrap/src/org/libreoffice/kit/`.
Source: https://github.com/LibreOffice/core/tree/libreoffice-26.2.6.3/android/Bootstrap/src/org/libreoffice/kit
License: Mozilla Public License 2.0, https://www.mozilla.org/MPL/2.0/.

Local modification: `LibreOfficeKit.init` accepts Android Context rather than Activity, so conversion can run in a private Service process. Cache lookup uses Context.getCacheDir(). Native API names and callback fields remain upstream-compatible.

Native runtime is prepared by `tool/setup_office_runtime.ps1` from the F-Droid-built LibreOffice Viewer 26.2.6.3 packages. Exact APK URLs and SHA-256 are pinned in that script. APKs and extracted libraries are build dependencies in ignored `android/office-runtime/`, not source files.

Corresponding source distributions:
- https://f-droid.org/repo/org.documentfoundation.libreoffice_131_src.tar.gz
- https://f-droid.org/repo/org.documentfoundation.libreoffice_129_src.tar.gz

LibreOffice licensing and bundled third-party notices: https://www.libreoffice.org/about-us/licenses/ and the above corresponding source distributions. Preserve the original runtime files and font notices when redistributing. The app does not use the LibreOffice Viewer UI or Android application package.
