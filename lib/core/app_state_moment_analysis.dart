part of 'app_state.dart';

extension AppControllerMomentAnalysis on AppController {
  Future<void> analyzeMoment(String imagePath, {PersonProfile? target}) async {
    if (isBusy) return;
    final submittedImagePath = _normalizedGenerationImagePath(imagePath);
    if (submittedImagePath == null) {
      _invalidateMomentAnalysisOperation();
      _clearFeedbackMessages();
      _clearMomentAnalysisReferences();
      _clearBusyOperation();
      _applyErrorMessage('请先选择动态截图。');
      _notifyControllerListeners();
      return;
    }
    final requestRevision = _contentRevision;
    final requestMomentRevision = _beginMomentAnalysisOperation();
    final busyRevision = _beginBusyOperation();
    _notifyControllerListeners();
    try {
      final payload = await _imageService.prepareImagePayload(
        submittedImagePath,
        maxWidth: config.imageMaxWidth,
        quality: config.imageCompressionQuality,
      );
      if (!_isCurrentMomentAnalysis(requestRevision, requestMomentRevision)) {
        return;
      }
      final analysis = await _api.analyzeMomentScreenshot(
        payload,
        target?.summaryForPrompt,
        config,
        apiKey,
      );
      if (!_isCurrentMomentAnalysis(requestRevision, requestMomentRevision)) {
        return;
      }
      final savedProfile = await _upsertInsight(
          momentInsightForTarget(analysis, target), analysis.sceneSummary);
      if (!_isCurrentMomentAnalysis(requestRevision, requestMomentRevision)) {
        return;
      }
      currentMomentAnalysis = analysis;
      currentMomentProfile = savedProfile;
      await _fileCleaner.deleteOwnedTransientImageFile(submittedImagePath);
      _applyStatusMessage('已分析并写入人物库');
    } catch (error) {
      if (!_isCurrentMomentAnalysis(requestRevision, requestMomentRevision)) {
        return;
      }
      _applyErrorMessage(userMessageFor(error));
    } finally {
      _finishBusyOperation(busyRevision);
    }
  }

  void clearMomentResult({bool notify = true}) {
    _invalidateMomentAnalysisOperation();
    if (!_clearMomentAnalysisReferences()) return;
    if (notify) _notifyControllerListeners();
  }

  bool _isCurrentMomentAnalysis(int contentRevision, int momentRevision) =>
      _isCurrentMomentAnalysisOperation(
        contentRevision: contentRevision,
        momentRevision: momentRevision,
      );
}
