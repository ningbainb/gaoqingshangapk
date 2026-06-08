part of 'app_state.dart';

extension AppControllerRuntimeHelpers on AppController {
  int _beginInitialLoadOperation() => ++_loadRevision;

  bool _isCurrentInitialLoadOperation(int revision) =>
      revision == _loadRevision;

  int _beginPrivacyAcknowledgementOperation() {
    _privacyRevision += 1;
    _loadRevision += 1;
    return _privacyRevision;
  }

  bool _isCurrentPrivacyAcknowledgementOperation(int revision) =>
      revision == _privacyRevision;

  void _applyPrivacyAcknowledgement() {
    _hasLoadedInitialState = true;
    showingPrivacyNotice = false;
    _notifyControllerListeners();
  }

  void _applyLoadedPrivacyState(bool loadedShowingPrivacyNotice) {
    showingPrivacyNotice = loadedShowingPrivacyNotice;
    _hasLoadedInitialState = true;
    _notifyControllerListeners();
  }

  void _applyLoadedInitialState({
    required APIConfig loadedConfig,
    required String loadedApiKey,
    required List<GenerationRecord> loadedHistory,
    required List<PersonProfile> loadedProfiles,
    required ReplyPersonalizationSettings loadedPersonalization,
    required ChatStyle loadedDefaultStyle,
    required AppearanceSettings loadedAppearance,
    required bool loadedShowingPrivacyNotice,
    required bool loadedFloatingAutoStart,
  }) {
    config = loadedConfig;
    apiKey = loadedApiKey;
    history = loadedHistory;
    profiles = loadedProfiles;
    personalization = loadedPersonalization;
    defaultStyle = loadedDefaultStyle;
    currentStyle = loadedDefaultStyle;
    appearance = loadedAppearance;
    floatingAutoStart = loadedFloatingAutoStart;
    _applyLoadedPrivacyState(loadedShowingPrivacyNotice);
  }

  int _beginBusyOperation() {
    final revision = ++_busyRevision;
    isBusy = true;
    return revision;
  }

  int _beginReplyGenerationOperation() {
    final revision = ++_replyGenerationBusyRevision;
    _isReplyGenerationBusy = true;
    return revision;
  }

  void _finishReplyGenerationOperation(int revision) {
    if (revision != _replyGenerationBusyRevision) return;
    _isReplyGenerationBusy = false;
  }

  void _finishGenerationOperation({
    required int busyRevision,
    int? replyBusyRevision,
  }) {
    if (replyBusyRevision != null) {
      _finishReplyGenerationOperation(replyBusyRevision);
    }
    _finishBusyOperation(busyRevision);
  }

  int _captureGenerationRevision() => _generationRevision;

  bool _isCurrentGenerationRevision(int revision) =>
      revision == _generationRevision;

  void _invalidateContentOperations() {
    _contentRevision += 1;
  }

  int _beginGenerationOperation() => ++_generationRevision;

  void _invalidateGenerationOperation() {
    _generationRevision += 1;
  }

  bool _isCurrentGeneration(int contentRevision, int generationRevision) =>
      contentRevision == _contentRevision &&
      _isCurrentGenerationRevision(generationRevision);

  int _beginBackgroundImportOperation() => ++_backgroundRevision;

  bool _isCurrentBackgroundImportOperation(int revision) =>
      revision == _backgroundRevision;

  int _captureBackgroundOperationRevision() => _backgroundRevision;

  void _invalidateBackgroundImportOperation() {
    _backgroundRevision += 1;
  }

  int _beginPreferencesMutation() => ++_preferencesRevision;

  bool _isCurrentPreferencesRevision(int revision) =>
      revision == _preferencesRevision;

  int _beginAppearanceMutation() => ++_appearanceRevision;

  bool _isCurrentAppearanceRevision(int revision) =>
      revision == _appearanceRevision;

  int _captureProfilesRevision() => _profilesRevision;

