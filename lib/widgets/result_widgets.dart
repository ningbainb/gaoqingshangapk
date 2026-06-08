import 'package:flutter/material.dart';

import 'glass_widgets.dart';

class ResultCopySuccessCard extends StatelessWidget {
  const ResultCopySuccessCard(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      tint: Colors.greenAccent.withValues(alpha: 0.08),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const GlassIcon(
            Icons.check_circle_outline,
            color: Colors.greenAccent,
            size: 34,
          ),
          const SizedBox(width: 12),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('已复制，可以回聊天 App 粘贴',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text(
                text,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}
