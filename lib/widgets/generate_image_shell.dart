import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/app_feedback.dart';
import '../core/app_provider.dart';
import '../core/app_state.dart';
import '../core/generation_flow.dart';
import '../core/models.dart';
import '../core/presentation_helpers.dart';
import 'glass_scaffold.dart';
import 'glass_widgets.dart';
import 'image_input_widgets.dart';
import 'profile_widgets.dart';

class GenerateImageShell extends ConsumerWidget {
  const GenerateImageShell({
    super.key,
    required this.title,
    required this.isQuickReply,
    required this.imagePath,
    required this.goal,
    required this.style,
    required this.onStyle,
    required this.selectedProfileId,
    required this.onProfileChanged,
    required this.onPick,
    required this.onClearImage,
    required this.onCaptureScreen,
    required this.onReadClipboard,
    this.isReadingClipboard = false,
    this.didReadClipboard = false,
    required this.onGenerate,
  });

  final String title;
  final bool isQuickReply;
  final String? imagePath;
  final TextEditingController goal;
  final ChatStyle style;
  final ValueChanged<ChatStyle> onStyle;
  final String? selectedProfileId;
  final ValueChanged<String?> onProfileChanged;
  final VoidCallback onPick;
  final VoidCallback onClearImage;
  final VoidCallback? onCaptureScreen;
  final VoidCallback? onReadClipboard;
  final bool isReadingClipboard;
  final bool didReadClipboard;
  final VoidCallback? onGenerate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final app = ref.watch(appProvider);
    final header = GenerateImageShellHeaderCopy.forMode(
      isQuickReply: isQuickReply,
    );
    final readiness = GenerateAPIReadiness(
      config: app.config,
      hasAPIKey: hasUsableAPIKey(app.apiKey),
      capability: GenerateAPICapability.vision,
      isQuickReply: isQuickReply,
    );
    return GlassScaffold(
      title: title,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 76, 20, 96),
        children: [
          GlassCard(
            tint: Colors.cyanAccent.withValues(alpha: 0.07),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(header.icon, color: header.color),
                    const SizedBox(height: 10),
                    Text(header.title,
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 6),
                    Text(
                      header.detail,
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ]),
            ),
          ),
          const SizedBox(height: 16),
          APIReadinessCard(readiness: readiness),
          const SizedBox(height: 16),
          if (imagePath == null)
            GlassCard(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  children: [
                    const SizedBox(height: 12),
                    Icon(
                      isQuickReply
                          ? Icons.bolt_outlined
                          : Icons.add_photo_alternate_outlined,
                      size: 44,
                      color: Colors.cyanAccent,
                    ),
                    const SizedBox(height: 12),
                    Text(isQuickReply ? '等待当前截图' : '还没有选择截图',
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 8),
                    Text(
                      isQuickReply
                          ? '可以直接截取当前屏幕，也可以先截图复制到剪贴板后读取。'
                          : '选择一张聊天截图后，模型会提取语境并生成回复。',
                      textAlign: TextAlign.center,
                      style:
                          const TextStyle(color: Colors.white70, height: 1.35),
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      alignment: WrapAlignment.center,
                      children: [
                        if (isQuickReply)
                          FilledButton.icon(
                            onPressed:
                                readiness.isReady ? onCaptureScreen : null,
                            icon: const Icon(Icons.screenshot_monitor_outlined),
                            label: const Text('截取当前屏幕'),
                          ),
                        if (onReadClipboard != null)
                          GenerateImageClipboardButton(
                            isReadingClipboard: isReadingClipboard,
                            didReadClipboard: didReadClipboard,
                            isBlocked: isQuickReply && !readiness.isReady,
                            onPressed: onReadClipboard!,
                          ),
                        OutlinedButton.icon(
                          onPressed: onPick,
                          icon: const Icon(Icons.add_photo_alternate_outlined),
                          label: Text(isQuickReply ? '从相册选择' : '选择聊天截图'),
                        ),
                      ],
                    ),
                    if (isQuickReply) ...[
                      const SizedBox(height: 14),
                      Text(
                        'URL 入口可配合“截屏 -> 复制到剪贴板 -> 打开 aichathelper://quick-image”使用。',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.58),
                            fontSize: 12),
                      ),
                    ],
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            )
          else
            GlassCard(
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Image.file(File(imagePath!),
                          height: 340,
                          width: double.infinity,
                          fit: BoxFit.contain,
                          cacheWidth: 900,
                          filterQuality: FilterQuality.low),
                    ),
                    const SizedBox(height: 10),
                    Row(children: [
                      const Expanded(
                          child: Text('已选择截图',
                              style: TextStyle(color: Colors.white70))),
                      TextButton.icon(
                        onPressed: onPick,
                        icon: const Icon(Icons.photo_library_outlined),
                        label: const Text('更换'),
                      ),
                      if (onReadClipboard != null)
                        GenerateImageClipboardButton(
                          isReadingClipboard: isReadingClipboard,
                          didReadClipboard: didReadClipboard,
                          isBlocked: isQuickReply && !readiness.isReady,
                          compact: true,
                          onPressed: onReadClipboard!,
                        ),
                      TextButton.icon(
                        onPressed: onClearImage,
                        icon: const Icon(Icons.delete_outline),
                        label: const Text('删除'),
                      ),
                    ]),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 16),
          const SectionHeader('聊天风格', Icons.style_outlined),
          StylePicker(
              selected: style,
              styles: app.personalization.availableStyles,
              onChanged: (next) {
                app.clearFeedback(notify: false);
                onStyle(next);
              }),
          const SizedBox(height: 16),
          GlassTextField(
              controller: goal,
              label: '我的目标',
              hint: '想自然一点、想结束话题、想哄一下对方...',
              onChanged: (_) => app.clearFeedback()),
          const SizedBox(height: 18),
          PersonProfilePickerCard(
            title: '聊天对象',
            profiles: app.profiles,
            selectedProfileId: selectedProfileId,
            onChanged: (next) {
              app.clearFeedback(notify: false);
              onProfileChanged(next);
            },
            emptyText: '生成人物画像后，可以在这里指定聊天对象。',
            autoSummary: '自动模式会带入最近的人物库帮助判断对象。',
            selectedSummary: (profile) => '将按「${profile.displayLabel}」制定回复。',
          ),
          const SizedBox(height: 18),
          if (app.errorMessage != null) ErrorBanner(app.errorMessage!),
          FilledButton.icon(
            onPressed: canSubmitImageGeneration(
              readiness: readiness,
              isBusy: app.isBusy,
              imagePath: imagePath,
              onGenerate: onGenerate,
            )
                ? onGenerate
                : null,
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
}
