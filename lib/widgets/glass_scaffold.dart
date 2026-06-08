import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/app_provider.dart';
import '../core/app_state.dart';
import '../core/presentation_helpers.dart';
import 'glass_widgets.dart';

class GlassScaffold extends ConsumerStatefulWidget {
  const GlassScaffold({super.key, required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  ConsumerState<GlassScaffold> createState() => _GlassScaffoldState();
}

class _GlassScaffoldState extends ConsumerState<GlassScaffold> {
  bool _privacySheetOpen = false;

  @override
  Widget build(BuildContext context) {
    final appearance = ref.watch(appProvider.select((app) => app.appearance));
    final shouldShowPrivacy =
        ref.watch(appProvider.select((app) => app.showingPrivacyNotice));
    if (shouldShowPrivacy && !_privacySheetOpen) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showPrivacyNotice();
      });
    }
    final customBackground = appearance.customBackgroundPath;
    final hasCustomBackground =
        customBackground != null && File(customBackground).existsSync();
    final cacheWidth = (MediaQuery.sizeOf(context).width *
            MediaQuery.devicePixelRatioOf(context))
        .round()
        .clamp(720, 1440);
    final background = hasCustomBackground
        ? Image.file(File(customBackground),
            fit: BoxFit.cover,
            cacheWidth: cacheWidth,
            filterQuality: FilterQuality.low)
        : Image.asset('assets/images/bloom_glass_background.png',
            fit: BoxFit.cover,
            cacheWidth: cacheWidth,
            filterQuality: FilterQuality.low);
    final backgroundLayer = appearance.isBackgroundBlurEnabled &&
            appearance.backgroundBlurRadius > 0
        ? ImageFiltered(
            imageFilter: ImageFilter.blur(
                sigmaX: appearance.backgroundBlurRadius,
                sigmaY: appearance.backgroundBlurRadius),
            child: background,
          )
        : background;
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(widget.title),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: RepaintBoundary(
              child: backgroundLayer,
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    const Color(0xFF005C94).withValues(
                        alpha: (0.58 + appearance.backgroundDimOpacity)
                            .clamp(0.0, 0.92)),
                    appearance.accentColor.withValues(
                        alpha: (0.22 + appearance.backgroundDimOpacity)
                            .clamp(0.0, 0.66)),
                    Colors.transparent,
                    const Color(0xFFF78A05).withValues(
                        alpha: (0.14 + appearance.backgroundDimOpacity)
                            .clamp(0.0, 0.54)),
                  ],
                ),
              ),
            ),
          ),
          widget.child,
        ],
      ),
    );
  }

  Future<void> _showPrivacyNotice() async {
    final app = ref.read(appProvider);
    if (_privacySheetOpen || !app.showingPrivacyNotice) return;
    _privacySheetOpen = true;
    await showModalBottomSheet<void>(
      context: context,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.all(16),
        child: GlassCard(
          radius: 24,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('隐私与数据',
                    style:
                        TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                const SizedBox(height: 12),
                const Text(
                    '截图只在你主动选择、分享或点击悬浮窗后处理。原始截图不会保存到历史记录。API Key 只保存在本机安全存储中。'),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: () async {
                    await app.markPrivacySeen();
                    if (sheetContext.mounted) Navigator.pop(sheetContext);
                  },
                  icon: const Icon(Icons.check),
                  label: const Text('我知道了'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (mounted) {
      setState(() => _privacySheetOpen = false);
    } else {
      _privacySheetOpen = false;
    }
  }
}
