part of 'models.dart';

List<ReplySuggestion> _replySuggestionsFromJson(Map<String, dynamic> json) {
  final raw = _firstListFromSources(_replyResponseSources(json), const [
        'replies',
        'replySuggestions',
        'suggestions',
        'replyOptions',
        'options',
        'candidates',
        'answers',
      ]) ??
      _wrappedReplyList(json);
  return _replyListFromJson(raw);
}

List<ReplySuggestion> _replyListFromJson(Object? raw) {
  if (raw is! List) return const [];
  return cleanUniqueReplySuggestions(
    raw.whereType<Object?>().map(
          (e) => e is Map
              ? ReplySuggestion.fromJson(Map<String, dynamic>.from(e))
              : ReplySuggestion(
                  styleLabel: '建议',
                  text: cleanPresentationText(e?.toString()) ?? '',
                  reason: '',
                ),
        ),
  );
}

List<ReplySuggestion> _generationRecordReplies(Object? raw) {
  if (raw is! List) {
    throw const FormatException('Generation history replies must be a list.');
  }
  return _replyListFromJson(raw);
}

List<ReplySuggestion> cleanUniqueReplySuggestions(
  Iterable<ReplySuggestion> replies, {
  int? limit,
}) =>
    uniqueByCleanPresentationText(
      replies,
      normalize: (reply) => reply.normalized(),
      text: (reply) => reply.text,
      limit: limit,
    );

List<String> cleanUniqueReplyTexts(
  Iterable<ReplySuggestion> replies, {
  int? limit,
}) =>
    cleanUniqueReplySuggestions(replies, limit: limit)
        .map((reply) => reply.text)
        .toList();

bool cleanReplyTextsMatch(String? left, String? right) {
  final cleanedLeft = cleanPresentationText(left);
  final cleanedRight = cleanPresentationText(right);
  return cleanedLeft != null && cleanedLeft == cleanedRight;
}

PersonInsight? _personInsightFromJson(Map<String, dynamic> json) {
  final map = _firstMapFromSources(_replyResponseSources(json), const [
    'personInsight',
    'profile',
    'contactProfile',
    'person_profile',
    'contact',
    'recipientProfile',
    'targetProfile',
    'person',
  ]);
  return map == null ? null : PersonInsight.fromJson(map);
}

List<Map<String, dynamic>> _momentProfileSources(Map<String, dynamic> json) => [
      json,
      ..._responseWrappers(json, _looksLikeMomentProfileMap),
    ];

List<Map<String, dynamic>> _replyResponseSources(Map<String, dynamic> json) => [
      json,
      ..._replyResponseWrappers(json),
    ];

List<Map<String, dynamic>> _replyResponseWrappers(Map<String, dynamic> json) =>
    _responseWrappers(json, _looksLikeReplyResponseMap);

Object? _wrappedReplyList(Map<String, dynamic> json) {
  return _wrappedReplyListAtDepth(json, 0);
}

Object? _wrappedReplyListAtDepth(Map<String, dynamic> json, int depth) {
  if (depth >= 4) return null;
  for (final key in _responseWrapperKeys) {
    final value = _valueForKey(json, key);
    if (value is List) return value;
    final decoded = _mapValue(value);
    if (decoded != null) {
      final list = _firstListFromSources([
        decoded
      ], const [
        'replies',
        'replySuggestions',
        'suggestions',
        'replyOptions',
        'options',
        'candidates',
        'answers',
      ]);
      if (list != null) return list;
      final nested = _wrappedReplyListAtDepth(decoded, depth + 1);
      if (nested != null) return nested;
    }
  }
  return null;
}

bool _looksLikeReplyResponseMap(Map<String, dynamic> map) {
  const keys = [
    ..._sceneSummaryKeys,
    ..._platformKeys,
    ..._relationshipKeys,
    ..._latestMessageKeys,
    ..._emotionKeys,
    'replies',
    'replySuggestions',
    'suggestions',
    'replyOptions',
    'options',
    'candidates',
    'answers',
    'personInsight',
    'contactProfile',
    'contact',
    'recipientProfile',
    'targetProfile',
  ];
  return keys.any((key) => _valueForKey(map, key) != null) ||
      _riskNoticeKeys.any((key) => _valueForKey(map, key) != null);
}

bool _looksLikeMomentProfileMap(Map<String, dynamic> map) {
  const keys = [
    ..._sceneSummaryKeys,
    ..._platformKeys,
    ..._personNameKeys,
    ..._personRelationshipKeys,
    ..._personTraitKeys,
    ..._personNeedKeys,
    ..._personKeyPointKeys,
    ..._personMomentInsightKeys,
    ..._personCommunicationAdviceKeys,
    ..._personBoundaryKeys,
    ..._personFactKeys,
    ..._personConfidenceKeys,
    ..._personLastUpdateReasonKeys,
    'advice',
  ];
  return keys.any((key) => _valueForKey(map, key) != null);
}
