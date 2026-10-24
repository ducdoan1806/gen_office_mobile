plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.gen_office_mobile"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion
    sourceSets.getByName("main") {
        jniLibs.srcDir("../office-runtime/jniLibs")
        assets.srcDir("../office-runtime/assets")
    }
    packaging.jniLibs.useLegacyPackaging = true

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.gen_office_mobile"
        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}

val checkOfficeRuntime by tasks.registering {
    doLast {
        check(file("../office-runtime/assets/program/bootstraprc").isFile &&
            file("../office-runtime/jniLibs/arm64-v8a/liblo-native-code.so").isFile &&
            file("../office-runtime/jniLibs/x86_64/liblo-native-code.so").isFile) {
            "Prepare offline DOC runtime first: powershell -ExecutionPolicy Bypass -File tool/setup_office_runtime.ps1 (from project root)."
        }
    }
}
tasks.named("preBuild") { dependsOn(checkOfficeRuntime) }


dependencies {
    implementation("androidx.browser:browser:1.9.0")
    // Match Flutter integration_test's debug runtime constraints.
    androidTestImplementation("androidx.test:runner:1.3.0")
    androidTestImplementation("androidx.test.uiautomator:uiautomator:2.2.0")
    androidTestImplementation("junit:junit:4.12")
}
