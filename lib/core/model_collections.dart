part of 'models.dart';

enum HistoryFilterMode { all, image, text, copied }

List<APIModel> normalizedApiModels(Iterable<APIModel> models) {
  final byNormalizedId = <String, APIModel>{};
  for (final model in models) {
    final id = cleanModelId(model.id);
    if (id.isEmpty) continue;
    final normalized = normalizedModelId(id);
    final existing = byNormalizedId[normalized];
    if (existing == null) {
      byNormalizedId[normalized] = APIModel(
        id: id,
        ownedBy: cleanPresentationText(model.ownedBy),
        capability: model.capability,
      );
      continue;
    }
    final existingCapability = existing.capability;
    final nextCapability = model.capability;
    final mergedCapability =
        existingCapability == null && nextCapability == null
            ? null
            : ModelCapability(
                isMultimodal: (existingCapability?.isMultimodal ?? false) ||
                    (nextCapability?.isMultimodal ?? false),
                isReasoning: (existingCapability?.isReasoning ?? false) ||
                    (nextCapability?.isReasoning ?? false),
              );
    byNormalizedId[normalized] = APIModel(
      id: existing.id,
      ownedBy: existing.ownedBy ?? cleanPresentationText(model.ownedBy),
      capability: mergedCapability,
    );
  }
  return byNormalizedId.values.toList()
    ..sort((a, b) => localizedStandardLikeCompare(a.id, b.id));
}

extension HistoryFilterModeLogic on HistoryFilterMode {
  String get label => switch (this) {
        HistoryFilterMode.all => '全部',
        HistoryFilterMode.image => '截图',
        HistoryFilterMode.text => '文本',
        HistoryFilterMode.copied => '已复制',
      };

  bool includes(GenerationRecord record) {
    return switch (this) {
      HistoryFilterMode.all => true,
      HistoryFilterMode.image => record.inputType == ChatInputType.image,
      HistoryFilterMode.text => record.inputType == ChatInputType.text,
      HistoryFilterMode.copied => record.hasCopiedReply,
    };
  }
}

extension GenerationRecordSearch on GenerationRecord {
  String? get cleanCopiedReply => cleanPresentationText(copiedReply);

  bool get hasCopiedReply => cleanCopiedReply != null;

  List<String> get searchableMetadataValues => uniqueCleanPresentationList([
        sceneSummary,
        platform,
        relationshipGuess,
        latestMessage,
        emotion,
        riskNotice,
        selectedStyleName,
        userGoal,
        cleanCopiedReply,
      ]);

  List<String> get searchableReplyValues => uniqueCleanPresentationList(
        cleanUniqueReplySuggestions(replies)
            .expand((reply) => [reply.text, reply.reason]),
      );

  String get searchableText =>
      [...searchableMetadataValues, ...searchableReplyValues].join(' ');
}

List<GenerationRecord> filterHistoryRecords(
  List<GenerationRecord> records, {
  required HistoryFilterMode mode,
  required String query,
}) {
  return records.where((record) {
    return mode.includes(record) &&
        textMatchesSearchQuery(record.searchableText, query);
  }).toList();
}
