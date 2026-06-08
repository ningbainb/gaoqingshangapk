# AI Reply

Android Flutter version of the original iOS SwiftUI `AIChatHelper`.

## Migrated Features

- Home entries for screenshot reply, pasted text reply, quick reply, history, people library, API settings, personalization, and privacy.
- Screenshot reply from gallery, clipboard image, Android share image, or floating capture, with quick/floating replies returning to detected chat apps after copy when Android can resolve the target package.
- Android image share/view intake also handles providers that omit `Intent.type` but expose an image URI, including manifest fallbacks for untyped share/view intents.
- Android floating capture gates the Android 14-only special-use foreground-service type by OS version, so Android 10-13 use the compatible foreground-service path.
- Android floating and MediaProjection services use the Android 8+ foreground-service startup API.
- Android 13+ notification permission is declared and exposed in the floating guide so foreground-service notifications can be shown when required.
- Android floating/quick-reply service startup failures are reported through the Flutter bridge instead of escaping the MethodChannel handler.
- MediaProjection screenshot requests are guarded against double-launches and report authorization launch failures back to Flutter.
- App-internal MediaProjection/accessibility screenshots return only through their MethodChannel result, so they do not replay as external quick-image events and reset the current quick-reply draft.
- MediaProjection and accessibility screenshots close native image buffers and recycle intermediate bitmaps even on conversion failures.
- Text reply from pasted text, Android share text, and Android selected-text `PROCESS_TEXT`; text handoff accepts `text/*`, multi-share text from extras or pure-text `ClipData`, missing or generic MIME types, explicit shared text alongside preview/file URIs, `CharSequence` payloads, and read-only selected-text semantics from real apps while skipping URI-only file shares.
- First-run privacy notice is enforced across normal pages, Android share handoffs, and quick/floating screenshot entry points before external content is consumed.
- Android external handoffs are mutually exclusive while deferred by the privacy gate, so a newer share/quick/text entry clears older pending content before it can be consumed later.
- `aichathelper://...` deep links route to the migrated Android pages for quick reply, image/text input, Moments/profile analysis, history, people, nested person editing, settings, API, personalization, privacy, and shortcut guide.
- Android Launcher App Shortcut exposes the screenshot quick-reply entry and launches the same `aichathelper://quick-image` flow used by the iOS App Intent replacement.
- Person creation routes always open a blank profile editor instead of reusing the previously selected profile.
- Corrupt local history/profile JSON is ignored instead of breaking app startup, matching the iOS stores' fallback behavior.
- Missing or corrupt temporary image files from gallery/share/clipboard/floating capture are reported as clean image-processing errors.
- Screenshot reply image preparation failures clear stale results and surface through app state instead of escaping the UI flow.
- Clipboard image import ignores non-image URI items instead of forwarding them into image decoding.
- Raw API/network failures are mapped to user-facing timeout, connection, permission, and server-error messages.
- Older API settings without model capability metadata keep the default multimodal marker so screenshot generation remains available.
- Personalization prompts include iOS-style recent conversation examples and adaptive style memory from recently copied replies.
- Conversation simulation prompts use the original iOS coaching rules, metric requirements, and safety constraints.
- API, personalization, appearance, and person-profile settings tolerate legacy string/number values, malformed model capability entries, and corrupt JSON by falling back safely where possible.
- 8 official reply styles plus custom styles, default style persistence, user goals, and personalization memory.
- OpenAI-compatible Chat Completions and Responses API calls, including endpoint fallback and retry without `response_format` when needed.
- Reply, Moments/profile, and simulation response parsers tolerate common schema aliases, person-insight aliases, string scores, and common provider response envelopes from less strict OpenAI-compatible providers.
- TokenPlan preset, `/models` fetching, automatic model recommendation, and manual multimodal/reasoning capability marking; plain text models are not auto-marked as vision-ready.
- `/models` parsing accepts standard OpenAI `data`, common compatible `models`, and top-level list responses, with `id`/`name`/`model` field aliases.
- `/models` recommendation preserves valid manual model selections despite provider casing/whitespace differences.
- `/models` permission failures keep the iOS list-specific API Key guidance and service error detail.
- Connection and vision-test loading states ignore stale older completions after settings/key resets and newer tests.
- Optional two-step vision flow: first extract screenshot text, then generate replies with the text model.
- Reply generation keeps the original iOS minimum 1800-token output budget to reduce truncated JSON replies.
- Overlapping reply generations ignore stale older results, so an earlier request cannot close loading or save history over the newer request.
- Failed reply generations clear stale current history ids together with stale results, preventing later copy actions from adopting an older record.
- Reply generation, Moments/profile analysis, and conversation simulation share a guarded busy token so one feature's late completion cannot close another feature's active loading state.
- Result page, one-tap copy, copied-reply history, people profile extraction, Moments/profile analysis, and conversation simulation.
- Screenshot reply, quick reply, and Moments/profile entry pages keep separate feature copy so generation pages do not show Moments/profile wording.
- Result metadata for platform, relationship, emotion, and risk warnings from the original iOS response schema.
- People profile merging updates names and preserves higher confidence like the original iOS model.
- Legacy people profiles that lack `updatedAt` restore recency from `createdAt` instead of being promoted to the current time.
- New generated people profiles clean blank and `未知` insight list items before saving, matching the iOS upsert behavior.
- Oversized migrated history/profile stores are capped on load to the iOS 100-history and 50-profile limits.
- Moments/profile analysis merges into selected target profiles and falls back to `朋友圈对象` when no visible name is extracted.
- Moments/profile analysis only sends a person context when a target profile is selected, matching the original iOS flow.
- Moments/profile analysis ignores stale pending results after replacing/clearing an image or starting a newer analysis.
- Moments/profile analysis results show the saved profile and can jump straight to that profile's detail page.
- Moments/profile analysis keeps its result linked to the updated profile even when saving resorts the people list.
- Unselected people context uses the three most recent profiles as cautious candidates, matching the original iOS `PersonProfile.promptContext` behavior.
- Person profile editing includes the original iOS-style quick-fill presets for common relationship/persona cues.
- Saving a person profile refreshes its update time and rebinds active people references, matching the iOS store behavior.
- Generated reply insights that update an existing person also rebind active selected, Moments, and simulation references.
- Conversation simulation includes the full training loop: profile header, scenario restart, score cards, transcript, coach feedback, suggested replies that can fill the draft or send directly, failed-reply retry preservation, and empty/busy duplicate-submit guards.
- Editing or deleting a profile keeps active simulation and Moments result references in sync with the people library.
- API settings presets, reset, manual model names, and model capability markers stay synchronized with the form state.
- API settings trim URL/model/key whitespace before saving/testing/fetching, and reset clears stale error banners.
- Settings readiness now requires a usable text model before reporting the API as ready.
- Clearing all local data also resets an in-memory custom default style back to the official default.
- History detail copying updates the saved copied-reply marker, including copy-all; history dates use the original iOS-style Chinese short date display.
- History records retain generated platform, relationship, emotion, and risk metadata so detail pages match the result page.
- Copying a still-open result after clearing history recreates the current result record with the copied reply instead of losing the adoption marker.
- Appearance settings include the original iOS-style defaults, slider ranges, blur toggle behavior, sunset theme color, and comfortable text size.
- Custom background import atomically writes a compressed JPEG, then reports success after the saved image path has refreshed.
- Local privacy controls and clearing of local history, profiles, API key, personalization, appearance settings, imported backgrounds, and temporary screenshot files; app-owned transient screenshots are deleted after successful image generation or Moments/profile analysis.

