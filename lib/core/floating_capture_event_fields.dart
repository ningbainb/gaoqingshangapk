part of 'floating_capture_event.dart';

const _eventWrapperKeys = [
  'event',
  'payload',
  'data',
  'message',
  'body',
  'handoff',
  'nativeEvent',
];

const _eventPathKeys = [
  'path',
  'imagePath',
  'filePath',
  'screenshotPath',
  'capturePath',
  'sharedImagePath',
];

const _eventTextKeys = [
  'text',
  'sharedText',
  'selectedText',
  'processText',
  'clipboardText',
];

const _eventCopiedReplyKeys = [
  'copiedReply',
  'copiedText',
  'copiedReplyText',
  'replyText',
];

const _eventErrorKeys = ['error', 'errorMessage'];

const _eventRouteKeys = [
  'route',
  'deepLink',
  'url',
  'uri',
  'link',
  'destination',
  'targetRoute',
  'target',
  'screen',
  'page',
];

const _eventSourceKeys = [
  'source',
  'sourceType',
  'eventSource',
  'eventType',
  'inputSource',
  'inputType',
  'handoffSource',
  'handoffType',
  'intentAction',
  'intentSource',
];

const _eventDirectFieldKeys = [
  ..._eventPathKeys,
  ..._eventTextKeys,
  ..._eventCopiedReplyKeys,
  ..._eventErrorKeys,
  ..._eventRouteKeys,
  ..._eventSourceKeys,
];

const _eventDirectFieldKeyGroups = [
  _eventPathKeys,
  _eventTextKeys,
  _eventCopiedReplyKeys,
  _eventErrorKeys,
  _eventRouteKeys,
  _eventSourceKeys,
];

Map<dynamic, dynamic>? _eventPayloadMap(Object? event, [int depth = 0]) {
  if (depth > 4) return null;
  if (event is String) {
    try {
      return _eventPayloadMap(jsonDecode(event), depth + 1);
    } catch (_) {
      return null;
    }
  }
  if (event is! Map) return null;
  final wrapped = _firstEventValue(event, _eventWrapperKeys);
  if (wrapped != null && !identical(wrapped, event)) {
    final wrappedPayload = _eventPayloadMap(wrapped, depth + 1);
    if (wrappedPayload != null && _hasDirectEventField(wrappedPayload)) {
      if (_hasDirectEventField(event)) {
        return _mergedEventPayload(event, wrappedPayload);
      }
      return wrappedPayload;
    }
  }
  return event;
}

bool _hasDirectEventField(Map<dynamic, dynamic> event) {
  for (final key in _eventDirectFieldKeys) {
    if (_eventValue(event, key) != null) return true;
  }
  return false;
}

Map<dynamic, dynamic> _mergedEventPayload(
  Map<dynamic, dynamic> outer,
  Map<dynamic, dynamic> wrapped,
) {
  final merged = <dynamic, dynamic>{...wrapped};
  for (final keys in _eventDirectFieldKeyGroups) {
    final outerValue = _firstEventValue(outer, keys);
    if (outerValue != null && _firstEventValue(merged, keys) == null) {
      merged[keys.first] = outerValue;
    }
  }
  return merged;
}

Object? _firstEventValue(Map<dynamic, dynamic> event, List<String> keys) {
  for (final key in keys) {
    final value = _eventValue(event, key);
    if (value != null) return value;
  }
  return null;
}

Object? _eventValue(Map<dynamic, dynamic> event, String key) {
  return valueForLooseKey(event, key);
}

String? _cleanEventField(Object? value) => cleanNonEmptyText(value?.toString());
