import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/app_feedback.dart';
import '../core/app_provider.dart';
import '../core/app_routes.dart';
import '../core/app_state.dart';
import '../core/models.dart';
import '../widgets/glass_scaffold.dart';
import '../widgets/glass_widgets.dart';
import '../widgets/settings_cards.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final app = ref.watch(appProvider);
    final snapshot = SettingsSnapshot(
      hasAPIKey: hasUsableAPIKey(app.apiKey),
      config: app.config,
      historyCount: app.history.length,
      profileCount: app.profiles.length,
      personalization: app.personalization,
      defaultStyleName: app.defaultStyle.name,
    );
    return GlassScaffold(
      title: '设置',
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 76, 20, 96),
        children: [
          SettingsOverviewCard(snapshot: snapshot),
          const SizedBox(height: 12),
          SettingsNextActionCard(snapshot: snapshot),
          const SizedBox(height: 18),
          const SectionHeader('设置', Icons.settings_outlined),
          GlassActionRow(
              title: '悬浮窗截图',
              subtitle: '开启悬浮按钮、授权截屏和无障碍增强模式',
              icon: Icons.control_camera,
              color: Colors.cyanAccent,
              onTap: () => context.push(AppRoutes.floatingGuide)),
          GlassActionRow(
              title: 'API 设置',
              subtitle: 'Base URL、Key、模型、图片和生成参数',
              icon: Icons.settings_outlined,
              color: Colors.white70,
              onTap: () => context.push(AppRoutes.api)),
          GlassActionRow(
              title: '个性化回复',
              subtitle: '口语化、我的资料、记忆、自定义风格',
              icon: Icons.tune,
              color: Colors.tealAccent,
              onTap: () => context.push(AppRoutes.personalization)),
          GlassActionRow(
              title: '隐私与数据',
              subtitle: '查看隐私说明并清空本地数据',
              icon: Icons.privacy_tip_outlined,
              color: Colors.orangeAccent,
              onTap: () => context.push(AppRoutes.privacy)),
          const SizedBox(height: 14),
          const SectionHeader('外观', Icons.auto_awesome),
          AppearanceSettingsCard(
              settings: app.appearance,
              statusMessage: isAppearanceStatusMessage(app.statusMessage)
                  ? app.statusMessage
                  : null,
              errorMessage: isAppearanceErrorMessage(app.errorMessage)
                  ? app.errorMessage
                  : null,
              onChanged: app.saveAppearance,
              onImport: app.importCustomBackground,
              onResetCustomBackground: app.resetCustomBackground,
              onResetPreferences: app.resetAppearance),
          const SizedBox(height: 14),
          const SectionHeader('本机数据', Icons.storage_outlined),
          Row(children: [
            Expanded(
                child: SettingsMetricCard(
                    title: '历史',
                    value: snapshot.historyMetricValue,
                    icon: Icons.history,
                    color: Colors.orangeAccent)),
            const SizedBox(width: 10),
            Expanded(
                child: SettingsMetricCard(
                    title: '人物',
                    value: snapshot.profileMetricValue,
                    icon: Icons.people_outline,
                    color: Colors.tealAccent)),
          ]),
        ],
      ),
    );
  }
}
