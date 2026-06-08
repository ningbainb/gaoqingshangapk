import 'app_feedback.dart';
import 'app_state.dart';
import 'generation_goal_helpers.dart';
import 'loose_key.dart';
import 'models.dart';
import 'platform_bridge.dart';
import 'text_cleaning.dart';

part 'quick_reply_overlay_helpers.dart';
part 'quick_reply_return_packages.dart';

String? quickAutoGenerateBlockMessage({
  required GenerateAPIReadiness readiness,
  required bool isBusy,
}) {
  if (!readiness.isReady) return readiness.statusText;
  if (isBusy) return '正在生成中，请稍后再试。';
  return null;
}

const quickReplyDefaultGoal = '根据当前界面的聊天内容，生成多条可直接发送的自然回复。';

void prepareQuickShortcutFallback(AppController app) {
  app.requestQuickClipboardImport();
}

String effectiveQuickReplyGoal(String goal) {
  final trimmed = sanitizedGoal(goal);
  return trimmed.isEmpty ? quickReplyDefaultGoal : trimmed;
}

String effectiveImageReplyGoal({
  required bool isQuickReply,
  required String goal,
}) {
  return isQuickReply ? effectiveQuickReplyGoal(goal) : sanitizedGoal(goal);
}

Future<bool> prepareQuickReplyAutoGenerateBridge({
  required AppController app,
  required Future<void> Function() showAnalyzingOverlay,
  required Future<void> Function() collapseQuickPanel,
  Future<void> Function(String message)? showErrorOverlay,
  void Function(String message)? onError,
}) async {
  try {
    await showAnalyzingOverlay();
    await collapseQuickPanel();
    return true;
  } catch (error) {
    final message = userMessageFor(error);
    onError?.call(message);
    if (showErrorOverlay != null) {
      try {
        await showErrorOverlay(message);
      } catch (overlayError) {
        onError?.call(userMessageFor(overlayError));
      }
    }
    await app.finishQuickReplySession();
    return false;
  }
}

Future<void> finishBlockedQuickReplyAutoGenerate({
  required AppController app,
  required String message,
  required Future<void> Function(String message) showErrorOverlay,
  void Function(String message)? onError,
}) async {
  app.setError(message);
  try {
    await showErrorOverlay(message);
  } catch (error) {
    onError?.call(userMessageFor(error));
  } finally {
    await app.finishQuickReplySession();
  }
}

Future<void> completeQuickReplyAutoGenerateAttempt({
  required AppController app,
  required Future<void> Function() generate,
  required Future<void> Function(List<String> replies, String? returnPackage)
      showOverlay,
  required Future<void> Function(String message) showErrorOverlay,
  void Function(String message)? onError,
}) async {
  Future<void> showOverlaySafely(
    List<String> replies,
    String? returnPackage,
  ) async {
    try {
      await showOverlay(replies, returnPackage);
    } catch (error) {
      onError?.call(userMessageFor(error));
    }
  }

  try {
    await generate();
    final replies = quickReplyCopyableOverlayReplies(app);
    if (replies.isEmpty) {
      await showErrorOverlay(quickReplyOverlayMessage(app));
    } else {
      await showOverlaySafely(
        replies,
        quickReplyReturnPackageForPlatform(app.currentResponse?.platform),
      );
    }
  } catch (error) {
    final message = userMessageFor(error);
    onError?.call(message);
    try {
      await showErrorOverlay(message);
    } catch (overlayError) {
      onError?.call(userMessageFor(overlayError));
    }
  } finally {
    await app.finishQuickReplySession();
  }
}

Future<void> showQuickReplyMessageOverlaySafely(
  String message, {
  required String title,
  void Function(String message)? onError,
}) async {
  try {
    await FloatingCaptureBridge.showMessageOverlay(
      title: title,
      message: message,
    );
  } catch (error) {
    onError?.call(userMessageFor(error));
  }
}

Future<void> showQuickReplyOverlaySafely(
  List<String> replies, {
  String? returnPackage,
  void Function(String message)? onError,
}) async {
  try {
    await FloatingCaptureBridge.showReplyOverlayForPlatform(
      replies,
      returnPackage: returnPackage,
    );
  } catch (error) {
    onError?.call(userMessageFor(error));
  }
}
