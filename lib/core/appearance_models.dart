part of 'models.dart';

class AppearanceSettings {
  const AppearanceSettings({
    this.isBackgroundBlurEnabled = true,
    this.backgroundBlurRadius = 14,
    this.backgroundDimOpacity = 0.20,
    this.glassTintStrength = 1,
    this.glassBorderStrength = 1,
    this.accentColorName = 'ocean',
    this.textSizeName = 'standard',
    this.customBackgroundPath,
  });

  final bool isBackgroundBlurEnabled;
  final double backgroundBlurRadius;
  final double backgroundDimOpacity;
  final double glassTintStrength;
  final double glassBorderStrength;
  final String accentColorName;
  final String textSizeName;
  final String? customBackgroundPath;

  static const defaults = AppearanceSettings();
  static const backgroundBlurRadiusMin = 0.0;
  static const backgroundBlurRadiusMax = 28.0;
  static const backgroundDimOpacityMin = 0.0;
  static const backgroundDimOpacityMax = 0.42;
  static const glassTintStrengthMin = 0.35;
  static const glassTintStrengthMax = 1.65;
  static const glassBorderStrengthMin = 0.45;
  static const glassBorderStrengthMax = 1.45;

  AppearanceSettings withBackgroundBlurEnabled(bool enabled) =>
      copyWith(isBackgroundBlurEnabled: enabled);

  AppearanceSettings normalized() => _appearanceSettingsNormalized(this);

  AppearanceSettings copyWith({
    bool? isBackgroundBlurEnabled,
    double? backgroundBlurRadius,
    double? backgroundDimOpacity,
    double? glassTintStrength,
    double? glassBorderStrength,
    String? accentColorName,
    String? textSizeName,
    String? customBackgroundPath,
    bool clearCustomBackground = false,
  }) {
    return AppearanceSettings(
      isBackgroundBlurEnabled:
          isBackgroundBlurEnabled ?? this.isBackgroundBlurEnabled,
      backgroundBlurRadius: backgroundBlurRadius ?? this.backgroundBlurRadius,
      backgroundDimOpacity: backgroundDimOpacity ?? this.backgroundDimOpacity,
      glassTintStrength: glassTintStrength ?? this.glassTintStrength,
      glassBorderStrength: glassBorderStrength ?? this.glassBorderStrength,
      accentColorName: accentColorName ?? this.accentColorName,
      textSizeName: textSizeName ?? this.textSizeName,
      customBackgroundPath: clearCustomBackground
          ? null
          : (customBackgroundPath ?? this.customBackgroundPath),
    );
  }

  factory AppearanceSettings.fromJson(Map<String, dynamic> json) =>
      _appearanceSettingsFromJson(json);

  Map<String, dynamic> toJson() => _appearanceSettingsToJson(this);
}
