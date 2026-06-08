import 'package:flutter/material.dart';

import '../core/models.dart';
import 'glass_widgets.dart';

export 'personalization_custom_style_widgets.dart';

class PersonalizationSummaryCard extends StatelessWidget {
  const PersonalizationSummaryCard({
    super.key,
    required this.draft,
    required this.colloquial,
    required this.memory,
    required this.adaptive,
    this.saveMessage,
  });

  final ReplyPersonalizationSettings draft;
  final bool colloquial;
  final bool memory;
  final bool adaptive;
  final String? saveMessage;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      tint: Colors.cyan.withValues(alpha: 0.10),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const GlassIcon(
              Icons.person_pin_circle_outlined,
              color: Colors.cyanAccent,
              size: 42,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('让回复更像你',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 4),
                    Text('这些设置会进入截图、文本和快捷回复的生成提示。',
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.68),
                            height: 1.35)),
                  ]),
            ),
          ]),
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, children: [
            GlassPill(colloquial ? '口语化' : '稳重表达'),
            GlassPill(memory ? '记忆开启' : '无记忆'),
            GlassPill(adaptive ? '自适应' : '固定风格'),
          ]),
          const SizedBox(height: 10),
          Text(draft.enabledFeatureSummary,
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.72),
                  fontWeight: FontWeight.w700,
                  fontSize: 12)),
          if (saveMessage != null) ...[
            const SizedBox(height: 8),
            Row(children: [
              const Icon(Icons.check_circle_outline,
                  color: Colors.greenAccent, size: 16),
              const SizedBox(width: 6),
              Text(saveMessage!,
                  style: const TextStyle(
                      color: Colors.greenAccent, fontWeight: FontWeight.w700)),
            ]),
          ],
        ]),
      ),
    );
  }
}

class PersonalizationProfileCard extends StatelessWidget {
  const PersonalizationProfileCard({
    super.key,
    required this.gender,
    required this.age,
    required this.onGenderChanged,
    required this.onAgeChanged,
  });

  final UserGender gender;
  final TextEditingController age;
  final ValueChanged<UserGender> onGenderChanged;
  final ValueChanged<String> onAgeChanged;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      tint: Colors.blue.withValues(alpha: 0.08),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const SectionHeader('我的资料', Icons.person_outline),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: UserGender.values
                .map((item) => ChoiceChip(
                      label: Text(item.title),
                      selected: gender == item,
                      onSelected: (_) => onGenderChanged(item),
                    ))
                .toList(),
          ),
          const SizedBox(height: 12),
          GlassTextField(
              controller: age,
              label: '我的年龄',
              hint: '例如：22、95 后、大学生',
              onChanged: onAgeChanged),
        ]),
      ),
    );
  }
}

class PersonalizationSwitchesCard extends StatelessWidget {
  const PersonalizationSwitchesCard({
    super.key,
    required this.colloquial,
    required this.memory,
    required this.adaptive,
    required this.onColloquialChanged,
    required this.onMemoryChanged,
    required this.onAdaptiveChanged,
  });

  final bool colloquial;
  final bool memory;
  final bool adaptive;
  final ValueChanged<bool> onColloquialChanged;
  final ValueChanged<bool> onMemoryChanged;
  final ValueChanged<bool> onAdaptiveChanged;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      tint: Colors.green.withValues(alpha: 0.08),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const SectionHeader('生成开关', Icons.tune_outlined),
          _PersonalizationToggle(
              icon: Icons.chat_bubble_outline,
              title: '口语化表达',
              subtitle: '更像手机聊天，不写作文、不像客服',
              value: colloquial,
              onChanged: onColloquialChanged),
          _PersonalizationToggle(
              icon: Icons.psychology_alt_outlined,
              title: '储存对话记忆',
              subtitle: '使用本机历史和采用过的回复作为记忆',
              value: memory,
              onChanged: onMemoryChanged),
          _PersonalizationToggle(
              icon: Icons.auto_awesome,
              title: '自适应我的风格',
              subtitle: '参考你最近复制采用的回复长度和语气',
              value: adaptive,
              onChanged: onAdaptiveChanged),
        ]),
      ),
    );
  }
}

class PersonalizationMemoryCard extends StatelessWidget {
  const PersonalizationMemoryCard({
    super.key,
    required this.notes,
    required this.onNotesChanged,
  });

  final TextEditingController notes;
  final ValueChanged<String> onNotesChanged;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      tint: Colors.orange.withValues(alpha: 0.08),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const SectionHeader('手动记忆', Icons.note_alt_outlined),
          Text('可以写你的常用说话习惯、禁忌、关系边界或固定人设。',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.70))),
          const SizedBox(height: 4),
          Text('例：我平时不爱连续追问；暧昧也要轻一点；不要替我说太满。',
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.52), fontSize: 12)),
          const SizedBox(height: 12),
          GlassTextField(
              controller: notes,
              label: '手动记忆',
              hint: '希望 AI 长期记住的表达偏好',
              minLines: 4,
              maxLines: 8,
              onChanged: onNotesChanged),
        ]),
      ),
    );
  }
}

class _PersonalizationToggle extends StatelessWidget {
  const _PersonalizationToggle({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white24),
      ),
      child: Row(children: [
        GlassIcon(icon,
            color: value ? Colors.greenAccent : Colors.white54, size: 34),
        const SizedBox(width: 12),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 3),
          Text(subtitle,
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.66), fontSize: 12)),
        ])),
        Switch(value: value, onChanged: onChanged),
      ]),
    );
  }
}
