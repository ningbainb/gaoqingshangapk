part of 'app_state.dart';

extension AppControllerRegeneration on AppController {
  bool get canRegenerate =>
      lastInput != null && !isBusy && !_isReplyGenerationBusy;

  Future<void> regenerateLast() async {
    final input = lastInput;
    if (input == null || isBusy || _isReplyGenerationBusy) return;
    final replyBusyRevision = _beginReplyGenerationOperation();
    await _generate(
      _inputForRegeneration(input),
      selectedProfileId: currentSelectedProfileId,
      imagePath: currentImagePath,
      replyBusyRevision: replyBusyRevision,
    );
  }
}
