part of 'api_service.dart';

List<ReplySuggestion> _parseReplyArray(String content) {
  final decoded = _decodeJsonArray(content);
  if (decoded == null) return const [];
  return cleanUniqueReplySuggestions(
    decoded.whereType<Object?>().map(
          (item) => item is Map
              ? ReplySuggestion.fromJson(Map<String, dynamic>.from(item))
              : ReplySuggestion(
                  styleLabel: '建议',
                  text: _cleanReplyLine(item?.toString() ?? ''),
                  reason: '',
                ),
        ),
  );
}

List<Object?>? _decodeJsonArray(String content) {
  final text = cleanNonEmptyText(_stripJsonCodeFence(content)) ?? '';
  try {
    final decoded = jsonDecode(text);
    if (decoded is List) return decoded.cast<Object?>();
  } catch (_) {
    return _decodeFirstReplyJsonArray(text);
  }
  return null;
}

List<Object?>? _decodeFirstReplyJsonArray(String text) {
  for (var start = text.indexOf('[');
      start >= 0;
      start = text.indexOf('[', start + 1)) {
    final end = _matchingJsonArrayEnd(text, start);
    if (end == null) continue;
    try {
      final decoded = jsonDecode(text.substring(start, end + 1));
      if (decoded is List && _looksLikeReplyArrayCandidate(decoded)) {
        return decoded.cast<Object?>();
      }
    } catch (_) {}
  }
  return null;
}

bool _looksLikeReplyArrayCandidate(List<dynamic> decoded) {
  if (decoded.isEmpty) return false;
  return decoded.any((item) => item is Map || item is String);
}

bool _looksLikeTopLevelJsonArray(String content) {
  final text = cleanNonEmptyText(_stripJsonCodeFence(content));
  if (text == null) return false;
  if (text.startsWith('[')) return true;
  final arrayStart = _firstReplyJsonArrayStart(text);
  if (arrayStart == null) return false;
  final firstObjectStart = text.indexOf('{');
  return firstObjectStart < 0 || arrayStart < firstObjectStart;
}

int? _firstReplyJsonArrayStart(String text) {
  for (var start = text.indexOf('[');
      start >= 0;
      start = text.indexOf('[', start + 1)) {
    final end = _matchingJsonArrayEnd(text, start);
    if (end == null) continue;
    try {
      final decoded = jsonDecode(text.substring(start, end + 1));
      if (decoded is List && _looksLikeReplyArrayCandidate(decoded)) {
        return start;
      }
    } catch (_) {}
  }
  return null;
}

String _stripJsonCodeFence(String content) {
  return content
      .replaceAll('```json', '')
      .replaceAll('```JSON', '')
      .replaceAll('```', '');
}
