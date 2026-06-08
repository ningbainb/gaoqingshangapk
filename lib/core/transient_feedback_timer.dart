import 'dart:async';

import 'package:flutter/foundation.dart';

const defaultTransientFeedbackDuration = Duration(milliseconds: 1200);

Timer scheduleTransientFeedbackReset({
  required Timer? previousTimer,
  required bool Function() isMounted,
  required VoidCallback reset,
  Duration delay = defaultTransientFeedbackDuration,
}) {
  previousTimer?.cancel();
  return Timer(delay, () {
    if (isMounted()) reset();
  });
}
