import 'package:flutter/material.dart';

import 'glass_widgets.dart';

class GenerateImageClipboardButton extends StatelessWidget {
  const GenerateImageClipboardButton({
    super.key,
    required this.isReadingClipboard,
    required this.didReadClipboard,
    required this.onPressed,
    this.isBlocked = false,
    this.compact = false,
  });

  final bool isReadingClipboard;
  final bool didReadClipboard;
  final VoidCallback onPressed;
  final bool isBlocked;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final effectiveOnPressed =
        isReadingClipboard || isBlocked ? null : onPressed;
    final icon =
        Icon(didReadClipboard ? Icons.check : Icons.content_paste_search);
    final label = Text(didReadClipboard
        ? '已读取'
        : compact
            ? '剪贴板'
            : '读取剪贴板截图');
    if (compact) {
      return TextButton.icon(
        onPressed: effectiveOnPressed,
        icon: icon,
        label: label,
      );
    }
    return OutlinedButton.icon(
      onPressed: effectiveOnPressed,
      icon: icon,
      label: label,
    );
  }
}

class GenerateImageShellHeaderCopy {
  const GenerateImageShellHeaderCopy({
    required this.title,
    required this.detail,
    required this.icon,
    required this.color,
  });

  final String title;
  final String detail;
  final IconData icon;
  final Color color;

  factory GenerateImageShellHeaderCopy.forMode({required bool isQuickReply}) {
    if (isQuickReply) {
      return const GenerateImageShellHeaderCopy(
        title: '用当前截图快速回复',
        detail: '截取当前聊天界面或读取剪贴板截图，生成后可直接复制回原聊天 App。',
        icon: Icons.bolt_outlined,
        color: Colors.orangeAccent,
      );
    }
    return const GenerateImageShellHeaderCopy(
      title: '从聊天截图生成回复',
      detail: '选择微信、QQ、小红书私信等聊天截图，模型只分析可见文字和聊天语境，生成可直接发送的候选回复。',
      icon: Icons.chat_bubble_outline,
      color: Colors.cyanAccent,
    );
  }
}

class MomentProfileHeaderCopy {
  const MomentProfileHeaderCopy({
    required this.title,
    required this.detail,
  });

  final String title;
  final String detail;

  static const defaultCopy = MomentProfileHeaderCopy(
    title: '用朋友圈完善人物库',
    detail: '上传朋友圈、小红书主页或社交动态截图，模型会基于文字和互动语境提取画像，不做人脸或真实身份识别。',
  );
}

class MomentProfileClipboardButton extends StatelessWidget {
  const MomentProfileClipboardButton({
    super.key,
    required this.isReadingClipboard,
    required this.didReadClipboard,
    required this.onPressed,
    this.compact = false,
  });

  final bool isReadingClipboard;
  final bool didReadClipboard;
  final VoidCallback onPressed;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final icon =
        Icon(didReadClipboard ? Icons.check : Icons.content_paste_search);
    final label = Text(didReadClipboard
        ? '已读取'
        : compact
            ? '剪贴板'
            : '读取剪贴板截图');
    final effectiveOnPressed = isReadingClipboard ? null : onPressed;
    if (compact) {
      return TextButton.icon(
        onPressed: effectiveOnPressed,
        icon: icon,
        label: label,
      );
    }
    return OutlinedButton.icon(
      onPressed: effectiveOnPressed,
      icon: icon,
      label: label,
    );
  }
}

class MomentProfileHeaderCard extends StatelessWidget {
  const MomentProfileHeaderCard({super.key});

  @override
  Widget build(BuildContext context) {
    const copy = MomentProfileHeaderCopy.defaultCopy;
    return GlassCard(
      tint: Colors.indigoAccent.withValues(alpha: 0.07),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Icon(Icons.person_search_outlined, color: Colors.indigoAccent),
          const SizedBox(height: 10),
          Text(copy.title,
              style:
                  const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text(copy.detail, style: const TextStyle(color: Colors.white70)),
        ]),
      ),
    );
  }
}
