part of 'api_service.dart';

extension _OpenAICompatibleApiTransport on OpenAICompatibleApi {
  Uri _base(APIConfig config) {
    final base = config.normalizedBaseUri;
    if (base == null || !config.hasValidBaseUri) {
      throw AppException(apiBaseUrlInvalidMessage);
    }
    return base;
  }

  void _requireKey(String apiKey) {
    if (!hasUsableAPIKey(apiKey)) {
      throw AppException(apiKeyRequiredMessage);
    }
  }

  void _validate(APIConfig config, String apiKey, {required bool needsVision}) {
    _base(config);
    _requireKey(apiKey);
    _requiredTextModelName(config);
    if (needsVision) {
      final visionModelName = _requiredVisionModelName(config);
      if (!config.enableImageInput) {
        throw AppException('请先在 API 设置中启用截图模式。');
      }
      if (!isUsableVisionChatModelId(visionModelName)) {
        throw AppException(visionChatModelRequiredMessage);
      }
      if (!config.capability(visionModelName).isMultimodal) {
        throw AppException('当前视觉模型未标记为多模态，请在 API 设置中勾选后再使用截图功能。');
      }
    }
    if (config.imageMaxWidth < APIConfig.imageMaxWidthMin) {
      throw AppException(imageMaxWidthTooSmallMessage);
    }
    if (config.imageCompressionQuality < APIConfig.imageCompressionQualityMin ||
        config.imageCompressionQuality > APIConfig.imageCompressionQualityMax) {
      throw AppException(imageCompressionQualityInvalidMessage);
    }
  }

  Dio _dio(APIConfig config) =>
      _dioFactory?.call(config) ??
      Dio(BaseOptions(
          connectTimeout: Duration(seconds: config.timeout),
          receiveTimeout: Duration(seconds: config.timeout)));

  Map<String, String> _headers(String apiKey) {
    final cleanedKey = cleanAPIKeyInput(apiKey);
    if (cleanedKey == null) {
      throw AppException(apiKeyRequiredMessage);
    }
    return {
      'Authorization': 'Bearer $cleanedKey',
      'Content-Type': 'application/json',
    };
  }

  Uri _modelsUrl(Uri base) => openAIModelsUrl(base);

  Future<Response<Object?>> _fetchModelsResponse(
    APIConfig config,
    String apiKey,
    Uri url,
  ) async {
    try {
      return await _dio(config)
          .getUri<Object?>(url, options: Options(headers: _headers(apiKey)));
    } on DioException catch (error) {
      throw _mapFetchModelsDioException(error);
    }
  }

  Future<String> _performChatRequest(
    APIConfig config,
    String apiKey,
    Uri url,
    Map<String, dynamic> chatBody,
  ) async {
    try {
      final data = await _postJson(config, apiKey, url, chatBody);
      return _chatContent(data);
    } catch (error) {
      if (!_shouldRetryWithoutResponseFormat(error) ||
          !chatBody.containsKey('response_format')) {
        rethrow;
      }
      final fallbackBody = Map<String, dynamic>.from(chatBody)
        ..remove('response_format');
      final data = await _postJson(config, apiKey, url, fallbackBody);
      return _chatContent(data);
    }
  }

  Future<Object?> _postJson(
    APIConfig config,
    String apiKey,
    Uri url,
    Map<String, dynamic> body,
  ) async {
    try {
      final response = await _dio(config).postUri(
        url,
        data: body,
        options: Options(headers: _headers(apiKey)),
      );
      return response.data;
    } on DioException catch (error) {
      throw _mapDioException(error);
    }
  }
}

String _requiredTextModelName(APIConfig config) {
  final modelName = cleanPresentationText(config.textModelName);
  if (modelName == null) {
    throw AppException(textModelRequiredMessage);
  }
  return modelName;
}

String _requiredVisionModelName(APIConfig config) {
  final modelName = cleanPresentationText(config.visionModelName);
  if (modelName == null) {
    throw AppException(visionModelRequiredMessage);
  }
  return modelName;
}
