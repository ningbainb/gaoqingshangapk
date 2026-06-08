import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/app_provider.dart';

class GlassCard extends ConsumerWidget {
  const GlassCard(
      {super.key,
      required this.child,
      this.radius = 20,
      this.tint,
      this.margin});

  final Widget child;
  final double radius;
  final Color? tint;
  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appearance = ref.watch(appProvider.select((app) => app.appearance));
    return Container(
      margin: margin,
      decoration: BoxDecoration(
        color: tint ??
            Colors.white.withValues(
                alpha: (0.13 * appearance.glassTintStrength).clamp(0.05, 0.22)),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
            color: Colors.white.withValues(
                alpha:
                    (0.38 * appearance.glassBorderStrength).clamp(0.16, 0.72))),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.16),
              blurRadius: 24,
              offset: const Offset(0, 12))
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: child,
      ),
    );
  }
}

class GlassActionRow extends StatelessWidget {
  const GlassActionRow(
      {super.key,
      required this.title,
      required this.subtitle,
      required this.icon,
      required this.color,
      required this.onTap});

  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        type: MaterialType.transparency,
        child: ListTile(
          onTap: onTap,
          leading: GlassIcon(icon, color: color),
          title:
              Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
          subtitle:
              Text(subtitle, style: const TextStyle(color: Colors.white70)),
          trailing: const Icon(Icons.chevron_right),
        ),
      ),
    );
  }
}

class GlassIcon extends StatelessWidget {
  const GlassIcon(this.icon, {super.key, required this.color, this.size = 40});

  final IconData icon;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(colors: [
          color.withValues(alpha: 0.72),
          Colors.white.withValues(alpha: 0.20)
        ]),
        border: Border.all(color: Colors.white.withValues(alpha: 0.55)),
      ),
      child: Icon(icon, size: size * 0.48, color: Colors.white),
    );
  }
}

class GlassPill extends StatelessWidget {
  const GlassPill(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(99),
            border: Border.all(color: Colors.white30)),
        child: Text(text,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
      );
}

class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, this.icon, {super.key});
  final String title;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(12, 2, 12, 10),
        child: Row(children: [
          Icon(icon, size: 16),
          const SizedBox(width: 7),
          Text(title, style: const TextStyle(fontWeight: FontWeight.w800))
        ]),
      );
}

class GlassTextField extends StatelessWidget {
  const GlassTextField(
      {super.key,
      required this.controller,
      required this.label,
      required this.hint,
      this.minLines = 1,
      this.maxLines = 1,
      this.obscure = false,
      this.onChanged});
  final TextEditingController controller;
  final String label;
  final String hint;
  final int minLines;
  final int maxLines;
  final bool obscure;
  final ValueChanged<String>? onChanged;
  @override
  Widget build(BuildContext context) => TextField(
        controller: controller,
        onChanged: onChanged,
        minLines: obscure ? 1 : minLines,
        maxLines: obscure ? 1 : maxLines,
        obscureText: obscure,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          filled: true,
          fillColor: Colors.white.withValues(alpha: 0.12),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide:
                  BorderSide(color: Colors.white.withValues(alpha: 0.35))),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide:
                  BorderSide(color: Colors.white.withValues(alpha: 0.25))),
        ),
      );
}
