part of 'models.dart';

const _generationRecordIdKeys = [
  'id',
  'recordId',
  'generationId',
  'historyId',
  'historyRecordId',
];

const _generationRecordInputTypeKeys = [
  'inputType',
  'type',
  'sourceType',
  'inputMode',
  'mode',
];

const _generationRecordStyleKeys = [
  'selectedStyleName',
  'selectedStyle',
  'selectedStyleLabel',
  'styleName',
  'styleLabel',
  'style',
  'chatStyle',
  'tone',
  'toneLabel',
];

const _generationRecordGoalKeys = [
  'userGoal',
  'goal',
  'intent',
  'instruction',
  'replyGoal',
  'userIntent',
];

const _generationRecordReplyKeys = [
  'replies',
  'suggestions',
  'replyOptions',
  'replySuggestions',
  'candidates',
  'answers',
  'results',
  'items',
  'messages',
];

const _generationRecordCopiedReplyKeys = [
  'copiedReply',
  'copied',
  'copiedReplyText',
  'lastCopiedReply',
  'selectedReply',
];

const _generationRecordCreatedAtKeys = [
  'createdAt',
  'createdTime',
  'createdOn',
  'generatedAt',
  'timestamp',
  'time',
];

GenerationRecord _generationRecordFromJson(Map<String, dynamic> json) {
  return GenerationRecord(
    id: _firstIdentifier(json, _generationRecordIdKeys),
    inputType: _chatInputTypeValue(
      _firstClean(json, _generationRecordInputTypeKeys),
    ),
    sceneSummary: _firstClean(json, _sceneSummaryKeys),
    platform: _firstClean(json, _platformKeys),
    relationshipGuess: _firstClean(json, _relationshipKeys),
    latestMessage: _firstClean(json, _latestMessageKeys),
    emotion: _firstClean(json, _emotionKeys),
    riskNotice: _firstClean(json, _riskNoticeKeys),
    selectedStyleName: _firstClean(json, _generationRecordStyleKeys) ?? '自然',
    userGoal: _firstClean(json, _generationRecordGoalKeys),
    replies: _generationRecordReplies(
      _firstValue(json, _generationRecordReplyKeys),
    ),
    copiedReply: _firstClean(json, _generationRecordCopiedReplyKeys),
    createdAt: _dateTimeValue(
          _firstValue(json, _generationRecordCreatedAtKeys),
        ) ??
        DateTime.now(),
  );
}
