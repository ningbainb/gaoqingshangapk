import 'models.dart';

String? normalizedHistoryRecordId(String? id) {
  return cleanIdentifierText(id);
}

bool historyRecordIdsMatch(String? left, String? right) {
  final normalizedLeft = normalizedHistoryRecordId(left);
  final normalizedRight = normalizedHistoryRecordId(right);
  return normalizedLeft != null &&
      normalizedRight != null &&
      normalizedLeft == normalizedRight;
}

GenerationRecord? historyRecordById(
  Iterable<GenerationRecord> history,
  String? id,
) {
  final normalizedId = normalizedHistoryRecordId(id);
  if (normalizedId == null) return null;
  for (final record in history) {
    if (historyRecordIdsMatch(record.id, normalizedId)) return record;
  }
  return null;
}

String? restorableHistoryRecordId(
  Iterable<GenerationRecord> history,
  String? selectedRecordId,
) {
  return historyRecordById(history, selectedRecordId)?.id;
}
