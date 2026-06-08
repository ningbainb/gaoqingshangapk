import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';

import 'app_feedback.dart';
import 'api_failure_messages.dart';
import 'api_service.dart';
import 'connection_interruption.dart';
import 'error_response_message.dart';

String userMessageFor(Object error) {
  if (error is AppException) {
    return error.message;
  }
  if (error is TimeoutException) {
    return apiRequestTimeoutMessage;
  }
  if (error is DioException) {
    final status = error.response?.statusCode;
    final message = errorResponseMessageFromData(error.response?.data) ??
        error.message ??
        error.toString();
    if (status == 401 || status == 403) {
      return apiUserAuthInvalidMessage;
    }
    if (status != null) {
      return '接口返回错误（$status）：$message';
    }
    if (isConnectionInterrupted(error)) {
      return apiConnectionInterruptedMessage;
    }
    return switch (error.type) {
      DioExceptionType.connectionTimeout ||
      DioExceptionType.receiveTimeout ||
      DioExceptionType.sendTimeout =>
        apiRequestTimeoutMessage,
      DioExceptionType.connectionError => apiConnectionServerUnreachableMessage,
      _ => '网络请求失败：$message',
    };
  }
  if (error is SocketException) {
    if (isConnectionInterrupted(error)) {
      return apiConnectionInterruptedMessage;
    }
    return apiNetworkConnectionFailedMessage;
  }
  if (error is FileSystemException) {
    return _fileSystemErrorMessage(error);
  }
  if (error is PlatformException) {
    return cleanFeedbackMessage(error.message) ?? '系统剪贴板暂不可用。';
  }
  final text = error.toString();
  if (text.contains('SocketException')) {
    if (isConnectionInterrupted(text)) {
      return apiConnectionInterruptedMessage;
    }
    return apiNetworkConnectionFailedMessage;
  }
  if (text.contains('401') || text.contains('403')) {
    return apiUserAuthInvalidMessage;
  }
  if (text.toLowerCase().contains('timeout')) {
    return apiRequestTimeoutMessage;
  }
  return text.replaceFirst('Exception: ', '');
}

String _fileSystemErrorMessage(FileSystemException error) {
  final detail = cleanFeedbackMessage(error.message) ?? '请检查文件权限、存储空间或文件是否仍存在。';
  final path = cleanFeedbackMessage(error.path);
  if (path == null) {
    return '文件读写失败：$detail';
  }
  return '文件读写失败：$detail（$path）';
}
