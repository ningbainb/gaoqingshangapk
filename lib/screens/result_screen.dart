import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/app_provider.dart';
import '../core/app_routes.dart';
import '../core/app_state.dart';
import '../core/generation_flow.dart';
import '../core/models.dart';
import '../core/platform_bridge.dart';
import '../core/presentation_helpers.dart';
import '../widgets/glass_scaffold.dart';
import '../widgets/glass_widgets.dart';
import '../widgets/profile_widgets.dart';
import '../widgets/result_widgets.dart';

class ResultScreen extends ConsumerStatefulWidget {
  const ResultScreen({super.key});

  @override
  ConsumerState<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends ConsumerState<ResultScreen> {
  String? copiedText;

  @override
  Widget build(BuildContext context) {
    final app = ref.watch(appProvider);
    final response = app.currentResponse;
    final effectiveCopiedText = resultCopiedTextFor(app, response, copiedText);
    final visibleCopiedText = cleanPresentationText(effectiveCopiedText);
    final replies = cleanUniqueReplySuggestions(response?.replies ?? const []);
    final resultInfoLines =
        response?.resultInfoLines ?? const <(String, String)>[];
    Future<void> copyAndMaybeCollapse(ReplySuggestion reply) async {
      final copied = await app.copyReply(reply);
      if (!copied) return;
      if (context.mounted) {
        setState(() => copiedText = cleanPresentationText(reply.text));
      }
      if (!app.isQuickReplySession) return;
      await app.finishQuickReplySession();
      await FloatingCaptureBridge.collapseQuickPanel();
    }

    return GlassScaffold(
      title: '回复建议',
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 76, 20, 96),
        children: [
          if (response == null)
            EmptyState(
                icon: app.isBusy ? Icons.hourglass_top : Icons.auto_awesome,
                title: app.isBusy ? '正在重新生成' : '还没有生成结果',
                subtitle: app.isBusy ? '正在按上一次输入生成新的候选回复。' : '先选择截图或粘贴文本生成回复。')
          else ...[
            GlassCard(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ...resultInfoLines
                        .map((line) => InfoLine(line.$1, line.$2)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (response.personInsight != null) ...[
              PersonInsightResultCard(
                  insight: response.personInsight!,
                  sceneSummary: response.sceneSummary,
                  savedProfile: app.currentGeneratedProfile,
                  onOpenProfile: (profile) {
                    app.selectProfile(profile);
                    context.push(AppRoutes.peopleDetail);
                  },
                  onEditDraft: (profile) {
                    app.selectProfile(profile);
                    context.push(AppRoutes.peopleEdit);
                  }),
              const SizedBox(height: 16),
            ],
            if (visibleCopiedText != null) ...[
              ResultCopySuccessCard(visibleCopiedText),
              const SizedBox(height: 12),
            ],
            Row(children: [
              Expanded(
                child: Text('候选回复 ${replies.length}',
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w800)),
              ),
              OutlinedButton.icon(
                onPressed: replies.isEmpty
                    ? null
                    : () => copyAndMaybeCollapse(replies.first),
                icon: Icon(replies.isNotEmpty &&
                        cleanReplyTextsMatch(
                            effectiveCopiedText, replies.first.text)
                    ? Icons.check
                    : Icons.copy_all_outlined),
                label: Text(replies.isNotEmpty &&
                        cleanReplyTextsMatch(
                            effectiveCopiedText, replies.first.text)
                    ? '已复制首条'
                    : '复制首条'),
              ),
            ]),
            const SizedBox(height: 10),
            ...replies.map((reply) => ReplyCard(
                reply: reply,
                isCopied: cleanReplyTextsMatch(effectiveCopiedText, reply.text),
                onCopy: () => copyAndMaybeCollapse(reply))),
            const SizedBox(height: 12),
            GlassCard(
              tint:
                  Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('继续调整',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 6),
                      const Text('想换一批候选就重新生成；想改截图、文本或目标，就返回上一步。',
                          style: TextStyle(color: Colors.white70)),
                      const SizedBox(height: 12),
                      Row(children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => context.go(app.isQuickReplySession
                                ? AppRoutes.quick
                                : app.currentInputType == ChatInputType.image
                                    ? AppRoutes.image
                                    : AppRoutes.text),
                            icon: const Icon(Icons.tune),
                            label: const Text('返回修改'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: FilledButton.icon(
                            onPressed:
                                app.canRegenerate ? app.regenerateLast : null,
                            icon: app.isBusy
                                ? const SizedBox.square(
                                    dimension: 16,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2))
                                : const Icon(Icons.refresh),
                            label: Text(app.isBusy ? '生成中...' : '重新生成'),
                          ),
                        ),
                      ]),
                    ]),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
