part of 'models.dart';

APIConfig _apiConfigFromJson(Map<String, dynamic> json) {
  final sources = _apiConfigSources(json);
  final capabilities =
      Map<String, ModelCapability>.from(APIConfig.defaults.modelCapabilities);
  _mergeModelCapabilities(
    capabilities,
    _firstValueFromSources(sources, const [
      'modelCapabilities',
      'capabilities',
      'modelCapabilityMap',
      'modelMetadata',
    ]),
  );
  final baseURL = _apiConfigBaseUrlFromJson(sources);
  return APIConfig(
    baseURL: baseURL,
    visionModelName:
        _firstCleanFromSources(sources, _apiConfigVisionModelKeys) ??
            APIConfig.defaults.visionModelName,
    textModelName: _firstCleanFromSources(sources, _apiConfigTextModelKeys) ??
        APIConfig.defaults.textModelName,
    modelCapabilities: capabilities,
    enableImageInput:
        _boolValue(_firstValueFromSources(sources, _apiConfigImageInputKeys)) ??
            APIConfig.defaults.enableImageInput,
    enableTwoStepVision: _boolValue(
          _firstValueFromSources(sources, _apiConfigTwoStepVisionKeys),
        ) ??
        APIConfig.defaults.enableTwoStepVision,
    imageMaxWidth: _boundedDouble(
      _firstValueFromSources(sources, _apiConfigImageMaxWidthKeys),
      fallback: APIConfig.defaults.imageMaxWidth,
      min: APIConfig.imageMaxWidthMin,
      max: APIConfig.imageMaxWidthMax,
    ),
    imageCompressionQuality: _boundedDouble(
      _firstValueFromSources(
        sources,
        _apiConfigImageCompressionQualityKeys,
      ),
      fallback: APIConfig.defaults.imageCompressionQuality,
      min: APIConfig.imageCompressionQualityMin,
      max: APIConfig.imageCompressionQualityMax,
    ),
    temperature: _boundedDouble(
      _firstValueFromSources(sources, _apiConfigTemperatureKeys),
      fallback: APIConfig.defaults.temperature,
      min: APIConfig.temperatureMin,
      max: APIConfig.temperatureMax,
    ),
    maxTokens: _boundedInt(
      _firstValueFromSources(sources, _apiConfigMaxTokensKeys),
      fallback: APIConfig.defaults.maxTokens,
      min: APIConfig.maxTokensMin,
      max: APIConfig.maxTokensMax,
    ),
    timeout: _boundedInt(
      _firstValueFromSources(sources, _apiConfigTimeoutKeys),
      fallback: APIConfig.defaults.timeout,
      min: APIConfig.timeoutMin,
      max: APIConfig.timeoutMax,
    ),
  );
}

String _apiConfigBaseUrlFromJson(List<Map<String, dynamic>> sources) {
  final baseURL = _firstCleanFromSources(sources, _apiConfigBaseUrlKeys);
  if (baseURL == null) return APIConfig.defaults.baseURL;
  return canonicalApiBaseUrl(baseURL) ?? baseURL;
}

List<Map<String, dynamic>> _apiConfigSources(Map<String, dynamic> json) =>
    _containerSources(json, _apiConfigContainerKeys);

Map<String, dynamic> _apiConfigToJson(APIConfig config) => {
      'baseURL': canonicalApiBaseUrl(config.baseURL) ??
          cleanPresentationText(config.baseURL) ??
          APIConfig.defaults.baseURL,
      'visionModelName': cleanModelId(
        cleanPresentationText(config.visionModelName) ??
            APIConfig.defaults.visionModelName,
      ),
      'textModelName': cleanModelId(
        cleanPresentationText(config.textModelName) ??
            APIConfig.defaults.textModelName,
      ),
      'modelCapabilities': _apiConfigModelCapabilitiesToJson(config),
      'enableImageInput': config.enableImageInput,
      'enableTwoStepVision': config.enableTwoStepVision,
      'imageMaxWidth': _boundedDouble(
        config.imageMaxWidth,
        fallback: APIConfig.defaults.imageMaxWidth,
        min: APIConfig.imageMaxWidthMin,
        max: APIConfig.imageMaxWidthMax,
      ),
      'imageCompressionQuality': _boundedDouble(
        config.imageCompressionQuality,
        fallback: APIConfig.defaults.imageCompressionQuality,
        min: APIConfig.imageCompressionQualityMin,
        max: APIConfig.imageCompressionQualityMax,
      ),
      'temperature': _boundedDouble(
        config.temperature,
        fallback: APIConfig.defaults.temperature,
        min: APIConfig.temperatureMin,
        max: APIConfig.temperatureMax,
      ),
      'maxTokens': _boundedInt(
        config.maxTokens,
        fallback: APIConfig.defaults.maxTokens,
        min: APIConfig.maxTokensMin,
        max: APIConfig.maxTokensMax,
      ),
      'timeout': _boundedInt(
        config.timeout,
        fallback: APIConfig.defaults.timeout,
        min: APIConfig.timeoutMin,
        max: APIConfig.timeoutMax,
      ),
    };

Map<String, dynamic> _apiConfigModelCapabilitiesToJson(APIConfig config) {
  final capabilities = <String, ModelCapability>{};
  for (final entry in config.modelCapabilities.entries) {
    final modelId = cleanPresentationText(entry.key);
    if (modelId == null) continue;
    mergeCapability(capabilities, modelId, entry.value);
  }
  return capabilities.map((key, value) => MapEntry(key, value.toJson()));
}

const _apiConfigContainerKeys = [
  'apiConfig',
  'apiSettings',
  'openAIConfig',
  'openAISettings',
  'openAI',
  'openai',
  'llmConfig',
  'llmSettings',
  'modelConfig',
  'modelSettings',
  'providerConfig',
  'providerSettings',
  'settings',
  'config',
];

const _apiConfigBaseUrlKeys = [
  'baseURL',
  'apiBaseURL',
  'apiBaseUrl',
  'baseUrl',
  'base',
  'endpoint',
  'apiEndpoint',
  'apiURL',
  'apiUrl',
];

const _apiConfigVisionModelKeys = [
  'visionModelName',
  'visionModel',
  'imageModel',
  'multimodalModel',
  'visualModel',
];

const _apiConfigTextModelKeys = [
  'textModelName',
  'textModel',
  'chatModel',
  'modelName',
  'model',
];

const _apiConfigImageInputKeys = [
  'enableImageInput',
  'imageInputEnabled',
  'supportsImageInput',
];

const _apiConfigTwoStepVisionKeys = [
  'enableTwoStepVision',
  'twoStepVision',
  'useTwoStepVision',
  'extractTextBeforeReply',
];

const _apiConfigImageMaxWidthKeys = [
  'imageMaxWidth',
  'maxImageWidth',
  'imageWidth',
];

const _apiConfigImageCompressionQualityKeys = [
  'imageCompressionQuality',
  'compressionQuality',
  'jpegQuality',
  'imageQuality',
];

const _apiConfigTemperatureKeys = ['temperature', 'temp'];

const _apiConfigMaxTokensKeys = [
  'maxTokens',
  'maxOutputTokens',
  'maxOutputToken',
  'max_tokens',
];

const _apiConfigTimeoutKeys = [
  'timeout',
  'timeoutSeconds',
  'requestTimeout',
];
