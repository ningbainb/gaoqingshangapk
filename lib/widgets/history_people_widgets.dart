import 'package:flutter/material.dart';

import '../core/models.dart';
import '../core/presentation_helpers.dart';
import 'glass_widgets.dart';

export 'history_record_widgets.dart';

class PeopleEmptyState extends StatelessWidget {
  const PeopleEmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const EmptyState(
          icon: Icons.badge_outlined,
          title: '人物库还是空的',
          subtitle: '先添加一个人物名称，再逐步补关系、偏好和避雷点；也可以用朋友圈截图让模型帮你整理画像线索。'),
      const SizedBox(height: 14),
      GlassCard(
        tint: Colors.lightBlueAccent.withValues(alpha: 0.08),
        child: const Padding(
          padding: EdgeInsets.all(16),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('建议优先补这三项',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
            SizedBox(height: 10),
            InfoLine('人物名称和关系', '让回复对象更明确'),
            InfoLine('适合怎么回', '沉淀对方偏好的语气和表达'),
            InfoLine('聊天避雷', '避免踩到反感点'),
          ]),
        ),
      ),
    ]);
  }
}

class PeopleControlsCard extends StatelessWidget {
  const PeopleControlsCard({
    super.key,
    required this.totalCount,
    required this.averageCoverage,
    required this.highCoverageCount,
    required this.search,
    required this.sortMode,
    required this.onSearchChanged,
    required this.onClearSearch,
    required this.onSortChanged,
    required this.onClearProfiles,
  });

  final int totalCount;
  final int averageCoverage;
  final int highCoverageCount;
  final TextEditingController search;
  final PersonProfileSortMode sortMode;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onClearSearch;
  final ValueChanged<PersonProfileSortMode> onSortChanged;
  final VoidCallback onClearProfiles;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      tint: Colors.cyanAccent.withValues(alpha: 0.08),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
              child: Wrap(spacing: 8, runSpacing: 8, children: [
                GlassPill('总数 $totalCount'),
                GlassPill('平均完整度 $averageCoverage%'),
                GlassPill('高完整 $highCoverageCount'),
              ]),
            ),
            IconButton(
              tooltip: '清空人物库',
              onPressed: onClearProfiles,
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
              labelText: '搜索人物',
              hintText: '名称、别名、关系、画像线索',
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
            children: PersonProfileSortMode.values.map((mode) {
              return FilterChip(
                label: Text(mode.label),
                selected: sortMode == mode,
                onSelected: (_) => onSortChanged(mode),
              );
            }).toList(),
          ),
        ]),
      ),
    );
  }
}

class PersonProfileListCard extends StatelessWidget {
  const PersonProfileListCard({
    super.key,
    required this.profile,
    required this.onOpen,
    this.onDelete,
  });

  final PersonProfile profile;
  final VoidCallback onOpen;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final firstLetter = profile.displayInitial;
    final displayName = profile.displayLabel;
    final relationship = profile.displayRelationship;
    final summary = profile.listSubtitleLabel;
    final tags = profile.previewTags;
    final visibleTags = tags.take(2).toList();
    final hiddenTagCount = tags.length - visibleTags.length;
    return GlassCard(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            CircleAvatar(
              backgroundColor: Colors.cyanAccent.withValues(alpha: 0.18),
              foregroundColor: Colors.white,
              child: Text(firstLetter,
                  style: const TextStyle(fontWeight: FontWeight.w800)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Expanded(
                        child: Text(
                          displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 17, fontWeight: FontWeight.w800),
                        ),
                      ),
                      if (relationship != null) GlassPill(relationship),
                      const SizedBox(width: 6),
                      GlassPill('${profile.coveragePercent}%'),
                    ]),
                    const SizedBox(height: 6),
                    Text(
                      summary,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white70),
                    ),
                    const SizedBox(height: 8),
                    Row(children: [
                      Expanded(
                        child: Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            if (visibleTags.isEmpty)
                              const GlassPill('等待画像线索')
                            else ...[
                              ...visibleTags.map(GlassPill.new),
                              if (hiddenTagCount > 0)
                                GlassPill('+$hiddenTagCount'),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        chineseRelativeShortDate(profile.updatedAt),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: Colors.white54, fontSize: 12),
                      ),
                    ]),
                  ]),
            ),
            if (onDelete != null)
              IconButton(
                tooltip: '删除人物',
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline),
              ),
          ]),
        ),
      ),
    );
  }
}
