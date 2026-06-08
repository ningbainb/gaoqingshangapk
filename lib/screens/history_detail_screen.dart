import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/app_provider.dart';
import '../core/app_state.dart';
import '../core/models.dart';
import '../core/presentation_helpers.dart';
import '../core/transient_feedback_timer.dart';
import '../widgets/glass_scaffold.dart';
import '../widgets/glass_widgets.dart';
import '../widgets/history_people_widgets.dart';

class HistoryDetailScreen extends ConsumerStatefulWidget {
  const HistoryDetailScreen({super.key});

  @override
  ConsumerState<HistoryDetailScreen> createState() =>
      _HistoryDetailScreenState();
}

class _HistoryDetailScreenState extends ConsumerState<HistoryDetailScreen> {
  bool didCopyAll = false;
  String? copiedText;
  String? copyFeedbackText;
  Timer? copyAllTimer;
  Timer? copyFeedbackTimer;

  @override
  void initState() {
    super.initState();
    final initialCopied =
        ref.read(appProvider).selectedHistoryRecord?.displayCopiedReply;
    if (initialCopied != null) {
      copiedText = initialCopied;
    }
  }

  @override
  void dispose() {
    copyAllTimer?.cancel();
    copyFeedbackTimer?.cancel();
    super.dispose();
  }

  void _showCopiedAllFeedback() {
    copyAllTimer?.cancel();
    copyFeedbackTimer?.cancel();
    setState(() {
      didCopyAll = true;
      copiedText = null;
      copyFeedbackText = null;
    });
    copyAllTimer = scheduleTransientFeedbackReset(
      previousTimer: copyAllTimer,
      isMounted: () => mounted,
      reset: () => setState(() => didCopyAll = false),
      delay: const Duration(milliseconds: 1300),
    );
  }

  void _showCopiedReplyFeedback(String text) {
    final cleanedText = cleanPresentationText(text);
    if (cleanedText == null) return;
    copyAllTimer?.cancel();
    copyFeedbackTimer?.cancel();
    setState(() {
      copiedText = cleanedText;
      copyFeedbackText = cleanedText;
      didCopyAll = false;
    });
    copyFeedbackTimer = scheduleTransientFeedbackReset(
      previousTimer: copyFeedbackTimer,
      isMounted: () => mounted,
      reset: () => setState(() => copyFeedbackText = null),
      delay: const Duration(milliseconds: 1600),
    );
  }

  bool _isLastCopiedReplyMarked(GenerationRecord record) {
    final text = record.displayCopiedReply;
    if (text == null) return false;
    final replies = cleanUniqueReplySuggestions(record.replies);
    return cleanReplyTextsMatch(copiedText, text) ||
        (copiedText == null &&
            copyFeedbackText == null &&
            replies.any((reply) => cleanReplyTextsMatch(reply.text, text)));
  }

  @override
  Widget build(BuildContext context) {
    final app = ref.watch(appProvider);
    final record = app.selectedHistoryRecord;
    final sceneSummary = record?.displaySceneSummary ?? '未识别场景';
    final platform = record?.displayPlatform;
    final relationship = record?.displayRelationshipGuess;
    final latestMessage = record?.displayLatestMessage;
    final emotion = record?.displayEmotion;
    final riskNotice = record?.displayRiskNotice;
    final userGoal = record?.displayUserGoal;
    final copiedReply = record?.displayCopiedReply;
    final selectedStyleName = record?.displayStyleName ?? '自然';
    final visibleCopyFeedbackText = cleanPresentationText(copyFeedbackText);
    final replies = cleanUniqueReplySuggestions(record?.replies ?? const []);
    return GlassScaffold(
      title: '历史详情',
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 76, 20, 96),
        children: [
          if (record == null)
            const EmptyState(
                icon: Icons.history, title: '没有选择记录', subtitle: '请从历史列表进入详情。')
          else ...[
            GlassCard(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      GlassIcon(
                          record.inputType == ChatInputType.image
                              ? Icons.photo_outlined
                              : Icons.chat_bubble_outline,
                          color: Colors.cyanAccent),
                      const SizedBox(height: 12),
                      Text(sceneSummary,
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w800)),
                      if (platform != null) InfoLine('平台', platform),
                      if (relationship != null) InfoLine('关系', relationship),
                      if (latestMessage != null)
                        InfoLine('最后一句', latestMessage),
                      if (emotion != null) InfoLine('情绪', emotion),
                      if (riskNotice != null) InfoLine('风险', riskNotice),
                      InfoLine(
                          '输入方式',
                          record.inputType == ChatInputType.image
                              ? '截图'
                              : '文本'),
                      InfoLine('风格', selectedStyleName),
                      InfoLine('时间', chineseShortDate(record.createdAt)),
                      if (userGoal != null) InfoLine('目标', userGoal),
                    ]),
              ),
            ),
            if (copiedReply != null) ...[
              const SizedBox(height: 12),
              GlassCard(
                tint: Colors.greenAccent.withValues(alpha: 0.10),
                child: Material(
                  type: MaterialType.transparency,
                  child: ListTile(
                    leading: const Icon(Icons.check_circle_outline),
                    title: const Text('上次复制的回复'),
                    subtitle: Text(copiedReply),
                    trailing: IconButton(
                      tooltip:
                          _isLastCopiedReplyMarked(record) ? '已复制这句' : '复制这句',
                      icon: Icon(_isLastCopiedReplyMarked(record)
                          ? Icons.check
                          : Icons.copy),
                      onPressed: () async {
                        final copied =
                            await app.copyHistoryText(copiedReply, record);
                        if (context.mounted) {
                          if (copied) {
                            _showCopiedReplyFeedback(copiedReply);
                          }
                        }
                      },
                    ),
                  ),
                ),
              ),
            ],
            if (visibleCopyFeedbackText != null) ...[
              const SizedBox(height: 12),
              HistoryCopyFeedbackCard(visibleCopyFeedbackText),
            ],
            const SizedBox(height: 14),
            Row(children: [
              Expanded(
                  child: Text('候选回复 ${replies.length}',
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w800))),
              OutlinedButton.icon(
                onPressed: replies.isEmpty
                    ? null
                    : () async {
                        final text = replies
                            .asMap()
                            .entries
                            .map((e) =>
                                '${e.key + 1}. ${e.value.styleLabel}：${e.value.text}')
                            .join('\n');
                        final copied = await app.copyHistoryText(text, record);
                        if (context.mounted && copied) {
                          _showCopiedAllFeedback();
                        }
                      },
                icon: Icon(didCopyAll ? Icons.check : Icons.copy_all_outlined),
                label: Text(didCopyAll ? '已复制全部' : '复制全部'),
              ),
            ]),
            const SizedBox(height: 10),
            ...replies.map((reply) => ReplyCard(
                  reply: reply,
                  isCopied: cleanReplyTextsMatch(copiedText, reply.text) ||
                      (_isLastCopiedReplyMarked(record) &&
                          cleanReplyTextsMatch(copiedReply, reply.text)),
                  copyLabel: '复制这句',
                  copiedLabel: '已复制这句',
                  onCopy: () async {
                    final copied =
                        await app.copyHistoryText(reply.text, record);
                    if (context.mounted) {
                      if (copied) _showCopiedReplyFeedback(reply.text);
                    }
                  },
                )),
          ],
        ],
      ),
    );
  }
}
