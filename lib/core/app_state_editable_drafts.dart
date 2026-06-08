part of 'app_state.dart';

extension AppControllerEditableDrafts on AppController {
  void clearEditableTextDraft() {
    final changed = _clearEditableDraftSource(ChatInputType.text);
    if (changed) _notifyControllerListeners();
  }

  Future<void> clearEditableImageDraft() async {
    final path =
        currentInputType == ChatInputType.image ? currentImagePath : null;
    final changed = _clearEditableDraftSource(ChatInputType.image);
    if (changed) _notifyControllerListeners();
    await _fileCleaner.deleteOwnedTransientImageFile(path);
  }

  bool _clearEditableDraftSource(ChatInputType type) {
    var changed = false;

    if (type == ChatInputType.text &&
        currentInputType == ChatInputType.text &&
        currentTextInput != null) {
      currentTextInput = null;
      changed = true;
    }

    if (type == ChatInputType.image &&
        currentInputType == ChatInputType.image &&
        currentImagePath != null) {
      currentImagePath = null;
      changed = true;
    }

    if (lastInput?.type == type) {
      lastInput = null;
      changed = true;
    }

    return changed;
  }
}
