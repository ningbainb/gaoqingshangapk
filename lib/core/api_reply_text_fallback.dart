part of 'api_service.dart';

List<String> _fallbackReplyLines(String content) {
  final text = cleanNonEmptyText(_stripJsonCodeFence(content)) ?? '';
  final extracted = _extractReplyTextFields(text);
  if (extracted.isNotEmpty) return extracted;
  return text
      .split(RegExp(r'\n+'))
      .map(_cleanReplyLine)
      .where((line) => line.isNotEmpty)
      .where((line) => visibleTextLength(line) <= 80)
      .where((line) => !_looksLikeJsonFragment(line))
      .toList();
}

List<String> _extractReplyTextFields(String text) {
  final sectionIndex = [
    '"replies"',
    '"replySuggestions"',
    '"suggestions"',
    '"replyOptions"',
    '"options"',
    '"candidates"',
    '"answers"',
  ].map(text.indexOf).where((index) => index >= 0).fold<int?>(
      null, (best, index) => best == null ? index : min(best, index));
  if (sectionIndex == null) return const [];
  final replySection = _replyCandidateSection(text.substring(sectionIndex));
  final regex = RegExp(
      r'"(?:text|reply|message|content|suggestion|answer)"\s*:\s*"((?:\\.|[^"\\])*)"');
  final objectValues = regex.allMatches(replySection).map((match) {
    final raw = match.group(1) ?? '';
    return _cleanReplyLine(_decodeJsonStringLiteral(raw) ?? raw);
  }).where((line) {
    return line.isNotEmpty && !_looksLikeJsonFragment(line);
  }).toList();
  if (objectValues.isNotEmpty) return objectValues;

  return _extractStringArrayReplyItems(replySection);
}

String _replyCandidateSection(String replySection) {
  final arrayStart = replySection.indexOf('[');
  if (arrayStart < 0) return replySection;
  final arrayEnd = _matchingJsonArrayEnd(replySection, arrayStart);
  if (arrayEnd == null) return replySection;
  return replySection.substring(0, arrayEnd + 1);
}

List<String> _extractStringArrayReplyItems(String replySection) {
  final arrayStart = replySection.indexOf('[');
  if (arrayStart < 0) return const [];
  final arrayEnd = _matchingJsonArrayEnd(replySection, arrayStart);
  final arrayText = replySection.substring(
    arrayStart,
    arrayEnd == null ? replySection.length : arrayEnd + 1,
  );
  return RegExp(r'"((?:\\.|[^"\\])*)"')
      .allMatches(arrayText)
      .where((match) {
        final after = arrayText.substring(match.end).trimLeft();
        return !after.startsWith(':');
      })
      .map((match) {
        final raw = match.group(1) ?? '';
        return _cleanReplyLine(_decodeJsonStringLiteral(raw) ?? raw);
      })
      .where((line) => line.isNotEmpty && !_looksLikeJsonFragment(line))
      .take(5)
      .toList();
}

int? _matchingJsonArrayEnd(String source, int start) {
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
    } else if (char == '[') {
      depth += 1;
    } else if (char == ']') {
      depth -= 1;
      if (depth == 0) return index;
    }
  }
  return null;
}

String? _decodeJsonStringLiteral(String text) {
  try {
    final decoded = jsonDecode('"$text"');
    return decoded is String ? decoded : null;
  } catch (_) {
    return null;
  }
}

String _cleanReplyLine(String line) {
  var text = cleanNonEmptyText(line) ?? '';
  text = text.replaceFirst(RegExp(r'^[-*•]\s*'), '');
  text = text.replaceFirst(RegExp(r'^[0-9]+[.、]\s*'), '');
  return cleanNonEmptyText(
        text.replaceAll(RegExp("^[\\\"“”']+|[\\\"“”']+\$"), ''),
      ) ??
      '';
}

bool _looksLikeJsonFragment(String text) {
  final trimmed = cleanNonEmptyText(text);
  if (trimmed == null) return true;
  if (const ['{', '}', '[', ']', ','].contains(trimmed)) return true;
  if (trimmed.startsWith('"') && trimmed.contains('":')) return true;
  if (trimmed.contains('":')) return true;
  return trimmed.startsWith('"replies"') ||
      trimmed.startsWith('"personInsight"');
}
