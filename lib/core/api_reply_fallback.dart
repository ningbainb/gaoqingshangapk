part of 'api_service.dart';

ChatReplyResponse _parseReply(String content) {
  final decoded = decodeJsonObject(content);
  if (decoded != null) {
    final parsed = ChatReplyResponse.fromJson(decoded);
    if (parsed.replies.isNotEmpty) return parsed;
    if (_looksLikeTopLevelJsonArray(content)) {
      final arrayResponse = _arrayReplyResponse(content);
      if (arrayResponse != null) return arrayResponse;
    }
  } else {
    final arrayResponse = _arrayReplyResponse(content);
    if (arrayResponse != null) return arrayResponse;
  }
  final lines = _fallbackReplyLines(content).take(5).toList();
  return ChatReplyResponse(
    sceneSummary: '模型返回格式不标准，已尽量提取可用回复。',
    riskNotice: '建议检查模型是否支持 JSON 输出。',
    replies: lines.isEmpty
        ? [
            ReplySuggestion(
                styleLabel: '兜底',
                text: '模型返回内容不完整，请重新生成一次。',
                reason: '模型未返回标准 JSON，且没有提取到可直接发送的回复。')
          ]
        : lines
            .asMap()
            .entries
            .map((entry) => ReplySuggestion(
                styleLabel: entry.key == 0 ? '兜底' : '建议 ${entry.key + 1}',
                text: truncateVisibleText(entry.value, maxCharacters: 40),
                reason: '模型未返回标准 JSON，已从文本内容中提取。'))
            .toList(),
  );
}

ChatReplyResponse? _arrayReplyResponse(String content) {
  final arrayReplies = _parseReplyArray(content);
  if (arrayReplies.isEmpty) return null;
  return ChatReplyResponse(
    sceneSummary: '模型返回候选回复列表，已尽量提取可用回复。',
    riskNotice: '建议检查模型是否支持完整 JSON 输出。',
    replies: arrayReplies,
  );
}
