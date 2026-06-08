import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../core/app_feedback.dart';
import '../core/app_provider.dart';
import '../core/app_routes.dart';
import '../core/app_state.dart';
import '../core/generation_goal_helpers.dart';
import '../core/models.dart';
import '../core/platform_bridge.dart';
import '../core/quick_reply_flow.dart';
import '../core/transient_feedback_timer.dart';
import '../widgets/generate_image_shell.dart';
import 'profile_selection_helpers.dart';

class ImageInputScreen extends ConsumerStatefulWidget {
  const ImageInputScreen({super.key});

  @override
  ConsumerState<ImageInputScreen> createState() => _ImageInputScreenState();
}

class _ImageInputScreenState extends ConsumerState<ImageInputScreen> {
  String? imagePath;
  String? selectedProfileId;
  ChatStyle? style;
  bool isReadingClipboard = false;
  bool didReadClipboard = false;
  Timer? clipboardFeedbackTimer;
  final goal = TextEditingController();

  @override
  void initState() {
    super.initState();
    final app = ref.read(appProvider);
    app.clearFeedback(notify: false);
    if (app.currentInputType != ChatInputType.image) return;
    final restoredImagePath = cleanImagePathInput(app.currentImagePath);
    if (restoredImagePath != null && File(restoredImagePath).existsSync()) {
      imagePath = restoredImagePath;
    }
    final restoredGoal = optionalSanitizedGoal(app.currentGoal);
    if (restoredGoal != null) {
      goal.text = restoredGoal;
    }
    style = app.currentStyle;
    selectedProfileId = restorableScreenProfileId(app);
  }

  @override
  void dispose() {
    clipboardFeedbackTimer?.cancel();
    final path = imagePath;
    imagePath = null;
    if (isOwnedTransientImagePath(path)) {
      unawaited(ref.read(appProvider).discardTransientImagePath(path));
    }
    goal.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = ref.watch(appProvider);
    _schedulePendingSharedImage(app);
    final submitImagePath = cleanImagePathInput(imagePath);
    return GenerateImageShell(
      title: '截图生成',
      isQuickReply: false,
      imagePath: submitImagePath,
      goal: goal,
      style: style ?? app.defaultStyle,
      onStyle: (next) => setState(() => style = next),
      selectedProfileId: selectedProfileId,
      onProfileChanged: (next) => setState(() => selectedProfileId = next),
      onPick: _pick,
      onClearImage: () {
        final path = imagePath;
        app.clearFeedback(notify: false);
        unawaited(app.clearEditableImageDraft());
        if (isOwnedTransientImagePath(path)) {
          unawaited(app.discardTransientImagePath(path));
        }
        setState(() {
          imagePath = null;
          didReadClipboard = false;
          clipboardFeedbackTimer?.cancel();
        });
      },
      onCaptureScreen: null,
      onReadClipboard: _readClipboardImage,
      isReadingClipboard: isReadingClipboard,
      didReadClipboard: didReadClipboard,
      onGenerate: submitImagePath == null
          ? null
          : () async {
              await app.generateImage(
                submitImagePath,
                style ?? app.defaultStyle,
                effectiveImageReplyGoal(isQuickReply: false, goal: goal.text),
                selectedProfileId: selectedProfileId,
              );
              if (context.mounted && app.currentResponse != null) {
                context.go(AppRoutes.result);
              }
            },
    );
  }

  Future<void> _pick() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (!mounted) return;
    if (picked != null) {
      final app = ref.read(appProvider);
      final previousPath = imagePath;
      app.clearFeedback(notify: false);
      setState(() {
        imagePath = picked.path;
        didReadClipboard = false;
        clipboardFeedbackTimer?.cancel();
      });
      if (previousPath != picked.path &&
          isOwnedTransientImagePath(previousPath)) {
        unawaited(app.discardTransientImagePath(previousPath));
      }
    }
  }

  Future<void> _readClipboardImage() async {
    setState(() => isReadingClipboard = true);
    try {
      final path =
          cleanImagePathInput(await FloatingCaptureBridge.readClipboardImage());
      if (path != null && mounted) {
        final app = ref.read(appProvider);
        final previousPath = imagePath;
        app.clearFeedback(notify: false);
        setState(() {
          imagePath = path;
          didReadClipboard = true;
        });
        if (previousPath != path && isOwnedTransientImagePath(previousPath)) {
          unawaited(app.discardTransientImagePath(previousPath));
        }
        _scheduleClipboardFeedbackReset();
      } else {
        _clearClipboardReadFeedback();
        if (!mounted) return;
        ref.read(appProvider).setError(noClipboardScreenshotMessage);
      }
    } catch (error) {
      _clearClipboardReadFeedback();
      if (!mounted) return;
      ref.read(appProvider).setError(userMessageFor(error));
    } finally {
      if (mounted) setState(() => isReadingClipboard = false);
    }
  }

  void _schedulePendingSharedImage(AppController app) {
    if (app.shouldDeferExternalHandoffs) return;
    if (app.sharedImagePath == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final controller = ref.read(appProvider);
      final sharedPath =
          cleanImagePathInput(controller.consumeSharedImagePath());
      if (sharedPath != null) {
        final previousPath = imagePath;
        setState(() {
          if (sharedPath != imagePath) {
            imagePath = sharedPath;
          }
          goal.clear();
          style = controller.currentStyle;
          selectedProfileId = restorableScreenProfileId(controller);
          didReadClipboard = false;
          clipboardFeedbackTimer?.cancel();
        });
        if (previousPath != sharedPath &&
            isOwnedTransientImagePath(previousPath)) {
          unawaited(controller.discardTransientImagePath(previousPath));
        }
      }
    });
  }

  void _scheduleClipboardFeedbackReset() {
    clipboardFeedbackTimer = scheduleTransientFeedbackReset(
      previousTimer: clipboardFeedbackTimer,
      isMounted: () => mounted,
      reset: () => setState(() => didReadClipboard = false),
    );
  }

  void _clearClipboardReadFeedback() {
    clipboardFeedbackTimer?.cancel();
    if (mounted) setState(() => didReadClipboard = false);
  }
}

