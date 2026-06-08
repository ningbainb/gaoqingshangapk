part of 'storage.dart';

Future<void> _clearAllFor(LocalStore store) async {
  final prefs = await store._ready;
  await prefs.remove(LocalStore._settingsKey);
  await prefs.remove(LocalStore._historyKey);
  await prefs.remove(LocalStore._profilesKey);
  await prefs.remove(LocalStore._personalizationKey);
  await prefs.remove(LocalStore._defaultStyleIdKey);
  await prefs.remove(LocalStore._legacyDefaultStyleNameKey);
  await prefs.remove(LocalStore._legacyPendingQuickImageRequestKey);
  await prefs.remove(LocalStore._appearanceKey);
  await _removeLegacyAppearancePreferences(prefs);
  await prefs.remove(LocalStore._privacyKey);
  await prefs.remove(LocalStore._apiKeyFallbackKey);
  try {
    await store._secure.delete(key: LocalStore._apiKey);
  } catch (_) {}
}
