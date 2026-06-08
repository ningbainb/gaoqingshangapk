part of 'api_service.dart';

const _visionMessageContainerKeys = [
  'messages',
  'items',
  'segments',
  'blocks',
  'results',
  'conversation',
  'chat',
  'lines',
  'ocrLines',
  'textLines',
  'texts',
  'data',
  'rows',
  'entries',
  'records',
  'list',
];

String _conversationTextFromExtraction(Map<String, dynamic> extraction) {
  final parts = <String>[];
  final conversation = _firstCleanText(extraction, const [
    'conversationText',
    'chatText',
    'text',
    'content',
    'ocrText',
    'transcript',
  ]);
  final messageLines = _extractedMessageLines(
    _firstValue(extraction, _visionMessageContainerKeys),
  );
  final scene = _firstCleanText(extraction, const [
    'sceneSummary',
    'summary',
    'scene',
    'context',
  ]);
  final latest = _firstCleanText(extraction, const [
    'latestMessage',
    'lastMessage',
    'latest',
    'last',
  ]);
  final visibleName = _firstCleanText(extraction, const [
    'visibleName',
    'nickname',
    'senderName',
    'name',
  ]);
  final notes = _firstCleanText(extraction, const [
    'notes',
    'note',
    'remark',
    'observation',
  ]);
  if (conversation != null) parts.add('聊天内容：\n$conversation');
  if (messageLines.isNotEmpty) {
    parts.add('聊天内容：\n${messageLines.join('\n')}');
  }
  if (scene != null) parts.add('截图场景：$scene');
  if (latest != null) parts.add('对方最后一句：$latest');
  if (visibleName != null) parts.add('可见昵称：$visibleName');
  if (notes != null) parts.add('识别备注：$notes');
  return parts.join('\n\n');
}

List<String> _extractedMessageLines(Object? raw) {
  if (raw is List) {
    return raw.map(_extractedMessageLine).whereType<String>().take(30).toList();
  }
  if (raw is Map) {
    final nested = _firstValue(raw, _visionMessageContainerKeys);
    if (nested != null && !identical(nested, raw)) {
      return _extractedMessageLines(nested);
    }
    final line = _extractedMessageLine(raw);
    return line == null ? const [] : [line];
  }
  final text = _cleanText(raw);
  return text == null ? const [] : [text];
}

String? _extractedMessageLine(Object? raw) {
  if (raw is Map) {
    final speaker = _firstCleanText(raw, const [
      'speaker',
      'sender',
      'senderName',
      'from',
      'user',
      'username',
      'displayName',
      'role',
      'author',
      'name',
    ]);
    final text = _firstCleanText(raw, const [
      'text',
      'content',
      'message',
      'messageText',
      'lineText',
      'utterance',
      'ocrText',
      'transcript',
      'body',
      'value',
    ]);
    if (text == null) return null;
    return speaker == null ? text : '$speaker：$text';
  }
  return _cleanText(raw);
}
