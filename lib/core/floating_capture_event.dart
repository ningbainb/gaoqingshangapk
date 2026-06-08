import 'dart:convert';

import 'loose_key.dart';
import 'route_path_normalization.dart';
import 'text_cleaning.dart';

part 'floating_capture_event_fields.dart';
part 'floating_capture_event_source.dart';

class FloatingCaptureEvent {
  const FloatingCaptureEvent({
    this.path,
    this.text,
    this.copiedReply,
    this.error,
    this.route,
    this.source,
  });

  final String? path;
  final String? text;
  final String? copiedReply;
  final String? error;
  final String? route;
  final String? source;

  factory FloatingCaptureEvent.fromMap(Object? event) {
    final payload = _eventPayloadMap(event);
    if (payload == null) {
      return const FloatingCaptureEvent(error: '未知悬浮窗事件。');
    }
    return FloatingCaptureEvent(
      path: _cleanEventField(_firstEventValue(payload, _eventPathKeys)),
      text: _cleanEventField(_firstEventValue(payload, _eventTextKeys)),
      copiedReply:
          _cleanEventField(_firstEventValue(payload, _eventCopiedReplyKeys)),
      error: _cleanEventField(_firstEventValue(payload, _eventErrorKeys)),
      route: _cleanEventField(_firstEventValue(payload, _eventRouteKeys)),
      source: _normalizedEventSource(_firstEventValue(
        payload,
        _eventSourceKeys,
      )),
    );
  }
}
