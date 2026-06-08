import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/app_provider.dart';
import '../core/app_routes.dart';
import '../core/app_state.dart';
import '../core/models.dart';
import '../core/presentation_helpers.dart';
import '../widgets/glass_scaffold.dart';
import '../widgets/glass_widgets.dart';
import '../widgets/history_people_widgets.dart';
import '../widgets/simulation_screen_widgets.dart';
import '../widgets/simulation_widgets.dart';

class SimulationProfileSelectScreen extends ConsumerWidget {
  const SimulationProfileSelectScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final app = ref.watch(appProvider);
    final profiles = filterPersonProfiles(
      app.profiles,
      sortMode: PersonProfileSortMode.recent,
      query: '',
    );
    final header = <Widget>[
      GlassCard(
        tint: Colors.purpleAccent.withValues(alpha: 0.08),
        child: const Padding(
          padding: EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.forum_outlined, color: Colors.purpleAccent),
              SizedBox(width: 10),
              Expanded(
                child: Text('选择训练对象。系统会按该人物画像模拟对方语气，并根据你的回复给出反馈。'),
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 14),
      const SectionHeader('人物', Icons.people_outline),
    ];
    return GlassScaffold(
      title: '选择人物',
      child: profiles.isEmpty
          ? ListView(
              padding: const EdgeInsets.fromLTRB(20, 76, 20, 96),
              children: const [
                EmptyState(
                    icon: Icons.person_add_alt_1,
                    title: '还没有可训练的人物',
                    subtitle: '先添加人物画像，再开始模拟对话训练。'),
              ],
            )
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(20, 76, 20, 96),
              itemCount: header.length + profiles.length,
              itemBuilder: (context, index) {
                if (index < header.length) return header[index];
                final profile = profiles[index - header.length];
                return PersonProfileListCard(
                  profile: profile,
                  onOpen: () async {
                    await app.startSimulation(
                      profile,
                      resetScenario: true,
                    );
                    if (context.mounted) context.push(AppRoutes.simulation);
                  },
                );
              },
            ),
    );
  }
}

class SimulationScreen extends ConsumerStatefulWidget {
  const SimulationScreen({super.key});

  @override
  ConsumerState<SimulationScreen> createState() => _SimulationScreenState();
}

class _SimulationScreenState extends ConsumerState<SimulationScreen> {
  final reply = TextEditingController();
  String? selectedOptionId;

  @override
  void initState() {
    super.initState();
    ref.read(appProvider).clearFeedback(notify: false);
  }

  @override
  void dispose() {
    reply.dispose();
    super.dispose();
  }

  Future<void> _restartSimulation(
    AppController app,
    PersonProfile profile, {
    SimulationScenario? scenario,
  }) async {
    if (scenario != null) {
      app.simulationScenario = scenario;
    }
    setState(() {
      reply.clear();
      selectedOptionId = null;
    });
    await app.startSimulation(profile);
  }

  void _chooseOption(SimulationOption option) {
    setState(() {
      selectedOptionId = option.id;
      reply.text = option.text;
      reply.selection = TextSelection.collapsed(offset: reply.text.length);
    });
  }

  Future<void> _submitReply(AppController app, {String? text}) async {
    final submitted = cleanSimulationReplyInput(text ?? reply.text);
    if (submitted == null || app.isBusy) return;
    if (text != null) {
      setState(() {
        reply.text = submitted;
        reply.selection = TextSelection.collapsed(offset: reply.text.length);
      });
    }
    final succeeded = await app.submitSimulationReply(submitted);
    if (!mounted) return;
    if (succeeded) {
      setState(() {
        reply.clear();
        selectedOptionId = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = ref.watch(appProvider);
    final profile = app.simulationProfile;
    return GlassScaffold(
      title: profile == null ? '模拟练习' : '${profile.displayLabel} · 模拟练习',
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 76, 20, 96),
        children: [
          if (profile == null)
            const EmptyState(
                icon: Icons.forum_outlined,
                title: '没有选择人物',
                subtitle: '请先从人物库选择一个对象开始练习。')
          else ...[
            SimulationHeaderCard(
              profile: profile,
              isBusy: app.isBusy,
              onRestart: () => unawaited(_restartSimulation(app, profile)),
            ),
            const SizedBox(height: 12),
            SimulationScenarioCard(
              scenario: app.simulationScenario,
              isBusy: app.isBusy,
              onChanged: (scenario) => unawaited(_restartSimulation(
                app,
                profile,
                scenario: scenario,
              )),
            ),
            const SizedBox(height: 12),
            SimulationMetricsCard(
              response: app.simulationResponse,
              isBusy: app.isBusy,
            ),
            const SizedBox(height: 12),
            SimulationConversationCard(
              messages: app.simulationMessages,
              isBusy: app.isBusy,
            ),
            const SizedBox(height: 12),
            if (app.simulationResponse != null) ...[
              SimulationFeedbackCard(response: app.simulationResponse!),
              const SizedBox(height: 12),
            ],
            SimulationOptionsCard(
              response: app.simulationResponse,
              isBusy: app.isBusy,
              selectedOptionId: selectedOptionId,
              onSelected: _chooseOption,
              onSubmit: (option) =>
                  unawaited(_submitReply(app, text: option.text)),
            ),
            const SizedBox(height: 14),
            SimulationReplyInputCard(
              reply: reply,
              isBusy: app.isBusy,
              errorMessage: app.errorMessage,
              onChanged: (_) => setState(() => selectedOptionId = null),
              onSubmit: () => unawaited(_submitReply(app)),
            ),
          ],
        ],
      ),
    );
  }
}
