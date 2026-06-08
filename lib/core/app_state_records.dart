part of 'app_state.dart';

extension AppControllerRecords on AppController {
  Future<void> saveProfile(PersonProfile profile) async {
    final saved = profile.touch();
    final selectedBeforeSave = selectedProfile;
    final index =
        profiles.indexWhere((item) => personProfileIdsMatch(item.id, saved.id));
    if (index >= 0) {
      profiles[index] = saved;
    } else {
      profiles.insert(0, saved);
    }
    selectedProfile = saved;
    if (index < 0 &&
        currentGeneratedProfile == null &&
        currentResponse?.personInsight != null &&
        personProfileIdsMatch(selectedBeforeSave?.id, saved.id)) {
      currentGeneratedProfile = saved;
    }
    await _persistProfiles();
    _notifyControllerListeners();
  }

  Future<void> deleteProfile(PersonProfile profile) async {
    _invalidateContentOperations();
    profiles = profiles
        .where((item) => !personProfileIdsMatch(item.id, profile.id))
        .toList();
    _clearProfileRuntimeReferencesFor(profile.id);
    _clearSimulationSessionForProfile(profile.id);
    await _persistProfiles();
    _notifyControllerListeners();
  }

  Future<void> clearProfiles() async {
    _invalidateContentOperations();
    profiles = [];
    _clearProfileRuntimeReferences();
    _clearSimulationSession();
    await _persistProfiles();
    _notifyControllerListeners();
  }

  Future<void> deleteHistory(GenerationRecord record) async {
    history = history
        .where((item) => !historyRecordIdsMatch(item.id, record.id))
        .toList();
    _clearHistoryRuntimeReferencesFor(record.id);
    await _persistHistory();
    _notifyControllerListeners();
  }

  Future<void> clearHistory() async {
    _invalidateContentOperations();
    history = [];
    _clearHistoryRuntimeReferences();
    await _persistHistory();
    _notifyControllerListeners();
  }

  void selectHistoryRecord(GenerationRecord record) {
    selectedHistoryRecord = retainedHistoryRecord(history, record);
    _notifyControllerListeners();
  }

  void selectProfile(PersonProfile? profile) {
    selectedProfile = retainedPersonProfile(profiles, profile) ?? profile;
    _notifyControllerListeners();
  }
}
