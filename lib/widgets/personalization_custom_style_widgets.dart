import 'package:flutter/material.dart';

import '../core/models.dart';
import 'glass_widgets.dart';

class PersonalizationCustomStylesCard extends StatelessWidget {
  const PersonalizationCustomStylesCard({
    super.key,
    required this.customStyles,
    required this.styleName,
    required this.styleDescription,
    required this.styleRules,
    required this.canAddCustomStyle,
    required this.onStyleNameChanged,
    required this.onRemoveStyle,
    required this.onAddCustomStyle,
  });

  final List<ChatStyle> customStyles;
  final TextEditingController styleName;
  final TextEditingController styleDescription;
  final TextEditingController styleRules;
  final bool canAddCustomStyle;
  final ValueChanged<String> onStyleNameChanged;
  final ValueChanged<ChatStyle> onRemoveStyle;
  final VoidCallback onAddCustomStyle;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      tint: Colors.purple.withValues(alpha: 0.08),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const SectionHeader('自定义聊天风格', Icons.palette_outlined),
          if (customStyles.isEmpty)
            const EmptyState(
                icon: Icons.style_outlined,
                title: '还没有自定义风格',
                subtitle: '添加后会出现在首页、截图生成、文本生成和悬浮窗快捷回复里。')
          else
            ...customStyles.map(
              (style) => _CustomStyleRow(
                style: style,
                onRemove: () => onRemoveStyle(style),
              ),
            ),
          const Divider(height: 24),
          GlassTextField(
              controller: styleName,
              label: '风格名称',
              hint: '例如：我平时说话',
              onChanged: onStyleNameChanged),
          const SizedBox(height: 10),
          GlassTextField(
              controller: styleDescription,
              label: '风格描述',
              hint: '短句、轻松、不主动暴露需求感',
              minLines: 2,
              maxLines: 3),
          const SizedBox(height: 10),
          GlassTextField(
              controller: styleRules,
              label: '规则',
              hint: '每行一条',
              minLines: 3,
              maxLines: 6),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: canAddCustomStyle ? onAddCustomStyle : null,
            icon: const Icon(Icons.add_circle_outline),
            label: const Text('添加风格'),
          ),
        ]),
      ),
    );
  }
}

class _CustomStyleRow extends StatelessWidget {
  const _CustomStyleRow({
    required this.style,
    required this.onRemove,
  });

  final ChatStyle style;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white24),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: ListTile(
          leading: const Icon(Icons.format_quote),
          title: Text(style.name),
          subtitle: Text(
            '${style.description}\n${style.rules.join(' / ')}',
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: IconButton(
            tooltip: '删除 ${style.name}',
            icon: const Icon(Icons.delete_outline),
            onPressed: onRemove,
          ),
        ),
      ),
    );
  }
}
