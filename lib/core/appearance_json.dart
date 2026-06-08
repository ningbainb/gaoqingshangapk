part of 'models.dart';

const _appearanceBlurEnabledKeys = [
  'isBackgroundBlurEnabled',
  'backgroundBlurEnabled',
  'blurEnabled',
  'enableBackgroundBlur',
  'enableBlur',
  'useBackgroundBlur',
];

const _appearanceBlurRadiusKeys = [
  'backgroundBlurRadius',
  'blurRadius',
  'backgroundBlur',
  'blur',
];

const _appearanceDimOpacityKeys = [
  'backgroundDimOpacity',
  'dimOpacity',
  'overlayOpacity',
  'backgroundOverlayOpacity',
  'backgroundDim',
];

const _appearanceGlassTintKeys = [
  'glassTintStrength',
  'glassTint',
  'tintStrength',
  'glassOpacity',
];

const _appearanceGlassBorderKeys = [
  'glassBorderStrength',
  'glassBorder',
  'borderStrength',
  'borderOpacity',
];

const _appearanceAccentColorKeys = [
  'accentColorName',
  'accentColor',
  'accent',
  'themeColor',
  'themeColorName',
  'colorName',
];

const _appearanceTextSizeKeys = [
  'textSizeName',
  'textSize',
  'fontSizeName',
  'fontSize',
  'textScaleName',
  'displaySize',
];

const _appearanceCustomBackgroundKeys = [
  'customBackgroundPath',
  'customBackground',
  'backgroundPath',
  'backgroundImagePath',
  'backgroundImage',
  'wallpaperPath',
];

const _appearanceContainerKeys = [
  'appearanceSettings',
  'appearance',
  'themeSettings',
  'theme',
  'uiSettings',
  'ui',
  'displaySettings',
  'display',
  'visualSettings',
  'visual',
  'settings',
];

AppearanceSettings _appearanceSettingsFromJson(Map<String, dynamic> json) {
  final sources = _appearanceSources(json);
  return AppearanceSettings(
    isBackgroundBlurEnabled: _boolValue(
            _firstValueFromSources(sources, _appearanceBlurEnabledKeys)) ??
        AppearanceSettings.defaults.isBackgroundBlurEnabled,
    backgroundBlurRadius: _boundedDouble(
      _firstValueFromSources(sources, _appearanceBlurRadiusKeys),
      fallback: AppearanceSettings.defaults.backgroundBlurRadius,
      min: AppearanceSettings.backgroundBlurRadiusMin,
      max: AppearanceSettings.backgroundBlurRadiusMax,
    ),
    backgroundDimOpacity: _boundedDouble(
      _firstValueFromSources(sources, _appearanceDimOpacityKeys),
      fallback: AppearanceSettings.defaults.backgroundDimOpacity,
      min: AppearanceSettings.backgroundDimOpacityMin,
      max: AppearanceSettings.backgroundDimOpacityMax,
    ),
    glassTintStrength: _boundedDouble(
      _firstValueFromSources(sources, _appearanceGlassTintKeys),
      fallback: AppearanceSettings.defaults.glassTintStrength,
      min: AppearanceSettings.glassTintStrengthMin,
      max: AppearanceSettings.glassTintStrengthMax,
    ),
    glassBorderStrength: _boundedDouble(
      _firstValueFromSources(sources, _appearanceGlassBorderKeys),
      fallback: AppearanceSettings.defaults.glassBorderStrength,
      min: AppearanceSettings.glassBorderStrengthMin,
      max: AppearanceSettings.glassBorderStrengthMax,
    ),
    accentColorName:
        _firstCleanFromSources(sources, _appearanceAccentColorKeys) ??
            AppearanceSettings.defaults.accentColorName,
    textSizeName: _firstCleanFromSources(sources, _appearanceTextSizeKeys) ??
        AppearanceSettings.defaults.textSizeName,
    customBackgroundPath:
        _firstCleanFromSources(sources, _appearanceCustomBackgroundKeys),
  );
}

List<Map<String, dynamic>> _appearanceSources(Map<String, dynamic> json) =>
    _containerSources(json, _appearanceContainerKeys);

Map<String, dynamic> _appearanceSettingsToJson(AppearanceSettings settings) => {
      'isBackgroundBlurEnabled': settings.isBackgroundBlurEnabled,
      'backgroundBlurRadius': _boundedDouble(
        settings.backgroundBlurRadius,
        fallback: AppearanceSettings.defaults.backgroundBlurRadius,
        min: AppearanceSettings.backgroundBlurRadiusMin,
        max: AppearanceSettings.backgroundBlurRadiusMax,
      ),
      'backgroundDimOpacity': _boundedDouble(
        settings.backgroundDimOpacity,
        fallback: AppearanceSettings.defaults.backgroundDimOpacity,
        min: AppearanceSettings.backgroundDimOpacityMin,
        max: AppearanceSettings.backgroundDimOpacityMax,
      ),
      'glassTintStrength': _boundedDouble(
        settings.glassTintStrength,
        fallback: AppearanceSettings.defaults.glassTintStrength,
        min: AppearanceSettings.glassTintStrengthMin,
        max: AppearanceSettings.glassTintStrengthMax,
      ),
      'glassBorderStrength': _boundedDouble(
        settings.glassBorderStrength,
        fallback: AppearanceSettings.defaults.glassBorderStrength,
        min: AppearanceSettings.glassBorderStrengthMin,
        max: AppearanceSettings.glassBorderStrengthMax,
      ),
      'accentColorName': cleanPresentationText(settings.accentColorName) ??
          AppearanceSettings.defaults.accentColorName,
      'textSizeName': cleanPresentationText(settings.textSizeName) ??
          AppearanceSettings.defaults.textSizeName,
      'customBackgroundPath':
          cleanPresentationText(settings.customBackgroundPath),
    };

AppearanceSettings _appearanceSettingsNormalized(AppearanceSettings settings) {
  final normalized = AppearanceSettings.fromJson(settings.toJson());
  if (settings.isBackgroundBlurEnabled == normalized.isBackgroundBlurEnabled &&
      settings.backgroundBlurRadius == normalized.backgroundBlurRadius &&
      settings.backgroundDimOpacity == normalized.backgroundDimOpacity &&
      settings.glassTintStrength == normalized.glassTintStrength &&
      settings.glassBorderStrength == normalized.glassBorderStrength &&
      settings.accentColorName == normalized.accentColorName &&
      settings.textSizeName == normalized.textSizeName &&
      settings.customBackgroundPath == normalized.customBackgroundPath) {
    return settings;
  }
  return normalized;
}
