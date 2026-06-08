import 'package:flutter/material.dart';

import 'glass_widgets.dart';

class FloatingGuideHeroCard extends StatelessWidget {
  const FloatingGuideHeroCard({super.key});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      radius: 28,
      tint: Colors.cyanAccent.withValues(alpha: 0.10),
      child: const Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              GlassIcon(Icons.control_camera,
                  color: Colors.cyanAccent, size: 52),
              SizedBox(width: 14),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('AI Reply 悬浮窗',
                          style: TextStyle(
                              fontSize: 24, fontWeight: FontWeight.w900)),
                      SizedBox(height: 7),
                      Text('在聊天 App 上方轻触 AI 按钮，读取当前屏幕并生成可复制回复。',
                          style:
                              TextStyle(color: Colors.white70, height: 1.35)),
                    ]),
              ),
            ]),
            SizedBox(height: 16),
            Wrap(spacing: 8, runSpacing: 8, children: [
              GlassPill('点击才截图'),
              GlassPill('无障碍增强'),
              GlassPill('复制后返回聊天'),
            ]),
          ],
        ),
      ),
    );
  }
}

class FloatingPreviewCard extends StatelessWidget {
  const FloatingPreviewCard({super.key, required this.canStartFloating});

  final bool canStartFloating;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      tint: Colors.lightBlueAccent.withValues(alpha: 0.08),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                gradient: const LinearGradient(colors: [
                  Color(0xFF0F766E),
                  Color(0xFF38BDF8),
                ]),
                border: Border.all(color: Colors.white54),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withValues(alpha: 0.20),
                      blurRadius: 18,
                      offset: const Offset(0, 10)),
                ],
              ),
              child: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('AI',
                        style: TextStyle(
                            fontWeight: FontWeight.w900, fontSize: 17)),
                    Text('回复',
                        style: TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 10)),
                  ]),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(canStartFloating ? '可以启动' : '等待授权',
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 4),
                    Text(
                        canStartFloating
                            ? '权限和模型已就绪，悬浮按钮会保持在聊天界面上方。'
                            : '补齐 API、悬浮窗和无障碍增强后即可使用。',
                        style: const TextStyle(
                            color: Colors.white70, height: 1.35)),
                  ]),
            ),
          ]),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF0A1424).withValues(alpha: 0.72),
              borderRadius: BorderRadius.circular(18),
              border:
                  Border.all(color: Colors.cyanAccent.withValues(alpha: 0.24)),
            ),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const GlassPill('AI 分析中'),
                const Spacer(),
                Text('快捷回复面板',
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.72),
                        fontWeight: FontWeight.w800,
                        fontSize: 12)),
              ]),
              const SizedBox(height: 10),
              const _PreviewReplyLine('收到，我晚点认真看一下。', highlighted: true),
              const SizedBox(height: 7),
              const _PreviewReplyLine('可以，等你方便的时候聊。'),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _PreviewReplyLine extends StatelessWidget {
  const _PreviewReplyLine(this.text, {this.highlighted = false});

  final String text;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: highlighted ? const Color(0xFFE0FFF7) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: highlighted ? const Color(0xFF5EEAD4) : Colors.white70),
      ),
      child: Text(text,
          style: TextStyle(
              color: const Color(0xFF082F49),
              fontWeight: highlighted ? FontWeight.w900 : FontWeight.w700)),
    );
  }
}

class FloatingGuideStep extends StatelessWidget {
  const FloatingGuideStep({
    super.key,
    required this.number,
    required this.title,
    required this.description,
  });

  final String number;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          CircleAvatar(
              radius: 16,
              backgroundColor: Colors.cyanAccent.withValues(alpha: 0.16),
              child: Text(number,
                  style: const TextStyle(fontWeight: FontWeight.w900))),
          const SizedBox(width: 12),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text(description,
                  style: const TextStyle(color: Colors.white70, height: 1.35)),
            ]),
          ),
        ]),
      ),
    );
  }
}
