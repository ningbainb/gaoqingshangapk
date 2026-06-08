part of 'models.dart';

const _replySuggestionIdKeys = [
  'id',
  'suggestionId',
  'replyId',
  'candidateId',
  'optionId',
  'messageId',
];

const _replySuggestionStyleKeys = [
  'styleLabel',
  'styleName',
  'style',
  'label',
  'tone',
  'toneLabel',
  'category',
];

const _replySuggestionTextKeys = [
  'text',
  'reply',
  'replyText',
  'message',
  'body',
  'content',
  'suggestion',
  'suggestedReply',
  'answer',
  'option',
  'optionText',
  'response',
  'candidate',
];

const _replySuggestionReasonKeys = [
  'reason',
  'explanation',
  'why',
  'rationale',
  'note',
  'notes',
  'comment',
];

ReplySuggestion _replySuggestionFromJson(Map<String, dynamic> json) =>
    ReplySuggestion(
      id: _firstIdentifier(json, _replySuggestionIdKeys),
      styleLabel: _firstClean(json, _replySuggestionStyleKeys) ?? '建议',
      text: _firstClean(json, _replySuggestionTextKeys) ?? '',
      reason: _firstClean(json, _replySuggestionReasonKeys) ?? '',
    );

PersonInsight _personInsightModelFromJson(Map<String, dynamic> json) =>
    PersonInsight(
      displayName: _firstClean(json, _personNameKeys),
      aliases: _firstUniqueStringList(json, _personAliasKeys),
      relationship: _firstClean(json, _personRelationshipKeys),
      communicationStyle: _firstClean(json, _personCommunicationStyleKeys) ??
          cleanPresentationText(
              _firstUniqueStringList(json, _personCommunicationAdviceKeys)
                  .join('；')),
      personalityTraits: _firstUniqueStringList(json, _personTraitKeys),
      innerNeeds: _firstUniqueStringList(json, _personNeedKeys),
      keyPersonPoints: _firstUniqueStringList(json, _personKeyPointKeys),
      momentsInsights: _firstUniqueStringList(json, _personMomentInsightKeys),
      tonePreferences: _firstUniqueStringList(json, _personTonePreferenceKeys),
      boundaries: _firstUniqueStringList(json, _personBoundaryKeys),
      facts: _firstUniqueStringList(json, _personFactKeys),
      confidence: _doubleValue(_firstValue(json, _personConfidenceKeys)),
      updateReason: _firstClean(json, _updateReasonKeys),
    );

ChatReplyResponse _chatReplyResponseFromJson(Map<String, dynamic> json) {
  final sources = _replyResponseSources(json);
  return ChatReplyResponse(
    sceneSummary: _firstCleanFromSources(
      sources,
      _sceneSummaryKeys,
    ),
    platform: _firstCleanFromSources(
      sources,
      _platformKeys,
    ),
    relationshipGuess: _firstCleanFromSources(
      sources,
      _relationshipKeys,
    ),
    latestMessage: _firstCleanFromSources(
      sources,
      _latestMessageKeys,
    ),
    emotion: _firstCleanFromSources(sources, _emotionKeys),
    riskNotice: _firstCleanFromSources(sources, _riskNoticeKeys),
    replies: _replySuggestionsFromJson(json),
    personInsight: _personInsightFromJson(json),
  );
}
