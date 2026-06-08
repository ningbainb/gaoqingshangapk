part of 'app_state.dart';

extension AppControllerTextGeneration on AppController {
  Future<void> generateText(
    String text,
    ChatStyle style,
    String goal, {
    String? selectedProfileId,
  }) async {
    if (_isReplyGenerationBusy) return;
    isQuickReplySession = false;
    final cleanedText = cleanChatTextInput(text);
    if (cleanedText == null) {
      _invalidateGenerationOperation();
      _clearFeedbackMessages();
      _clearCurrentResultReferences();
      _clearBusyOperation();
      _setPendingGenerationSource(
        type: ChatInputType.text,
        selectedProfileId: selectedProfileId,
        goal: optionalSanitizedGoal(goal),
        style: style,
      );
      _applyErrorMessage('请先输入聊天文本。');
      _notifyControllerListeners();
      return;
    }
    final replyBusyRevision = _beginReplyGenerationOperation();
    final userGoal = optionalSanitizedGoal(goal);
    final promptContext =
        _promptContextSnapshot(selectedProfileId: selectedProfileId);
    await _generate(
      ChatInput(
        type: ChatInputType.text,
        text: cleanedText,
        userGoal: userGoal,
        selectedStyle: style,
        personProfileContext: promptContext.personProfileContext,
        personalizationContext: promptContext.personalizationContext,
      ),
      selectedProfileId: selectedProfileId,
      replyBusyRevision: replyBusyRevision,
    );
  }
}
