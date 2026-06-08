import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/app_feedback.dart';
import '../core/app_provider.dart';
import '../core/app_state.dart';
import '../core/models.dart';
import '../widgets/glass_scaffold.dart';
import '../widgets/glass_widgets.dart';
import '../widgets/privacy_widgets.dart';
import '../widgets/settings_cards.dart';

class PrivacyScreen extends ConsumerStatefulWidget {
  const PrivacyScreen({super.key});

  @override
  ConsumerState<PrivacyScreen> createState() => _PrivacyScreenState();
}

class _PrivacyScreenState extends ConsumerState<PrivacyScreen> {
  bool didClearData = false;

  @override
  Widget build(BuildContext context) {
    final app = ref.watch(appProvider);
    final snapshot = PrivacySnapshot(
      hasAPIKey: hasUsableAPIKey(app.apiKey),
      hasCustomConfig: !app.config.hasDefaultValues,
      historyCount: app.history.length,
      profileCount: app.profiles.length,
    );
    return GlassScaffold(
      title: '隐私与数据',
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 76, 20, 96),
        children: [
          GlassCard(
            tint: Colors.lightBlueAccent.withValues(alpha: 0.08),
            child: const Padding(
              padding: EdgeInsets.all(18),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GlassIcon(Icons.lock_outline,
                        color: Colors.lightBlueAccent, size: 46),
                    SizedBox(height: 12),
                    Text('数据只为生成回复服务',
                        style: TextStyle(
                            fontSize: 22, fontWeight: FontWeight.w800)),
                    SizedBox(height: 8),
                    Text(
                      '截图由你主动选择或点击悬浮窗后处理；App 不会静默读取其他应用界面，也不会保存原始截图。',
                      style: TextStyle(color: Colors.white70, height: 1.45),
                    ),
                  ]),
            ),
          ),
          const SizedBox(height: 18),
          const SectionHeader('处理方式', Icons.checklist_outlined),
          const PrivacyInfoRow(
              title: '图片只临时上传',
              detail: '聊天截图和朋友圈截图会发送到你配置的视觉模型 API，用完不写入历史。',
              icon: Icons.photo_outlined,
              color: Colors.lightBlueAccent),
          const PrivacyInfoRow(
              title: '不接入本地 OCR',
              detail: 'App 不做本地文字识别；开启两步视觉时，截图文字只经你配置的视觉模型用于本次生成，不长期缓存。',
              icon: Icons.visibility_off_outlined,
              color: Colors.purpleAccent),
          const PrivacyInfoRow(
              title: 'Key 留在本机',
              detail: 'API Key 存在本机安全存储，不上传到开发者服务器。',
              icon: Icons.key_outlined,
              color: Colors.greenAccent),
          const PrivacyInfoRow(
              title: '人物库不识别人脸',
              detail: '只保存聊天语境、可见昵称、偏好和边界，不根据头像或面部判断身份。',
              icon: Icons.person_pin_outlined,
              color: Colors.orangeAccent),
          const SizedBox(height: 18),
          const SectionHeader('本地保留', Icons.storage_outlined),
          Row(children: [
            Expanded(
                child: SettingsMetricCard(
                    title: '历史记录',
                    value: snapshot.historyMetricValue,
                    icon: Icons.history,
                    color: Colors.orangeAccent)),
            const SizedBox(width: 10),
            Expanded(
                child: SettingsMetricCard(
                    title: '人物画像',
                    value: snapshot.profileMetricValue,
                    icon: Icons.person_outline,
                    color: Colors.tealAccent)),
          ]),
          const SizedBox(height: 14),
          PrivacyRetentionCard(
            snapshot: snapshot,
            onClear: () => _confirmClear(context, app),
          ),
          if (didClearData) ...[
            const SizedBox(height: 12),
            const SuccessBanner(privacyClearSuccessMessage),
          ],
        ],
      ),
    );
  }

  Future<void> _confirmClear(BuildContext context, AppController app) async {
    final confirmed = await showConfirmationDialog(
      context,
      title: '清空本地数据？',
      message: '这会删除本机历史、人物库、API Key，并恢复默认 API 配置。已经发送给模型 API 的请求无法撤回。',
      confirmLabel: '清空',
    );
    if (confirmed) {
      await app.clearAllLocalData();
      if (mounted) setState(() => didClearData = true);
    }
  }
}
