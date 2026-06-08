import 'package:flutter/material.dart';

import 'glass_widgets.dart';

class ProfileQuickFillCard extends StatelessWidget {
  const ProfileQuickFillCard({
    super.key,
    required this.onStableReply,
    required this.onLightHumor,
    required this.onAvoidPressure,
    required this.onPlanning,
  });

  final VoidCallback onStableReply;
  final VoidCallback onLightHumor;
  final VoidCallback onAvoidPressure;
  final VoidCallback onPlanning;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      tint: Colors.indigoAccent.withValues(alpha: 0.07),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Row(children: [
            Icon(Icons.auto_fix_high, color: Colors.indigoAccent),
            SizedBox(width: 8),
            Text('快速补充',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          ]),
          const SizedBox(height: 6),
          const Text('把常用画像线索追加到对应字段，之后还能继续手改。',
              style: TextStyle(color: Colors.white70)),
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, children: [
            _QuickFillChip(
              label: '稳定回应',
              icon: Icons.check_circle_outline,
              color: Colors.greenAccent,
              onPressed: onStableReply,
            ),
            _QuickFillChip(
              label: '轻松幽默',
              icon: Icons.sentiment_satisfied_alt,
              color: Colors.orangeAccent,
              onPressed: onLightHumor,
            ),
            _QuickFillChip(
              label: '别催促',
              icon: Icons.front_hand_outlined,
              color: Colors.redAccent,
              onPressed: onAvoidPressure,
            ),
            _QuickFillChip(
              label: '重视计划',
              icon: Icons.event_available_outlined,
              color: Colors.lightBlueAccent,
              onPressed: onPlanning,
            ),
          ]),
        ]),
      ),
    );
  }
}

class _QuickFillChip extends StatelessWidget {
  const _QuickFillChip({
    required this.label,
    required this.icon,
    required this.color,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      avatar: Icon(icon, size: 18, color: color),
      label: Text(label),
      onPressed: onPressed,
    );
  }
}

class ProfileEditorField extends StatelessWidget {
  const ProfileEditorField({
    super.key,
    required this.label,
    required this.controller,
    this.minLines = 3,
  });

  final String label;
  final TextEditingController controller;
  final int minLines;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GlassTextField(
          controller: controller,
          label: label,
          hint: '每行一条',
          minLines: minLines,
          maxLines: 7),
    );
  }
}
