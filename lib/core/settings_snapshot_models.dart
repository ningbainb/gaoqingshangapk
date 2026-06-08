part of 'models.dart';

class SettingsSnapshot {
  const SettingsSnapshot({
    required this.hasAPIKey,
    required this.config,
    required this.historyCount,
    required this.profileCount,
    required this.personalization,
    required this.defaultStyleName,
  });

  final bool hasAPIKey;
  final APIConfig config;
  final int historyCount;
  final int profileCount;
  final ReplyPersonalizationSettings personalization;
  final String defaultStyleName;

  int get safeHistoryCount => _safeLocalDataCount(historyCount);

  int get safeProfileCount => _safeLocalDataCount(profileCount);

  bool get hasValidBaseURL => config.hasValidBaseUri;

  GenerateAPIReadiness get textReadiness => GenerateAPIReadiness(
        config: config,
        hasAPIKey: hasAPIKey,
        capability: GenerateAPICapability.text,
      );

  bool get isAPIReady => textReadiness.isReady;

  GenerateAPIReadiness get shortcutReadiness => GenerateAPIReadiness(
        config: config,
        hasAPIKey: hasAPIKey,
        capability: GenerateAPICapability.vision,
        isQuickReply: true,
      );

  bool get isShortcutReady => shortcutReadiness.isReady;

  bool get isOverviewReady => isAPIReady && isShortcutReady;

  String get statusTitle {
    if (!hasAPIKey) return '需要配置 API';
    if (!hasValidBaseURL) return 'API 地址需要修正';
    if (!isAPIReady) return 'API 设置待完善';
    if (!isShortcutReady) return '截图回复待完善';
    return 'API 已就绪';
  }

  String get statusSubtitle {
    if (!hasAPIKey) return '填写接口地址和 Key 后才能生成回复。';
    if (!hasValidBaseURL) return 'Base URL 格式不正确，修正后才能测试连接。';
    if (!isAPIReady) return textReadiness.statusText;
    if (!isShortcutReady) return shortcutReadiness.statusText;
    return '可继续生成截图回复、文本回复和人物画像。';
  }

  String get visionLine {
    return shortcutReadiness.isReady
        ? '视觉模型：${shortcutReadiness.visionModelName}'
        : shortcutReadiness.statusText;
  }

  String get textLine => textReadiness.isReady
      ? '文本模型：${textReadiness.textModelName}'
      : textReadiness.statusText;

  String get defaultStyleLine => '默认风格：$defaultStyleName';

  String get historyMetricValue => _localDataMetricValue(safeHistoryCount);

  String get profileMetricValue => _localDataMetricValue(safeProfileCount);

  String get personalizationLine => _settingsPersonalizationLine(
        personalization,
      );

  String get nextActionTitle {
    if (!isAPIReady) return '下一步：完成接口配置';
    if (!isShortcutReady) return '下一步：完善截图回复配置';
    return '下一步：测试快捷回复';
  }

  String get nextActionDescription {
    if (!hasAPIKey || !hasValidBaseURL) {
      return '先填入 OpenAI 兼容接口和 Key，再拉取模型列表并标记能力。';
    }
    if (!isAPIReady) {
      return textReadiness.statusText;
    }
    if (!isShortcutReady) {
      return shortcutReadiness.statusText;
    }
    return '接口已可用，可以打开悬浮窗截图入口，验证复制后回聊天 App 粘贴的流程。';
  }
}

String _settingsPersonalizationLine(ReplyPersonalizationSettings settings) {
  final enabled = _personalizationFeatureLabels(settings);
  return enabled.isEmpty ? '个性化回复：未开启' : '个性化回复：${enabled.join(' · ')}';
}