  bool _isCurrentProfilesRevision(int revision) =>
      revision == _profilesRevision;

  int _beginProfilesMutation() => ++_profilesRevision;

  int _beginHistoryMutation() => ++_historyRevision;

  bool _isCurrentHistoryRevision(int revision) => revision == _historyRevision;

  void _finishBusyOperation(int revision) {
    if (revision != _busyRevision) return;
    isBusy = false;
    _notifyControllerListeners();
  }

  void _clearBusyOperation() {
    _busyRevision += 1;
    _replyGenerationBusyRevision += 1;
    isBusy = false;
    _isReplyGenerationBusy = false;
  }

  int _beginModelFetchOperation() {
    final revision = ++_modelFetchGeneration;
    isFetchingModels = true;
    _clearFeedbackMessages();
    return revision;
  }

  bool _isCurrentModelFetchOperation(int revision) =>
      revision == _modelFetchGeneration;

  void _finishModelFetchOperation(int revision, {bool notify = true}) {
    if (!_isCurrentModelFetchOperation(revision)) return;
    isFetchingModels = false;
    if (notify) _notifyControllerListeners();
  }

  int _beginConnectionTestOperation() {
    final revision = ++_connectionTestGeneration;
    isTestingConnection = true;
    _clearFeedbackMessages();
    return revision;
  }

  bool _isCurrentConnectionTestOperation(int revision) =>
      revision == _connectionTestGeneration;

  void _finishConnectionTestOperation(int revision) {
    if (!_isCurrentConnectionTestOperation(revision)) return;
    isTestingConnection = false;
    _notifyControllerListeners();
  }

  int _beginVisionTestOperation() {
    final revision = ++_visionTestGeneration;
    isTestingVision = true;
    _clearFeedbackMessages();
    return revision;
  }

  bool _isCurrentVisionTestOperation(int revision) =>
      revision == _visionTestGeneration;

  void _finishVisionTestOperation(int revision) {
    if (!_isCurrentVisionTestOperation(revision)) return;
    isTestingVision = false;
    _notifyControllerListeners();
  }

  void _clearApiOperationState() {
    isFetchingModels = false;
    isTestingConnection = false;
    isTestingVision = false;
  }

  int _beginSettingsMutation() {
    _settingsRevision += 1;
    return _settingsRevision;
  }

  int _captureSettingsRevision() => _settingsRevision;

  bool _isCurrentSettingsRevision(int revision) =>
      revision == _settingsRevision;

  int _captureLocalDataClearRevision() => _localDataClearRevision;

  bool _isCurrentLocalDataClearRevision(int revision) =>
      revision == _localDataClearRevision;

  int _beginMomentAnalysisOperation() {
    final revision = ++_momentAnalysisRevision;
    _clearFeedbackMessages();
    _clearMomentAnalysisReferences();
    return revision;
  }

  bool _isCurrentMomentAnalysisOperation({
    required int contentRevision,
    required int momentRevision,
  }) =>
      contentRevision == _contentRevision &&
      momentRevision == _momentAnalysisRevision;

  void _invalidateMomentAnalysisOperation() {
    _momentAnalysisRevision += 1;
  }

  int _beginSimulationSession(
    PersonProfile profile, {
    required bool resetScenario,
  }) {
    final normalizedProfile = profile.normalized();
    _simulationRevision += 1;
    simulationProfile = personProfileValuesEqual(profile, normalizedProfile)
        ? profile
        : normalizedProfile;
    if (resetScenario) {
      simulationScenario = SimulationScenario.dailyChat;
    }
    _openingSimulationScenario = simulationScenario;
    simulationMessages = [];
    simulationResponse = null;
    return _simulationRevision;
  }

  bool _isCurrentSimulationTurn({
    required int contentRevision,
    required int simulationRevision,
    required String profileId,
  }) =>
      contentRevision == _contentRevision &&
      simulationRevision == _simulationRevision &&
      personProfileIdsMatch(simulationProfile?.id, profileId);

