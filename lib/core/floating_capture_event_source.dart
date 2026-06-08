part of 'floating_capture_event.dart';

String? _normalizedEventSource(Object? value) {
  final source = _cleanEventField(value);
  if (source == null) return null;

  final normalized = normalizedRoutePathToken(source);
  return switch (normalized) {
    'floating' ||
    'float' ||
    'floating-capture' ||
    'floating-window' ||
    'overlay' ||
    'overlay-capture' =>
      'floating',
    'share' ||
    'shared' ||
    'share-image' ||
    'shared-image' ||
    'android-share-image' ||
    'system-share-image' ||
    'image-share' ||
    'share-text' ||
    'shared-text' ||
    'android-share-text' ||
    'system-share-text' ||
    'text-share' ||
    'android-share' ||
    'system-share' ||
    'android.intent.action.send' ||
    'android.intent.action.send-multiple' ||
    'action-send' ||
    'action-send-multiple' ||
    'send' ||
    'send-multiple' =>
      'share',
    'quick' ||
    'quick-image' ||
    'quick-shortcut' ||
    'shortcut' ||
    'clipboard' ||
    'clipboard-image' =>
      'quick',
    'process-text' ||
    'android-process-text' ||
    'system-process-text' ||
    'process-text-selection' ||
    'selected-text' ||
    'android.intent.action.process-text' ||
    'action-process-text' =>
      'selected-text',
    'keyboard' || 'ime' || 'input-method' => 'selected-text',
    _ => normalized,
  };
}
