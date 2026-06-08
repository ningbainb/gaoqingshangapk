import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/app_feedback.dart';
import '../core/app_provider.dart';
import '../core/app_state.dart';
import '../core/api_config_rules.dart';
import '../core/api_settings_draft_helpers.dart';
import '../core/models.dart';
import '../core/transient_feedback_timer.dart';
import '../widgets/api_settings_widgets.dart';
import '../widgets/glass_scaffold.dart';
import '../widgets/glass_widgets.dart';

class ApiSettingsScreen extends ConsumerStatefulWidget {
  const ApiSettingsScreen({super.key});

  @override
  ConsumerState<ApiSettingsScreen> createState() => _ApiSettingsScreenState();
}

class _ApiSettingsScreenState extends ConsumerState<ApiSettingsScreen> {
  late final base =
      TextEditingController(text: ref.read(appProvider).config.baseURL);
  late final key = TextEditingController(text: ref.read(appProvider).apiKey);
  late final vision =
      TextEditingController(text: ref.read(appProvider).config.visionModelName);
  late final text =
      TextEditingController(text: ref.read(appProvider).config.textModelName);
  double imageMaxWidth = APIConfig.defaults.imageMaxWidth;
  double imageQuality = APIConfig.defaults.imageCompressionQuality;
  double temperature = APIConfig.defaults.temperature;
  double maxTokens = APIConfig.defaults.maxTokens.toDouble();
  double timeout = APIConfig.defaults.timeout.toDouble();
  late Map<String, ModelCapability> modelCapabilities;
  late bool imageInputEnabled;
  late bool twoStepVisionEnabled;
  Timer? modelFetchTimer;
  Timer? apiKeyPasteFeedbackTimer;
  String? lastAutoFetchFingerprint;
  bool didPasteAPIKey = false;
  int draftRevision = 0;

  @override
  void initState() {
    super.initState();
    final config = ref.read(appProvider).config;
    _loadDraftFromConfig(config);
    Future.microtask(() {
      if (!mounted) return;
      final app = ref.read(appProvider);
      if (app.availableModels.isEmpty &&
          hasUsableAPIKey(app.apiKey) &&
          app.config.hasValidBaseUri) {
        unawaited(_autoFetchModelsIfReady());
      }
    });
  }

  @override
  void dispose() {
    modelFetchTimer?.cancel();
    apiKeyPasteFeedbackTimer?.cancel();
    base.dispose();
    key.dispose();
    vision.dispose();
    text.dispose();
    super.dispose();
  }

  APIConfig draftConfigFrom(APIConfig config) => apiSettingsDraftConfigFrom(
        source: config,
        baseURL: base.text,
        visionModelName: vision.text,
        textModelName: text.text,
        modelCapabilities: modelCapabilities,
        imageMaxWidth: imageMaxWidth,
        imageCompressionQuality: imageQuality,
        enableImageInput: imageInputEnabled,
        enableTwoStepVision: twoStepVisionEnabled,
        temperature: temperature,
        maxTokens: maxTokens,
        timeout: timeout,
      );

  APIConfig _currentDraftConfig() =>
      draftConfigFrom(ref.read(appProvider).config);

  void _scheduleAutoFetchModels() {
    _markDraftChanged();
    ref
        .read(appProvider)
        .invalidateModelsForDraftSource(_currentDraftConfig(), key.text);
    setState(() {});
    modelFetchTimer?.cancel();
    modelFetchTimer = Timer(const Duration(milliseconds: 700), () {
      unawaited(_autoFetchModelsIfReady());
    });
  }

