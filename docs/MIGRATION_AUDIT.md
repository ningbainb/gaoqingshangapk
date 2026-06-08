# Migration Audit

This document tracks the Android Flutter migration status against the original iOS SwiftUI `AIChatHelper` project at `/Users/xua/Code/gaoqingshang`.

## Verified Locally

These checks pass on the current workspace:

```bash
flutter analyze
flutter test
flutter build apk --debug
flutter build apk --release
flutter build appbundle --release
cd android && ./gradlew lintVitalRelease
scripts/android_smoke.sh build/app/outputs/flutter-apk/app-debug.apk
```

The APKs/app bundle are generated at:

```text
build/app/outputs/flutter-apk/app-debug.apk
build/app/outputs/flutter-apk/app-release.apk
build/app/outputs/bundle/release/app-release.aab
```

Latest local verification on 2026-06-06:

- `flutter analyze` passed.
- `flutter test` passed with 456 tests.
- `flutter build apk --debug` passed and produced `build/app/outputs/flutter-apk/app-debug.apk`.
- `flutter build apk --release` passed and produced `build/app/outputs/flutter-apk/app-release.apk`.
- `flutter build appbundle --release` passed and produced `build/app/outputs/bundle/release/app-release.aab`.
- `./gradlew lintVitalRelease` passed from `android/`.
- The release APK/AAB and `lintVitalRelease` gates above were rerun after the Android native event source-metadata alias update.
- After the Android smoke-helper cleanup, `bash -n scripts/android_smoke.sh`, full `flutter test` with 456 tests, `flutter analyze`, and `flutter build apk --debug` were rerun successfully; no Android device was attached for a repeat smoke run in that pass.
- After the floating overlay polish and bug audit, a clean `flutter clean && flutter pub get` verification passed `flutter test` with 456 tests, `flutter analyze`, `flutter build apk --debug`, `flutter build apk --release`, `flutter build appbundle --release`, and `cd android && ./gradlew lintVitalRelease`; no Android device was attached for adb smoke.
- `scripts/android_smoke.sh build/app/outputs/flutter-apk/app-debug.apk` passed on `emulator-5554` and remains available for repeatable adb smoke on attached emulators or Android devices; the helper now also inspects installed package components before exercising external entry points.
- Release merged/packaged manifests were inspected after the current builds and retained the `aichathelper` scheme, Android share/`PROCESS_TEXT` filters, Android Launcher App Shortcut metadata, foreground services, accessibility service, package queries, and network-security config.
- Android SDK system image `system-images;android-36;google_apis;arm64-v8a` was installed, AVD `ai_reply_api36` was created, and the debug APK was installed/launched on `emulator-5554`.
- Android emulator smoke passed for Android Launcher App Shortcut registration plus cold launch, explicit `aichathelper://settings/api`, file-URI `ACTION_SEND image/png`, untyped file-URI `ACTION_SEND`, file-URI `ACTION_VIEW image/png`, untyped file-URI `ACTION_VIEW`, `ACTION_SEND` text, `ACTION_SEND_MULTIPLE text/plain`, read-only `ACTION_PROCESS_TEXT`, and `aichathelper://quick-image` intent delivery: `cmd shortcut get-shortcuts com.local.aichathelper` exposed `quick_image_reply` pointing at `aichathelper://quick-image`, the app stayed foregrounded as `com.local.aichathelper/.MainActivity`, `pidof com.local.aichathelper` returned a running process, `dumpsys activity processes` showed no app crash/ANR state, and recent logcat contained no `FATAL EXCEPTION`, `AndroidRuntime`, process death, or force-finish lines for the app.

## Feature Coverage Matrix

| iOS capability | Android/Flutter coverage | Evidence | Remaining gap |
| --- | --- | --- | --- |
| Home navigation and `AppRoute` destinations | Migrated with matching Flutter pages for screenshot, text, Moments/profile, history, people, settings, personalization, API, privacy, add-person, and shortcut guide; Android also adds quick reply, detail pages, and simulation routes. | `lib/main.dart` `GoRoute` table; `test/models_test.dart` external-route coverage. | None known from static route audit. |
| Screenshot reply | Migrated for gallery images, clipboard images, Android image share/view handoffs, and quick/floating screenshot paths. App-owned temp screenshots are deleted after success, replacement, deletion, page disposal, or local-data cleanup. | `ImageInputScreen`, `ImageService`, Android `MainActivity`; image/transient cleanup tests. | Real third-party image share and cloud-backed `content://` images need device proof. |
| Pasted text reply | Migrated for manual text, clipboard paste, Android share text, and selected-text `PROCESS_TEXT`. | `TextInputScreen`, `MainActivity`; text handoff and paste tests. | Real chat-app share/selection behavior needs device proof. |
| iOS App Intent quick screenshot | Replaced on Android by floating capture, an Android Launcher App Shortcut, and `aichathelper://quick-image` clipboard fallback. | `FloatingGuideScreen`, `FloatingCaptureService`, Android manifest `@xml/shortcuts`, quick auto-generation and shortcut-resource tests. | Not a one-to-one App Intent port; Android replacement needs overlay/accessibility/quick URL/device proof. |
| iOS Share Extension | Replaced by Android image/text `ACTION_SEND`, `ACTION_SEND_MULTIPLE`, and broad MIME/URI intake. | Android manifest and `MainActivity`; share intake tests. | Needs real app/provider matrix on Android. |
| iOS selected-text handoff | Covered by Android selected-text `PROCESS_TEXT`; this build intentionally does not ship a custom system input method. | Android manifest and `MainActivity`; selected-text handoff tests. | Needs real selected-text proof across Android vendors. |
| Result page, copy, and copied-history adoption | Migrated, including current result, history detail, copy-all, native floating overlay copy adoption, and clipboard failure handling. | `ResultScreen`, `HistoryDetailScreen`, `AppController.copyReply`; copy-state tests. | None known from local tests. |
| History store/list/detail | Migrated with iOS-style short dates, corrupt-record tolerance, side-effect-free sorted saves, delete/clear synchronization, and no original screenshot storage. | `LocalStore`, `HistoryScreen`, `HistoryDetailScreen`; history tests. | None known from local tests. |
| People library/profile editor | Migrated with tolerant legacy decoding, merge/update semantics, aliases, quick-fill presets, detail copy, delete/clear synchronization, and selected-target prompt context. | `PeopleScreen`, profile detail/editor, `PersonProfile` helpers; profile tests. | None known from local tests. |
| Moments/profile analysis | Migrated with gallery/clipboard image input, selected-profile merging, fallback profile creation, write-back card, stale-result clearing, and temp screenshot cleanup. | `MomentProfileScreen`, `AppController.analyzeMoment`; Moments tests. | Real image handoff still needs Android device proof. |
| Conversation simulation | Migrated with scenario handling, restart loop, score cards, transcript, coach feedback, suggested replies that can fill the draft or send directly, failed-reply retry preservation, metric fallback, empty-submit/busy guards, and profile mutation synchronization. | `SimulationScreen`, simulation prompt/parser/state tests. | None known from local tests. |
| API settings and model discovery | Migrated with Base URL/API Key/model/image/generation settings, TokenPlan preset, `/models` fetch/recommendation, draft-local edits, stale async guards, and release signing guard. | `ApiSettingsScreen`, `OpenAICompatibleApi`, Gradle config; API/model/signing tests. | Live provider compatibility still depends on configured service. |
| Personalization and styles | Migrated with official styles, custom styles, default-style legacy migration, adaptive copied-reply memory, and prompt context parity. | `PersonalizationScreen`, `ReplyPersonalizationSettings`, prompt tests. | None known from local tests. |
| Appearance settings | Android-specific implementation preserves iOS defaults/options plus imported custom backgrounds, scoped feedback, atomic JPEG import, and privacy cleanup. | `AppearanceSettingsCard`, `ImageService`, `LocalStore`; appearance tests. | None known from local tests. |
| Privacy and local-data cleanup | Migrated with first-run gate across external handoffs, full local reset, API Key/config cleanup, app-owned custom-background deletion, temp screenshot deletion, and stale async-result guards. | `GlassScaffold`, `AppController.clearAllLocalData`, storage tests. | Device-only external handoff timing still needs final real-world proof. |

## Migrated From iOS

