part of 'models.dart';

class ChatTextStats {
  const ChatTextStats({required this.characters, required this.lines});

  final int characters;
  final int lines;
}

ChatTextStats chatTextStats(String text) {
  final trimmed = cleanChatTextInput(text);
  if (trimmed == null) return const ChatTextStats(characters: 0, lines: 0);
  return ChatTextStats(
    characters: visibleTextLength(trimmed.replaceAll(RegExp(r'\s+'), '')),
    lines: trimmed.split(RegExp(r'\r?\n')).where(_hasChatTextLine).length,
  );
}

String? cleanChatTextInput(String? text) => cleanNonEmptyText(text);

bool hasUsableChatText(String? text) => cleanChatTextInput(text) != null;

bool _hasChatTextLine(String line) => cleanChatTextInput(line) != null;

String appendClipboardText(String current, String clipboard) {
  final pasted = cleanChatTextInput(clipboard);
  if (pasted == null) return current;
  final existing = cleanChatTextInput(current);
  if (existing == null) return pasted;
  return '$existing\n$pasted';
}

String chineseShortDate(DateTime date) {
  final local = date.toLocal();
  return '${local.year}年${local.month}月${local.day}日';
}

String chineseRelativeShortDate(DateTime date, {DateTime? now}) {
  final localNow = (now ?? DateTime.now()).toLocal();
  final localDate = date.toLocal();
  final diff = localNow.difference(localDate);
  if (diff.isNegative || diff.inSeconds < 60) return '刚刚';
  if (diff.inMinutes < 60) return '${diff.inMinutes}分钟前';
  if (diff.inHours < 24 && _isSameLocalDay(localDate, localNow)) {
    return '${diff.inHours}小时前';
  }
  if (_isSameLocalDay(localDate, localNow.subtract(const Duration(days: 1)))) {
    return '昨天';
  }
  if (diff.inDays < 7) return '${diff.inDays}天前';
  return chineseShortDate(localDate);
}

bool _isSameLocalDay(DateTime left, DateTime right) =>
    left.year == right.year &&
    left.month == right.month &&
    left.day == right.day;