  _SimulationTurnSnapshot _beginSimulationTurn() {
    final contentRevision = _contentRevision;
    final simulationRevision = _simulationRevision;
    final busyRevision = _beginBusyOperation();
    return _SimulationTurnSnapshot(
      busyRevision: busyRevision,
      contentRevision: contentRevision,
      simulationRevision: simulationRevision,
    );
  }

  void _finishSimulationTurn({
    required int busyRevision,
    required int contentRevision,
    required int simulationRevision,
    required String profileId,
  }) {
    if (!_isCurrentSimulationTurn(
      contentRevision: contentRevision,
      simulationRevision: simulationRevision,
      profileId: profileId,
    )) {
      return;
    }
    _openingSimulationScenario = null;
    _finishBusyOperation(busyRevision);
  }

  void _setStatusMessage(String message) {
    _applyStatusMessage(message);
    _notifyControllerListeners();
  }

  void _setErrorMessage(String message) {
    _applyErrorMessage(message);
    _notifyControllerListeners();
  }

  void _clearFeedbackMessages() {
    statusMessage = null;
    errorMessage = null;
  }

  void _applyStatusMessage(String message) {
    statusMessage = message;
    errorMessage = null;
  }

  void _applyErrorMessage(String message) {
    statusMessage = null;
    errorMessage = message;
  }

  void _clearCurrentResultReferences() {
    currentResponse = null;
    currentGeneratedProfile = null;
    currentRecordId = null;
  }

  bool _clearMomentAnalysisReferences() {
    if (currentMomentAnalysis == null && currentMomentProfile == null) {
      return false;
    }
    currentMomentAnalysis = null;
    currentMomentProfile = null;
    return true;
  }

  bool _clearCurrentImagePathIfMatches(String? path) {
    final targetPath = _normalizedGenerationImagePath(path);
    if (targetPath == null ||
        _normalizedGenerationImagePath(currentImagePath) != targetPath) {
      return false;
    }
    currentImagePath = null;
    return true;
  }

  bool _clearQuickImagePathIfMatches(String? path) {
    final targetPath = _normalizedGenerationImagePath(path);
    if (targetPath == null ||
        _normalizedGenerationImagePath(quickImagePath) != targetPath) {
      return false;
    }
    quickImagePath = null;
    return true;
  }

  String? _normalizedSelectedProfileId(String? selectedProfileId) =>
      restorablePersonProfileId(profiles, selectedProfileId);

  String? _normalizedGenerationTextInput(String? text) =>
      cleanPresentationText(text);

  String? _normalizedGenerationImagePath(String? imagePath) {
    return cleanImagePathInput(imagePath);
  }

  void _setCurrentGenerationSource({
    required ChatInput input,
    String? selectedProfileId,
    String? imagePath,
  }) {
    currentInputType = input.type;
    currentTextInput = input.type == ChatInputType.text
        ? _normalizedGenerationTextInput(input.text)
        : null;
    currentImagePath = input.type == ChatInputType.image
        ? _normalizedGenerationImagePath(imagePath)
        : null;
    currentSelectedProfileId = _normalizedSelectedProfileId(selectedProfileId);
    currentGoal = optionalSanitizedGoal(input.userGoal);
    currentStyle = input.selectedStyle;
    lastInput = input;
  }

  void _setPendingGenerationSource({
    required ChatInputType type,
    String? text,
    String? imagePath,
    String? selectedProfileId,
    String? goal,
    required ChatStyle style,
  }) {
    currentInputType = type;
    currentTextInput = type == ChatInputType.text
        ? _normalizedGenerationTextInput(text)
        : null;
    currentImagePath = type == ChatInputType.image
        ? _normalizedGenerationImagePath(imagePath)
        : null;
    currentSelectedProfileId = _normalizedSelectedProfileId(selectedProfileId);
    currentGoal = optionalSanitizedGoal(goal);
    currentStyle = style;
    lastInput = null;
  }

