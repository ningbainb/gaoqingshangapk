import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/app_routes.dart';
import '../core/models.dart';
import 'glass_foundation_widgets.dart';

export 'model_select_widgets.dart';

class ParameterSlider extends StatelessWidget {
  const ParameterSlider({
    super.key,
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    this.divisions,
    this.suffix = '',
    this.fractionDigits = 0,
    this.enabled = true,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final ValueChanged<double>? onChanged;
  final int? divisions;
  final String suffix;
  final int fractionDigits;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final text = fractionDigits == 0
        ? value.round().toString()
        : value.toStringAsFixed(fractionDigits);
    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: GlassCard(
        margin: const EdgeInsets.only(bottom: 10),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('$label：$text$suffix',
                style: const TextStyle(fontWeight: FontWeight.w700)),
            Slider(
                value: value.clamp(min, max),
                min: min,
                max: max,
                divisions: divisions,
                onChanged: enabled ? onChanged : null),
          ]),
        ),
      ),
    );
  }
}

class APIStatusCard extends StatelessWidget {
  const APIStatusCard({super.key, required this.config, required this.hasKey});
  final APIConfig config;
  final bool hasKey;

  @override
  Widget build(BuildContext context) {
    final snapshot = APIStatusSnapshot(config: config, hasAPIKey: hasKey);
    return GlassCard(
      tint: snapshot.isReady
          ? Colors.greenAccent.withValues(alpha: 0.10)
          : Colors.orangeAccent.withValues(alpha: 0.10),
      child: Material(
        type: MaterialType.transparency,
        child: ListTile(
          leading: Icon(
            snapshot.isReady ? Icons.check_circle_outline : Icons.info_outline,
          ),
          title: Text(snapshot.title),
          subtitle: Text(
            snapshot.subtitle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }
}

class APIReadinessCard extends StatelessWidget {
  const APIReadinessCard({super.key, required this.readiness});

  final GenerateAPIReadiness readiness;

  @override
  Widget build(BuildContext context) {
    final color = readiness.isReady ? Colors.greenAccent : Colors.orangeAccent;
    return GlassCard(
      tint: color.withValues(alpha: 0.12),
      child: Material(
        type: MaterialType.transparency,
        child: ListTile(
          leading: Icon(
            readiness.isReady ? Icons.check_circle_outline : Icons.info_outline,
            color: color,
          ),
          title: Text(readiness.title,
              style: const TextStyle(fontWeight: FontWeight.w800)),
          subtitle: Text(readiness.statusText,
              maxLines: 3, overflow: TextOverflow.ellipsis),
          trailing: readiness.isReady
              ? null
              : IconButton(
                  tooltip: '打开 API 设置',
                  onPressed: () => context.push(AppRoutes.api),
                  icon: const Icon(Icons.settings_outlined),
                ),
        ),
      ),
    );
  }
}
