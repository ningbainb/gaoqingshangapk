part of 'app_state.dart';

extension AppControllerImageGeneration on AppController {
  Future<void> generateImage(
    String imagePath,
    ChatStyle style,
    String goal, {
    String? selectedProfileId,
  }) async {
    if (isBusy) return;
    final submittedImagePath = _normalizedGenerationImagePath(imagePath);
    if (submittedImagePath == null) {
      isQuickReplySession = false;
      _invalidateGenerationOperation();
      _clearFeedbackMessages();
      _clearCurrentResultReferences();
      _clearBusyOperation();
      _setPendingGenerationSource(
        type: ChatInputType.image,
        selectedProfileId: selectedProfileId,
        goal: optionalSanitizedGoal(goal),
        style: style,
      );
      _applyErrorMessage('请先选择截图。');
      _notifyControllerListeners();
      return;
    }
    final replyBusyRevision = _beginReplyGenerationOperation();
    final requestGeneration = _beginGenerationOperation();
    final requestRevision = _contentRevision;
    final busyRevision = _beginBusyOperation();
    isQuickReplySession = quickImagePath != null &&
        _normalizedGenerationImagePath(quickImagePath) == submittedImagePath;
    _clearFeedbackMessages();
    _clearCurrentResultReferences();
    final userGoal = optionalSanitizedGoal(goal);
    _setPendingGenerationSource(
      type: ChatInputType.image,
      imagePath: submittedImagePath,
      selectedProfileId: selectedProfileId,
      goal: userGoal,
      style: style,
    );
    _notifyControllerListeners();
    final ImagePayload payload;
    final _PromptContextSnapshot promptContext;
    try {
      final prepared = await Future.wait<Object>([
        _imageService.prepareImagePayload(
          submittedImagePath,
          maxWidth: config.imageMaxWidth,
          quality: config.imageCompressionQuality,
        ),
        Future<_PromptContextSnapshot>(
          () => _promptContextSnapshot(selectedProfileId: selectedProfileId),
        ),
      ]);
      payload = prepared[0] as ImagePayload;
      promptContext = prepared[1] as _PromptContextSnapshot;
    } catch (error) {
      if (!_isCurrentGeneration(requestRevision, requestGeneration)) {
        _finishGenerationOperation(
          busyRevision: busyRevision,
          replyBusyRevision: replyBusyRevision,
        );
        return;
      }
      _applyErrorMessage(userMessageFor(error));
      _finishGenerationOperation(
        busyRevision: busyRevision,
        replyBusyRevision: replyBusyRevision,
      );
      return;
    }
    if (!_isCurrentGeneration(requestRevision, requestGeneration)) {
      _finishGenerationOperation(
        busyRevision: busyRevision,
        replyBusyRevision: replyBusyRevision,
      );
      return;
    }
    final didApply = await _generate(
      ChatInput(
        type: ChatInputType.image,
        imagePayload: payload,
        userGoal: userGoal,
        selectedStyle: style,
        personProfileContext: promptContext.personProfileContext,
        personalizationContext: promptContext.personalizationContext,
      ),
      selectedProfileId: selectedProfileId,
      imagePath: submittedImagePath,
      requestGeneration: requestGeneration,
      busyRevision: busyRevision,
      replyBusyRevision: replyBusyRevision,
    );
    if (didApply && currentResponse != null) {
      final wasEditableTransientImage =
          await _fileCleaner.isOwnedTransientImagePath(submittedImagePath);
      await _fileCleaner.deleteOwnedTransientImageFile(submittedImagePath);
      if (wasEditableTransientImage) {
        final clearedCurrent =
            _clearCurrentImagePathIfMatches(submittedImagePath);
        final clearedQuick = _clearQuickImagePathIfMatches(submittedImagePath);
        if (clearedCurrent || clearedQuick) _notifyControllerListeners();
      }
    }
  }
}
