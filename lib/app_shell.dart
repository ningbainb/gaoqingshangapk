import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'app_router.dart';
import 'core/app_feedback.dart';
import 'core/app_provider.dart';
import 'core/app_routes.dart';
import 'core/app_state.dart';
import 'core/models.dart';
import 'core/platform_bridge.dart';
import 'core/presentation_helpers.dart';
import 'core/quick_reply_flow.dart';

class AIReplyApp extends ConsumerStatefulWidget {
  const AIReplyApp({super.key});

  @override
  ConsumerState<AIReplyApp> createState() => _AIReplyAppState();
}

class _AIReplyAppState extends ConsumerState<AIReplyApp> {
  StreamSubscription<FloatingCaptureEvent>? _floatingSub;
  String? _floatingGenerationPath;
  String? _pendingExternalPath;
  bool _didAttemptAutoStartFloating = false;
  late final GoRouter _router = buildAIReplyRouter();

  @override
  void initState() {
    super.initState();
    _floatingSub = FloatingCaptureBridge.events.listen(
      _handleFloatingEvent,
      onError: _handleFloatingEventError,
    );
  }

  void _handleFloatingEvent(FloatingCaptureEvent event) {
    if (event.path != null) {
      if (event.source == 'floating') {
        unawaited(_handleFloatingCapture(event.path!));
      } else if (event.source == 'share') {
        ref.read(appProvider).setSharedImagePath(event.path!);
        _routeExternalPath(AppRoutes.image);
      } else {
        ref.read(appProvider).setQuickImagePath(
              event.path!,
              autoGenerate: true,
              resetDraft: true,
            );
        _routeExternalPath(AppRoutes.quick);
      }
    } else if (event.text != null) {
      ref.read(appProvider).setSharedText(event.text!);
      _routeExternalPath(AppRoutes.text);
    } else if (event.copiedReply != null) {
      unawaited(
          ref.read(appProvider).markNativeCopiedReply(event.copiedReply!));
    } else if (event.route != null) {
      final path = appPathForExternalRoute(event.route);
      if (path != null) {
        if (isNewProfileExternalRoute(event.route)) {
          ref.read(appProvider).selectProfile(null);
        }
        if (isQuickExternalRoute(event.route)) {
          ref.read(appProvider).requestQuickClipboardImport();
        }
        if (isImageExternalRoute(event.route)) {
          ref.read(appProvider).prepareExternalImageInput();
        }
        if (isTextExternalRoute(event.route)) {
          ref.read(appProvider).prepareExternalTextInput();
        }
        _routeExternalPath(path);
      }
    } else if (event.error != null) {
      ref.read(appProvider).setError(event.error!);
    }
  }

  void _handleFloatingEventError(Object error, StackTrace stackTrace) {
    if (!mounted) return;
    ref.read(appProvider).setError(userMessageFor(error));
  }

  Future<void> _handleFloatingCapture(String imagePath) async {
    final app = ref.read(appProvider);
    if (_floatingGenerationPath != null || app.isBusy) {
      if (_floatingGenerationPath != imagePath) {
        await app.discardTransientImagePath(imagePath);
      }
      await showQuickReplyMessageOverlaySafely(
        '正在生成中，请稍后再试。',
        title: 'AI Reply 正在忙',
        onError: app.setError,
      );
      return;
    }
    _floatingGenerationPath = imagePath;
    var deferredForPrivacy = false;
    try {
      if (app.shouldDeferExternalHandoffs) {
        deferredForPrivacy = true;
        app.setQuickImagePath(
          imagePath,
          autoGenerate: true,
          resetDraft: true,
        );
        _routeExternalPath(AppRoutes.quick);
        return;
      }
      app.setQuickImagePath(imagePath, resetDraft: true);
      await FloatingCaptureBridge.showAnalyzingOverlay();
      await FloatingCaptureBridge.collapseQuickPanel();

      for (var attempt = 0;
          attempt < 10 && !hasUsableAPIKey(app.apiKey);
          attempt++) {
        await Future<void>.delayed(const Duration(milliseconds: 120));
      }
      final readiness = GenerateAPIReadiness(
        config: app.config,
        hasAPIKey: hasUsableAPIKey(app.apiKey),
        capability: GenerateAPICapability.vision,
        isQuickReply: true,
      );
      if (!readiness.isReady) {
        await showQuickReplyMessageOverlaySafely(
          readiness.statusText,
          title: '需要完成设置',
          onError: app.setError,
        );
        return;
      }
      final selectedStyle = app.defaultStyle;
      await app.generateImage(imagePath, selectedStyle,
          effectiveImageReplyGoal(isQuickReply: true, goal: ''));
      final replies = quickReplyCopyableOverlayReplies(app);
      if (replies.isEmpty) {
        await showQuickReplyMessageOverlaySafely(
          quickReplyOverlayMessage(app),
          title: quickReplyOverlayTitle(app),
          onError: app.setError,
        );
      } else {
        await showQuickReplyOverlaySafely(
          replies,
          returnPackage:
              quickReplyReturnPackageForPlatform(app.currentResponse?.platform),
          onError: app.setError,
        );
      }
    } catch (error) {
      final message = userMessageFor(error);
      app.setError(message);
      await showQuickReplyMessageOverlaySafely(
        message,
        title: '生成失败',
        onError: app.setError,
      );
    } finally {
      if (!deferredForPrivacy) {
        await app.finishQuickReplySession();
      }
      _floatingGenerationPath = null;
    }
  }

  @override
  void dispose() {
    _floatingSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<bool>(
      appProvider.select((app) => app.shouldDeferExternalHandoffs),
      (previous, next) {
        if (previous == true && !next) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              _flushPendingExternalPath();
              _autoStartFloatingWindowIfNeeded();
            }
          });
        }
      },
    );
    final appearance = ref.watch(appProvider.select((app) => app.appearance));
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      routerConfig: _router,
      title: 'AI Reply',
      theme: ThemeData(
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
            seedColor: appearance.accentColor, brightness: Brightness.dark),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFF061823),
        fontFamily: Platform.isAndroid ? 'sans' : null,
      ),
      builder: (context, child) {
        final media = MediaQuery.of(context);
        return MediaQuery(
          data: media.copyWith(
              textScaler: TextScaler.linear(appearance.textScale)),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }

  void _routeExternalPath(String path) {
    if (ref.read(appProvider).shouldDeferExternalHandoffs) {
      _pendingExternalPath = path;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _flushPendingExternalPath();
      });
      return;
    }
    _router.go(path);
  }

  void _flushPendingExternalPath() {
    if (ref.read(appProvider).shouldDeferExternalHandoffs) return;
    final path = _pendingExternalPath;
    if (path == null) return;
    _pendingExternalPath = null;
    _router.go(path);
  }

  Future<void> _autoStartFloatingWindowIfNeeded() async {
    if (_didAttemptAutoStartFloating) return;
    _didAttemptAutoStartFloating = true;
    final app = ref.read(appProvider);
    if (!app.floatingAutoStart) return;
    final readiness = GenerateAPIReadiness(
      config: app.config,
      hasAPIKey: hasUsableAPIKey(app.apiKey),
      capability: GenerateAPICapability.vision,
      isQuickReply: true,
    );
    if (!readiness.isReady) return;
    try {
      final hasOverlay = await FloatingCaptureBridge.hasOverlayPermission();
      final hasAccessibility =
          await FloatingCaptureBridge.isAccessibilityEnabled();
      if (!hasOverlay || !hasAccessibility) return;
      await FloatingCaptureBridge.startFloatingWindow();
    } catch (_) {
      // Silently ignore auto-start failures
    }
  }
}