- Home entries for screenshot reply, pasted text reply, quick reply, history, API settings, privacy, personalization, and people library.
- Screenshot reply from gallery images.
- Mounted screenshot reply screens reset stale goal, style, and selected-person controls even when Android re-delivers the same shared image path, so repeated external image handoffs still start from a fresh draft.
- Clipboard image import for screenshot reply, quick reply, and Moments/profile analysis.
- Clipboard image import now reports the iOS empty-screenshot guidance when no usable image is available, instead of silently clearing the read indicator on screenshot reply, quick reply, or Moments/profile analysis.
- Quick URL clipboard fallback clears its pending auto-generation flag when no screenshot is available, matching the iOS fallback state where the user sees recovery guidance instead of leaving a stale generation request armed.
- Moments/profile analysis deletes app-owned clipboard preview images when the user replaces, deletes, or leaves an unsubmitted preview, closing the Android-only temp-file lifecycle gap absent from the original iOS in-memory image flow.
- Moments/profile analysis clears stale success feedback before a new run and on failures, so an old write-back success cannot coexist with a newer image-processing or API error.
- Moments/profile target changes clear stale global feedback before the next analysis, preserving the iOS page-local form behavior after the user changes the write-back target.
- Android clipboard image import rejects non-image URI items instead of forwarding arbitrary clipboard URIs to image decoding.
- Android clipboard image import now also tries untyped `content://` and `file://` image candidates and relies on the existing decode validation, matching the share/view handoff fallback for providers that hide MIME type and file extension.
- Android share/clipboard image copies validate the copied bytes as a decodable image before handing the path to Flutter, matching the iOS pending-image store's early `UIImage(data:)` guard and cleaning partial files on failure.
- Image payload data URLs are locked to the same `data:<mime>;base64,<payload>` format as the iOS `Base64ImageEncoder`, preserving vision-model request compatibility.
- Text reply from pasted chat text.
- Mounted text reply screens reset stale goal, style, and selected-person controls when a real Android shared-text handoff arrives, matching the fresh-draft behavior used by the iOS share flow.
- Android text share intake accepts plain text even when providers omit or loosen the MIME type, while avoiding file/image shares.
- Android text share intake only treats `EXTRA_STREAM` as a file handoff after resolving a real URI, so providers that attach an empty stream extra do not drop plain shared text.
- Android text and selected-text intake read `EXTRA_TEXT`/`EXTRA_PROCESS_TEXT` through the raw extras bundle before normalizing single `CharSequence` values, arrays, and iterable text lists, so multi-share payloads do not trigger Android `Bundle` class-cast warnings and URI/file objects are not silently converted to pasted text.
- Android pure-text `ClipData` multi-share handoffs are now joined with newlines instead of keeping only the first item, while URI-backed clip entries are still skipped so file/image shares do not become chat text.
- Android text share and selected-text manifest entries accept `text/*`, matching the broader runtime intake.
- First-run privacy notice gating across normal navigation, share handoff, selected text, clipboard quick launch, and floating screenshot entry points.
- Android `aichathelper://...` deep link routing for the same migrated page commands as iOS where an Android page exists.
- Android Launcher App Shortcut exposes the screenshot quick-reply entry from the launcher long-press menu and routes it into `aichathelper://quick-image`, covering the system shortcut surface left by the iOS AppShortcuts provider.
- The Android Launcher App Shortcut also carries an explicit launcher icon resource and is covered by a static regression check, preserving a visible shortcut affordance in launcher long-press menus.
- Android deep links preserve host plus path segments, so forms like `aichathelper://people/edit` open the intended nested page.
- Android deep link aliases cover the iOS personalization/settings commands (`personalization`, `reply-settings`, `style-settings`, `api`, `privacy`, `shortcut`, and related variants).
- Android deep link normalization also accepts legacy iOS `AppRoute` case names and common separators such as `textInput`, `personLibrary`, `apiSettings`, `text_input`, or `text input`.
- Android deep link normalization also accepts query-target wrappers such as `aichathelper://open?route=settings/api`, `aichathelper://route?path=people/new`, and `aichathelper://screen?page=privacy`, so older shortcuts or third-party launchers that put the real destination in parameters still reach the migrated page.
- Android deep link aliases also cover the migrated conversation-simulation surfaces (`simulation` and `people/select-simulation` variants), so the Android-added training flow is reachable from external route events instead of only in-app taps.
- Floating capture foreground service uses the Android 14 special-use foreground service type only on Android 14+, avoiding older-system foreground-service startup failures.
- Floating capture and MediaProjection services use `startForegroundService` on Android 8+ and plain `startService` only on older systems.
- Floating capture and MediaProjection services guard `startForeground` promotion failures, reporting native error events instead of crashing the service when Android rejects the foreground-service type or notification setup.
- Floating guide checks and requests Android 13+ notification permission so foreground-service notifications are visible when the system requires permission.
- Floating window and quick-reply panel service startup failures are reported back to Flutter with native error events instead of escaping the MethodChannel handler.
- Native floating/share/error events are buffered with a bounded latest-event queue before Flutter attaches its listener, avoiding unbounded startup-time event accumulation.
- Flutter normalizes native floating/share event fields by trimming blank values and canonicalizing source aliases such as `shared_image`, `androidShareImage`, `system-share-text`, `floating-capture`, `quickImage`, and `process_text`, so compatible native events cannot route shared screenshots into the wrong quick-reply flow or hide an error behind an empty path.
- Flutter accepts common native event field aliases such as `imagePath`, `filePath`, `sharedText`, `selectedText`, `deepLink`, `targetRoute`/`target`/`screen`/`page`, `replyText`/`copiedText`, and `eventSource`, so compatible bridge payloads with renamed keys still reach the migrated Android routes and copied-reply adoption path.
- Flutter also accepts source metadata aliases such as `sourceType`, `eventType`, `inputType`, `handoffType`, and Android intent action values like `ACTION_SEND_MULTIPLE`/`ACTION_PROCESS_TEXT` when classifying native handoffs.
- Flutter also accepts separator/case variants for native floating/share event keys such as `copied_reply` and `error-message`, so copied overlay replies and native error messages are not dropped if a bridge emits snake_case or kebab-case payloads.
- Android native share/deep-link/process-text handoffs are marked consumed after their first delivery, so Activity recreation cannot replay the same external Intent into Flutter and duplicate a screenshot, shared text, or route event.
- Floating window and quick-reply panel view add/remove failures are guarded inside the service so overlay-window races or vendor restrictions report native error events instead of crashing the service.
- Floating window drag updates, system settings launches, and return-to-app launches are guarded so vendor permission edge cases report native error events instead of throwing out of the Android bridge.
- Floating window drag gestures are separated from click gestures with Android touch slop, so moving the shortcut button does not accidentally trigger a screenshot capture.
- MediaProjection screenshot requests reject concurrent launches and report authorization-activity launch failures back to Flutter instead of overwriting pending results.
- MediaProjection and accessibility screenshot resources are closed/recycled in `finally` blocks so failures during bitmap conversion do not leak native image buffers.
- Person creation routes and empty-library entry points clear the selected profile before opening the editor, matching iOS' explicit `profile: nil` add flow.
- Local history/profile stores tolerate corrupt JSON or corrupt individual records and fall back to the remaining valid data instead of failing startup.
- Local migrated preference reads now ignore wrong-typed stored values for API config, history, profiles, personalization, appearance, default style, API-key fallback, and privacy flags instead of throwing during startup.
- Imported history, people, and reply-suggestion records regenerate blank IDs instead of keeping empty primary keys, matching the iOS UUID-backed model's protection against invalid record identity.
- Imported history, people, reply-suggestion, and custom-style records preserve common compatible ID aliases such as `generation_id`, `profile_id`, `person_id`, `candidate_id`, and `style_id`, so restored references do not silently change identity when backups do not use a plain `id` key.
- Imported history reply candidates preserve compatible list fields such as `reply_options`, `replySuggestions`, `candidates`, and `answers`, and ID fields such as `suggestion_id` and `reply-id`, so restored candidate identity and text stay stable when backups use non-standard reply field names.
- Imported or provider-returned reply candidates that omit a style label fall back to the iOS `ReplySuggestion` default `建议`, including plain-string reply candidates in history, structured replies, and top-level reply arrays.
- Provider model responses wrapped in common envelopes such as `data`, `result`, `response`, `output`, `payload`, `content`, or `message` are unwrapped only when the envelope looks like the expected reply, Moments/profile, or simulation payload, preserving summary metadata, candidate replies, person insights, profile facts, coaching scores, and suggested simulation replies without scanning unrelated nested arrays.
- Imported history records also preserve compatible selected-style fields such as `style` and `chatStyle`, so restored records keep their intended reply style even when backups do not use the exact `selectedStyleName` key.
- Imported history records normalize compatible input-type values such as `Image`, `screen-shot`, and `截图`, so screenshot replies do not fall into text-only history filters after migration.
- Imported people-profile records preserve compatible recent-source fields such as `scene_summary` and `update_reason`, plus confidence aliases such as `confidence_score`, so migrated profile prompt context and merge confidence keep the latest evidence even when the record came from a model-style payload.
- Imported people-profile records also preserve compatible recent-source aliases such as `context_summary`, `source_summary`, `evidenceSummary`, `source_reason`, `basis`, and `updateSource`, so restored profile detail cards and prompt context keep the latest update evidence from non-iOS backups.
- Imported history records trim blank style names and copied-reply markers, falling back to the default "自然" style and no copied reply instead of showing empty chips or feeding blank style text into adaptive memory.
- Imported API config, appearance, history, personalization, and people records also accept snake_case, kebab-case, space-separated, and case-only variants for known fields, preserving compatible backups with keys such as `base_url`, `image_max_width`, `background_blur_radius`, `scene_summary`, `selected_style_name`, `copied_reply`, `custom_styles`, `style_rules`, `memory_notes`, and `last_scene_summary`.
- App-state history and people lists apply the same 100-history and 50-profile sorted caps as the iOS stores before saving, keeping the current session consistent with restored storage.
- Restored/migrated history and people-library lists are also capped on load to the same 100-history and 50-profile iOS limits, so oversized legacy backups cannot bloat the current session until the next save.
- Image preparation maps missing/corrupt temporary files to user-facing image-processing errors instead of leaking low-level file or isolate exceptions.
- Screenshot reply generation catches image preparation failures in app state, clears stale results, and avoids uncaught UI futures before model generation starts.
- Raw Dio/API failures from model fetching and connection tests are mapped to user-facing timeout, connection, permission, and server-error messages.
- User-facing Dio error mapping accepts separator/case variants and common nested provider error payloads, so connection tests and model fetching preserve messages from keys such as `error_message`, `error-message`, `error_description`, and `errors[].message`.
- API config migration preserves default model capability markers and accepts string/number booleans, list-shaped model capability imports, plus capability aliases such as `supports_vision`, `supportsImages`, and `reasoning`, so older or compatible settings do not disable screenshot readiness.
- API config list-shaped model capability imports also accept `model_name`/`modelName` identifiers, matching `/models` parsing so compatible provider metadata keeps vision/reasoning markers when restored from settings backups.
- API config map-shaped model capability imports also accept modality values such as `["text", "image"]`, `"text,image"`, `supported_inputs`, `supported_capabilities`, `capability_flags`, `supported_features`, `features`, and nested `architecture`/`capabilities` metadata, so restored settings keep the same vision/reasoning markers that `/models` discovery would infer.
- API config loading falls back safely from corrupt JSON and skips malformed model capability entries.
- API config, person insights, and person profiles tolerate legacy string numeric values where safe, and skip profiles without a usable display name.
- People-library profile records accept common imported field aliases such as `name`, `nicknames`, `relationshipGuess`, `communicationAdvice`, `importantNotes`, `avoidTopics`, and `stableFacts`, so compatible backups do not lose saved profile details.
- New people-library profiles created from generated reply insights clean blank and `未知` list entries before saving, matching the iOS upsert path and keeping prompt summaries free of unusable profile bullets.
- Missing communication-style fields on imported people records and generated person insights stay `null`, so profile cards and simulation headers can fall back to relationship/default copy instead of rendering a blank subtitle.
- Personalization prompt context includes iOS-style candidate examples and adaptive style memory from recently copied replies.
- Conversation simulation prompt mirrors the iOS training template, including opening-turn behavior, required metrics, and anti-manipulation constraints.
- Conversation simulation clears stale success feedback when a new turn starts and stale failure feedback when a later retry succeeds, so old page banners cannot remain below newer training results.
- Conversation simulation parsing fills the same iOS default metrics and suggested replies when a model returns empty arrays, so the training loop still has feedback and tappable options.
- Conversation simulation metric fallback now preserves provider metrics while filling the six core training metrics required by the iOS prompt: favorability, naturalness, boundaries, progression, emotional reception, and risk control.
- Conversation simulation caps metrics to the iOS normalized maximum of 8 while preserving the six required coaching metrics, so provider-specific extra scores cannot bloat the training view.
- Conversation simulation non-JSON fallback now also fills the six required coaching metrics while keeping the iOS fallback score state and suggested replies, so malformed model text cannot downgrade the training view to three legacy metrics.
- Conversation simulation parsing also accepts common compatible-provider aliases for nested scores, scorecards, suggested reply options, persona messages, and coaching notes, preserving useful training feedback when models return `scores`, `scorecard`, `suggestedReplies`, `choices`, `characterReply`, or `trainingTip` instead of the exact prompt schema.
- Personalization and appearance settings use tolerant decoding for legacy boolean/number values and corrupt local JSON.
- Appearance option imports trim accent/text-size names and ignore blank values, so empty compatible backups cannot overwrite the iOS-style default appearance with invalid unselected options.
- Appearance settings also load legacy iOS-style `appearance.*` preference keys when no current JSON blob exists, preserving migrated blur, dim, glass, accent, and text-size preferences.
- 8 official reply styles: natural, relaxed, flirty, humorous, gentle, comforting, apology, and work.
- User goal input.
- OpenAI-compatible Chat Completions and Responses API calls.
- JSON prompt construction and JSON response parsing.
- Fallback reply extraction when the model returns non-standard JSON.
- Fallback reply extraction stays bounded to the candidate reply array when a malformed response has a closed `replies`/`replyOptions` section followed by broken profile JSON, so later `personInsight` text fields cannot be shown as sendable replies.
- Parser normalization for common model schema aliases and string numeric scores across replies, Moments/profile analysis, and conversation simulation.
- Parser field lookup also accepts snake_case, kebab-case, space-separated, case-only variants, and common provider aliases of known model response keys, so compatible providers do not lose fields such as `scene_summary`, `sceneDescription`, `platformName`, `profileName`, `currentMessage`, `person_insight`, `reply_options`, `predicted_score`, or `confidence_score`.
- Reply and history parsers preserve compatible safety/risk notice aliases such as `safety_warning`, `risk_reminder`, and `safetyAdvice`, so model-returned boundary reminders survive both the immediate result page and later history restore.
- Person/profile list fields also accept object-array items such as `{"trait":"慢热"}`, `{"fact":"项目负责人"}`, or `{"advice":"直接一点"}`, extracting the useful text instead of saving raw map strings into prompts, cards, or imported people records.
- Reply result page with scene summary, latest message, emotion, risk notice, and reply cards.
- Reply result metadata for platform and relationship, compatible with the iOS `riskWarning` response field.
- Screenshot reply, quick reply, and Moments/profile pages now keep their distinct iOS-style explanatory headers instead of sharing the wrong feature copy.
- Screenshot reply, quick reply, and Moments/profile previews use the iOS-style full-image fit instead of center-cropping tall screenshots.
- Screenshot reply and quick reply clear stale global error banners when a new screenshot is picked, captured, read from clipboard, or deleted, matching the iOS image view model's fresh-input behavior.
- Text reply clears stale global feedback when the user edits, pastes, or clears the chat text, keeping clipboard messages local like the iOS text input flow.
- Text reply clipboard failure/empty-clipboard messages now clear themselves like the iOS local paste message instead of lingering until the next page action.
- Text reply generation now has a controller-level duplicate-submission guard, so repeated text/image/regenerate requests from external handoffs, automation, or future non-button entry points are ignored while a reply generation is already running, without breaking the existing simulation/generation busy-state handoff tests.
- Text, screenshot, and quick-reply generation options clear stale global feedback when the user changes style, goal, or selected chat target, matching the fresh local form state on iOS.
- Quick-reply image handoffs clear stale success/error feedback at the app-state boundary too, so floating capture events, URL clipboard imports, and UI buttons all start from the same fresh screenshot state.
- The floating-window guide now exposes the same reply-style picker used by normal screenshot/text generation, and background floating captures explicitly generate with the selected default style instead of hiding style control behind the home screen.
- Android image/text share handoffs and blank external image/text routes also clear stale success/error feedback at the app-state boundary before opening a fresh draft.
- Appearance preference changes clear stale custom-background import feedback while leaving unrelated API/copy feedback page-local, matching the iOS settings card's local error model.
- One-tap copy and copied-reply history.
- History list/detail dates use the iOS-style Chinese short date display.
- Local history that does not store original screenshots.
- Successful image generation and Moments/profile analysis delete app-owned transient screenshot/cache files while preserving user-picked gallery files.
- People library/profile extraction from chat context.
- People profile editing now disables saving until a name is present and clears stale global feedback when the name is corrected, matching the iOS editor's local validation gate.
- Moments/profile analysis merges into an explicitly selected profile and uses a fallback "朋友圈对象" profile when no visible name is extracted.
- Person-profile pickers match the iOS automatic/selected target behavior across text reply, screenshot reply, quick reply, and Moments/profile analysis. Selected reply generation sends only the chosen profile context, unselected generation sends the cautious recent-candidate context, and repeated Android handoffs restore only still-existing selected profiles.
- Moments/profile target merging keeps the selected profile identity like iOS, preserves existing aliases/relationship, and records model-visible names as aliases instead of overwriting the selected display name.
- Generated history records preserve the original iOS `GenerationRecord` fields (`sceneSummary`, `latestMessage`, selected style, user goal, replies, copied reply, and creation time) and add Android-compatible result metadata for platform, relationship, emotion, and risk notice. Saved/merged profile cards remain result-page runtime state, matching the iOS `ReplyResultView` flow rather than being stored inside history.
- Personalization settings match the iOS profile, memory, adaptive-style, summary, custom-style creation, and prompt-context behavior. Android flushes pending drafts on page disposal so quick returns do not drop the last edit.
- API settings for Base URL, API key, model names, image parameters, generation parameters, and timeout.
- API configuration defaults, numeric ranges, multimodal capability markers, and model-fetch invalidation were rechecked against the iOS `APIConfig`/`SettingsViewModel` behavior; Android preserves those fields and adds draft-local model discovery plus the optional two-step vision toggle.
- API model capability editing now includes the current visual/text model selections as first-class rows, so manually typed models or models beyond the first visible `/models` preview can still be marked multimodal/reasoning like the iOS selected-model editor.
- API Key secure storage with a local fallback when the platform secure store is unavailable, matching the iOS Keychain fallback behavior.
- `/models` fetching with automatic text/vision model recommendation.
- `/models` responses tolerate standard OpenAI `data`, compatible `models`, `items`, `model_list`/`modelList`, nested list wrappers, top-level list shapes, string model arrays, and `id`/`name`/`model` field aliases.
- `/models` model items also accept compatible `model_name`/`modelName` identifiers and top-level modality/capability metadata such as `input`, `inputs`, `supported_inputs`, `supported_modalities`, `supported_capabilities`, `supported_features`, and `capability_flags`, so gateways that do not nest capabilities under `architecture` still preserve vision/reasoning readiness.
- `/models` parsing skips empty candidate lists and continues to later compatible fields, so gateways that return empty `data` plus populated `models`/`items` still surface available models.
- `/models` permission failures preserve the iOS list-specific API Key guidance and service error detail, so model discovery does not collapse 401/403 responses into a generic generation error.
- Automatic model recommendation only marks vision readiness when a model looks multimodal or was already explicitly marked.
- Model metadata and automatic recommendation share the same multimodal ID detection for common vision/chat models such as `gpt-4o`, `gpt-4v`, `gpt-5`, `gemini`, `llava`, `minicpm`, `internvl`, `step-1v`, `glm-4v`, and `qwen-vl`, and also use provider-declared `/models` metadata such as `modalities` string arrays, `modalities` object arrays, `architecture.input_modalities`, `architecture.modality`, `capabilities.supports_vision`, `capabilities: ["image_input"]`, `supported_features`, `capability_flags`, and `reasoning`, avoiding inconsistent capability chips and saved recommendations.
- Automatic model recommendation preserves valid manually selected text/vision models with trimmed, case-insensitive ID matching while saving the provider-returned canonical ID, so casing differences from compatible gateways do not unexpectedly replace a usable model.
- Automatic model recommendation clears false-positive multimodal markers from voice/non-chat models such as `omni-moderation-latest`, and does not keep them as the active vision model even if an older config marked them as multimodal.
- Automatic model recommendation excludes common non-chat image/video generation and realtime model IDs such as `gpt-image-*`, `dall-e-*`, `imagen`, `sora`, `video`, or `realtime`, so they are not saved as text reply models.
- TokenPlan preset.
- API key secure storage.
- Privacy page and local data clearing.
- Custom styles and personalization memory.
- Moments/profile analysis.
- Moments/profile analysis result shows the saved/merged profile, new insight count, update reason, and a jump to profile detail.
- Conversation simulation.
- Conversation simulation now includes the iOS-style training header/restart loop, current score cards, transcript, coach feedback, selected option feedback, scenario restart behavior, and empty-reply plus busy-state duplicate-submit guards.
- Person profile edits/deletes keep selected profile, Moments result profile, and active simulation state synchronized.
- Optional two-step vision flow: extract screenshot text first, then generate replies from the extracted text.

