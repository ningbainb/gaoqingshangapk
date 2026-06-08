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
import '../core/generation_flow.dart';
import '../core/models.dart';
import '../core/platform_bridge.dart';
import '../core/presentation_helpers.dart';
import '../core/transient_feedback_timer.dart';
import '../widgets/glass_scaffold.dart';
import '../widgets/glass_widgets.dart';
import '../widgets/image_input_widgets.dart';
import '../widgets/profile_widgets.dart';
import 'profile_selection_helpers.dart';

class MomentProfileScreen extends ConsumerStatefulWidget {
  const MomentProfileScreen({super.key});

  @override
  ConsumerState<MomentProfileScreen> createState() =>
      _MomentProfileScreenState();
}

class _MomentProfileScreenState extends ConsumerState<MomentProfileScreen> {
  String? path;
  String? selectedProfileId;
  bool isReadingClipboard = false;
  bool didReadClipboard = false;
  Timer? clipboardFeedbackTimer;

  @override
  void initState() {
    super.initState();
    final app = ref.read(appProvider);
    app.clearFeedback(notify: false);
    app.clearMomentResult(notify: false);
  }

  @override
  void dispose() {
    clipboardFeedbackTimer?.cancel();
    final previewPath = path;
    path = null;
    if (isOwnedTransientImagePath(previewPath)) {
      unawaited(ref.read(appProvider).discardTransientImagePath(previewPath));
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = ref.watch(appProvider);
    final readiness = GenerateAPIReadiness(
      config: app.config,
      hasAPIKey: hasUsableAPIKey(app.apiKey),
      capability: GenerateAPICapability.vision,
    );
    return GlassScaffold(
      title: '朋友圈画像',
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 76, 20, 96),
        children: [
          const MomentProfileHeaderCard(),
          const SizedBox(height: 16),
          APIReadinessCard(readiness: readiness),
          const SizedBox(height: 16),
          if (path == null)
            GlassCard(
              child: SizedBox(
                height: 240,
                child: Center(
                    child: Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  alignment: WrapAlignment.center,
                  children: [
                    FilledButton.icon(
                        onPressed: _pick,
                        icon: const Icon(Icons.add_photo_alternate_outlined),
                        label: const Text('选择动态截图')),
                    MomentProfileClipboardButton(
                      isReadingClipboard: isReadingClipboard,
                      didReadClipboard: didReadClipboard,
                      onPressed: _readClipboardImage,
                    ),
                  ],
                )),
              ),
            )
          else
            GlassCard(
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: Image.file(File(path!),
                            height: 340,
                            width: double.infinity,
                            fit: BoxFit.contain,
                            cacheWidth: 900,
                            filterQuality: FilterQuality.low)),
                    const SizedBox(height: 10),
                    Row(children: [
                      const Expanded(
                          child: Text('已选择动态截图',
                              style: TextStyle(color: Colors.white70))),
                      TextButton.icon(
                        onPressed: _pick,
                        icon: const Icon(Icons.photo_library_outlined),
                        label: const Text('更换'),
                      ),
                      MomentProfileClipboardButton(
                        isReadingClipboard: isReadingClipboard,
                        didReadClipboard: didReadClipboard,
                        compact: true,
                        onPressed: _readClipboardImage,
                      ),
                      TextButton.icon(
                        onPressed: () {
                          final app = ref.read(appProvider);
                          final previewPath = path;
                          app.clearMomentResult(notify: false);
                          setState(() {
                            path = null;
                            didReadClipboard = false;
                            clipboardFeedbackTimer?.cancel();
                          });
                          if (isOwnedTransientImagePath(previewPath)) {
                            unawaited(
                                app.discardTransientImagePath(previewPath));
                          }
                        },
                        icon: const Icon(Icons.delete_outline),
                        label: const Text('删除'),
                      ),
                    ]),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 18),
          PersonProfilePickerCard(
            title: '目标人物',
            profiles: app.profiles,
            selectedProfileId: selectedProfileId,
            onChanged: (next) {
              app.clearFeedback(notify: false);
              setState(() => selectedProfileId = next);
            },
            emptyText: '未选择时会按截图内容新建人物画像。',
            autoSummary: '自动模式会结合最近的人物库判断是否新建或合并。',
            selectedSummary: (profile) => '将合并到「${profile.displayLabel}」的人物画像。',
          ),
          const SizedBox(height: 18),
          if (app.errorMessage != null) ErrorBanner(app.errorMessage!),
          FilledButton.icon(
            onPressed: !canSubmitMomentProfileAnalysis(
              readiness: readiness,
              isBusy: app.isBusy,
              imagePath: path,
            )
                ? null
                : () async {
                    final submittedPath = path!;
                    await app.analyzeMoment(
                      submittedPath,
                      target: selectedScreenProfile(
                        app.profiles,
                        selectedProfileId,
                      ),
                    );
                    if (!mounted) return;
                    if (app.currentMomentAnalysis != null &&
                        isOwnedTransientImagePath(submittedPath) &&
                        path == submittedPath) {
                      setState(() {
                        path = null;
                        didReadClipboard = false;
                        clipboardFeedbackTimer?.cancel();
                      });
                    }
                  },
            icon: const Icon(Icons.person_search_outlined),
            label: Text(app.isBusy ? '分析中...' : '分析并写入人物库'),
          ),
          if (app.currentMomentAnalysis != null) ...[
            const SizedBox(height: 16),
            MomentAnalysisCard(
              analysis: app.currentMomentAnalysis!,
              savedProfile: app.currentMomentProfile,
              onOpenProfile: app.currentMomentProfile == null
                  ? null
                  : () {
                      app.selectProfile(app.currentMomentProfile);
                      context.push(AppRoutes.peopleDetail);
                    },
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _pick() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (!mounted) return;
    if (picked != null) {
      final app = ref.read(appProvider);
      final previousPath = path;
      app.clearFeedback(notify: false);
      app.clearMomentResult(notify: false);
      setState(() {
        path = picked.path;
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
      final clipboardPath =
          cleanImagePathInput(await FloatingCaptureBridge.readClipboardImage());
      if (clipboardPath != null && mounted) {
        final app = ref.read(appProvider);
        final previousPath = path;
        app.clearFeedback(notify: false);
        app.clearMomentResult(notify: false);
        setState(() {
          path = clipboardPath;
          didReadClipboard = true;
        });
        clipboardFeedbackTimer = scheduleTransientFeedbackReset(
          previousTimer: clipboardFeedbackTimer,
          isMounted: () => mounted,
          reset: () => setState(() => didReadClipboard = false),
        );
        if (previousPath != clipboardPath &&
            isOwnedTransientImagePath(previousPath)) {
          unawaited(app.discardTransientImagePath(previousPath));
        }
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

  void _clearClipboardReadFeedback() {
    clipboardFeedbackTimer?.cancel();
    if (mounted) setState(() => didReadClipboard = false);
  }
}
