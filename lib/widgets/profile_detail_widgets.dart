import 'package:flutter/material.dart';

import '../core/models.dart';
import '../core/presentation_helpers.dart';
import 'glass_widgets.dart';

class ProfileCoverageCard extends StatelessWidget {
  const ProfileCoverageCard({super.key, required this.profile});

  final PersonProfile profile;

  @override
  Widget build(BuildContext context) {
    final sections = profile.coverageSections;
    final filled = sections.where((s) => s.$2).length;
    return GlassCard(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Expanded(
                child: Text('画像完整度',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.w800))),
            Text('$filled/${sections.length}',
                style: const TextStyle(color: Colors.white70)),
          ]),
          const SizedBox(height: 10),
          LinearProgressIndicator(value: filled / sections.length),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: sections
                .map((section) => Chip(
                    avatar: Icon(
                        section.$2
                            ? Icons.check_circle
                            : Icons.add_circle_outline,
                        size: 16),
                    label: Text(section.$1)))
                .toList(),
          ),
          if (profile.missingCoverageSuggestion != null) ...[
            const SizedBox(height: 10),
            Text(profile.missingCoverageSuggestion!,
                style: const TextStyle(color: Colors.white70, fontSize: 12)),
          ],
        ]),
      ),
    );
  }
}

class ProfileDetailSection extends StatelessWidget {
  const ProfileDetailSection(
      {super.key,
      required this.title,
      required this.values,
      required this.icon});

  final String title;
  final List<String> values;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final visibleValues = uniqueCleanPresentationList(values);
    return GlassCard(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(icon, size: 18),
            const SizedBox(width: 8),
            Text(title,
                style:
                    const TextStyle(fontSize: 17, fontWeight: FontWeight.w800))
          ]),
          const SizedBox(height: 10),
          if (visibleValues.isEmpty)
            const Text('暂无记录', style: TextStyle(color: Colors.white70))
          else
            ...visibleValues.map((value) => Padding(
                  padding: const EdgeInsets.only(bottom: 7),
                  child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.check_circle,
                            size: 15, color: Colors.cyanAccent),
                        const SizedBox(width: 8),
                        Expanded(child: Text(value)),
                      ]),
                )),
        ]),
      ),
    );
  }
}
