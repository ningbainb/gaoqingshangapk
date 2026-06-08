part of 'storage.dart';

Future<ReplyPersonalizationSettings> _loadPersonalizationFor(
    LocalStore store) async {
  final prefs = await store._ready;
  final decoded = _jsonObjectPreference(prefs, LocalStore._personalizationKey);
  if (decoded == null) return ReplyPersonalizationSettings.defaults;
  try {
    return ReplyPersonalizationSettings.fromJson(decoded);
  } catch (_) {
    return ReplyPersonalizationSettings.defaults;
  }
}

Future<void> _savePersonalizationFor(
  LocalStore store,
  ReplyPersonalizationSettings settings,
) async {
  final prefs = await store._ready;
  await prefs.setString(
    LocalStore._personalizationKey,
    jsonEncode(settings.normalized().toJson()),
  );
}

Future<void> _clearPersonalizationFor(LocalStore store) async {
  final prefs = await store._ready;
  await prefs.remove(LocalStore._personalizationKey);
}

Future<String?> _loadDefaultStyleIdFor(LocalStore store) async {
  final prefs = await store._ready;
  final value = _storedStringPreference(
        prefs,
        LocalStore._defaultStyleIdKey,
      ) ??
      _storedStringPreference(prefs, LocalStore._legacyDefaultStyleNameKey);
  return cleanIdentifierText(value);
}

Future<void> _saveDefaultStyleIdFor(LocalStore store, String styleId) async {
  final prefs = await store._ready;
  final cleanedStyleId = cleanIdentifierText(styleId);
  if (cleanedStyleId == null) {
    await prefs.remove(LocalStore._defaultStyleIdKey);
  } else {
    await prefs.setString(LocalStore._defaultStyleIdKey, cleanedStyleId);
  }
  await prefs.remove(LocalStore._legacyDefaultStyleNameKey);
}

Future<void> _clearDefaultStyleIdFor(LocalStore store) async {
  final prefs = await store._ready;
  await prefs.remove(LocalStore._defaultStyleIdKey);
  await prefs.remove(LocalStore._legacyDefaultStyleNameKey);
}
