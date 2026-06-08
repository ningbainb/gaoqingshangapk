import 'app_feedback.dart';
import 'api_config_rules.dart';
import 'models.dart';
import 'presentation_text_helpers.dart';

class APISettingsActionState {
  const APISettingsActionState({
    required this.normalizedDraftConfig,
    required this.hasUsableKey,
    required this.canFetchModels,
    required this.canRunConnectionTest,
    required this.canTestVisionModel,
  });

  final APIConfig normalizedDraftConfig;
  final bool hasUsableKey;
  final bool canFetchModels;
  final bool canRunConnectionTest;
  final bool canTestVisionModel;
}

APIConfig apiSettingsDraftConfigFrom({
  required APIConfig source,
  required String baseURL,
  required String visionModelName,
  required String textModelName,
  required Map<String, ModelCapability> modelCapabilities,
  required double imageMaxWidth,
  required double imageCompressionQuality,
  required bool enableImageInput,
  required bool enableTwoStepVision,
  required double temperature,
  required double maxTokens,
  required double timeout,
}) {
  return source.copyWith(
    baseURL: baseURL,
    visionModelName: visionModelName,
    textModelName: textModelName,
    modelCapabilities: modelCapabilities,
    imageMaxWidth: imageMaxWidth,
    imageCompressionQuality: imageCompressionQuality,
    enableImageInput: enableImageInput,
    enableTwoStepVision: enableTwoStepVision,
    temperature: temperature,
    maxTokens: maxTokens.round(),
    timeout: timeout.round(),
  );
}

APISettingsActionState apiSettingsActionState({
  required APIConfig draftConfig,
  required String apiKey,
  required bool isFetchingModels,
  required bool isTestingConnection,
  required bool isTestingVision,
}) {
  final normalizedDraftConfig = normalizeApiConfig(draftConfig);
  final hasUsableKey = hasUsableAPIKey(apiKey);
  final hasUsableTextModel =
      cleanPresentationText(normalizedDraftConfig.textModelName) != null;
  final hasUsableBaseUrl = normalizedDraftConfig.hasValidBaseUri;
  final hasUsableVisionModel =
      isUsableVisionChatModelId(normalizedDraftConfig.visionModelName);
  final canRunConnectionTest = !isFetchingModels &&
      !isTestingConnection &&
      !isTestingVision &&
      hasUsableKey &&
      hasUsableBaseUrl &&
      hasUsableTextModel;
  return APISettingsActionState(
    normalizedDraftConfig: normalizedDraftConfig,
    hasUsableKey: hasUsableKey,
    canFetchModels: !isFetchingModels &&
        !isTestingConnection &&
        !isTestingVision &&
        hasUsableKey &&
        hasUsableBaseUrl,
    canRunConnectionTest: canRunConnectionTest,
    canTestVisionModel: canRunConnectionTest &&
        normalizedDraftConfig.enableImageInput &&
        hasUsableVisionModel &&
        normalizedDraftConfig
            .capability(normalizedDraftConfig.visionModelName)
            .isMultimodal,
  );
}

Map<String, ModelCapability> apiSettingsDraftCapabilitiesWith(
  Map<String, ModelCapability> current,
  String modelId, {
  bool? isMultimodal,
  bool? isReasoning,
}) {
  final trimmed = cleanPresentationText(modelId);
  if (trimmed == null) return current;
  final next = Map<String, ModelCapability>.from(current);
  final capability = APIConfig.lookupCapability(next, trimmed);
  next[trimmed] = ModelCapability(
    isMultimodal: isMultimodal ?? capability.isMultimodal,
    isReasoning: isReasoning ?? capability.isReasoning,
  );
  return next;
}
