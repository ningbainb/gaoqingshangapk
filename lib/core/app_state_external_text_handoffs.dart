part of 'app_state.dart';

extension AppControllerExternalTextHandoffs on AppController {
  void setSharedText(String text) {
    final cleanedText = cleanChatTextInput(text);
    if (cleanedText == null) {
      prepareExternalTextInput();
      return;
    }
    final previousSharedPath = sharedImagePath;
    final previousQuickPath = quickImagePath;
    _resetTextDraftForExternalInput();
    _setPendingExternalHandoff(text: cleanedText);
    _deleteOwnedTransientImage(previousSharedPath);
    _deleteOwnedTransientImage(previousQuickPath);
    _notifyControllerListeners();
  }

  void prepareExternalTextInput() {
    final previousSharedPath = sharedImagePath;
    final previousQuickPath = quickImagePath;
    _resetTextDraftForExternalInput();
    _setPendingExternalHandoff();
    _deleteOwnedTransientImage(previousSharedPath);
    _deleteOwnedTransientImage(previousQuickPath);
    _notifyControllerListeners();
  }

  String? consumeSharedText() {
    final text = sharedText;
    if (text == null) return null;
    sharedText = null;
    _notifyControllerListeners();
    return cleanChatTextInput(text);
  }
}