class QuickReplyScreen extends ConsumerStatefulWidget {
  const QuickReplyScreen({super.key});

  @override
  ConsumerState<QuickReplyScreen> createState() => _QuickReplyScreenState();
}

class _QuickReplyScreenState extends ConsumerState<QuickReplyScreen> {
  String? selectedProfileId;
  ChatStyle? style;
  final goal = TextEditingController();
  bool isCapturing = false;
  bool didReadClipboard = false;
  bool isHandlingLaunchRequest = false;
  String? autoGeneratingPath;
  Timer? clipboardFeedbackTimer;

  @override
  void initState() {
    super.initState();
    final app = ref.read(appProvider);
    app.clearFeedback(notify: false);
    if (app.isQuickReplySession &&
        app.currentInputType == ChatInputType.image) {
      final restoredGoal = optionalSanitizedGoal(app.currentGoal);
      if (restoredGoal != null) {
        goal.text = restoredGoal;
      }
      style = app.currentStyle;
    }
    selectedProfileId = restorableScreenProfileId(app);
  }

  @override
  void dispose() {
    clipboardFeedbackTimer?.cancel();
    goal.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = ref.watch(appProvider);
    _schedulePendingQuickWork(app);
    final submitImagePath = cleanImagePathInput(app.quickImagePath);
    return GenerateImageShell(
      title: '悬浮窗截图',
      isQuickReply: true,
      imagePath: submitImagePath,
      goal: goal,
      style: style ?? app.defaultStyle,
      onStyle: (next) => setState(() => style = next),
      selectedProfileId: selectedProfileId,
      onProfileChanged: (next) => setState(() => selectedProfileId = next),
      onPick: () => context.go(AppRoutes.image),
      onClearImage: () {
        clipboardFeedbackTimer?.cancel();
        app.clearFeedback(notify: false);
        setState(() => didReadClipboard = false);
        unawaited(app.finishQuickReplySession());
      },
      onCaptureScreen: isCapturing ? null : _captureCurrentScreen,
      onReadClipboard: _readClipboardImage,
      isReadingClipboard: isCapturing,
      didReadClipboard: didReadClipboard,
      onGenerate: submitImagePath == null
          ? null
          : () async {
              await app.generateImage(
                submitImagePath,
                style ?? app.defaultStyle,
                effectiveImageReplyGoal(isQuickReply: true, goal: goal.text),
                selectedProfileId: selectedProfileId,
              );
              if (context.mounted && app.currentResponse != null) {
                context.go(AppRoutes.result);
              }
            },
    );
  }

