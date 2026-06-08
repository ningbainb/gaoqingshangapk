part of 'api_service.dart';

extension _OpenAICompatibleApiConnectionTests on OpenAICompatibleApi {
  Future<void> _testConnection(APIConfig config, String apiKey) async {
    _validate(config, apiKey, needsVision: false);
    final request = _textJsonRequest(
      model: _requiredTextModelName(config),
      systemPrompt: '你只需要返回 JSON。',
      userPrompt: '返回 {"sceneSummary":"连接正常","replies":[]}',
      temperature: 0,
      maxTokens: 80,
    );
    await _send(
      config.copyWith(maxTokens: 80, temperature: 0),
      apiKey,
      chatBody: request.chatBody,
      responsesBody: request.responsesBody,
    );
  }

  Future<void> _testVisionConnection(APIConfig config, String apiKey) async {
    _validate(config, apiKey, needsVision: true);
    const imageURL =
        'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+/p9sAAAAASUVORK5CYII=';
    const prompt = '这是一张 1x1 测试图片。只返回 JSON：{"ok":true}';
    final request = _imageJsonRequest(
      model: _requiredVisionModelName(config),
      systemPrompt: '你只需要返回 JSON。',
      userPrompt: prompt,
      imageDataUrl: imageURL,
      temperature: 0,
      maxTokens: 80,
    );
    await _send(
      config.copyWith(maxTokens: 80, temperature: 0),
      apiKey,
      chatBody: request.chatBody,
      responsesBody: request.responsesBody,
    );
  }
}
