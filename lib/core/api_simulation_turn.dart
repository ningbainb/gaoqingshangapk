part of 'api_service.dart';

extension _OpenAICompatibleApiSimulationTurn on OpenAICompatibleApi {
  Future<SimulationTurnResponse> _runSimulationTurn({
    required PersonProfile profile,
    required SimulationScenario scenario,
    required List<SimulationMessage> history,
    required String? userReply,
    required String personalizationContext,
    required APIConfig config,
    required String apiKey,
  }) async {
    _validate(config, apiKey, needsVision: false);
    final historyText = cleanSimulationMessages(history).map((message) {
      final speaker = message.speaker == SimulationSpeaker.user ? '我' : '对方';
      return '$speaker：${message.text}';
    }).join('\n');
    final prompt = simulationPrompt(
      profileContext: profile.summaryForPrompt,
      scenario: scenario.title,
      scenarioGoal: scenario.promptGoal,
      history: historyText,
      userReply: userReply,
      personalizationContext: personalizationContext,
    );
    final temperature = config.temperature.clamp(0.7, 0.95);
    final request = _textJsonRequest(
      model: _requiredTextModelName(config),
      systemPrompt: systemPromptChatReplyAssistant,
      userPrompt: prompt,
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
      return _fallbackSimulationTurnResponse(content);
    }
    final parsed = SimulationTurnResponse.fromJson(decoded);
    return _simulationResponseWithDefaults(parsed);
  }
}
