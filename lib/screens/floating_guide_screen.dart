import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/app_feedback.dart';
import '../core/app_provider.dart';
import '../core/app_routes.dart';
import '../core/app_state.dart';
import '../core/models.dart';
import '../core/platform_bridge.dart';
import '../core/quick_reply_flow.dart';
import '../core/transient_feedback_timer.dart';
import '../widgets/floating_guide_widgets.dart';
import '../widgets/glass_scaffold.dart';

class FloatingGuideScreen extends ConsumerStatefulWidget {
  const FloatingGuideScreen({super.key});

  @override
  ConsumerState<FloatingGuideScreen> createState() =>
      _FloatingGuideScreenState();
}

class _FloatingGuideScreenState extends ConsumerState<FloatingGuideScreen>
    with WidgetsBindingObserver {
  bool overlay = false;
  bool accessibility = false;
  bool accessibilityConnected = false;
  bool notification = true;
  bool refreshing = true;
  bool didCopyQuickUrl = false;
  bool shouldStartFloatingAfterPermission = false;
  String? permissionError;
  Timer? copyTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    copyTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshStatus(autoStartWhenReady: true);
    }
  }

  Future<void> _refresh() async {
    await _refreshStatus();
  }

  Future<void> _refreshStatus({bool autoStartWhenReady = false}) async {
    if (!mounted) return;
    setState(() {
      refreshing = true;
      permissionError = null;
    });
    bool nextOverlay;
    bool nextNotification;
    bool nextAccessibility;
    bool nextAccessibilityConnected;
    try {
      nextOverlay = await FloatingCaptureBridge.hasOverlayPermission();
      nextNotification =
          await FloatingCaptureBridge.hasNotificationPermission();
      nextAccessibility = await FloatingCaptureBridge.isAccessibilityEnabled();
      nextAccessibilityConnected =
          await FloatingCaptureBridge.isAccessibilityConnected();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        refreshing = false;
        overlay = false;
        notification = true;
        accessibility = false;
        accessibilityConnected = false;
        permissionError = '权限状态读取失败：${userMessageFor(error)}';
      });
      return;
    }
    if (!mounted) return;
    setState(() {
      overlay = nextOverlay;
      notification = nextNotification;
      accessibility = nextAccessibility;
      accessibilityConnected = nextAccessibilityConnected;
      refreshing = false;
    });
    if (!mounted ||
        !autoStartWhenReady ||
        !shouldStartFloatingAfterPermission ||
        !_canStartFloating(
          GenerateAPIReadiness(
            config: ref.read(appProvider).config,
            hasAPIKey: hasUsableAPIKey(ref.read(appProvider).apiKey),
            capability: GenerateAPICapability.vision,
            isQuickReply: true,
          ),
        )) {
      return;
    }
    shouldStartFloatingAfterPermission = false;
    await _startFloatingWindow();
  }

  @override
  Widget build(BuildContext context) {
    final app = ref.watch(appProvider);
    final readiness = GenerateAPIReadiness(
      config: app.config,
      hasAPIKey: hasUsableAPIKey(app.apiKey),
      capability: GenerateAPICapability.vision,
      isQuickReply: true,
    );
    final canStartFloating = _canStartFloating(readiness);
    return GlassScaffold(
      title: '悬浮窗截图',
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 76, 20, 96),
        children: [
          const FloatingGuideHeroCard(),
          const SizedBox(height: 14),
          FloatingPreviewCard(canStartFloating: canStartFloating),
          const SizedBox(height: 14),
          FloatingApiReadinessDetailsCard(readiness: readiness),
          const SizedBox(height: 14),
          FloatingStyleCard(app: app),
          const SizedBox(height: 14),
          FloatingPermissionCard(
            refreshing: refreshing,
            permissionError: permissionError,
            overlay: overlay,
            notification: notification,
            accessibility: accessibility,
            accessibilityConnected: accessibilityConnected,
            readiness: readiness,
            onApiSettings: () => context.push(AppRoutes.api),
            onOverlaySettings: _openOverlaySettings,
            onNotificationPermission: _requestNotificationPermission,
            onAccessibilitySettings: _openAccessibilitySettings,
            onRefresh: _refresh,
          ),
          const SizedBox(height: 14),
          const FloatingGuideStep(
              number: '1',
              title: '开启悬浮窗',
              description: '先授权悬浮窗权限和无障碍增强，再启动悬浮按钮。常驻时会显示前台服务通知。'),
          const FloatingGuideStep(
              number: '2',
              title: '点击悬浮按钮',
              description: '点击后才会通过无障碍截图读取当前屏幕，适合不跳回 App 的快捷回复。'),
          const FloatingGuideStep(
              number: '3',
              title: '生成并复制',
              description: '预览截图、选择风格、填写目标，生成回复后点复制，快速面板会自动收起。'),
          const FloatingGuideStep(
              number: '4',
              title: 'App 内备用截图',
              description: '在 App 内点击截图按钮仍会走 MediaProjection 系统授权，不会静默读取屏幕。'),
          const SizedBox(height: 14),
          FloatingQuickUrlCard(
            didCopyQuickUrl: didCopyQuickUrl,
            onCopy: _copyQuickUrl,
            onTest: () {
              prepareQuickShortcutFallback(ref.read(appProvider));
              context.go(AppRoutes.quick);
            },
          ),
          const SizedBox(height: 14),
          SwitchListTile(
            title: const Text(
              '启动 App 时自动开启悬浮窗',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            subtitle: Text(
              canStartFloating
                  ? '开启后每次打开 App 将自动启动悬浮窗'
                  : '需先完成上方权限授权和 API 设置',
              style: TextStyle(
                color: canStartFloating ? Colors.white60 : Colors.orangeAccent,
                fontSize: 12,
              ),
            ),
            value: app.floatingAutoStart,
            onChanged: canStartFloating
                ? (value) => app.setFloatingAutoStart(value)
                : null,
            activeTrackColor: Colors.tealAccent,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: !canStartFloating ? null : _startFloatingWindow,
                icon: const Icon(Icons.play_circle_outline),
                label: const Text('启动悬浮窗'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _stopFloatingWindow,
                icon: const Icon(Icons.stop_circle_outlined),
                label: const Text('关闭悬浮窗'),
              ),
            ),
          ]),
        ],
      ),
    );
  }

  bool _canStartFloating(GenerateAPIReadiness readiness) =>
      readiness.isReady && overlay && accessibility;

  void _showFloatingGuideSnack(String message) {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _openOverlaySettings() async {
    shouldStartFloatingAfterPermission = !overlay;
    try {
      await FloatingCaptureBridge.openOverlaySettings();
    } catch (error) {
      shouldStartFloatingAfterPermission = false;
      if (!mounted) return;
      _showFloatingGuideSnack('打开悬浮窗权限失败：${userMessageFor(error)}');
      return;
    }
    await _refreshStatus(autoStartWhenReady: true);
  }

  Future<void> _requestNotificationPermission() async {
    bool granted;
    try {
      granted = await FloatingCaptureBridge.requestNotificationPermission();
    } catch (error) {
      if (!mounted) return;
      _showFloatingGuideSnack('请求通知权限失败：${userMessageFor(error)}');
      return;
    }
    if (!mounted) return;
    setState(() => notification = granted);
    _showFloatingGuideSnack(
        granted ? '通知权限已开启' : '未开启通知权限，悬浮窗仍可尝试启动，但常驻通知可能不可见。');
  }

  Future<void> _openAccessibilitySettings() async {
    shouldStartFloatingAfterPermission = !accessibility;
    try {
      await FloatingCaptureBridge.openAccessibilitySettings();
    } catch (error) {
      shouldStartFloatingAfterPermission = false;
      if (!mounted) return;
      _showFloatingGuideSnack('打开无障碍设置失败：${userMessageFor(error)}');
      return;
    }
    await _refreshStatus(autoStartWhenReady: true);
  }

  Future<void> _startFloatingWindow() async {
    try {
      await FloatingCaptureBridge.startFloatingWindow();
    } catch (error) {
      if (!mounted) return;
      _showFloatingGuideSnack('启动悬浮窗失败：${userMessageFor(error)}');
      return;
    }
    if (!mounted) return;
    _showFloatingGuideSnack('悬浮窗已启动');
  }

  Future<void> _stopFloatingWindow() async {
    try {
      await FloatingCaptureBridge.stopFloatingWindow();
    } catch (error) {
      if (!mounted) return;
      _showFloatingGuideSnack('关闭悬浮窗失败：${userMessageFor(error)}');
      return;
    }
    if (!mounted) return;
    _showFloatingGuideSnack('悬浮窗已关闭');
  }

  Future<void> _copyQuickUrl() async {
    try {
      await Clipboard.setData(const ClipboardData(text: quickShortcutUrl));
    } catch (error) {
      if (!mounted) return;
      _showFloatingGuideSnack('复制备用 URL 失败：${userMessageFor(error)}');
      return;
    }
    if (!mounted) return;
    setState(() => didCopyQuickUrl = true);
    copyTimer = scheduleTransientFeedbackReset(
      previousTimer: copyTimer,
      isMounted: () => mounted,
      reset: () => setState(() => didCopyQuickUrl = false),
      delay: const Duration(milliseconds: 1300),
    );
  }
}
