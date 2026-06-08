part of 'app_state.dart';

const _customBackgroundExportMaxWidth = 2560.0;
const _customBackgroundExportQuality = 0.86;

extension AppControllerAppearance on AppController {
  Future<void> saveAppearance(AppearanceSettings next) async {
    final requestRevision = _beginAppearanceMutation();
    final requestClearRevision = _captureLocalDataClearRevision();
    appearance = next.normalized();
    if (isAppearanceFeedbackMessage(statusMessage)) statusMessage = null;
    if (isAppearanceFeedbackMessage(errorMessage)) errorMessage = null;
    final didPersist = await _persistAppearanceForRevision(
      revision: requestRevision,
      clearRevision: requestClearRevision,
    );
    if (!didPersist) {
      return;
    }
    _notifyControllerListeners();
  }

  Future<bool> _persistAppearanceForRevision({
    required int revision,
    required int clearRevision,
  }) async {
    await _store.saveAppearance(appearance);
    if (_isCurrentAppearanceRevision(revision)) return true;

    if (!_isCurrentLocalDataClearRevision(clearRevision)) {
      await _store.clearAppearance();
      return false;
    }
    await _store.saveAppearance(appearance);
    return true;
  }

  Future<void> importCustomBackground(String sourcePath) async {
    final requestRevision = _beginBackgroundImportOperation();
    final cleanedSourcePath = cleanImagePathInput(sourcePath);
    if (cleanedSourcePath == null) {
      _setErrorMessage('$customBackgroundFailurePrefix：无法读取所选图片，请重新选择。');
      return;
    }
    String? outputPath;
    try {
      final dir = await _supportDirectoryProvider();
      final previousPath = appearance.customBackgroundPath;
      final file = File(
          '${dir.path}/custom-background-${DateTime.now().microsecondsSinceEpoch}.jpg');
      outputPath = file.path;
      await _imageService.saveJpegCopy(
        cleanedSourcePath,
        file.path,
        maxWidth: _customBackgroundExportMaxWidth,
        quality: _customBackgroundExportQuality,
      );
      if (!_isCurrentBackgroundImportOperation(requestRevision)) {
        await _fileCleaner.deleteCustomBackground(outputPath);
        return;
      }
      await saveAppearance(
          appearance.copyWith(customBackgroundPath: file.path));
      if (!_isCurrentBackgroundImportOperation(requestRevision)) {
        await _deleteStaleCustomBackgroundImport(
          outputPath: outputPath,
          previousPath: previousPath,
        );
        return;
      }
      await _fileCleaner.deleteCustomBackground(previousPath);
      _setStatusMessage(customBackgroundImportedMessage);
    } catch (error) {
      if (!_isCurrentBackgroundImportOperation(requestRevision)) {
        await _fileCleaner.deleteCustomBackground(outputPath);
        return;
      }
      _setErrorMessage('$customBackgroundFailurePrefix：$error');
    }
  }

  Future<void> _deleteStaleCustomBackgroundImport({
    required String? outputPath,
    required String? previousPath,
  }) async {
    await _fileCleaner.deleteCustomBackground(outputPath);
    if (cleanImagePathInput(appearance.customBackgroundPath) !=
        cleanImagePathInput(previousPath)) {
      await _fileCleaner.deleteCustomBackground(previousPath);
    }
  }

  Future<void> resetAppearance() async {
    await saveAppearance(AppearanceSettings.defaults.copyWith(
      customBackgroundPath: appearance.customBackgroundPath,
    ));
  }

  Future<void> resetCustomBackground() async {
    _invalidateBackgroundImportOperation();
    final requestRevision = _captureBackgroundOperationRevision();
    final previousPath = appearance.customBackgroundPath;
    await _fileCleaner.deleteCustomBackground(previousPath);
    await saveAppearance(appearance.copyWith(clearCustomBackground: true));
    if (_isCurrentBackgroundImportOperation(requestRevision) &&
        hasUsableImagePath(previousPath)) {
      _setStatusMessage(customBackgroundResetMessage);
    }
  }
}
