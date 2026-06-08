part of 'api_service.dart';

String _responsesContent(Object? data) {
  if (data is Map) {
    final outputText = _contentText(_firstValue(data, _responseOutputTextKeys));
    if (outputText != null) return outputText;
    final parts = _responsesTextParts(_valueForKey(data, 'output'));
    if (parts.isNotEmpty) return parts.join('\n');
    final content = _contentText(_firstValue(data, _responseContentKeys));
    if (content != null) return content;
    final message = _contentText(_valueForKey(data, 'message'));
    if (message != null) return message;
    final wrapped = _contentText(_firstValue(data, _contentWrapperKeys));
    if (wrapped != null) return wrapped;
    try {
      return _chatContent(data);
    } catch (_) {}
  }
  throw AppException('无法读取 Responses API 返回内容。');
}

List<String> _responsesTextParts(Object? output) {
  if (output is List) {
    return output.expand(_responsesTextParts).toList();
  }
  if (output is Map) {
    final contentParts = _contentTextParts(_valueForKey(output, 'content'));
    if (contentParts.isNotEmpty) return contentParts;
    final textParts = _contentTextParts(_valueForKey(output, 'text'));
    if (textParts.isNotEmpty) return textParts;
    final outputTextParts =
        _contentTextParts(_firstValue(output, _responseOutputTextKeys));
    if (outputTextParts.isNotEmpty) return outputTextParts;
    final messageParts =
        _contentTextParts(_firstValue(output, _responseMessageKeys));
    if (messageParts.isNotEmpty) return messageParts;
    final valueParts = _contentTextParts(_valueForKey(output, 'value'));
    if (valueParts.isNotEmpty) return valueParts;
    final structuredParts =
        _contentTextParts(_firstValue(output, _structuredContentKeys));
    if (structuredParts.isNotEmpty) return structuredParts;
    final wrappedParts =
        _contentTextParts(_firstValue(output, _contentWrapperKeys));
    if (wrappedParts.isNotEmpty) return wrappedParts;
    final toolContent = _toolCallContent(output);
    if (toolContent != null) return [toolContent];
    return const [];
  }
  return _contentTextParts(output);
}
