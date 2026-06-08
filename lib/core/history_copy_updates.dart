import 'history_record_collection_helpers.dart';
import 'models.dart';
import 'presentation_text_helpers.dart';

class CopiedReplyUpdate {
  const CopiedReplyUpdate({
    required this.recordFound,
    required this.historyChanged,
    required this.selectedHistoryRecord,
  });

  final bool recordFound;
  final bool historyChanged;
  final GenerationRecord? selectedHistoryRecord;
}

CopiedReplyUpdate markCopiedReplyForCurrentRecord({
  required List<GenerationRecord> history,
  required GenerationRecord? selectedHistoryRecord,
  required String currentRecordId,
  required String copiedReply,
}) {
  final cleanedCopiedReply = cleanPresentationText(copiedReply);
  if (cleanedCopiedReply == null) {
    return CopiedReplyUpdate(
      recordFound: false,
      historyChanged: false,
      selectedHistoryRecord: selectedHistoryRecord,
    );
  }
  final index = history.indexWhere(
      (record) => historyRecordIdsMatch(record.id, currentRecordId));
  if (index < 0) {
    return CopiedReplyUpdate(
      recordFound: false,
      historyChanged: false,
      selectedHistoryRecord: selectedHistoryRecord,
    );
  }

  history[index].copiedReply = cleanedCopiedReply;
  return CopiedReplyUpdate(
    recordFound: true,
    historyChanged: true,
    selectedHistoryRecord:
        historyRecordIdsMatch(selectedHistoryRecord?.id, history[index].id)
            ? history[index]
            : selectedHistoryRecord,
  );
}

CopiedReplyUpdate markCopiedReplyForHistoryRecord({
  required List<GenerationRecord> history,
  required GenerationRecord? selectedHistoryRecord,
  required GenerationRecord record,
  required String copiedReply,
}) {
  final cleanedCopiedReply = cleanPresentationText(copiedReply);
  if (cleanedCopiedReply == null) {
    return CopiedReplyUpdate(
      recordFound: false,
      historyChanged: false,
      selectedHistoryRecord: selectedHistoryRecord,
    );
  }
  final index =
      history.indexWhere((item) => historyRecordIdsMatch(item.id, record.id));
  if (index >= 0) {
    history[index].copiedReply = cleanedCopiedReply;
    return CopiedReplyUpdate(
      recordFound: true,
      historyChanged: true,
      selectedHistoryRecord: history[index],
    );
  }

  if (historyRecordIdsMatch(selectedHistoryRecord?.id, record.id)) {
    selectedHistoryRecord!.copiedReply = cleanedCopiedReply;
    return CopiedReplyUpdate(
      recordFound: false,
      historyChanged: false,
      selectedHistoryRecord: selectedHistoryRecord,
    );
  }

  return CopiedReplyUpdate(
    recordFound: false,
    historyChanged: false,
    selectedHistoryRecord: selectedHistoryRecord,
  );
}
