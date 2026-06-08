import 'package:flutter/material.dart';

import '../core/models.dart';
import 'glass_widgets.dart';
import 'simulation_widgets.dart';

export 'simulation_interaction_widgets.dart';

class SimulationScenarioCard extends StatelessWidget {
  const SimulationScenarioCard({
    super.key,
    required this.scenario,
    required this.isBusy,
    required this.onChanged,
  });

  final SimulationScenario scenario;
  final bool isBusy;
  final ValueChanged<SimulationScenario> onChanged;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      tint: Colors.blueAccent.withValues(alpha: 0.05),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Row(children: [
            Icon(Icons.track_changes, size: 18, color: Colors.lightBlueAccent),
            SizedBox(width: 8),
            Text('训练场景', style: TextStyle(fontWeight: FontWeight.w800)),
          ]),
          const SizedBox(height: 8),
          DropdownButton<SimulationScenario>(
            value: scenario,
            isExpanded: true,
            dropdownColor: const Color(0xFF123545),
            items: SimulationScenario.values
                .map((scenario) => DropdownMenuItem(
                    value: scenario,
                    child: Text('${scenario.title} · ${scenario.promptGoal}',
                        overflow: TextOverflow.ellipsis)))
                .toList(),
            onChanged: isBusy
                ? null
                : (scenario) {
                    if (scenario != null) onChanged(scenario);
                  },
          ),
          const SizedBox(height: 6),
          Text(scenario.promptGoal,
              style: const TextStyle(color: Colors.white70, fontSize: 12)),
        ]),
      ),
    );
  }
}

class SimulationMetricsCard extends StatelessWidget {
  const SimulationMetricsCard({
    super.key,
    required this.response,
    required this.isBusy,
  });

  final SimulationTurnResponse? response;
  final bool isBusy;

  @override
  Widget build(BuildContext context) {
    final metrics = response == null
        ? const <SimulationScore>[
            SimulationScore('好感度', 0, Colors.pinkAccent),
            SimulationScore('紧张度', 0, Colors.orangeAccent, lowerIsBetter: true),
            SimulationScore('信任度', 0, Colors.lightBlueAccent),
            SimulationScore('兴趣度', 0, Colors.purpleAccent),
          ]
        : [
            SimulationScore('好感度', response!.favorability, Colors.pinkAccent),
            SimulationScore('紧张度', response!.tension, Colors.orangeAccent,
                lowerIsBetter: true),
            SimulationScore('信任度', response!.trust, Colors.lightBlueAccent),
            SimulationScore('兴趣度', response!.interest, Colors.purpleAccent),
          ];
    return GlassCard(
      tint: Colors.greenAccent.withValues(alpha: 0.05),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Row(children: [
            Icon(Icons.bar_chart, size: 18, color: Colors.greenAccent),
            SizedBox(width: 8),
            Text('当前指标', style: TextStyle(fontWeight: FontWeight.w800)),
          ]),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 2,
            childAspectRatio: 2.35,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: metrics
                .map((score) => SimulationScoreTile(
                      score: score,
                      isPlaceholder: response == null,
                    ))
                .toList(),
          ),
          const SizedBox(height: 10),
          Text(
            response?.sceneState ?? (isBusy ? '正在模拟对方开场。' : '开始训练后会显示当前关系状态。'),
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ]),
      ),
    );
  }
}
