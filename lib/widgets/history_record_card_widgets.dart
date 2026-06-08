import 'package:flutter/material.dart';

import '../core/models.dart';
import '../core/presentation_helpers.dart';
import 'glass_widgets.dart';

class HistoryRecordCard extends StatelessWidget {
  const HistoryRecordCard({
    super.key,
    required this.record,
    required this.onOpen,
    required this.onDelete,
  });

  final GenerationRecord record;
  final VoidCallback onOpen;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final copiedReply = record.displayCopiedReply;
    final sceneSummary = record.displaySceneSummary;
    final latestMessage = record.displayLatestMessage;
    final selectedStyleName = record.displayStyleName;
    final replies = cleanUniqueReplySuggestions(record.replies);
    final isImage = record.inputType == ChatInputType.image;
    return GlassCard(
      margin: const EdgeInsets.only(bottom: 12),
      tint: copiedReply != null
          ? Colors.greenAccent.withValues(alpha: 0.09)
          : isImage
              ? Colors.lightBlueAccent.withValues(alpha: 0.07)
              : Colors.tealAccent.withValues(alpha: 0.06),
      child: InkWell(
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              GlassPill(isImage ? '截图' : '文本'),
              const SizedBox(width: 8),
              Expanded(
                child: Text(selectedStyleName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white70)),
              ),
              const Icon(Icons.chat_bubble_outline, size: 15),
              const SizedBox(width: 4),
              Text('${replies.length}',
                  style: const TextStyle(color: Colors.white70)),
              IconButton(
                tooltip: '删除',
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline),
              ),
            ]),
            const SizedBox(height: 8),
            Text(sceneSummary,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            if (latestMessage != null) ...[
              const SizedBox(height: 5),
              Text(latestMessage,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white70)),
            ],
            if (copiedReply != null) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.greenAccent.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.greenAccent),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.check_circle,
                        size: 16, color: Colors.greenAccent),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('已采用回复',
                                style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.greenAccent,
                                    fontWeight: FontWeight.w800)),
                            const SizedBox(height: 3),
                            Text(copiedReply,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: Colors.white70)),
                          ]),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 9),
            Row(children: [
              const Icon(Icons.calendar_today_outlined, size: 14),
              const SizedBox(width: 5),
              Text(chineseShortDate(record.createdAt),
                  style: const TextStyle(color: Colors.white60, fontSize: 12)),
              if (copiedReply != null) ...[
                const SizedBox(width: 10),
                const Icon(Icons.check_circle,
                    size: 14, color: Colors.greenAccent),
                const SizedBox(width: 4),
                const Text('已复制',
                    style: TextStyle(color: Colors.greenAccent, fontSize: 12)),
              ],
            ]),
          ]),
        ),
      ),
    );
  }
}

class HistoryCopyFeedbackCard extends StatelessWidget {
  const HistoryCopyFeedbackCard(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      tint: Colors.greenAccent.withValues(alpha: 0.08),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const GlassIcon(
            Icons.check_circle_outline,
            color: Colors.greenAccent,
            size: 32,
          ),
          const SizedBox(width: 12),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('已复制到剪贴板',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text(
                text,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}
