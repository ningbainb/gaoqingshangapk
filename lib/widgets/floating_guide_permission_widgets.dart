import 'package:flutter/material.dart';

import '../core/models.dart';
import '../core/platform_bridge.dart';
import 'glass_widgets.dart';

class FloatingPermissionCard extends StatelessWidget {
  const FloatingPermissionCard({
    super.key,
    required this.refreshing,
    required this.permissionError,
    required this.overlay,
    required this.notification,
    required this.accessibility,
    required this.accessibilityConnected,
    required this.readiness,
    required this.onApiSettings,
    required this.onOverlaySettings,
    required this.onNotificationPermission,
    required this.onAccessibilitySettings,
    required this.onRefresh,
  });

  final bool refreshing;
  final String? permissionError;
  final bool overlay;
  final bool notification;
  final bool accessibility;
  final bool accessibilityConnected;
  final GenerateAPIReadiness readiness;
  final VoidCallback onApiSettings;
  final VoidCallback onOverlaySettings;
  final VoidCallback onNotificationPermission;
  final VoidCallback onAccessibilitySettings;
  final VoidCallback onRefresh;

  String get _accessibilityValue {
    if (accessibilityConnected) return '已连接';
    if (accessibility) return '已开启，正在连接';
    return '悬浮截图必需';
  }

  IconData get _accessibilityIcon {
    if (accessibilityConnected) return Icons.check_circle;
    if (accessibility) return Icons.sync;
    return Icons.error_outline;
  }

  Color get _accessibilityColor {
    if (accessibilityConnected) return Colors.greenAccent;
    if (accessibility) return Colors.amber;
    return Colors.orangeAccent;
  }

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(refreshing ? '正在检查权限...' : '准备状态',
              style:
                  const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          if (permissionError != null) ...[
            Text(permissionError!,
                style:
                    const TextStyle(color: Colors.orangeAccent, height: 1.35)),
            const SizedBox(height: 12),
          ],
          ReadinessRow(
              title: '悬浮窗权限',
              value: overlay ? '已授权' : '未授权',
              icon: overlay ? Icons.check_circle : Icons.error_outline,
              color: overlay ? Colors.greenAccent : Colors.orangeAccent),
          ReadinessRow(
              title: '通知权限',
              value: notification ? '已允许' : '建议开启',
              icon: notification
                  ? Icons.notifications_active_outlined
                  : Icons.notifications_off_outlined,
              color: notification ? Colors.greenAccent : Colors.orangeAccent),
          ReadinessRow(
              title: '无障碍增强',
              value: _accessibilityValue,
              icon: _accessibilityIcon,
              color: _accessibilityColor),
          if (accessibility && !accessibilityConnected) ...[
            const SizedBox(height: 4),
            const Text(
              '无障碍服务已在系统设置中开启，正在等待连接。如果长时间未连接，请尝试关闭后重新开启。',
              style: TextStyle(color: Colors.amber, fontSize: 12, height: 1.35),
            ),
            const SizedBox(height: 8),
          ],
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, children: [
            if (!readiness.isReady)
              OutlinedButton.icon(
                onPressed: onApiSettings,
                icon: const Icon(Icons.settings_outlined),
                label: const Text('完善 API 设置'),
              ),
            FilledButton.icon(
              onPressed: onOverlaySettings,
              icon: const Icon(Icons.open_in_new),
              label: Text(overlay ? '查看悬浮窗权限' : '授权悬浮窗'),
            ),
            if (!notification)
              OutlinedButton.icon(
                onPressed: onNotificationPermission,
                icon: const Icon(Icons.notifications_active_outlined),
                label: const Text('开启通知权限'),
              ),
            OutlinedButton.icon(
              onPressed: onAccessibilitySettings,
              icon: const Icon(Icons.accessibility),
              label: Text(accessibility ? '查看无障碍服务' : '开启无障碍增强'),
            ),
            OutlinedButton.icon(
                onPressed: onRefresh,
                icon: const Icon(Icons.refresh),
                label: const Text('刷新状态')),
          ]),
        ]),
      ),
    );
  }
}

class FloatingQuickUrlCard extends StatelessWidget {
  const FloatingQuickUrlCard({
    super.key,
    required this.didCopyQuickUrl,
    required this.onCopy,
    required this.onTest,
  });

  final bool didCopyQuickUrl;
  final VoidCallback onCopy;
  final VoidCallback onTest;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      tint: Colors.blueAccent.withValues(alpha: 0.08),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('备用 URL 入口',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          const Text(
            '如果想用系统快捷方式、自动化或第三方启动器，可以配置：截屏 -> 复制到剪贴板 -> 打开 URL。',
            style: TextStyle(color: Colors.white70, height: 1.35),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white24),
            ),
            child: Row(children: [
              const Expanded(
                child: Text(
                  quickShortcutUrl,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontFamily: 'monospace'),
                ),
              ),
              const SizedBox(width: 8),
              TextButton.icon(
                onPressed: onCopy,
                icon: Icon(didCopyQuickUrl ? Icons.check : Icons.copy),
                label: Text(didCopyQuickUrl ? '已复制' : '复制'),
              ),
            ]),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: onTest,
            icon: const Icon(Icons.play_circle_outline),
            label: const Text('测试快捷入口'),
          ),
        ]),
      ),
    );
  }
}

class FloatingApiReadinessDetailsCard extends StatelessWidget {
  const FloatingApiReadinessDetailsCard({super.key, required this.readiness});

  final GenerateAPIReadiness readiness;

  @override
  Widget build(BuildContext context) {
    final ready = readiness.isReady;
    final color = ready ? Colors.greenAccent : Colors.orangeAccent;
    return GlassCard(
      tint: color.withValues(alpha: 0.10),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            GlassIcon(
                ready ? Icons.verified_outlined : Icons.warning_amber_rounded,
                color: color,
                size: 38),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(ready ? '快捷回复配置可用' : '快捷回复配置还差一步',
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 5),
                    Text(readiness.statusText,
                        style: const TextStyle(
                            color: Colors.white70, height: 1.35)),
                  ]),
            ),
          ]),
          const SizedBox(height: 12),
          ReadinessRow(
              title: readiness.hasAPIKey ? 'API Key' : 'API Key',
              value: readiness.hasAPIKey ? '已填写' : '未填写',
              icon: readiness.hasAPIKey ? Icons.key : Icons.key_off,
              color: readiness.hasAPIKey
                  ? Colors.greenAccent
                  : Colors.orangeAccent),
          ReadinessRow(
              title: '截图模式',
              value: readiness.config.enableImageInput ? '已开启' : '未开启',
              icon: readiness.config.enableImageInput
                  ? Icons.photo_camera_back_outlined
                  : Icons.image_not_supported_outlined,
              color: readiness.config.enableImageInput
                  ? Colors.greenAccent
                  : Colors.orangeAccent),
          ReadinessRow(
              title: '视觉模型',
              value: readiness.hasMultimodalVisionModel ? '多模态可用' : '需标记多模态',
              icon: readiness.hasMultimodalVisionModel
                  ? Icons.visibility_outlined
                  : Icons.visibility_off_outlined,
              color: readiness.hasMultimodalVisionModel
                  ? Colors.greenAccent
                  : Colors.orangeAccent),
        ]),
      ),
    );
  }
}

class ReadinessRow extends StatelessWidget {
  const ReadinessRow({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String title;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 8),
        Expanded(
            child: Text(title,
                style: const TextStyle(fontWeight: FontWeight.w700))),
        Text(value,
            style: TextStyle(color: color, fontWeight: FontWeight.w800)),
      ]),
    );
  }
}
