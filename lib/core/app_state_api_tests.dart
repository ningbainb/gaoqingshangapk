part of 'app_state.dart';

extension AppControllerApiTests on AppController {
  Future<void> testConnection(APIConfig draftConfig, String draftKey) async {
    if (_isSettingsTestBusy) return;
    final requestGeneration = _beginConnectionTestOperation();
    final requestRevision = _captureSettingsRevision();
    _notifyControllerListeners();
    try {
      final previousFingerprint = apiConfigSourceFingerprint(config, apiKey);
      final normalized = normalizeApiConfig(draftConfig);
      final trimmedKey = cleanAPIKeyInput(draftKey) ?? '';
      validateApiConfig(normalized);
      await _api.testConnection(normalized, trimmedKey);
      final isCurrent = _isCurrentConnectionTestOperation(requestGeneration);
      if (!_isCurrentSettingsTest(requestRevision, isCurrent)) {
        return;
      }
      final didApply = await _applySuccessfulSettingsTest(
        normalized: normalized,
        trimmedKey: trimmedKey,
        previousFingerprint: previousFingerprint,
      );
      if (!didApply) {
        return;
      }
      _applyStatusMessage('连接测试成功，配置已保存');
    } catch (error) {
      final isCurrent = _isCurrentConnectionTestOperation(requestGeneration);
      if (_isCurrentSettingsTest(requestRevision, isCurrent)) {
        _applyErrorMessage(userMessageFor(error));
      }
    } finally {
      _finishConnectionTestOperation(requestGeneration);
    }
  }

  Future<void> testVisionConnection(
      APIConfig draftConfig, String draftKey) async {
    if (_isSettingsTestBusy) return;
    final requestGeneration = _beginVisionTestOperation();
    final requestRevision = _captureSettingsRevision();
    _notifyControllerListeners();
    try {
      final previousFingerprint = apiConfigSourceFingerprint(config, apiKey);
      final normalized = normalizeApiConfig(draftConfig);
      final trimmedKey = cleanAPIKeyInput(draftKey) ?? '';
      validateApiConfig(normalized);
      validateVisionTestConfig(normalized);
      await _api.testVisionConnection(normalized, trimmedKey);
      final isCurrent = _isCurrentVisionTestOperation(requestGeneration);
      if (!_isCurrentSettingsTest(requestRevision, isCurrent)) {
        return;
      }
      final didApply = await _applySuccessfulSettingsTest(
        normalized: normalized,
        trimmedKey: trimmedKey,
        previousFingerprint: previousFingerprint,
      );
      if (!didApply) {
        return;
      }
      _applyStatusMessage('视觉模型测试成功，配置已保存');
    } catch (error) {
      final isCurrent = _isCurrentVisionTestOperation(requestGeneration);
      if (_isCurrentSettingsTest(requestRevision, isCurrent)) {
        _applyErrorMessage('视觉模型测试失败：${userMessageFor(error)}');
      }
    } finally {
      _finishVisionTestOperation(requestGeneration);
    }
  }

  bool _isCurrentSettingsTest(int settingsRevision, bool isCurrentOperation) =>
      _isCurrentSettingsRevision(settingsRevision) && isCurrentOperation;

  bool get _isSettingsTestBusy =>
      isFetchingModels || isTestingConnection || isTestingVision;

  Future<bool> _applySuccessfulSettingsTest({
    required APIConfig normalized,
    required String trimmedKey,
    required String previousFingerprint,
  }) async {
    config = normalized;
    apiKey = trimmedKey;
    final saveRevision = _beginSettingsMutation();
    final saveClearRevision = _captureLocalDataClearRevision();
    _clearAvailableModelsIfSourceChanged(previousFingerprint);
    return _persistCurrentSettingsForRevision(
      revision: saveRevision,
      clearRevision: saveClearRevision,
    );
  }
}
