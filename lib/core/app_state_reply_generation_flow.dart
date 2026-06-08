part of 'app_state.dart';

extension AppControllerReplyGenerationFlow on AppController {
  _PromptContextSnapshot _promptContextSnapshot({String? selectedProfileId}) =>
      _PromptContextSnapshot(
        personProfileContext:
            makePersonProfileContext(selectedProfileId: selectedProfileId),
        personalizationContext: personalizationPromptContext(),
      );

  Future<bool> _generate(
    ChatInput input, {
    String? selectedProfileId,
    String? imagePath,
    int? requestGeneration,
    int? busyRevision,
    int? replyBusyRevision,
  }) async {
    final generation = requestGeneration ?? _beginGenerationOperation();
    final requestRevision = _contentRevision;
    final activeBusyRevision = busyRevision ?? _beginBusyOperation();
    _clearFeedbackMessages();
    _clearCurrentResultReferences();
    _setCurrentGenerationSource(
      input: input,
      selectedProfileId: selectedProfileId,
      imagePath: imagePath,
    );
    _notifyControllerListeners();
    try {
      final enriched = ChatInput(
        type: input.type,
        text: input.text,
        imagePayload: input.imagePayload,
        userGoal: input.userGoal,
        selectedStyle: input.selectedStyle,
        personProfileContext:
            cleanPresentationText(input.personProfileContext) ??
                makePersonProfileContext(selectedProfileId: selectedProfileId),
        personalizationContext:
            cleanPresentationText(input.personalizationContext) ??
                personalizationPromptContext(),
      );
      final response =
          (await _api.generateReply(enriched, config, apiKey)).normalized();
      if (!_isCurrentGeneration(requestRevision, generation)) return false;
      currentResponse = response;
      final insight = response.personInsight;
      PersonProfile? generatedProfile;
      if (insight != null) {
        generatedProfile = await _upsertInsight(insight, response.sceneSummary);
      }
      if (!_isCurrentGeneration(requestRevision, generation)) return false;
      currentGeneratedProfile = generatedProfile;
      final record = GenerationRecord(
        inputType: input.type,
        sceneSummary: response.sceneSummary,
        platform: response.platform,
        relationshipGuess: response.relationshipGuess,
        latestMessage: response.latestMessage,
        emotion: response.emotion,
        riskNotice: response.riskNotice,
        selectedStyleName: input.selectedStyle.name,
        userGoal: input.userGoal,
        replies: response.replies,
      );
      currentRecordId = record.id;
      history.insert(0, record);
      final clearRevision = _captureLocalDataClearRevision();
      await _persistHistory();
      if (!_isCurrentGeneration(requestRevision, generation)) {
        await _discardStaleCurrentGenerationRecord(
          record,
          clearRevision: clearRevision,
        );
        return false;
      }
      return true;
    } catch (error) {
      if (!_isCurrentGeneration(requestRevision, generation)) return false;
      _applyErrorMessage(userMessageFor(error));
      return false;
    } finally {
      _finishGenerationOperation(
        busyRevision: activeBusyRevision,
        replyBusyRevision: replyBusyRevision,
      );
    }
  }
}
