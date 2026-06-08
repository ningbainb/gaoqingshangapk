import 'package:dio/dio.dart';

bool isConnectionInterrupted(Object? error) {
  return connectionInterruptionCandidates(error).any(_looksInterrupted);
}

List<String> connectionInterruptionCandidates(Object? error) {
  if (error is DioException) {
    return [
      error.message ?? '',
      error.error?.toString() ?? '',
      error.toString(),
    ];
  }
  return [
    if (error != null) error.toString(),
  ];
}

bool _looksInterrupted(String value) {
  final text = value.toLowerCase();
  return text.contains('network connection lost') ||
      text.contains('connection lost') ||
      text.contains('connection reset') ||
      text.contains('connection closed') ||
      text.contains('broken pipe') ||
      text.contains('连接被中断') ||
      text.contains('连接中断');
}
