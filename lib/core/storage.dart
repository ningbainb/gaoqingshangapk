import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_feedback.dart';
import 'bool_value.dart';
import 'models.dart';
import 'record_retention.dart';
import 'text_cleaning.dart';

part 'storage_api_key.dart';
part 'storage_appearance.dart';
part 'storage_config.dart';
part 'storage_data_clear.dart';
part 'storage_profiles_history.dart';
part 'storage_preferences.dart';
part 'storage_user_settings.dart';

class LocalStore {
  static const _maxHistoryCount = 100;
  static const _maxProfileCount = 50;
  static const _settingsKey = 'apiConfig';
  static const _historyKey = 'generationHistory';
  static const _profilesKey = 'personProfiles';
  static const _personalizationKey = 'replyPersonalizationSettings';
  static const _defaultStyleIdKey = 'defaultChatStyleId';
  static const _legacyDefaultStyleNameKey = 'defaultChatStyleName';
  static const _legacyPendingQuickImageRequestKey = 'pendingQuickImageRequest';
  static const _appearanceKey = 'appearanceSettings';
  static const _legacyAppearanceBlurEnabledKey =
      'appearance.isBackgroundBlurEnabled';
  static const _legacyAppearanceBlurRadiusKey =
      'appearance.backgroundBlurRadius';
  static const _legacyAppearanceDimOpacityKey =
      'appearance.backgroundDimOpacity';
  static const _legacyAppearanceGlassTintStrengthKey =
      'appearance.glassTintStrength';
  static const _legacyAppearanceGlassBorderStrengthKey =
      'appearance.glassBorderStrength';
  static const _legacyAppearanceAccentColorNameKey =
      'appearance.accentColorName';
  static const _legacyAppearanceTextSizeNameKey = 'appearance.textSizeName';
  static const _legacyAppearanceCustomBackgroundVersionKey =
      'appearance.customBackgroundVersion';
  static const _legacyAppearanceKeys = [
    _legacyAppearanceBlurEnabledKey,
    _legacyAppearanceBlurRadiusKey,
    _legacyAppearanceDimOpacityKey,
    _legacyAppearanceGlassTintStrengthKey,
    _legacyAppearanceGlassBorderStrengthKey,
    _legacyAppearanceAccentColorNameKey,
    _legacyAppearanceTextSizeNameKey,
    _legacyAppearanceCustomBackgroundVersionKey,
  ];
  static const _privacyKey = 'hasSeenPrivacyNotice';
  static const _floatingAutoStartKey = 'floatingAutoStartEnabled';
  static const _apiKey = 'apiKey';
  static const _apiKeyFallbackKey = 'apiKey.keychainUnavailableFallback';

  final _secure = const FlutterSecureStorage();
  SharedPreferences? _prefs;

  Future<SharedPreferences> get _ready async =>
      _prefs ??= await SharedPreferences.getInstance();

  Future<APIConfig> loadConfig() => _loadConfigFor(this);

  Future<void> saveConfig(APIConfig config) => _saveConfigFor(this, config);

  Future<void> clearConfig() => _clearConfigFor(this);

  Future<String> loadAPIKey() => _loadAPIKeyFor(this);

  Future<void> saveAPIKey(String key) => _saveAPIKeyFor(this, key);

  Future<List<GenerationRecord>> loadHistory() => _loadHistoryFor(this);

  Future<void> saveHistory(List<GenerationRecord> records) =>
      _saveHistoryFor(this, records);

  Future<List<PersonProfile>> loadProfiles() => _loadProfilesFor(this);

  Future<void> saveProfiles(List<PersonProfile> profiles) =>
      _saveProfilesFor(this, profiles);

  Future<ReplyPersonalizationSettings> loadPersonalization() =>
      _loadPersonalizationFor(this);

  Future<void> savePersonalization(ReplyPersonalizationSettings settings) =>
      _savePersonalizationFor(this, settings);

  Future<void> clearPersonalization() => _clearPersonalizationFor(this);

  Future<String?> loadDefaultStyleId() => _loadDefaultStyleIdFor(this);

  Future<void> saveDefaultStyleId(String styleId) =>
      _saveDefaultStyleIdFor(this, styleId);

  Future<void> clearDefaultStyleId() => _clearDefaultStyleIdFor(this);

  Future<AppearanceSettings> loadAppearance() => _loadAppearanceFor(this);

  Future<void> saveAppearance(AppearanceSettings settings) =>
      _saveAppearanceFor(this, settings);

  Future<void> clearAppearance() => _clearAppearanceFor(this);

  Future<bool> hasSeenPrivacyNotice() async =>
      _boolPreference(await _ready, _privacyKey) ?? false;

  Future<void> markPrivacyNoticeSeen() async =>
      (await _ready).setBool(_privacyKey, true);

  Future<void> clearPrivacyNoticeSeen() async =>
      (await _ready).remove(_privacyKey);

  Future<bool> loadFloatingAutoStart() async =>
      _boolPreference(await _ready, _floatingAutoStartKey) ?? false;

  Future<void> saveFloatingAutoStart(bool enabled) async =>
      (await _ready).setBool(_floatingAutoStartKey, enabled);

  Future<void> clearAll() => _clearAllFor(this);
}
