import 'package:flutter/material.dart';

import '../core/models.dart';
import 'glass_foundation_widgets.dart';

class StylePicker extends StatelessWidget {
  const StylePicker(
      {super.key,
      required this.selected,
      required this.styles,
      required this.onChanged});
  final ChatStyle selected;
  final List<ChatStyle> styles;
  final ValueChanged<ChatStyle> onChanged;
  @override
  Widget build(BuildContext context) => SizedBox(
        height: 108,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemBuilder: (context, index) {
            final style = styles[index];
            final active = chatStyleIdsMatch(style.id, selected.id);
            return GestureDetector(
              onTap: () => onChanged(style),
              child: SizedBox(
                width: 156,
                child: GlassCard(
                  tint: active ? Colors.cyan.withValues(alpha: 0.24) : null,
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(style.name,
                              style: const TextStyle(
                                  fontSize: 17, fontWeight: FontWeight.w800)),
                          const SizedBox(height: 6),
                          Text(style.description,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  color: Colors.white70, fontSize: 12)),
                          if (!style.isOfficial) ...[
                            const SizedBox(height: 6),
                            const Row(children: [
                              Icon(Icons.person_pin_circle_outlined, size: 14),
                              SizedBox(width: 4),
                              Text('自定义',
                                  style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700)),
                            ]),
                          ],
                        ]),
                  ),
                ),
              ),
            );
          },
          separatorBuilder: (_, __) => const SizedBox(width: 10),
          itemCount: styles.length,
        ),
      );
}

class ReplyCard extends StatelessWidget {
  const ReplyCard({
    super.key,
    required this.reply,
    required this.onCopy,
    this.isCopied = false,
    this.copyLabel = '复制',
    this.copiedLabel = '已复制',
  });
  final ReplySuggestion reply;
  final VoidCallback onCopy;
  final bool isCopied;
  final String copyLabel;
  final String copiedLabel;
  @override
  Widget build(BuildContext context) => GlassCard(
        margin: const EdgeInsets.only(bottom: 12),
        tint: isCopied ? Colors.greenAccent.withValues(alpha: 0.10) : null,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(reply.styleLabel,
                style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: isCopied ? Colors.greenAccent : Colors.cyanAccent)),
            const SizedBox(height: 8),
            Text(reply.text,
                style: const TextStyle(fontSize: 18, height: 1.35)),
            if (reply.reason.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(reply.reason, style: const TextStyle(color: Colors.white70))
            ],
            const SizedBox(height: 10),
            Align(
                alignment: Alignment.centerRight,
                child: FilledButton.icon(
                    onPressed: onCopy,
                    icon: Icon(isCopied ? Icons.check : Icons.copy),
                    label: Text(isCopied ? copiedLabel : copyLabel))),
          ]),
        ),
      );
}
