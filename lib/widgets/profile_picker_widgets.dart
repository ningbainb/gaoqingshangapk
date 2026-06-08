import 'package:flutter/material.dart';

import '../core/models.dart';
import '../core/presentation_helpers.dart';
import 'glass_widgets.dart';

class PersonProfilePickerCard extends StatelessWidget {
  const PersonProfilePickerCard({
    super.key,
    required this.title,
    required this.profiles,
    required this.selectedProfileId,
    required this.onChanged,
    required this.emptyText,
    required this.autoSummary,
    required this.selectedSummary,
  });

  final String title;
  final List<PersonProfile> profiles;
  final String? selectedProfileId;
  final ValueChanged<String?> onChanged;
  final String emptyText;
  final String autoSummary;
  final String Function(PersonProfile profile) selectedSummary;

  @override
  Widget build(BuildContext context) {
    final selectedProfile = personProfileById(profiles, selectedProfileId);
    final normalizedSelectedProfileId = selectedProfile?.id;
    final summary = selectedProfile == null
        ? (profiles.isEmpty ? emptyText : autoSummary)
        : selectedSummary(selectedProfile);
    final previewTags = selectedProfile == null
        ? const <String>[]
        : selectedProfile.pickerPreviewTagValues.take(4).toList();

    return GlassCard(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.person_pin_circle_outlined, size: 18),
            const SizedBox(width: 8),
            Expanded(
                child: Text(title,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w800))),
          ]),
          const SizedBox(height: 10),
          SizedBox(
            height: 112,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: profiles.length + 1,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                if (index == 0) {
                  return _ProfileChoiceTile(
                    width: 154,
                    title: '自动判断',
                    subtitle: profiles.isEmpty ? '等待画像沉淀' : '带入最近画像',
                    detail:
                        profiles.isEmpty ? '暂无人物库' : '${profiles.length} 个画像',
                    icon: Icons.auto_awesome,
                    selected: normalizedSelectedProfileId == null,
                    onTap: () => onChanged(null),
                  );
                }
                final profile = profiles[index - 1];
                return _ProfileChoiceTile(
                  width: 186,
                  title: profile.displayLabel,
                  subtitle: profile.pickerSubtitleLabel,
                  detail: '完整度 ${profile.coveragePercent}%',
                  icon: Icons.person_outline,
                  selected: personProfileIdsMatch(
                      profile.id, normalizedSelectedProfileId),
                  onTap: () => onChanged(profile.id),
                );
              },
            ),
          ),
          const SizedBox(height: 10),
          Text(summary,
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.74), fontSize: 12)),
          if (previewTags.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: previewTags
                  .map((tag) => GlassPill(truncatedPresentationText(
                        tag,
                        maxCharacters: 16,
                      )))
                  .toList(),
            ),
          ],
        ]),
      ),
    );
  }
}

class _ProfileChoiceTile extends StatelessWidget {
  const _ProfileChoiceTile({
    required this.width,
    required this.title,
    required this.subtitle,
    required this.detail,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final double width;
  final String title;
  final String subtitle;
  final String detail;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        width: width,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected
              ? Colors.cyanAccent.withValues(alpha: 0.18)
              : Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: selected ? Colors.cyanAccent : Colors.white30,
              width: selected ? 1.4 : 1),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(icon, size: 17, color: selected ? Colors.cyanAccent : null),
            const SizedBox(width: 6),
            Expanded(
              child: Text(title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w800)),
            ),
          ]),
          const SizedBox(height: 8),
          Text(subtitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.72), fontSize: 12)),
          const Spacer(),
          Text(detail,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.58), fontSize: 11)),
        ]),
      ),
    );
  }
}
