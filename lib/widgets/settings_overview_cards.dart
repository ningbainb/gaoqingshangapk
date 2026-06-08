import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/app_routes.dart';
import '../core/models.dart';
import 'glass_widgets.dart';

class SettingsOverviewCard extends StatelessWidget {
  const SettingsOverviewCard({super.key, required this.snapshot});

  final SettingsSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final color =
        snapshot.isOverviewReady ? Colors.greenAccent : Colors.orangeAccent;
    final icon = snapshot.isOverviewReady
        ? Icons.verified_outlined
        : Icons.key_off_outlined;
    return GlassCard(
      tint: color.withValues(alpha: 0.10),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            GlassIcon(icon, color: color),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(snapshot.statusTitle,
                        style: const TextStyle(
                            fontSize: 20, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 4),
                    Text(snapshot.statusSubtitle,
                        style: const TextStyle(color: Colors.white70)),
                  ]),
            ),
          ]),
          const SizedBox(height: 14),
          InfoLine('截图', snapshot.visionLine),
          InfoLine('文本', snapshot.textLine),
          InfoLine('风格', snapshot.defaultStyleLine),
          InfoLine('个性化', snapshot.personalizationLine),
        ]),
      ),
    );
  }
}

class SettingsNextActionCard extends StatelessWidget {
  const SettingsNextActionCard({super.key, required this.snapshot});

  final SettingsSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final ready = snapshot.isShortcutReady;
    final color = ready ? Colors.lightBlueAccent : Colors.orangeAccent;
    return GlassCard(
      tint: color.withValues(alpha: 0.08),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          GlassIcon(
            ready ? Icons.bolt_outlined : Icons.auto_fix_high,
            color: color,
            size: 38,
          ),
          const SizedBox(width: 12),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(snapshot.nextActionTitle,
                  style: const TextStyle(
                      fontSize: 17, fontWeight: FontWeight.w800)),
              const SizedBox(height: 5),
              Text(snapshot.nextActionDescription,
                  style: const TextStyle(color: Colors.white70)),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () => context
                    .push(ready ? AppRoutes.floatingGuide : AppRoutes.api),
                icon: Icon(ready ? Icons.control_camera : Icons.settings),
                label: Text(ready ? '打开悬浮窗说明' : '去完善 API'),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}

class SettingsMetricCard extends StatelessWidget {
  const SettingsMetricCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String title;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      tint: color.withValues(alpha: 0.08),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          GlassIcon(icon, color: color, size: 34),
          const SizedBox(height: 10),
          Text(value,
              style:
                  const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
          Text(title, style: const TextStyle(color: Colors.white70)),
        ]),
      ),
    );
  }
}
