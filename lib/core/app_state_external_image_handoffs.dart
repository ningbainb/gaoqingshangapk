part of 'app_state.dart';

extension AppControllerExternalImageHandoffs on AppController {
  void setSharedImagePath(String path) {
    final nextPath = _normalizedExternalImagePath(path);
    final previousPath = sharedImagePath;
    final previousQuickPath = quickImagePath;
    _resetImageDraftForExternalInput(exceptPath: nextPath);
    _setPendingExternalHandoff(sharedPath: nextPath);
    _deleteOwnedTransientImageIfChanged(previousPath, nextPath);
    _deleteOwnedTransientImageIfChanged(previousQuickPath, nextPath);
    _notifyControllerListeners();
  }

  String? consumeSharedImagePath() {
    final path = _normalizedExternalImagePath(sharedImagePath);
    if (path == null) {
      if (sharedImagePath != null) {
        sharedImagePath = null;
        _notifyControllerListeners();
      }
      return null;
    }
    sharedImagePath = null;
    _notifyControllerListeners();
    return path;
  }

  void prepareExternalImageInput() {
    final previousSharedPath = sharedImagePath;
    final previousQuickPath = quickImagePath;
    _resetImageDraftForExternalInput();
    _setPendingExternalHandoff();
    _deleteOwnedTransientImage(previousSharedPath);
    _deleteOwnedTransientImage(previousQuickPath);
    _notifyControllerListeners();
  }
}
