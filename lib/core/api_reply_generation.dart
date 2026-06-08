part of 'api_service.dart';

extension _OpenAICompatibleApiReplyGeneration on OpenAICompatibleApi {
  Future<ChatReplyResponse> _generateReply(
    ChatInput input,
    APIConfig config,
    String apiKey,
  ) async {
    if (input.type == ChatInputType.image) {
      final payload = input.imagePayload;
      if (payload == null) throw AppException('截图数据为空，请重新选择图片。');
      return generateReplyFromImage(
        payload,
        input.selectedStyle,
        input.userGoal,
        input.personProfileContext,
        input.personalizationContext,
        config,
        apiKey,
      );
    }
    final text = cleanChatTextInput(input.text);
    if (text == null) throw AppException('请先输入聊天文本。');
    return generateReplyFromText(
      text,
      input.selectedStyle,
      input.userGoal,
      input.personProfileContext,
      input.personalizationContext,
      config,
      apiKey,
    );
  }

  Future<ChatReplyResponse> _generateReplyFromImage(
    ImagePayload image,
    ChatStyle style,
    String? goal,
    String? personContext,
    String? personalization,
    APIConfig config,
    String apiKey,
  ) async {
    _validate(config, apiKey, needsVision: true);
    if (config.enableTwoStepVision) {
      try {
        return await _generateReplyFromImageInTwoSteps(
          image,
          style,
          goal,
          personContext,
          personalization,
          config,
          apiKey,
        );
      } catch (_) {
        // Keep screenshot generation usable even when a provider cannot handle
        // the extra extraction round-trip.
      }
    }
    return _generateReplyDirectlyFromImage(
      image,
      style,
      goal,
      personContext,
      personalization,
      config,
      apiKey,
    );
  }

  Future<ChatReplyResponse> _generateReplyFromText(
    String text,
    ChatStyle style,
    String? goal,
    String? personContext,
    String? personalization,
    APIConfig config,
    String apiKey,
  ) async {
    _validate(config, apiKey, needsVision: false);
    final prompt = textReplyPrompt(
      text: text,
      style: style,
      userGoal: goal,
      personProfileContext: personContext,
      personalizationContext: personalization,
    );
    final maxTokens = _replyOutputTokenLimit(config);
    final request = _textJsonRequest(
      model: _requiredTextModelName(config),
      systemPrompt: systemPromptChatReplyAssistant,
      userPrompt: prompt,
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
}
