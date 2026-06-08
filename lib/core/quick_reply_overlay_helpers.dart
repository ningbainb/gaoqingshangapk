part of 'quick_reply_flow.dart';

List<String> quickReplyCopyableOverlayReplies(AppController app) {
  final replies = app.currentResponse?.replies;
  return replies == null
      ? const <String>[]
      : cleanUniqueReplyTexts(replies, limit: 5);
}

String quickReplyOverlayMessage(AppController app) {
  final error = cleanFeedbackMessage(app.errorMessage);
  if (error != null) return error;
  return '没有生成可复制的回复，请稍后重试。';
}

String quickReplyOverlayTitle(AppController app) {
  return cleanFeedbackMessage(app.errorMessage) != null ? '生成失败' : '没有可复制回复';
}
