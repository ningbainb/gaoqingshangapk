part of 'app_state.dart';

extension AppControllerLocalData on AppController {
  Future<void> markPrivacySeen() async {
    final requestRevision = _beginPrivacyAcknowledgementOperation();
    await _store.markPrivacyNoticeSeen();
    if (!_isCurrentPrivacyAcknowledgementOperation(requestRevision)) {
      if (showingPrivacyNotice) {
        await _store.clearPrivacyNoticeSeen();
      }
      return;
    }
    _applyPrivacyAcknowledgement();
  }

  Future<void> clearAllLocalData() async {
    final customBackgroundPath = appearance.customBackgroundPath;
    final editableImagePath = currentImagePath;
    final transientImagePaths = [quickImagePath, sharedImagePath];
    _invalidateLocalDataOperations();
    _hasLoadedInitialState = true;
    config = APIConfig.defaults;
    apiKey = '';
    _clearAvailableModels();
    history = [];
    profiles = [];
    personalization = ReplyPersonalizationSettings.defaults;
    defaultStyle = ChatStyle.defaultStyle;
    appearance = AppearanceSettings.defaults;
    floatingAutoStart = false;
    _clearCurrentResultReferences();
    _clearMomentAnalysisReferences();
    _clearProfileRuntimeReferences();
    _clearBusyOperation();
    _clearApiOperationState();
    _setPendingGenerationSource(
      type: ChatInputType.text,
      style: ChatStyle.defaultStyle,
    );
    _clearHistoryRuntimeReferences();
    _clearSimulationSession(invalidatePending: false, clearBusy: false);
    simulationScenario = SimulationScenario.dailyChat;
    _clearQuickReplySessionState();
    sharedImagePath = null;
    sharedText = null;
    _applyStatusMessage(privacyClearSuccessMessage);
    showingPrivacyNotice = true;
    await _fileCleaner.deleteCustomBackground(customBackgroundPath);
    await _fileCleaner.deleteOwnedTransientImageFile(editableImagePath);
    await _fileCleaner.deleteTransientImageFiles(transientImagePaths);
    await _store.clearAll();
    _notifyControllerListeners();
  }

  void _invalidateLocalDataOperations() {
    _settingsRevision += 1;
    _contentRevision += 1;
    _simulationRevision += 1;
    _historyRevision += 1;
    _profilesRevision += 1;
    _backgroundRevision += 1;
    _preferencesRevision += 1;
    _appearanceRevision += 1;
    _privacyRevision += 1;
    _loadRevision += 1;
    _generationRevision += 1;
    _momentAnalysisRevision += 1;
    _modelFetchGeneration += 1;
    _connectionTestGeneration += 1;
    _visionTestGeneration += 1;
    _localDataClearRevision += 1;
  }

  void setError(String message) {
    _setErrorMessage(message);
  }

  void setStatus(String message) {
    _setStatusMessage(message);
  }

  void clearFeedback({bool notify = true}) {
    if (statusMessage == null && errorMessage == null) return;
    _clearFeedbackMessages();
    if (notify) _notifyControllerListeners();
  }

  Future<void> setFloatingAutoStart(bool enabled) async {
    if (floatingAutoStart == enabled) return;
    floatingAutoStart = enabled;
    _notifyControllerListeners();
    await _store.saveFloatingAutoStart(enabled);
  }
}
