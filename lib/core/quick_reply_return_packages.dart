part of 'quick_reply_flow.dart';

const _quickReplyReturnPackages = [
  _QuickReplyReturnPackage(
    packageName: 'com.tencent.mm',
    aliases: ['微信', 'wechat', 'weixin'],
  ),
  _QuickReplyReturnPackage(
    packageName: 'com.tencent.mobileqq',
    aliases: ['qq'],
  ),
  _QuickReplyReturnPackage(
    packageName: 'com.xingin.xhs',
    aliases: ['小红书', 'rednote', 'red note', 'little red book', 'xhs'],
  ),
  _QuickReplyReturnPackage(
    packageName: 'com.sina.weibo',
    aliases: ['微博', 'weibo'],
  ),
  _QuickReplyReturnPackage(
    packageName: 'com.ss.android.ugc.aweme',
    aliases: ['抖音', 'douyin'],
  ),
  _QuickReplyReturnPackage(
    packageName: 'com.whatsapp',
    aliases: ['whatsapp', 'whats app'],
  ),
  _QuickReplyReturnPackage(
    packageName: 'org.telegram.messenger',
    aliases: ['telegram', 'tg'],
  ),
  _QuickReplyReturnPackage(
    packageName: 'jp.naver.line.android',
    aliases: ['line'],
  ),
  _QuickReplyReturnPackage(
    packageName: 'com.alibaba.android.rimet',
    aliases: ['钉钉', 'dingtalk', 'ding talk'],
  ),
  _QuickReplyReturnPackage(
    packageName: 'com.ss.android.lark',
    aliases: ['飞书', 'lark', 'feishu'],
  ),
];

String? quickReplyReturnPackageForPlatform(String? platform) {
  final normalized = cleanNonEmptyText(platform)?.toLowerCase();
  if (normalized == null) return null;
  for (final entry in _quickReplyReturnPackages) {
    if (entry.matches(normalized)) return entry.packageName;
  }
  return null;
}

class _QuickReplyReturnPackage {
  const _QuickReplyReturnPackage({
    required this.packageName,
    required this.aliases,
  });

  final String packageName;
  final List<String> aliases;

  bool matches(String platform) {
    if (_matchesPackageName(platform)) return true;
    final compactPlatform = normalizedLooseKey(platform);
    return aliases.any((alias) {
      final normalizedAlias = alias.toLowerCase();
      return platform.contains(normalizedAlias) ||
          compactPlatform.contains(normalizedLooseKey(normalizedAlias));
    });
  }

  bool _matchesPackageName(String platform) {
    final normalizedPackage = packageName.toLowerCase();
    return platform == normalizedPackage ||
        platform.contains(normalizedPackage) ||
        platform.contains('package:$normalizedPackage');
  }
}
