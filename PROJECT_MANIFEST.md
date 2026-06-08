# Project Manifest

## 1. What This Repository Is

This repository is a Flutter application with an Android Gradle host project in `android/`.

- Flutter root project: repository root
- Android Studio / Gradle host project: `android/`
- Main Android module: `android/app`
- Android package / namespace: `com.local.aichathelper`

## 2. Top-Level Files and Directories

### `pubspec.yaml`

Flutter package definition. Declares:

- app name and version
- Dart SDK range
- Flutter dependencies
- image / icon asset registration

### `pubspec.lock`

Locked Flutter dependency versions for reproducible dependency resolution.

### `README.md`

Original repository overview, migrated features, build notes, and release signing notes.

### `README-WINDOWS.md`

Windows-specific handoff instructions for continuing development and build work.

### `PROJECT_MANIFEST.md`

This manifest. Intended as a quick map for the next developer.

### `.metadata`

Flutter project metadata showing this is a Flutter app project.

### `assets/`

Shared Flutter assets registered through `pubspec.yaml`.

Included files observed:

- `assets/icons/app_icon.png`
- `assets/images/bloom_glass_background.png`

### `lib/`

Primary Flutter application source. This is where most business logic lives.

Key areas:

- `lib/main.dart`: Flutter app entry point
- `lib/app_shell.dart`: app shell / startup behavior
- `lib/app_router.dart`: routing setup
- `lib/core/`: state, storage, models, API logic, platform bridges
- `lib/screens/`: major app screens
- `lib/widgets/`: reusable UI components

### `test/`

Dart / Flutter tests.

Observed file:

- `test/models_test.dart`

### `docs/`

Project notes and migration audit.

Observed file:

- `docs/MIGRATION_AUDIT.md`

### `scripts/`

Helper scripts for verification and local testing.

Observed file:

- `scripts/android_smoke.sh`

### `android/`

Android Gradle host project used by Flutter.

Key files:

- `android/settings.gradle`
- `android/build.gradle`
- `android/gradle.properties`
- `android/gradlew`
- `android/gradlew.bat`
- `android/gradle/wrapper/gradle-wrapper.properties`

Important note:

- `android/local.properties` is machine-specific and should be recreated on each developer machine

## 3. Android Gradle Files

### `android/settings.gradle`

Role:

- Configures plugin management
- Reads `flutter.sdk` from `android/local.properties`
- Includes Flutter tooling build
- Declares plugin versions
- Includes module `:app`

Important versions found:

- `com.android.application` `8.11.1`
- `org.jetbrains.kotlin.android` `2.2.20`

### `android/build.gradle`

Role:

- Declares repositories for all subprojects
- Sets root and subproject build directories
- Registers a clean task

### `android/gradle.properties`

Role:

- Sets Gradle JVM arguments
- Enables AndroidX and Jetifier
- Stores Flutter migration flags

### `android/gradle/wrapper/gradle-wrapper.properties`

Role:

- Pins the Gradle Wrapper distribution

Observed version:

- `gradle-8.14-all.zip`

### `android/gradlew` and `android/gradlew.bat`

Role:

- Wrapper scripts used to run the pinned Gradle version on macOS/Linux and Windows

## 4. Android App Module

### `android/app/build.gradle`

Role:

- Declares the Android application module
- Applies Flutter Gradle plugin
- Reads version values from properties
- Defines release signing behavior
- Sets Android SDK, namespace, minSdk, targetSdk, compile options, and Kotlin JVM toolchain

Observed values:

- namespace: `com.local.aichathelper`
- applicationId: `com.local.aichathelper`
- compileSdk: `36`
- targetSdk: `36`
- minSdk: `30`
- ndkVersion: `28.2.13676358`
- Java compatibility: `21`
- Kotlin JVM toolchain: `21`

### `android/app/src/main/AndroidManifest.xml`

Role:

- Declares Android permissions
- Declares the main activity
- Declares foreground services
- Declares accessibility service
- Registers launcher entry and deep links
- Registers Android package visibility queries

Important components observed:

- Main activity: `.MainActivity`
- Service: `.FloatingCaptureService`
- Service: `.ProjectionForegroundService`
- Service: `.ScreenshotAccessibilityService`

Important intent handling observed:

