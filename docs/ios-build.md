# iOS build — Xcode 27 / Flutter 3.35.3

## Environment verified

- Flutter 3.35.3 / Dart 3.9.2
- Xcode 27.0 (27A266a), CocoaPods 1.16.2
- iPhone 18 Pro Simulator, iOS 27.0
- Deployment target: iOS 15.0

Verified: Debug Simulator build, DOCX WKWebView integration test on iOS 27, and unsigned device Release build all passed.

## Fixes

### Deployment target

Xcode 27 rejects deployment targets below iOS 15. Runner's Debug/Release/Profile settings, Flutter/AppFrameworkInfo.plist and Podfile now use 15.0. The Podfile post_install hook raises lower plugin pod targets to 15.0 without lowering plugins that request a newer version. Regenerate Pods using pod install; do not edit Pods.xcodeproj manually.

### Flutter framework architecture verification

Flutter 3.35 verifies multiple requested architectures using one lipo -verify_arch invocation, which fails with Xcode 27's lipo. The project's Debug.xcconfig restricts only Simulator SDK 27 to arm64. Xcode 27 runs on Apple Silicon. Other SDKs, physical-device builds, Release and Profile retain their standard architecture settings. No shared Flutter SDK files are patched.

Avoid using NATIVE_ARCH_ACTUAL in this SDK-conditional override: with this toolchain it causes concrete simulator destination resolution to fail, despite a generic Simulator build succeeding.

Upstream issue: https://github.com/flutter/flutter/issues/188461

### Required scene lifecycle

Apps compiled using SDK iOS 27 must adopt UIScene. The previous template crashed on startup in UIApplicationEvaluateRuntimeIssueForNoSceneLifecycleAdoption. Info.plist now declares a single scene using FlutterSceneDelegate and the Main storyboard. AppDelegate uses Flutter 3.35's available FlutterPluginRegistrant callback so plugins register with the engine created when the scene connects.

Do not replace this callback with FlutterImplicitEngineDelegate while remaining on Flutter 3.35: that newer API is not in this installed SDK's headers. When upgrading Flutter, follow the migration for the selected SDK version.

Reference: https://docs.flutter.dev/release/breaking-changes/uiscenedelegate

## Build and run

```sh
flutter pub get
cd ios
pod install
cd ..
flutter build ios --simulator --debug
flutter devices
flutter run -d <ios-simulator-id>
```

Open ios/Runner.xcworkspace when building in Xcode so CocoaPods is included. Commit Podfile.lock for reproducible dependency resolution.

```sh
flutter test integration_test/docx_webview_test.dart --no-uninstall -d <ios-simulator-id> --reporter expanded
flutter build ios --release --no-codesign
```

The Simulator integration test verifies real WKWebView loading, Vietnamese text insertion, undo/redo, native save and reopening exported DOCX. Automated insertion does not validate Vietnamese keyboard composition on a physical device. Unsigned Release output still needs an Apple signing identity/provisioning before installation on an iPhone; this command does not produce a distributable signed IPA.