## Android Replacements

- iOS Shortcut screenshot flow is replaced by a floating capture button, an Android Launcher App Shortcut, and the `aichathelper://quick-image` clipboard fallback.
- iOS Share Extension equivalent is covered by Android image/text share intents.
- Android selected-text `PROCESS_TEXT` covers chat text handoff, so selected chat text can still be sent into the text-reply flow without shipping a custom system input method.
- Screenshots are captured only after user action and Android permission/service setup.

## Requirements

- Flutter stable
- Android Studio or Android command-line SDK
- Android SDK Platform 36+

Run:

```bash
flutter pub get
flutter run
```

If Gradle reports `flutter.sdk not set in local.properties`, copy `android/local.properties.example` to `android/local.properties` and fill in your local Flutter and Android SDK paths.

## Android Permissions

The floating screenshot feature uses two user-enabled paths:

- MediaProjection from inside the app.
- AccessibilityService for the floating one-tap screenshot mode.

The app does not silently read other apps, does not auto-send messages, and does not save original screenshots to history. The app does not run local OCR; if optional two-step vision is enabled, screenshot text is extracted by your configured vision-model API only for the current generation and is not long-term cached.

## Migration Audit

Verified locally:

- `flutter analyze`
- `flutter test`
- `flutter build apk --debug`
- `flutter build apk --release`
- `flutter build appbundle --release`
- `cd android && ./gradlew lintVitalRelease`
- `scripts/android_smoke.sh build/app/outputs/flutter-apk/app-debug.apk` with an emulator or device connected

Remaining items that need broader device-side proof:

- Android 36 emulator smoke now covers debug APK install, installed native component/permission inspection, Android Launcher App Shortcut registration, cold launch, `aichathelper://settings/api`, typed and untyped file-URI image `ACTION_SEND`, typed and untyped file-URI image `ACTION_VIEW`, `ACTION_SEND` text, `ACTION_SEND_MULTIPLE` text, `ACTION_PROCESS_TEXT`, and quick-URL intent delivery without app crash.
- Floating overlay permission and AccessibilityService screenshot behavior across Android versions/vendors.
- Share image/text and selected-text `PROCESS_TEXT` behavior in real chat apps.
- URI permission behavior for large or cloud-backed `content://` images shared from third-party apps.
- Selected-text `PROCESS_TEXT` behavior in real chat apps across Android vendors.

See [docs/MIGRATION_AUDIT.md](docs/MIGRATION_AUDIT.md) for the full migrated-feature checklist and manual device test matrix.

## Release Signing

Local release APK/AAB builds fall back to the Android debug keystore so `flutter build apk --release` remains runnable during development. For distributable builds, provide these Gradle properties in `android/local.properties` or CI secrets:

```properties
RELEASE_STORE_FILE=/absolute/path/to/release.keystore
RELEASE_STORE_PASSWORD=...
RELEASE_KEY_ALIAS=...
RELEASE_KEY_PASSWORD=...
ENFORCE_RELEASE_SIGNING=true
```

Package versions are read from Flutter's `flutter.versionCode` / `flutter.versionName` metadata, so set them through `android/local.properties`, CI Gradle properties, or Flutter build flags such as `--build-number` and `--build-name` before distribution.