  Future<bool> _saveCurrentResponseAsHistory({
    String? copiedReply,
    int? generationRevision,
  }) async {
    if (generationRevision != null &&
        !_isCurrentGenerationRevision(generationRevision)) {
      return false;
    }
    final response = currentResponse;
    if (response == null) return false;
    final record = GenerationRecord(
      inputType: currentInputType,
      sceneSummary: response.sceneSummary,
      platform: response.platform,
      relationshipGuess: response.relationshipGuess,
      latestMessage: response.latestMessage,
      emotion: response.emotion,
      riskNotice: response.riskNotice,
      selectedStyleName: currentStyle.name,
      userGoal: currentGoal,
      replies: response.replies,
      copiedReply: copiedReply,
    );
    currentRecordId = record.id;
    history.insert(0, record);
    final clearRevision = _captureLocalDataClearRevision();
    await _persistHistory();
    if (generationRevision != null &&
        !_isCurrentGenerationRevision(generationRevision)) {
      await _discardStaleHistoryRecord(record, clearRevision: clearRevision);
      return false;
    }
    return true;
  }

  Future<void> _discardStaleCurrentGenerationRecord(
    GenerationRecord record, {
    required int clearRevision,
  }) async {
    final removed = _removeHistoryRecordById(record.id);
    _clearCurrentResultReferences();
    if (removed && _isCurrentLocalDataClearRevision(clearRevision)) {
      await _persistHistory();
    }
  }

  Future<void> _discardStaleHistoryRecord(
    GenerationRecord record, {
    required int clearRevision,
  }) async {
    final removed = _removeHistoryRecordById(record.id);
    if (removed && _isCurrentLocalDataClearRevision(clearRevision)) {
      await _persistHistory();
    }
  }

  bool _removeHistoryRecordById(String recordId) {
    final previousLength = history.length;
    history = history
        .where((item) => !historyRecordIdsMatch(item.id, recordId))
        .toList();
    _clearHistoryRuntimeReferencesFor(recordId);
    return history.length != previousLength;
  }

  Future<PersonProfile?> _upsertInsight(
      PersonInsight insight, String? sceneSummary) async {
    final result = upsertPersonInsight(
      profiles: profiles,
      insight: insight,
      sceneSummary: sceneSummary,
    );
    if (result.savedProfile == null) return null;
    profiles = result.profiles;
    await _persistProfiles();
    return result.savedProfile;
  }

  Future<void> _persistProfiles() async {
    final requestRevision = _beginProfilesMutation();
    await _persistNormalizedListForRevision<PersonProfile>(
      revision: requestRevision,
      isCurrentRevision: _isCurrentProfilesRevision,
      items: () => profiles,
      setItems: (items) => profiles = items,
      normalize: (items) => normalizedPersonProfiles(
        items,
        maxCount: AppController._maxProfileCount,
      ),
      save: (items) => _store.saveProfiles(items),
      syncReferences: _syncRetainedProfileReferences,
      syncAfterStale: false,
    );
  }

  Future<void> _persistHistory() async {
    final requestRevision = _beginHistoryMutation();
    await _persistNormalizedListForRevision<GenerationRecord>(
      revision: requestRevision,
      isCurrentRevision: _isCurrentHistoryRevision,
      items: () => history,
      setItems: (items) => history = items,
      normalize: (items) => normalizedHistoryRecords(
        items,
        maxCount: AppController._maxHistoryCount,
      ),
      save: (items) => _store.saveHistory(items),
      syncReferences: _syncRetainedHistoryReferences,
    );
  }