  Future<void> _autoFetchModelsIfReady() async {
    if (!mounted) return;
    final app = ref.read(appProvider);
    final draft = draftConfigFrom(app.config);
    final draftKey = cleanAPIKeyInput(key.text);
    if (draftKey == null || !draft.hasValidBaseUri) return;
    final fingerprint = apiConfigSourceFingerprint(draft, draftKey);
    if (lastAutoFetchFingerprint == fingerprint &&
        app.availableModels.isNotEmpty) {
      return;
    }
    final requestDraftRevision = draftRevision;
    lastAutoFetchFingerprint = fingerprint;
    final fetchedConfig = await app.fetchModelsForDraft(draft, draftKey);
    if (!mounted) return;
    if (!_isCurrentDraftRevision(requestDraftRevision)) return;
    if (fetchedConfig == null) return;
    setState(() {
      _applyFetchedModelsConfig(fetchedConfig);
    });
  }

  Future<void> _fetchModelsNow() async {
    modelFetchTimer?.cancel();
    final requestDraftRevision = draftRevision;
    final fetchedConfig = await ref
        .read(appProvider)
        .fetchModelsForDraft(_currentDraftConfig(), key.text);
    if (!mounted) return;
    if (!_isCurrentDraftRevision(requestDraftRevision)) return;
    if (fetchedConfig == null) return;
    setState(() {
      _applyFetchedModelsConfig(fetchedConfig);
      lastAutoFetchFingerprint =
          apiConfigSourceFingerprint(fetchedConfig, key.text);
    });
  }

