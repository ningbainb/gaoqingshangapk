part of 'models.dart';

class APIConfig {
  const APIConfig({
    required this.baseURL,
    required this.visionModelName,
    required this.textModelName,
    required this.modelCapabilities,
    required this.enableImageInput,
    required this.enableTwoStepVision,
    required this.imageMaxWidth,
    required this.imageCompressionQuality,
    required this.temperature,
    required this.maxTokens,
    required this.timeout,
  });

  final String baseURL;
  final String visionModelName;
  final String textModelName;
  final Map<String, ModelCapability> modelCapabilities;
  final bool enableImageInput;
  final bool enableTwoStepVision;
  final double imageMaxWidth;
  final double imageCompressionQuality;
  final double temperature;
  final int maxTokens;
  final int timeout;

  static const imageMaxWidthMin = 320.0;
  static const imageMaxWidthMax = 2048.0;
  static const imageCompressionQualityMin = 0.1;
  static const imageCompressionQualityMax = 1.0;
  static const temperatureMin = 0.0;
  static const temperatureMax = 2.0;
  static const maxTokensMin = 200;
  static const maxTokensMax = 4000;
  static const timeoutMin = 10;
  static const timeoutMax = 180;

  static const defaults = APIConfig(
    baseURL: 'https://api.openai.com/v1',
    visionModelName: 'gpt-4o-mini',
    textModelName: 'gpt-4o-mini',
    modelCapabilities: {'gpt-4o-mini': ModelCapability(isMultimodal: true)},
    enableImageInput: true,
    enableTwoStepVision: false,
    imageMaxWidth: 1280,
    imageCompressionQuality: 0.75,
    temperature: 0.8,
    maxTokens: 1000,
    timeout: 60,
  );



  Uri? get normalizedBaseUri {
    return normalizedApiBaseUri(baseURL);
  }

  bool get hasValidBaseUri {
    final uri = normalizedBaseUri;
    if (uri == null || cleanNonEmptyText(uri.host) == null) return false;
    final scheme = uri.scheme.toLowerCase();
    return scheme == 'http' || scheme == 'https';
  }

  static ModelCapability lookupCapability(
      Map<String, ModelCapability> capabilities, String modelId) {
    final trimmed = cleanModelId(modelId);
    if (trimmed.isEmpty) return const ModelCapability();
    final direct = capabilities[trimmed];
    if (direct != null) return direct;
    final normalized = normalizedModelId(trimmed);
    for (final entry in capabilities.entries) {
      if (normalizedModelId(entry.key) == normalized) {
        return entry.value;
      }
    }
    return const ModelCapability();
  }

  ModelCapability capability(String modelId) =>
      lookupCapability(modelCapabilities, modelId);

  bool get hasDefaultValues => isEquivalentTo(defaults);

  bool isEquivalentTo(APIConfig other) =>
      _apiConfigBaseUrlsMatch(baseURL, other.baseURL) &&
      _apiConfigModelIdsMatch(visionModelName, other.visionModelName) &&
      _apiConfigModelIdsMatch(textModelName, other.textModelName) &&
      _apiConfigCapabilitiesMatch(modelCapabilities, other.modelCapabilities) &&
      enableImageInput == other.enableImageInput &&
      enableTwoStepVision == other.enableTwoStepVision &&
      imageMaxWidth == other.imageMaxWidth &&
      imageCompressionQuality == other.imageCompressionQuality &&
      temperature == other.temperature &&
      maxTokens == other.maxTokens &&
      timeout == other.timeout;

  APIConfig copyWith({
    String? baseURL,
    String? visionModelName,
    String? textModelName,
    Map<String, ModelCapability>? modelCapabilities,
    bool? enableImageInput,
    bool? enableTwoStepVision,
    double? imageMaxWidth,
    double? imageCompressionQuality,
    double? temperature,
    int? maxTokens,
    int? timeout,
  }) {
    return APIConfig(
      baseURL: baseURL ?? this.baseURL,
      visionModelName: visionModelName ?? this.visionModelName,
      textModelName: textModelName ?? this.textModelName,
      modelCapabilities: modelCapabilities ?? this.modelCapabilities,
      enableImageInput: enableImageInput ?? this.enableImageInput,
      enableTwoStepVision: enableTwoStepVision ?? this.enableTwoStepVision,
      imageMaxWidth: imageMaxWidth ?? this.imageMaxWidth,
      imageCompressionQuality:
          imageCompressionQuality ?? this.imageCompressionQuality,
      temperature: temperature ?? this.temperature,
      maxTokens: maxTokens ?? this.maxTokens,
      timeout: timeout ?? this.timeout,
    );
  }

  factory APIConfig.fromJson(Map<String, dynamic> json) =>
      _apiConfigFromJson(json);

  Map<String, dynamic> toJson() => _apiConfigToJson(this);
}
