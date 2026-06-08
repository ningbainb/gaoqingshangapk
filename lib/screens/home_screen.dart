import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/app_feedback.dart';
import '../core/app_provider.dart';
import '../core/app_routes.dart';
import '../core/app_state.dart';
import '../widgets/glass_scaffold.dart';
import '../widgets/glass_widgets.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final app = ref.watch(appProvider);
    return GlassScaffold(
      title: 'AI 回复助手',
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 76, 20, 96),
        children: [
          GlassCard(
            radius: 28,
            tint: Colors.cyan.withValues(alpha: 0.12),
            child: const Padding(
              padding: EdgeInsets.all(22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      GlassIcon(Icons.photo_library_outlined,
                          color: Color(0xFF2EAFFF), size: 54),
                      SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('不知道怎么回？',
                                style: TextStyle(
                                    fontSize: 30, fontWeight: FontWeight.w800)),
                            SizedBox(height: 6),
                            Text('上传聊天截图，让 AI 帮你生成自然回复，并持续完善人物库。',
                                style: TextStyle(
                                    color: Colors.white70, height: 1.35)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 18),
                  Wrap(spacing: 10, runSpacing: 10, children: [
                    GlassPill('截图回复'),
                    GlassPill('人物库记忆'),
                    GlassPill('悬浮窗截图'),
                  ]),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          APIStatusCard(
              config: app.config, hasKey: hasUsableAPIKey(app.apiKey)),
          const SizedBox(height: 18),
          const SectionHeader('开始生成', Icons.auto_awesome),
          GlassActionRow(
              title: '选择截图',
              subtitle: '视觉模型看图，提取聊天语境',
              icon: Icons.photo_library_outlined,
              color: Colors.blue,
              onTap: () => context.push(AppRoutes.image)),
          GlassActionRow(
              title: '粘贴文本',
              subtitle: '备用文本模式，省 token 更稳定',
              icon: Icons.chat_bubble_outline,
              color: Colors.greenAccent,
              onTap: () => context.push(AppRoutes.text)),
          GlassActionRow(
              title: '朋友圈画像',
              subtitle: '分析动态截图，自动完善人物库',
              icon: Icons.person_search_outlined,
              color: Colors.indigoAccent,
              onTap: () => context.push(AppRoutes.moments)),
          const SizedBox(height: 18),
          const SectionHeader('管理', Icons.inventory_2_outlined),
          GlassActionRow(
              title: '人物库',
              subtitle: '沉淀关系、偏好和避雷点',
              icon: Icons.badge_outlined,
              color: Colors.tealAccent,
              onTap: () => context.push(AppRoutes.people)),
          GlassActionRow(
              title: '历史记录',
              subtitle: '查看生成过的回复',
              icon: Icons.history,
              color: Colors.orangeAccent,
              onTap: () => context.push(AppRoutes.history)),
          GlassActionRow(
              title: 'API 设置',
              subtitle: '配置 OpenAI 兼容接口',
              icon: Icons.settings_outlined,
              color: Colors.white70,
              onTap: () => context.push(AppRoutes.api)),
          GlassActionRow(
              title: '设置中心',
              subtitle: '隐私、悬浮窗、外观和个性化',
              icon: Icons.tune,
              color: Colors.cyanAccent,
              onTap: () => context.push(AppRoutes.settings)),
          const SizedBox(height: 18),
          const SectionHeader('默认聊天风格', Icons.style_outlined),
          StylePicker(
            selected: app.defaultStyle,
            styles: app.personalization.availableStyles,
            onChanged: app.setDefaultStyle,
          ),
        ],
      ),
    );
  }
}
