part of 'app_state.dart';

extension AppControllerClipboardActions on AppController {
  Future<bool> copyReply(ReplySuggestion reply) async {
    final text = cleanPresentationText(reply.text);
    if (text == null) return false;
    final requestGeneration = _captureGenerationRevision();
    bool isCurrentCopy() => _isCurrentGenerationRevision(requestGeneration);
    if (!await _copyToClipboard(text, isCurrent: isCurrentCopy)) return false;
    if (!isCurrentCopy()) return false;
    return _markCopiedReply(text, generationRevision: requestGeneration);
  }

  Future<void> markNativeCopiedReply(String text) async {
    final trimmed = cleanPresentationText(text);
    if (trimmed == null) return;
    final requestGeneration = _captureGenerationRevision();
    final matchedReply = currentResponse?.replies
        .map((reply) => cleanPresentationText(reply.text))
        .contains(trimmed);
    if (matchedReply != true) return;
    await _markCopiedReply(
      trimmed,
      generationRevision: requestGeneration,
    );
  }

  Future<bool> _markCopiedReply(
    String text, {
    int? generationRevision,
  }) async {
    final copiedReply = cleanPresentationText(text);
    if (copiedReply == null) return false;
    if (generationRevision != null &&
        !_isCurrentGenerationRevision(generationRevision)) {
      return false;
    }
    if (currentRecordId != null) {
      final update = markCopiedReplyForCurrentRecord(
        history: history,
        selectedHistoryRecord: selectedHistoryRecord,
        currentRecordId: currentRecordId!,
        copiedReply: copiedReply,
      );
      selectedHistoryRecord = update.selectedHistoryRecord;
      if (update.recordFound) {
        await _persistHistory();
      } else {
        final didSave = await _saveCurrentResponseAsHistory(
          copiedReply: copiedReply,
          generationRevision: generationRevision,
        );
        if (!didSave) return false;
      }
    } else {
      final didSave = await _saveCurrentResponseAsHistory(
        copiedReply: copiedReply,
        generationRevision: generationRevision,
      );
      if (!didSave) return false;
    }
    if (generationRevision != null &&
        !_isCurrentGenerationRevision(generationRevision)) {
      return false;
    }
    _setStatusMessage('已复制');
    return true;
  }

  Future<bool> copyHistoryText(String text, GenerationRecord record) async {
    final trimmed = cleanPresentationText(text);
    if (trimmed == null) return false;
    bool isCurrentCopy() => retainedHistoryRecord(history, record) != null;
    if (!isCurrentCopy()) return false;
    if (!await _copyToClipboard(trimmed, isCurrent: isCurrentCopy)) {
      return false;
    }
    if (!isCurrentCopy()) return false;
    final update = markCopiedReplyForHistoryRecord(
      history: history,
      selectedHistoryRecord: selectedHistoryRecord,
      record: record,
      copiedReply: trimmed,
    );
    selectedHistoryRecord = update.selectedHistoryRecord;
    if (update.historyChanged) await _persistHistory();
    if (!isCurrentCopy()) return false;
    _setStatusMessage('已复制');
    return true;
  }

  Future<bool> copyProfileSummary(PersonProfile profile) async {
    final requestRevision = _captureProfilesRevision();
    bool isCurrentCopy() => _isCurrentProfilesRevision(requestRevision);
    if (!await _copyToClipboard(
      profile.summaryForPrompt,
      isCurrent: isCurrentCopy,
    )) {
      return false;
    }
    if (!isCurrentCopy()) return false;
    _setStatusMessage('已复制画像上下文');
    return true;
  }

  Future<bool> _copyToClipboard(String text,
      {bool Function()? isCurrent}) async {
    try {
      await Clipboard.setData(ClipboardData(text: text));
      return true;
    } catch (error) {
      if (isCurrent != null && !isCurrent()) return false;
      _setErrorMessage('复制失败：${userMessageFor(error)}');
      return false;
    }
  }

  Future<void> finishQuickReplySession() async {
    final path = quickImagePath;
    _clearQuickReplySessionState();
    lastInput = null;
    _clearCurrentImagePathIfMatches(path);
    await _fileCleaner.deleteOwnedTransientImageFile(path);
    _notifyControllerListeners();
  }

  Future<void> discardTransientImagePath(String? path) =>
      _fileCleaner.deleteOwnedTransientImageFile(path);
}
