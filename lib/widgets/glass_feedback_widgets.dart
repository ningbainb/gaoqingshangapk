import 'package:flutter/material.dart';

import 'glass_foundation_widgets.dart';

Future<bool> showConfirmationDialog(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  String cancelLabel = '取消',
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: Text(cancelLabel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return confirmed == true;
}

class InfoLine extends StatelessWidget {
  const InfoLine(this.label, this.value, {super.key});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(
              width: 72,
              child: Text(label,
                  style: const TextStyle(
                      color: Colors.white70, fontWeight: FontWeight.w700))),
          Expanded(child: Text(value)),
        ]),
      );
}

class EmptyState extends StatelessWidget {
  const EmptyState(
      {super.key,
      required this.icon,
      required this.title,
      required this.subtitle});
  final IconData icon;
  final String title;
  final String subtitle;
  @override
  Widget build(BuildContext context) => GlassCard(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(children: [
            Icon(icon, size: 48),
            const SizedBox(height: 12),
            Text(title,
                style:
                    const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text(subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70))
          ]),
        ),
      );
}

class ErrorBanner extends StatelessWidget {
  const ErrorBanner(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: GlassCard(
            tint: Colors.redAccent.withValues(alpha: 0.16),
            child: Material(
              type: MaterialType.transparency,
              child: ListTile(
                  leading: const Icon(Icons.error_outline), title: Text(text)),
            )),
      );
}

class SuccessBanner extends StatelessWidget {
  const SuccessBanner(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: GlassCard(
            tint: Colors.greenAccent.withValues(alpha: 0.16),
            child: Material(
              type: MaterialType.transparency,
              child: ListTile(
                  leading: const Icon(Icons.check_circle_outline),
                  title: Text(text)),
            )),
      );
}
