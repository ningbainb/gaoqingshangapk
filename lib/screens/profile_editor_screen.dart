import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/app_provider.dart';
import '../core/app_routes.dart';
import '../core/app_state.dart';
import '../core/models.dart';
import '../core/presentation_helpers.dart';
import '../core/transient_feedback_timer.dart';
import '../widgets/glass_scaffold.dart';
import '../widgets/glass_widgets.dart';
import '../widgets/profile_widgets.dart';

class ProfileEditorScreen extends ConsumerStatefulWidget {
  const ProfileEditorScreen({super.key});

  @override
  ConsumerState<ProfileEditorScreen> createState() =>
      _ProfileEditorScreenState();
}

class _ProfileEditorScreenState extends ConsumerState<ProfileEditorScreen> {
  late final AppController _app = ref.read(appProvider);
  late final original = _app.selectedProfile;
  late final displayName =
      TextEditingController(text: original?.displayName ?? '');
  late final aliases = TextEditingController(
      text: joinEditorLines(original?.aliases ?? const []));
  late final relationship =
      TextEditingController(text: original?.relationship ?? '');
  late final communicationStyle =
      TextEditingController(text: original?.communicationStyle ?? '');
  late final personalityTraits = TextEditingController(
      text: joinEditorLines(original?.personalityTraits ?? const []));
  late final innerNeeds = TextEditingController(
      text: joinEditorLines(original?.innerNeeds ?? const []));
  late final keyPersonPoints = TextEditingController(
      text: joinEditorLines(original?.keyPersonPoints ?? const []));
  late final momentsInsights = TextEditingController(
      text: joinEditorLines(original?.momentsInsights ?? const []));
  late final tonePreferences = TextEditingController(
      text: joinEditorLines(original?.tonePreferences ?? const []));
  late final boundaries = TextEditingController(
      text: joinEditorLines(original?.boundaries ?? const []));
  late final facts =
      TextEditingController(text: joinEditorLines(original?.facts ?? const []));
  late final lastSceneSummary =
      TextEditingController(text: original?.lastSceneSummary ?? '');
  late final lastUpdateReason =
      TextEditingController(text: original?.lastUpdateReason ?? '');
  late double confidence = original?.confidence ?? 0.5;
  String? quickFillStatus;
  Timer? quickFillTimer;

  @override
  void initState() {
    super.initState();
    _app.clearFeedback(notify: false);
  }

