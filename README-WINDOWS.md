# Android/Flutter Project Handoff for Windows

## 1. Project Overview

This repository is a Flutter application project that contains a standard Android Gradle host project under `android/`.

- Project name: `ai_reply`
- Android applicationId / package: `com.local.aichathelper`
- Android namespace: `com.local.aichathelper`
- App display name: `AI Reply`
- Project type: Flutter app + Android Studio / Gradle Android host project

This is not a standalone native Android-only codebase. To continue development on Windows, open the repository root as a Flutter project. The `android/` folder is the Android build host used by Flutter.

## 2. Main Capabilities

The app is an AI reply assistant migrated from an iOS app to Flutter + Android. Main features include:

- Chat screenshot reply generation
- Text paste reply generation
- Floating capture / quick reply overlay
- Moments/profile analysis
- People library and history management
- API settings for OpenAI-compatible endpoints
- Privacy, personalization, and appearance settings
- Android share intent, deep link, and accessibility / MediaProjection integrations

## 3. Project Structure

```text
gaoqingshangapk/
|- lib/                         Flutter Dart application source
|- assets/                      Shared image/icon assets
|- android/                     Android Gradle host project
|  |- app/                      Android app module
|  |- gradle/wrapper/           Gradle Wrapper files
|  |- build.gradle              Root Android Gradle config
|  |- settings.gradle           Android Gradle settings and plugin versions
|  |- gradle.properties         Android Gradle properties
|  |- gradlew / gradlew.bat     Gradle wrapper launchers
|- test/                        Dart / Flutter tests
|- docs/                        Migration and audit notes
|- scripts/                     Helper scripts
|- pubspec.yaml                 Flutter package definition
|- pubspec.lock                 Locked Flutter dependency versions
|- README.md                    Original project overview
|- README-WINDOWS.md            Windows handoff guide
|- PROJECT_MANIFEST.md          File and module manifest
```

## 4. Languages Used

This repository is a mixed project:

- Primary app language: Dart / Flutter
- Android native bridge layer: Kotlin
- Generated Android plugin file: Java

If you only inspect `android/`, you will miss most business logic because the main app code lives in `lib/`.

## 5. Build Toolchain Versions

From the checked-in project files:

- Android Gradle Plugin: `8.11.1`
- Gradle Wrapper: `8.14`
- Kotlin Android plugin: `2.2.20`
- Java / JDK target: `21`
- Kotlin JVM toolchain: `21`
- Flutter Dart SDK constraint: `>=3.3.0 <4.0.0`

Android SDK configuration in `android/app/build.gradle`:

- `compileSdk = 36`
- `targetSdk = 36`
- `minSdk = 30`
- `ndkVersion = 28.2.13676358`

## 6. Software Required on Windows

Please install the following on the Windows laptop:

1. Android Studio latest stable version
2. Flutter SDK, stable channel
3. JDK 21
4. Android SDK Platform 36
5. Android SDK Build-Tools corresponding to Platform 36
6. Android command-line tools
7. Optional: an Android emulator or a physical Android device with USB debugging

Recommended installation path examples:

- Flutter SDK: `C:/src/flutter`
- Android SDK: `C:/Users/<YourUser>/AppData/Local/Android/Sdk`

Avoid placing the project, Flutter SDK, or Android SDK in deeply nested Chinese paths if possible, because some older tools and scripts behave better with short ASCII paths.

## 7. How to Open the Project in Android Studio

Recommended method:

1. Unzip the package to a short local path, for example `C:/work/gaoqingshangapk`
2. Open `README-WINDOWS.md` first
3. Launch Android Studio
4. Choose **Open**
5. Select the repository root folder, not only the `android/` folder
6. Wait for Android Studio to detect the Flutter project and index Gradle / Dart files

Why open the root:

- `lib/` contains the real app source
- `pubspec.yaml` defines Flutter dependencies
- `android/` is only one platform host

Command-line build is also possible, but Android Studio is the better first entry point for understanding and continuing development.

## 8. local.properties Setup on Windows

Do not reuse the original Mac-specific `android/local.properties` values.

This package includes:

- `android/local.properties.example` from the existing repo
- `android/local.properties.template` generated for Windows handoff

Create or edit `android/local.properties` on the Windows machine and set values like:

```properties
sdk.dir=C:/Users/<YourUser>/AppData/Local/Android/Sdk
flutter.sdk=C:/src/flutter
flutter.buildMode=debug
flutter.versionName=1.0.0
flutter.versionCode=1
```

If you need release signing later, add signing properties only on the target machine or in CI secrets. Do not commit real keystore passwords into the repository.

## 9. Dependency Notes

