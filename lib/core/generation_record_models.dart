part of 'models.dart';

class GenerationRecord {
  GenerationRecord({
    String? id,
    required this.inputType,
    this.sceneSummary,
    this.platform,
    this.relationshipGuess,
    this.latestMessage,
    this.emotion,
    this.riskNotice,
    required this.selectedStyleName,
    this.userGoal,
    required this.replies,
    this.copiedReply,
    DateTime? createdAt,
  })  : id = id ?? _uuid.v4(),
        createdAt = createdAt ?? DateTime.now();

  final String id;
  final ChatInputType inputType;
  final String? sceneSummary;
  final String? platform;
  final String? relationshipGuess;
  final String? latestMessage;
  final String? emotion;
  final String? riskNotice;
  final String selectedStyleName;
  final String? userGoal;
  final List<ReplySuggestion> replies;
  String? copiedReply;
  final DateTime createdAt;

  factory GenerationRecord.fromJson(Map<String, dynamic> json) =>
      _generationRecordFromJson(json);

  GenerationRecord normalized() => GenerationRecord(
        id: id,
        inputType: inputType,
        sceneSummary: cleanPresentationText(sceneSummary),
        platform: cleanPresentationText(platform),
        relationshipGuess: cleanPresentationText(relationshipGuess),
        latestMessage: cleanPresentationText(latestMessage),
        emotion: cleanPresentationText(emotion),
        riskNotice: cleanPresentationText(riskNotice),
        selectedStyleName: cleanPresentationText(selectedStyleName) ?? '自然',
        userGoal: cleanPresentationText(userGoal),
        replies: cleanUniqueReplySuggestions(replies),
        copiedReply: cleanPresentationText(copiedReply),
        createdAt: createdAt,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'inputType': inputType.name,
        'sceneSummary': cleanPresentationText(sceneSummary),
        'platform': cleanPresentationText(platform),
        'relationshipGuess': cleanPresentationText(relationshipGuess),
        'latestMessage': cleanPresentationText(latestMessage),
        'emotion': cleanPresentationText(emotion),
        'riskNotice': cleanPresentationText(riskNotice),
        'selectedStyleName': cleanPresentationText(selectedStyleName) ?? '自然',
        'userGoal': cleanPresentationText(userGoal),
        'replies': cleanUniqueReplySuggestions(replies)
            .map((e) => e.toJson())
            .toList(),
        'copiedReply': cleanPresentationText(copiedReply),
        'createdAt': createdAt.toIso8601String(),
      };
}

ChatInputType _chatInputTypeValue(String? raw) {
  final normalized = raw == null ? null : normalizedLooseKey(raw);
  return switch (normalized) {
    'image' ||
    'screenshot' ||
    'screenimage' ||
    'photo' ||
    'picture' ||
    'vision' ||
    '图片' ||
    '截图' =>
      ChatInputType.image,
    _ => ChatInputType.text,
  };
}
