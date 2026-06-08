import 'package:flutter/material.dart';

import '../core/models.dart';
import 'glass_widgets.dart';

class PrivacyInfoRow extends StatelessWidget {
  const PrivacyInfoRow({
    super.key,
    required this.title,
    required this.detail,
    required this.icon,
    required this.color,
  });

  final String title;
  final String detail;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      margin: const EdgeInsets.only(bottom: 10),
      tint: color.withValues(alpha: 0.06),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          GlassIcon(icon, color: color, size: 36),
          const SizedBox(width: 12),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text(detail,
                    style:
                        const TextStyle(color: Colors.white70, height: 1.35)),
              ])),
        ]),
      ),
    );
  }
}

class PrivacyRetentionCard extends StatelessWidget {
  const PrivacyRetentionCard({
    super.key,
    required this.snapshot,
    required this.onClear,
  });

  final PrivacySnapshot snapshot;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      tint: Colors.redAccent.withValues(alpha: 0.07),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            GlassIcon(Icons.delete_forever, color: Colors.redAccent, size: 38),
            SizedBox(width: 12),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text('清空范围',
                      style:
                          TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                  SizedBox(height: 4),
                  Text('仅清理本机保存的数据，不会撤回已经发送给你配置模型 API 的请求。',
                      style: TextStyle(color: Colors.white70)),
                ])),
          ]),
          const SizedBox(height: 12),
          _retentionLine(
              '历史记录', snapshot.historyLine, Icons.history, Colors.orangeAccent),
          _retentionLine('人物库', snapshot.profileLine, Icons.people_outline,
              Colors.tealAccent),
          _retentionLine(
              'API 配置',
              snapshot.apiLine,
              snapshot.hasAPIKey ? Icons.key : Icons.key_off_outlined,
              snapshot.hasAPIKey ? Colors.greenAccent : Colors.white70),
          const SizedBox(height: 12),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: snapshot.hasLocalData ? onClear : null,
            icon: const Icon(Icons.delete_forever),
            label: Text(snapshot.clearButtonLabel),
          ),
        ]),
      ),
    );
  }

  Widget _retentionLine(
      String title, String detail, IconData icon, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white24),
      ),
      child: Row(children: [
        Icon(icon, size: 17, color: color),
        const SizedBox(width: 8),
        Expanded(
            child: Text(title,
                style: const TextStyle(fontWeight: FontWeight.w800))),
        Flexible(
          child: Text(detail,
              textAlign: TextAlign.right,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white70, fontSize: 12)),
        ),
      ]),
    );
  }
}