  void _schedulePendingQuickWork(AppController app) {
    if (app.shouldDeferExternalHandoffs) return;
    if (app.shouldResetQuickReplyDraft) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final controller = ref.read(appProvider);
        if (!controller.consumeQuickDraftResetRequest()) return;
        setState(() {
          goal.clear();
          style = controller.currentStyle;
          selectedProfileId = restorableScreenProfileId(controller);
          didReadClipboard = false;
          clipboardFeedbackTimer?.cancel();
        });
      });
    }
    if (app.shouldReadQuickClipboardOnOpen && !isHandlingLaunchRequest) {
      isHandlingLaunchRequest = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _consumePendingClipboardImport();
      });
    }

    final imagePath = app.quickImagePath;
    if (imagePath != null &&
        app.shouldAutoGenerateQuickReply &&
        autoGeneratingPath != imagePath) {
      autoGeneratingPath = imagePath;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _autoGenerateQuickReply(imagePath);
      });
    }
  }

  Future<void> _consumePendingClipboardImport() async {
    final app = ref.read(appProvider);
    final shouldRead = app.consumeQuickClipboardImportRequest();
    if (!shouldRead) {
      if (mounted) setState(() => isHandlingLaunchRequest = false);
      return;
    }
    await _readClipboardImage(autoGenerate: true);
    if (mounted) setState(() => isHandlingLaunchRequest = false);
  }

  Future<void> _autoGenerateQuickReply(String imagePath) async {
    final app = ref.read(appProvider);
    final readiness = GenerateAPIReadiness(
      config: app.config,
      hasAPIKey: hasUsableAPIKey(app.apiKey),
      capability: GenerateAPICapability.vision,
      isQuickReply: true,
    );
    final shouldGenerate = app.consumeQuickAutoGenerate(imagePath);
    if (!shouldGenerate) {
      autoGeneratingPath = null;
      return;
    }
    final blockMessage = quickAutoGenerateBlockMessage(
      readiness: readiness,
      isBusy: app.isBusy,
    );
    if (blockMessage != null) {
      await finishBlockedQuickReplyAutoGenerate(
        app: app,
        message: blockMessage,
        showErrorOverlay: (message) => showQuickReplyMessageOverlaySafely(
          message,
          title: '快捷回复失败',
          onError: app.setError,
        ),
        onError: app.setError,
      );
      autoGeneratingPath = null;
      return;
    }
    final prepared = await prepareQuickReplyAutoGenerateBridge(
      app: app,
      showAnalyzingOverlay: FloatingCaptureBridge.showAnalyzingOverlay,
      collapseQuickPanel: FloatingCaptureBridge.collapseQuickPanel,
      showErrorOverlay: (message) => showQuickReplyMessageOverlaySafely(
        message,
        title: '快捷回复失败',
        onError: app.setError,
      ),
      onError: app.setError,
    );
    if (!prepared) {
      autoGeneratingPath = null;
      return;
    }
    await completeQuickReplyAutoGenerateAttempt(
      app: app,
      generate: () => app.generateImage(
        imagePath,
        style ?? app.defaultStyle,
        effectiveImageReplyGoal(isQuickReply: true, goal: goal.text),
        selectedProfileId: selectedProfileId,
      ),
      showOverlay: (replies, returnPackage) async {
        if (mounted) {
          await FloatingCaptureBridge.showReplyOverlayForPlatform(
            replies,
            returnPackage: returnPackage,
          );
        }
      },
      showErrorOverlay: (message) async {
        if (mounted) {
          await showQuickReplyMessageOverlaySafely(
            message,
            title: '生成失败',
            onError: app.setError,
          );
        }
      },
      onError: app.setError,
    );
    autoGeneratingPath = null;
  }

  Future<void> _captureCurrentScreen() async {
    setState(() => isCapturing = true);
    try {
      final path = await FloatingCaptureBridge.isAccessibilityEnabled()
          ? await FloatingCaptureBridge.takeAccessibilityScreenshot()
          : await FloatingCaptureBridge.requestMediaProjectionScreenshot();
      if (!mounted) return;
      final cleanedPath = cleanImagePathInput(path);
      if (cleanedPath != null) {
        final app = ref.read(appProvider);
        clipboardFeedbackTimer?.cancel();
        app.clearFeedback(notify: false);
        if (mounted) setState(() => didReadClipboard = false);
        app.setQuickImagePath(cleanedPath, autoGenerate: true);
      }
    } catch (error) {
      if (!mounted) return;
      ref.read(appProvider).setError(userMessageFor(error));
    } finally {
      if (mounted) setState(() => isCapturing = false);
    }
  }

  Future<void> _readClipboardImage({bool autoGenerate = true}) async {
    setState(() => isCapturing = true);
    try {
      final path =
          cleanImagePathInput(await FloatingCaptureBridge.readClipboardImage());
      if (!mounted) return;
      if (path != null) {
        final app = ref.read(appProvider);
        clipboardFeedbackTimer?.cancel();
        app.clearFeedback(notify: false);
        if (mounted) setState(() => didReadClipboard = true);
        app.setQuickImagePath(path, autoGenerate: autoGenerate);
        clipboardFeedbackTimer = scheduleTransientFeedbackReset(
          previousTimer: clipboardFeedbackTimer,
          isMounted: () => mounted,
          reset: () => setState(() => didReadClipboard = false),
        );
      } else {
        _clearClipboardReadFeedback();
        final app = ref.read(appProvider);
        if (autoGenerate && app.quickImagePath == null) {
          app.clearPendingQuickAutoGenerate();
        }
        app.setError(noClipboardScreenshotMessage);
      }
    } catch (error) {
      _clearClipboardReadFeedback();
      if (!mounted) return;
      ref.read(appProvider).setError(userMessageFor(error));
    } finally {
      if (mounted) setState(() => isCapturing = false);
    }
  }

  void _clearClipboardReadFeedback() {
    clipboardFeedbackTimer?.cancel();
    if (mounted) setState(() => didReadClipboard = false);
  }
}
