part of 'api_service.dart';

extension _OpenAICompatibleApiSend on OpenAICompatibleApi {
  Future<String> _send(
    APIConfig config,
    String apiKey, {
    required Map<String, dynamic> chatBody,
    required Map<String, dynamic> responsesBody,
  }) async {
    final base = _base(config);
    if (usesResponsesApiEndpoint(base)) {
      return _sendWithResponsesFallback(
        config,
        apiKey,
        base: base,
        chatBody: chatBody,
        responsesBody: responsesBody,
      );
    }
    return _performChatRequest(
      config,
      apiKey,
      openAIEndpointUrl(base),
      chatBody,
    );
  }

  Future<String> _sendWithResponsesFallback(
    APIConfig config,
    String apiKey, {
    required Uri base,
    required Map<String, dynamic> chatBody,
    required Map<String, dynamic> responsesBody,
  }) async {
    try {
      final data = await _postJson(config, apiKey, base, responsesBody);
      return _responsesContent(data);
    } catch (error) {
      if (!_shouldFallbackFromResponses(error)) rethrow;
      return _sendChatAfterResponsesFailure(
        config,
        apiKey,
        base: base,
        chatBody: chatBody,
      );
    }
  }

  Future<String> _sendChatAfterResponsesFailure(
    APIConfig config,
    String apiKey, {
    required Uri base,
    required Map<String, dynamic> chatBody,
  }) async {
    try {
      return await _performChatRequest(
        config,
        apiKey,
        chatCompletionsUrlFromResponses(base),
        chatBody,
      );
    } catch (chatError) {
      throw AppException(
        'Responses API 不可用，已自动尝试 Chat Completions，仍失败：${_messageFor(chatError)}',
      );
    }
  }
}
