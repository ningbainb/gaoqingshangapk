part of 'api_service.dart';

extension _OpenAICompatibleApiProfileAnalysis on OpenAICompatibleApi {
  Future<MomentProfileAnalysis> _analyzeMomentScreenshot(
    ImagePayload image,
    String? personContext,
    APIConfig config,
    String apiKey,
  ) async {
    _validate(config, apiKey, needsVision: true);
    final prompt = momentProfilePrompt(personProfileContext: personContext);
    final temperature = config.temperature.clamp(0, 0.7);
    final request = _imageJsonRequest(
      model: _requiredVisionModelName(config),
      systemPrompt: systemPromptMomentsProfileAnalyst,
      userPrompt: prompt,
      imageDataUrl: image.dataURL,
      temperature: temperature,
      maxTokens: config.maxTokens,
    );
    final content = await _send(
      config,
      apiKey,
      chatBody: request.chatBody,
      responsesBody: request.responsesBody,
    );
    final decoded = decodeJsonObject(content);
    if (decoded == null) {
      throw AppException('朋友圈画像返回格式不正确，请检查模型是否支持 JSON 输出。');
    }
    return MomentProfileAnalysis.fromJson(decoded);
  }
}
