import 'package:flutter/material.dart';

import '../core/models.dart';
import '../core/presentation_helpers.dart';
import 'glass_widgets.dart';

class SimulationOptionCard extends StatelessWidget {
  const SimulationOptionCard({
    super.key,
    required this.option,
    required this.isSelected,
    required this.onSelected,
    required this.onSubmit,
  });

  final SimulationOption option;
  final bool isSelected;
  final VoidCallback onSelected;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onSelected,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isSelected
                ? Colors.cyan.withValues(alpha: 0.24)
                : Colors.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? Colors.cyanAccent : Colors.white24,
            ),
          ),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text(option.label,
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w900)),
              const Spacer(),
              Text('预估 ${option.predictedScore}',
                  style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      fontWeight: FontWeight.w700)),
            ]),
            const SizedBox(height: 6),
            Text(option.text,
                style: const TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text(option.reason,
                style: const TextStyle(color: Colors.white70, fontSize: 12)),
            const SizedBox(height: 8),
            Row(children: [
              TextButton.icon(
                onPressed: onSelected,
                icon: const Icon(Icons.edit_outlined, size: 16),
                label: const Text('填入草稿'),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: onSubmit,
                icon: const Icon(Icons.send_outlined, size: 16),
                label: const Text('采用并发送'),
              ),
            ]),
          ]),
        ),
      ),
    );
  }
}

class SimulationScore {
  const SimulationScore(this.label, this.score, this.tint,
      {this.lowerIsBetter = false});

  final String label;
  final int score;
  final Color tint;
  final bool lowerIsBetter;
}

class SimulationScoreTile extends StatelessWidget {
  const SimulationScoreTile({
    super.key,
    required this.score,
    required this.isPlaceholder,
  });

  final SimulationScore score;
  final bool isPlaceholder;

  @override
  Widget build(BuildContext context) {
    final effectiveScore = isPlaceholder ? 0 : score.score.clamp(0, 100);
    final quality = score.lowerIsBetter ? 100 - effectiveScore : effectiveScore;
    final color = _scoreColor(quality);
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: score.tint.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: score.tint.withValues(alpha: 0.30)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Text(score.label,
                overflow: TextOverflow.ellipsis,
                style:
                    const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
          ),
          Text(isPlaceholder ? '--' : '$effectiveScore',
              style:
                  const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
        ]),
        const SizedBox(height: 8),
        LinearProgressIndicator(
          value: isPlaceholder ? 0 : effectiveScore / 100,
          color: color,
          backgroundColor: Colors.white.withValues(alpha: 0.12),
          minHeight: 5,
        ),
      ]),
    );
  }

  Color _scoreColor(int score) {
    if (score >= 80) return Colors.greenAccent;
    if (score >= 60) return Colors.lightBlueAccent;
    if (score >= 40) return Colors.orangeAccent;
    return Colors.redAccent;
  }
}

class SimulationHeaderCard extends StatelessWidget {
  const SimulationHeaderCard({
    super.key,
    required this.profile,
    required this.isBusy,
    required this.onRestart,
  });

  final PersonProfile profile;
  final bool isBusy;
  final VoidCallback onRestart;

  @override
  Widget build(BuildContext context) {
    final initial = profile.displayInitial;
    return GlassCard(
      tint: Colors.tealAccent.withValues(alpha: 0.07),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          CircleAvatar(
            backgroundColor: Colors.tealAccent.withValues(alpha: 0.22),
            child: Text(initial,
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w900)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('和 ${profile.displayLabel} 练习反应',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text(profile.subtitleLabel,
                  style: const TextStyle(color: Colors.white70, fontSize: 12)),
            ]),
          ),
          IconButton(
            tooltip: '重新开始',
            onPressed: isBusy ? null : onRestart,
            icon: const Icon(Icons.refresh),
          ),
        ]),
      ),
    );
  }
}
