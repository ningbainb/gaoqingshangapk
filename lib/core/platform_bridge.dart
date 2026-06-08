import 'dart:async';

import 'package:flutter/services.dart';

import 'floating_capture_event.dart';

export 'floating_capture_event.dart';
export 'platform_routes.dart';

class FloatingCaptureBridge {
  static const _method = MethodChannel('ai_reply/floating');
  static const _events = EventChannel('ai_reply/floating_events');

  static Stream<FloatingCaptureEvent> get events =>
      _events.receiveBroadcastStream().map(FloatingCaptureEvent.fromMap);

  static Future<bool> hasOverlayPermission() async =>
      await _method.invokeMethod<bool>('hasOverlayPermission') ?? false;

  static Future<bool> hasNotificationPermission() async =>
      await _method.invokeMethod<bool>('hasNotificationPermission') ?? true;

  static Future<bool> requestNotificationPermission() async =>
      await _method.invokeMethod<bool>('requestNotificationPermission') ??
      false;

  static Future<void> openOverlaySettings() =>
      _method.invokeMethod('openOverlaySettings');

  static Future<void> startFloatingWindow() =>
      _method.invokeMethod('startFloatingWindow');

  static Future<void> stopFloatingWindow() =>
      _method.invokeMethod('stopFloatingWindow');

  static Future<void> collapseQuickPanel() =>
      _method.invokeMethod('collapseQuickPanel');

  static Future<void> showAnalyzingOverlay() =>
      _method.invokeMethod('showReplyOverlay', {
        'title': 'AI Reply 正在分析',
        'replies': <String>[],
        'loading': true,
      });

  static Future<void> showReplyOverlay(List<String> replies) =>
      _method.invokeMethod('showReplyOverlay', {
        'title': '点击回复即可复制',
        'replies': replies,
        'loading': false,
        'returnPackage': null,
      });

  static Future<void> showReplyOverlayForPlatform(
    List<String> replies, {
    String? returnPackage,
  }) =>
      _method.invokeMethod('showReplyOverlay', {
        'title': '点击回复即可复制',
        'replies': replies,
        'loading': false,
        'returnPackage': returnPackage,
      });

  static Future<void> showMessageOverlay({
    required String title,
    required String message,
  }) =>
      _method.invokeMethod('showReplyOverlay', {
        'title': title,
        'message': message,
        'replies': <String>[],
        'loading': false,
        'returnPackage': null,
      });

  static Future<void> hideReplyOverlay() =>
      _method.invokeMethod('hideReplyOverlay');

  static Future<bool> isAccessibilityEnabled() async =>
      await _method.invokeMethod<bool>('isAccessibilityEnabled') ?? false;

  static Future<bool> isAccessibilityConnected() async =>
      await _method.invokeMethod<bool>('isAccessibilityConnected') ?? false;

  static Future<void> openAccessibilitySettings() =>
      _method.invokeMethod('openAccessibilitySettings');

  static Future<String?> requestMediaProjectionScreenshot() =>
      _method.invokeMethod<String>('requestMediaProjectionScreenshot');

  static Future<String?> takeAccessibilityScreenshot() =>
      _method.invokeMethod<String>('takeAccessibilityScreenshot');

  static Future<String?> readClipboardImage() =>
      _method.invokeMethod<String>('readClipboardImage');
}
