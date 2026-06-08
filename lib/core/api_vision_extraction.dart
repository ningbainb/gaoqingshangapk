part of 'api_service.dart';

extension _OpenAICompatibleApiVisionExtraction on OpenAICompatibleApi {
  Future<ChatReplyResponse> _generateReplyDirectlyFromImage(
    ImagePayload image,
    ChatStyle style,
    String? goal,
    String? personContext,
    String? personalization,
    APIConfig config,
    String apiKey,
  ) async {
    final prompt = visionReplyPrompt(
        style: style,
        userGoal: goal,
        personProfileContext: personContext,
        personalizationContext: personalization);
    final maxTokens = _replyOutputTokenLimit(config);
    final request = _imageJsonRequest(
      model: _requiredVisionModelName(config),
      systemPrompt: systemPromptChatReplyAssistant,
      userPrompt: prompt,
      imageDataUrl: image.dataURL,
      temperature: config.temperature,
      maxTokens: maxTokens,
    );
    final content = await _send(
      config,
      apiKey,
      chatBody: request.chatBody,
      responsesBody: request.responsesBody,
    );
    return _parseReply(content);
  }

  Future<ChatReplyResponse> _generateReplyFromImageInTwoSteps(
    ImagePayload image,
    ChatStyle style,
    String? goal,
    String? personContext,
    String? personalization,
    APIConfig config,
    String apiKey,
  ) async {
    final extracted =
        await _extractConversationFromImage(image, config, apiKey);
    final text = _conversationTextFromExtraction(extracted);
    if (cleanChatTextInput(text) == null) {
      throw AppException('视觉模型没有提取到可用聊天内容。');
    }
    return generateReplyFromText(
      text,
      style,
      goal,
      personContext,
      personalization,
      config,
      apiKey,
    );
  }

  Future<Map<String, dynamic>> _extractConversationFromImage(
    ImagePayload image,
    APIConfig config,
    String apiKey,
  ) async {
    final prompt = visionExtractionPrompt();
    final extractionMaxTokens = config.maxTokens.clamp(600, 1800).toInt();
    final request = _imageJsonRequest(
      model: _requiredVisionModelName(config),
      systemPrompt: '你只负责读取截图中的文字并输出 JSON。',
      userPrompt: prompt,
      imageDataUrl: image.dataURL,
      temperature: 0,
      maxTokens: extractionMaxTokens,
    );
    final content = await _send(
      config.copyWith(maxTokens: extractionMaxTokens),
      apiKey,
      chatBody: request.chatBody,
      responsesBody: request.responsesBody,
    );
    final decoded = decodeJsonObject(content);
    if (decoded == null) {
      throw AppException('视觉识别返回格式不正确，已尝试回退到直接截图生成。');
    }
    return decoded;
  }
}
