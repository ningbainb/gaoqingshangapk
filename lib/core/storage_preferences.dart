part of 'storage.dart';

AppearanceSettings? _loadLegacyAppearance(SharedPreferences prefs) {
  if (!LocalStore._legacyAppearanceKeys.any(prefs.containsKey)) return null;
  return AppearanceSettings.fromJson({
    'isBackgroundBlurEnabled':
        _boolPreference(prefs, LocalStore._legacyAppearanceBlurEnabledKey),
    'backgroundBlurRadius':
        _doublePreference(prefs, LocalStore._legacyAppearanceBlurRadiusKey),
    'backgroundDimOpacity':
        _doublePreference(prefs, LocalStore._legacyAppearanceDimOpacityKey),
    'glassTintStrength': _doublePreference(
        prefs, LocalStore._legacyAppearanceGlassTintStrengthKey),
    'glassBorderStrength': _doublePreference(
        prefs, LocalStore._legacyAppearanceGlassBorderStrengthKey),
    'accentColorName': _stringPreference(
        prefs, LocalStore._legacyAppearanceAccentColorNameKey),
    'textSizeName':
        _stringPreference(prefs, LocalStore._legacyAppearanceTextSizeNameKey),
  });
}

Future<void> _removeLegacyAppearancePreferences(SharedPreferences prefs) async {
  for (final key in LocalStore._legacyAppearanceKeys) {
    await prefs.remove(key);
  }
}

bool? _boolPreference(SharedPreferences prefs, String key) {
  return boolValue(_preferenceValue(prefs, key));
}

double? _doublePreference(SharedPreferences prefs, String key) {
  final value = _preferenceValue(prefs, key);
  if (value is num) return value.toDouble();
  if (value is String) {
    final text = cleanNonEmptyText(value);
    return text == null ? null : double.tryParse(text);
  }
  return null;
}

String? _stringPreference(SharedPreferences prefs, String key) {
  return cleanNonEmptyText(_preferenceValue(prefs, key)?.toString());
}

Object? _preferenceValue(SharedPreferences prefs, String key) {
  try {
    return prefs.get(key);
  } catch (_) {
    return null;
  }
}

String? _storedStringPreference(SharedPreferences prefs, String key) {
  final value = _preferenceValue(prefs, key);
  if (value is! String) return null;
  return cleanNonEmptyText(value);
}

String? _jsonPreference(SharedPreferences prefs, String key) {
  final value = _preferenceValue(prefs, key);
  if (value is String) return cleanNonEmptyText(value);
  if (value is Map || value is List) {
    try {
      return jsonEncode(value);
    } catch (_) {
      return null;
    }
  }
  return null;
}

Map<String, dynamic>? _jsonObjectPreference(
  SharedPreferences prefs,
  String key,
) {
  final raw = _jsonPreference(prefs, key);
  return raw == null ? null : decodeJsonObject(raw);
}
