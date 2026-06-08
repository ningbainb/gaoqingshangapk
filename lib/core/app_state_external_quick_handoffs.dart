part of 'app_state.dart';

extension AppControllerExternalQuickHandoffs on AppController {
  void setQuickImagePath(
    String path, {
    bool autoGenerate = false,
    bool resetDraft = false,
  }) {
    final nextPath = _normalizedExternalImagePath(path);
    final previousPath = quickImagePath;
    final previousSharedPath = sharedImagePath;
    if (resetDraft) {
      _resetImageDraftForExternalInput(exceptPath: nextPath);
    }
    _setPendingExternalHandoff(
      quickPath: nextPath,
      autoGenerateQuickReply: autoGenerate && nextPath != null,
      resetQuickDraft: resetDraft,
    );
    _deleteOwnedTransientImageIfChanged(previousPath, nextPath);
    _deleteOwnedTransientImageIfChanged(previousSharedPath, nextPath);
    _notifyControllerListeners();
  }

  void requestQuickClipboardImport({bool autoGenerate = true}) {
    final previousPath = quickImagePath;
    final previousSharedPath = sharedImagePath;
    _resetImageDraftForExternalInput(exceptPath: previousPath);
    _clearCurrentImagePathIfMatches(previousPath);
    _setPendingExternalHandoff(
      readQuickClipboard: true,
      autoGenerateQuickReply: autoGenerate,
      resetQuickDraft: true,
    );
    _deleteOwnedTransientImage(previousPath);
    _deleteOwnedTransientImage(previousSharedPath);
    _notifyControllerListeners();
  }

  bool consumeQuickDraftResetRequest() {
    if (!shouldResetQuickReplyDraft) return false;
    shouldResetQuickReplyDraft = false;
    _notifyControllerListeners();
    return true;
  }

  bool consumeQuickClipboardImportRequest() {
    if (!shouldReadQuickClipboardOnOpen) return false;
    shouldReadQuickClipboardOnOpen = false;
    _notifyControllerListeners();
    return true;
  }

  bool consumeQuickAutoGenerate(String imagePath) {
    final nextPath = _normalizedExternalImagePath(imagePath);
    final pendingPath = _normalizedExternalImagePath(quickImagePath);
    if (quickImagePath != null && pendingPath == null) {
      quickImagePath = null;
      if (shouldAutoGenerateQuickReply) {
        shouldAutoGenerateQuickReply = false;
      }
      _notifyControllerListeners();
      return false;
    }
    if (nextPath == null ||
        !shouldAutoGenerateQuickReply ||
        pendingPath != nextPath) {
      return false;
    }
    shouldAutoGenerateQuickReply = false;
    _notifyControllerListeners();
    return true;
  }

  void clearPendingQuickAutoGenerate() {
    if (!shouldAutoGenerateQuickReply) return;
    shouldAutoGenerateQuickReply = false;
    _notifyControllerListeners();
  }
}