## Android Replacements

- iOS App Intent shortcut is replaced by Android floating capture, an Android Launcher App Shortcut, and `aichathelper://quick-image` clipboard fallback.
- iOS Share Extension is covered by Android image/text share intents.
- Android selected-text `PROCESS_TEXT` covers the text handoff path; the custom Android system input method has been removed.

## Fixed During Audit

- Avoid duplicate `/chat/completions/chat/completions` endpoint paths when Base URL already points to Chat Completions.
- Normalize `/models` URL generation from root, `/responses`, `/chat/completions`, and `/models` Base URLs.
- Fallback from Responses API to Chat Completions when Responses is unavailable, unsupported, unknown, or returns an unreadable content shape.
- Retry Chat Completions without `response_format` when a provider does not support JSON response format.
- Read Chat Completions content from `message.content`, `delta.content`, or `choice.text` so compatible providers can return either standard or aggregated shapes.
- Read Chat Completions list-style `message.content` parts and nested `text.value` objects used by some compatible gateways.
- Accept compatible reply candidate array aliases such as `replyOptions`, `options`, `candidates`, and `answers`, including `answer` text fields, in both structured and fallback reply parsing.
- Read Responses API text from direct `output_text`, nested `output[].content[]`, and object-style `text.value` payloads instead of treating nested text objects as raw maps.
- Read Responses API structured JSON from `output[].content[].json`, `output[].parsed`, and related normalized keys, so compatible structured-output gateways can return reply/profile/simulation objects without wrapping them as text.
- Read Chat Completions structured JSON from `choices[].message.parsed`, `message.json`, and normalized `structured_content` aliases, matching the Responses parser so compatible structured-output gateways do not fail when `message.content` is empty.
- Scan later Chat Completions `choices` when earlier choices are empty or metadata-only, so compatible providers that return multiple candidates do not fail before the usable JSON candidate.
- Surface compatible-provider error messages from string `error`, `detail`, `error_description`, and nested `errors[]` response fields, skip blank nested `error.message` values, and keep retry decisions based on the provider's usable error text.
- Serialize reply risk notices with the original iOS `riskWarning` field while keeping the Android `riskNotice` alias readable, so generated response JSON stays aligned with the migrated prompt schema.
- Add normal screenshot clipboard import.
- Add Moments/profile clipboard import.
- Guard Android clipboard image import with clipboard/content MIME checks so non-image clipboard URIs are ignored cleanly.
- Add Android share image intake.
- Add Android manifest fallbacks for untyped image/text share and content/file image view handoffs so runtime MIME/URI detection can run when real apps omit `Intent.type`.
- Accept Android image share/view handoffs whose image MIME is only present on `ClipData.description`, matching the clipboard image guard used for providers that hide resolver MIME types.
- Prefer individually image-looking URIs for Android multi-image/share/view handoffs, and keep trying later shared or clipboard URI items if an earlier declared-image item fails to copy or decode.
- Detect Android image URIs from both resolver MIME and path/last-segment file extensions, so content URIs with query strings or provider-specific paths can still be accepted before byte validation.
- Android image share `EXTRA_STREAM` intake accepts single `Uri`, `ArrayList<Uri>`, array, and iterable URI containers before de-duplicating candidates, avoiding typed Bundle reads that can warn or drop compatible handoff shapes.
- Try untyped Android `content://`/`file://` image handoff candidates when providers omit MIME and filename extensions, while keeping app deep links out of the image-import path and relying on decode validation to reject non-images.
- Add Android share text intake.
- Loosen Android share text intake for real-world providers that send `EXTRA_TEXT` with missing or generic MIME types, including `CharSequence` payloads, without converting URI/file shares into text.
- Fall back to explicit shared text when a missing/generic MIME share includes URI candidates that are not readable images, so real-world text shares with preview/file URIs are not swallowed by the image handoff path.
- Reset stale cross-type result-source state when Android external image/text handoffs arrive, so a shared screenshot cannot inherit an older text `lastInput` and shared text cannot inherit an older image result source.
- Delete stale app-owned screenshot paths during external draft resets even if the previous input type is already text, preventing inconsistent handoff state from orphaning transient image files.
- Android share text intake now rejects non-text MIME types before reading `EXTRA_TEXT`, so image/file shares that only include a caption cannot be misrouted into the pasted-text reply flow.
- Handle Android `ACTION_SEND_MULTIPLE` text handoffs and `CharSequenceArrayList` payloads, with an explicit `SEND_MULTIPLE text/*` manifest entry so typed multi-message shares can resolve into the app.
- Skip URI-only `ClipData` items during Android share text intake so untyped file shares are not imported as chat text.
- Reject untyped or `*/*` Android text-share candidates when the Intent also carries a shared URI, so image/file captions are not mistaken for pasted chat text after image detection fails.
- Widen Android manifest text handoff MIME filters from `text/plain` to `text/*` so non-plain text providers can actually dispatch into the app.
- Add Android selected-text `PROCESS_TEXT` intake.
- Accept selected-text `PROCESS_TEXT` payloads from either `EXTRA_PROCESS_TEXT` or a provider's plain `EXTRA_TEXT` fallback, keeping selected chat text handoff available without a system input method.
- Mark Android selected-text `PROCESS_TEXT` handoffs as `EXTRA_PROCESS_TEXT_READONLY` and include the same extra in adb smoke, preserving standard read-only text-processing semantics.
- Guard Android selected-text fallbacks so compatible chat-app selections route to the text page without requiring a custom keyboard service.
- Add TokenPlan preset.
- Add two-step vision recognition.
- Preserve the iOS Keychain fallback behavior for API Key storage: if platform secure storage is temporarily unavailable, Android falls back to a local preference value and clears that fallback during API-key or full privacy cleanup.
- Remove the app module's direct `kotlin-android` Gradle plugin usage.
- Restore iOS-style reply prompt constraints: selected style has highest priority, replies stay under 40 Chinese characters, reply `style` labels must follow the selected style, and risk warnings use the original schema.
- Display platform and relationship metadata on the Flutter result page instead of dropping those fields.
- Match iOS result-page metadata behavior by showing "最后一句" only when the model returns a non-empty latest message, while keeping platform/relationship/emotion fallback metadata visible.
- Preserve TokenPlan preset model capability markers when applying the preset from the API settings screen, so screenshot readiness still sees `gpt-4o-mini` as multimodal.
- Wrap glass-card switch rows in transparent `Material` widgets to avoid Flutter `ListTile` ink/background assertions in API and appearance settings.
- Reset API settings form fields after restoring defaults, instead of only resetting the stored controller state.
- Read the latest API settings text controllers when saving, testing, or fetching models, so manually typed vision/text model names are not lost when the page has not rebuilt.
- Normalize API settings fields before saving/testing/fetching: Base URL, model names, model capability keys, and API Key whitespace are trimmed, and restoring defaults clears stale error banners.
- Let draft `/models` fetching validate only Base URL and API Key, matching iOS model discovery, so a blank or corrupt saved model name can still be recovered by pulling and recommending available models.
- Clamp API numeric settings loaded from migrated/corrupt preferences or saved from drafts to the iOS settings control ranges: image width 320-2048, compression 0.1-1.0, temperature 0-2, max tokens 200-4000, and timeout 10-180.
- Use semantic API config comparison for the privacy clear-all preview, so model capability map ordering cannot make a default-equivalent config look custom or hide an actually custom value.
- Keep the privacy clear-all success banner scoped to the local clear result like iOS, so later unrelated global success messages such as API saves cannot replace the "本地数据已清空" confirmation.
- Reject API Base URLs without an `http`/`https` host across readiness, saving, request validation, and model auto-fetch, and keep a static Android network-security check for the TokenPlan cleartext preset host.
- Settings overview readiness now uses the same text-generation gate as generation pages, so a missing text model is not shown as "API ready".
- Settings overview no longer reports or visually marks full API readiness when only text generation is ready; incomplete screenshot/quick-reply setup now shows the vision blocker in both the summary and the screenshot detail line instead of claiming screenshot replies are available.
- Home API status now uses the same text and vision readiness gates as generation/settings pages, so having an API Key alone no longer makes invalid URLs, missing models, disabled screenshot mode, or unmarked vision models look ready.
- Vision model testing now uses the same multimodal-model gate as iOS, so plain text models cannot be tested with an image payload by mistake.
- Chat reply and Moments profile system prompts now mirror the iOS safety boundaries for anti-manipulation, excessive sexual innuendo, non-diagnostic profile analysis, and non-sensitive trait inference.
- Fallback reply extraction now reads common alias fields such as `message`, `reply`, `content`, and `suggestion` from broken `suggestions`/`replySuggestions` JSON, not only `replies[].text`.
- Persist copied replies from the Flutter history detail screen, including single-reply and copy-all actions, matching the iOS history behavior that marks the last copied reply.
- Keep selected history-detail state synchronized when copying from the current result or native quick overlay updates the same history record.
- Clear stale selected history-detail references after iOS-style 100-record history capping removes the selected record, so detail state cannot point at a record no longer present in the saved history list.
- Persist generated platform, relationship, emotion, and risk metadata into history records so historical detail views keep the same context as the result page.
- Preserve the iOS generated-result `savedProfile` loop: after a reply generation writes or merges a person profile, the result page opens that exact saved profile instead of re-matching the insight heuristically.
- Preserve the iOS manual person-insight save loop from the result page: naming and saving a generated profile draft now marks that same result card as written instead of leaving it in a pending state.
- Clear unsaved result-page person-profile drafts when the Android editor route is dismissed, matching the iOS local sheet so a cancelled draft does not remain as the global selected profile.
- Save history through a sorted copy instead of mutating the caller's in-memory list, matching the iOS store's side-effect-free save behavior.
- Recreate a current result's history record when the user clears history or deletes that current record and then copies from the still-open result page, preserving the copied-reply adoption marker without keeping a stale record id.
- Give official chat styles stable ids and accept the iOS `defaultChatStyleName` key when loading the default style, so selecting a non-default official style survives app restarts instead of falling back to "自然".
- Trim migrated default style ids/names before matching them, so whitespace in restored preferences does not make Android fall back to "自然".
- Refresh active/default generation style objects after personalization changes, so an existing custom style that is renamed or has its rules edited is used immediately instead of leaving the prompt on stale style text.
- Restore iOS-style Chinese short date formatting in Flutter history list and detail pages instead of showing raw `DateTime` strings.
- Decode Swift `JSONEncoder` Date timestamps and common Unix epoch second timestamps from migrated history and people-library records, so recency sorting does not collapse imported items to the current time or drift decades into the future.
- Restore iOS appearance defaults and options: background blur defaults to enabled at radius 14, iOS-style slider ranges and blur toggle behavior are preserved, the sunset theme color is exposed, and the comfortable text-size option is available. The old Flutter `amber` accent value is still accepted as a compatibility alias.
- Clamp migrated or corrupt appearance slider values back into the same ranges exposed by the iOS controls, preventing invalid blur, dim, tint, or border strengths from breaking background rendering.
- Notify after successful custom background imports so the settings page shows the success state once the saved image path has refreshed.
- Normalize imported custom backgrounds by decoding and writing a compressed JPEG, matching the iOS import flow instead of blindly copying unsupported or oversized source files.
- Save imported custom backgrounds through a same-directory temporary JPEG followed by rename, mirroring iOS atomic writes and cleaning temporary files if the write fails.
- Delete imported custom background image files and Android temporary screenshot/cache images when clearing all local data, so privacy cleanup removes both preference records and file-backed local image data.
- Clear-all privacy cleanup also deletes the current app-owned transient screenshot path, while preserving ordinary user-picked image files.
- Reset the in-memory default chat style during full local-data cleanup so a removed custom style cannot remain active until the next app restart.
- Remove both current `defaultChatStyleId` and legacy iOS `defaultChatStyleName` keys during full local-data cleanup, so old migrated default-style choices cannot survive privacy clearing.
- Remove the legacy iOS quick-shortcut `pendingQuickImageRequest` key during full local-data cleanup, so stale shortcut state cannot survive the Android privacy reset even though Android now uses native events and deep links instead.
- Delete app-owned transient screenshot files after successful image generation and Moments/profile analysis, so original screenshots are not kept in cache after the payload has been prepared.
- Finishing a quick-reply session deletes only app-owned transient screenshots, preserving ordinary image files even if a future entry point accidentally passes one into quick reply state.
- Match iOS reply-generation token budgeting by using a minimum 1800 output tokens for text and screenshot reply JSON, while leaving Moments/profile analysis and simulation on the configured limit.
- Clear stale reply results when text generation is blocked by empty input, so the text page does not navigate back to an old result.
- Clear stale generation ids, source state, and regeneration input when text/image generation fails before a valid request is built, so empty text or unreadable images cannot leave "return to edit" or regenerate pointing at the previous successful result.
- Guard overlapping text/screenshot reply generations with a generation revision, so an older request cannot clear the newer loading state, overwrite current results, or save stale history.
- Clear the current history record id as soon as a new reply generation starts, so a later model failure cannot leave copy/native-overlay adoption pointing at the previous successful record.
- Guard the shared busy flag with an operation revision across reply generation, Moments/profile analysis, and conversation simulation, so a late completion from one feature cannot close another feature's active loading state.
- Disable the text-generation submit button until API readiness, non-busy state, and non-empty chat text all match the iOS `canGenerate` gate.
- Enter busy state as soon as screenshot reply generation starts preparing the image payload and keep the screenshot submit button disabled while busy, so double taps or quick-entry repeats cannot enqueue duplicate image generations.
- Accept Android image share/view intents whose `Intent.type` is missing by resolving MIME type from the shared URI or file extension before handing the image to Flutter.
- Align Flutter person-profile merging with the iOS model: incoming display names can update an existing profile, and confidence only increases instead of being overwritten by a lower-confidence extraction.
- Preserve iOS legacy person-profile date recovery: profiles missing `updatedAt` now fall back to `createdAt` instead of being treated as newly updated on load.
- Align Moments/profile analysis target handling with iOS: selected profiles keep their identity while model-visible names are added as aliases, and nameless analyses still create a fallback profile.
- Align Moments/profile context injection with iOS: unselected analysis sends no recent people candidates, while selected analysis sends only the chosen profile summary.
- Confirm the iOS quick shortcut path is intentionally replaced rather than directly ported: iOS App Intent screenshot data plus clipboard fallback maps to Android floating capture plus `aichathelper://quick-image` clipboard fallback.
- Clear stale quick-reply draft-reset requests when a newer native quick image event does not require a draft reset, so late Android handoffs cannot inherit the previous clipboard/URL launch state.
- Confirm Android privacy cleanup covers the current and legacy default-style keys, legacy `appearance.*` keys, secure-storage fallback API Key, privacy confirmation state, imported custom backgrounds, app-owned temp screenshots, and in-memory generation/profile/simulation references.
- Keep Moments/profile result references pointed at the updated profile after profile persistence resorts the in-memory list by update time.
- Fix misplaced Flutter page copy: screenshot/quick reply pages no longer show Moments/profile wording, and the Moments/profile page has its own explanatory header restored.
- Restore the iOS Moments/profile write-back result loop: Flutter now retains the saved/merged profile after analysis and lets the user open the written profile from the analysis result.
- Align unselected person-profile prompt context with the original iOS `PersonProfile.promptContext`: the three most recently updated profiles are provided as cautious matching candidates, preserving iOS people-library context breadth while still avoiding an unbounded profile dump.
- Preserve the iOS person-profile prompt summary's latest update reason, so selected and auto-matched profiles carry the recent evidence behind the stored portrait into generation.
- Restore iOS-style person-profile editor quick-fill presets for stable responses, light humor, avoiding pressure, and planning preference.
- Align manual person-profile saves with iOS storage semantics: every save refreshes `updatedAt`, resorts recency, and keeps selected/simulation/Moments references bound to the saved profile.
- Clamp manually saved person-profile confidence to the iOS editor range `0...1`, so corrupt or programmatic drafts cannot persist out-of-range confidence values after an edit/save.
- Keep selected, simulation, and Moments profile references bound when generated reply insights update an existing people profile.
- Clear generated-result saved-profile references when the people library is cleared, so result cards cannot keep pointing at a profile that no longer exists.
- Restore missing simulation training interactions from iOS: the Flutter page now shows the active profile header, has a restart action, separates score cards/transcript/coach feedback/options/input, highlights selected suggested replies, and prevents empty submissions.
- Keep profile-dependent state coherent when editing or deleting a person: active simulation and Moments result references update or clear with the profile store.
- Keep the Android people-library simulation entry semantically routed to the simulation picker even when the library is empty, so it shows the training empty state instead of silently opening the manual add-person form.
- Match the iOS people-library list preview priority: personality traits, inner needs, key person points, then tone preferences are shown first, instead of hiding core profile clues behind reply preferences or boundaries.
- Match the iOS people-library row footer: show only the first two preview tags with a compact `+N` overflow marker and restore the short relative update time.
- Match the iOS people-library name sort more closely by using natural numeric ordering, so names such as `人物2` sort before `人物10` like `localizedStandardCompare`.
- Harden model response parsing so useful replies, profile insights, and simulation turns are preserved when providers return common alternate field names or numeric scores as strings.
- Responses endpoint parsing also accepts Chat Completions-shaped `choices.message.content` payloads in-place, so compatible proxies that return chat-style bodies from `/responses` do not trigger an unnecessary fallback request.
- Chat Completions parsing also accepts JSON reply payloads returned through `tool_calls[].function.arguments`, `delta.tool_calls[].function.arguments`, or legacy `function_call.arguments`, so tool/function-style compatible providers do not fail with an empty-content error.
- Responses endpoint parsing also accepts JSON reply payloads returned through function/tool-call `output[].arguments` or nested `output[].function.arguments`, matching compatible providers that expose structured output through the Responses output list.
- Preserve useful reply candidates when compatible providers return a top-level JSON array of suggestion objects/strings instead of the requested wrapper object.
- Keep top-level reply-array fallback scoped to actual array responses, so empty `replies` objects with nested person-profile arrays are not mistaken for candidate replies.
- Extract the first balanced JSON object from noisy model output containing multiple JSON objects, preserving usable replies instead of falling back because the first-to-last brace span is invalid.
- Preserve useful simulation training reply options when compatible providers return `options`/`suggestedReplies` as strings instead of objects, rather than replacing them with defaults.
- Preserve reply-generated people-library updates when providers return person insight under aliases such as `profile`, `contactProfile`, `person_profile`, or `person`.
- Preserve reply-generated people-library updates when compatible providers double-encode the nested `personInsight`/profile object as a JSON string inside an otherwise valid response.
- Normalize reply-generated person insight field aliases for tone advice, key points, boundaries, and facts, so provider outputs such as `communicationAdvice`, `keyPoints`, `avoidTopics`, and `knownFacts` still update the people library.
- Preserve parsed reply `personInsight` when serializing `ChatReplyResponse` back to JSON, matching the iOS Codable response model instead of dropping generated people-library evidence.
- Preserve Moments/profile key-person points when providers return them as `importantPoints`, `importantNotes`, or `notes`.
- Preserve Moments/profile advice, boundaries, and facts when compatible providers return people-library aliases such as `replyAdvice`, `preferredTone`, `avoidTopics`, `redFlags`, or `knownFacts`.
- Move the first-run privacy notice from the home screen to the shared scaffold and defer Android external handoffs until the user confirms it, matching the iOS quick shortcut privacy gate.
- Report API readiness and busy-state blockers during quick URL/clipboard auto-generation instead of silently consuming the launch request.
- Show generation errors in the Android quick-reply overlay when auto-generation fails, instead of leaving the overlay in an analyzing/empty state.
- Finish Android quick-reply auto-generation sessions after attempted generation even on model/image failures, so temporary screenshots and auto-generate flags do not linger after the overlay shows the error.
- Preserve the iOS shortcut reply intent when Android quick reply is launched without a typed goal, using the default "generate directly sendable natural replies from the current chat" goal instead of sending an empty objective.
- Keep the iOS goal semantics split between normal screenshot generation and quick reply: empty normal screenshot goals stay empty, while only quick reply falls back to the shortcut-specific default intent.
- Clear any stale quick-reply image before processing the Android quick URL clipboard fallback, so `aichathelper://quick-image` cannot auto-generate from an older screenshot while the new clipboard read is still pending.
- Match iOS user-goal sanitation: text, screenshot, and quick-reply goals are trimmed but no longer truncated, so detailed user intent survives into prompts and history.
- Expand Android deep link handling beyond `quick-image` so iOS-style commands such as `image`, `text`, `moments`, `history`, `people`, `api-settings`, and `privacy-settings` open the matching Flutter pages.
- Parse Android deep link host and path together and normalize route casing/trailing slashes so nested commands such as `people/edit` are not downgraded to `people`.
- Lock Android external route coverage to the full migrated iOS command set, including settings, personalization/style settings, API, privacy, and shortcut-guide aliases.
- Accept full `aichathelper://...` URLs, query strings, and fragments in the Flutter external-route mapper as well as native route strings, so shortcut/floating events cannot be dropped just because the handoff shape differs.
- Accept nested compatibility routes such as `aichathelper://settings/api`, `settings/privacy`, `settings/shortcut`, and `people/new`, so old shortcuts or manually written Android deep links still reach the intended migrated page.
- Keep Android `Intent` text-extra parsing intentionally tolerant of strings, arrays, and iterables with a local deprecation suppress around `Bundle.get`, avoiding typed-extra class-cast warnings without leaving release Kotlin builds noisy.
- Guard Android floating foreground-service startup by API level: `FOREGROUND_SERVICE_TYPE_SPECIAL_USE` is only passed on Android 14+, while Android 10-13 use the normal foreground-service start path.
- Start Android foreground services with the Android 8+ foreground-service API for both the floating window and MediaProjection capture service.
- Guard Android foreground-service promotion inside both services, so `startForeground` failures are surfaced as native error events instead of uncaught service crashes.
- Add Android 13+ notification permission declaration, native permission bridge, and Flutter guide row for foreground-service notification visibility.
- Catch Android floating window and quick-reply service startup failures inside the MethodChannel bridge so vendor/background-start restrictions produce a clean Flutter error.
- Guard Android floating overlay `addView`/`removeView` calls in the service itself, covering failures that happen after the MethodChannel service-start call has already returned.
- Guard Android floating overlay drag updates plus system settings and return-to-app `startActivity` calls, so late overlay permission changes or missing settings handlers do not crash native code.
- Launch Android system settings intents through a copied intent with `FLAG_ACTIVITY_NEW_TASK`, reducing vendor/task-stack failures while preserving guarded MethodChannel errors.
- Guard MediaProjection request re-entry so rapid repeated screenshot requests cannot orphan the first Flutter method result.
- Harden screenshot resource cleanup for MediaProjection `Image` objects, accessibility `HardwareBuffer`s, and intermediate bitmaps.
- Register and unregister a `MediaProjection.Callback` before creating the virtual display, matching Android 14+ requirements for in-app screenshot capture.
- Bound the native pending floating-event queue before Flutter attaches its listener, keeping only the latest events so startup-time share/error bursts cannot grow unbounded.
- Prevent "add person" entry points from accidentally editing the previously selected profile by clearing selection before opening the profile editor.
- Make Flutter history/profile storage decoding as tolerant as iOS `try? JSONDecoder`: invalid blobs return empty lists, and invalid individual records are skipped.
- Preserve legacy/compatible history reply entries when a saved record's `replies` list contains plain strings, so history detail and search do not lose usable candidate replies.
- Map failed gallery/share/clipboard/floating image reads and unsupported image bytes to a clean `AppException`, matching iOS image-processing error behavior.
- Map imported-background JPEG copy write/rename failures to a clean image-copy error and remove any partial temp file, instead of surfacing raw filesystem exceptions.
- Android share/clipboard image copying removes partially written cache files when the source stream fails mid-copy.
- Map raw Dio failures and standard Dart timeout exceptions that bypass the API helper wrapper to clean user-facing messages, matching the iOS `ErrorMapper` behavior more closely.
- Preserve the iOS `NSURLErrorNetworkConnectionLost` copy for interrupted Dio/Socket connections (`Connection reset/lost/closed`, `broken pipe`) and keep those failures eligible for the Responses-to-Chat-Completions network fallback.
- Restore default `gpt-4o-mini` multimodal capability when loading older API settings that lack `modelCapabilities`, while still allowing explicit overrides.
- Resolve, merge, and semantically compare saved model capability markers with trimmed, case-insensitive matching, including map-shaped and list-shaped imports, and compare Base URLs after scheme/host/trailing-slash normalization, so provider/model-name or URL casing differences do not break Android vision readiness, dirty/default-state checks, or leave duplicate capability keys after import, save, or `/models` recommendation.
- Preserve manually selected API models during `/models` recommendation with trim/case-insensitive ID matching, while normalizing the saved selection to the provider-returned model ID.
- Harden API config loading so corrupt config blobs fall back to defaults, and malformed per-model capability entries do not break startup.
- Prevent `/models` recommendation from marking plain text models as multimodal when no vision-capable model is discoverable.
- Align Flutter personalization context with iOS by adding newest-first copied-reply adaptive style examples, numbered memory records, candidate examples, and the fuller reply-quality constraints.
- Align Flutter simulation prompts with the iOS training template so coaching metrics, options, safety rules, and JSON schema are equally constrained.
- Restore the iOS Moments/profile extraction checklist in the Flutter prompt, including platform, visible nickname, content theme, posting style, interaction mode, stable facts, and the non-Moments screenshot fallback.
- Accept common two-step vision extraction aliases such as `messages`, `chatText`, `ocrLines`, `lines`, `summary`, `last`, and `nickname`, plus snake_case/kebab-case variants like `ocr_lines`, `scene_summary`, `latest_message`, `sender_name`, and `message_text`, so OCR-style providers can feed the text-generation step instead of falling back to direct screenshot generation.
- Two-step vision extraction also descends into nested provider containers such as `conversation.messages`, `conversation.items`, `segments`, `blocks`, and `results`, so structured OCR outputs are converted into chat lines instead of leaking raw map strings into the second generation prompt.
- Harden personalization and appearance setting loads so malformed local JSON falls back like iOS stores, and legacy string/number values are accepted where safe.
- Preserve custom personalization style rules when legacy/imported settings store them as a delimited string instead of an array, so user-defined style constraints still reach generation prompts.
- Preserve imported custom personalization styles when compatible backups store a single style under `customStyle` or a style array under `styles`/`stylePresets`, instead of only accepting the iOS `customStyles` array.
- Normalize imported custom style ids with trim/case-insensitive duplicate and official-style collision checks, so empty, duplicate, or official-style collisions cannot make Android restore or delete the wrong default style after a backup/migration.
- Show the iOS-style "自定义" badge on Flutter style cards, so custom reply styles remain distinguishable from official presets on home and generation pages.
- Load and clear legacy iOS-style appearance AppStorage keys (`appearance.*`) so migrated visual preferences are preserved and privacy clear-all removes stale appearance records.
- Harden API numeric fields and person-profile decoding so legacy string numbers do not discard otherwise usable settings or profiles, while nameless profile records are skipped as corrupt.
- Clear stale fetched model lists when the API Base URL or API Key source changes, including save, reset, preset, and clear-key flows, so Android does not show models from a previous provider after iOS-style settings invalidation.
- Ignore stale API connection-test and vision-test successes after settings are saved/reset, the API Key is cleared, or local data is wiped, so an older async test cannot restore a cleared key or overwrite the reset configuration.
- Ignore stale API model-fetch, connection-test, and vision-test failures after settings are changed, the API Key is cleared, or local data is wiped, so an older failed request cannot overwrite the newer success/cleanup feedback.
- Guard overlapping API connection and vision tests with request generations, so an older test cannot clear the newer loading state after a key reset, settings change, or privacy clear.
- Guard overlapping saved-config and draft API model fetches with one shared generation token, so an older model-list request cannot clear the loading state or write stale models while a newer API Settings draft fetch is still running.
- Re-persist the latest API config/key when stale config saves or key-clears finish after another settings change or local-data clear, so delayed settings writes cannot restore cleared credentials or erase newer saved keys.
- Ignore stale reply generation, Moments/profile analysis, and simulation-turn results after history/profile/local-data clears, so older model responses cannot recreate cleared history, people profiles, current results, or simulation messages.
- Ignore stale reply generation, Moments/profile analysis, and simulation-turn failures after clear/restart boundaries, and isolate restarted same-profile simulations so older turns cannot close loading or append messages into the new training session.
- Re-persist the current history and people-library lists when stale copy/delete/profile saves finish after history/profile/local-data clears, so delayed ordinary store writes cannot resurrect cleared records.
- Ignore stale custom-background imports after local-data clear or default-background reset, and delete the late-written background copy so cleared appearance state cannot be restored by an older image save.
- Restrict custom-background file deletion to app-owned support-directory copies, so corrupt or imported appearance paths cannot make privacy clear/reset delete an external picked image file.
- Re-persist the current defaults when stale appearance or personalization saves finish after local-data clear, preventing delayed page/dispose saves from restoring cleared preferences on disk.
- Include fetched API model lists in privacy clear-all cleanup, so clearing local data removes both stored credentials/config and any in-memory provider model names.
- Delete stale Android handoff cache images when a newer shared image or quick-reply screenshot replaces the pending path, so privacy cleanup is not the only chance to remove copied `content://` screenshots.
- Delete partially written Android handoff cache files immediately if copying a shared or clipboard URI fails.
- Use unique Android temp files for clipboard, MediaProjection, and Accessibility screenshots while preserving the cleanup prefixes, avoiding same-millisecond cache filename collisions during rapid repeated handoffs.
- Reset the in-memory current generation input type, style, goal, and response during privacy clear-all, so cleared local data does not leave the previous generation context alive until app restart.
- Reset transient loading flags during privacy clear-all, so generation, model fetching, and API-test spinners cannot survive after the local state has been wiped.
- Ignore stale privacy-notice acknowledgement completions after privacy clear-all, and remove any late persisted acknowledgement so clearing local data reliably makes the notice visible again.
- Guard initial AppState loading with a persisted-domain revision check, so a delayed startup load cannot restore stale API config, history, profiles, personalization, appearance, or privacy state after the user has already changed settings, cleared local data, or accepted the privacy notice.
- Release the initial external-handoff gate when a delayed startup load is discarded because newer settings were saved, while still preserving the latest in-memory settings and only applying the loaded privacy visibility state.
- Delete app-owned transient screenshots that are only referenced as the current editable image during privacy clear-all, without deleting user-picked gallery images.
- Restrict quick-reply session cleanup to app-owned transient screenshot filenames instead of deleting arbitrary paths.
- Preserve the iOS return-to-edit loop after viewing generated replies: Flutter now restores the last editable text or still-existing screenshot, goal, style, and selected chat target when the user taps "返回修改".
- Treat Android external text handoffs as a fresh iOS-style text input session, so selected-text shares do not inherit a stale return-to-edit draft, goal, style, or selected person.
- Replace any currently mounted text-page draft when Android external text handoffs arrive, so share/selected text does not append to stale visible input while the page is already open.
- Treat Android external image handoffs as a fresh iOS-style screenshot input session, so shared screenshots and blank image deep links do not inherit a stale return-to-edit image draft, goal, style, or selected person.
- Reset any currently mounted screenshot-page goal, style, and selected person when Android external image handoffs arrive, so the visible page matches the fresh AppState draft.
- Reset any currently mounted quick-reply goal, style, and selected person before Android quick URL/floating image auto-generation, so external shortcut sessions do not reuse stale visible controls.
- Defer Android share/deep-link/quick handoffs until the persisted privacy state has finished loading, so a cold-start intent cannot bypass the first-run privacy notice before `hasSeenPrivacyNotice` is known.
- Make Android external handoff types mutually exclusive while deferred: a newer image share, text share/selected-text event, or quick screenshot launch clears older pending handoff data and app-owned temp screenshots before stale content can be consumed on another page.
- Clean Android-owned transient screenshot files when an external text/image handoff replaces an editable screenshot draft or pending shared image, while preserving the incoming shared file if it reuses the current path.
- Clear restored return-to-edit text/image drafts when the user taps the page clear action, so leaving and reopening the editor does not resurrect the just-cleared input.
- Keep the restored return-to-edit chat target coherent with people-library mutations by clearing stale selected target ids when a person is deleted or the people library is cleared.
- Regeneration rebuilds person-profile and personalization prompt context from the current app state, so edited/deleted people profiles are not leaked through stale saved `ChatInput` context.
- Match iOS person-profile prompt summaries by using the same field labels, list separators, and selected-target prefix, so generated replies, Moments/profile analysis, simulation, and copied profile context share the original schema.
- Restore the iOS quick-reply copy handoff behavior on Android: generated platform names now map to common chat app packages, the floating reply overlay receives the target package, and tapping a reply copies it before trying to return to the detected chat/social app.
- Android quick-reply return mapping recognizes precise Xiaohongshu English aliases such as `RedNote`, `Little Red Book`, and `xhs` without treating unrelated `red*` platform names as Xiaohongshu.
- Apply the same copy-and-return handoff to the standalone Android floating-capture generation path, not just the quick-reply page auto-generation path.
- Report native return-to-chat failures when the mapped Android chat app package is missing or cannot be launched, instead of silently staying on the overlay/app after a copied quick reply.
- Report quick-reply overlay display failures back into Flutter app state instead of letting MethodChannel failures escape from background auto-generation flows.
- Block concurrent Android floating-capture generations while one screenshot is already being processed, and discard only the newer app-owned transient screenshot so repeated taps do not race two reply generations or delete the active capture.
- Keep Android floating-button startup separate from reply-overlay startup, so showing generated quick replies no longer implicitly creates the persistent AI floating capture button when the service was not already running.
- Stop the Android floating foreground service after a standalone reply overlay is closed or copied, while keeping the service alive when the persistent floating capture button is still visible.
- Preserve iOS-style copied-reply history adoption from the native Android floating reply overlay: tapping a real generated reply now sends a copy event back to Flutter so the current history record's `copiedReply` is updated, while error overlay text is ignored.
- Successful result/history/profile copy actions clear stale copy errors before showing success feedback, matching iOS' page-local copied state instead of leaving an old failure banner visible.
- Refresh any selected history-detail record when current-result/native copied-reply adoption updates the same saved history item.
- Align people-profile detail polish with iOS: the detail page now shows which profile sections should be filled next and gives visible feedback after copying the profile prompt context.
- Match iOS people-profile detail behavior by hiding the latest write-source card when a profile has no `lastSceneSummary` or `lastUpdateReason`, instead of showing an empty "暂无记录" section.
- Restore the iOS people-profile detail safety note that profiles are updated only from chat text, social-post content, visible names, and relationship context, not from avatar/face recognition.
- Match iOS API Key paste feedback in settings: empty clipboard now shows a clear error, and successful paste trims the key and reminds the user to save the config.
- Restore the iOS text-input paste affordance: after clipboard text is appended, the paste button briefly changes to "已粘贴" before returning to its normal state.
- Match iOS personalization custom-style validation by disabling "添加风格" until the style name has non-empty text, instead of accepting a no-op tap.
- Match iOS appearance controls by disabling and dimming the background blur strength slider whenever background blur is turned off.
- Restore iOS-style history detail feedback for "复制全部": the button now briefly changes to "已复制全部" while still persisting the combined copied reply to history.
- Restore iOS-style per-candidate copy feedback in history detail: copying one saved reply marks that reply card as "已复制" while updating the record's copied reply.
- Restore iOS-style result-page copy feedback: copying the first or a specific generated reply now marks the matching reply card and turns "复制首条" into "已复制首条".
- Keep result-page copied state in sync with the current history record, so Android native floating-overlay copy events mark the matching generated reply and show the copied preview after returning to Flutter, while stale copied text from an older response is ignored.
- Trim current result replies before copying, saving copied history, and comparing copied state, so model-output whitespace cannot keep the result page from showing the iOS-style copied marker.
- Guard Flutter clipboard writes for current replies, history replies, and profile summaries, so clipboard failures show a clean error and do not falsely mark history as copied.
- Keep result-page copy feedback tied to actual clipboard success, so failed clipboard writes do not show "已复制" state, close quick sessions, or collapse the quick panel.
- Keep history-detail and profile-detail copy feedback tied to actual clipboard success, so failed clipboard writes do not show copied buttons or local success cards.
- Restore iOS-style simulation option detail: Android now shows each training option's label, predicted score, reply text, and reason instead of collapsing the coaching rationale into a one-line chip, can fill the draft or adopt-and-send an option directly, and shows an opening loading prompt while the first simulated reply is being generated.
- Roll back the pending user message when a simulation reply turn fails, so the training transcript does not keep a user bubble that never received a persona response.
- Restore iOS-style Moments/profile clipboard feedback: after Android reads a screenshot from the clipboard, the button briefly changes to "已读取" before returning to its normal state.
- Align appearance reset semantics with iOS: Android now separates "default background" from "reset personalization"; removing an imported background no longer resets blur, accent color, or text-size preferences, and resetting personalization no longer deletes the imported background.
- Restore iOS-style API Key paste affordance: after a successful clipboard paste, the API settings button briefly changes to "已粘贴"; empty clipboard errors do not trigger or keep a stale success state.
- Restore iOS-style screenshot clipboard feedback: normal screenshot input now keeps a clipboard button available after an image is selected and shows "已读取" after a successful clipboard import.
- Clear stale screenshot clipboard success feedback when Android clipboard image reads fail or return no usable image, so "已读取" only reflects a real imported screenshot across normal, quick-reply, and Moments/profile entry points.
- Keep privacy-page success feedback local to the clear-data action, so unrelated global status messages such as "配置已保存" no longer appear on the privacy screen.
- Restore the iOS result-page copy success card with the copied text preview, and keep it local to result-page copy actions so stale global status messages do not appear above generated replies.
- Keep API Settings feedback scoped to API-related actions, matching the iOS view model boundary so reply-copy or text-input errors do not appear on the settings page.
- Match the iOS API Settings reset confirmation: tapping "恢复默认并清除 Key" now opens a confirmation dialog before clearing the API Key and restoring defaults.
- Keep API Settings model capability edits, TokenPlan presets, and model-list fetch recommendations draft-local until the user explicitly saves or tests with that draft, matching the iOS settings view-model boundary instead of changing generation readiness or persisting API credentials immediately.
- Keep API Settings draft model fetching responsive when the user edits credentials mid-request: invalid newer drafts clear the loading state, and older `/models` responses are ignored instead of overwriting the current draft.
- Keep generation style references coherent when personalization changes: deleting a custom style now resets stale default/current/regeneration styles to the available default style.
- Restore the iOS History detail single-reply copy feedback card: copying one saved reply now briefly shows "已复制到剪贴板" with a preview, not only the per-card copied marker.
- Restore iOS-style person-profile copy feedback on the detail page: the "复制画像上下文" button now briefly changes to "已复制画像上下文" locally instead of relying on a global success banner.
- Align personalization navigation copy with iOS by using "个性化回复" for the settings entry and page title, and restore iOS-style history single-reply button labels "复制这句" / "已复制这句".
- Keep the Android home "设置中心" entry while matching the iOS settings page title "设置" once the page is opened.
- Wrap shared glass action rows in transparent Material so settings/home ListTile ink handling no longer trips Flutter's decorated-background assertion.
- Clear stale cross-page feedback when opening generation, quick reply, Moments/profile, profile editor, or simulation pages, matching iOS' page-local view-model feedback instead of leaking API/settings errors into unrelated workflows.
- Wrap remaining glass-card ListTile status rows in transparent Material, including API status/readiness, banners, and custom-style rows, to avoid Flutter decorated-background ink assertions.
- Make the Android floating-guide "测试快捷入口" button exercise the same clipboard-read and auto-generate state as the `aichathelper://quick-image` fallback, instead of merely opening the normal quick-reply page.
- Match the iOS simulation profile picker by making it selection-only: Android no longer shows the people-library delete action while choosing a training target.
- Align the Android floating-capture guide with the native service behavior: the external floating button now requires accessibility screenshot support before it can be started, while MediaProjection remains the in-app screenshot path.
- Remove an unused legacy floating settings sheet so floating-window startup has a single Android entry point with the full API, vision, overlay, and accessibility readiness checks.
- Guard privacy clear-all cleanup for quick/share image paths with the same app-owned transient screenshot check used elsewhere, so arbitrary user-picked files are never deleted just because a runtime field points at them.
- Keep the default-style setter bounded to the current available style list, so stale custom-style objects cannot be saved again after the style has been deleted.
- Let the default-style setter accept legacy iOS official style names when ids differ, while refusing ambiguous same-name custom-style conflicts.
- Guard native quick-reply clipboard writes: Android now emits an error instead of crashing the floating service or marking a reply copied when `ClipboardManager.setPrimaryClip` fails.
- Report revoked/missing overlay permission from the native floating service instead of silently starting a foreground service with no visible floating button or reply panel.
- Consume pending shared-image handoff state even when the image is already displayed on the screenshot page, preventing repeated processing on later rebuilds or returns.
- Keep the Android floating-guide readiness wording honest: the API card now says the quick-reply configuration is ready, while actual floating-entry availability still depends on overlay and accessibility permissions.
- Guard Android floating-guide platform failures so permission-status reads, permission-setting actions, notification permission requests, quick URL clipboard copy, floating-window startup, and floating-window shutdown show clean user feedback instead of surfacing raw platform exceptions.
- Keep Android external handoff navigation behind the first-run privacy gate: share image/text, quick URL routes, and deferred floating captures now save their pending data without jumping pages until the privacy notice is accepted.
- Guard Flutter text clipboard reads for pasted chat text and API Key paste, so platform clipboard failures show clean page-local errors instead of escaping the UI future or falsely showing paste success.
- Guard remaining Android MethodChannel service/permission actions: notification permission launch, floating-window shutdown, and quick-panel collapse now return clean errors and native events instead of letting platform exceptions escape or leave pending results hanging.
- Guard Android screenshot launch and save failures: MediaProjection authorization-intent creation, AccessibilityService `takeScreenshot`, and native JPEG writes now report clean errors and delete partial capture files instead of hanging method results or leaving corrupt cache images.
- Lock the Android AccessibilityService screenshot capability declaration (`canTakeScreenshot`) in tests, so the floating one-tap screenshot replacement cannot silently lose its Android 11+ service capability.
- Cancel pending Android native screenshot/notification permission MethodChannel results when the activity is destroyed, and stop delayed MediaProjection capture from saving or emitting stale screenshots after the result has been cancelled.
- Keep App-internal MediaProjection/accessibility screenshot results on the MethodChannel path only, so they do not replay as external quick-image events and reset a mounted quick-reply draft; external floating-button captures still emit explicit `source=floating` events.
- Keep aliases available for matching/search while omitting the non-iOS `别名` line from person-profile prompt summaries, preserving the original prompt schema exactly.
- Match iOS simulation fallback cleanup by stripping list prefixes and bounding non-JSON persona messages to 90 characters, preventing malformed provider text from creating oversized training bubbles.
- Remove the custom Android system input method service, generated pinyin dictionaries, rime-ice asset, input-method manifest registration, and floating-guide input-method controls while preserving selected-text `PROCESS_TEXT` routing.
- Refresh API Settings local readiness state when users manually edit text or vision model names, so test buttons and capability checks immediately reflect the typed model instead of waiting for another rebuild.
- Preserve iOS `/models` metadata and display behavior by retaining `owned_by`/`ownedBy`, exposing voice/text/vision model hints, and marking voice models with the original `· 语音` display suffix in API Settings.
- Sort fetched `/models` ids with the same natural numeric ordering used for iOS-style `localizedStandardCompare`, so `model-2` appears before `model-10` and mixed-case ids do not jump ahead of alphabetic groups.
- Harden compatible-provider API response parsing by accepting separator/case variants in `/models` list keys, model item ids/owners, Chat Completions content keys, Responses API text keys, and provider error-message payloads.
- Recognize map-shaped `/models` modality metadata such as `modalities.input` / `input_modalities`, so compatible providers can still auto-mark and recommend vision-capable models.
- Keep model-list voice/transcription and non-chat detection consistent across API Settings display and automatic text-model recommendation, so `whisper`/`transcribe` and embedding/moderation/rerank models are not treated as chat text candidates.
- Align the text and screenshot reply prompt JSON schema wording with the original iOS templates for `latestMessage` and person-insight fields, reducing model-output drift between platforms.
- Align personalization summary text with iOS by listing only active features (`口语化`/`稳重表达`, `我的资料`, `记忆`, `自适应`, and `自定义风格 N`) instead of Android-only disabled-state descriptions.
- Match iOS quick-shortcut readiness copy when API Key is missing, so the Android quick-reply flow says the shortcut will not send requests instead of using the normal screenshot-page wording.
- Restore the remaining iOS History detail copied-reply feedback path: opening a record now marks the previously copied candidate, and copying from the "上次复制的回复" card shows the same local "已复制到剪贴板" preview as copying a candidate reply.
- Flush pending personalization drafts when leaving the Android personalization page, matching iOS' immediate draft persistence so quickly returning after editing age or manual memory does not drop the last change.
- Mirror the screenshot-page clipboard affordance in quick reply: after manually reading a clipboard screenshot from the Android quick-reply page, the button briefly changes to "已读取" instead of staying visually idle.
- Guard Android quick-reply auto-generation's native prep steps, so failures while showing the analyzing overlay or collapsing the app report clean errors and clear the transient quick session instead of leaving the shortcut state stuck.
- Clear Android quick-reply transient sessions when auto-generation is blocked by missing API readiness or a busy generation state, so shortcut/floating launches do not leave stale temporary screenshots behind.
- Keep appearance background-import feedback local to the appearance card: successful imports and background-save failures now show in the same settings section like iOS, while unrelated API/copy feedback is filtered out.
- Align normal generation page navigation titles with iOS: Android now opens the screenshot page as "截图生成" and the pasted-chat page as "文本生成" while keeping the home entry labels unchanged.
- Match iOS API Settings model-list invalidation: editing or clearing the draft Base URL/API Key now immediately hides stale `/models` results instead of showing a list fetched from a previous provider or credential.
- Keep Moments/profile analysis results page-local like iOS: opening the page, selecting/replacing a screenshot, reading a clipboard screenshot, or deleting the image now clears stale analysis/write-back cards from the previous image.
- Invalidate pending Moments/profile analysis requests when the page clears/replaces the image or starts another analysis, so older model responses cannot restore stale analysis cards or write old profiles over the newer image.
- Clear the Moments/profile page's local preview path after a successful app-owned clipboard/floating/accessibility screenshot analysis, so Android does not keep rendering or retrying an image file that was already privacy-cleaned from cache; user-picked gallery images remain available.
- Delete app-owned clipboard/cache screenshots when the normal screenshot page replaces, deletes, or disposes its local preview, so abandoned temporary images do not linger if the user switches to a gallery image or leaves before generation.
- Match iOS simulation session defaults: starting training from a newly selected person now resets the scenario to "日常闲聊", while restarting within the active simulation still keeps the current scenario.
- Reset the global simulation scenario during privacy clear-all, so wiping local data cannot leave a stale training mode behind for later people-library sessions.
- Restore iOS History detail initial copied-state handling: previously copied copy-all text now opens with the "上次复制的回复" card already marked as copied, not only copied single-candidate replies.
- Align Android floating-guide permission resume behavior: opening accessibility setup now sets the same post-permission auto-start flag as overlay setup, and rolls it back if the settings launch fails.
- Keep Android floating-guide permission resume behavior consistent after the settings intent returns: both overlay and accessibility setup now immediately refresh with auto-start enabled, instead of relying only on a lifecycle resume callback.
- Only arm Android floating-guide post-permission auto-start when the relevant overlay/accessibility permission is missing, so viewing an already-granted settings page cannot unexpectedly start the floating button after returning.
- Upgrade patch-level Android plugin transitive dependencies (`image_picker_android` and `shared_preferences_android`) so debug/release APK builds no longer emit Flutter's future Built-in Kotlin compatibility warning.
- Add an explicit release-signing guard: local release APK/AAB builds can still use the debug keystore, but setting `ENFORCE_RELEASE_SIGNING=true` fails the build unless release keystore properties are provided.
- Align Android package versioning with Flutter release metadata: release APK/AAB builds now read `flutter.versionCode` and `flutter.versionName` from Gradle properties or `android/local.properties` instead of hardcoding `1` / `1.0`, so `--build-number` and `--build-name` can produce upgradeable artifacts.
- Synchronize README Android delivery instructions with the current package configuration by documenting Android SDK Platform 36, release AAB builds, and `lintVitalRelease`.
- Update project-owned Gradle repository declarations to assignment syntax, removing the local Gradle 10 deprecation warnings from `android/settings.gradle` and `android/build.gradle`.
- Ignore generated Flutter crash reports so stale toolchain failures do not pollute source-tree audits after successful reruns.
- Align Android appearance accent labels with the iOS `AppAccentColor` options, including using "玫瑰" for the `rose` theme instead of the earlier Flutter-only "玫红" label.
- Resize Android launcher icons to density-specific mipmap dimensions instead of shipping the 1024px source icon in every density bucket, and lock the expected sizes in tests.
- Restrict app-owned transient screenshot deletion to files inside the app temp/cache directory, so a user-picked file with an Android capture-like prefix is never deleted merely because its filename matches `floating-capture-*`, `clipboard-image-*`, or `accessibility-capture-*`.
- Stop the Android floating foreground service if the reply overlay cannot be shown because overlay permission was revoked, preventing an invisible service from lingering after a permission-state change.
- Stop the Android floating foreground service if the quick-reply panel fails during window attachment, preventing an invisible foreground service when vendor overlay/window races reject the panel after permission checks pass.
- Keep Android floating-capture setup and screenshot-failure messages out of the copyable reply list, so native guidance/errors cannot be copied as chat replies or saved as the last copied response.
- Use non-copy guidance in the native quick-reply overlay when it shows only a message/error and no reply candidates, so Android no longer tells users to tap a non-existent reply to copy.
- Extend the Android quick-reply MethodChannel with a non-copyable `message` overlay path and use it for floating/shortcut failures, keeping generated replies as copyable buttons while showing blocked/error states as guidance only.
- Keep Android quick-reply completion helpers from falling back to copyable error buttons when generation returns with `errorMessage` but no reply candidates; only real model replies can appear as copy actions.
- Remove the legacy quick-reply aggregate helper that mixed reply candidates and error messages into one list, making the copyable-reply/message split explicit in both production code and tests.
- Guard copied-reply writes with the active generation revision, so a delayed clipboard or history save cannot overwrite the full local-data cleanup banner or re-mark cleared history after privacy reset.
- Lock the delayed generation-history save path with a regression test, proving clear-all still wins if the model response has returned but history persistence is still pending.
- Guard delayed clipboard failures for reply and profile-summary copies, so a stale platform clipboard error cannot replace the privacy clear-all confirmation after local data has been reset.
- Remove default-style, personalization, and appearance keys if a delayed preference save completes after local-data cleanup, preserving the iOS-style privacy clear semantics instead of recreating default preference records.
- Remove API config and API Key records if a delayed config save, connection test save, vision test save, or model-recommendation save completes after local-data cleanup, so stale API settings writes cannot recreate local privacy data.
- Accept localized and compatible personalization gender values (`女`, `男`, `其他`, `用户自定义/非二元`, `non_binary`, `non-binary`, and `不填写`) during settings restore/import, preserving the iOS "我的资料" prompt context even when migrated data stores display text or raw enum variants.
- Accept singular and compatible person-alias fields (`alias`, `alsoKnownAs`) in both generated person insights and saved people-library profiles, so migrated or provider-shaped nickname data is not dropped.
- Filter blank and `未知` entries when merging generated insights into an existing people-library profile, matching iOS `PersonProfile.merged` list cleanup so placeholder model output does not pollute saved profile prompts.
- Match the iOS simulation fallback score state when a model returns non-JSON text: favorability 58, tension 42, trust 55, and interest 60 are preserved alongside the same suggested replies, while the metrics list is completed with the six required coaching metrics.
- Lock the five iOS conversation-simulation scenarios and prompt goals in Flutter tests, preserving "日常闲聊", "安慰情绪", "邀约推进", "化解误会", and "表达边界" as the migrated training modes.
- Match iOS Responses API fallback behavior for network errors: timeout, connection, and generic network failures on `/responses` now automatically retry the equivalent Chat Completions endpoint before surfacing an error.
- Lock the original iOS `GenerationRecord` Codable field shape in Flutter tests, including UUID ids, iOS `Date` timestamps, selected style, user goal, copied reply, and reply `style` fields, while keeping result-page saved-profile state out of persisted history like iOS.
- Align API settings button readiness with iOS: model fetching is disabled until Base URL and API Key are usable, and connection-test and vision-test actions are mutually disabled while either test is running.
- Prioritize app-owned `aichathelper://` view routes before generic image/text handoff parsing, so incidental `ClipData` attached by launchers or third-party apps cannot steal settings/text/quick deep links into the screenshot share flow.
- Normalize visible profile fallback copy from the stale `画像待完善` placeholder to the iOS wording `等待更多聊天样本完善画像`, keeping the people-card and selection-dialog fallback aligned with the original profile row.
- Allow API Settings to save and connection-test a text-only configuration when screenshot mode is disabled and the vision model field is empty, while keeping vision testing and screenshot generation blocked until a vision model is present and marked multimodal.
- Preserve a people-library profile's previous display name as a matching alias when generated insights rename the profile, preventing later chats that use the old name from creating a duplicate profile while keeping aliases out of the iOS-style prompt summary.
- Extract scalar text from nested provider objects such as `{text: ...}`, `{name: ...}`, `{label: ...}`, or `{summary: ...}` when parsing reply metadata and suggestions, preventing Dart map strings from leaking into result pages, history records, and restored data.
- Re-audit the migrated history and people-library management surfaces against iOS: history search/filter/counters/empty states/detail copy feedback, people search/sort/statistics/empty state/delete/clear flows, profile detail/editor, and simulation selection entry are all represented in Flutter; Android also keeps selected history/profile references synchronized after copy, delete, clear, save, and profile updates.
- Clear the Android accessibility screenshot service singleton on service unbind as well as destroy, so disabling the service cannot leave Flutter believing the iOS-replacement screenshot permission path is still available.
- Read Android's system-enabled accessibility service list when checking the AI Reply accessibility permission, instead of relying only on the current process singleton. This prevents app/process restarts from making the floating-window guide think the user must reopen accessibility settings even though the service permission is still enabled.
- Accept Android external deep-link aliases for the actual Flutter quick-reply and floating-guide route names (`quick-reply`, `floating-guide`, and related variants), so native `aichathelper://...` launches do not get ignored when they use Android page terminology instead of the original iOS shortcut wording.
- Delete the screenshot page's previous app-owned transient preview when a mounted page consumes a newer Android shared-image handoff, matching the existing picker/clipboard replacement cleanup and avoiding stale clipboard/share files after route-level image replacement.
- Preserve conversation-simulation scorecards when compatible providers return metrics as an object map such as `{自然度: {score: ...}}` instead of the prompt's array shape, while still filling the iOS-required core training metrics.
- Align generic timeout error mapping with the iOS network copy, so raw `TimeoutException` and string timeout fallbacks show the same `接口请求超时，请稍后重试或调大请求超时。` message as Dio/API timeouts.
- Extract usable fallback replies from broken compatible-provider string arrays such as `"replies":["..."]`, while keeping extraction bounded to the array so later malformed profile fields are not shown as reply candidates.
- Update the privacy page copy for Android's optional two-step vision flow: the app still does no local OCR, but when two-step vision is enabled the configured vision model may extract screenshot text for the current generation, and that text is not long-term cached.
- Synchronize the README Android privacy/permission section with the two-step vision behavior, so the public handoff docs match the in-app privacy copy.
- Guard the API Settings auto-fetch microtask with `mounted` before reading Riverpod state, so a very fast page disposal cannot trigger a provider read after the page has unmounted.
- Guard Android image-picker, screenshot, clipboard, text paste, Moments image-pick, and API Key paste async returns with `mounted` before touching provider/UI state, preventing disposed pages from handling late platform results.
- Guard the conversation simulation reply-submit path with `mounted` before clearing the local draft after the model call, and clear only after a successful simulated turn so failed submissions keep the draft available for retry.
- Guard appearance background imports with `context.mounted` after the Android image picker returns, so a late picker result cannot save a custom background after the settings page has gone away.
- Accept additional deep-link wrapper/query/event aliases (`uri`, `link`, and `destination`) across Flutter and Android native route parsing, so launchers, automation tools, or compatible bridge payloads that do not use `route` or `url` still reach migrated pages.
- Accept JSON-string native event payloads in the Flutter floating-capture parser, so smoke tools or bridge layers that serialize EventChannel maps still route image/text/copy/error events through the same Android handoff path.
- Keep Android string resources (`app_name`, shortcut labels, and AccessibilityService description) in `strings.xml` while leaving `styles.xml` for themes, so manifest/service declarations stay easy to audit and localize.
- Add an Android Launcher App Shortcut for `quick_image_reply`, wired through manifest `android.app.shortcuts` metadata to the existing `aichathelper://quick-image` flow, so the iOS AppShortcuts screenshot entry has a discoverable Android launcher equivalent.
- Lock the Android Launcher App Shortcut target package to the Gradle `applicationId` in tests, preventing a future package-name change from leaving the migrated iOS shortcut replacement pointed at a stale activity.
- Re-audit iOS `SafetyChecker` and error-mapping parity: the original safety layer only trims user goals, which is preserved by Flutter's `sanitizedGoal` tests, while iOS timeout/network copy is covered by `userMessageFor`/API error mapping tests.
- Re-audit image processing parity against iOS `DefaultImageProcessor` and `Base64ImageEncoder`: Flutter also normalizes orientation, bounds image width through the same settings range, clamps JPEG quality, encodes JPEG payloads off the UI path, and emits the same `data:<mime>;base64,<payload>` request shape.
- Re-audit route and settings-center parity against iOS `AppRoute`, `HomeView`, and `SettingsView`: every iOS destination has a Flutter route or Android replacement, while Android adds quick-reply/detail/simulation child routes and uses stricter text/vision readiness before showing setup as complete.
- Re-audit iOS `QuickShortcutReplyView` against Android quick reply: missing-screenshot recovery, API-readiness blocking, default quick-reply goal, screenshot preview, clipboard fallback, non-copyable error overlays, and return-to-chat behavior are represented in the Android replacement flow, with real overlay/clipboard behavior still left to device proof.
- Re-audit iOS `PersonProfileStore`/`PersonProfile.merged` against Flutter profile merging: display-name matching, alias matching, confidence maxing, list cleanup/capping, selected-profile prompt context, and sorted 50-profile storage caps are preserved; Flutter additionally retains the old display name as a hidden matching alias after model-driven renames to avoid duplicate future profiles.

