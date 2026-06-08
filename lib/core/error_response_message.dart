import 'app_feedback.dart';
import 'loose_key.dart';

const _errorMessageKeys = [
  'message',
  'msg',
  'title',
  'reason',
  'reasonPhrase',
  'errorMessage',
  'error_message',
  'errorDescription',
  'error_description',
  'detail',
  'details',
  'description',
  'code',
  'errorCode',
  'error_code',
  'type',
];

const _nestedErrorKeys = [
  'errors',
  'causes',
  'violations',
];

String? errorResponseMessageFromData(Object? data) {
  if (data is Map) {
    final error = _errorValue(data, 'error');
    if (error is Map) {
      final message =
          _cleanErrorText(_firstErrorValue(error, _errorMessageKeys));
      if (message != null) return message;
      final nested = errorResponseMessageFromData(
          _firstErrorValue(error, _nestedErrorKeys));
      if (nested != null) return nested;
    }
    final errorText = error is String ? cleanFeedbackMessage(error) : null;
    if (errorText != null) return errorText;
    final message = _cleanErrorText(_firstErrorValue(data, _errorMessageKeys));
    if (message != null) return message;
    final nested =
        errorResponseMessageFromData(_firstErrorValue(data, _nestedErrorKeys));
    if (nested != null) return nested;
  }
  if (data is List) {
    for (final item in data) {
      final message = errorResponseMessageFromData(item);
      if (message != null) return message;
    }
  }
  final text = data is String ? cleanFeedbackMessage(data) : null;
  if (text != null) return text;
  return null;
}

Object? _firstErrorValue(Map<dynamic, dynamic> data, List<String> keys) {
  for (final key in keys) {
    final value = _errorValue(data, key);
    if (value != null) return value;
  }
  return null;
}

Object? _errorValue(Map<dynamic, dynamic> data, String key) {
  return valueForLooseKey(data, key);
}

String? _cleanErrorText(Object? value) {
  if (value is Map || value is List) return errorResponseMessageFromData(value);
  return cleanFeedbackMessage(value?.toString());
}