- `MAIN` / `LAUNCHER`
- deep link scheme `aichathelper`
- `ACTION_SEND`
- `ACTION_SEND_MULTIPLE`
- `PROCESS_TEXT`
- image/text share and view intake

### `android/app/src/main/kotlin/com/local/aichathelper/MainActivity.kt`

Role:

- Native Android entry activity
- Flutter `MethodChannel` and `EventChannel` bridge
- Overlay permission flow
- Notification permission flow
- Floating window service control
- MediaProjection screenshot flow
- Accessibility screenshot flow
- Clipboard image handling
- Android share / deep-link handoff to Flutter

### `android/app/src/main/kotlin/com/local/aichathelper/FloatingCaptureService.kt`

Role:

- Manages floating overlay UI
- Starts foreground floating capture service
- Shows quick-reply panel
- Saves overlay position

### `android/app/src/main/kotlin/com/local/aichathelper/ProjectionForegroundService.kt`

Role:

- Hosts foreground notification during MediaProjection screenshot capture

### `android/app/src/main/kotlin/com/local/aichathelper/ScreenshotAccessibilityService.kt`

Role:

- Accessibility-based screenshot capture path for supported Android versions

### `android/app/src/main/java/io/flutter/plugins/GeneratedPluginRegistrant.java`

Role:

- Generated Flutter plugin registration source

### `android/app/src/main/res/`

Role:

- Android launcher icons
- launch background
- string/style resources
- XML configs for network security, accessibility, and app shortcuts

Observed resource files:

- `drawable/launch_background.xml`
- `mipmap-*/ic_launcher.png`
- `values/strings.xml`
- `values/styles.xml`
- `xml/accessibility_service_config.xml`
- `xml/network_security_config.xml`
- `xml/shortcuts.xml`

### `android/app/src/main/assets/`

Role:

- Android module asset directory

Observed status:

- directory exists

## 5. Flutter Source Map

### `lib/main.dart`

Flutter process entry point. Starts `ProviderScope` and launches `AIReplyApp`.

### `lib/screens/home_screen.dart`

Primary home screen with feature entry points:

- screenshot reply
- text reply
- moments/profile analysis
- people library
- history
- API settings
- settings center

### `lib/core/`

Main non-UI logic area. Contains:

- API endpoint and transport handling
- model parsing and model recommendation logic
- reply generation
- vision extraction
- personalization and style configuration
- persistence and secure/local storage
- app state orchestration
- history / profile models
- platform bridge helpers

### `lib/screens/`

High-level feature pages such as:

- API settings
- floating guide
- history details
- people / profile management
- home
- image generation
- moments profile analysis
- privacy
- result
- settings
- simulation
- text input

### `lib/widgets/`

Reusable visual components and feature widgets used by the screens.

## 6. Dependencies

### Direct Flutter dependencies declared in `pubspec.yaml`

- `characters`
- `cupertino_icons`
- `dio`
- `flutter_riverpod`
- `flutter_secure_storage`
- `go_router`
- `image`
- `image_picker`
- `path_provider`
- `shared_preferences`
- `uuid`

### Direct Android dependency in `android/app/build.gradle`

- `androidx.core:core-ktx:1.13.1`

### Dependency lock sources

- Flutter package versions: `pubspec.lock`
- Android / Gradle plugin versions: `android/settings.gradle`
- Gradle version: `android/gradle/wrapper/gradle-wrapper.properties`

## 7. Sensitive Data Check Summary

Observed sensitive-risk areas:

- `android/local.properties` contains machine-local SDK paths
- release signing property names are documented in `README.md` and Gradle files
- code contains API key handling logic, but no concrete API key value was found in the scanned tracked source files

Not found during scan:

- `.jks`
- `.keystore`
- `.p12`
- `.pem`
- `google-services.json`
- `.env`

Action taken for packaging:

- machine-specific `android/local.properties` should be excluded from the zip
- use `android/local.properties.template` on the Windows machine instead

## 8. Recommended Read Order for the Next Developer

1. `README-WINDOWS.md`
2. `PROJECT_MANIFEST.md`
3. `README.md`
4. `pubspec.yaml`
5. `lib/main.dart`
6. `lib/screens/home_screen.dart`
7. `android/app/build.gradle`
8. `android/app/src/main/AndroidManifest.xml`
9. `android/app/src/main/kotlin/com/local/aichathelper/MainActivity.kt`