## Still Needs Device Proof

These cannot be fully proven by static analysis, unit tests, APK build, or the current Android emulator smoke alone:

- Physical Android-device behavior across common vendors remains unproven.
- Overlay permission grant flow on common Android vendors.
- Floating button display, dragging, and tap handling.
- AccessibilityService screenshot behavior on Android 11+ devices.
- In-app MediaProjection screenshot behavior.
- Share image import from real chat/social apps, especially large or cloud-backed `content://` images. Emulator typed and untyped file-URI `ACTION_SEND`/`ACTION_VIEW` delivery passed.
- Share text import from real chat/social apps. Emulator explicit `ACTION_SEND` and `ACTION_SEND_MULTIPLE text/plain` delivery passed.
- Selected-text `PROCESS_TEXT` availability in real chat apps. Emulator explicit read-only `ACTION_PROCESS_TEXT` delivery passed.
- Quick URL fallback: screenshot -> copy to clipboard -> open `aichathelper://quick-image`. Emulator quick-URL intent delivery passed, but clipboard screenshot import still needs proof.
- Launcher long-press surface rendering for the Android Launcher App Shortcut. Emulator `cmd shortcut get-shortcuts` registration passed, but the visual launcher menu still needs device/launcher proof.
- The helper `scripts/android_smoke.sh build/app/outputs/flutter-apk/app-debug.apk` now covers install, installed native component/permission inspection, Android Launcher App Shortcut registration, cold launch, API deeplink, typed and untyped file-URI image share, typed and untyped file-URI image view, single text share, multi-text share, explicit read-only `PROCESS_TEXT`, quick URL delivery, process liveness, and recent logcat crash markers; run it on each emulator/physical device in the final matrix before manual app-specific checks.
- The smoke helper accepts both Android component dump formats (`package/.Class` and `package/package.Class`) when checking installed native components, reducing false failures across vendor builds.
- The smoke helper decodes its generated PNG fixture with a GNU/BSD-compatible `base64` fallback (`--decode` then `-D`), so the Android migration smoke can run from typical Linux and macOS shells.
- The smoke helper removes its generated PNG fixture from the device download directory on exit, so repeated manual matrix runs do not leave stale test images behind.

