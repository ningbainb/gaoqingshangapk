part of 'app_state.dart';

extension AppControllerSimulation on AppController {
  Future<void> startSimulation(
    PersonProfile profile, {
    bool resetScenario = false,
  }) async {
    if (_isDuplicateOpeningSimulation(profile, resetScenario: resetScenario)) {
      return;
    }
    _beginSimulationSession(profile, resetScenario: resetScenario);
    await _runSimulationTurn(null);
  }

  Future<bool> submitSimulationReply(String reply) async {
    final trimmed = cleanSimulationReplyInput(reply);
    if (trimmed == null || isBusy) return false;
    simulationMessages
        .add(SimulationMessage(speaker: SimulationSpeaker.user, text: trimmed));
    return _runSimulationTurn(trimmed);
  }

  bool _isDuplicateOpeningSimulation(
    PersonProfile profile, {
    required bool resetScenario,
  }) =>
      isBusy &&
      simulationMessages.isEmpty &&
      simulationResponse == null &&
      _openingSimulationScenario ==
          (resetScenario ? SimulationScenario.dailyChat : simulationScenario) &&
      personProfileIdsMatch(simulationProfile?.id, profile.normalized().id) &&
      _openingSimulationScenario != null;

  Future<bool> _runSimulationTurn(String? userReply) async {
    final profile = simulationProfile;
    if (profile == null) return false;
    final turn = _beginSimulationTurn();
    final rollbackUserReplyIndex =
        userReply == null ? null : simulationMessages.length - 1;
    _clearFeedbackMessages();
    _notifyControllerListeners();
    try {
      final response = (await _api.runSimulationTurn(
        profile: profile,
        scenario: simulationScenario,
        history: simulationMessages,
        userReply: userReply,
        personalizationContext: personalizationPromptContext(),
        config: config,
        apiKey: apiKey,
      ))
          .normalized();
      if (!_isCurrentSimulationTurn(
        contentRevision: turn.contentRevision,
        simulationRevision: turn.simulationRevision,
        profileId: profile.id,
      )) {
        return false;
      }
      simulationMessages.add(SimulationMessage(
          speaker: SimulationSpeaker.persona, text: response.personaMessage));
      simulationMessages = cleanSimulationMessages(simulationMessages);
      simulationResponse = response;
      _clearFeedbackMessages();
      return true;
    } catch (error) {
      if (!_isCurrentSimulationTurn(
        contentRevision: turn.contentRevision,
        simulationRevision: turn.simulationRevision,
        profileId: profile.id,
      )) {
        return false;
      }
      if (rollbackUserReplyIndex != null &&
          rollbackUserReplyIndex >= 0 &&
          rollbackUserReplyIndex < simulationMessages.length &&
          simulationMessages[rollbackUserReplyIndex].speaker ==
              SimulationSpeaker.user &&
          simulationMessages[rollbackUserReplyIndex].text == userReply) {
        simulationMessages.removeAt(rollbackUserReplyIndex);
      }
      _applyErrorMessage(userMessageFor(error));
      return false;
    } finally {
      _finishSimulationTurn(
        busyRevision: turn.busyRevision,
        contentRevision: turn.contentRevision,
        simulationRevision: turn.simulationRevision,
        profileId: profile.id,
      );
    }
  }
}
