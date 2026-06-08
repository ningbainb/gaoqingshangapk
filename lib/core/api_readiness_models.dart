part of 'models.dart';

enum GenerateAPICapability { text, vision }

class GenerateAPIReadiness {
  const GenerateAPIReadiness({
    required this.config,
    required this.hasAPIKey,
    required this.capability,
    this.isQuickReply = false,
  });

  final APIConfig config;
  final bool hasAPIKey;
  final GenerateAPICapability capability;
  final bool isQuickReply;

  bool get hasValidBaseURL => config.hasValidBaseUri;

  String? get textModelName => cleanPresentationText(config.textModelName);
  String? get visionModelName => cleanPresentationText(config.visionModelName);

  bool get hasTextModel => textModelName != null;
  bool get hasVisionModel => visionModelName != null;
  bool get hasUsableVisionModel {
    final modelName = visionModelName;
    return modelName != null && isUsableVisionChatModelId(modelName);
  }

  bool get hasMultimodalVisionModel {
    final modelName = visionModelName;
    return modelName != null &&
        isUsableVisionChatModelId(modelName) &&
        config.capability(modelName).isMultimodal;
  }

  bool get isReady {
    if (!hasAPIKey || !hasValidBaseURL || !hasTextModel) return false;
    return switch (capability) {
      GenerateAPICapability.text => true,
      GenerateAPICapability.vision => config.enableImageInput &&
          hasVisionModel &&
          hasUsableVisionModel &&
          hasMultimodalVisionModel,
    };
  }

  String get title => isReady ? 'API 已就绪' : '需要完成 API 设置';

  String get statusText => _generateAPIReadinessStatusText(this);
}

bool isUsableVisionChatModelId(String modelId) {
  final trimmed = cleanPresentationText(modelId);
  return trimmed != null &&
      !looksVoiceModelId(trimmed) &&
      !looksNonChatModelId(trimmed);
}

class APIStatusSnapshot {
  const APIStatusSnapshot({
    required this.config,
    required this.hasAPIKey,
  });

  final APIConfig config;
  final bool hasAPIKey;

  GenerateAPIReadiness get textReadiness => GenerateAPIReadiness(
        config: config,
        hasAPIKey: hasAPIKey,
        capability: GenerateAPICapability.text,
      );

  GenerateAPIReadiness get visionReadiness => GenerateAPIReadiness(
        config: config,
        hasAPIKey: hasAPIKey,
        capability: GenerateAPICapability.vision,
      );

  bool get isReady => textReadiness.isReady && visionReadiness.isReady;

  String get title {
    if (!hasAPIKey) return '还没有配置 API Key';
    if (isReady) return 'API 已就绪';
    if (!textReadiness.isReady) return '文本生成待完善';
    return '截图回复待完善';
  }

  String get subtitle {
    if (!textReadiness.isReady) return textReadiness.statusText;
    if (!visionReadiness.isReady) return visionReadiness.statusText;
    return visionReadiness.statusText;
  }
}
