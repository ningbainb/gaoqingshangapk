import 'dart:async';

import 'package:flutter/material.dart';

import '../core/app_state.dart';
import 'glass_widgets.dart';

class FloatingStyleCard extends StatelessWidget {
  const FloatingStyleCard({
    super.key,
    required this.app,
  });

  final AppController app;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Row(children: [
            Icon(Icons.style_outlined, size: 18, color: Colors.cyanAccent),
            SizedBox(width: 8),
            Text('悬浮窗回复风格',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          ]),
          const SizedBox(height: 8),
          Text('当前：${app.defaultStyle.name}',
              style: const TextStyle(color: Colors.white70)),
          const SizedBox(height: 12),
          StylePicker(
            selected: app.defaultStyle,
            styles: app.personalization.availableStyles,
            onChanged: (style) {
              unawaited(app.setDefaultStyle(style));
            },
          ),
        ]),
      ),
    );
  }
}
