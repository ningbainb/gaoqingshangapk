import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/app_provider.dart';
import '../core/app_routes.dart';
import '../core/app_state.dart';
import '../core/presentation_helpers.dart';
import '../core/transient_feedback_timer.dart';
import '../widgets/glass_scaffold.dart';
import '../widgets/glass_widgets.dart';
import '../widgets/profile_widgets.dart';

export 'profile_editor_screen.dart';

class ProfileDetailScreen extends ConsumerStatefulWidget {
  const ProfileDetailScreen({super.key});

  @override
  ConsumerState<ProfileDetailScreen> createState() =>
      _ProfileDetailScreenState();
}

class _ProfileDetailScreenState extends ConsumerState<ProfileDetailScreen> {
  bool didCopySummary = false;
  Timer? copySummaryTimer;

  @override
  void dispose() {
    copySummaryTimer?.cancel();
    super.dispose();
  }

  void _showCopySummaryFeedback() {
    setState(() => didCopySummary = true);
    copySummaryTimer = scheduleTransientFeedbackReset(
      previousTimer: copySummaryTimer,
      isMounted: () => mounted,
      reset: () => setState(() => didCopySummary = false),
      delay: const Duration(milliseconds: 1400),
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = ref.watch(appProvider);
    final profile = app.selectedProfile;
    final displayName = profile?.displayLabel;
    final communicationStyle = profile?.displayCommunicationStyle;
    final latestWriteSources =
        profile?.displayLatestWriteSources ?? const <String>[];
    return GlassScaffold(
      title: '人物详情',
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 76, 20, 96),
        children: [
          if (profile == null)
            const EmptyState(
                icon: Icons.person_outline,
                title: '没有选择人物',
                subtitle: '请从人物库进入详情。')
          else ...[
            GlassCard(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        CircleAvatar(
                            radius: 28, child: Text(profile.displayInitial)),
                        const SizedBox(width: 12),
                        Expanded(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                              Text(displayName!,
                                  style: const TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w800)),
                              Text(profile.detailRelationshipLabel,
                                  style:
                                      const TextStyle(color: Colors.white70)),
                            ])),
                      ]),
                      if (communicationStyle != null)
                        InfoLine('沟通风格', communicationStyle),
                      const SizedBox(height: 8),
                      Wrap(spacing: 8, runSpacing: 8, children: [
                        GlassPill('完整度 ${profile.coveragePercent}%'),
                        GlassPill('置信度 ${(profile.confidence * 100).round()}%'),
                      ]),
                      const SizedBox(height: 12),
                      Wrap(spacing: 8, runSpacing: 8, children: [
                        FilledButton.icon(
                          onPressed: () async {
                            await app.startSimulation(
                              profile,
                              resetScenario: true,
                            );
                            if (context.mounted) {
                              context.push(AppRoutes.simulation);
                            }
                          },
                          icon: const Icon(Icons.forum_outlined),
                          label: const Text('模拟对话训练'),
                        ),
                        OutlinedButton.icon(
                          onPressed: () async {
                            final copied =
                                await app.copyProfileSummary(profile);
                            if (mounted && copied) _showCopySummaryFeedback();
                          },
                          icon: Icon(didCopySummary ? Icons.check : Icons.copy),
                          label: Text(didCopySummary ? '已复制画像上下文' : '复制画像上下文'),
                        ),
                        OutlinedButton.icon(
                          onPressed: () => context.push(AppRoutes.peopleEdit),
                          icon: const Icon(Icons.edit_outlined),
                          label: const Text('编辑'),
                        ),
                      ]),
                    ]),
              ),
            ),
            const SizedBox(height: 12),
            ProfileCoverageCard(profile: profile),
            if (latestWriteSources.isNotEmpty)
              ProfileDetailSection(
                  title: '最近写入依据',
                  values: latestWriteSources,
                  icon: Icons.input_outlined),
            ProfileDetailSection(
                title: '性格倾向',
                values: profile.personalityTraits,
                icon: Icons.psychology_alt_outlined),
            ProfileDetailSection(
                title: '内心需求',
                values: profile.innerNeeds,
                icon: Icons.favorite_border),
            ProfileDetailSection(
                title: '关键人物点',
                values: profile.keyPersonPoints,
                icon: Icons.push_pin_outlined),
            ProfileDetailSection(
                title: '朋友圈观察',
                values: profile.momentsInsights,
                icon: Icons.collections_outlined),
            ProfileDetailSection(
                title: '适合怎么回',
                values: profile.tonePreferences,
                icon: Icons.auto_awesome),
            ProfileDetailSection(
                title: '聊天避雷',
                values: profile.boundaries,
                icon: Icons.front_hand_outlined),
            ProfileDetailSection(
                title: '已知信息',
                values: profile.facts,
                icon: Icons.notes_outlined),
            const SizedBox(height: 4),
            const Text(
              '仅根据聊天文字、朋友圈内容、可见昵称和关系语境更新；不会根据头像或面部识别真实身份。',
              style: TextStyle(color: Colors.white60, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }
}
