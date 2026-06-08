import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/app_feedback.dart';
import '../core/app_provider.dart';
import '../core/app_routes.dart';
import '../core/app_state.dart';
import '../core/generation_goal_helpers.dart';
import '../core/generation_flow.dart';
import '../core/models.dart';
import '../core/presentation_helpers.dart';
import '../core/transient_feedback_timer.dart';
import '../widgets/glass_scaffold.dart';
import '../widgets/glass_widgets.dart';
import '../widgets/profile_widgets.dart';
import '../widgets/text_input_widgets.dart';
import 'profile_selection_helpers.dart';

class TextInputScreen extends ConsumerStatefulWidget {
  const TextInputScreen({super.key});

  @override
  ConsumerState<TextInputScreen> createState() => _TextInputScreenState();
}

class _TextInputScreenState extends ConsumerState<TextInputScreen> {
  final text = TextEditingController();
  final goal = TextEditingController();
  String? selectedProfileId;
  String? pasteMessage;
  ChatStyle? style;
  bool didPaste = false;
  Timer? pasteFeedbackTimer;

  @override
  void initState() {
    super.initState();
    final app = ref.read(appProvider);
    app.clearFeedback(notify: false);
    if (app.currentInputType != ChatInputType.text) return;
    final restoredText = cleanChatTextInput(app.currentTextInput);
    if (restoredText != null) {
      text.text = restoredText;
      text.selection = TextSelection.collapsed(offset: text.text.length);
    }
    final restoredGoal = optionalSanitizedGoal(app.currentGoal);
    if (restoredGoal != null) {
      goal.text = restoredGoal;
    }
    style = app.currentStyle;
    selectedProfileId = restorableScreenProfileId(app);
  }

  @override
  void dispose() {
    pasteFeedbackTimer?.cancel();
    text.dispose();
    goal.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = ref.watch(appProvider);
    _schedulePendingSharedText(app);
    final selected = style ?? app.defaultStyle;
    final stats = chatTextStats(text.text);
    final readiness = GenerateAPIReadiness(
      config: app.config,
      hasAPIKey: hasUsableAPIKey(app.apiKey),
      capability: GenerateAPICapability.text,
    );
    return GlassScaffold(
      title: '文本生成',
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 76, 20, 96),
        children: [
          APIReadinessCard(readiness: readiness),
          const SizedBox(height: 16),
          GlassTextField(
              controller: text,
              label: '聊天内容',
              hint: '把聊天记录粘贴到这里',
              minLines: 8,
              maxLines: 14,
              onChanged: (_) {
                app.clearFeedback(notify: false);
                setState(() {});
              }),
          const SizedBox(height: 10),
          TextInputToolsCard(
            stats: stats,
            hasText: hasUsableChatText(text.text),
            didPaste: didPaste,
            onPaste: _pasteClipboardText,
            onClear: () {
              app.clearFeedback(notify: false);
              app.clearEditableTextDraft();
              setState(() {
                text.clear();
                pasteMessage = null;
                didPaste = false;
                pasteFeedbackTimer?.cancel();
              });
            },
          ),
          if (pasteMessage != null) ...[
            const SizedBox(height: 10),
            ErrorBanner(pasteMessage!),
          ],
          const SizedBox(height: 16),
          const SectionHeader('聊天风格', Icons.style_outlined),
          StylePicker(
              selected: selected,
              styles: app.personalization.availableStyles,
              onChanged: (next) {
                app.clearFeedback(notify: false);
                setState(() => style = next);
              }),
          const SizedBox(height: 16),
          GlassTextField(
              controller: goal,
              label: '我的目标',
              hint: '想自然一点、想拒绝但不尴尬...',
              onChanged: (_) {
                app.clearFeedback(notify: false);
                setState(() {});
              }),
          const SizedBox(height: 10),
          GoalSuggestionsCard(
            selectedGoal: goal.text,
            onSelected: (next) {
              app.clearFeedback(notify: false);
              setState(() => goal.text = next);
            },
          ),
          const SizedBox(height: 18),
          PersonProfilePickerCard(
            title: '聊天对象',
            profiles: app.profiles,
            selectedProfileId: selectedProfileId,
            onChanged: (next) {
              app.clearFeedback(notify: false);
              setState(() => selectedProfileId = next);
            },
            emptyText: '生成人物画像后，可以在这里指定聊天对象。',
            autoSummary: '自动模式会带入最近的人物库帮助判断对象。',
            selectedSummary: (profile) => '将按「${profile.displayLabel}」制定回复。',
          ),
          const SizedBox(height: 18),
          if (app.errorMessage != null) ErrorBanner(app.errorMessage!),
          FilledButton.icon(
            onPressed: !canSubmitTextGeneration(
                    readiness: readiness, isBusy: app.isBusy, text: text.text)
                ? null
                : () async {
                    await app.generateText(
                      text.text,
                      selected,
                      goal.text,
                      selectedProfileId: selectedProfileId,
                    );
                    if (context.mounted && app.currentResponse != null) {
                      context.go(AppRoutes.result);
                    }
                  },
            icon: app.isBusy
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.auto_awesome),
            label: Text(app.isBusy ? '生成中...' : '生成回复'),
          ),
        ],
      ),
    );
  }

  Future<void> _pasteClipboardText() async {
    ClipboardData? data;
    try {
      data = await Clipboard.getData(Clipboard.kTextPlain);
    } catch (error) {
      if (!mounted) return;
      pasteFeedbackTimer?.cancel();
      ref.read(appProvider).clearFeedback(notify: false);
      setState(() {
        didPaste = false;
      });
      _showPasteMessage('读取剪贴板失败：${userMessageFor(error)}');
      return;
    }
    if (!mounted) return;
    final pasted = cleanChatTextInput(data?.text);
    if (pasted == null) {
      ref.read(appProvider).clearFeedback(notify: false);
      pasteFeedbackTimer?.cancel();
      setState(() {
        didPaste = false;
      });
      _showPasteMessage('剪贴板里没有可用文本。');
      return;
    }
    ref.read(appProvider).clearFeedback(notify: false);
    pasteFeedbackTimer?.cancel();
    setState(() {
      text.text = appendClipboardText(text.text, pasted);
      text.selection = TextSelection.collapsed(offset: text.text.length);
      pasteMessage = null;
      didPaste = true;
    });
    pasteFeedbackTimer = scheduleTransientFeedbackReset(
      previousTimer: pasteFeedbackTimer,
      isMounted: () => mounted,
      reset: () => setState(() => didPaste = false),
    );
  }

  void _showPasteMessage(String message) {
    setState(() => pasteMessage = message);
    pasteFeedbackTimer = scheduleTransientFeedbackReset(
      previousTimer: pasteFeedbackTimer,
      isMounted: () => mounted,
      reset: () => setState(() => pasteMessage = null),
      delay: const Duration(milliseconds: 1800),
    );
  }

  void _schedulePendingSharedText(AppController app) {
    if (app.shouldDeferExternalHandoffs) return;
    if (app.sharedText == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final controller = ref.read(appProvider);
      final incoming = controller.consumeSharedText();
      final sharedText = cleanChatTextInput(incoming);
      if (sharedText == null) return;
      setState(() {
        text.text = sharedText;
        text.selection = TextSelection.collapsed(offset: text.text.length);
        goal.clear();
        style = controller.currentStyle;
        selectedProfileId = restorableScreenProfileId(controller);
        pasteMessage = null;
        didPaste = false;
        pasteFeedbackTimer?.cancel();
      });
    });
  }
}
