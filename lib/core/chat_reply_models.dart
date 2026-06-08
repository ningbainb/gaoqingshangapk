part of 'models.dart';

class ReplySuggestion {
  ReplySuggestion({
    String? id,
    required this.styleLabel,
    required this.text,
    required this.reason,
  }) : id = _cleanIdentifier(id) ?? _uuid.v4();

  final String id;
  final String styleLabel;
  final String text;
  final String reason;

  factory ReplySuggestion.fromJson(Map<String, dynamic> json) =>
      _replySuggestionFromJson(json);

  ReplySuggestion normalized() => ReplySuggestion(
        id: cleanIdentifierText(id),
        styleLabel: cleanPresentationText(styleLabel) ?? '建议',
        text: cleanPresentationText(text) ?? '',
        reason: cleanPresentationText(reason) ?? '',
      );

  Map<String, dynamic> toJson() => {
        'id': cleanIdentifierText(id) ?? _uuid.v4(),
        'styleLabel': cleanPresentationText(styleLabel) ?? '建议',
        'text': cleanPresentationText(text) ?? '',
        'reason': cleanPresentationText(reason) ?? '',
      };
}

class PersonInsight {
  const PersonInsight({
    this.displayName,
    this.aliases,
    this.relationship,
    this.communicationStyle,
    this.personalityTraits,
    this.innerNeeds,
    this.keyPersonPoints,
    this.momentsInsights,
    this.tonePreferences,
    this.boundaries,
    this.facts,
    this.confidence,
    this.updateReason,
  });

  final String? displayName;
  final List<String>? aliases;
  final String? relationship;
  final String? communicationStyle;
  final List<String>? personalityTraits;
  final List<String>? innerNeeds;
  final List<String>? keyPersonPoints;
  final List<String>? momentsInsights;
  final List<String>? tonePreferences;
  final List<String>? boundaries;
  final List<String>? facts;
  final double? confidence;
  final String? updateReason;

  factory PersonInsight.fromJson(Map<String, dynamic> json) =>
      _personInsightModelFromJson(json);

  PersonInsight normalized() => PersonInsight(
        displayName: cleanPresentationText(displayName),
        aliases: _cleanOptionalInsightList(aliases),
        relationship: cleanPresentationText(relationship),
        communicationStyle: cleanPresentationText(communicationStyle),
        personalityTraits: _cleanOptionalInsightList(personalityTraits),
        innerNeeds: _cleanOptionalInsightList(innerNeeds),
        keyPersonPoints: _cleanOptionalInsightList(keyPersonPoints),
        momentsInsights: _cleanOptionalInsightList(momentsInsights),
        tonePreferences: _cleanOptionalInsightList(tonePreferences),
        boundaries: _cleanOptionalInsightList(boundaries),
        facts: _cleanOptionalInsightList(facts),
        confidence: confidence?.clamp(0, 1).toDouble(),
        updateReason: cleanPresentationText(updateReason),
      );

  Map<String, dynamic> toJson() => {
        'displayName': cleanPresentationText(displayName),
        'aliases': _cleanOptionalInsightList(aliases),
        'relationship': cleanPresentationText(relationship),
        'communicationStyle': cleanPresentationText(communicationStyle),
        'personalityTraits': _cleanOptionalInsightList(personalityTraits),
        'innerNeeds': _cleanOptionalInsightList(innerNeeds),
        'keyPersonPoints': _cleanOptionalInsightList(keyPersonPoints),
        'momentsInsights': _cleanOptionalInsightList(momentsInsights),
        'tonePreferences': _cleanOptionalInsightList(tonePreferences),
        'boundaries': _cleanOptionalInsightList(boundaries),
        'facts': _cleanOptionalInsightList(facts),
        'confidence': confidence?.clamp(0, 1).toDouble(),
        'updateReason': cleanPresentationText(updateReason),
      };
}

List<String>? _cleanOptionalInsightList(List<String>? values) =>
    values == null ? null : uniqueCleanPresentationList(values);

class ChatReplyResponse {
  const ChatReplyResponse({
    this.sceneSummary,
    this.platform,
    this.relationshipGuess,
    this.latestMessage,
    this.emotion,
    this.riskNotice,
    required this.replies,
    this.personInsight,
  });

  final String? sceneSummary;
  final String? platform;
  final String? relationshipGuess;
  final String? latestMessage;
  final String? emotion;
  final String? riskNotice;
  final List<ReplySuggestion> replies;
  final PersonInsight? personInsight;

  factory ChatReplyResponse.fromJson(Map<String, dynamic> json) =>
      _chatReplyResponseFromJson(json);

  ChatReplyResponse normalized() => ChatReplyResponse(
        sceneSummary: cleanPresentationText(sceneSummary),
        platform: cleanPresentationText(platform),
        relationshipGuess: cleanPresentationText(relationshipGuess),
        latestMessage: cleanPresentationText(latestMessage),
        emotion: cleanPresentationText(emotion),
        riskNotice: cleanPresentationText(riskNotice),
        replies: cleanUniqueReplySuggestions(replies),
        personInsight: personInsight?.normalized(),
      );

  Map<String, dynamic> toJson() => {
        'sceneSummary': cleanPresentationText(sceneSummary),
        'platform': cleanPresentationText(platform),
        'relationshipGuess': cleanPresentationText(relationshipGuess),
        'latestMessage': cleanPresentationText(latestMessage),
        'emotion': cleanPresentationText(emotion),
        'riskWarning': cleanPresentationText(riskNotice),
        'riskNotice': cleanPresentationText(riskNotice),
        'replies': cleanUniqueReplySuggestions(replies)
            .map((e) => e.toJson())
            .toList(),
        'personInsight': personInsight?.toJson(),
      };
}
