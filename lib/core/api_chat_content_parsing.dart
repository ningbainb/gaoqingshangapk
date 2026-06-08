part of 'api_service.dart';

String _chatContent(Object? data) {
  if (data is Map) {
    final choices = _valueForKey(data, 'choices');
    if (choices is List && choices.isNotEmpty) {
      for (final choice in choices.whereType<Map>()) {
        final message = _valueForKey(choice, 'message');
        if (message is Map) {
          final content = _contentText(_firstValue(message, _chatContentKeys));
          if (content != null) return content;
          final toolContent = _toolCallContent(message);
          if (toolContent != null) return toolContent;
        }
        final delta = _valueForKey(choice, 'delta');
        if (delta is Map) {
          final content = _contentText(_firstValue(delta, _chatContentKeys));
          if (content != null) return content;
          final toolContent = _toolCallContent(delta);
          if (toolContent != null) return toolContent;
        }
        final text = _contentText(_firstValue(choice, _chatContentKeys));
        if (text != null) return text;
        final toolContent = _toolCallContent(choice);
        if (toolContent != null) return toolContent;
      }
    }
    final directContent =
        _contentText(_firstValue(data, _chatDirectContentKeys));
    if (directContent != null) return directContent;
    for (final key in _contentWrapperKeys) {
      final value = _valueForKey(data, key);
      if (value == null) continue;
      try {
        return _chatContent(value);
      } catch (_) {}
      final text = _contentText(value);
      if (text != null) return text;
    }
  }
  throw AppException('无法读取模型返回内容。');
}
