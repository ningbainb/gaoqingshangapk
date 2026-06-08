import 'api_base_url.dart';
import 'app_feedback.dart';
import 'api_failure_messages.dart';
import 'api_service.dart';
import 'models.dart';
import 'presentation_text_helpers.dart';
import 'text_cleaning.dart';

void validateApiConfig(APIConfig config) {
  if (!config.hasValidBaseUri) {
    throw AppException(apiBaseUrlInvalidMessage);
  }
  if (cleanPresentationText(config.textModelName) == null) {
    throw AppException(textModelRequiredMessage);
  }
}

void validateModelFetchSource(APIConfig config, String key) {
  if (!config.hasValidBaseUri) {
    throw AppException(apiBaseUrlInvalidMessage);
  }
  if (!hasUsableAPIKey(key)) {
    throw AppException(apiKeyRequiredMessage);
  }
}

void validateVisionTestConfig(APIConfig config) {
  final visionModelName = cleanPresentationText(config.visionModelName);
  if (visionModelName == null) {
    throw AppException(visionModelRequiredMessage);
  }
  if (!config.enableImageInput) {
    throw AppException('请先启用截图模式，再测试视觉模型。');
  }
  if (!isUsableVisionChatModelId(visionModelName)) {
    throw AppException(visionChatModelRequiredMessage);
  }
  if (!config.capability(visionModelName).isMultimodal) {
    throw AppException('请先将视觉模型标记为多模态，再测试视觉模型。');
  }
}

APIConfig normalizeApiConfig(APIConfig config) {
  final capabilities = <String, ModelCapability>{};
  for (final entry in config.modelCapabilities.entries) {
    final modelId = cleanPresentationText(entry.key);
    if (modelId == null) continue;
    mergeCapability(capabilities, modelId, entry.value);
  }
  return config.copyWith(
    baseURL: _normalizedApiConfigBaseUrl(config.baseURL),
    visionModelName: cleanPresentationText(config.visionModelName) ?? '',
    textModelName: cleanPresentationText(config.textModelName) ?? '',
    modelCapabilities: capabilities,
    imageMaxWidth: config.imageMaxWidth
        .clamp(
          APIConfig.imageMaxWidthMin,
          APIConfig.imageMaxWidthMax,
        )
        .toDouble(),
    imageCompressionQuality: config.imageCompressionQuality
        .clamp(
          APIConfig.imageCompressionQualityMin,
          APIConfig.imageCompressionQualityMax,
        )
        .toDouble(),
    temperature: config.temperature
        .clamp(
          APIConfig.temperatureMin,
          APIConfig.temperatureMax,
        )
        .toDouble(),
    maxTokens: config.maxTokens
        .clamp(
          APIConfig.maxTokensMin,
          APIConfig.maxTokensMax,
        )
        .toInt(),
    timeout: config.timeout
        .clamp(
          APIConfig.timeoutMin,
          APIConfig.timeoutMax,
        )
        .toInt(),
  );
}

String apiConfigSourceFingerprint(APIConfig config, String apiKey) {
  final base = _normalizedApiConfigBaseUrl(config.baseURL);
  return '$base|${cleanAPIKeyInput(apiKey) ?? ''}';
}

String _normalizedApiConfigBaseUrl(String value) {
  return canonicalApiBaseUrl(value) ?? cleanNonEmptyText(value) ?? '';
}
