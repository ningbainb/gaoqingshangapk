import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/app_routes.dart';
import '../core/models.dart';
import 'glass_widgets.dart';

export 'history_record_card_widgets.dart';

class HistoryEmptyActions extends StatelessWidget {
  const HistoryEmptyActions({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const EmptyState(
          icon: Icons.history,
          title: '暂无历史',
          subtitle: '生成成功后会保存文字结果，不保存原始截图。你可以从截图或文本开始。'),
      const SizedBox(height: 14),
      const SectionHeader('开始第一条', Icons.auto_awesome),
      GlassActionRow(
          title: '选择截图',
          subtitle: '让视觉模型看图生成回复',
          icon: Icons.photo_library_outlined,
          color: Colors.lightBlueAccent,
          onTap: () => context.push(AppRoutes.image)),
      GlassActionRow(
          title: '粘贴文本',
          subtitle: '直接用聊天文字生成回复',
          icon: Icons.textsms_outlined,
          color: Colors.tealAccent,
          onTap: () => context.push(AppRoutes.text)),
    ]);
  }
}

class HistoryControlsCard extends StatelessWidget {
  const HistoryControlsCard({
    super.key,
    required this.totalCount,
    required this.imageCount,
    required this.copiedCount,
    required this.search,
    required this.filterMode,
    required this.onSearchChanged,
    required this.onClearSearch,
    required this.onFilterChanged,
    required this.onClearHistory,
  });

  final int totalCount;
  final int imageCount;
  final int copiedCount;
  final TextEditingController search;
  final HistoryFilterMode filterMode;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onClearSearch;
  final ValueChanged<HistoryFilterMode> onFilterChanged;
  final VoidCallback onClearHistory;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      tint: Colors.orangeAccent.withValues(alpha: 0.08),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
              child: Wrap(spacing: 8, runSpacing: 8, children: [
                GlassPill('总数 $totalCount'),
                GlassPill('截图 $imageCount'),
                GlassPill('已复制 $copiedCount'),
              ]),
            ),
            IconButton(
              tooltip: '清空历史',
              onPressed: onClearHistory,
              icon: const Icon(Icons.delete_sweep_outlined),
            ),
          ]),
          const SizedBox(height: 12),
          TextField(
            controller: search,
            onChanged: onSearchChanged,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              suffixIcon: search.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: '清空搜索',
                      onPressed: onClearSearch,
                      icon: const Icon(Icons.cancel_outlined),
                    ),
              labelText: '搜索历史',
              hintText: '场景、最新消息、回复内容',
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.10),
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: HistoryFilterMode.values.map((mode) {
              return FilterChip(
                label: Text(mode.label),
                selected: filterMode == mode,
                onSelected: (_) => onFilterChanged(mode),
              );
            }).toList(),
          ),
        ]),
      ),
    );
  }
}
