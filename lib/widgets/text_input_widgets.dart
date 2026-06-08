import 'package:flutter/material.dart';

import '../core/models.dart';
import 'glass_widgets.dart';

class TextInputToolsCard extends StatelessWidget {
  const TextInputToolsCard({
    super.key,
    required this.stats,
    required this.hasText,
    required this.didPaste,
    required this.onPaste,
    required this.onClear,
  });

  final ChatTextStats stats;
  final bool hasText;
  final bool didPaste;
  final VoidCallback onPaste;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      tint: Colors.white.withValues(alpha: 0.08),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(children: [
          Expanded(
              child: GlassPill('${stats.characters} 字 · ${stats.lines} 行')),
          TextButton.icon(
            onPressed: onPaste,
            icon: Icon(didPaste ? Icons.check : Icons.content_paste),
            label: Text(didPaste ? '已粘贴' : '粘贴'),
          ),
          IconButton(
            tooltip: '清空文本',
            onPressed: hasText ? onClear : null,
            icon: const Icon(Icons.delete_outline),
          ),
        ]),
      ),
    );
  }
}

class GoalSuggestionsCard extends StatelessWidget {
  const GoalSuggestionsCard({
    super.key,
    required this.selectedGoal,
    required this.onSelected,
  });

  final String selectedGoal;
  final ValueChanged<String> onSelected;

  static const _suggestions = [
    ('自然接话', '自然接住对方的话，语气像日常聊天。'),
    ('结束话题', '礼貌自然地收尾，不显得冷淡。'),
    ('约时间', '推进到明确时间安排，但不要太强势。'),
    ('缓和气氛', '先接住情绪，再用轻松一点的方式回复。'),
  ];

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      tint: Colors.lightBlueAccent.withValues(alpha: 0.07),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('常用目标',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _suggestions.map((item) {
              final active = selectedGoal == item.$2;
              return FilterChip(
                avatar: Icon(active ? Icons.check_circle : Icons.add_circle,
                    size: 16),
                label: Text(item.$1),
                selected: active,
                onSelected: (_) => onSelected(item.$2),
              );
            }).toList(),
          ),
        ]),
      ),
    );
  }
}