  @override
  Widget build(BuildContext context) {
    final app = ref.watch(appProvider);
    final draftConfig = _currentDraftConfig();
    final actionState = apiSettingsActionState(
      draftConfig: draftConfig,
      apiKey: key.text,
      isFetchingModels: app.isFetchingModels,
      isTestingConnection: app.isTestingConnection,
      isTestingVision: app.isTestingVision,
    );
    final visibleStatusMessage = isAPISettingsStatusMessage(app.statusMessage)
        ? cleanFeedbackMessage(app.statusMessage)
        : null;
    final visibleErrorMessage = isAPISettingsErrorMessage(app.errorMessage)
        ? cleanFeedbackMessage(app.errorMessage)
        : null;
    return GlassScaffold(
      title: 'API 设置',
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 76, 20, 96),
        children: [
          GlassTextField(
              controller: base,
              label: 'Base URL',
              hint: 'https://api.openai.com/v1',
              onChanged: (_) => _scheduleAutoFetchModels()),
          const SizedBox(height: 12),
          GlassTextField(
              controller: key,
              label: 'API Key',
              hint: '只保存在本机安全存储',
              obscure: true,
              onChanged: (_) {
                apiKeyPasteFeedbackTimer?.cancel();
                setState(() => didPasteAPIKey = false);
                _scheduleAutoFetchModels();
              }),
          const SizedBox(height: 8),
          APIKeyControlRow(
            hasKey: hasUsableAPIKey(key.text),
            didPasteAPIKey: didPasteAPIKey,
            onPaste: _pasteAPIKey,
            onClear: !hasUsableAPIKey(key.text)
                ? null
                : () {
                    key.clear();
                    _scheduleAutoFetchModels();
                  },
          ),
          const SizedBox(height: 12),
          FetchModelsButton(
            enabled: actionState.canFetchModels,
            isFetching: app.isFetchingModels,
            onPressed: () {
              unawaited(_fetchModelsNow());
            },
          ),
          if (app.availableModels.isNotEmpty) ...[
            const SizedBox(height: 12),
            ModelSelectCard(
              models: app.availableModels,
              visionModel: vision.text,
              textModel: text.text,
              onVision: (value) => _updateDraftState(() => vision.text = value),
              onText: (value) => _updateDraftState(() => text.text = value),
              capabilityFor: _capabilityFor,
              onCapability: _setDraftModelCapability,
            ),
          ],
          const SizedBox(height: 12),
          GlassTextField(
              controller: vision,
              label: '视觉模型名称',
              hint: 'gpt-4o-mini',
              onChanged: (_) => _updateDraftState()),
          const SizedBox(height: 12),
          GlassTextField(
              controller: text,
              label: '文本模型名称',
              hint: 'gpt-4o-mini',
              onChanged: (_) => _updateDraftState()),
          const SizedBox(height: 14),
          GlassCard(
            tint: imageInputEnabled
                ? Colors.blue.withValues(alpha: 0.12)
                : Colors.orange.withValues(alpha: 0.10),
            child: Material(
              type: MaterialType.transparency,
              child: SwitchListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                value: imageInputEnabled,
                title: const Text('启用截图模式'),
                subtitle: Text(imageInputEnabled
                    ? '聊天截图、朋友圈截图和快捷回复会调用视觉模型。'
                    : '关闭后仅保留文本生成，截图相关入口会提示先开启。'),
                secondary: Icon(imageInputEnabled
                    ? Icons.photo_camera_back_outlined
                    : Icons.image_not_supported_outlined),
                onChanged: (v) =>
                    _updateDraftState(() => imageInputEnabled = v),
              ),
            ),
          ),
          const SizedBox(height: 10),
          GlassCard(
            tint: twoStepVisionEnabled
                ? Colors.tealAccent.withValues(alpha: 0.10)
                : Colors.white.withValues(alpha: 0.06),
            child: Material(
              type: MaterialType.transparency,
              child: SwitchListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                value: twoStepVisionEnabled,
                title: const Text('两步式视觉识别'),
                subtitle: Text(twoStepVisionEnabled
                    ? '先提取截图文字，再用文本模型生成回复，更稳但会多一次请求。'
                    : '关闭时由视觉模型直接根据截图生成回复。'),
                secondary: const Icon(Icons.account_tree_outlined),
                onChanged: imageInputEnabled
                    ? (v) => _updateDraftState(() => twoStepVisionEnabled = v)
                    : null,
              ),
            ),
          ),
          const SizedBox(height: 14),
          APIGenerationParametersSection(
            imageMaxWidth: imageMaxWidth,
            imageQuality: imageQuality,
            temperature: temperature,
            maxTokens: maxTokens,
            timeout: timeout,
            onImageMaxWidthChanged: (v) =>
                _updateDraftState(() => imageMaxWidth = v),
            onImageQualityChanged: (v) =>
                _updateDraftState(() => imageQuality = v),
            onTemperatureChanged: (v) =>
                _updateDraftState(() => temperature = v),
            onMaxTokensChanged: (v) => _updateDraftState(() => maxTokens = v),
            onTimeoutChanged: (v) => _updateDraftState(() => timeout = v),
          ),
          const SizedBox(height: 18),
          if (visibleStatusMessage != null) SuccessBanner(visibleStatusMessage),
          if (visibleErrorMessage != null) ErrorBanner(visibleErrorMessage),
          FilledButton.icon(
            onPressed: () => app.saveConfig(_currentDraftConfig(), key.text),
            icon: const Icon(Icons.save_outlined),
            label: const Text('保存配置'),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
              onPressed: !actionState.canRunConnectionTest
                  ? null
                  : () => app.testConnection(draftConfig, key.text),
              icon: app.isTestingConnection
                  ? const SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.network_check),
              label: Text(app.isTestingConnection ? '测试中...' : '测试连接')),
          const SizedBox(height: 10),
          OutlinedButton.icon(
              onPressed: !actionState.canTestVisionModel
                  ? null
                  : () => app.testVisionConnection(draftConfig, key.text),
              icon: app.isTestingVision
                  ? const SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.photo_camera_back_outlined),
              label: Text(app.isTestingVision ? '测试中...' : '测试视觉模型')),
          const SizedBox(height: 10),
          OutlinedButton.icon(
              onPressed: !hasUsableAPIKey(key.text)
                  ? null
                  : () {
                      key.clear();
                      app.clearAPIKey();
                    },
              icon: const Icon(Icons.key_off_outlined),
              label: const Text('清除 API Key')),
          const SizedBox(height: 10),
          OutlinedButton.icon(
              onPressed: _confirmResetConfig,
              icon: const Icon(Icons.restore),
              label: const Text('恢复默认并清除 Key')),
        ],
      ),
    );
  }

  Future<void> _pasteAPIKey() async {
    ClipboardData? data;
    try {
      data = await Clipboard.getData(Clipboard.kTextPlain);
    } catch (error) {
      if (!mounted) return;
      apiKeyPasteFeedbackTimer?.cancel();
      setState(() => didPasteAPIKey = false);
      ref.read(appProvider).setError('读取剪贴板失败：${userMessageFor(error)}');
      return;
    }
    if (!mounted) return;
    final app = ref.read(appProvider);
    final pastedKey = pastedAPIKeyFromClipboardText(data?.text);
    if (pastedKey == null) {
      apiKeyPasteFeedbackTimer?.cancel();
      setState(() => didPasteAPIKey = false);
      app.setError(apiKeyPasteEmptyMessage);
      return;
    }
    setState(() {
      _markDraftChanged();
      key.text = pastedKey;
      didPasteAPIKey = true;
    });
    _scheduleAPIKeyPasteFeedbackReset();
    app.setStatus(apiKeyPasteSuccessMessage);
    _scheduleAutoFetchModels();
  }

  void _scheduleAPIKeyPasteFeedbackReset() {
    apiKeyPasteFeedbackTimer = scheduleTransientFeedbackReset(
      previousTimer: apiKeyPasteFeedbackTimer,
      isMounted: () => mounted,
      reset: () => setState(() => didPasteAPIKey = false),
    );
  }

  Future<void> _confirmResetConfig() async {
    final confirmed = await showConfirmationDialog(
      context,
      title: '恢复默认配置？',
      message: '这会清除 API Key，并把接口地址、模型名称和生成参数恢复为默认值。',
      confirmLabel: '恢复默认并清除 Key',
    );
    if (confirmed) {
      await _resetConfig();
    }
  }

  Future<void> _resetConfig() async {
    modelFetchTimer?.cancel();
    apiKeyPasteFeedbackTimer?.cancel();
    await ref.read(appProvider).resetConfig();
    if (!mounted) return;
    const defaults = APIConfig.defaults;
    setState(() {
      _loadDraftFromConfig(defaults);
      key.clear();
      didPasteAPIKey = false;
      lastAutoFetchFingerprint = null;
    });
  }

  void _loadDraftFromConfig(APIConfig config) {
    base.text = config.baseURL;
    vision.text = config.visionModelName;
    text.text = config.textModelName;
    imageMaxWidth = config.imageMaxWidth;
    imageQuality = config.imageCompressionQuality;
    temperature = config.temperature;
    maxTokens = config.maxTokens.toDouble();
    timeout = config.timeout.toDouble();
    modelCapabilities = Map<String, ModelCapability>.from(
      config.modelCapabilities,
    );
    imageInputEnabled = config.enableImageInput;
    twoStepVisionEnabled = config.enableTwoStepVision;
  }

  void _markDraftChanged() {
    draftRevision += 1;
  }

  bool _isCurrentDraftRevision(int revision) => revision == draftRevision;

  void _updateDraftState([VoidCallback? update]) {
    setState(() {
      _markDraftChanged();
      update?.call();
    });
  }

  void _applyFetchedModelsConfig(APIConfig config) {
    vision.text = config.visionModelName;
    text.text = config.textModelName;
    modelCapabilities = Map<String, ModelCapability>.from(
      config.modelCapabilities,
    );
  }

  ModelCapability _capabilityFor(String modelId) =>
      APIConfig.lookupCapability(modelCapabilities, modelId);

  void _setDraftModelCapability(String modelId,
      {bool? isMultimodal, bool? isReasoning}) {
    setState(() {
      _markDraftChanged();
      modelCapabilities = apiSettingsDraftCapabilitiesWith(
        modelCapabilities,
        modelId,
        isMultimodal: isMultimodal,
        isReasoning: isReasoning,
      );
    });
  }
}