## Known Remaining Risk

- Local release signing intentionally falls back to the debug keystore for development builds. Set `ENFORCE_RELEASE_SIGNING=true` plus release keystore properties before producing distributable APKs or app bundles.
- `lintVitalRelease` passes, but Gradle 8.14 still prints an unsupported Kotlin plugin warning for Flutter's included Gradle build because Gradle embeds Kotlin 2.0.21 while the local Flutter Gradle plugin requests Kotlin 2.2.20. Treat this as a toolchain warning to revisit with future Flutter/Gradle upgrades.

## Suggested Manual Test Matrix

1. Install the debug APK on an Android 11+ device.
2. Open the app, set API Base URL and API Key, then run text and vision model tests.
3. Generate a reply from pasted text.
4. Generate a reply from a gallery screenshot.
5. Copy a screenshot to the clipboard and read it in the screenshot page.
6. Share an image from a chat/social app to AI Reply.
7. Share text from a chat/social app to AI Reply.
8. Select text in a chat app and use the system text-processing menu to open AI Reply.
9. Enable overlay permission, start the floating button, and verify it appears/drags.
10. Enable AccessibilityService and verify floating one-tap screenshot generates replies.
11. Verify the quick URL fallback with `aichathelper://quick-image`.
13. Confirm copied replies can be pasted back into the original chat app.
