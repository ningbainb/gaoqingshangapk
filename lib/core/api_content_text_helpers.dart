part of 'api_service.dart';

const _contentTextKeys = [
  'text',
  'outputText',
  'output_text',
  'messageText',
  'content',
  'value',
  ..._structuredContentKeys,
];

const _chatContentKeys = [
  'content',
  'text',
  'messageText',
  'outputText',
  'output_text',
  ..._structuredContentKeys,
  ..._contentWrapperKeys,
];

const _chatDirectContentKeys = [
  'content',
  'text',
  'messageText',
  'outputText',
  'output_text',
  ..._structuredContentKeys,
];

const _responseOutputTextKeys = [
  'outputText',
  'output_text',
];

const _responseContentKeys = [
  'content',
  'messageText',
];

const _responseMessageKeys = [
  'message',
  'messageText',
];

const _structuredContentKeys = [
  'json',
  'outputJson',
  'output_json',
  'parsed',
  'structuredContent',
  'structured_content',
];

const _contentWrapperKeys = [
  'message',
  'data',
  'result',
  'response',
  'payload',
  'body',
];

const _toolArgumentKeys = [
  'arguments',
  'args',
  'parameters',
];

const _toolFunctionKeys = [
  'function',
  'functionCall',
  'function_call',
];

const _toolCallKeys = [
  'toolCalls',
  'tool_calls',
  'calls',
];

List<String> _contentTextParts(Object? content) {
  if (content is List) {
    return content.expand(_contentTextParts).toList();
  }
  final text = _contentText(content);
  return text == null ? const [] : [text];
}

String? _contentText(Object? content) {
  if (content == null) return null;
  if (content is String) return _nonEmptyText(content);
  if (content is num || content is bool) return content.toString();
  if (content is List) {
    final parts = _contentTextParts(content);
    return parts.isEmpty ? null : parts.join('\n');
  }
  if (content is Map) {
    for (final key in _contentTextKeys) {
      final value = _valueForKey(content, key);
      if (value == null) continue;
      final text = _contentText(value);
      if (text != null) return text;
    }
    if (_looksLikeStructuredModelOutput(content)) {
      try {
        return jsonEncode(
            content.map((key, value) => MapEntry(key.toString(), value)));
      } catch (_) {}
    }
    for (final key in _contentWrapperKeys) {
      final value = _valueForKey(content, key);
      if (value == null) continue;
      final text = _contentText(value);
      if (text != null) return text;
    }
  }
  return null;
}

bool _looksLikeStructuredModelOutput(Map<dynamic, dynamic> content) {
  for (final key in const [
    'sceneSummary',
    'replies',
    'replySuggestions',
    'replyOptions',
    'personInsight',
    'sourcePlatform',
    'visibleName',
    'communicationAdvice',
    'stableFacts',
    'personaMessage',
    'sceneState',
    'metrics',
    'options',
    'coachTip',
  ]) {
    if (_valueForKey(content, key) != null) return true;
  }
  return false;
}

String? _toolCallContent(Object? data) {
  if (data is List) {
    for (final item in data) {
      final text = _toolCallContent(item);
      if (text != null) return text;
    }
    return null;
  }
  if (data is! Map) return null;
  final arguments = _contentText(_firstValue(data, _toolArgumentKeys));
  if (arguments != null) return arguments;
  final function = _toolCallContent(_firstValue(data, _toolFunctionKeys));
  if (function != null) return function;
  return _toolCallContent(_firstValue(data, _toolCallKeys));
}

String? _nonEmptyText(String text) {
  return cleanNonEmptyText(text);
}
