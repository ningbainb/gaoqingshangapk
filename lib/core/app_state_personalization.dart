part of 'app_state.dart';

extension AppControllerPersonalization on AppController {
  Future<void> savePersonalization(ReplyPersonalizationSettings next,
      {bool notify = true}) async {
    final requestRevision = _beginPreferencesMutation();
    final requestClearRevision = _captureLocalDataClearRevision();
    personalization = next.normalized();
    final refreshedDefaultStyle = _availableStyleMatching(defaultStyle);
    var shouldPersistDefaultStyle = false;
    if (refreshedDefaultStyle == null) {
      defaultStyle = ChatStyle.defaultStyle;
      shouldPersistDefaultStyle = true;
    } else {
      defaultStyle = refreshedDefaultStyle;
    }
    currentStyle = _availableStyleMatching(currentStyle) ?? defaultStyle;
    final input = lastInput;
    if (input != null) {
      final selectedStyle =
          _availableStyleMatching(input.selectedStyle) ?? defaultStyle;
      lastInput = ChatInput(
        type: input.type,
        text: input.text,
        imagePayload: input.imagePayload,
        userGoal: input.userGoal,
        selectedStyle: selectedStyle,
        personProfileContext: input.personProfileContext,
        personalizationContext: input.personalizationContext,
      );
    }
    final didPersist = await _persistPreferencesForRevision(
      revision: requestRevision,
      clearRevision: requestClearRevision,
      persistCurrent: () => _persistCurrentPersonalization(
          persistDefaultStyle: shouldPersistDefaultStyle),
      persistLatest: () =>
          _persistCurrentPersonalization(persistDefaultStyle: true),
      clearPersisted: _clearPersistedPersonalization,
    );
    if (!didPersist) {
      return;
    }
    if (notify) _notifyControllerListeners();
  }

  Future<void> _persistCurrentPersonalization(
      {required bool persistDefaultStyle}) async {
    await _store.savePersonalization(personalization);
    if (persistDefaultStyle) {
      await _store.saveDefaultStyleId(defaultStyle.id);
    }
  }

  Future<void> _persistDefaultStyleId() async {
    await _store.saveDefaultStyleId(defaultStyle.id);
  }

  Future<void> _clearPersistedPersonalization() async {
    await _store.clearPersonalization();
    await _store.clearDefaultStyleId();
  }

  Future<bool> _persistPreferencesForRevision({
    required int revision,
    required int clearRevision,
    required Future<void> Function() persistCurrent,
    required Future<void> Function() persistLatest,
    required Future<void> Function() clearPersisted,
  }) async {
    await persistCurrent();
    if (_isCurrentPreferencesRevision(revision)) return true;

    if (!_isCurrentLocalDataClearRevision(clearRevision)) {
      await clearPersisted();
      return false;
    }
    await persistLatest();
    return true;
  }

  ChatStyle? _availableStyleMatching(ChatStyle style) {
    for (final item in personalization.availableStyles) {
      if (chatStyleIdsMatch(item.id, style.id)) return item;
    }
    return chatStyleByName(
      personalization.availableStyles,
      style.name,
      preferOfficial: style.isOfficial,
    );
  }

  Future<void> setDefaultStyle(ChatStyle style) async {
    final requestRevision = _beginPreferencesMutation();
    final requestClearRevision = _captureLocalDataClearRevision();
    final previousDefaultStyle = defaultStyle;
    defaultStyle = _availableStyleMatching(style) ?? ChatStyle.defaultStyle;
    if (chatStyleIdsMatch(currentStyle.id, previousDefaultStyle.id)) {
      currentStyle = defaultStyle;
    }
    final didPersist = await _persistPreferencesForRevision(
      revision: requestRevision,
      clearRevision: requestClearRevision,
      persistCurrent: _persistDefaultStyleId,
      persistLatest: _persistDefaultStyleId,
      clearPersisted: _store.clearDefaultStyleId,
    );
    if (!didPersist) {
      return;
    }
    _notifyControllerListeners();
  }
}
