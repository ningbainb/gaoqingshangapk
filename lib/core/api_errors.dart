part of 'api_service.dart';

AppException _mapDioException(DioException error) {
  final status = error.response?.statusCode;
  final message = errorResponseMessageFromData(error.response?.data) ??
      error.message ??
      error.toString();
  if (status == 401 || status == 403) {
    return AppException(apiModelAuthFailureMessage(message));
  }
  if (status != null) {
    return AppException('模型接口返回错误（$status）：$message');
  }
  if (error.type == DioExceptionType.connectionTimeout ||
      error.type == DioExceptionType.receiveTimeout ||
      error.type == DioExceptionType.sendTimeout) {
    return AppException(apiRequestTimeoutMessage);
  }
  if (error.type == DioExceptionType.connectionError) {
    if (isConnectionInterrupted(error)) {
      return AppException(apiConnectionInterruptedMessage);
    }
    return AppException(apiNetworkConnectionFailedMessage);
  }
  return AppException('网络请求失败：$message');
}

AppException _mapFetchModelsDioException(DioException error) {
  final status = error.response?.statusCode;
  final message = errorResponseMessageFromData(error.response?.data) ??
      error.message ??
      error.toString();
  if (status == 401 || status == 403) {
    return AppException(apiFetchModelsAuthFailureMessage(message));
  }
  if (status != null) {
    return AppException('拉取模型列表失败（$status）：$message');
  }
  if (error.type == DioExceptionType.connectionTimeout ||
      error.type == DioExceptionType.receiveTimeout ||
      error.type == DioExceptionType.sendTimeout) {
    return AppException(apiRequestTimeoutMessage);
  }
  if (error.type == DioExceptionType.connectionError) {
    if (isConnectionInterrupted(error)) {
      return AppException(apiConnectionInterruptedMessage);
    }
    return AppException(apiNetworkConnectionFailedMessage);
  }
  return AppException('网络请求失败：$message');
}

bool _shouldFallbackFromResponses(Object error) {
  final message = _messageFor(error).toLowerCase();
  return message.contains('404') ||
      message.contains('405') ||
      message.contains('responses') ||
      message.contains('not found') ||
      message.contains('method') ||
      message.contains('unsupported') ||
      message.contains('unknown endpoint') ||
      message.contains('接口请求超时') ||
      message.contains('接口连接被中断') ||
      message.contains('网络连接失败') ||
      message.contains('网络请求失败') ||
      message.contains('无法读取 responses api 返回内容');
}

bool _shouldRetryWithoutResponseFormat(Object error) {
  final message = _messageFor(error).toLowerCase();
  return message.contains('response_format') ||
      message.contains('json_object') ||
      message.contains('unsupported');
}

String _messageFor(Object error) =>
    error is AppException ? error.message : error.toString();
