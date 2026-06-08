import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../core/app_feedback.dart';
import '../core/models.dart';
import '../core/presentation_helpers.dart';
import 'glass_widgets.dart';

export 'settings_overview_cards.dart';

class AppearanceSettingsCard extends StatelessWidget {
  const AppearanceSettingsCard({
    super.key,
    required this.settings,
    this.statusMessage,
    this.errorMessage,
    required this.onChanged,
    required this.onImport,
    required this.onResetCustomBackground,
    required this.onResetPreferences,
  });

  final AppearanceSettings settings;
  final String? statusMessage;
  final String? errorMessage;
  final Future<void> Function(AppearanceSettings settings) onChanged;
  final Future<void> Function(String path) onImport;
  final Future<void> Function() onResetCustomBackground;
  final Future<void> Function() onResetPreferences;

  @override
  Widget build(BuildContext context) {
    final visibleStatusMessage = cleanFeedbackMessage(statusMessage);
    final visibleErrorMessage = cleanFeedbackMessage(errorMessage);
    return GlassCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('外观',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text(
            settings.backgroundSummary,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
          const SizedBox(height: 10),
          Material(
            type: MaterialType.transparency,
            child: SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: settings.isBackgroundBlurEnabled,
              title: const Text('背景模糊'),
              subtitle: const Text('关闭会更流畅，低端机推荐关闭。'),
              onChanged: (v) =>
                  onChanged(settings.withBackgroundBlurEnabled(v)),
            ),
          ),
          ParameterSlider(
            label: '背景模糊强度',
            value: settings.backgroundBlurRadius,
            min: AppearanceSettings.backgroundBlurRadiusMin,
            max: AppearanceSettings.backgroundBlurRadiusMax,
            divisions: AppearanceSettings.backgroundBlurRadiusMax.round(),
            enabled: settings.isBackgroundBlurEnabled,
            onChanged: settings.isBackgroundBlurEnabled
                ? (v) => onChanged(settings.copyWith(backgroundBlurRadius: v))
                : null,
          ),
          ParameterSlider(
            label: '背景压暗',
            value: settings.backgroundDimOpacity,
            min: AppearanceSettings.backgroundDimOpacityMin,
            max: AppearanceSettings.backgroundDimOpacityMax,
            divisions: 42,
            fractionDigits: 2,
            onChanged: (v) =>
                onChanged(settings.copyWith(backgroundDimOpacity: v)),
          ),
          ParameterSlider(
            label: '玻璃底色',
            value: settings.glassTintStrength,
            min: AppearanceSettings.glassTintStrengthMin,
            max: AppearanceSettings.glassTintStrengthMax,
            divisions: 26,
            fractionDigits: 2,
            onChanged: (v) =>
                onChanged(settings.copyWith(glassTintStrength: v)),
          ),
          ParameterSlider(
            label: '玻璃描边',
            value: settings.glassBorderStrength,
            min: AppearanceSettings.glassBorderStrengthMin,
            max: AppearanceSettings.glassBorderStrengthMax,
            divisions: 20,
            fractionDigits: 2,
            onChanged: (v) =>
                onChanged(settings.copyWith(glassBorderStrength: v)),
          ),
          const SizedBox(height: 6),
          const Text('强调色', style: TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final option in const [
                ('ocean', '海蓝'),
                ('mint', '薄荷'),
                ('sunset', '日落'),
                ('rose', '玫瑰'),
                ('violet', '紫罗兰')
              ])
                ChoiceChip(
                  selected: settings.accentColorName == option.$1,
                  label: Text(option.$2),
                  avatar: CircleAvatar(
                      backgroundColor: settings
                          .copyWith(accentColorName: option.$1)
                          .accentColor),
                  onSelected: (_) =>
                      onChanged(settings.copyWith(accentColorName: option.$1)),
                ),
            ],
          ),
          const SizedBox(height: 14),
          const Text('字号', style: TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final option in const [
                ('compact', '紧凑'),
                ('standard', '标准'),
                ('comfortable', '舒适'),
                ('large', '大字')
              ])
                ChoiceChip(
                  selected: settings.textSizeName == option.$1,
                  label: Text(option.$2),
                  onSelected: (_) =>
                      onChanged(settings.copyWith(textSizeName: option.$1)),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(spacing: 8, runSpacing: 8, children: [
            FilledButton.icon(
              onPressed: () async {
                final picked =
                    await ImagePicker().pickImage(source: ImageSource.gallery);
                if (!context.mounted) return;
                if (picked != null) await onImport(picked.path);
              },
              icon: const Icon(Icons.image_outlined),
              label: const Text('导入背景'),
            ),
            OutlinedButton.icon(
                onPressed: !settings.hasCustomBackground
                    ? null
                    : onResetCustomBackground,
                icon: const Icon(Icons.restore),
                label: const Text('默认背景')),
          ]),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onResetPreferences,
              icon: const Icon(Icons.auto_fix_high_outlined),
              label: const Text('重置个性化'),
            ),
          ),
          if (visibleStatusMessage != null) ...[
            const SizedBox(height: 10),
            SuccessBanner(visibleStatusMessage),
          ],
          if (visibleErrorMessage != null) ...[
            const SizedBox(height: 10),
            ErrorBanner(visibleErrorMessage),
          ],
        ]),
      ),
    );
  }
}