  Future<void> _persistNormalizedListForRevision<T>({
    required int revision,
    required bool Function(int) isCurrentRevision,
    required List<T> Function() items,
    required void Function(List<T>) setItems,
    required List<T> Function(List<T>) normalize,
    required Future<void> Function(List<T>) save,
    required VoidCallback syncReferences,
    bool syncAfterStale = true,
  }) async {
    void normalizeCurrentItems() {
      setItems(normalize(items()));
    }

    normalizeCurrentItems();
    await save(List<T>.of(items()));
    if (!isCurrentRevision(revision)) {
      normalizeCurrentItems();
      await save(List<T>.of(items()));
      if (!syncAfterStale) return;
    }
    syncReferences();
  }

  void _syncRetainedHistoryReferences() {
    selectedHistoryRecord =
        retainedHistoryRecord(history, selectedHistoryRecord);
    final recordId = currentRecordId;
    if (recordId == null) return;
    currentRecordId = restorableHistoryRecordId(history, recordId);
  }

  void _clearHistoryRuntimeReferences() {
    currentRecordId = null;
    selectedHistoryRecord = null;
  }

  void _clearHistoryRuntimeReferencesFor(String recordId) {
    if (historyRecordIdsMatch(currentRecordId, recordId)) {
      currentRecordId = null;
    }
    if (historyRecordIdsMatch(selectedHistoryRecord?.id, recordId)) {
      selectedHistoryRecord = null;
    }
  }

  void _syncRetainedProfileReferences() {
    selectedProfile = retainedPersonProfile(profiles, selectedProfile);
    currentGeneratedProfile =
        retainedPersonProfile(profiles, currentGeneratedProfile);
    currentMomentProfile =
        retainedPersonProfile(profiles, currentMomentProfile);

    final retainedSimulationProfile =
        retainedPersonProfile(profiles, simulationProfile);
    if (simulationProfile != null && retainedSimulationProfile == null) {
      _clearSimulationSession();
    } else {
      simulationProfile = retainedSimulationProfile;
    }

    _syncSelectedProfileId();
  }

  void _clearProfileRuntimeReferences() {
    selectedProfile = null;
    currentGeneratedProfile = null;
    currentMomentProfile = null;
    currentSelectedProfileId = null;
  }

  void _clearProfileRuntimeReferencesFor(String profileId) {
    if (personProfileIdsMatch(selectedProfile?.id, profileId)) {
      selectedProfile = null;
    }
    if (personProfileIdsMatch(currentGeneratedProfile?.id, profileId)) {
      currentGeneratedProfile = null;
    }
    if (personProfileIdsMatch(currentMomentProfile?.id, profileId)) {
      currentMomentProfile = null;
    }
    if (personProfileIdsMatch(currentSelectedProfileId, profileId)) {
      currentSelectedProfileId = null;
    }
  }

  void _clearSimulationSession({
    bool invalidatePending = true,
    bool clearBusy = true,
  }) {
    if (invalidatePending) _simulationRevision += 1;
    simulationProfile = null;
    simulationMessages = [];
    simulationResponse = null;
    _openingSimulationScenario = null;
    if (clearBusy) _clearBusyOperation();
  }

  void _clearSimulationSessionForProfile(String profileId) {
    if (!personProfileIdsMatch(simulationProfile?.id, profileId)) return;
    _clearSimulationSession();
  }

  void _syncSelectedProfileId() {
    final selectedId = currentSelectedProfileId;
    if (selectedId == null) return;
    currentSelectedProfileId = restorablePersonProfileId(profiles, selectedId);
  }

  void _clearAvailableModels() {
    availableModels = [];
    _availableModelsFingerprint = null;
  }
}

class _PromptContextSnapshot {
  const _PromptContextSnapshot({
    required this.personProfileContext,
    required this.personalizationContext,
  });

  final String personProfileContext;
  final String personalizationContext;
}

class _SimulationTurnSnapshot {
  const _SimulationTurnSnapshot({
    required this.busyRevision,
    required this.contentRevision,
    required this.simulationRevision,
  });

  final int busyRevision;
  final int contentRevision;
  final int simulationRevision;
}
