import 'package:flutter/material.dart';

import '../core/models.dart';
import '../core/presentation_helpers.dart';
import 'glass_widgets.dart';

class PersonInsightResultCard extends StatelessWidget {
  const PersonInsightResultCard({
    super.key,
    required this.insight,
    required this.sceneSummary,
    required this.savedProfile,
    required this.onOpenProfile,
    required this.onEditDraft,
  });

  final PersonInsight insight;
  final String? sceneSummary;
  final PersonProfile? savedProfile;
  final ValueChanged<PersonProfile> onOpenProfile;
  final ValueChanged<PersonProfile> onEditDraft;

  @override
  Widget build(BuildContext context) {
    final activeProfile = savedProfile;
    final tags = insight.resultTags;
    final relationship = insight.displayRelationship;
    final communicationStyle = insight.displayCommunicationStyle;
    final title = insight.resultTitle(activeProfile);
    final footnoteParts = insight.resultFootnoteParts;

    return GlassCard(
      tint: activeProfile == null
          ? Colors.orangeAccent.withValues(alpha: 0.10)
          : Colors.greenAccent.withValues(alpha: 0.10),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            GlassIcon(
              activeProfile == null
                  ? Icons.person_search_outlined
                  : Icons.person_pin_circle_outlined,
              color: activeProfile == null
                  ? Colors.orangeAccent
                  : Colors.greenAccent,
              size: 38,
            ),
            const SizedBox(width: 10),
            const Expanded(
                child: Text('人物库更新',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.w800))),
            GlassPill(activeProfile == null ? '待保存' : '已写入'),
          ]),
          const SizedBox(height: 12),
          Text(title,
              style:
                  const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          if (relationship != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(relationship,
                  style: const TextStyle(color: Colors.white70)),
            ),
          if (communicationStyle != null) ...[
            const SizedBox(height: 8),
            Text(communicationStyle,
                style: const TextStyle(color: Colors.white70, height: 1.35)),
          ],
          if (tags.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: tags.map(GlassPill.new).toList(),
            ),
          ],
          if (footnoteParts.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              footnoteParts.join(' · '),
              style: const TextStyle(color: Colors.white60, fontSize: 12),
            ),
          ],
          const SizedBox(height: 12),
          if (activeProfile != null)
            OutlinedButton.icon(
              onPressed: () => onOpenProfile(activeProfile),
              icon: const Icon(Icons.person_outline),
              label: const Text('查看人物详情'),
            )
          else
            FilledButton.icon(
              onPressed: () => onEditDraft(insight.draftProfile(sceneSummary)),
              icon: const Icon(Icons.edit_outlined),
              label: const Text('命名并保存到人物库'),
            ),
        ]),
      ),
    );
  }
}

class MomentAnalysisCard extends StatelessWidget {
  const MomentAnalysisCard({
    super.key,
    required this.analysis,
    this.savedProfile,
    this.onOpenProfile,
  });

  final MomentProfileAnalysis analysis;
  final PersonProfile? savedProfile;
  final VoidCallback? onOpenProfile;

  @override
  Widget build(BuildContext context) {
    final profileName = analysis.profileDisplayName(savedProfile);
    final infoLines = analysis.displayInfoLines;
    return GlassCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Icon(Icons.check_circle, color: Colors.greenAccent),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('已写入人物库',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 4),
                      Text(profileName,
                          style: const TextStyle(
                              color: Colors.white70,
                              fontWeight: FontWeight.w700)),
                    ]),
              ),
            ]),
            const SizedBox(height: 10),
            ...infoLines.map((line) => InfoLine(line.$1, line.$2)),
            if (onOpenProfile != null) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: onOpenProfile,
                  icon: const Icon(Icons.person_search_outlined),
                  label: const Text('查看人物详情'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