  @override
  void dispose() {
    quickFillTimer?.cancel();
    for (final c in [
      displayName,
      aliases,
      relationship,
      communicationStyle,
      personalityTraits,
      innerNeeds,
      keyPersonPoints,
      momentsInsights,
      tonePreferences,
      boundaries,
      facts,
      lastSceneSummary,
      lastUpdateReason
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  void _clearUnsavedDraftSelection() {
    final draft = original;
    if (draft == null) return;
    final isPersisted = _app.profiles
        .any((profile) => personProfileIdsMatch(profile.id, draft.id));
    if (!isPersisted &&
        personProfileIdsMatch(_app.selectedProfile?.id, draft.id)) {
      _app.selectProfile(null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = ref.watch(appProvider);
    final canSave = canSaveProfileEditorDraft(displayName.text);
    return PopScope<Object?>(
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) _clearUnsavedDraftSelection();
      },
      child: GlassScaffold(
        title: original == null ? '添加人物' : '编辑人物',
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 76, 20, 96),
          children: [
            GlassTextField(
                controller: displayName,
                label: '人物名称',
                hint: '例如：小陈',
                onChanged: (_) {
                  app.clearFeedback(notify: false);
                  setState(() {});
                }),
            const SizedBox(height: 10),
            GlassTextField(
                controller: aliases,
                label: '别名',
                hint: '每行一个昵称或备注',
                minLines: 2,
                maxLines: 4),
            const SizedBox(height: 10),
            GlassTextField(
                controller: relationship,
                label: '关系',
                hint: '朋友、同学、同事、暧昧对象...'),
            const SizedBox(height: 10),
            GlassTextField(
                controller: communicationStyle,
                label: '沟通风格摘要',
                hint: '例如：喜欢轻松直接，讨厌被追问'),
            const SizedBox(height: 10),
            ParameterSlider(
                label: '置信度',
                value: confidence,
                min: 0,
                max: 1,
                divisions: 20,
                fractionDigits: 2,
                onChanged: (v) => setState(() => confidence = v)),
            ProfileQuickFillCard(
              onStableReply: () {
                _appendLine(innerNeeds, '需要稳定回应');
                _appendLine(tonePreferences, '回复要明确、可预期');
                _markPresetApplied('稳定回应');
              },
              onLightHumor: () {
                _appendLine(personalityTraits, '带有幽默感');
                _appendLine(tonePreferences, '适合轻松、口语化地聊');
                _markPresetApplied('轻松幽默');
              },
              onAvoidPressure: () {
                _appendLine(boundaries, '避免催促或逼问');
                _appendLine(keyPersonPoints, '给对方一点缓冲空间');
                _markPresetApplied('别催促');
              },
              onPlanning: () {
                _appendLine(personalityTraits, '重视计划感');
                _appendLine(keyPersonPoints, '提前说清时间和安排');
                _markPresetApplied('重视计划');
              },
            ),
            ProfileEditorField(label: '性格倾向', controller: personalityTraits),
            ProfileEditorField(label: '内心需求', controller: innerNeeds),
            ProfileEditorField(label: '关键人物点', controller: keyPersonPoints),
            ProfileEditorField(label: '朋友圈观察', controller: momentsInsights),
            ProfileEditorField(label: '适合怎么回', controller: tonePreferences),
            ProfileEditorField(label: '聊天避雷', controller: boundaries),
            ProfileEditorField(label: '已知信息', controller: facts),
            ProfileEditorField(
                label: '最近写入依据', controller: lastSceneSummary, minLines: 2),
            ProfileEditorField(
                label: '更新原因', controller: lastUpdateReason, minLines: 2),
            const SizedBox(height: 12),
            if (quickFillStatus != null) ...[
              SuccessBanner(quickFillStatus!),
              const SizedBox(height: 10),
            ],
            if (app.errorMessage != null) ErrorBanner(app.errorMessage!),
            FilledButton.icon(
              onPressed: canSave ? () => _saveProfile(app, context) : null,
              icon: const Icon(Icons.save_outlined),
              label: const Text('保存人物'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveProfile(AppController app, BuildContext context) async {
    final profile = personProfileFromEditorDraft(
      original: original,
      displayName: displayName.text,
      aliases: aliases.text,
      relationship: relationship.text,
      communicationStyle: communicationStyle.text,
      personalityTraits: personalityTraits.text,
      innerNeeds: innerNeeds.text,
      keyPersonPoints: keyPersonPoints.text,
      momentsInsights: momentsInsights.text,
      tonePreferences: tonePreferences.text,
      boundaries: boundaries.text,
      facts: facts.text,
      lastSceneSummary: lastSceneSummary.text,
      lastUpdateReason: lastUpdateReason.text,
      confidence: confidence,
    );
    if (profile == null) return;
    await app.saveProfile(profile);
    if (context.mounted) context.go(AppRoutes.peopleDetail);
  }

  void _appendLine(TextEditingController controller, String value) {
    controller.text = profileEditorTextWithSuggestion(controller.text, value);
  }

  void _markPresetApplied(String title) {
    setState(() => quickFillStatus = '已追加「$title」画像线索，可继续手动调整。');
    quickFillTimer = scheduleTransientFeedbackReset(
      previousTimer: quickFillTimer,
      isMounted: () => mounted,
      reset: () => setState(() => quickFillStatus = null),
      delay: const Duration(milliseconds: 1500),
    );
  }
}
