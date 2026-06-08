part of 'app_state.dart';

extension AppControllerExternalHandoffInternals on AppController {
  void _resetImageDraftForExternalInput({String? exceptPath}) {
    final previousPath = currentImagePath;
    final protectedPath = _normalizedExternalImagePath(exceptPath);
    currentInputType = ChatInputType.image;
    _resetEditableDraftState();
    if (_normalizedExternalImagePath(previousPath) != protectedPath) {
      unawaited(_fileCleaner.deleteOwnedTransientImageFile(previousPath));
    }
  }

  void _resetTextDraftForExternalInput() {
    final previousImagePath = currentImagePath;
    currentInputType = ChatInputType.text;
    _resetEditableDraftState();
    unawaited(_fileCleaner.deleteOwnedTransientImageFile(previousImagePath));
  }

  void _resetEditableDraftState() {
    _setPendingGenerationSource(
      type: currentInputType,
      style: defaultStyle,
    );
  }

  void _setPendingExternalHandoff({
    String? quickPath,
    String? sharedPath,
    String? text,
    bool readQuickClipboard = false,
    bool autoGenerateQuickReply = false,
    bool resetQuickDraft = false,
  }) {
    quickImagePath = _normalizedExternalImagePath(quickPath);
    sharedImagePath = _normalizedExternalImagePath(sharedPath);
    sharedText = text;
    isQuickReplySession = false;
    shouldReadQuickClipboardOnOpen = readQuickClipboard;
    shouldAutoGenerateQuickReply = autoGenerateQuickReply;
    shouldResetQuickReplyDraft = resetQuickDraft;
    _clearFeedbackFields();
  }

  void _clearQuickReplySessionState() {
    quickImagePath = null;
    isQuickReplySession = false;
    shouldReadQuickClipboardOnOpen = false;
    shouldAutoGenerateQuickReply = false;
    shouldResetQuickReplyDraft = false;
  }

  void _clearFeedbackFields() {
    _clearFeedbackMessages();
  }

  void _deleteOwnedTransientImageIfChanged(String? path, String? nextPath) {
    if (_normalizedExternalImagePath(path) !=
        _normalizedExternalImagePath(nextPath)) {
      _deleteOwnedTransientImage(path);
    }
  }

  void _deleteOwnedTransientImage(String? path) {
    unawaited(_fileCleaner.deleteOwnedTransientImageFile(path));
  }

  String? _normalizedExternalImagePath(String? path) =>
      _normalizedGenerationImagePath(path);
}