Flutter dependencies are declared in `pubspec.yaml` and locked in `pubspec.lock`.

Important direct Flutter packages:

- `dio`
- `flutter_riverpod`
- `flutter_secure_storage`
- `go_router`
- `image`
- `image_picker`
- `path_provider`
- `shared_preferences`
- `uuid`

Android dependencies declared directly in Gradle:

- `androidx.core:core-ktx:1.13.1`

Flutter plugin dependencies are resolved through Flutter tooling and the Gradle integration under `android/`.

## 10. Main Modules and Entry Points

Flutter app entry:

- `lib/main.dart`

Primary Flutter screens:

- `lib/screens/home_screen.dart`
- `lib/screens/image_generation_screens.dart`
- `lib/screens/text_input_screen.dart`
- `lib/screens/moment_profile_screen.dart`
- `lib/screens/history_people_screens.dart`
- `lib/screens/api_settings_screen.dart`
- `lib/screens/settings_screen.dart`
- `lib/screens/privacy_screen.dart`
- `lib/screens/simulation_screens.dart`

Core app state / service areas:

- `lib/core/` for API integration, storage, models, app state, prompts, parsing, and platform bridges
- `lib/widgets/` for reusable UI components

Android native entry points:

- Main activity: `android/app/src/main/kotlin/com/local/aichathelper/MainActivity.kt`
- Floating overlay service: `android/app/src/main/kotlin/com/local/aichathelper/FloatingCaptureService.kt`
- Projection foreground service: `android/app/src/main/kotlin/com/local/aichathelper/ProjectionForegroundService.kt`
- Accessibility screenshot service: `android/app/src/main/kotlin/com/local/aichathelper/ScreenshotAccessibilityService.kt`
- Android manifest: `android/app/src/main/AndroidManifest.xml`

## 11. Syncing and Building

First-time setup on Windows:

1. Install Flutter, Android Studio, JDK 21, and Android SDK 36
2. Configure `android/local.properties`
3. Open the repository root in Android Studio
4. Let Android Studio sync Gradle
5. Open a terminal in the project root
6. Run:

```bash
flutter pub get
flutter doctor
flutter run
```

Useful Android-specific commands:

```bash
cd android
gradlew.bat tasks
gradlew.bat assembleDebug
```

Useful Flutter build commands from the repository root:

```bash
flutter build apk --debug
flutter build apk --release
flutter build appbundle --release
```

## 12. Common Troubleshooting

### Problem: `flutter.sdk not set in local.properties`

Fix:

- Create or edit `android/local.properties`
- Set `flutter.sdk` to your local Flutter SDK path

### Problem: Android SDK not found

Fix:

- Set `sdk.dir` in `android/local.properties`
- Confirm Android Studio SDK Manager has installed Platform 36

### Problem: Gradle download fails

Fix:

- Check network / proxy settings
- Retry from Android Studio or command line
- Confirm `gradle/wrapper/gradle-wrapper.properties` still points to Gradle `8.14`

### Problem: JDK version mismatch

Fix:

- The project targets Java 21
- Set Android Studio Gradle JDK to JDK 21
- Confirm `java -version` reports 21 if using command line

### Problem: Flutter dependency resolution fails

Fix:

- Run `flutter pub get`
- Check Flutter SDK version and channel
- Confirm `pubspec.lock` is present

### Problem: Gradle or plugin sync errors

Fix:

- Open the repository root, not only `android/`
- Run `flutter pub get` before retrying
- Use Android Studio's Flutter and Dart plugins

### Problem: Release signing confusion

Fix:

- By default this project can fall back to the Android debug keystore for local release builds
- For distributable release packages, set:
  - `RELEASE_STORE_FILE`
  - `RELEASE_STORE_PASSWORD`
  - `RELEASE_KEY_ALIAS`
  - `RELEASE_KEY_PASSWORD`
  - optionally `ENFORCE_RELEASE_SIGNING=true`

## 13. Notes About Included and Excluded Files

Included in the handoff package:

- Source code
- Flutter and Android configuration
- Gradle wrapper and wrapper properties
- Android manifest and resources
- Assets and test files
- Project documentation and migration notes

Excluded from the handoff package:

- `build/`
- `.dart_tool/`
- `android/.gradle/`
- `android/.kotlin/`
- `*.iml`
- `.idea/workspace.xml`
- machine-specific `android/local.properties`

The original local file is intentionally not packaged because it contains Mac-specific SDK paths.

## 14. Recommended First File to Read

Open this file first:

- `README-WINDOWS.md`

Then review:

- `PROJECT_MANIFEST.md`
- `README.md`
- `pubspec.yaml`
- `android/app/build.gradle`
- `android/app/src/main/AndroidManifest.xml`

