part of 'app_state.dart';

extension AppControllerModelFetching on AppController {
  Future<void> fetchModels({bool applyRecommended = true}) async {
    final requestGeneration = _beginModelFetchOperation();
    var requestFingerprint = apiConfigSourceFingerprint(config, apiKey);
    _notifyControllerListeners();
    try {
      final requestConfig = normalizeApiConfig(config);
      final requestKey = cleanAPIKeyInput(apiKey) ?? '';
      validateModelFetchSource(requestConfig, requestKey);
      requestFingerprint =
          apiConfigSourceFingerprint(requestConfig, requestKey);
      _clearAvailableModelsIfSourceChanged(requestFingerprint);
      final models = normalizedApiModels(
          await _api.fetchModels(requestConfig, requestKey));
      if (!_isCurrentModelFetchOperation(requestGeneration)) return;
      if (requestFingerprint != apiConfigSourceFingerprint(config, apiKey)) {
        _clearAvailableModelsIfSourceChanged(
            apiConfigSourceFingerprint(config, apiKey));
        return;
      }
      availableModels = models;
      _availableModelsFingerprint = requestFingerprint;
      if (applyRecommended) {
        config = configWithRecommendedModels(requestConfig, models);
        final saveRevision = _beginSettingsMutation();
        final saveClearRevision = _captureLocalDataClearRevision();
        final didPersist = await _persistCurrentSettingsForRevision(
          revision: saveRevision,
          clearRevision: saveClearRevision,
        );
        if (!didPersist || !_isCurrentSettingsRevision(saveRevision)) {
          return;
        }
      }
      _applyStatusMessage(applyRecommended
          ? '已拉取 ${models.length} 个模型，并补全推荐组合。'
          : '已拉取 ${models.length} 个模型。');
    } catch (error) {
      if (!_isCurrentModelFetchOperation(requestGeneration)) {
        return;
      }
      if (requestFingerprint == apiConfigSourceFingerprint(config, apiKey)) {
        _clearAvailableModels();
        _applyErrorMessage(userMessageFor(error));
      } else {
        _clearAvailableModelsIfSourceChanged(
            apiConfigSourceFingerprint(config, apiKey));
      }
    } finally {
      _finishModelFetchOperation(requestGeneration);
    }
  }

  Future<APIConfig?> fetchModelsForDraft(
    APIConfig draftConfig,
    String draftKey, {
    bool applyRecommended = true,
  }) async {
    final requestGeneration = _beginModelFetchOperation();
    APIConfig normalized;
    String trimmedKey;
    String requestFingerprint;
    try {
      normalized = normalizeApiConfig(draftConfig);
      trimmedKey = cleanAPIKeyInput(draftKey) ?? '';
      validateModelFetchSource(normalized, trimmedKey);
      requestFingerprint = apiConfigSourceFingerprint(normalized, trimmedKey);
      if (_availableModelsFingerprint != requestFingerprint) {
        _clearAvailableModels();
      }
      _notifyControllerListeners();
    } catch (error) {
      _finishModelFetchOperation(requestGeneration, notify: false);
      _setErrorMessage(userMessageFor(error));
      return null;
    }
    try {
      final models =
          normalizedApiModels(await _api.fetchModels(normalized, trimmedKey));
      if (!_isCurrentModelFetchOperation(requestGeneration)) return null;
      availableModels = models;
      _availableModelsFingerprint = requestFingerprint;
      final recommended = applyRecommended
          ? configWithRecommendedModels(normalized, models)
          : normalized;
      _applyStatusMessage(applyRecommended
          ? '已拉取 ${models.length} 个模型，并补全推荐组合。'
          : '已拉取 ${models.length} 个模型。');
      return recommended;
    } catch (error) {
      if (_isCurrentModelFetchOperation(requestGeneration)) {
        _applyErrorMessage(userMessageFor(error));
      }
      return null;
    } finally {
      _finishModelFetchOperation(requestGeneration);
    }
  }

  void invalidateModelsForDraftSource(APIConfig draftConfig, String draftKey) {
    if (availableModels.isEmpty && _availableModelsFingerprint == null) {
      return;
    }

    final hasUsableSource =
        draftConfig.hasValidBaseUri && hasUsableAPIKey(draftKey);
    final sourceMatches = hasUsableSource &&
        _availableModelsFingerprint ==
            apiConfigSourceFingerprint(draftConfig, draftKey);
    if (sourceMatches) return;

    _clearAvailableModels();
    _notifyControllerListeners();
  }
}
