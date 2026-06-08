part of 'models.dart';

Map<String, dynamic>? decodeJsonObject(String source) {
  try {
    final decoded = jsonDecode(source);
    if (decoded is Map<String, dynamic>) return decoded;
    if (decoded is Map) return Map<String, dynamic>.from(decoded);
  } catch (_) {
    return _decodeFirstJsonObject(source);
  }
  return null;
}

Map<String, dynamic>? _decodeFirstJsonObject(String source) {
  for (var start = source.indexOf('{');
      start >= 0;
      start = source.indexOf('{', start + 1)) {
    final end = _matchingJsonObjectEnd(source, start);
    if (end == null) continue;
    try {
      final decoded = jsonDecode(source.substring(start, end + 1));
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (_) {}
  }
  return null;
}

int? _matchingJsonObjectEnd(String source, int start) {
  var depth = 0;
  var inString = false;
  var isEscaped = false;
  for (var index = start; index < source.length; index += 1) {
    final char = source[index];
    if (inString) {
      if (isEscaped) {
        isEscaped = false;
      } else if (char == '\\') {
        isEscaped = true;
      } else if (char == '"') {
        inString = false;
      }
      continue;
    }
    if (char == '"') {
      inString = true;
    } else if (char == '{') {
      depth += 1;
    } else if (char == '}') {
      depth -= 1;
      if (depth == 0) return index;
      if (depth < 0) return null;
    }
  }
  return null;
}
