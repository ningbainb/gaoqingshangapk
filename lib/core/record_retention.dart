import 'models.dart';
import 'history_record_collection_helpers.dart';

List<GenerationRecord> normalizedHistoryRecords(
  List<GenerationRecord> records, {
  required int maxCount,
}) {
  final sorted = records.map(_normalizedHistoryRecord).toList()
    ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  return sorted.take(maxCount).toList();
}

List<PersonProfile> normalizedPersonProfiles(
  List<PersonProfile> profiles, {
  required int maxCount,
}) {
  final sorted = profiles.map(_normalizedPersonProfile).toList()
    ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  return sorted.take(maxCount).toList();
}

GenerationRecord _normalizedHistoryRecord(GenerationRecord record) {
  final normalized = record.normalized();
  return _sameHistoryRecord(record, normalized) ? record : normalized;
}

PersonProfile _normalizedPersonProfile(PersonProfile profile) {
  final normalized = profile.normalized();
  return personProfileValuesEqual(profile, normalized) ? profile : normalized;
}

bool _sameHistoryRecord(GenerationRecord left, GenerationRecord right) {
  return left.id == right.id &&
      left.inputType == right.inputType &&
      left.sceneSummary == right.sceneSummary &&
      left.platform == right.platform &&
      left.relationshipGuess == right.relationshipGuess &&
      left.latestMessage == right.latestMessage &&
      left.emotion == right.emotion &&
      left.riskNotice == right.riskNotice &&
      left.selectedStyleName == right.selectedStyleName &&
      left.userGoal == right.userGoal &&
      _sameReplySuggestions(left.replies, right.replies) &&
      left.copiedReply == right.copiedReply &&
      left.createdAt == right.createdAt;
}

bool _sameReplySuggestions(
  List<ReplySuggestion> left,
  List<ReplySuggestion> right,
) {
  if (left.length != right.length) return false;
  for (var index = 0; index < left.length; index += 1) {
    final a = left[index];
    final b = right[index];
    if (a.id != b.id ||
        a.styleLabel != b.styleLabel ||
        a.text != b.text ||
        a.reason != b.reason) {
      return false;
    }
  }
  return true;
}

bool personProfileValuesEqual(PersonProfile left, PersonProfile right) {
  return left.id == right.id &&
      left.displayName == right.displayName &&
      _sameStrings(left.aliases, right.aliases) &&
      left.relationship == right.relationship &&
      left.communicationStyle == right.communicationStyle &&
      _sameStrings(left.personalityTraits, right.personalityTraits) &&
      _sameStrings(left.innerNeeds, right.innerNeeds) &&
      _sameStrings(left.keyPersonPoints, right.keyPersonPoints) &&
      _sameStrings(left.momentsInsights, right.momentsInsights) &&
      _sameStrings(left.tonePreferences, right.tonePreferences) &&
      _sameStrings(left.boundaries, right.boundaries) &&
      _sameStrings(left.facts, right.facts) &&
      left.lastSceneSummary == right.lastSceneSummary &&
      left.lastUpdateReason == right.lastUpdateReason &&
      left.confidence == right.confidence &&
      left.createdAt == right.createdAt &&
      left.updatedAt == right.updatedAt;
}

bool _sameStrings(List<String> left, List<String> right) {
  if (left.length != right.length) return false;
  for (var index = 0; index < left.length; index += 1) {
    if (left[index] != right[index]) return false;
  }
  return true;
}

GenerationRecord? retainedHistoryRecord(
  List<GenerationRecord> history,
  GenerationRecord? record,
) {
  if (record == null) return null;
  return historyRecordById(history, record.id);
}

PersonProfile? retainedPersonProfile(
  List<PersonProfile> profiles,
  PersonProfile? profile,
) {
  if (profile == null) return null;
  return personProfileById(profiles, profile.id);
}
