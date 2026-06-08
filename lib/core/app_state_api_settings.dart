part of 'app_state.dart';

extension AppControllerApiSettings on AppController {
  Future<void> saveConfig(APIConfig next, String nextKey) async {
    final previousFingerprint = apiConfigSourceFingerprint(config, apiKey);
    final requestRevision = _beginSettingsMutation();
    final requestClearRevision = _captureLocalDataClearRevision();
    _clearApiOperationState();
    try {
      final normalized = normalizeApiConfig(next);
      validateApiConfig(normalized);
      config = normalized;
      apiKey = cleanAPIKeyInput(nextKey) ?? '';
      _clearAvailableModelsIfSourceChanged(previousFingerprint);
      final didPersist = await _persistCurrentSettingsForRevision(
        revision: requestRevision,
        clearRevision: requestClearRevision,
      );
      if (!didPersist || !_isCurrentSettingsRevision(requestRevision)) {
        return;
      }
      _setStatusMessage('配置已保存');
    } catch (error) {
      _setErrorMessage(userMessageFor(error));
    }
  }

  Future<void> resetConfig() async {
    config = APIConfig.defaults;
    apiKey = '';
    final requestRevision = _beginSettingsMutation();
    final requestClearRevision = _captureLocalDataClearRevision();
    _clearApiOperationState();
    _clearAvailableModels();
    final didPersist = await _persistCurrentSettingsForRevision(
      revision: requestRevision,
      clearRevision: requestClearRevision,
    );
    if (!didPersist || !_isCurrentSettingsRevision(requestRevision)) {
      return;
    }
    _setStatusMessage('配置已恢复默认，API Key 已清除');
  }

  Future<void> clearAPIKey() async {
    apiKey = '';
    final requestRevision = _beginSettingsMutation();
    _clearApiOperationState();
    _clearAvailableModels();
    await _store.saveAPIKey(apiKey);
    if (!_isCurrentSettingsRevision(requestRevision)) {
      await _store.saveAPIKey(apiKey);
      return;
    }
    _setStatusMessage('API Key 已清除，其他配置已保留');
  }

  Future<void> _persistSettings(APIConfig nextConfig, String nextKey) async {
    await _store.saveConfig(nextConfig);
    await _store.saveAPIKey(nextKey);
  }

  Future<void> _persistCurrentSettings() async {
    await _persistSettings(config, apiKey);
  }

  Future<bool> _persistCurrentSettingsForRevision({
    required int revision,
    required int clearRevision,
  }) async {
    await _persistCurrentSettings();
    if (_isCurrentSettingsRevision(revision)) return true;

    if (!_isCurrentLocalDataClearRevision(clearRevision)) {
      await _clearPersistedSettings();
      return false;
    }
    await _persistCurrentSettings();
    return true;
  }

  Future<void> _clearPersistedSettings() async {
    await _store.clearConfig();
    await _store.saveAPIKey('');
  }

  void _clearAvailableModelsIfSourceChanged(String previousFingerprint) {
    final currentFingerprint = apiConfigSourceFingerprint(config, apiKey);
    if (previousFingerprint != currentFingerprint ||
        (_availableModelsFingerprint != null &&
            _availableModelsFingerprint != currentFingerprint)) {
      _clearAvailableModels();
    }
  }
}
