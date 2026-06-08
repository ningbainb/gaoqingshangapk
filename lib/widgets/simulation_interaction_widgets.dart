import 'package:flutter/material.dart';

import '../core/models.dart';
import 'glass_widgets.dart';
import 'simulation_widgets.dart';

class SimulationConversationCard extends StatelessWidget {
  const SimulationConversationCard({
    super.key,
    required this.messages,
    required this.isBusy,
  });

  final List<SimulationMessage> messages;
  final bool isBusy;

  @override
  Widget build(BuildContext context) {
    final visibleMessages = cleanSimulationMessages(messages);
    return GlassCard(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Row(children: [
            Icon(Icons.forum_outlined, size: 18),
            SizedBox(width: 8),
            Text('对话', style: TextStyle(fontWeight: FontWeight.w800)),
          ]),
          const SizedBox(height: 12),
          if (visibleMessages.isEmpty && isBusy)
            const Row(children: [
              SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(width: 10),
              Text('正在模拟对方开场', style: TextStyle(color: Colors.white70)),
            ])
          else if (visibleMessages.isEmpty)
            const Text('还没有对话内容。点击重新开始可生成开场。',
                style: TextStyle(color: Colors.white70))
          else
            ...visibleMessages.map(_SimulationMessageBubble.new),
        ]),
      ),
    );
  }
}

class _SimulationMessageBubble extends StatelessWidget {
  const _SimulationMessageBubble(this.message);

  final SimulationMessage message;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: message.speaker == SimulationSpeaker.user
          ? Alignment.centerRight
          : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 320),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: message.speaker == SimulationSpeaker.user
              ? Colors.cyan.withValues(alpha: 0.26)
              : Colors.white.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white24),
        ),
        child: Text(message.text),
      ),
    );
  }
}

class SimulationFeedbackCard extends StatelessWidget {
  const SimulationFeedbackCard({super.key, required this.response});

  final SimulationTurnResponse response;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      tint: Colors.orangeAccent.withValues(alpha: 0.05),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(
              response.userScore == null
                  ? Icons.tips_and_updates_outlined
                  : Icons.star_rate_rounded,
              size: 18,
              color: Colors.orangeAccent,
            ),
            const SizedBox(width: 8),
            Text(
                response.userScore == null
                    ? '教练反馈'
                    : '本轮得分 ${response.userScore}',
                style: const TextStyle(fontWeight: FontWeight.w800)),
          ]),
          if (response.feedback != null) ...[
            const SizedBox(height: 10),
            Text(response.feedback!,
                style: const TextStyle(color: Colors.white70, height: 1.35)),
          ],
          if (response.betterReply != null) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.lightBlueAccent.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.lightBlueAccent),
              ),
              child: Text('更稳回复：${response.betterReply}',
                  style: const TextStyle(fontWeight: FontWeight.w700)),
            ),
          ],
          const SizedBox(height: 10),
          Text('教练提示：${response.coachTip}',
              style: const TextStyle(color: Colors.white70, height: 1.35)),
          if (response.metrics.isNotEmpty) ...[
            const SizedBox(height: 12),
            ...response.metrics.map((metric) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                      '${metric.name} ${metric.score}：${metric.insight}',
                      style: const TextStyle(
                          color: Colors.white70, fontSize: 12, height: 1.3)),
                )),
          ],
        ]),
      ),
    );
  }
}

class SimulationOptionsCard extends StatelessWidget {
  const SimulationOptionsCard({
    super.key,
    required this.response,
    required this.isBusy,
    required this.selectedOptionId,
    required this.onSelected,
    required this.onSubmit,
  });

  final SimulationTurnResponse? response;
  final bool isBusy;
  final String? selectedOptionId;
  final ValueChanged<SimulationOption> onSelected;
  final ValueChanged<SimulationOption> onSubmit;

  @override
  Widget build(BuildContext context) {
    final options = cleanUniqueSimulationOptions(response?.options ?? const []);
    return GlassCard(
      tint: Colors.cyanAccent.withValues(alpha: 0.05),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Row(children: [
            Icon(Icons.checklist, color: Colors.cyanAccent),
            SizedBox(width: 8),
            Text('选项回答', style: TextStyle(fontWeight: FontWeight.w800)),
          ]),
          const SizedBox(height: 10),
          if (isBusy)
            const SizedBox.square(
              dimension: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else if (options.isNotEmpty)
            ...options.map(
              (option) => SimulationOptionCard(
                option: option,
                isSelected: selectedOptionId == option.id,
                onSelected: () => onSelected(option),
                onSubmit: () => onSubmit(option),
              ),
            )
          else
            const Text('生成后会给出 3 个可选回复。',
                style: TextStyle(color: Colors.white70)),
        ]),
      ),
    );
  }
}

class SimulationReplyInputCard extends StatelessWidget {
  const SimulationReplyInputCard({
    super.key,
    required this.reply,
    required this.isBusy,
    required this.errorMessage,
    required this.onChanged,
    required this.onSubmit,
  });

  final TextEditingController reply;
  final bool isBusy;
  final String? errorMessage;
  final ValueChanged<String> onChanged;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      tint: Colors.orangeAccent.withValues(alpha: 0.05),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Row(children: [
            Icon(Icons.edit_outlined, color: Colors.orangeAccent),
            SizedBox(width: 8),
            Text('自己回答', style: TextStyle(fontWeight: FontWeight.w800)),
          ]),
          const SizedBox(height: 10),
          GlassTextField(
              controller: reply,
              label: '我的回复',
              hint: '写下你会怎么回，也可以先点上面的选项',
              minLines: 2,
              maxLines: 5,
              onChanged: onChanged),
          const SizedBox(height: 12),
          if (errorMessage != null) ...[
            ErrorBanner(errorMessage!),
            const SizedBox(height: 10),
          ],
          FilledButton.icon(
            onPressed: canSubmitSimulationReplyInput(
              reply.text,
              isBusy: isBusy,
            )
                ? onSubmit
                : null,
            icon: isBusy
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.send_outlined),
            label: Text(isBusy ? '思考中...' : '提交并打分'),
          ),
        ]),
      ),
    );
  }
}
