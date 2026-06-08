import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:ai_reply/core/api_base_url.dart';
import 'package:ai_reply/core/api_config_rules.dart';
import 'package:ai_reply/core/api_settings_draft_helpers.dart';
import 'package:ai_reply/core/api_failure_messages.dart';
import 'package:ai_reply/core/api_service.dart';
import 'package:ai_reply/core/app_routes.dart';
import 'package:ai_reply/core/app_state.dart';
import 'package:ai_reply/core/bool_value.dart';
import 'package:ai_reply/core/connection_interruption.dart';
import 'package:ai_reply/core/generation_goal_helpers.dart';
import 'package:ai_reply/core/history_record_collection_helpers.dart';
import 'package:ai_reply/core/image_service.dart';
import 'package:ai_reply/core/loose_key.dart';
import 'package:ai_reply/core/model_id.dart';
import 'package:ai_reply/core/model_recommendation_helpers.dart';
import 'package:ai_reply/core/owned_file_cleaner.dart';
import 'package:ai_reply/core/platform_bridge.dart';
import 'package:ai_reply/core/presentation_helpers.dart';
import 'package:ai_reply/core/profile_insights.dart';
import 'package:ai_reply/core/prompts.dart';
import 'package:ai_reply/core/record_retention.dart';
import 'package:ai_reply/core/search_match.dart';
import 'package:ai_reply/core/storage.dart';
import 'package:ai_reply/core/text_cleaning.dart';
import 'package:ai_reply/core/text_truncation.dart';
import 'package:ai_reply/screens/profile_selection_helpers.dart';
import 'package:ai_reply/widgets/api_settings_widgets.dart';
import 'package:ai_reply/widgets/history_record_card_widgets.dart';
import 'package:ai_reply/widgets/profile_picker_widgets.dart';
import 'package:ai_reply/widgets/profile_result_widgets.dart';
import 'package:ai_reply/main.dart' as app_shell;
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:ai_reply/core/models.dart';
import 'package:image/image.dart' as img;
import 'package:shared_preferences/shared_preferences.dart';

class FakeApi extends OpenAICompatibleApi {
  @override
  Future<ChatReplyResponse> generateReply(
    ChatInput input,
    APIConfig config,
    String apiKey,
  ) async {
    return ChatReplyResponse(
      sceneSummary: '测试场景',
      replies: [
        ReplySuggestion(
            styleLabel: input.selectedStyle.name, text: '收到', reason: '测试'),
      ],
    );
  }

  @override
  Future<MomentProfileAnalysis> analyzeMomentScreenshot(
    ImagePayload image,
    String? personContext,
    APIConfig config,
    String apiKey,
  ) async {
    return const MomentProfileAnalysis(
      sceneSummary: '测试画像',
      visibleName: '小林',
      confidence: 0.8,
    );
  }

  @override
  Future<SimulationTurnResponse> runSimulationTurn({
    required PersonProfile profile,
    required SimulationScenario scenario,
    required List<SimulationMessage> history,
    required String? userReply,
    required String personalizationContext,
    required APIConfig config,
    required String apiKey,
  }) async {
    return SimulationTurnResponse(
      personaMessage:
          userReply == null ? '开场-${scenario.title}' : '回应-$userReply',
      sceneState: scenario.promptGoal,
      options: [
        SimulationOption(text: '建议回复', label: '建议', reason: '测试'),
      ],
      coachTip: '测试提示',
    );
  }
}

class RecordingVisionApi extends FakeApi {
  int visionTestCalls = 0;

  @override
  Future<void> testVisionConnection(APIConfig config, String apiKey) async {
    visionTestCalls += 1;
  }
}

class FakeModelsApi extends OpenAICompatibleApi {
  FakeModelsApi(this.models);

  final List<APIModel> models;
  String? lastAPIKey;

  @override
  Future<List<APIModel>> fetchModels(APIConfig config, String apiKey) async {
    lastAPIKey = apiKey;
    return models;
  }
}

class NamelessMomentApi extends FakeApi {
  @override
  Future<MomentProfileAnalysis> analyzeMomentScreenshot(
    ImagePayload image,
    String? personContext,
    APIConfig config,
    String apiKey,
  ) async {
    return const MomentProfileAnalysis(
      sceneSummary: '无昵称动态',
      confidence: 0.5,
    );
  }
}

class RecordingMomentContextApi extends FakeApi {
  final personContexts = <String?>[];

  @override
  Future<MomentProfileAnalysis> analyzeMomentScreenshot(
    ImagePayload image,
    String? personContext,
    APIConfig config,
    String apiKey,
  ) async {
    personContexts.add(personContext);
    return const MomentProfileAnalysis(
      sceneSummary: '动态上下文',
      visibleName: '小林',
      confidence: 0.8,
    );
  }
}

class FailingMomentApi extends FakeApi {
  @override
  Future<MomentProfileAnalysis> analyzeMomentScreenshot(
    ImagePayload image,
    String? personContext,
    APIConfig config,
    String apiKey,
  ) async {
    throw AppException('画像失败');
  }
}

class FailingSimulationApi extends FakeApi {
  @override
  Future<SimulationTurnResponse> runSimulationTurn({
    required PersonProfile profile,
    required SimulationScenario scenario,
    required List<SimulationMessage> history,
    required String? userReply,
    required String personalizationContext,
    required APIConfig config,
    required String apiKey,
  }) async {
    if (userReply != null) {
      throw AppException('模拟失败');
    }
    return super.runSimulationTurn(
      profile: profile,
      scenario: scenario,
      history: history,
      userReply: userReply,
      personalizationContext: personalizationContext,
      config: config,
      apiKey: apiKey,
    );
  }
}

class MetadataApi extends FakeApi {
  @override
  Future<ChatReplyResponse> generateReply(
    ChatInput input,
    APIConfig config,
    String apiKey,
  ) async {
    return ChatReplyResponse(
      sceneSummary: '约晚饭',
      platform: '微信',
      relationshipGuess: '朋友',
      latestMessage: '晚上吃啥',
      emotion: '期待',
      riskNotice: '别承诺太满',
      replies: [
        ReplySuggestion(
            styleLabel: input.selectedStyle.name,
            text: '看你想吃啥',
            reason: '顺着约饭'),
      ],
    );
  }
}

class InsightApi extends FakeApi {
  @override
  Future<ChatReplyResponse> generateReply(
    ChatInput input,
    APIConfig config,
    String apiKey,
  ) async {
    return ChatReplyResponse(
      sceneSummary: '确认时间',
      replies: [
        ReplySuggestion(
            styleLabel: input.selectedStyle.name,
            text: '我提前看下时间',
            reason: '稳住'),
      ],
      personInsight: const PersonInsight(
        displayName: '小林',
        aliases: ['Lin'],
        relationship: '同事',
        keyPersonPoints: ['喜欢提前确认时间'],
        confidence: 0.8,
        updateReason: '聊天中强调提前确认',
      ),
    );
  }
}

class DirtyInsightApi extends FakeApi {
  @override
  Future<ChatReplyResponse> generateReply(
    ChatInput input,
    APIConfig config,
    String apiKey,
  ) async {
    return ChatReplyResponse(
      sceneSummary: '  新画像场景  ',
      replies: [
        ReplySuggestion(
            styleLabel: input.selectedStyle.name, text: '收到', reason: '测试'),
      ],
      personInsight: const PersonInsight(
        displayName: ' 小林 ',
        aliases: [' Lin ', ' ', '未知'],
        relationship: ' 同事 ',
        communicationStyle: ' 直接一点 ',
        personalityTraits: [' 稳 ', '', '未知'],
        innerNeeds: [' 确定性 ', '未知'],
        keyPersonPoints: [' 提前确认时间 ', ' '],
        momentsInsights: [' 常发工作动态 ', '未知'],
        tonePreferences: [' 少绕弯 ', ''],
        boundaries: [' 别催促 ', '未知'],
        facts: [' 在上海 ', ' '],
        confidence: 0.8,
        updateReason: ' 聊天中强调提前确认 ',
      ),
    );
  }
}

class DirtyResponseApi extends FakeApi {
  @override
  Future<ChatReplyResponse> generateReply(
    ChatInput input,
    APIConfig config,
    String apiKey,
  ) async {
    return ChatReplyResponse(
      sceneSummary: '未知',
      platform: '  微信  ',
      relationshipGuess: '未知',
      latestMessage: '  今晚见吗  ',
      emotion: '未知',
      riskNotice: '  ',
      replies: [
        ReplySuggestion(styleLabel: '未知', text: '未知', reason: '占位'),
        ReplySuggestion(styleLabel: '  轻松  ', text: '  可以呀  ', reason: '未知'),
      ],
      personInsight: const PersonInsight(
        displayName: ' 小林 ',
        aliases: [' Lin ', '未知'],
        relationship: '未知',
        communicationStyle: '  直接一点  ',
        personalityTraits: [' 稳 ', '未知'],
        confidence: 1.4,
        updateReason: '未知',
      ),
    );
  }
}

class RecordingInputApi extends FakeApi {
  final inputs = <ChatInput>[];

  @override
  Future<ChatReplyResponse> generateReply(
    ChatInput input,
    APIConfig config,
    String apiKey,
  ) async {
    inputs.add(input);
    return super.generateReply(input, config, apiKey);
  }
}

class InsightReplyApi extends FakeApi {
  @override
  Future<ChatReplyResponse> generateReply(
    ChatInput input,
    APIConfig config,
    String apiKey,
  ) async {
    return ChatReplyResponse(
      sceneSummary: '聊项目',
      personInsight: const PersonInsight(
        displayName: '小林',
        aliases: ['Lin'],
        keyPersonPoints: ['喜欢提前确认时间'],
        confidence: 0.9,
      ),
      replies: [
        ReplySuggestion(
            styleLabel: input.selectedStyle.name, text: '我确认下时间', reason: '测试'),
      ],
    );
  }
}

class DeferredModelsApi extends OpenAICompatibleApi {
  final completer = Completer<List<APIModel>>();

  @override
  Future<List<APIModel>> fetchModels(APIConfig config, String apiKey) =>
      completer.future;
}

class SequencedModelsApi extends OpenAICompatibleApi {
  final completers = <Completer<List<APIModel>>>[];

  @override
  Future<List<APIModel>> fetchModels(APIConfig config, String apiKey) {
    final completer = Completer<List<APIModel>>();
    completers.add(completer);
    return completer.future;
  }
}

class DeferredConnectionApi extends FakeApi {
  final connectionCompleter = Completer<void>();
  final visionCompleter = Completer<void>();
  final generateCompleter = Completer<ChatReplyResponse>();
  final momentCompleter = Completer<MomentProfileAnalysis>();
  final simulationCompleter = Completer<SimulationTurnResponse>();
  final generateStarted = Completer<void>();
  final momentStarted = Completer<void>();
  final simulationStarted = Completer<void>();

  APIConfig? connectionConfig;
  String? connectionKey;
  APIConfig? visionConfig;
  String? visionKey;
  ChatInput? generatedInput;
  PersonProfile? simulationRequestProfile;

  @override
  Future<void> testConnection(APIConfig config, String apiKey) {
    connectionConfig = config;
    connectionKey = apiKey;
    return connectionCompleter.future;
  }

  @override
  Future<void> testVisionConnection(APIConfig config, String apiKey) {
    visionConfig = config;
    visionKey = apiKey;
    return visionCompleter.future;
  }

  @override
  Future<ChatReplyResponse> generateReply(
    ChatInput input,
    APIConfig config,
    String apiKey,
  ) {
    generatedInput = input;
    if (!generateStarted.isCompleted) generateStarted.complete();
    return generateCompleter.future;
  }

  @override
  Future<MomentProfileAnalysis> analyzeMomentScreenshot(
    ImagePayload image,
    String? personContext,
    APIConfig config,
    String apiKey,
  ) {
    if (!momentStarted.isCompleted) momentStarted.complete();
    return momentCompleter.future;
  }

  @override
  Future<SimulationTurnResponse> runSimulationTurn({
    required PersonProfile profile,
    required SimulationScenario scenario,
    required List<SimulationMessage> history,
    required String? userReply,
    required String personalizationContext,
    required APIConfig config,
    required String apiKey,
  }) {
    simulationRequestProfile = profile;
    if (!simulationStarted.isCompleted) simulationStarted.complete();
    return simulationCompleter.future;
  }
}

class SequencedSettingsTestApi extends FakeApi {
  final connectionCompleters = <Completer<void>>[];
  final connectionConfigs = <APIConfig>[];
  final connectionKeys = <String>[];
  final visionCompleters = <Completer<void>>[];
  final visionConfigs = <APIConfig>[];
  final visionKeys = <String>[];

  @override
  Future<void> testConnection(APIConfig config, String apiKey) {
    connectionConfigs.add(config);
    connectionKeys.add(apiKey);
    final completer = Completer<void>();
    connectionCompleters.add(completer);
    return completer.future;
  }

  @override
  Future<void> testVisionConnection(APIConfig config, String apiKey) {
    visionConfigs.add(config);
    visionKeys.add(apiKey);
    final completer = Completer<void>();
    visionCompleters.add(completer);
    return completer.future;
  }
}

class SequencedGenerationApi extends FakeApi {
  final generateCompleters = <Completer<ChatReplyResponse>>[];
  final generatedInputs = <ChatInput>[];

  @override
  Future<ChatReplyResponse> generateReply(
    ChatInput input,
    APIConfig config,
    String apiKey,
  ) {
    generatedInputs.add(input);
    final completer = Completer<ChatReplyResponse>();
    generateCompleters.add(completer);
    return completer.future;
  }
}

class SequencedSimulationApi extends FakeApi {
  final simulationCompleters = <Completer<SimulationTurnResponse>>[];
  final simulationUserReplies = <String?>[];

  @override
  Future<SimulationTurnResponse> runSimulationTurn({
    required PersonProfile profile,
    required SimulationScenario scenario,
    required List<SimulationMessage> history,
    required String? userReply,
    required String personalizationContext,
    required APIConfig config,
    required String apiKey,
  }) {
    final completer = Completer<SimulationTurnResponse>();
    simulationCompleters.add(completer);
    simulationUserReplies.add(userReply);
    return completer.future;
  }
}

class SequencedGenerationAndSimulationApi extends FakeApi {
  final generateCompleters = <Completer<ChatReplyResponse>>[];
  final simulationCompleters = <Completer<SimulationTurnResponse>>[];

  @override
  Future<ChatReplyResponse> generateReply(
    ChatInput input,
    APIConfig config,
    String apiKey,
  ) {
    final completer = Completer<ChatReplyResponse>();
    generateCompleters.add(completer);
    return completer.future;
  }

  @override
  Future<SimulationTurnResponse> runSimulationTurn({
    required PersonProfile profile,
    required SimulationScenario scenario,
    required List<SimulationMessage> history,
    required String? userReply,
    required String personalizationContext,
    required APIConfig config,
    required String apiKey,
  }) {
    final completer = Completer<SimulationTurnResponse>();
    simulationCompleters.add(completer);
    return completer.future;
  }
}

class SequencedMomentApi extends FakeApi {
  final momentCompleters = <Completer<MomentProfileAnalysis>>[];
  final personContexts = <String?>[];

  @override
  Future<MomentProfileAnalysis> analyzeMomentScreenshot(
    ImagePayload image,
    String? personContext,
    APIConfig config,
    String apiKey,
  ) {
    personContexts.add(personContext);
    final completer = Completer<MomentProfileAnalysis>();
    momentCompleters.add(completer);
    return completer.future;
  }
}

Future<void> waitForCondition(bool Function() condition) async {
  for (var attempt = 0; attempt < 50; attempt += 1) {
    if (condition()) return;
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}

class DeferredBackgroundImageService extends ImageService {
  final completer = Completer<void>();
  final started = Completer<void>();
  String? outputPath;
  double? maxWidth;
  double? quality;

  @override
  Future<void> saveJpegCopy(
    String sourcePath,
    String outputPath, {
    required double maxWidth,
    required double quality,
  }) async {
    this.outputPath = outputPath;
    this.maxWidth = maxWidth;
    this.quality = quality;
    if (!started.isCompleted) started.complete();
    await completer.future;
    await File(outputPath).parent.create(recursive: true);
    await File(outputPath).writeAsBytes([1, 2, 3], flush: true);
  }
}

class DeferredPayloadImageService extends ImageService {
  final completer = Completer<ImagePayload>();
  final started = Completer<void>();
  int prepareCalls = 0;
  String? preparedPath;

  @override
  Future<ImagePayload> prepareImagePayload(
    String path, {
    required double maxWidth,
    required double quality,
  }) {
    prepareCalls += 1;
    preparedPath = path;
    if (!started.isCompleted) started.complete();
    return completer.future;
  }
}

class FakeStore extends LocalStore {
  String savedAPIKey = '';
  APIConfig? savedConfig = APIConfig.defaults;
  List<GenerationRecord> savedHistory = [];
  List<PersonProfile> savedProfiles = [];
  bool didClearAll = false;
  APIConfig loadedConfig = APIConfig.defaults;
  String loadedAPIKey = '';
  List<GenerationRecord> loadedHistory = [];
  List<PersonProfile> loadedProfiles = [];
  String? loadedDefaultStyleId;
  String? savedDefaultStyleId;
  ReplyPersonalizationSettings loadedPersonalization =
      ReplyPersonalizationSettings.defaults;
  AppearanceSettings loadedAppearance = AppearanceSettings.defaults;
  ReplyPersonalizationSettings? savedPersonalization;
  AppearanceSettings? savedAppearance;
  bool hasSeenPrivacy = true;

  @override
  Future<APIConfig> loadConfig() async => loadedConfig;

  @override
  Future<String> loadAPIKey() async => loadedAPIKey;

  @override
  Future<List<GenerationRecord>> loadHistory() async => loadedHistory;

  @override
  Future<void> saveHistory(List<GenerationRecord> records) async {
    savedHistory = List.of(records);
  }

  @override
  Future<List<PersonProfile>> loadProfiles() async => loadedProfiles;

  @override
  Future<void> saveProfiles(List<PersonProfile> profiles) async {
    savedProfiles = List.of(profiles);
  }

  @override
  Future<ReplyPersonalizationSettings> loadPersonalization() async =>
      loadedPersonalization;

  @override
  Future<void> savePersonalization(
      ReplyPersonalizationSettings settings) async {
    savedPersonalization = settings;
  }

  @override
  Future<void> clearPersonalization() async {
    savedPersonalization = null;
  }

  @override
  Future<String?> loadDefaultStyleId() async => loadedDefaultStyleId;

  @override
  Future<void> saveDefaultStyleId(String styleId) async {
    savedDefaultStyleId = styleId;
  }

  @override
  Future<void> clearDefaultStyleId() async {
    savedDefaultStyleId = null;
  }

  @override
  Future<void> saveAPIKey(String key) async {
    savedAPIKey = key.trim();
  }

  @override
  Future<void> saveConfig(APIConfig config) async {
    savedConfig = config;
  }

  @override
  Future<void> clearConfig() async {
    savedConfig = null;
  }

  @override
  Future<AppearanceSettings> loadAppearance() async => loadedAppearance;

  @override
  Future<void> saveAppearance(AppearanceSettings settings) async {
    savedAppearance = settings;
  }

  @override
  Future<void> clearAppearance() async {
    savedAppearance = null;
  }

  @override
  Future<bool> hasSeenPrivacyNotice() async => hasSeenPrivacy;

  @override
  Future<void> markPrivacyNoticeSeen() async {
    hasSeenPrivacy = true;
  }

  @override
  Future<void> clearPrivacyNoticeSeen() async {
    hasSeenPrivacy = false;
  }

  @override
  Future<void> clearAll() async {
    didClearAll = true;
    savedAPIKey = '';
    savedConfig = null;
    savedHistory = [];
    savedProfiles = [];
    savedDefaultStyleId = null;
    savedPersonalization = ReplyPersonalizationSettings.defaults;
    savedAppearance = AppearanceSettings.defaults;
  }
}

class DeferredPrivacyStore extends FakeStore {
  final markStarted = Completer<void>();
  final markRelease = Completer<void>();

  @override
  Future<void> markPrivacyNoticeSeen() async {
    if (!markStarted.isCompleted) markStarted.complete();
    await markRelease.future;
    hasSeenPrivacy = true;
  }

  @override
  Future<void> clearAll() async {
    await super.clearAll();
    hasSeenPrivacy = false;
  }
}

class DeferredPreferenceStore extends FakeStore {
  final configStarted = Completer<void>();
  final configRelease = Completer<void>();
  final apiKeyStarted = Completer<void>();
  final apiKeyRelease = Completer<void>();
  final historyStarted = Completer<void>();
  final historyRelease = Completer<void>();
  final profilesStarted = Completer<void>();
  final profilesRelease = Completer<void>();
  final appearanceStarted = Completer<void>();
  final appearanceRelease = Completer<void>();
  final personalizationStarted = Completer<void>();
  final personalizationRelease = Completer<void>();
  final defaultStyleStarted = Completer<void>();
  final defaultStyleRelease = Completer<void>();
  bool delayConfigSave = false;
  bool delayAPIKeySave = false;
  bool delayHistorySave = false;
  bool delayProfilesSave = false;
  bool delayAppearanceSave = false;
  bool delayPersonalizationSave = false;
  bool delayDefaultStyleSave = false;

  @override
  Future<void> saveConfig(APIConfig config) async {
    if (delayConfigSave) {
      delayConfigSave = false;
      if (!configStarted.isCompleted) configStarted.complete();
      await configRelease.future;
    }
    await super.saveConfig(config);
  }

  @override
  Future<void> saveAPIKey(String key) async {
    if (delayAPIKeySave) {
      delayAPIKeySave = false;
      if (!apiKeyStarted.isCompleted) apiKeyStarted.complete();
      await apiKeyRelease.future;
    }
    await super.saveAPIKey(key);
  }

  @override
  Future<void> saveHistory(List<GenerationRecord> records) async {
    if (delayHistorySave) {
      delayHistorySave = false;
      if (!historyStarted.isCompleted) historyStarted.complete();
      await historyRelease.future;
    }
    await super.saveHistory(records);
  }

  @override
  Future<void> saveProfiles(List<PersonProfile> profiles) async {
    if (delayProfilesSave) {
      delayProfilesSave = false;
      if (!profilesStarted.isCompleted) profilesStarted.complete();
      await profilesRelease.future;
    }
    await super.saveProfiles(profiles);
  }

  @override
  Future<void> saveAppearance(AppearanceSettings settings) async {
    if (delayAppearanceSave) {
      delayAppearanceSave = false;
      if (!appearanceStarted.isCompleted) appearanceStarted.complete();
      await appearanceRelease.future;
    }
    await super.saveAppearance(settings);
  }

  @override
  Future<void> savePersonalization(
      ReplyPersonalizationSettings settings) async {
    if (delayPersonalizationSave) {
      delayPersonalizationSave = false;
      if (!personalizationStarted.isCompleted) {
        personalizationStarted.complete();
      }
      await personalizationRelease.future;
    }
    await super.savePersonalization(settings);
  }

  @override
  Future<void> saveDefaultStyleId(String styleId) async {
    if (delayDefaultStyleSave) {
      delayDefaultStyleSave = false;
      if (!defaultStyleStarted.isCompleted) defaultStyleStarted.complete();
      await defaultStyleRelease.future;
    }
    return super.saveDefaultStyleId(styleId);
  }
}

class DeferredLoadStore extends FakeStore {
  final historyLoadStarted = Completer<void>();
  final historyLoadRelease = Completer<void>();
  bool delayHistoryLoad = false;

  @override
  Future<List<GenerationRecord>> loadHistory() async {
    if (delayHistoryLoad) {
      delayHistoryLoad = false;
      if (!historyLoadStarted.isCompleted) historyLoadStarted.complete();
      await historyLoadRelease.future;
    }
    return super.loadHistory();
  }
}

class _FakeApiResponse {
  const _FakeApiResponse(this.statusCode, this.data);

  final int statusCode;
  final Object data;
}

Dio _fakeDio({
  required List<_FakeApiResponse> responses,
  required List<String> paths,
  List<Map<String, dynamic>>? bodies,
  List<Map<String, dynamic>>? headers,
}) {
  var index = 0;
  final dio = Dio();
  dio.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) {
    paths.add(options.uri.path);
    if (bodies != null) {
      bodies.add(Map<String, dynamic>.from(options.data as Map));
    }
    if (headers != null) {
      headers.add(Map<String, dynamic>.from(options.headers));
    }
    final response = responses[index++];
    final dioResponse = Response(
      requestOptions: options,
      statusCode: response.statusCode,
      data: response.data,
    );
    if (response.statusCode >= 200 && response.statusCode < 300) {
      handler.resolve(dioResponse);
    } else {
      handler.reject(DioException.badResponse(
        statusCode: response.statusCode,
        requestOptions: options,
        response: dioResponse,
      ));
    }
  }));
  return dio;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('decodeJsonObject extracts JSON from noisy model output', () {
    final decoded = decodeJsonObject(
        '好的\n{"sceneSummary":"连接正常","replies":[{"text":"收到","styleLabel":"自然版"}]}\n谢谢');
    expect(decoded?['sceneSummary'], '连接正常');
  });

  test('decodeJsonObject keeps first balanced object from multiple objects',
      () {
    final decoded = decodeJsonObject(
      '先看这个 {"sceneSummary":"可用","replies":[{"text":"收到 { 好的 }","styleLabel":"自然"}]} '
      '后面还有 {"example":true}',
    );

    expect(decoded?['sceneSummary'], '可用');
    expect(
      ((decoded?['replies'] as List).single as Map)['text'],
      '收到 { 好的 }',
    );
  });

  test('loose key lookup ignores separators while preserving exact keys', () {
    final data = {
      'error_message': '接口失败',
      'errorMessage': '精确字段优先',
      'Target Route': 'settings/api',
    };

    expect(normalizedLooseKey('target-route'), 'targetroute');
    expect(valueForLooseKey(data, 'errorMessage'), '精确字段优先');
    expect(valueForLooseKey(data, 'error-message'), '接口失败');
    expect(valueForLooseKey(data, 'target_route'), 'settings/api');
    expect(valueForLooseKey(data, 'missing'), isNull);
  });

  test('bool value parser accepts common imported switch labels', () {
    expect(boolValue(' ON '), isTrue);
    expect(boolValue('on'), isTrue);
    expect(boolValue('enabled'), isTrue);
    expect(boolValue('supported'), isTrue);
    expect(boolValue('available'), isTrue);
    expect(boolValue('是'), isTrue);
    expect(boolValue('off'), isFalse);
    expect(boolValue('disabled'), isFalse);
    expect(boolValue('unsupported'), isFalse);
    expect(boolValue('unavailable'), isFalse);
    expect(boolValue('否'), isFalse);
    expect(boolValue('  '), isNull);
    expect(boolValue('maybe'), isNull);

    final source = File('lib/core/bool_value.dart').readAsStringSync();
    expect(source, contains("import 'text_cleaning.dart';"));
    expect(
      source,
      contains('cleanNonEmptyText(raw?.toString())?.toLowerCase()'),
    );
    expect(source, isNot(contains('raw?.toString().trim()')));
  });

  test('search matcher tolerates separators in user queries', () {
    expect(textMatchesSearchQuery('项目负责人 Lin', '   '), isTrue);
    expect(textMatchesSearchQuery('项目负责人 Lin', '项 目-负责人'), isTrue);
    expect(textMatchesSearchQuery('项目负责人 Lin', 'li_n'), isTrue);
    expect(textMatchesSearchQuery('项目负责人 Lin', '陌生人'), isFalse);
    expect(textMatchesSearchQuery('项目负责人 Lin', '---'), isFalse);
    expect(textMatchesSearchQuery('项目 -- 负责人', '--'), isTrue);

    final source = File('lib/core/search_match.dart').readAsStringSync();
    expect(source, contains("import 'text_cleaning.dart';"));
    expect(source, contains('final trimmedQuery = cleanNonEmptyText(query);'));
    expect(source, contains('if (looseQuery.isEmpty) return false;'));
    expect(source, isNot(contains('query.trim()')));
  });

  test('reply parser accepts iOS risk warning and metadata fields', () {
    final parsed = ChatReplyResponse.fromJson({
      'sceneSummary': '约周末见面',
      'platform': '微信',
      'relationshipGuess': '朋友',
      'latestMessage': '周末有空吗',
      'emotion': '期待',
      'riskWarning': '别给太满承诺',
      'replies': [
        {'style': '自然-轻推话题', 'text': '可以呀，看你想去哪', 'reason': '自然接住'}
      ],
    });

    expect(parsed.platform, '微信');
    expect(parsed.relationshipGuess, '朋友');
    expect(parsed.riskNotice, '别给太满承诺');
    expect(parsed.replies.single.styleLabel, '自然-轻推话题');

    final encoded = parsed.toJson();
    expect(encoded['riskWarning'], '别给太满承诺');
    expect(ChatReplyResponse.fromJson(encoded).riskNotice, '别给太满承诺');
  });

  test('reply and history parsers preserve compatible safety notice aliases',
      () {
    final reply = ChatReplyResponse.fromJson({
      'sceneSummary': '关系边界',
      'safety_warning': '不要承诺替对方做决定',
      'replies': [
        {'text': '我理解你的担心，我们慢慢看。'}
      ],
    });
    final record = GenerationRecord.fromJson({
      'inputType': 'text',
      'risk_reminder': '先确认对方是否愿意继续聊',
      'replies': [
        {'text': '我先听你怎么想。'}
      ],
    });

    expect(reply.riskNotice, '不要承诺替对方做决定');
    expect(record.riskNotice, '先确认对方是否愿意继续聊');
  });

  test('reply parser regenerates blank suggestion ids', () {
    final parsed = ChatReplyResponse.fromJson({
      'sceneSummary': '约周末见面',
      'replies': [
        {'id': '   ', 'style': '自然', 'text': '可以呀', 'reason': '接住邀约'}
      ],
    });

    expect(parsed.replies.single.id.trim(), isNotEmpty);
    expect(parsed.replies.single.id, isNot('   '));
  });

  test('reply parser defaults missing style to iOS suggestion label', () {
    final parsed = ChatReplyResponse.fromJson({
      'sceneSummary': '约周末见面',
      'replies': [
        {'text': '可以呀，我看看时间'},
        '那我先确认一下安排',
      ],
    });

    expect(parsed.replies.map((reply) => reply.styleLabel), ['建议', '建议']);
    expect(parsed.replies.map((reply) => reply.text), [
      '可以呀，我看看时间',
      '那我先确认一下安排',
    ]);
  });

  test('reply parser keeps useful content from common schema aliases', () {
    final parsed = ChatReplyResponse.fromJson({
      'summary': '对方在约晚饭',
      'sourcePlatform': 'QQ',
      'relationship': '同学',
      'lastMessage': '今晚一起吃饭吗',
      'warning': '别显得太急',
      'suggestions': [
        {'label': '自然', 'message': '可以呀，你想吃什么', 'explanation': '接住邀约'},
        {'label': '重复', 'message': '可以呀，你想吃什么'},
        '我都行，看你方便',
      ],
    });

    expect(parsed.sceneSummary, '对方在约晚饭');
    expect(parsed.platform, 'QQ');
    expect(parsed.relationshipGuess, '同学');
    expect(parsed.latestMessage, '今晚一起吃饭吗');
    expect(parsed.riskNotice, '别显得太急');
    expect(parsed.replies.map((reply) => reply.text), [
      '可以呀，你想吃什么',
      '我都行，看你方便',
    ]);

    final compatible = ChatReplyResponse.fromJson({
      'payload': {
        'sceneDescription': '对方临时改时间',
        'platformName': '微信',
        'relation': '朋友',
        'currentMessage': '我可能要晚一点',
        'sentiment': '抱歉',
        'caution': '先接住影响',
        'options': [
          {'text': '没事，你路上慢点，到时说一声。'}
        ],
      },
    });

    expect(compatible.sceneSummary, '对方临时改时间');
    expect(compatible.platform, '微信');
    expect(compatible.relationshipGuess, '朋友');
    expect(compatible.latestMessage, '我可能要晚一点');
    expect(compatible.emotion, '抱歉');
    expect(compatible.riskNotice, '先接住影响');
    expect(compatible.replies.single.text, '没事，你路上慢点，到时说一声。');
  });

  test('reply parser extracts scalar text from nested value objects', () {
    final parsed = ChatReplyResponse.fromJson({
      'sceneSummary': {'summary': '对方在确认周末安排'},
      'platform': {'name': '微信'},
      'relationshipGuess': {'label': '朋友'},
      'latestMessage': {'text': '周末你有空吗'},
      'riskWarning': {'value': '不要一次给太多承诺'},
      'replies': [
        {
          'style': {'label': '自然'},
          'message': {'text': '周末应该可以，我看看具体时间'},
          'reason': {'summary': '先答应方向，保留余地'},
        }
      ],
    });

    expect(parsed.sceneSummary, '对方在确认周末安排');
    expect(parsed.platform, '微信');
    expect(parsed.relationshipGuess, '朋友');
    expect(parsed.latestMessage, '周末你有空吗');
    expect(parsed.riskNotice, '不要一次给太多承诺');
    expect(parsed.replies.single.styleLabel, '自然');
    expect(parsed.replies.single.text, '周末应该可以，我看看具体时间');
    expect(parsed.replies.single.reason, '先答应方向，保留余地');
    expect(parsed.toJson().toString(), isNot(contains('{text:')));
  });

  test('model parsers accept snake case response fields', () {
    final reply = ChatReplyResponse.fromJson({
      'scene_summary': '解释迟到',
      'source_platform': '微信',
      'relationship_guess': '朋友',
      'latest_message': '你怎么还没到',
      'risk_warning': '先承认影响',
      'reply_suggestions': [
        {
          'style_label': '修复',
          'message': '抱歉让你等了，我还有五分钟到。',
          'explanation': '先道歉，再给明确时间',
        }
      ],
      'person_insight': {
        'display_name': '小林',
        'communication_style': '直接一点',
        'personality_traits': '重视时间',
        'inner_needs': '确定性',
        'key_person_points': '提前同步进度',
        'moments_insights': '常发工作动态',
        'tone_preferences': '少绕弯',
        'stable_facts': '住在附近',
        'update_reason': '对方反复追问时间',
      },
    });

    expect(reply.sceneSummary, '解释迟到');
    expect(reply.platform, '微信');
    expect(reply.relationshipGuess, '朋友');
    expect(reply.latestMessage, '你怎么还没到');
    expect(reply.riskNotice, '先承认影响');
    expect(reply.replies.single.styleLabel, '修复');
    expect(reply.replies.single.text, '抱歉让你等了，我还有五分钟到。');
    expect(reply.personInsight?.displayName, '小林');
    expect(reply.personInsight?.personalityTraits, ['重视时间']);
    expect(reply.personInsight?.innerNeeds, ['确定性']);
    expect(reply.personInsight?.keyPersonPoints, ['提前同步进度']);
    expect(reply.personInsight?.momentsInsights, ['常发工作动态']);
    expect(reply.personInsight?.tonePreferences, ['少绕弯']);
    expect(reply.personInsight?.facts, ['住在附近']);
    expect(reply.personInsight?.updateReason, '对方反复追问时间');

    final moment = MomentProfileAnalysis.fromJson({
      'scene_summary': '朋友圈展示工作节奏',
      'source_platform': '微信朋友圈',
      'visible_name': '小林',
      'relationship_guess': '同事',
      'communication_advice': '直接一点；别催',
      'stable_facts': '项目负责人',
    });

    expect(moment.sourcePlatform, '微信朋友圈');
    expect(moment.visibleName, '小林');
    expect(moment.relationshipGuess, '同事');
    expect(moment.communicationAdvice, ['直接一点', '别催']);
    expect(moment.stableFacts, ['项目负责人']);

    final simulation = SimulationTurnResponse.fromJson({
      'persona_message': '那你下次提前说一下',
      'scene_state': '对方需要明确解释',
      'score_card': [
        {'metric': '自然度', 'value': '82'}
      ],
      'reply_options': [
        {
          'text': '我刚才没及时说清楚，下次提前告诉你。',
          'predicted_score': '87',
        }
      ],
      'user_score': '76',
      'better_reply': '我应该先告诉你进度。',
      'coach_tip': '先承认等待成本。',
    });

    expect(simulation.personaMessage, '那你下次提前说一下');
    expect(simulation.sceneState, '对方需要明确解释');
    expect(simulation.metrics.first.name, '自然度');
    expect(simulation.options.single.predictedScore, 87);
    expect(simulation.userScore, 76);
    expect(simulation.betterReply, '我应该先告诉你进度。');
    expect(simulation.coachTip, '先承认等待成本。');
  });

  test('reply parser accepts compatible reply option arrays', () {
    final replyOptions = ChatReplyResponse.fromJson({
      'summary': '确认周末安排',
      'replyOptions': [
        {'reply': '可以呀，周六下午方便吗？', 'tone': '自然', 'why': '接住邀约并给具体时间'},
      ],
    });
    final candidates = ChatReplyResponse.fromJson({
      'summary': '解释延迟回复',
      'candidates': ['刚忙完，才看到消息。'],
    });
    final answers = ChatReplyResponse.fromJson({
      'summary': '低压力推进',
      'answers': [
        {'answer': '那我们先轻松聊聊。'},
      ],
    });

    expect(replyOptions.replies.single.text, '可以呀，周六下午方便吗？');
    expect(replyOptions.replies.single.styleLabel, '自然');
    expect(replyOptions.replies.single.reason, '接住邀约并给具体时间');
    expect(candidates.replies.single.text, '刚忙完，才看到消息。');
    expect(answers.replies.single.text, '那我们先轻松聊聊。');
  });

  test('reply parser accepts exported suggestion and contact aliases', () {
    final parsed = ChatReplyResponse.fromJson({
      'summary': '对方催确认',
      'replyOptions': [
        {
          'optionId': 'exported-option-1',
          'styleName': '稳一点',
          'optionText': '我现在确认一下，十分钟内回你。',
          'note': '给出明确等待时间',
        }
      ],
      'contact': {
        'contactName': '小林',
        'relation': '同事',
        'preferredCommunicationStyle': '直接给结论',
        'emotionalNeeds': '确定性',
        'highlights': '重视时间安排',
        'recentSignals': '最近频繁确认项目节点',
        'preferredTones': '清楚；别绕弯',
        'doNotMention': '临时变卦',
        'profileFacts': '项目负责人',
        'score': '0.88',
      },
    });

    expect(parsed.replies.single.id, 'exported-option-1');
    expect(parsed.replies.single.styleLabel, '稳一点');
    expect(parsed.replies.single.text, '我现在确认一下，十分钟内回你。');
    expect(parsed.replies.single.reason, '给出明确等待时间');
    expect(parsed.personInsight?.displayName, '小林');
    expect(parsed.personInsight?.relationship, '同事');
    expect(parsed.personInsight?.communicationStyle, '直接给结论');
    expect(parsed.personInsight?.innerNeeds, ['确定性']);
    expect(parsed.personInsight?.keyPersonPoints, ['重视时间安排']);
    expect(parsed.personInsight?.momentsInsights, ['最近频繁确认项目节点']);
    expect(parsed.personInsight?.tonePreferences, ['清楚', '别绕弯']);
    expect(parsed.personInsight?.boundaries, ['临时变卦']);
    expect(parsed.personInsight?.facts, ['项目负责人']);
    expect(parsed.personInsight?.confidence, 0.88);
  });

  test('reply parser unwraps compatible provider response envelopes', () {
    final resultWrapped = ChatReplyResponse.fromJson({
      'result': {
        'scene_summary': '解释临时改时间',
        'source_platform': '微信',
        'relationship_guess': '朋友',
        'latest_message': '你怎么又改时间',
        'risk_warning': '先承认影响',
        'reply_options': [
          {
            'reply': '确实是我没安排好，抱歉让你又调整了一次。',
            'tone': '修复',
            'why': '先承认影响再道歉',
          }
        ],
        'person_insight': {
          'display_name': '小林',
          'stable_facts': '重视计划感',
        },
      },
    });
    final stringWrapped = ChatReplyResponse.fromJson({
      'content': '{"summary":"低压力推进","answers":["那我们先按你方便的节奏来。"]}',
    });
    final nestedWrapped = ChatReplyResponse.fromJson({
      'payload': {
        'data': {
          'result': {
            'summary': '多层包装',
            'answers': ['我明白你的意思，先照这个节奏来。'],
          },
        },
      },
    });

    expect(resultWrapped.sceneSummary, '解释临时改时间');
    expect(resultWrapped.platform, '微信');
    expect(resultWrapped.relationshipGuess, '朋友');
    expect(resultWrapped.latestMessage, '你怎么又改时间');
    expect(resultWrapped.riskNotice, '先承认影响');
    expect(resultWrapped.replies.single.styleLabel, '修复');
    expect(resultWrapped.replies.single.text, '确实是我没安排好，抱歉让你又调整了一次。');
    expect(resultWrapped.replies.single.reason, '先承认影响再道歉');
    expect(resultWrapped.personInsight?.displayName, '小林');
    expect(resultWrapped.personInsight?.facts, ['重视计划感']);
    expect(stringWrapped.sceneSummary, '低压力推进');
    expect(stringWrapped.replies.single.text, '那我们先按你方便的节奏来。');
    expect(nestedWrapped.sceneSummary, '多层包装');
    expect(nestedWrapped.replies.single.text, '我明白你的意思，先照这个节奏来。');
  });

  test('reply parser accepts common person insight aliases', () {
    final parsed = ChatReplyResponse.fromJson({
      'summary': '聊近况',
      'suggestions': ['最近怎么样'],
      'contactProfile': {
        'nickname': '小林',
        'relationshipGuess': '同事',
        'communicationAdvice': ['直接一点', '别绕太久'],
        'keyPoints': '喜欢提前确认时间',
        'avoidTopics': '临时催促',
        'stableFacts': '项目负责人；常加班',
        'reason': '聊天中反复提到项目节奏',
        'confidence': '0.7',
      },
    });

    expect(parsed.replies.single.text, '最近怎么样');
    expect(parsed.personInsight?.displayName, '小林');
    expect(parsed.personInsight?.relationship, '同事');
    expect(parsed.personInsight?.communicationStyle, '直接一点；别绕太久');
    expect(parsed.personInsight?.tonePreferences, ['直接一点', '别绕太久']);
    expect(parsed.personInsight?.keyPersonPoints, ['喜欢提前确认时间']);
    expect(parsed.personInsight?.boundaries, ['临时催促']);
    expect(parsed.personInsight?.facts, ['项目负责人', '常加班']);
    expect(parsed.personInsight?.updateReason, '聊天中反复提到项目节奏');
    expect(parsed.personInsight?.confidence, 0.7);
  });

  test('reply parser accepts stringified nested person insight', () {
    final parsed = ChatReplyResponse.fromJson({
      'summary': '聊近况',
      'suggestions': ['最近怎么样'],
      'personInsight':
          '{"displayName":"小林","tonePreferences":"直接一点；别绕太久","facts":["项目负责人"]}',
    });

    expect(parsed.replies.single.text, '最近怎么样');
    expect(parsed.personInsight?.displayName, '小林');
    expect(parsed.personInsight?.tonePreferences, ['直接一点', '别绕太久']);
    expect(parsed.personInsight?.facts, ['项目负责人']);
  });

  test('reply response json preserves parsed person insight', () {
    final parsed = ChatReplyResponse.fromJson({
      'summary': '聊近况',
      'suggestions': ['最近怎么样'],
      'personInsight': {
        'displayName': '小林',
        'aliases': ['Lin'],
        'relationship': '同事',
        'communicationStyle': '直接一点',
        'personalityTraits': ['靠谱'],
        'innerNeeds': ['确定性'],
        'keyPersonPoints': ['喜欢提前确认时间'],
        'momentsInsights': ['常分享工作动态'],
        'tonePreferences': ['别绕太久'],
        'boundaries': ['临时催促'],
        'facts': ['项目负责人'],
        'confidence': 0.72,
        'updateReason': '聊天中反复提到项目节奏',
      },
    });

    final json = parsed.toJson();
    final restored = ChatReplyResponse.fromJson(json);

    expect(json['personInsight'], isA<Map<String, dynamic>>());
    expect(restored.personInsight?.displayName, '小林');
    expect(restored.personInsight?.aliases, ['Lin']);
    expect(restored.personInsight?.relationship, '同事');
    expect(restored.personInsight?.personalityTraits, ['靠谱']);
    expect(restored.personInsight?.innerNeeds, ['确定性']);
    expect(restored.personInsight?.keyPersonPoints, ['喜欢提前确认时间']);
    expect(restored.personInsight?.momentsInsights, ['常分享工作动态']);
    expect(restored.personInsight?.tonePreferences, ['别绕太久']);
    expect(restored.personInsight?.boundaries, ['临时催促']);
    expect(restored.personInsight?.facts, ['项目负责人']);
    expect(restored.personInsight?.confidence, 0.72);
    expect(restored.personInsight?.updateReason, '聊天中反复提到项目节奏');
  });

  test('person insight json cleans noisy presentation values', () {
    const insight = PersonInsight(
      displayName: '未知',
      aliases: [' Lin ', 'lin', '未知', ' '],
      relationship: '未知',
      communicationStyle: '  直接一点  ',
      personalityTraits: [' 靠谱 ', '靠谱', '未知'],
      innerNeeds: ['未知'],
      keyPersonPoints: [' 喜欢提前确认时间 '],
      momentsInsights: [' 常分享工作动态 ', '未知'],
      tonePreferences: ['别绕太久', '未知'],
      boundaries: ['未知'],
      facts: [' 项目负责人 ', '未知'],
      confidence: 1.4,
      updateReason: '未知',
    );

    final json = insight.toJson();
    final restored = PersonInsight.fromJson(json);

    expect(json['displayName'], isNull);
    expect(json['aliases'], ['Lin']);
    expect(json['relationship'], isNull);
    expect(json['innerNeeds'], isEmpty);
    expect(json['boundaries'], isEmpty);
    expect(json['confidence'], 1);
    expect(json['updateReason'], isNull);
    expect(restored.displayName, isNull);
    expect(restored.aliases, ['Lin']);
    expect(restored.communicationStyle, '直接一点');
    expect(restored.personalityTraits, ['靠谱']);
    expect(restored.keyPersonPoints, ['喜欢提前确认时间']);
    expect(restored.momentsInsights, ['常分享工作动态']);
    expect(restored.tonePreferences, ['别绕太久']);
    expect(restored.facts, ['项目负责人']);
    expect(restored.confidence, 1);
    expect(restored.updateReason, isNull);
  });

  test('reply response json cleans noisy presentation values', () {
    final response = ChatReplyResponse(
      sceneSummary: '未知',
      platform: '  微信  ',
      relationshipGuess: '未知',
      latestMessage: '  今晚见吗  ',
      emotion: '未知',
      riskNotice: '未知',
      replies: [
        ReplySuggestion(styleLabel: '未知', text: '未知', reason: '未知'),
        ReplySuggestion(
          id: ' 未知 ',
          styleLabel: '  轻松  ',
          text: '  可以呀  ',
          reason: '未知',
        ),
        ReplySuggestion(styleLabel: '重复', text: '可以呀', reason: '重复'),
      ],
    );

    final json = response.toJson();
    final restored = ChatReplyResponse.fromJson(json);
    final replies = json['replies'] as List<Object?>;
    final reply = Map<String, dynamic>.from(replies.single as Map);

    expect(json['sceneSummary'], isNull);
    expect(json['platform'], '微信');
    expect(json['relationshipGuess'], isNull);
    expect(json['latestMessage'], '今晚见吗');
    expect(json['emotion'], isNull);
    expect(json['riskWarning'], isNull);
    expect(json['riskNotice'], isNull);
    expect(reply['id'], '未知');
    expect(reply['styleLabel'], '轻松');
    expect(reply['text'], '可以呀');
    expect(reply['reason'], '');
    expect(restored.replies, hasLength(1));
    expect(restored.replies.single.id, '未知');
    expect(restored.replies.single.styleLabel, '轻松');
    expect(restored.replies.single.text, '可以呀');

    final source = File('lib/core/chat_reply_models.dart').readAsStringSync();
    expect(source, contains('id: cleanIdentifierText(id),'));
    expect(source, contains("'id': cleanIdentifierText(id) ?? _uuid.v4(),"));
    expect(source, isNot(contains('id: cleanPresentationText(id),')));
  });

  test('moment profile parser normalizes aliases and string values', () {
    final parsed = MomentProfileAnalysis.fromJson({
      'summary': '  截图里是旅行动态  ',
      'platform': '小红书',
      'nickname': '阿周',
      'relationship': '朋友',
      'traits': '爱分享；重体验',
      'importantNotes': ['喜欢提前约定时间'],
      'advice': ['轻松开场', '别催回复'],
      'facts': List.generate(12, (index) => '事实$index'),
      'confidence': ' 1.2 ',
    });

    expect(parsed.sceneSummary, '截图里是旅行动态');
    expect(parsed.sourcePlatform, '小红书');
    expect(parsed.visibleName, '阿周');
    expect(parsed.relationshipGuess, '朋友');
    expect(parsed.personalityTraits, ['爱分享', '重体验']);
    expect(parsed.keyPersonPoints, ['喜欢提前约定时间']);
    expect(parsed.communicationAdvice, ['轻松开场', '别催回复']);
    expect(parsed.stableFacts, hasLength(10));
    expect(parsed.writableInsightCount, 15);
    expect(parsed.confidence, 1);
  });

  test('moment profile parser accepts people-library field aliases', () {
    final parsed = MomentProfileAnalysis.fromJson({
      'summary': '朋友圈展示工作节奏',
      'app': '微信',
      'name': '小林',
      'relationship': '同事',
      'preferredTone': '直接一点；别绕太久',
      'avoidTopics': '临时催促；强行邀约',
      'knownFacts': '项目负责人；常加班',
      'confidence_score': '0.66',
    });

    expect(parsed.sourcePlatform, '微信');
    expect(parsed.visibleName, '小林');
    expect(parsed.relationshipGuess, '同事');
    expect(parsed.communicationAdvice, ['直接一点', '别绕太久']);
    expect(parsed.boundaries, ['临时催促', '强行邀约']);
    expect(parsed.stableFacts, ['项目负责人', '常加班']);
    expect(parsed.confidence, 0.66);
    expect(parsed.personInsight.tonePreferences, ['直接一点', '别绕太久']);
    expect(parsed.personInsight.boundaries, ['临时催促', '强行邀约']);
    expect(parsed.personInsight.facts, ['项目负责人', '常加班']);

    final compatible = MomentProfileAnalysis.fromJson({
      'payload': {
        'sceneDescription': '动态里在复盘项目',
        'platformName': '微信朋友圈',
        'profileName': '小周',
        'relation': '同事',
        'sourceReason': '配文多次提到项目节奏',
        'traits': '认真；慢热',
        'preferredTone': '直接一点',
      },
    });

    expect(compatible.sceneSummary, '动态里在复盘项目');
    expect(compatible.sourcePlatform, '微信朋友圈');
    expect(compatible.visibleName, '小周');
    expect(compatible.relationshipGuess, '同事');
    expect(compatible.updateReason, '配文多次提到项目节奏');
    expect(compatible.personalityTraits, ['认真', '慢热']);
    expect(compatible.communicationAdvice, ['直接一点']);

    final replyInsightAliases = MomentProfileAnalysis.fromJson({
      'result': {
        'sceneDescription': '动态展示备考状态',
        'sourceApp': '小红书',
        'contactName': '小陈',
        'connection': '同学',
        'characterTraits': '自律；紧张',
        'motivations': '被认可',
        'highlights': '喜欢线下聚会',
        'recentSignals': '最近在准备考试',
        'preferredTones': '轻松；少说教',
        'doNotMention': '挂科',
        'profileFacts': '学生会成员',
        'score': '0.61',
        'basis': '动态里多次提到复习进度',
      },
    });

    expect(replyInsightAliases.sourcePlatform, '小红书');
    expect(replyInsightAliases.visibleName, '小陈');
    expect(replyInsightAliases.relationshipGuess, '同学');
    expect(replyInsightAliases.personalityTraits, ['自律', '紧张']);
    expect(replyInsightAliases.innerNeeds, ['被认可']);
    expect(replyInsightAliases.keyPersonPoints, ['喜欢线下聚会']);
    expect(replyInsightAliases.momentsInsights, ['最近在准备考试']);
    expect(replyInsightAliases.communicationAdvice, ['轻松', '少说教']);
    expect(replyInsightAliases.boundaries, ['挂科']);
    expect(replyInsightAliases.stableFacts, ['学生会成员']);
    expect(replyInsightAliases.confidence, 0.61);
    expect(replyInsightAliases.updateReason, '动态里多次提到复习进度');
  });

  test('moment profile parser unwraps compatible provider envelopes', () {
    final parsed = MomentProfileAnalysis.fromJson({
      'payload': {
        'scene_summary': '朋友圈展示复盘习惯',
        'source_platform': '微信朋友圈',
        'visible_name': '小林',
        'relationship_guess': '同事',
        'personality_traits': '认真；慢热',
        'communication_advice': '直接一点；少催促',
        'stable_facts': '常发项目复盘',
        'confidence_score': '0.78',
      },
    });
    final nested = MomentProfileAnalysis.fromJson({
      'response': {
        'data': {
          'body': {
            'summary': '动态展示备考状态',
            'platform': '小红书',
            'profileName': '小陈',
            'relationship': '同学',
            'traits': '自律；紧张',
            'facts': '正在备考',
          },
        },
      },
    });

    expect(parsed.sceneSummary, '朋友圈展示复盘习惯');
    expect(parsed.sourcePlatform, '微信朋友圈');
    expect(parsed.visibleName, '小林');
    expect(parsed.relationshipGuess, '同事');
    expect(parsed.personalityTraits, ['认真', '慢热']);
    expect(parsed.communicationAdvice, ['直接一点', '少催促']);
    expect(parsed.stableFacts, ['常发项目复盘']);
    expect(parsed.confidence, 0.78);
    expect(nested.sceneSummary, '动态展示备考状态');
    expect(nested.sourcePlatform, '小红书');
    expect(nested.visibleName, '小陈');
    expect(nested.relationshipGuess, '同学');
    expect(nested.personalityTraits, ['自律', '紧张']);
    expect(nested.stableFacts, ['正在备考']);
  });

  test('moment and person profile parsers accept interest evidence aliases',
      () {
    final moment = MomentProfileAnalysis.fromJson({
      'evidence_summary': '动态展示徒步和咖啡偏好',
      'source_app': '小红书',
      'target_name': '小周',
      'relation': '朋友',
      'interests': '徒步；手冲咖啡',
      'confidence_score': '0.72',
    });

    expect(moment.sceneSummary, '动态展示徒步和咖啡偏好');
    expect(moment.sourcePlatform, '小红书');
    expect(moment.visibleName, '小周');
    expect(moment.relationshipGuess, '朋友');
    expect(moment.keyPersonPoints, ['徒步', '手冲咖啡']);
    expect(moment.confidence, 0.72);
    expect(moment.personInsight.keyPersonPoints, ['徒步', '手冲咖啡']);

    final profile = PersonProfile.fromJson({
      'display_name': '小周',
      'source_summary': '常分享户外计划',
      'topics': [
        {'topic': '徒步路线'},
        {'label': '咖啡店'}
      ],
    });

    expect(profile.displayName, '小周');
    expect(profile.lastSceneSummary, '常分享户外计划');
    expect(profile.keyPersonPoints, ['徒步路线', '咖啡店']);
  });

  test('profile list parsers accept object array items', () {
    final moment = MomentProfileAnalysis.fromJson({
      'summary': '朋友圈展示工作节奏',
      'name': '小林',
      'traits': [
        {'trait': '慢热'},
        {'text': '靠谱'}
      ],
      'needs': [
        {'need': '确定性'}
      ],
      'importantNotes': [
        {'point': '喜欢提前确认时间'}
      ],
      'observations': [
        {'insight': '常发项目复盘'}
      ],
      'advice': [
        {'advice': '直接一点'}
      ],
      'avoidTopics': [
        {'topic': '临时催促'}
      ],
      'knownFacts': [
        {'fact': '项目负责人'}
      ],
    });
    final insight = PersonInsight.fromJson({
      'displayName': '小林',
      'personalityTraits': [
        {'trait': '稳'},
        {'value': '靠谱'}
      ],
      'communicationAdvice': [
        {'text': '别绕太久'}
      ],
    });
    final profile = PersonProfile.fromJson({
      'displayName': '小林',
      'nicknames': [
        {'name': 'Lin'}
      ],
      'communicationAdvice': [
        {'content': '轻松一点'}
      ],
      'stableFacts': [
        {'fact': '项目负责人'}
      ],
    });

    expect(moment.personalityTraits, ['慢热', '靠谱']);
    expect(moment.innerNeeds, ['确定性']);
    expect(moment.keyPersonPoints, ['喜欢提前确认时间']);
    expect(moment.momentsInsights, ['常发项目复盘']);
    expect(moment.communicationAdvice, ['直接一点']);
    expect(moment.boundaries, ['临时催促']);
    expect(moment.stableFacts, ['项目负责人']);
    expect(moment.personalityTraits.join(), isNot(contains('{')));
    expect(insight.personalityTraits, ['稳', '靠谱']);
    expect(insight.tonePreferences, ['别绕太久']);
    expect(profile.aliases, ['Lin']);
    expect(profile.communicationStyle, '轻松一点');
    expect(profile.facts, ['项目负责人']);
  });

  test('moment profile insight count ignores noisy presentation values', () {
    const analysis = MomentProfileAnalysis(
      sceneSummary: '动态画像',
      personalityTraits: [' 稳 ', '稳', '未知', ' '],
      innerNeeds: ['未知'],
      keyPersonPoints: [' 关键线索 '],
      momentsInsights: [' 常发工作动态 ', '未知'],
      communicationAdvice: ['未知', '少追问'],
      boundaries: ['未知'],
      stableFacts: ['喜欢提前确认', '喜欢提前确认', '未知'],
    );

    expect(analysis.writableInsightCount, 5);
  });

  test('moment profile person insight cleans noisy presentation values', () {
    const analysis = MomentProfileAnalysis(
      sceneSummary: '动态画像',
      visibleName: '未知',
      relationshipGuess: '未知',
      personalityTraits: [' 稳 ', '稳', '未知', ' '],
      innerNeeds: ['未知'],
      keyPersonPoints: [' 关键线索 '],
      momentsInsights: [' 常发工作动态 ', '未知'],
      communicationAdvice: ['未知', '少追问'],
      boundaries: ['未知'],
      stableFacts: ['喜欢提前确认', '喜欢提前确认', '未知'],
      confidence: 1.4,
      updateReason: '未知',
    );

    final insight = analysis.personInsight;

    expect(insight.displayName, isNull);
    expect(insight.aliases, isNull);
    expect(insight.relationship, isNull);
    expect(insight.communicationStyle, '稳');
    expect(insight.personalityTraits, ['稳']);
    expect(insight.innerNeeds, isEmpty);
    expect(insight.keyPersonPoints, ['关键线索']);
    expect(insight.momentsInsights, ['常发工作动态']);
    expect(insight.tonePreferences, ['少追问']);
    expect(insight.boundaries, isEmpty);
    expect(insight.facts, ['喜欢提前确认']);
    expect(insight.confidence, 1);
    expect(insight.updateReason, isNull);
  });

  test('moment profile analysis json cleans noisy presentation values', () {
    final analysis = MomentProfileAnalysis(
      sceneSummary: '未知',
      sourcePlatform: '  微信  ',
      visibleName: '未知',
      relationshipGuess: '未知',
      personalityTraits: [
        ' 稳 ',
        '稳',
        '未知',
        ' ',
        ...List.generate(9, (i) => '特质$i'),
      ],
      innerNeeds: ['未知', '确定性'],
      keyPersonPoints: [' 喜欢提前确认时间 ', '未知'],
      momentsInsights: [' 常发工作动态 ', '未知'],
      communicationAdvice: ['未知', '少追问'],
      boundaries: ['未知', '临时催促'],
      stableFacts: [
        ' 项目负责人 ',
        '项目负责人',
        '未知',
        ...List.generate(12, (i) => '事实$i'),
      ],
      confidence: 1.4,
      updateReason: '未知',
    );

    final json = analysis.toJson();
    final restored = MomentProfileAnalysis.fromJson(json);

    expect(json['sceneSummary'], '已从截图提取人物画像。');
    expect(json['sourcePlatform'], '微信');
    expect(json['visibleName'], isNull);
    expect(json['relationshipGuess'], isNull);
    expect(json['personalityTraits'], hasLength(8));
    expect(
      List<String>.from(json['personalityTraits'] as List).take(2).toList(),
      ['稳', '特质0'],
    );
    expect(json['innerNeeds'], ['确定性']);
    expect(json['keyPersonPoints'], ['喜欢提前确认时间']);
    expect(json['momentsInsights'], ['常发工作动态']);
    expect(json['communicationAdvice'], ['少追问']);
    expect(json['boundaries'], ['临时催促']);
    expect(json['stableFacts'], hasLength(10));
    expect(
      List<String>.from(json['stableFacts'] as List).take(2).toList(),
      ['项目负责人', '事实0'],
    );
    expect(json['confidence'], 1);
    expect(json['updateReason'], isNull);
    expect(restored.sceneSummary, '已从截图提取人物画像。');
    expect(restored.sourcePlatform, '微信');
    expect(restored.visibleName, isNull);
    expect(restored.relationshipGuess, isNull);
    expect(restored.personalityTraits, hasLength(8));
    expect(restored.innerNeeds, ['确定性']);
    expect(restored.keyPersonPoints, ['喜欢提前确认时间']);
    expect(restored.momentsInsights, ['常发工作动态']);
    expect(restored.communicationAdvice, ['少追问']);
    expect(restored.boundaries, ['临时催促']);
    expect(restored.stableFacts, hasLength(10));
    expect(restored.confidence, 1);
    expect(restored.updateReason, isNull);
    expect(restored.personInsight.displayName, isNull);
    expect(restored.personInsight.facts, hasLength(10));
  });

  test('simulation parser normalizes aliases and string scores', () {
    final parsed = SimulationTurnResponse.fromJson({
      'opponentMessage': '那你刚才为什么不说',
      'state': '有点追问',
      'favorability': ' 120 ',
      'tension': ' -5 ',
      'metrics': [
        {'label': '边界感', 'score': ' 88 ', 'comment': '表达清楚'}
      ],
      'options': [
        {'reply': '未知', 'style': '占位'},
        {'reply': '刚刚我没想清楚，现在认真说。', 'style': '修复', 'explanation': '补上态度'},
        {'reply': '刚刚我没想清楚，现在认真说。', 'style': '重复'},
        {'reply': '我补一句更具体的后续。', 'style': '补充'}
      ],
      'userScore': ' 92 ',
      'tip': '先解释，再给对方空间。',
    });

    expect(parsed.personaMessage, '那你刚才为什么不说');
    expect(parsed.sceneState, '有点追问');
    expect(parsed.favorability, 100);
    expect(parsed.tension, 0);
    expect(parsed.metrics.first.name, '边界感');
    expect(parsed.metrics.first.score, 88);
    expect(parsed.metrics.first.insight, '表达清楚');
    expect(
        parsed.metrics.map((metric) => metric.name),
        containsAll([
          '好感度',
          '自然度',
          '边界感',
          '推进度',
          '情绪接住',
          '风险控制',
        ]));
    expect(parsed.metrics, hasLength(6));
    expect(parsed.options.map((option) => option.text), [
      '刚刚我没想清楚，现在认真说。',
      '我补一句更具体的后续。',
    ]);
    expect(parsed.options.first.label, '修复');
    expect(parsed.options.first.reason, '补上态度');
    expect(parsed.userScore, 92);
    expect(parsed.coachTip, '先解释，再给对方空间。');

    final scalarSource =
        File('lib/core/model_json_scalar_helpers.dart').readAsStringSync();
    expect(scalarSource, contains('_doubleInRange(Object? raw'));
    expect(scalarSource, contains('_optionalScore(Object? raw'));
    expect(
      scalarSource,
      isNot(contains("double.tryParse('\$raw')")),
    );
    expect(scalarSource, isNot(contains("int.tryParse('\$raw')")));
  });

  test('simulation parser accepts scorecard and reply option aliases', () {
    final parsed = SimulationTurnResponse.fromJson({
      'personaReply': '那你下次提前说一下',
      'stateSummary': '对方需要一个明确解释',
      'scores': {
        'favorability': '72',
        'tension': '25',
        'trust': 68,
        'interest': '70',
      },
      'scorecard': [
        {'metric': '自然度', 'value': '81', 'explanation': '像日常聊天'}
      ],
      'suggestedReplies': [
        {
          'suggestion': '下次我提前跟你说，不让你一直等。',
          'tone': '修复',
          'why': '给出具体行动',
          'qualityScore': '86',
        }
      ],
      'replyScore': '78',
      'review': '解释清楚，但可以更早承认对方感受。',
      'improvedReply': '我刚才没及时说清楚，下次会提前告诉你。',
      'advice': '先承认，再补行动。',
    });

    expect(parsed.personaMessage, '那你下次提前说一下');
    expect(parsed.sceneState, '对方需要一个明确解释');
    expect(parsed.favorability, 72);
    expect(parsed.tension, 25);
    expect(parsed.trust, 68);
    expect(parsed.interest, 70);
    expect(parsed.metrics.first.name, '自然度');
    expect(parsed.metrics.first.score, 81);
    expect(parsed.metrics.first.insight, '像日常聊天');
    expect(
        parsed.metrics.map((metric) => metric.name),
        containsAll([
          '好感度',
          '自然度',
          '边界感',
          '推进度',
          '情绪接住',
          '风险控制',
        ]));
    expect(parsed.metrics, hasLength(6));
    expect(parsed.options.single.text, '下次我提前跟你说，不让你一直等。');
    expect(parsed.options.single.label, '修复');
    expect(parsed.options.single.reason, '给出具体行动');
    expect(parsed.options.single.predictedScore, 86);
    expect(parsed.userScore, 78);
    expect(parsed.feedback, '解释清楚，但可以更早承认对方感受。');
    expect(parsed.betterReply, '我刚才没及时说清楚，下次会提前告诉你。');
    expect(parsed.coachTip, '先承认，再补行动。');

    final compatible = SimulationTurnResponse.fromJson({
      'payload': {
        'characterReply': '那你打算怎么补上？',
        'sceneSummary': '对方在等具体行动',
        'choices': [
          {
            'answer': '我今天先把这件事补完，再跟你同步结果。',
            'tone': '承担',
            'rationale': '给出明确动作',
            'expectedScore': '84',
          }
        ],
        'critique': '态度有了，还可以更具体。',
        'rewrite': '我今天会先补上这件事，晚点把结果发你。',
        'trainingTip': '把承诺落到一个具体动作。',
      },
    });

    expect(compatible.personaMessage, '那你打算怎么补上？');
    expect(compatible.sceneState, '对方在等具体行动');
    expect(compatible.options.single.text, '我今天先把这件事补完，再跟你同步结果。');
    expect(compatible.options.single.label, '承担');
    expect(compatible.options.single.reason, '给出明确动作');
    expect(compatible.options.single.predictedScore, 84);
    expect(compatible.feedback, '态度有了，还可以更具体。');
    expect(compatible.betterReply, '我今天会先补上这件事，晚点把结果发你。');
    expect(compatible.coachTip, '把承诺落到一个具体动作。');
  });

  test('simulation parser unwraps compatible provider envelopes', () {
    final parsed = SimulationTurnResponse.fromJson({
      'result': {
        'persona_reply': '那你准备怎么补救？',
        'scene_state': '对方在等明确回应',
        'scores': {
          'favorability': '70',
          'tension': '34',
          'trust': '66',
          'interest': '64',
        },
        'score_card': [
          {'metric': '自然度', 'value': '82', 'explanation': '像日常聊天'}
        ],
        'reply_options': [
          {
            'text': '我刚才没处理好，先跟你道个歉。',
            'label': '修复',
            'reason': '先承认问题',
            'predicted_score': '86',
          }
        ],
        'user_score': '74',
        'feedback': '先接住情绪会更稳。',
        'better_reply': '我刚刚没顾到你的感受，先跟你说声抱歉。',
        'coach_tip': '先承认影响，再补行动。',
      },
    });
    final nested = SimulationTurnResponse.fromJson({
      'payload': {
        'data': {
          'response': {
            'persona_reply': '那你具体打算怎么做？',
            'scene_state': '对方需要具体计划',
            'scores': {'favorability': '68', 'tension': '42'},
            'replies': ['我今晚先整理出来，明早发你。'],
          },
        },
      },
    });

    expect(parsed.personaMessage, '那你准备怎么补救？');
    expect(parsed.sceneState, '对方在等明确回应');
    expect(parsed.favorability, 70);
    expect(parsed.tension, 34);
    expect(parsed.trust, 66);
    expect(parsed.interest, 64);
    expect(parsed.metrics.first.name, '自然度');
    expect(parsed.metrics.first.score, 82);
    expect(parsed.options.single.text, '我刚才没处理好，先跟你道个歉。');
    expect(parsed.options.single.label, '修复');
    expect(parsed.options.single.predictedScore, 86);
    expect(parsed.userScore, 74);
    expect(parsed.feedback, '先接住情绪会更稳。');
    expect(parsed.betterReply, '我刚刚没顾到你的感受，先跟你说声抱歉。');
    expect(parsed.coachTip, '先承认影响，再补行动。');
    expect(nested.personaMessage, '那你具体打算怎么做？');
    expect(nested.sceneState, '对方需要具体计划');
    expect(nested.favorability, 68);
    expect(nested.tension, 42);
    expect(nested.options.single.text, '我今晚先整理出来，明早发你。');
  });

  test('simulation parser accepts exported next reply aliases', () {
    final parsed = SimulationTurnResponse.fromJson({
      'output': {
        'assistantReply': '那你现在准备怎么说？',
        'status': '对方在等明确解释',
        'ratings': {
          'liking': '69',
          'awkwardness': '31',
          'confidence': '67',
          'engagement': '72',
        },
        'evaluation': {
          '自然度': {'score': '83', 'comment': '接近日常表达'},
        },
        'nextReplies': [
          {
            'replyText': '我刚才没说清楚，现在认真补一下。',
            'styleName': '修复',
            'note': '先承认沟通缺口',
            'expectedScore': '85',
          }
        ],
        'responseScore': '79',
        'assessment': '方向对，但可以更具体。',
        'suggestedRewrite': '我刚才没有及时讲清楚，接下来会提前同步。',
        'nextStep': '给出一个具体后续动作。',
      },
    });

    expect(parsed.personaMessage, '那你现在准备怎么说？');
    expect(parsed.sceneState, '对方在等明确解释');
    expect(parsed.favorability, 69);
    expect(parsed.tension, 31);
    expect(parsed.trust, 67);
    expect(parsed.interest, 72);
    expect(parsed.metrics.first.name, '自然度');
    expect(parsed.metrics.first.score, 83);
    expect(parsed.metrics.first.insight, '接近日常表达');
    expect(parsed.options.single.text, '我刚才没说清楚，现在认真补一下。');
    expect(parsed.options.single.label, '修复');
    expect(parsed.options.single.reason, '先承认沟通缺口');
    expect(parsed.options.single.predictedScore, 85);
    expect(parsed.userScore, 79);
    expect(parsed.feedback, '方向对，但可以更具体。');
    expect(parsed.betterReply, '我刚才没有及时讲清楚，接下来会提前同步。');
    expect(parsed.coachTip, '给出一个具体后续动作。');
  });

  test('simulation parser accepts rubric and candidate reply aliases', () {
    final parsed = SimulationTurnResponse.fromJson({
      'assistantMessage': '那你打算怎么安排？',
      'situation': '对方在确认后续计划',
      'relationshipScores': {
        'affection': '73',
        'risk': '28',
        'confidence': '69',
        'engagement': '71',
      },
      'dimensionScores': {
        '推进度': {'points': '84', 'description': '给出了清晰后续'},
      },
      'candidateReplies': [
        {
          'candidateReply': '我今晚先确认时间，确定后马上告诉你。',
          'toneLabel': '稳妥',
          'justification': '给出明确时间点',
          'confidenceScore': '88',
        },
        {
          'recommendedReply': '我先把可选时间列出来，你选方便的。',
          'category': '协商',
          'why': '让对方参与选择',
          'rating': '82',
        },
      ],
      'score': '80',
      'assessment': '计划清楚，但还可以更主动。',
      'suggestedRewrite': '我今晚先确认两个可选时间，确定后马上发你。',
      'trainingTip': '承诺后补一个具体时间点。',
    });

    expect(parsed.personaMessage, '那你打算怎么安排？');
    expect(parsed.sceneState, '对方在确认后续计划');
    expect(parsed.favorability, 73);
    expect(parsed.tension, 28);
    expect(parsed.trust, 69);
    expect(parsed.interest, 71);
    expect(parsed.metrics.first.name, '推进度');
    expect(parsed.metrics.first.score, 84);
    expect(parsed.metrics.first.insight, '给出了清晰后续');
    expect(parsed.options.map((option) => option.text), [
      '我今晚先确认时间，确定后马上告诉你。',
      '我先把可选时间列出来，你选方便的。',
    ]);
    expect(parsed.options.first.label, '稳妥');
    expect(parsed.options.first.reason, '给出明确时间点');
    expect(parsed.options.first.predictedScore, 88);
    expect(parsed.options[1].label, '协商');
    expect(parsed.options[1].predictedScore, 82);
    expect(parsed.userScore, 80);
    expect(parsed.feedback, '计划清楚，但还可以更主动。');
    expect(parsed.betterReply, '我今晚先确认两个可选时间，确定后马上发你。');
    expect(parsed.coachTip, '承诺后补一个具体时间点。');
  });

  test('simulation options and metrics accept common exported aliases', () {
    final option = SimulationOption.fromJson({
      'candidateId': 'sim-option-1',
      'nextReply': '我先把刚才没说清楚的地方补一下。',
      'toneLabel': '修复',
      'notes': '先补信息，再给承诺',
      'rating': '87',
    });
    final metric = SimulationMetric.fromJson({
      'dimension': '情绪接住',
      'points': '82',
      'description': '先回应了对方感受',
    });

    expect(option.id, 'sim-option-1');
    expect(option.text, '我先把刚才没说清楚的地方补一下。');
    expect(option.label, '修复');
    expect(option.reason, '先补信息，再给承诺');
    expect(option.predictedScore, 87);
    expect(metric.name, '情绪接住');
    expect(metric.score, 82);
    expect(metric.insight, '先回应了对方感受');
  });

  test('simulation response json cleans noisy presentation values', () {
    final message = SimulationMessage(
      id: ' 未知 ',
      speaker: SimulationSpeaker.user,
      text: '  我会认真说  ',
    ).normalized();
    final response = SimulationTurnResponse(
      personaMessage: '未知',
      sceneState: ' ',
      favorability: 120,
      tension: -5,
      trust: 101,
      interest: -2,
      metrics: const [
        SimulationMetric(name: '自然度', score: 120, insight: '未知'),
        SimulationMetric(name: ' 自定义 ', score: -3, insight: ' 额外 '),
        SimulationMetric(name: '未知', score: 77, insight: '占位'),
      ],
      options: [
        SimulationOption(
          text: '未知',
          label: '未知',
          reason: '未知',
          predictedScore: 120,
        ),
        SimulationOption(
          id: ' 未知 ',
          text: '  我先把这件事说清楚。  ',
          label: '  修复  ',
          reason: '  先补信息  ',
          predictedScore: -8,
        ),
        SimulationOption(text: '我先把这件事说清楚。', label: '重复', reason: '重复'),
        SimulationOption(text: '第二条', label: '跟进', reason: '继续聊'),
        SimulationOption(text: '第三条', label: '稳住', reason: '接情绪'),
        SimulationOption(text: '第四条', label: '忽略', reason: '超过上限'),
      ],
      userScore: 999,
      feedback: '未知',
      betterReply: '未知',
      coachTip: '未知',
    );

    final json = response.toJson();
    final metrics = (json['metrics'] as List<Object?>)
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
    final options = (json['options'] as List<Object?>)
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
    final restored = SimulationTurnResponse.fromJson(json);

    expect(json['personaMessage'], '嗯，我听到了。你继续说，我想知道你真正的想法。');
    expect(json['sceneState'], '对话正在进行中。');
    expect(json['favorability'], 100);
    expect(json['tension'], 0);
    expect(json['trust'], 100);
    expect(json['interest'], 0);
    expect(metrics.map((metric) => metric['name']), contains('自然度'));
    expect(metrics.map((metric) => metric['name']), isNot(contains('指标')));
    expect(
      metrics.firstWhere((metric) => metric['name'] == '自然度')['score'],
      100,
    );
    expect(
      metrics.firstWhere((metric) => metric['name'] == '自然度')['insight'],
      '暂无说明',
    );
    expect(options, hasLength(3));
    expect(options.first['id'], '未知');
    expect(options.first['text'], '我先把这件事说清楚。');
    expect(options.first['label'], '修复');
    expect(options.first['reason'], '先补信息');
    expect(options.first['predictedScore'], 0);
    expect(options.map((option) => option['text']), isNot(contains('第四条')));
    expect(json['userScore'], 100);
    expect(json['feedback'], isNull);
    expect(json['betterReply'], isNull);
    expect(json['coachTip'], '下一轮可以更具体地接住对方情绪。');
    expect(restored.personaMessage, '嗯，我听到了。你继续说，我想知道你真正的想法。');
    expect(restored.favorability, 100);
    expect(restored.tension, 0);
    expect(restored.trust, 100);
    expect(restored.interest, 0);
    expect(restored.options, hasLength(3));
    expect(restored.options.first.id, '未知');
    expect(restored.options.first.text, '我先把这件事说清楚。');
    expect(restored.userScore, 100);
    expect(restored.feedback, isNull);
    expect(restored.betterReply, isNull);
    expect(message.id, '未知');
    expect(message.text, '我会认真说');

    final modelsSource =
        File('lib/core/simulation_models.dart').readAsStringSync();
    final jsonSource =
        File('lib/core/simulation_option_metric_json.dart').readAsStringSync();
    final metricSource =
        File('lib/core/simulation_metric_helpers.dart').readAsStringSync();
    expect(
        modelsSource, contains('id = cleanIdentifierText(id) ?? _uuid.v4();'));
    expect(modelsSource, contains('id: cleanIdentifierText(id),'));
    expect(jsonSource,
        contains("'id': cleanIdentifierText(option.id) ?? _uuid.v4(),"));
    expect(modelsSource, isNot(contains('id: cleanPresentationText(id),')));
    expect(metricSource, contains('cleanPresentationText(metric.name)'));
    expect(metricSource, contains('_normalizedSimulationMetric(metric)'));
    expect(metricSource, isNot(contains('metric.name.trim()')));
  });

  test('simulation parser preserves map scorecard metrics from providers', () {
    final parsed = SimulationTurnResponse.fromJson({
      'personaMessage': '那你准备怎么说？',
      'scorecard': {
        '自然度': {'score': '81', 'insight': '像日常聊天'},
        '边界感': 76,
      },
    });

    expect(parsed.metrics.first.name, '自然度');
    expect(parsed.metrics.first.score, 81);
    expect(parsed.metrics.first.insight, '像日常聊天');
    expect(parsed.metrics[1].name, '边界感');
    expect(parsed.metrics[1].score, 76);
    expect(parsed.metrics[1].insight, '暂无说明');
    expect(
        parsed.metrics.map((metric) => metric.name),
        containsAll([
          '好感度',
          '自然度',
          '边界感',
          '推进度',
          '情绪接住',
          '风险控制',
        ]));
  });

  test('simulation parser caps metrics while preserving required iOS metrics',
      () {
    final parsed = SimulationTurnResponse.fromJson({
      'personaMessage': '那你想怎么聊？',
      'metrics': [
        {'name': '自定义1', 'score': 11, 'insight': '额外'},
        {'name': '自定义2', 'score': 12, 'insight': '额外'},
        {'name': '自定义3', 'score': 13, 'insight': '额外'},
        {'name': '自定义4', 'score': 14, 'insight': '额外'},
        {'name': '自定义5', 'score': 15, 'insight': '额外'},
        {'name': '自定义6', 'score': 16, 'insight': '额外'},
        {'name': '自然度', 'score': 88, 'insight': '像日常聊天'},
      ],
    });

    expect(parsed.metrics, hasLength(8));
    expect(
        parsed.metrics.map((metric) => metric.name),
        containsAll([
          '好感度',
          '自然度',
          '边界感',
          '推进度',
          '情绪接住',
          '风险控制',
        ]));
    expect(
        parsed.metrics.firstWhere((metric) => metric.name == '自然度').score, 88);
    expect(parsed.metrics.where((metric) => metric.name.startsWith('自定义')),
        hasLength(2));
  });

  test('simulation scenarios preserve iOS titles and prompt goals', () {
    expect(
      SimulationScenario.values.map((scenario) => scenario.title).toList(),
      ['日常闲聊', '安慰情绪', '邀约推进', '化解误会', '表达边界'],
    );
    expect(
      SimulationScenario.values.map((scenario) => scenario.promptGoal).toList(),
      [
        '练习自然接话，避免尬聊，让对方愿意继续聊。',
        '练习接住对方情绪，稳定陪伴，不过度说教。',
        '练习低压力推进邀约，表达清楚但不逼迫。',
        '练习化解误会，减少防御感，给关系留余地。',
        '练习温和但清楚地表达边界，不攻击对方。',
      ],
    );
  });

  test('simulation parser preserves string reply options from providers', () {
    final parsed = SimulationTurnResponse.fromJson({
      'personaMessage': '那你准备怎么补救？',
      'suggestedReplies': [
        '我刚刚处理得不够好，我先跟你说声抱歉。',
        '我会把这件事补上，也想听听你希望我怎么做。',
        '那我们先把误会说清楚，好吗？',
        '第四条应该被截断',
      ],
    });

    expect(parsed.options.map((option) => option.text), [
      '我刚刚处理得不够好，我先跟你说声抱歉。',
      '我会把这件事补上，也想听听你希望我怎么做。',
      '那我们先把误会说清楚，好吗？',
    ]);
    expect(parsed.options.first.label, '建议');
    expect(parsed.options.first.reason, '模型提供的候选回复。');
  });

  test('simulation parser fills iOS default metrics and options', () {
    final parsed = SimulationTurnResponse.fromJson({
      'personaMessage': '你继续说，我在听。',
      'metrics': [],
      'options': [],
    });

    expect(parsed.metrics.map((metric) => metric.name), [
      '好感度',
      '自然度',
      '边界感',
      '推进度',
      '情绪接住',
      '风险控制',
    ]);
    expect(parsed.metrics.map((metric) => metric.score), [
      55,
      55,
      55,
      55,
      55,
      60,
    ]);
    expect(parsed.options.map((option) => option.label), [
      '稳妥',
      '追问',
      '澄清',
    ]);
    expect(parsed.options.map((option) => option.id).toSet(), hasLength(3));
  });

  test('reply prompts preserve iOS style execution constraints', () {
    final style = ChatStyle.presets.first;
    final textPrompt = textReplyPrompt(
      text: '对方：周末有空吗',
      style: style,
      userGoal: '自然一点',
    );
    final imagePrompt = visionReplyPrompt(style: style);

    expect(textPrompt, contains('用户选择风格是最高优先级'));
    expect(textPrompt, contains('风格优先级：'));
    expect(textPrompt, contains('用户本次选择的“自然”是最高表达优先级'));
    expect(textPrompt, contains('不能覆盖或稀释“自然”'));
    expect(textPrompt, contains('如果人物库或历史语气与“自然”冲突'));
    expect(textPrompt, contains('每条 style 都以“自然-”开头'));
    expect(textPrompt, contains('人物库只能决定“怎么避雷、怎么理解对方”，不能决定本次回复风格'));
    expect(textPrompt, contains('如果设置与“自然”冲突，优先“自然”'));
    expect(textPrompt, contains('每条回复不超过 40 字'));
    expect(textPrompt, contains('回复策略：'));
    expect(textPrompt, contains('接住情绪、补充解释、轻推下一步、设定边界、低压力收尾'));
    expect(textPrompt, contains('输出前自检：'));
    expect(textPrompt, contains('replies 正好 5 条'));
    expect(textPrompt, contains('"style": "自然-接住情绪"'));
    expect(textPrompt, contains('"riskWarning": "风险提醒，没有则为空"'));
    expect(textPrompt, contains('"latestMessage": "对方最后一句需要回复的话"'));
    expect(textPrompt, contains('聊天中可见的昵称或用户给出的称呼'));
    expect(imagePrompt, contains('判断聊天平台'));
    expect(imagePrompt, contains('用户本次选择的“自然”是最高表达优先级'));
    expect(imagePrompt, contains('如果用户目标与“自然”冲突，优先保持“自然”'));
    expect(imagePrompt, contains('不要根据头像、面部、照片外貌推断真实身份'));
    expect(imagePrompt, contains('低压力收尾'));
    expect(imagePrompt, contains('不确定的信息写在 riskWarning 或 reason 里保持克制'));
    expect(imagePrompt, contains('"latestMessage": "对方最后一句需要回复的话"'));
    expect(imagePrompt, contains('截图中可见的昵称或用户给出的称呼'));
  });

  test('reply prompts treat placeholder optional context as empty', () {
    final style = ChatStyle.presets.first;
    final textPrompt = textReplyPrompt(
      text: '对方：周末有空吗',
      style: style,
      userGoal: '  未知  ',
      personProfileContext: '  未知  ',
      personalizationContext: '  未知  ',
    );
    final imagePrompt = visionReplyPrompt(
      style: style,
      userGoal: '  未知  ',
      personProfileContext: '  未知  ',
      personalizationContext: '  未知  ',
    );

    for (final prompt in [textPrompt, imagePrompt]) {
      expect(prompt, contains('用户目标：\n无额外目标'));
      expect(prompt, contains('已有人物库摘要：\n暂无人物库记录'));
      expect(prompt, contains('我的个性化回复设置：\n暂无个性化设置'));
    }
  });

  test('reply prompts clean dirty style names and rules', () {
    final dirtyStyle = ChatStyle(
      name: '  未知  ',
      description: '  ',
      rules: const ['  ', '未知'],
    );
    final textPrompt = textReplyPrompt(
      text: '对方：周末有空吗',
      style: dirtyStyle,
    );
    final imagePrompt = visionReplyPrompt(style: dirtyStyle);

    for (final prompt in [textPrompt, imagePrompt]) {
      expect(prompt, contains('用户选择风格：\n自然'));
      expect(prompt, contains('用户本次选择的“自然”是最高表达优先级'));
      expect(prompt, contains('风格要求：\n- 语气自然'));
      expect(prompt, contains('- 每条回复不超过40字'));
      expect(prompt, isNot(contains('用户本次选择的“未知”')));
    }

    final source = File('lib/core/prompts.dart').readAsStringSync();
    expect(source, contains('final styleName ='));
    expect(source, contains('cleanPresentationText(style.name)'));
    expect(source, contains('uniqueCleanPresentationList(style.rules)'));
  });

  test('simulation prompt preserves iOS training constraints', () {
    final prompt = simulationPrompt(
      profileContext: '昵称：小林',
      scenario: SimulationScenario.conflict.title,
      scenarioGoal: SimulationScenario.conflict.promptGoal,
      history: '我：刚才有点急',
      userReply: '我重新说',
      personalizationContext: '口语化',
    );

    expect(prompt, contains('中文聊天训练教练'));
    expect(prompt, contains('如果“用户本轮回复”为“尚未回复”'));
    expect(prompt, contains('好感度、自然度、边界感、推进度、情绪接住、风险控制'));
    expect(prompt, contains('具体指出用户本轮回复的一个有效点和一个可改进点'));
    expect(
        prompt, contains('personaMessage、options.text、betterReply 都要像手机聊天短句'));
    expect(prompt, contains('稳妥”“推进”“修复”“降温”“澄清'));
    expect(prompt, contains('不要输出操控、PUA、威胁、羞辱或过度性暗示内容'));
    expect(prompt, contains('不要暴露“我根据人物库判断”'));
    expect(prompt, contains('"personaMessage": "对方下一句会怎么说"'));
    expect(prompt, contains('"feedback": "对用户本轮回复的具体点评；没回复时为空"'));
  });

  test('simulation prompt treats placeholder context as empty', () {
    final prompt = simulationPrompt(
      profileContext: ' 未知 ',
      scenario: SimulationScenario.dailyChat.title,
      scenarioGoal: SimulationScenario.dailyChat.promptGoal,
      history: ' 未知 ',
      userReply: ' 未知 ',
      personalizationContext: ' 未知 ',
    );

    expect(prompt, contains('人物画像：\n暂无人物库记录'));
    expect(prompt, contains('用户个性化设置：\n暂无个性化设置'));
    expect(prompt, contains('已有对话：\n暂无，请由对方自然开场。'));
    expect(prompt, contains('用户本轮回复：\n尚未回复'));
  });

  test('moment profile prompt preserves iOS extraction checklist', () {
    final prompt = momentProfilePrompt(personProfileContext: '昵称：小林');

    expect(prompt, contains('你要识别：'));
    expect(prompt, contains('内容主题、发帖风格、互动方式'));
    expect(prompt, contains('可稳定保存的事实，必须来自截图可见文字或明确语境'));
    expect(prompt, contains('如果截图不是朋友圈/社交动态，也尽量提取内容画像'));
    expect(prompt, contains('昵称：小林'));
  });

  test('moment profile prompt treats placeholder target as unspecified', () {
    final prompt = momentProfilePrompt(personProfileContext: '  未知  ');

    expect(
      prompt,
      contains('本次用户指定的可能写入对象：\n未指定，请根据截图可见昵称和内容自动判断。'),
    );
  });

  test('openai endpoint helpers preserve explicit API endpoint paths', () {
    final noisyChatEndpoint =
        openAIEndpointUrl(Uri.parse('https://api.example//v1//?foo=bar'));
    expect(noisyChatEndpoint.path, '/v1/chat/completions');
    expect(noisyChatEndpoint.query, isEmpty);
    expect(
      openAIEndpointUrl(Uri.parse('https://api.example:8443//v1//?foo=bar'))
          .toString(),
      'https://api.example:8443/v1/chat/completions',
    );
    expect(openAIEndpointUrl(Uri.parse('https://api.example/v1')).path,
        '/v1/chat/completions');
    expect(openAIEndpointUrl(Uri.parse('https://api.example//v1//')).path,
        '/v1/chat/completions');
    expect(
        openAIEndpointUrl(Uri.parse('https://api.example/v1/chat/completions'))
            .path,
        '/v1/chat/completions');
    expect(openAIModelsUrl(Uri.parse('https://api.example/v1/responses')).path,
        '/v1/models');
    final noisyModelsEndpoint = openAIModelsUrl(
        Uri.parse('https://api.example//v1//responses?foo=bar'));
    expect(noisyModelsEndpoint.path, '/v1/models');
    expect(noisyModelsEndpoint.query, isEmpty);
    expect(
        openAIModelsUrl(Uri.parse('https://api.example/v1/chat/completions'))
            .path,
        '/v1/models');
    expect(openAIModelsUrl(Uri.parse('https://api.example/v1/models')).path,
        '/v1/models');
    final noisyResponsesFallback = chatCompletionsUrlFromResponses(
        Uri.parse('https://api.example//v1//responses?foo=bar'));
    expect(noisyResponsesFallback.path, '/v1/chat/completions');
    expect(noisyResponsesFallback.query, isEmpty);
  });

  test('api model preserves iOS display metadata', () {
    final model = APIModel.fromJson({
      'id': 'tts-1',
      'owned_by': 'openai',
    });

    expect(model.id, 'tts-1');
    expect(model.ownedBy, 'openai');
    expect(model.isVoiceModel, isTrue);
    expect(model.isTextCandidate, isFalse);
    expect(model.displayTitle, 'tts-1 · 语音');

    final compatibleModel = APIModel.fromJson({
      'model_id': 'provider-chat',
      'owned-by': 'compatible-provider',
    });
    expect(compatibleModel.id, 'provider-chat');
    expect(compatibleModel.ownedBy, 'compatible-provider');

    final whisper = APIModel.fromJson({'id': 'whisper-1'});
    expect(whisper.isVoiceModel, isTrue);
    expect(whisper.isTextCandidate, isFalse);
    expect(whisper.displayTitle, 'whisper-1 · 语音');

    final transcribe = APIModel.fromJson({'id': 'gpt-4o-transcribe'});
    expect(transcribe.isVoiceModel, isTrue);
    expect(transcribe.isTextCandidate, isFalse);
    expect(transcribe.displayTitle, 'gpt-4o-transcribe · 语音');

    final embedding = APIModel.fromJson({'id': 'text-embedding-3-large'});
    expect(embedding.isNonChatModel, isTrue);
    expect(embedding.isTextCandidate, isFalse);
    expect(embedding.displayTitle, 'text-embedding-3-large · 非聊天');

    final moderation = APIModel.fromJson({'id': 'omni-moderation-latest'});
    expect(moderation.isNonChatModel, isTrue);
    expect(moderation.isVisionCandidate, isFalse);
    expect(moderation.isTextCandidate, isFalse);
    expect(moderation.displayTitle, 'omni-moderation-latest · 非聊天');

    final safety = APIModel.fromJson({'id': 'omni-safety-classifier'});
    expect(safety.isNonChatModel, isTrue);
    expect(safety.isVisionCandidate, isFalse);
    expect(safety.isTextCandidate, isFalse);
    expect(safety.displayTitle, 'omni-safety-classifier · 非聊天');

    final visionModel = APIModel.fromJson({'name': 'qwen2.5-vl-72b'});
    expect(visionModel.isVisionCandidate, isTrue);
    expect(visionModel.displayTitle, 'qwen2.5-vl-72b');

    final declaredVisionModel = APIModel.fromJson({
      'id': 'provider-chat-pro',
      'modalities': ['text', 'image'],
    });
    final objectModalitiesModel = APIModel.fromJson({
      'id': 'provider-object-modalities',
      'modalities': [
        {'type': 'text'},
        {'type': 'image'}
      ],
    });
    final mapModalitiesModel = APIModel.fromJson({
      'id': 'provider-map-modalities',
      'modalities': {
        'input': ['text', 'image'],
        'output': ['text'],
      },
    });
    final nestedCapabilityModel = APIModel.fromJson({
      'id': 'provider-reasoner',
      'capabilities': {'supports_vision': true, 'reasoning': true},
    });
    expect(declaredVisionModel.isVisionCandidate, isTrue);
    expect(declaredVisionModel.capability?.isMultimodal, isTrue);
    expect(objectModalitiesModel.isVisionCandidate, isTrue);
    expect(objectModalitiesModel.capability?.isMultimodal, isTrue);
    expect(mapModalitiesModel.isVisionCandidate, isTrue);
    expect(mapModalitiesModel.capability?.isMultimodal, isTrue);
    expect(nestedCapabilityModel.isVisionCandidate, isTrue);
    expect(nestedCapabilityModel.capability?.isReasoning, isTrue);

    expect(APIModel.fromJson({'id': 'gpt-4o-mini'}).isVisionCandidate, isTrue);
    expect(APIModel.fromJson({'id': 'gemini-1.5-flash'}).isVisionCandidate,
        isTrue);
    expect(APIModel.fromJson({'id': 'llava-1.6'}).isVisionCandidate, isTrue);
    expect(APIModel.fromJson({'id': 'MiniCPM-V'}).isVisionCandidate, isTrue);
    expect(APIModel.fromJson({'id': 'gpt-4v'}).isVisionCandidate, isTrue);
    expect(APIModel.fromJson({'id': 'glm-4v-plus'}).isVisionCandidate, isTrue);
    expect(APIModel.fromJson({'id': 'InternVL2.5'}).isVisionCandidate, isTrue);
    expect(APIModel.fromJson({'id': 'step-1v-32k'}).isVisionCandidate, isTrue);
  });

  test('api model accepts top-level compatible modality metadata', () {
    final modelName = APIModel.fromJson({
      'model_name': 'provider-top-input',
      'input': ['text', 'image'],
    });
    final supportedInputs = APIModel.fromJson({
      'id': 'provider-supported-inputs',
      'supported_inputs': ['text', 'vision', 'reasoning'],
    });
    final aliasedCapability = APIModel.fromJson({
      'id': 'provider-aliased-capability',
      'supports_image': 'yes',
      'reasoning_model': true,
    });
    final supportedCapability = APIModel.fromJson({
      'id': 'provider-supported-capability',
      'supports_vision': 'supported',
      'supports_thinking': 'available',
    });
    final unsupportedCapability = APIModel.fromJson({
      'id': 'provider-unsupported-capability',
      'supports_vision': 'unsupported',
      'supports_thinking': 'unavailable',
    });

    expect(modelName.id, 'provider-top-input');
    expect(modelName.capability?.isMultimodal, isTrue);
    expect(supportedInputs.capability?.isMultimodal, isTrue);
    expect(supportedInputs.capability?.isReasoning, isTrue);
    expect(aliasedCapability.capability?.isMultimodal, isTrue);
    expect(aliasedCapability.capability?.isReasoning, isTrue);
    expect(supportedCapability.capability?.isMultimodal, isTrue);
    expect(supportedCapability.capability?.isReasoning, isTrue);
    expect(unsupportedCapability.capability?.isMultimodal, isFalse);
    expect(unsupportedCapability.capability?.isReasoning, isFalse);
  });

  test('api model accepts common exported identity aliases', () {
    final slugModel = APIModel.fromJson({
      'slug': 'provider-chat-pro',
      'provider': 'compatible-provider',
    });
    final valueModel = APIModel.fromJson({
      'label': 'Provider Chat Pro',
      'value': 'provider-chat-lite',
      'publisher': 'provider-name',
    });
    final unknownLabelModel = APIModel.fromJson({
      'id': '  未知  ',
      'provider': 'compatible-provider',
    });

    expect(slugModel.id, 'provider-chat-pro');
    expect(slugModel.ownedBy, 'compatible-provider');
    expect(valueModel.id, 'provider-chat-lite');
    expect(valueModel.ownedBy, 'provider-name');
    expect(unknownLabelModel.id, '未知');

    final modelJsonSource =
        File('lib/core/api_model_json.dart').readAsStringSync();
    final itemSource = File('lib/core/api_model_items.dart').readAsStringSync();
    expect(modelJsonSource,
        contains('id: _firstIdentifier(json, _apiModelIdKeys) ?? \'\','));
    expect(modelJsonSource,
        isNot(contains('id: _firstClean(json, _apiModelIdKeys)')));
    expect(
      itemSource,
      contains(
          "return APIModel(id: cleanIdentifierText(item?.toString()) ?? '');"),
    );
    expect(itemSource, isNot(contains('item?.toString().trim()')));
  });

  test('api base url validation requires an http host', () {
    expect(APIConfig.defaults.hasValidBaseUri, isTrue);
    expect(
      APIConfig.defaults
          .copyWith(baseURL: 'http://127.0.0.1:8080/v1')
          .hasValidBaseUri,
      isTrue,
    );

    for (final baseURL in ['https://', 'http://', 'ftp://api.example/v1']) {
      final config = APIConfig.defaults.copyWith(baseURL: baseURL);
      expect(config.hasValidBaseUri, isFalse, reason: baseURL);
      expect(
        GenerateAPIReadiness(
          config: config,
          hasAPIKey: true,
          capability: GenerateAPICapability.text,
        ).statusText,
        contains('Base URL'),
      );
    }
    final withFragment = APIConfig.defaults
        .copyWith(baseURL: ' HTTPS://API.EXAMPLE//v1//?foo=bar#top ');
    expect(
        withFragment.normalizedBaseUri?.toString(), 'https://api.example/v1');
    expect(canonicalApiBaseUrl(withFragment.baseURL), 'https://api.example/v1');
    expect(
      canonicalApiBaseUrl(' HTTP://LOCALHOST:8080//v1?foo=bar#top '),
      'http://localhost:8080/v1',
    );
    expect(normalizedApiBaseUri('   '), isNull);
    expect(canonicalApiBaseUrl('   '), isNull);

    final baseUrlSource = File('lib/core/api_base_url.dart').readAsStringSync();
    expect(baseUrlSource, contains("import 'text_cleaning.dart';"));
    expect(
        baseUrlSource, contains('final trimmed = cleanNonEmptyText(value);'));
    expect(baseUrlSource, contains('if (trimmed == null) return null;'));
    expect(
      baseUrlSource,
      contains('cleanNonEmptyText(uri.host) == null'),
    );
    expect(baseUrlSource, contains('String _normalizedApiBasePath('));
    expect(baseUrlSource, contains("path.replaceAll(RegExp(r'/+'), '/')"));
    expect(baseUrlSource, contains('return Uri('));
    expect(baseUrlSource, contains('if (uri.hasPort)'));
    expect(baseUrlSource, contains('port: uri.port,'));
    expect(baseUrlSource, isNot(contains('removeFragment()')));
    expect(baseUrlSource, isNot(contains('value.trim()')));
    expect(baseUrlSource, isNot(contains('uri.host.isEmpty')));

    final apiModelSource = File('lib/core/api_models.dart').readAsStringSync();
    expect(
      apiModelSource,
      contains('cleanNonEmptyText(uri.host) == null'),
    );
    expect(apiModelSource, isNot(contains('uri.host.trim()')));
  });

  test('api config persists two step vision setting', () {
    final config = APIConfig.defaults.copyWith(enableTwoStepVision: true);
    final restored = APIConfig.fromJson(config.toJson());

    expect(restored.enableTwoStepVision, isTrue);
  });

  test('api config restores default model capabilities for older settings', () {
    final restored = APIConfig.fromJson({
      'baseURL': 'https://api.openai.com/v1',
      'visionModelName': 'gpt-4o-mini',
      'textModelName': 'gpt-4o-mini',
      'enableImageInput': 'true',
      'enableTwoStepVision': '1',
      'imageMaxWidth': '960',
      'imageCompressionQuality': '0.65',
      'temperature': '0.7',
      'maxTokens': '800',
      'timeout': '45',
    });

    expect(restored.capability('gpt-4o-mini').isMultimodal, isTrue);
    expect(restored.enableImageInput, isTrue);
    expect(restored.enableTwoStepVision, isTrue);
    expect(restored.imageMaxWidth, 960);
    expect(restored.imageCompressionQuality, 0.65);
    expect(restored.temperature, 0.7);
    expect(restored.maxTokens, 800);
    expect(restored.timeout, 45);
    expect(
      GenerateAPIReadiness(
        config: restored,
        hasAPIKey: true,
        capability: GenerateAPICapability.vision,
      ).isReady,
      isTrue,
    );
  });

  test('api config accepts snake case imported fields', () {
    final restored = APIConfig.fromJson({
      'base_url': ' https://proxy.example/v1 ',
      'vision_model_name': ' qwen-vl ',
      'text_model_name': ' qwen-chat ',
      'model_capabilities': {
        ' qwen-vl ': {'is_multimodal': 'yes', 'is_reasoning': 'true'},
        'gemini-flash': {'supports_vision': '1', 'reasoning': 'false'},
      },
      'enable_image_input': 'false',
      'enable_two_step_vision': '1',
      'image_max_width': '960',
      'image_compression_quality': '0.66',
      'max_tokens': '1800',
    });

    expect(restored.baseURL, 'https://proxy.example/v1');
    expect(restored.visionModelName, 'qwen-vl');
    expect(restored.textModelName, 'qwen-chat');
    expect(restored.capability('qwen-vl').isMultimodal, isTrue);
    expect(restored.capability('qwen-vl').isReasoning, isTrue);
    expect(restored.capability('gemini-flash').isMultimodal, isTrue);
    expect(restored.capability('gemini-flash').isReasoning, isFalse);
    expect(restored.enableImageInput, isFalse);
    expect(restored.enableTwoStepVision, isTrue);
    expect(restored.imageMaxWidth, 960);
    expect(restored.imageCompressionQuality, 0.66);
    expect(restored.maxTokens, 1800);
  });

  test('api config canonicalizes imported base urls on read', () {
    final restored = APIConfig.fromJson({
      'baseURL': ' HTTPS://PROXY.EXAMPLE/v1//#top ',
    });
    final invalid = APIConfig.fromJson({
      'baseURL': 'https://',
    });

    expect(restored.baseURL, 'https://proxy.example/v1');
    expect(invalid.baseURL, 'https://');
    expect(invalid.hasValidBaseUri, isFalse);
  });

  test('api config accepts common provider import aliases', () {
    final restored = APIConfig.fromJson({
      'endpoint': ' https://provider.example/api ',
      'imageModel': ' provider-vl ',
      'chatModel': ' provider-chat ',
      'capabilities': {
        'provider-vl': {
          'supported_inputs': ['text', 'image'],
        },
        'provider-chat': {
          'features': ['reasoning'],
        },
        'provider-aliased-vl': {
          'supports_image_input': 'yes',
          'reasoner': '1',
        },
      },
      'imageInputEnabled': 'yes',
      'extractTextBeforeReply': true,
      'maxImageWidth': '1440',
      'jpegQuality': '0.7',
      'temp': '0.4',
      'maxOutputTokens': '2200',
      'timeoutSeconds': '90',
    });

    expect(restored.baseURL, 'https://provider.example/api');
    expect(restored.visionModelName, 'provider-vl');
    expect(restored.textModelName, 'provider-chat');
    expect(restored.capability('provider-vl').isMultimodal, isTrue);
    expect(restored.capability('provider-chat').isReasoning, isTrue);
    expect(restored.capability('provider-aliased-vl').isMultimodal, isTrue);
    expect(restored.capability('provider-aliased-vl').isReasoning, isTrue);
    expect(restored.enableImageInput, isTrue);
    expect(restored.enableTwoStepVision, isTrue);
    expect(restored.imageMaxWidth, 1440);
    expect(restored.imageCompressionQuality, 0.7);
    expect(restored.temperature, 0.4);
    expect(restored.maxTokens, 2200);
    expect(restored.timeout, 90);
  });

  test('api config accepts wrapped exported provider settings', () {
    final restored = APIConfig.fromJson({
      'exportedAt': '2026-01-01T00:00:00Z',
      'apiSettings': {
        'endpoint': ' https://wrapped.example/v1 ',
        'visionModel': ' wrapped-vl ',
        'chatModel': ' wrapped-chat ',
        'capabilities': {
          'wrapped-vl': {
            'supported_inputs': ['text', 'image']
          },
          'wrapped-chat': {
            'features': ['reasoning']
          },
        },
        'imageInputEnabled': 'yes',
        'extractTextBeforeReply': 'true',
        'timeoutSeconds': '75',
      },
    });
    final topLevelWins = APIConfig.fromJson({
      'baseURL': 'https://top.example/v1',
      'apiSettings': {
        'baseURL': 'https://nested.example/v1',
        'chatModel': 'nested-chat',
      },
      'textModelName': 'top-chat',
    });
    final nestedSettings = APIConfig.fromJson({
      'settings': {
        'apiSettings': {
          'endpoint': 'https://deep.example/v1',
          'chatModel': 'deep-chat',
        },
      },
    });

    expect(restored.baseURL, 'https://wrapped.example/v1');
    expect(restored.visionModelName, 'wrapped-vl');
    expect(restored.textModelName, 'wrapped-chat');
    expect(restored.capability('wrapped-vl').isMultimodal, isTrue);
    expect(restored.capability('wrapped-chat').isReasoning, isTrue);
    expect(restored.enableImageInput, isTrue);
    expect(restored.enableTwoStepVision, isTrue);
    expect(restored.timeout, 75);
    expect(topLevelWins.baseURL, 'https://top.example/v1');
    expect(topLevelWins.textModelName, 'top-chat');
    expect(nestedSettings.baseURL, 'https://deep.example/v1');
    expect(nestedSettings.textModelName, 'deep-chat');
  });

  test('api config accepts list shaped model capability imports', () {
    final restored = APIConfig.fromJson({
      'visionModelName': 'qwen-vl',
      'modelCapabilities': [
        {
          'model_id': ' qwen-vl ',
          'is_multimodal': 'yes',
        },
        {
          'modelName': ' QWEN-VL ',
          'features': ['reasoning'],
        },
        {
          'model': 'provider-reasoner',
          'capabilities': {
            'supports_vision': '1',
            'reasoning': 'yes',
          },
        },
        'ignored',
        {
          'id': 'broken',
          42: 'bad-key',
        },
      ],
    });

    expect(restored.capability('qwen-vl').isMultimodal, isTrue);
    expect(restored.capability('qwen-vl').isReasoning, isTrue);
    expect(restored.capability('provider-reasoner').isMultimodal, isTrue);
    expect(restored.capability('provider-reasoner').isReasoning, isTrue);
    expect(restored.capability('broken').isMultimodal, isFalse);
    expect(restored.capability('gpt-4o-mini').isMultimodal, isTrue);
    expect(
      GenerateAPIReadiness(
        config: restored,
        hasAPIKey: true,
        capability: GenerateAPICapability.vision,
      ).isReady,
      isTrue,
    );
  });

  test('api config list capability imports accept model name aliases', () {
    final restored = APIConfig.fromJson({
      'model_capabilities': [
        {
          'model_name': 'provider-vl',
          'supported_inputs': ['text', 'image'],
        },
        {
          'modelName': 'provider-reasoner',
          'features': ['text', 'reasoning'],
        },
      ],
    });

    expect(restored.capability('provider-vl').isMultimodal, isTrue);
    expect(restored.capability('provider-reasoner').isReasoning, isTrue);
  });

  test('api config clamps migrated numeric fields to settings ranges', () {
    final tooHigh = APIConfig.fromJson({
      'imageMaxWidth': '9999',
      'imageCompressionQuality': '2',
      'temperature': '9',
      'maxTokens': '99999',
      'timeout': '999',
    });
    final tooLow = APIConfig.fromJson({
      'imageMaxWidth': '12',
      'imageCompressionQuality': '0.01',
      'temperature': '-1',
      'maxTokens': '10',
      'timeout': '1',
    });
    final padded = APIConfig.fromJson({
      'imageMaxWidth': ' 512 ',
      'imageCompressionQuality': ' 0.5 ',
      'temperature': ' 1.25 ',
      'maxTokens': ' 800 ',
      'timeout': ' 60 ',
    });

    expect(tooHigh.imageMaxWidth, APIConfig.imageMaxWidthMax);
    expect(
      tooHigh.imageCompressionQuality,
      APIConfig.imageCompressionQualityMax,
    );
    expect(tooHigh.temperature, APIConfig.temperatureMax);
    expect(tooHigh.maxTokens, APIConfig.maxTokensMax);
    expect(tooHigh.timeout, APIConfig.timeoutMax);
    expect(tooLow.imageMaxWidth, APIConfig.imageMaxWidthMin);
    expect(
      tooLow.imageCompressionQuality,
      APIConfig.imageCompressionQualityMin,
    );
    expect(tooLow.temperature, APIConfig.temperatureMin);
    expect(tooLow.maxTokens, APIConfig.maxTokensMin);
    expect(tooLow.timeout, APIConfig.timeoutMin);
    expect(padded.imageMaxWidth, 512);
    expect(padded.imageCompressionQuality, 0.5);
    expect(padded.temperature, 1.25);
    expect(padded.maxTokens, 800);
    expect(padded.timeout, 60);

    final scalarSource =
        File('lib/core/model_json_scalar_helpers.dart').readAsStringSync();
    expect(scalarSource, contains('String? _scalarTextValue(Object? raw)'));
    expect(scalarSource, contains('cleanNonEmptyText(raw?.toString())'));
    expect(scalarSource, isNot(contains('raw?.toString().trim()')));
    expect(scalarSource, isNot(contains('raw.toString().trim()')));
  });

  test('api config json writes cleaned bounded values', () {
    const config = APIConfig(
      baseURL: ' HTTPS://PROXY.EXAMPLE/v1//#top ',
      visionModelName: '未知',
      textModelName: '  qwen-chat  ',
      modelCapabilities: {
        ' qwen-vl ': ModelCapability(isMultimodal: true),
        '  ': ModelCapability(isMultimodal: true, isReasoning: true),
        ' provider-reasoner ': ModelCapability(isReasoning: true),
      },
      enableImageInput: true,
      enableTwoStepVision: true,
      imageMaxWidth: 9999,
      imageCompressionQuality: 2,
      temperature: -1,
      maxTokens: 99999,
      timeout: 1,
    );

    final json = config.toJson();
    final capabilities =
        Map<String, dynamic>.from(json['modelCapabilities'] as Map);
    final restored = APIConfig.fromJson(json);

    expect(json['baseURL'], 'https://proxy.example/v1');
    expect(json['visionModelName'], APIConfig.defaults.visionModelName);
    expect(json['textModelName'], 'qwen-chat');
    expect(capabilities.keys, containsAll(['qwen-vl', 'provider-reasoner']));
    expect(capabilities.keys, isNot(contains('')));
    expect(json['imageMaxWidth'], APIConfig.imageMaxWidthMax);
    expect(
      json['imageCompressionQuality'],
      APIConfig.imageCompressionQualityMax,
    );
    expect(json['temperature'], APIConfig.temperatureMin);
    expect(json['maxTokens'], APIConfig.maxTokensMax);
    expect(json['timeout'], APIConfig.timeoutMin);
    expect(restored.baseURL, 'https://proxy.example/v1');
    expect(restored.visionModelName, APIConfig.defaults.visionModelName);
    expect(restored.textModelName, 'qwen-chat');
    expect(restored.capability('qwen-vl').isMultimodal, isTrue);
    expect(restored.capability('provider-reasoner').isReasoning, isTrue);
    expect(restored.imageMaxWidth, APIConfig.imageMaxWidthMax);
    expect(
      restored.imageCompressionQuality,
      APIConfig.imageCompressionQualityMax,
    );
    expect(restored.temperature, APIConfig.temperatureMin);
    expect(restored.maxTokens, APIConfig.maxTokensMax);
    expect(restored.timeout, APIConfig.timeoutMin);

    final configJsonSource =
        File('lib/core/api_config_json.dart').readAsStringSync();
    expect(
      configJsonSource,
      contains('mergeCapability(capabilities, modelId, entry.value);'),
    );
  });

  test('api config explicit model capability overrides defaults', () {
    final restored = APIConfig.fromJson({
      'modelCapabilities': {
        ' GPT-4O-MINI ': {'isMultimodal': false, 'isReasoning': 'yes'},
        'bad-model': {'isMultimodal': true, 42: 'bad-key'},
        'string-vision-model': 'text,image',
        '  ': {'isMultimodal': true},
      },
    });

    expect(restored.capability('gpt-4o-mini').isMultimodal, isFalse);
    expect(restored.capability('gpt-4o-mini').isReasoning, isTrue);
    expect(restored.capability('bad-model').isMultimodal, isFalse);
    expect(restored.capability('string-vision-model').isMultimodal, isTrue);
  });

  test('api config map capability imports accept modality values', () {
    final restored = APIConfig.fromJson({
      'modelCapabilities': {
        'provider-vl': {
          'supported_inputs': ['text', 'image'],
        },
        'provider-map-vl': {
          'modalities': {
            'input_modalities': ['text', 'image'],
            'output_modalities': ['text'],
          },
        },
        'provider-reasoner': ['text', 'reasoning'],
        'provider-nested-vl': {
          'architecture': {
            'input_modalities': ['text', 'image'],
          },
        },
        'provider-nested-capabilities': {
          'capabilities': {
            'supported_inputs': ['text', 'vision'],
            'features': ['reasoning'],
          },
        },
        'plain-text': 'text',
        'provider-duplicate': {
          'supports_vision': 'yes',
        },
        ' PROVIDER-DUPLICATE ': {
          'features': ['reasoning'],
        },
      },
    });

    expect(restored.capability('provider-vl').isMultimodal, isTrue);
    expect(restored.capability('provider-map-vl').isMultimodal, isTrue);
    expect(restored.capability('provider-reasoner').isReasoning, isTrue);
    expect(restored.capability('provider-nested-vl').isMultimodal, isTrue);
    expect(restored.capability('provider-nested-capabilities').isMultimodal,
        isTrue);
    expect(restored.capability('provider-nested-capabilities').isReasoning,
        isTrue);
    expect(restored.capability('plain-text').isMultimodal, isFalse);
    expect(restored.capability('plain-text').isReasoning, isFalse);
    expect(restored.capability('provider-duplicate').isMultimodal, isTrue);
    expect(restored.capability('provider-duplicate').isReasoning, isTrue);
  });

  test('api config default comparison ignores capability map order', () {
    const textOnly = ModelCapability();
    const multimodal = ModelCapability(isMultimodal: true);
    final first = APIConfig.defaults.copyWith(modelCapabilities: const {
      'gpt-4o-mini': multimodal,
      'text-only': textOnly,
    });
    final reordered = APIConfig.defaults.copyWith(modelCapabilities: const {
      'text-only': textOnly,
      'gpt-4o-mini': multimodal,
    });
    final recased = APIConfig.defaults.copyWith(modelCapabilities: const {
      ' TEXT-ONLY ': textOnly,
      ' GPT-4O-MINI ': multimodal,
    });

    expect(first.toJson().toString(), isNot(reordered.toJson().toString()));
    expect(first.isEquivalentTo(reordered), isTrue);
    expect(first.isEquivalentTo(recased), isTrue);
    expect(APIConfig.defaults.hasDefaultValues, isTrue);
    expect(
      APIConfig.defaults
          .copyWith(baseURL: ' HTTPS://API.OPENAI.COM/v1/// ')
          .hasDefaultValues,
      isTrue,
    );
    expect(
      APIConfig.defaults
          .copyWith(baseURL: 'https://api.openai.com/v1/#fragment')
          .hasDefaultValues,
      isTrue,
    );
    expect(
      APIConfig.defaults.copyWith(
        modelCapabilities: const {
          ' GPT-4O-MINI ': multimodal,
        },
      ).hasDefaultValues,
      isTrue,
    );
    expect(
      APIConfig.defaults.copyWith(
          modelCapabilities: const {'gpt-4o-mini': textOnly}).hasDefaultValues,
      isFalse,
    );
    expect(
      APIConfig.defaults
          .copyWith(
            visionModelName: ' GPT-4O-MINI ',
            textModelName: ' gPt-4o-MINI ',
          )
          .hasDefaultValues,
      isTrue,
    );
    expect(
      APIConfig.defaults
          .copyWith(baseURL: ' ')
          .isEquivalentTo(APIConfig.defaults.copyWith(baseURL: '')),
      isTrue,
    );

    final modelSource = File('lib/core/api_models.dart').readAsStringSync();
    expect(
      modelSource,
      contains(
          '_apiConfigModelIdsMatch(visionModelName, other.visionModelName)'),
    );
    expect(
      modelSource,
      contains('_apiConfigModelIdsMatch(textModelName, other.textModelName)'),
    );
    expect(modelSource,
        isNot(contains('visionModelName == other.visionModelName')));
    expect(
        modelSource, isNot(contains('textModelName == other.textModelName')));

    final comparisonSource =
        File('lib/core/api_config_comparison.dart').readAsStringSync();
    expect(
      comparisonSource,
      contains('return cleanNonEmptyText(left) == cleanNonEmptyText(right);'),
    );
    expect(comparisonSource, contains('return modelIdsEqual(left, right);'));
    expect(comparisonSource, isNot(contains('left.trim()')));
    expect(comparisonSource, isNot(contains('right.trim()')));
  });

  test('api config model capability lookup normalizes case and whitespace', () {
    final config = APIConfig.defaults.copyWith(
      visionModelName: ' QWEN2.5-VL-72B ',
      modelCapabilities: const {
        'qwen2.5-vl-72b': ModelCapability(isMultimodal: true),
      },
    );
    final readiness = GenerateAPIReadiness(
      config: config,
      hasAPIKey: true,
      capability: GenerateAPICapability.vision,
    );

    expect(config.capability(' QWEN2.5-VL-72B ').isMultimodal, isTrue);
    expect(readiness.isReady, isTrue);
  });

  test('appearance settings preserve iOS defaults and options', () {
    final restored = AppearanceSettings.fromJson(const {});
    final legacy = AppearanceSettings.fromJson({
      'isBackgroundBlurEnabled': 'off',
      'backgroundBlurRadius': '18.5',
      'backgroundDimOpacity': '0.35',
    });
    final bounded = AppearanceSettings.fromJson({
      'backgroundBlurRadius': 999,
      'backgroundDimOpacity': -2,
      'glassTintStrength': '9',
      'glassBorderStrength': '-1',
    });

    expect(AppearanceSettings.defaults.isBackgroundBlurEnabled, isTrue);
    expect(AppearanceSettings.defaults.backgroundBlurRadius, 14);
    expect(AppearanceSettings.backgroundBlurRadiusMax, 28);
    expect(AppearanceSettings.backgroundDimOpacityMax, 0.42);
    expect(AppearanceSettings.glassTintStrengthMin, 0.35);
    expect(AppearanceSettings.glassTintStrengthMax, 1.65);
    expect(AppearanceSettings.glassBorderStrengthMin, 0.45);
    expect(AppearanceSettings.glassBorderStrengthMax, 1.45);
    expect(restored.isBackgroundBlurEnabled, isTrue);
    expect(restored.backgroundBlurRadius, 14);
    expect(legacy.isBackgroundBlurEnabled, isFalse);
    expect(legacy.backgroundBlurRadius, 18.5);
    expect(legacy.backgroundDimOpacity, 0.35);
    expect(bounded.backgroundBlurRadius,
        AppearanceSettings.backgroundBlurRadiusMax);
    expect(bounded.backgroundDimOpacity,
        AppearanceSettings.backgroundDimOpacityMin);
    expect(bounded.glassTintStrength, AppearanceSettings.glassTintStrengthMax);
    expect(
        bounded.glassBorderStrength, AppearanceSettings.glassBorderStrengthMin);
    expect(
      const AppearanceSettings(backgroundBlurRadius: 22)
          .withBackgroundBlurEnabled(false)
          .backgroundBlurRadius,
      22,
    );
    expect(
      const AppearanceSettings(
              isBackgroundBlurEnabled: false, backgroundBlurRadius: 22)
          .withBackgroundBlurEnabled(true)
          .backgroundBlurRadius,
      22,
    );
    expect(
      app_shell.AppearancePresentation(
              const AppearanceSettings(textSizeName: 'comfortable'))
          .textScale,
      greaterThan(1.0),
    );
    expect(
      app_shell.AppearancePresentation(
              const AppearanceSettings(textSizeName: 'large'))
          .textScale,
      greaterThan(app_shell.AppearancePresentation(
              const AppearanceSettings(textSizeName: 'comfortable'))
          .textScale),
    );
    expect(
      app_shell.AppearancePresentation(
              const AppearanceSettings(accentColorName: 'sunset'))
          .accentColor,
      app_shell.AppearancePresentation(
              const AppearanceSettings(accentColorName: 'amber'))
          .accentColor,
    );
    expect(const AppearanceSettings().backgroundSummary, '默认玻璃背景');
    expect(
      const AppearanceSettings(customBackgroundPath: '  /tmp/bg.jpg  ')
          .backgroundSummary,
      '自定义背景',
    );
    expect(
      const AppearanceSettings(customBackgroundPath: '   ').hasCustomBackground,
      isFalse,
    );

    final shell = File('lib/widgets/settings_cards.dart').readAsStringSync();
    final appearanceStart = shell.indexOf('class AppearanceSettingsCard');
    expect(appearanceStart, isNonNegative);
    final appearanceCard = shell.substring(appearanceStart);

    for (final option in const [
      "('ocean', '海蓝')",
      "('mint', '薄荷')",
      "('sunset', '日落')",
      "('rose', '玫瑰')",
      "('violet', '紫罗兰')",
      "('compact', '紧凑')",
      "('standard', '标准')",
      "('comfortable', '舒适')",
      "('large', '大字')",
    ]) {
      expect(appearanceCard, contains(option));
    }
    expect(appearanceCard, isNot(contains("('rose', '玫红')")));
  });

  test('appearance settings accept snake case imported fields', () {
    final restored = AppearanceSettings.fromJson({
      'is_background_blur_enabled': 'false',
      'background_blur_radius': '22',
      'background_dim_opacity': '0.33',
      'glass_tint_strength': '1.2',
      'glass_border_strength': '0.8',
      'accent_color_name': 'rose',
      'text_size_name': 'large',
      'custom_background_path': '/tmp/background.jpg',
    });

    expect(restored.isBackgroundBlurEnabled, isFalse);
    expect(restored.backgroundBlurRadius, 22);
    expect(restored.backgroundDimOpacity, 0.33);
    expect(restored.glassTintStrength, 1.2);
    expect(restored.glassBorderStrength, 0.8);
    expect(restored.accentColorName, 'rose');
    expect(restored.textSizeName, 'large');
    expect(restored.customBackgroundPath, '/tmp/background.jpg');
  });

  test('appearance settings accept common exported aliases', () {
    final restored = AppearanceSettings.fromJson({
      'blurEnabled': 'no',
      'blurRadius': '21',
      'overlayOpacity': '0.32',
      'glassTint': '1.25',
      'borderStrength': '0.9',
      'themeColor': 'mint',
      'fontSizeName': 'comfortable',
      'backgroundImagePath': ' /tmp/exported-bg.jpg ',
    });

    expect(restored.isBackgroundBlurEnabled, isFalse);
    expect(restored.backgroundBlurRadius, 21);
    expect(restored.backgroundDimOpacity, 0.32);
    expect(restored.glassTintStrength, 1.25);
    expect(restored.glassBorderStrength, 0.9);
    expect(restored.accentColorName, 'mint');
    expect(restored.textSizeName, 'comfortable');
    expect(restored.customBackgroundPath, '/tmp/exported-bg.jpg');
  });

  test('appearance settings accepts wrapped exported preferences', () {
    final restored = AppearanceSettings.fromJson({
      'exportedAt': '2026-01-01T00:00:00Z',
      'appearanceSettings': {
        'blurEnabled': 'off',
        'blurRadius': '23',
        'overlayOpacity': '0.31',
        'glassTint': '1.3',
        'borderStrength': '1.1',
        'themeColor': 'sunset',
        'fontSizeName': 'large',
        'backgroundImagePath': ' /tmp/wrapped-bg.jpg ',
      },
    });
    final topLevelWins = AppearanceSettings.fromJson({
      'accentColorName': 'rose',
      'appearanceSettings': {
        'accentColorName': 'mint',
        'textSizeName': 'large',
      },
      'textSizeName': 'compact',
    });
    final nestedSettings = AppearanceSettings.fromJson({
      'settings': {
        'appearanceSettings': {
          'themeColor': 'mint',
          'fontSizeName': 'comfortable',
        },
      },
    });

    expect(restored.isBackgroundBlurEnabled, isFalse);
    expect(restored.backgroundBlurRadius, 23);
    expect(restored.backgroundDimOpacity, 0.31);
    expect(restored.glassTintStrength, 1.3);
    expect(restored.glassBorderStrength, 1.1);
    expect(restored.accentColorName, 'sunset');
    expect(restored.textSizeName, 'large');
    expect(restored.customBackgroundPath, '/tmp/wrapped-bg.jpg');
    expect(topLevelWins.accentColorName, 'rose');
    expect(topLevelWins.textSizeName, 'compact');
    expect(nestedSettings.accentColorName, 'mint');
    expect(nestedSettings.textSizeName, 'comfortable');
  });

  test('appearance settings trim names and ignore blank imported options', () {
    final trimmed = AppearanceSettings.fromJson({
      'accentColorName': '  rose  ',
      'textSizeName': '  comfortable  ',
    });
    final blank = AppearanceSettings.fromJson({
      'accentColorName': '   ',
      'textSizeName': '',
    });

    expect(trimmed.accentColorName, 'rose');
    expect(trimmed.textSizeName, 'comfortable');
    expect(blank.accentColorName, AppearanceSettings.defaults.accentColorName);
    expect(blank.textSizeName, AppearanceSettings.defaults.textSizeName);
  });

  test('appearance settings json writes cleaned bounded values', () {
    const settings = AppearanceSettings(
      isBackgroundBlurEnabled: false,
      backgroundBlurRadius: 999,
      backgroundDimOpacity: -2,
      glassTintStrength: 9,
      glassBorderStrength: -1,
      accentColorName: '未知',
      textSizeName: '  comfortable  ',
      customBackgroundPath: '未知',
    );

    final json = settings.toJson();
    final restored = AppearanceSettings.fromJson(json);

    expect(json['isBackgroundBlurEnabled'], isFalse);
    expect(
      json['backgroundBlurRadius'],
      AppearanceSettings.backgroundBlurRadiusMax,
    );
    expect(
      json['backgroundDimOpacity'],
      AppearanceSettings.backgroundDimOpacityMin,
    );
    expect(
      json['glassTintStrength'],
      AppearanceSettings.glassTintStrengthMax,
    );
    expect(
      json['glassBorderStrength'],
      AppearanceSettings.glassBorderStrengthMin,
    );
    expect(
        json['accentColorName'], AppearanceSettings.defaults.accentColorName);
    expect(json['textSizeName'], 'comfortable');
    expect(json['customBackgroundPath'], isNull);
    expect(restored.isBackgroundBlurEnabled, isFalse);
    expect(
      restored.backgroundBlurRadius,
      AppearanceSettings.backgroundBlurRadiusMax,
    );
    expect(
      restored.backgroundDimOpacity,
      AppearanceSettings.backgroundDimOpacityMin,
    );
    expect(restored.glassTintStrength, AppearanceSettings.glassTintStrengthMax);
    expect(
      restored.glassBorderStrength,
      AppearanceSettings.glassBorderStrengthMin,
    );
    expect(
        restored.accentColorName, AppearanceSettings.defaults.accentColorName);
    expect(restored.textSizeName, 'comfortable');
    expect(restored.customBackgroundPath, isNull);
  });

  testWidgets('appearance blur slider is disabled when blur is off like iOS',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final changed = <AppearanceSettings>[];

    await tester.pumpWidget(ProviderScope(
      child: MaterialApp(
        home: Scaffold(
          body: app_shell.AppearanceSettingsCard(
            settings: const AppearanceSettings(
              isBackgroundBlurEnabled: false,
              backgroundBlurRadius: 22,
            ),
            onChanged: (settings) async => changed.add(settings),
            onImport: (_) async {},
            onResetCustomBackground: () async {},
            onResetPreferences: () async {},
          ),
        ),
      ),
    ));

    expect(tester.widget<Slider>(find.byType(Slider).first).onChanged, isNull);

    await tester.pumpWidget(ProviderScope(
      child: MaterialApp(
        home: Scaffold(
          body: app_shell.AppearanceSettingsCard(
            settings: const AppearanceSettings(
              isBackgroundBlurEnabled: true,
              backgroundBlurRadius: 22,
            ),
            onChanged: (settings) async => changed.add(settings),
            onImport: (_) async {},
            onResetCustomBackground: () async {},
            onResetPreferences: () async {},
          ),
        ),
      ),
    ));

    expect(
        tester.widget<Slider>(find.byType(Slider).first).onChanged, isNotNull);
  });

  testWidgets(
      'appearance card separates background reset from preference reset',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    var didResetBackground = false;
    var didResetPreferences = false;

    await tester.pumpWidget(ProviderScope(
      child: MaterialApp(
        home: Scaffold(
          body: app_shell.AppearanceSettingsCard(
            settings: const AppearanceSettings(
              customBackgroundPath: '/tmp/custom-background.jpg',
              accentColorName: 'rose',
              textSizeName: 'large',
            ),
            onChanged: (_) async {},
            onImport: (_) async {},
            onResetCustomBackground: () async => didResetBackground = true,
            onResetPreferences: () async => didResetPreferences = true,
          ),
        ),
      ),
    ));

    await tester.tap(find.text('默认背景'));
    await tester.tap(find.text('重置个性化'));

    expect(didResetBackground, isTrue);
    expect(didResetPreferences, isTrue);
  });

  test('appearance background import checks context before saving late picks',
      () {
    final source = File('lib/widgets/settings_cards.dart').readAsStringSync();
    final cardStart = source.indexOf('class AppearanceSettingsCard');
    final pickerStart = source.indexOf(
      'await ImagePicker().pickImage(source: ImageSource.gallery)',
      cardStart,
    );
    final importStart =
        source.indexOf('await onImport(picked.path)', pickerStart);
    final pickerReturnBlock = source.substring(pickerStart, importStart);

    expect(cardStart, isNonNegative);
    expect(pickerStart, greaterThan(cardStart));
    expect(importStart, greaterThan(pickerStart));
    expect(pickerReturnBlock, contains('if (!context.mounted) return;'));
  });

  test('appearance feedback filters keep messages page-local like iOS', () {
    expect(app_shell.isAppearanceStatusMessage('背景已导入'), isTrue);
    expect(app_shell.isAppearanceStatusMessage('已恢复默认背景'), isTrue);
    expect(app_shell.isAppearanceErrorMessage('背景保存失败：无法读取所选图片'), isTrue);
    expect(app_shell.cleanFeedbackMessage('  背景已导入  '), '背景已导入');
    expect(app_shell.cleanFeedbackMessage('   '), isNull);

    expect(app_shell.isAppearanceStatusMessage('配置已保存'), isFalse);
    expect(app_shell.isAppearanceStatusMessage('已复制'), isFalse);
    expect(app_shell.isAppearanceErrorMessage('复制失败：剪贴板不可用'), isFalse);
    expect(app_shell.isAppearanceErrorMessage('API Base URL 格式不正确'), isFalse);
  });

  test('owned transient image path helper matches Android cache prefixes', () {
    expect(app_shell.cleanImagePathInput('  /tmp/chat.jpg  '), '/tmp/chat.jpg');
    expect(app_shell.cleanImagePathInput('   '), isNull);
    expect(app_shell.hasUsableImagePath('/tmp/chat.jpg'), isTrue);
    expect(app_shell.hasUsableImagePath('   '), isFalse);
    expect(
      app_shell
          .isOwnedTransientImagePath('  /tmp/clipboard-image-moment.img  '),
      isTrue,
    );
    expect(
      app_shell.isOwnedTransientImagePath('/tmp/floating-capture-chat.jpg'),
      isTrue,
    );
    expect(
      app_shell
          .isOwnedTransientImagePath('/tmp/accessibility-capture-screen.jpg'),
      isTrue,
    );
    expect(
      app_shell.isOwnedTransientImagePath('/tmp/user-picked-moment.jpg'),
      isFalse,
    );
    expect(app_shell.isOwnedTransientImagePath('/'), isFalse);
    expect(app_shell.isOwnedTransientImagePath('/tmp/'), isFalse);
    expect(app_shell.isOwnedTransientImagePath(null), isFalse);

    final source = File('lib/core/app_feedback.dart').readAsStringSync();
    expect(source, contains("import 'text_cleaning.dart';"));
    expect(source, contains('cleanImagePathInput(String? path)'));
    expect(source, contains('=> cleanNonEmptyText(path);'));
    expect(source, contains('String? imagePathFileName(String? path)'));
    expect(source, contains('if (segments.isEmpty) return null;'));
    expect(source, isNot(contains('final trimmed = path?.trim();')));
  });

  test('owned file cleaner shares image path cleaning rules', () async {
    final source = File('lib/core/owned_file_cleaner.dart').readAsStringSync();
    final tempDir =
        await Directory.systemTemp.createTemp('owned-cleaner-test-');
    final supportDir =
        await Directory.systemTemp.createTemp('owned-support-test-');

    try {
      final cleaner = OwnedFileCleaner(
        supportDirectoryProvider: () async => supportDir,
        temporaryDirectoryProvider: () async => tempDir,
      );

      expect(await cleaner.isOwnedTransientImagePath('/'), isFalse);
      expect(await cleaner.isOwnedCustomBackgroundPath('/'), isFalse);
      await cleaner.deleteOwnedTransientImageFile('/');
      await cleaner.deleteCustomBackground('/');

      expect(source, contains("import 'app_feedback.dart';"));
      expect(
          source, contains('final cleanedPath = cleanImagePathInput(path);'));
      expect(source, contains('final name = imagePathFileName(cleanedPath);'));
      expect(source, contains('await _deleteFile(cleanedPath!);'));
      expect(source,
          contains('final normalizedPath = cleanImagePathInput(path);'));
      expect(
        source,
        contains(
            'final normalizedDirectory = cleanImagePathInput(directoryPath);'),
      );
      expect(source, isNot(contains('path == null || path.trim().isEmpty')));
      expect(source, isNot(contains('pathSegments.last')));
    } finally {
      if (await tempDir.exists()) await tempDir.delete(recursive: true);
      if (await supportDir.exists()) await supportDir.delete(recursive: true);
    }
  });

  test('screenshot and moment previews show complete screenshots like iOS', () {
    final source =
        File('lib/widgets/generate_image_shell.dart').readAsStringSync();
    final momentSource =
        File('lib/screens/moment_profile_screen.dart').readAsStringSync();
    final imageShellStart = source.indexOf('class GenerateImageShell');
    final imageShellPreviewEnd =
        source.indexOf("const SectionHeader('聊天风格'", imageShellStart);
    final momentStart = momentSource.indexOf('class MomentProfileScreen');
    final momentPreviewEnd =
        momentSource.indexOf('PersonProfilePickerCard(', momentStart);

    expect(imageShellStart, isNonNegative);
    expect(imageShellPreviewEnd, greaterThan(imageShellStart));
    expect(momentStart, isNonNegative);
    expect(momentPreviewEnd, greaterThan(momentStart));

    final imagePreview =
        source.substring(imageShellStart, imageShellPreviewEnd);
    final momentPreview = momentSource.substring(momentStart, momentPreviewEnd);

    expect(imagePreview, contains('Image.file(File(imagePath!)'));
    expect(imagePreview, contains('fit: BoxFit.contain'));
    expect(imagePreview, isNot(contains('fit: BoxFit.cover')));
    expect(momentPreview, contains('Image.file(File(path!)'));
    expect(momentPreview, contains('fit: BoxFit.contain'));
    expect(momentPreview, isNot(contains('fit: BoxFit.cover')));
  });

  test('screenshot page discards replaced local transient clipboard images',
      () {
    final source =
        File('lib/screens/image_generation_screens.dart').readAsStringSync();
    final screenStart = source.indexOf('class _ImageInputScreenState');
    final disposeStart = source.indexOf('void dispose()', screenStart);
    final buildStart = source.indexOf('Widget build(', disposeStart);
    final pickStart = source.indexOf('Future<void> _pick() async', buildStart);
    final readStart =
        source.indexOf('Future<void> _readClipboardImage() async', pickStart);
    final sharedStart =
        source.indexOf('void _schedulePendingSharedImage', readStart);

    expect(screenStart, isNonNegative);
    expect(disposeStart, isNonNegative);
    expect(buildStart, greaterThan(disposeStart));
    expect(pickStart, greaterThan(buildStart));
    expect(readStart, greaterThan(pickStart));
    expect(sharedStart, greaterThan(readStart));

    final disposeBlock = source.substring(disposeStart, buildStart);
    expect(disposeBlock, contains('isOwnedTransientImagePath(path)'));
    expect(disposeBlock, contains('discardTransientImagePath(path)'));

    final clearBlock = source.substring(buildStart, pickStart);
    expect(clearBlock, contains('final path = imagePath'));
    expect(clearBlock, contains('isOwnedTransientImagePath(path)'));
    expect(clearBlock, contains('discardTransientImagePath(path)'));

    final pickBlock = source.substring(pickStart, readStart);
    expect(pickBlock, contains('final previousPath = imagePath'));
    expect(pickBlock, contains('previousPath != picked.path'));
    expect(pickBlock, contains('isOwnedTransientImagePath(previousPath)'));
    expect(pickBlock, contains('discardTransientImagePath(previousPath)'));

    final readBlock = source.substring(readStart, sharedStart);
    expect(readBlock, contains('final previousPath = imagePath'));
    expect(readBlock, contains('previousPath != path'));
    expect(readBlock, contains('isOwnedTransientImagePath(previousPath)'));
    expect(readBlock, contains('discardTransientImagePath(previousPath)'));

    final sharedEnd =
        source.indexOf('void _scheduleClipboardFeedbackReset', sharedStart);
    expect(sharedEnd, greaterThan(sharedStart));
    final sharedBlock = source.substring(sharedStart, sharedEnd);
    expect(sharedBlock, contains('final previousPath = imagePath'));
    expect(sharedBlock, contains('previousPath != sharedPath'));
    expect(sharedBlock, contains('isOwnedTransientImagePath(previousPath)'));
    expect(sharedBlock, contains('discardTransientImagePath(previousPath)'));
  });

  test('image generation screens use cleaned paths at input boundaries', () {
    final source =
        File('lib/screens/image_generation_screens.dart').readAsStringSync();
    final momentSource =
        File('lib/screens/moment_profile_screen.dart').readAsStringSync();
    final screenStart = source.indexOf('class _ImageInputScreenState');
    final quickStart = source.indexOf('class QuickReplyScreen');
    final momentReadStart =
        momentSource.indexOf('Future<void> _readClipboardImage() async');
    final momentReadEnd = momentSource.indexOf(
        'void _clearClipboardReadFeedback', momentReadStart);

    expect(screenStart, isNonNegative);
    expect(quickStart, greaterThan(screenStart));
    expect(momentReadStart, isNonNegative);
    expect(momentReadEnd, greaterThan(momentReadStart));

    final imageScreenBlock = source.substring(screenStart, quickStart);
    expect(
      imageScreenBlock,
      contains(
          'final restoredImagePath = cleanImagePathInput(app.currentImagePath);'),
    );
    expect(imageScreenBlock, isNot(contains('restoredImagePath.isNotEmpty')));
    expect(
      imageScreenBlock,
      contains('final submitImagePath = cleanImagePathInput(imagePath);'),
    );
    expect(
      imageScreenBlock,
      contains(
        'final path =\n          cleanImagePathInput(await FloatingCaptureBridge.readClipboardImage());',
      ),
    );
    expect(
      imageScreenBlock,
      contains(
        'final sharedPath =\n          cleanImagePathInput(controller.consumeSharedImagePath());',
      ),
    );
    expect(imageScreenBlock, contains('imagePath: submitImagePath,'));
    expect(imageScreenBlock, contains('onGenerate: submitImagePath == null'));
    expect(imageScreenBlock,
        contains('app.generateImage(\n                submitImagePath,'));
    expect(
        imageScreenBlock, isNot(contains('imagePath == null || app.isBusy')));

    final quickBlock = source.substring(quickStart);
    expect(
      quickBlock,
      contains(
        'final submitImagePath = cleanImagePathInput(app.quickImagePath);',
      ),
    );
    expect(quickBlock, contains('imagePath: submitImagePath,'));
    expect(quickBlock, contains('onGenerate: submitImagePath == null'));
    expect(quickBlock,
        contains('app.generateImage(\n                submitImagePath,'));
    expect(
        quickBlock, contains('final cleanedPath = cleanImagePathInput(path);'));
    expect(quickBlock,
        contains('app.setQuickImagePath(cleanedPath, autoGenerate: true);'));
    expect(
      quickBlock,
      contains(
        'final path =\n          cleanImagePathInput(await FloatingCaptureBridge.readClipboardImage());',
      ),
    );
    expect(quickBlock,
        isNot(contains('app.quickImagePath == null || app.isBusy')));

    final momentReadBlock =
        momentSource.substring(momentReadStart, momentReadEnd);
    expect(
      momentReadBlock,
      contains(
        'final clipboardPath =\n          cleanImagePathInput(await FloatingCaptureBridge.readClipboardImage());',
      ),
    );
    expect(momentReadBlock, isNot(contains('clipboardPath.isNotEmpty')));
  });

  test('transient UI feedback timers share reset helper', () {
    final helperSource =
        File('lib/core/transient_feedback_timer.dart').readAsStringSync();

    expect(helperSource, contains('const defaultTransientFeedbackDuration'));
    expect(helperSource, contains('Timer scheduleTransientFeedbackReset('));
    expect(helperSource, contains('if (isMounted()) reset();'));

    for (final path in [
      'lib/screens/api_settings_screen.dart',
      'lib/screens/floating_guide_screen.dart',
      'lib/screens/history_detail_screen.dart',
      'lib/screens/image_generation_screens.dart',
      'lib/screens/moment_profile_screen.dart',
      'lib/screens/personalization_screen.dart',
      'lib/screens/profile_editor_screen.dart',
      'lib/screens/profile_screens.dart',
      'lib/screens/text_input_screen.dart',
    ]) {
      final source = File(path).readAsStringSync();

      expect(
        source,
        contains("import '../core/transient_feedback_timer.dart';"),
        reason: path,
      );
      expect(source, contains('scheduleTransientFeedbackReset('), reason: path);
      expect(
          source,
          isNot(matches(
              r'Timer\(const Duration\(milliseconds: (1200|1300|1400|1500|1600|1800)\), \(\)')),
          reason: path);
    }
  });

  testWidgets('appearance card shows scoped background import feedback',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(ProviderScope(
      child: MaterialApp(
        home: Scaffold(
          body: app_shell.AppearanceSettingsCard(
            settings: AppearanceSettings.defaults,
            statusMessage: '背景已导入',
            errorMessage: '背景保存失败：无法读取所选图片',
            onChanged: (_) async {},
            onImport: (_) async {},
            onResetCustomBackground: () async {},
            onResetPreferences: () async {},
          ),
        ),
      ),
    ));

    expect(find.text('背景已导入'), findsOneWidget);
    expect(find.text('背景保存失败：无法读取所选图片'), findsOneWidget);
  });

  test('screenshot generation header copy stays separate from moments copy',
      () {
    final normal =
        app_shell.GenerateImageShellHeaderCopy.forMode(isQuickReply: false);
    final quick =
        app_shell.GenerateImageShellHeaderCopy.forMode(isQuickReply: true);

    expect(normal.title, '从聊天截图生成回复');
    expect(normal.detail, contains('候选回复'));
    expect(normal.detail, isNot(contains('朋友圈')));
    expect(quick.title, '用当前截图快速回复');
    expect(quick.detail, contains('原聊天 App'));
    expect(quick.detail, isNot(contains('朋友圈')));
    expect(
      app_shell.MomentProfileHeaderCopy.defaultCopy.title,
      '用朋友圈完善人物库',
    );
    expect(
      app_shell.MomentProfileHeaderCopy.defaultCopy.detail,
      contains('不做人脸或真实身份识别'),
    );
  });

  test('local store ignores corrupt history and profile data like iOS stores',
      () async {
    SharedPreferences.setMockInitialValues({
      'generationHistory': '{not json',
      'personProfiles': '[{"confidence":"0.8"}]',
    });
    final store = LocalStore();

    expect(await store.loadHistory(), isEmpty);
    expect(await store.loadProfiles(), isEmpty);
  });

  test('local store falls back from corrupt api config safely', () async {
    SharedPreferences.setMockInitialValues({
      'apiConfig': '{not json',
    });

    expect(await LocalStore().loadConfig(), APIConfig.defaults);

    SharedPreferences.setMockInitialValues({
      'apiConfig': jsonEncode({
        'modelCapabilities': {
          'broken': 'not a map',
        },
      }),
    });

    final loaded = await LocalStore().loadConfig();
    expect(loaded.baseURL, APIConfig.defaults.baseURL);
    expect(loaded.capability('gpt-4o-mini').isMultimodal, isTrue);
    expect(loaded.capability('broken').isMultimodal, isFalse);
  });

  test('local store canonicalizes legacy api base url on load', () async {
    SharedPreferences.setMockInitialValues({
      'apiConfig': jsonEncode({
        'baseURL': ' HTTPS://PROXY.EXAMPLE/v1//#top ',
      }),
    });

    final loaded = await LocalStore().loadConfig();

    expect(loaded.baseURL, 'https://proxy.example/v1');
  });

  test('local store keeps valid records when neighbors are corrupt', () async {
    final validHistory = GenerationRecord(
      inputType: ChatInputType.text,
      selectedStyleName: '未知',
      replies: [
        ReplySuggestion(styleLabel: '自然', text: '收到', reason: '测试'),
      ],
      createdAt: DateTime(2026, 1, 2),
    );
    final validProfile = PersonProfile(
      displayName: '小林',
      updatedAt: DateTime(2026, 1, 2),
    );
    SharedPreferences.setMockInitialValues({
      'generationHistory': jsonEncode([
        validHistory.toJson(),
        {'inputType': 'text', 'replies': 'bad'},
      ]),
      'personProfiles': jsonEncode([
        validProfile.toJson(),
        {
          'aliases': ['坏画像'],
          'confidence': '0.7'
        },
      ]),
    });
    final store = LocalStore();

    final history = await store.loadHistory();
    final profiles = await store.loadProfiles();

    expect(history, hasLength(1));
    expect(history.first.replies.single.text, '收到');
    expect(profiles, hasLength(1));
    expect(profiles.single.displayName, '小林');
  });

  test('local store accepts map shaped history and profile exports', () async {
    SharedPreferences.setMockInitialValues({
      'generationHistory': jsonEncode({
        'history-old': {
          'inputType': 'text',
          'style': '自然',
          'replies': [
            {'text': '早一点', 'styleLabel': '自然'}
          ],
          'createdAt': '2026-01-01T00:00:00.000',
        },
        'history-new': {
          'inputType': 'image',
          'style': '松弛',
          'replies': [
            {'text': '晚一点', 'styleLabel': '松弛'}
          ],
          'createdAt': '2026-01-02T00:00:00.000',
        },
        'metadata': {'count': 2},
      }),
      'personProfiles': jsonEncode({
        'profile-old': {
          'displayName': '早一点',
          'updatedAt': '2026-01-01T00:00:00.000',
        },
        'profile-new': {
          'displayName': '晚一点',
          'updatedAt': '2026-01-02T00:00:00.000',
        },
        'bad-profile': {'confidence': '0.7'},
      }),
    });
    final store = LocalStore();

    final history = await store.loadHistory();
    final profiles = await store.loadProfiles();

    expect(history.map((record) => record.id), ['history-new', 'history-old']);
    expect(history.map((record) => record.replies.single.text), ['晚一点', '早一点']);
    expect(
        profiles.map((profile) => profile.id), ['profile-new', 'profile-old']);
    expect(profiles.map((profile) => profile.displayName), ['晚一点', '早一点']);
  });

  test('local store accepts wrapped history and profile collection exports',
      () async {
    SharedPreferences.setMockInitialValues({
      'generationHistory': jsonEncode({
        'exportedAt': '2026-01-03T00:00:00.000',
        'data': {
          'history': [
            {
              'historyRecordId': 'wrapped-history-old',
              'inputType': 'text',
              'style': '自然',
              'replies': [
                {'text': '先早点说', 'styleLabel': '自然'}
              ],
              'createdAt': '2026-01-01T00:00:00.000',
            },
            jsonEncode({
              'historyRecordId': 'wrapped-history-new',
              'inputType': 'image',
              'style': '松弛',
              'replies': [
                {'text': '那就晚点见', 'styleLabel': '松弛'}
              ],
              'createdAt': '2026-01-02T00:00:00.000',
            }),
          ],
        },
      }),
      'personProfiles': jsonEncode({
        'payload': {
          'people': [
            {
              'profileId': 'wrapped-profile-old',
              'name': '早一点',
              'updatedAt': '2026-01-01T00:00:00.000',
            },
            jsonEncode({
              'profileId': 'wrapped-profile-new',
              'name': '晚一点',
              'updatedAt': '2026-01-02T00:00:00.000',
            }),
          ],
        },
      }),
    });
    final store = LocalStore();

    final history = await store.loadHistory();
    final profiles = await store.loadProfiles();

    expect(history.map((record) => record.id), [
      'wrapped-history-new',
      'wrapped-history-old',
    ]);
    expect(history.map((record) => record.replies.single.text), [
      '那就晚点见',
      '先早点说',
    ]);
    expect(profiles.map((profile) => profile.id), [
      'wrapped-profile-new',
      'wrapped-profile-old',
    ]);
    expect(profiles.map((profile) => profile.displayName), ['晚一点', '早一点']);
  });

  test('local store caps migrated history and profiles on load like iOS',
      () async {
    final start = DateTime(2026, 1, 1);
    final history = List.generate(
      105,
      (index) => GenerationRecord(
        id: 'history-$index',
        inputType: ChatInputType.text,
        selectedStyleName: '自然',
        replies: [
          ReplySuggestion(styleLabel: '自然', text: '回复$index', reason: '测试'),
        ],
        createdAt: start.add(Duration(minutes: index)),
      ).toJson(),
    );
    final profiles = List.generate(
      55,
      (index) => PersonProfile(
        id: 'profile-$index',
        displayName: '人物$index',
        createdAt: start.add(Duration(minutes: index)),
        updatedAt: start.add(Duration(minutes: index)),
      ).toJson(),
    );
    SharedPreferences.setMockInitialValues({
      'generationHistory': jsonEncode(history),
      'personProfiles': jsonEncode(profiles),
    });

    final store = LocalStore();
    final loadedHistory = await store.loadHistory();
    final loadedProfiles = await store.loadProfiles();

    expect(loadedHistory, hasLength(100));
    expect(loadedHistory.first.id, 'history-104');
    expect(loadedHistory.last.id, 'history-5');
    expect(loadedHistory.any((record) => record.id == 'history-0'), isFalse);
    expect(loadedProfiles, hasLength(50));
    expect(loadedProfiles.first.id, 'profile-54');
    expect(loadedProfiles.last.id, 'profile-5');
    expect(loadedProfiles.any((profile) => profile.id == 'profile-0'), isFalse);
  });

  test('local store saves sorted history without mutating caller list',
      () async {
    SharedPreferences.setMockInitialValues({});
    final older = GenerationRecord(
      inputType: ChatInputType.text,
      selectedStyleName: '自然',
      replies: [
        ReplySuggestion(styleLabel: '自然', text: '早一点', reason: '测试'),
      ],
      createdAt: DateTime(2026, 1, 1),
    );
    final newer = GenerationRecord(
      inputType: ChatInputType.text,
      selectedStyleName: '自然',
      replies: [
        ReplySuggestion(styleLabel: '自然', text: '晚一点', reason: '测试'),
      ],
      createdAt: DateTime(2026, 1, 2),
    );
    final records = [older, newer];

    await LocalStore().saveHistory(records);

    expect(records.map((record) => record.replies.single.text), [
      '早一点',
      '晚一点',
    ]);
    final saved = await LocalStore().loadHistory();
    expect(saved.map((record) => record.replies.single.text), [
      '晚一点',
      '早一点',
    ]);
  });

  test('local store saves sorted profiles without mutating caller list',
      () async {
    SharedPreferences.setMockInitialValues({});
    final older = PersonProfile(
      id: 'older',
      displayName: '早一点',
      updatedAt: DateTime(2026, 1, 1),
    );
    final newer = PersonProfile(
      id: 'newer',
      displayName: '晚一点',
      updatedAt: DateTime(2026, 1, 2),
    );
    final profiles = [older, newer];

    await LocalStore().saveProfiles(profiles);

    expect(profiles.map((profile) => profile.displayName), [
      '早一点',
      '晚一点',
    ]);
    final saved = await LocalStore().loadProfiles();
    expect(saved.map((profile) => profile.displayName), [
      '晚一点',
      '早一点',
    ]);
  });

  test('generation records decode iOS JSONEncoder date timestamps', () {
    final instant = DateTime.utc(2026, 1, 2, 3, 4, 5);
    final iosTimestamp = instant.millisecondsSinceEpoch / 1000 - 978307200;

    final numericRecord = GenerationRecord.fromJson({
      'inputType': 'image',
      'selectedStyleName': '自然',
      'replies': [
        {'style': '自然', 'text': '收到'}
      ],
      'createdAt': iosTimestamp,
    });
    final stringRecord = GenerationRecord.fromJson({
      'inputType': 'text',
      'selectedStyleName': '自然',
      'replies': [
        {'style': '自然', 'text': '好呀'}
      ],
      'createdAt': ' ${iosTimestamp.toString()} ',
    });

    expect(numericRecord.inputType, ChatInputType.image);
    expect(numericRecord.createdAt.toUtc(), instant);
    expect(stringRecord.createdAt.toUtc(), instant);
  });

  test('generation records preserve original iOS codable shape', () {
    final instant = DateTime.utc(2026, 1, 2, 3, 4, 5);
    final iosTimestamp = instant.millisecondsSinceEpoch / 1000 - 978307200;

    final record = GenerationRecord.fromJson({
      'id': '123e4567-e89b-12d3-a456-426614174000',
      'inputType': 'image',
      'sceneSummary': '解释迟到',
      'latestMessage': '你到哪了',
      'selectedStyleName': '道歉',
      'userGoal': '别显得敷衍',
      'copiedReply': '抱歉让你等了，我马上到。',
      'createdAt': iosTimestamp,
      'replies': [
        {
          'id': '123e4567-e89b-12d3-a456-426614174001',
          'style': '修复',
          'text': '抱歉让你等了，我马上到。',
          'reason': '先道歉再给进度',
        }
      ],
    });

    expect(record.id, '123e4567-e89b-12d3-a456-426614174000');
    expect(record.inputType, ChatInputType.image);
    expect(record.sceneSummary, '解释迟到');
    expect(record.latestMessage, '你到哪了');
    expect(record.selectedStyleName, '道歉');
    expect(record.userGoal, '别显得敷衍');
    expect(record.copiedReply, '抱歉让你等了，我马上到。');
    expect(record.createdAt.toUtc(), instant);
    expect(record.replies.single.id, '123e4567-e89b-12d3-a456-426614174001');
    expect(record.replies.single.styleLabel, '修复');
    expect(record.replies.single.text, '抱歉让你等了，我马上到。');
    expect(record.replies.single.reason, '先道歉再给进度');

    final json = record.toJson();
    expect(json['sceneSummary'], '解释迟到');
    expect(json['latestMessage'], '你到哪了');
    expect(json['selectedStyleName'], '道歉');
    expect(json['userGoal'], '别显得敷衍');
    expect(json['copiedReply'], '抱歉让你等了，我马上到。');
    expect(json, isNot(containsPair('screenshot', anything)));
  });

  test('generation records decode Unix epoch second timestamps', () {
    final instant = DateTime.utc(2026, 1, 2, 3, 4, 5);
    final unixSeconds = instant.millisecondsSinceEpoch / 1000;

    final record = GenerationRecord.fromJson({
      'inputType': 'text',
      'selectedStyleName': '自然',
      'replies': [
        {'text': '收到'}
      ],
      'createdAt': unixSeconds,
    });

    expect(record.createdAt.toUtc(), instant);
  });

  test('generation records regenerate blank imported ids', () {
    final blank = GenerationRecord.fromJson({
      'id': '   ',
      'inputType': 'text',
      'selectedStyleName': '自然',
      'replies': [
        {'text': '收到'}
      ],
    });
    final migrated = GenerationRecord.fromJson({
      'id': 'ios-history-id',
      'inputType': 'text',
      'selectedStyleName': '自然',
      'replies': [
        {'text': '收到'}
      ],
    });

    expect(blank.id.trim(), isNotEmpty);
    expect(blank.id, isNot('   '));
    expect(migrated.id, 'ios-history-id');
  });

  test('generation records clean blank migrated style and copied reply', () {
    final record = GenerationRecord.fromJson({
      'inputType': 'text',
      'selectedStyleName': '   ',
      'copiedReply': '   ',
      'replies': [
        {'text': '收到'}
      ],
    });

    expect(record.selectedStyleName, '自然');
    expect(record.copiedReply, isNull);
    expect(record.searchableText, isNot(contains('   ')));
  });

  test('generation record search text skips noisy presentation values', () {
    final record = GenerationRecord(
      inputType: ChatInputType.text,
      sceneSummary: '未知',
      platform: '  ',
      relationshipGuess: '未知',
      latestMessage: '今天见吗',
      emotion: '未知',
      riskNotice: '未知',
      selectedStyleName: '自然',
      userGoal: '  ',
      copiedReply: '未知',
      replies: [
        ReplySuggestion(styleLabel: '自然', text: '可以呀', reason: '未知'),
      ],
    );

    expect(record.searchableMetadataValues, contains('今天见吗'));
    expect(record.searchableMetadataValues, isNot(contains('未知')));
    expect(record.searchableReplyValues, ['可以呀']);
    expect(record.searchableText, contains('今天见吗'));
    expect(record.searchableText, contains('可以呀'));
    expect(record.searchableText, isNot(contains('未知')));
    expect(
      filterHistoryRecords([record], mode: HistoryFilterMode.all, query: '未知'),
      isEmpty,
    );
  });

  test('generation record copied reply helpers share presentation cleaning',
      () {
    final clean = GenerationRecord(
      inputType: ChatInputType.text,
      selectedStyleName: '自然',
      copiedReply: '  今晚可以  ',
      replies: [],
    );
    final noisy = GenerationRecord(
      inputType: ChatInputType.text,
      selectedStyleName: '自然',
      copiedReply: '未知',
      replies: const [],
    );

    expect(clean.cleanCopiedReply, '今晚可以');
    expect(clean.hasCopiedReply, isTrue);
    expect(clean.searchableMetadataValues, contains('今晚可以'));
    expect(noisy.cleanCopiedReply, isNull);
    expect(noisy.hasCopiedReply, isFalse);
    expect(noisy.searchableMetadataValues, isNot(contains('未知')));
    expect(
      filterHistoryRecords([clean, noisy],
          mode: HistoryFilterMode.copied, query: ''),
      [clean],
    );
  });

  test('generation record json cleans noisy presentation values', () {
    final record = GenerationRecord(
      inputType: ChatInputType.text,
      sceneSummary: '未知',
      platform: '  微信  ',
      relationshipGuess: '未知',
      latestMessage: '  今天见吗  ',
      emotion: '未知',
      riskNotice: '未知',
      selectedStyleName: '未知',
      userGoal: '  ',
      copiedReply: '未知',
      replies: [
        ReplySuggestion(styleLabel: '未知', text: '未知', reason: '未知'),
        ReplySuggestion(styleLabel: '  自然  ', text: '  可以呀  ', reason: '未知'),
        ReplySuggestion(styleLabel: '重复', text: '可以呀', reason: '重复'),
      ],
      createdAt: DateTime.utc(2026, 1, 2, 3, 4, 5),
    );

    final json = record.toJson();
    final restored = GenerationRecord.fromJson(json);
    final replies = json['replies'] as List<Object?>;
    final reply = Map<String, dynamic>.from(replies.single as Map);

    expect(json['sceneSummary'], isNull);
    expect(json['platform'], '微信');
    expect(json['relationshipGuess'], isNull);
    expect(json['latestMessage'], '今天见吗');
    expect(json['emotion'], isNull);
    expect(json['riskNotice'], isNull);
    expect(json['selectedStyleName'], '自然');
    expect(json['userGoal'], isNull);
    expect(json['copiedReply'], isNull);
    expect(reply['styleLabel'], '自然');
    expect(reply['text'], '可以呀');
    expect(restored.replies, hasLength(1));
    expect(restored.replies.single.text, '可以呀');
  });

  test('generation record normalized shares presentation cleaning rules', () {
    final createdAt = DateTime.utc(2026, 1, 2, 3, 4, 5);
    final record = GenerationRecord(
      id: ' dirty-record ',
      inputType: ChatInputType.text,
      sceneSummary: '未知',
      platform: '  微信  ',
      relationshipGuess: '未知',
      latestMessage: '  今天见吗  ',
      emotion: '未知',
      riskNotice: '  ',
      selectedStyleName: '未知',
      userGoal: '未知',
      copiedReply: '未知',
      replies: [
        ReplySuggestion(styleLabel: '未知', text: '未知', reason: '占位'),
        ReplySuggestion(styleLabel: '  自然  ', text: '  可以呀  ', reason: '未知'),
        ReplySuggestion(styleLabel: '重复', text: '可以呀', reason: '重复'),
      ],
      createdAt: createdAt,
    );

    final normalized = record.normalized();

    expect(normalized.id, ' dirty-record ');
    expect(normalized.sceneSummary, isNull);
    expect(normalized.platform, '微信');
    expect(normalized.relationshipGuess, isNull);
    expect(normalized.latestMessage, '今天见吗');
    expect(normalized.emotion, isNull);
    expect(normalized.riskNotice, isNull);
    expect(normalized.selectedStyleName, '自然');
    expect(normalized.userGoal, isNull);
    expect(normalized.copiedReply, isNull);
    expect(normalized.replies, hasLength(1));
    expect(normalized.replies.single.styleLabel, '自然');
    expect(normalized.replies.single.text, '可以呀');
    expect(normalized.replies.single.reason, '');
    expect(normalized.createdAt, createdAt);
  });

  test('generation records preserve legacy string reply entries', () {
    final record = GenerationRecord.fromJson({
      'inputType': 'text',
      'sceneSummary': '约晚饭',
      'selectedStyleName': '自然',
      'replies': [
        {'style': '自然', 'text': '可以呀，看你想吃什么', 'reason': '接住邀约'},
        '我都行，看你方便',
      ],
    });

    expect(record.replies.map((reply) => reply.text), [
      '可以呀，看你想吃什么',
      '我都行，看你方便',
    ]);
    expect(record.replies.last.styleLabel, '建议');
    expect(record.searchableText, contains('看你方便'));
  });

  test('generation records accept snake case imported fields', () {
    final record = GenerationRecord.fromJson({
      'input_type': 'image',
      'scene_summary': '解释迟到',
      'source_platform': '微信',
      'relationship_guess': '朋友',
      'latest_message': '你到哪了',
      'risk_warning': '先承认等待成本',
      'selected_style_name': '道歉',
      'user_goal': '别显得敷衍',
      'copied_reply': '抱歉让你等了，我马上到。',
      'created_at': '2026-01-02T03:04:05.000Z',
      'replies': [
        {
          'suggestion_id': 'reply-ios-1',
          'style_label': '修复',
          'message': '抱歉让你等了，我马上到。',
          'explanation': '先道歉再给进度',
        }
      ],
    });

    expect(record.inputType, ChatInputType.image);
    expect(record.sceneSummary, '解释迟到');
    expect(record.platform, '微信');
    expect(record.relationshipGuess, '朋友');
    expect(record.latestMessage, '你到哪了');
    expect(record.riskNotice, '先承认等待成本');
    expect(record.selectedStyleName, '道歉');
    expect(record.userGoal, '别显得敷衍');
    expect(record.copiedReply, '抱歉让你等了，我马上到。');
    expect(record.createdAt.toUtc(), DateTime.utc(2026, 1, 2, 3, 4, 5));
    expect(record.replies.single.id, 'reply-ios-1');
    expect(record.replies.single.styleLabel, '修复');
    expect(record.replies.single.reason, '先道歉再给进度');

    final aliasRecord = GenerationRecord.fromJson({
      'inputType': 'text',
      'sceneDescription': '对方临时改时间',
      'platformName': '微信',
      'relation': '朋友',
      'currentMessage': '我可能要晚一点',
      'sentiment': '抱歉',
      'caution': '先接住影响',
      'selectedStyleName': '自然',
      'replies': [
        {'text': '没事，你路上慢点，到时说一声。'}
      ],
    });

    expect(aliasRecord.sceneSummary, '对方临时改时间');
    expect(aliasRecord.platform, '微信');
    expect(aliasRecord.relationshipGuess, '朋友');
    expect(aliasRecord.latestMessage, '我可能要晚一点');
    expect(aliasRecord.emotion, '抱歉');
    expect(aliasRecord.riskNotice, '先接住影响');
  });

  test('generation records accept compatible reply candidate fields', () {
    final replyOptionsRecord = GenerationRecord.fromJson({
      'inputType': 'text',
      'chat_style': '职场',
      'reply_options': [
        {'reply': '那我们七点见', 'tone': '自然', 'reason': '承接约定'}
      ],
    });
    final candidatesRecord = GenerationRecord.fromJson({
      'inputType': 'text',
      'candidates': ['可以，晚点见。'],
    });

    expect(replyOptionsRecord.selectedStyleName, '职场');
    expect(replyOptionsRecord.replies.single.text, '那我们七点见');
    expect(replyOptionsRecord.replies.single.styleLabel, '自然');
    expect(replyOptionsRecord.replies.single.reason, '承接约定');
    expect(candidatesRecord.replies.single.text, '可以，晚点见。');
  });

  test('generation records accept common exported aliases', () {
    final record = GenerationRecord.fromJson({
      'historyRecordId': 'export-1',
      'mode': 'photo',
      'styleLabel': '轻松',
      'userIntent': '别太正式',
      'selectedReply': '那就晚一点见。',
      'timestamp': '2026-01-02T03:04:05.000Z',
      'results': [
        {
          'toneLabel': '自然',
          'replyText': '那就晚一点见。',
          'note': '顺着对方节奏',
        }
      ],
    });

    expect(record.id, 'export-1');
    expect(record.inputType, ChatInputType.image);
    expect(record.selectedStyleName, '轻松');
    expect(record.userGoal, '别太正式');
    expect(record.copiedReply, '那就晚一点见。');
    expect(record.createdAt.toUtc(), DateTime.utc(2026, 1, 2, 3, 4, 5));
    expect(record.replies.single.styleLabel, '自然');
    expect(record.replies.single.text, '那就晚一点见。');
    expect(record.replies.single.reason, '顺着对方节奏');
  });

  test('generation records accept compatible input type values', () {
    GenerationRecord recordWithType(String value) => GenerationRecord.fromJson({
          'inputType': value,
          'selectedStyleName': '自然',
          'replies': [
            {'text': '收到'}
          ],
        });

    expect(recordWithType('Image').inputType, ChatInputType.image);
    expect(recordWithType('screen-shot').inputType, ChatInputType.image);
    expect(recordWithType('screen image').inputType, ChatInputType.image);
    expect(recordWithType('screen_image').inputType, ChatInputType.image);
    expect(recordWithType(' 截图 ').inputType, ChatInputType.image);
    expect(recordWithType('text').inputType, ChatInputType.text);
    expect(recordWithType('chat_text').inputType, ChatInputType.text);
  });

  test('legacy person profiles use createdAt when updatedAt is missing', () {
    final createdAt = DateTime(2026, 1, 2, 9, 30);
    final profile = PersonProfile.fromJson({
      'id': 'legacy-person',
      'displayName': '旧画像',
      'createdAt': createdAt.toIso8601String(),
    });

    expect(profile.createdAt, createdAt);
    expect(profile.updatedAt, createdAt);
  });

  test('person profiles decode iOS JSONEncoder date timestamps', () {
    final createdInstant = DateTime.utc(2026, 1, 2, 3, 4, 5);
    final updatedInstant = DateTime.utc(2026, 1, 3, 4, 5, 6);
    final createdTimestamp =
        createdInstant.millisecondsSinceEpoch / 1000 - 978307200;
    final updatedTimestamp =
        updatedInstant.millisecondsSinceEpoch / 1000 - 978307200;

    final profile = PersonProfile.fromJson({
      'displayName': '小林',
      'createdAt': createdTimestamp,
      'updatedAt': ' ${updatedTimestamp.toString()} ',
    });

    expect(profile.createdAt.toUtc(), createdInstant);
    expect(profile.updatedAt.toUtc(), updatedInstant);
  });

  test('person profiles decode Unix epoch second timestamps', () {
    final createdInstant = DateTime.utc(2026, 1, 2, 3, 4, 5);
    final updatedInstant = DateTime.utc(2026, 1, 3, 4, 5, 6);

    final profile = PersonProfile.fromJson({
      'displayName': '小林',
      'createdAt': createdInstant.millisecondsSinceEpoch / 1000,
      'updatedAt': updatedInstant.millisecondsSinceEpoch / 1000,
    });

    expect(profile.createdAt.toUtc(), createdInstant);
    expect(profile.updatedAt.toUtc(), updatedInstant);
  });

  test('person profiles accept snake case imported fields', () {
    final profile = PersonProfile.fromJson({
      'display_name': '小林',
      'last_scene_summary': '最近在聊项目排期',
      'last_update_reason': '聊天中多次提到时间安排',
      'created_at': '2026-01-02T03:04:05.000Z',
      'updated_at': '2026-01-03T04:05:06.000Z',
    });
    final compatibleProfile = PersonProfile.fromJson({
      'display_name': '小周',
      'scene_summary': '最近在聊旅行计划',
      'update_reason': '朋友圈动态反复提到行程',
    });

    expect(profile.displayName, '小林');
    expect(profile.lastSceneSummary, '最近在聊项目排期');
    expect(profile.lastUpdateReason, '聊天中多次提到时间安排');
    expect(profile.createdAt.toUtc(), DateTime.utc(2026, 1, 2, 3, 4, 5));
    expect(profile.updatedAt.toUtc(), DateTime.utc(2026, 1, 3, 4, 5, 6));
    expect(compatibleProfile.lastSceneSummary, '最近在聊旅行计划');
    expect(compatibleProfile.lastUpdateReason, '朋友圈动态反复提到行程');
  });

  test('person profiles preserve compatible recent source aliases', () {
    final profile = PersonProfile.fromJson({
      'displayName': '小林',
      'context_summary': '最近在聊毕业答辩安排',
      'source_reason': '聊天里连续提到答辩时间',
    });
    final evidenceProfile = PersonProfile.fromJson({
      'displayName': '小周',
      'evidenceSummary': '朋友圈展示加班状态',
      'basis': '动态里多次提到项目截止',
    });
    final insight = PersonInsight.fromJson({
      'displayName': '阿杰',
      'evidence': '对方反复强调不要临时变更',
    });

    expect(profile.lastSceneSummary, '最近在聊毕业答辩安排');
    expect(profile.lastUpdateReason, '聊天里连续提到答辩时间');
    expect(evidenceProfile.lastSceneSummary, '朋友圈展示加班状态');
    expect(evidenceProfile.lastUpdateReason, '动态里多次提到项目截止');
    expect(insight.updateReason, '对方反复强调不要临时变更');
  });

  test('person profiles accept common exported date aliases', () {
    final createdInstant = DateTime.utc(2026, 1, 2, 3, 4, 5);
    final updatedInstant = DateTime.utc(2026, 1, 3, 4, 5, 6);
    final createdTimestamp =
        createdInstant.millisecondsSinceEpoch / 1000 - 978307200;
    final updatedTimestamp =
        updatedInstant.millisecondsSinceEpoch / 1000 - 978307200;

    final profile = PersonProfile.fromJson({
      'displayName': '小林',
      'createdTime': '2026-01-02T03:04:05.000Z',
      'lastUpdatedAt': '2026-01-03T04:05:06.000Z',
    });
    final modifiedProfile = PersonProfile.fromJson({
      'displayName': '小周',
      'createdOn': createdTimestamp,
      'modifiedAt': updatedTimestamp,
    });

    expect(profile.createdAt.toUtc(), createdInstant);
    expect(profile.updatedAt.toUtc(), updatedInstant);
    expect(modifiedProfile.createdAt.toUtc(), createdInstant);
    expect(modifiedProfile.updatedAt.toUtc(), updatedInstant);
  });

  test('person profiles regenerate blank imported ids', () {
    final blank = PersonProfile.fromJson({
      'id': '  ',
      'displayName': '小林',
    });
    final migrated = PersonProfile.fromJson({
      'id': 'ios-profile-id',
      'displayName': '小林',
    });

    expect(blank.id.trim(), isNotEmpty);
    expect(blank.id, isNot('  '));
    expect(migrated.id, 'ios-profile-id');
  });

  test('person profile json cleans noisy presentation values', () {
    final createdAt = DateTime.utc(2026, 1, 2, 3, 4, 5);
    final updatedAt = DateTime.utc(2026, 1, 3, 4, 5, 6);
    final profile = PersonProfile(
      displayName: '未知',
      aliases: const [' Lin ', 'lin', '未知', ' '],
      relationship: '未知',
      communicationStyle: '  直接一点  ',
      personalityTraits: const [' 靠谱 ', '靠谱', '未知'],
      innerNeeds: const ['未知'],
      keyPersonPoints: const [' 喜欢提前确认时间 '],
      momentsInsights: const [' 常分享工作动态 ', '未知'],
      tonePreferences: const ['别绕太久', '未知'],
      boundaries: const ['未知'],
      facts: const [' 项目负责人 ', '未知'],
      lastSceneSummary: '未知',
      lastUpdateReason: '未知',
      confidence: 1.4,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );

    final json = profile.toJson();
    final restored = PersonProfile.fromJson(json);

    expect(json['displayName'], '未命名人物');
    expect(json['aliases'], ['Lin']);
    expect(json['relationship'], isNull);
    expect(json['communicationStyle'], '直接一点');
    expect(json['personalityTraits'], ['靠谱']);
    expect(json['innerNeeds'], isEmpty);
    expect(json['keyPersonPoints'], ['喜欢提前确认时间']);
    expect(json['momentsInsights'], ['常分享工作动态']);
    expect(json['tonePreferences'], ['别绕太久']);
    expect(json['boundaries'], isEmpty);
    expect(json['facts'], ['项目负责人']);
    expect(json['lastSceneSummary'], isNull);
    expect(json['lastUpdateReason'], isNull);
    expect(json['confidence'], 1);
    expect(restored.displayName, '未命名人物');
    expect(restored.aliases, ['Lin']);
    expect(restored.relationship, isNull);
    expect(restored.communicationStyle, '直接一点');
    expect(restored.personalityTraits, ['靠谱']);
    expect(restored.innerNeeds, isEmpty);
    expect(restored.keyPersonPoints, ['喜欢提前确认时间']);
    expect(restored.momentsInsights, ['常分享工作动态']);
    expect(restored.tonePreferences, ['别绕太久']);
    expect(restored.boundaries, isEmpty);
    expect(restored.facts, ['项目负责人']);
    expect(restored.lastSceneSummary, isNull);
    expect(restored.lastUpdateReason, isNull);
    expect(restored.confidence, 1);
    expect(restored.createdAt.toUtc(), createdAt);
    expect(restored.updatedAt.toUtc(), updatedAt);
  });

  test('imported model identity aliases stay stable', () {
    final record = GenerationRecord.fromJson({
      'generation_id': 'gen-compatible-1',
      'inputType': 'text',
      'selectedStyleName': '自然',
      'replies': [
        {
          'candidate_id': 'candidate-compatible-1',
          'text': '收到，我晚点看。',
        }
      ],
    });
    final profile = PersonProfile.fromJson({
      'profile_id': 'profile-compatible-1',
      'displayName': '小林',
    });
    final personProfile = PersonProfile.fromJson({
      'person_id': 'person-compatible-1',
      'displayName': '小周',
    });
    final customStyle = ChatStyle.fromJson({
      'style_id': 'style-compatible-1',
      'name': '短句',
      'description': '少说一点',
      'rules': '短句；不解释太多',
      'isOfficial': false,
    });

    expect(record.id, 'gen-compatible-1');
    expect(record.replies.single.id, 'candidate-compatible-1');
    expect(profile.id, 'profile-compatible-1');
    expect(personProfile.id, 'person-compatible-1');
    expect(customStyle.id, 'style-compatible-1');
    expect(customStyle.rules, ['短句', '不解释太多']);
  });

  test('model id helpers share text cleaning and natural sort ignores padding',
      () {
    final ids = [' model-10 ', 'model-2', ' model-01 ']
      ..sort(localizedStandardLikeCompare);

    expect(cleanModelId('  gpt-4o-mini  '), 'gpt-4o-mini');
    expect(cleanModelId('   '), '');
    expect(normalizedModelId('  GPT-4O-MINI  '), 'gpt-4o-mini');
    expect(modelIdsEqual(' GPT-4O-MINI ', 'gpt-4o-mini'), isTrue);
    expect(ids, [' model-01 ', 'model-2', ' model-10 ']);

    final modelIdSource = File('lib/core/model_id.dart').readAsStringSync();
    final sortSource =
        File('lib/core/model_natural_sort.dart').readAsStringSync();
    expect(modelIdSource, contains("import 'text_cleaning.dart';"));
    expect(
      modelIdSource,
      contains(
        "String cleanModelId(String modelId) => cleanNonEmptyText(modelId) ?? '';",
      ),
    );
    expect(modelIdSource, isNot(contains('modelId.trim()')));
    expect(sortSource, contains('_naturalSortParts(cleanModelId(left))'));
    expect(sortSource, contains('_naturalSortParts(cleanModelId(right))'));
    expect(sortSource, isNot(contains('left.trim()')));
    expect(sortSource, isNot(contains('right.trim()')));
  });

  test('reasoning model detection only treats o-series as standalone ids', () {
    expect(looksReasoningModelId('o3-mini'), isTrue);
    expect(looksReasoningModelId('openai/o4-mini'), isTrue);
    expect(looksReasoningModelId('deepseek-r1'), isTrue);
    expect(looksReasoningModelId('qwen3-thinking'), isTrue);
    expect(looksReasoningModelId('omni-moderation-latest'), isFalse);
    expect(looksReasoningModelId('openchat-3.5'), isFalse);
    expect(looksReasoningModelId('ollama/llama3'), isFalse);

    final source =
        File('lib/core/model_recommendation_helpers.dart').readAsStringSync();
    expect(source, isNot(contains("lower.startsWith('o')")));
    expect(source, contains(r"RegExp(r'(^|[/:\-_])o\d')"));
  });

  test('person decoding keeps missing communication style null', () {
    final insight = PersonInsight.fromJson({
      'displayName': '小林',
      'relationship': '朋友',
    });
    final profile = PersonProfile.fromJson({
      'displayName': '小林',
      'relationship': '朋友',
    });

    expect(insight.communicationStyle, isNull);
    expect(profile.communicationStyle, isNull);
    expect(profile.summaryForPrompt, contains('关系：朋友'));
    expect(profile.summaryForPrompt, isNot(contains('沟通风格：')));
  });

  test('person insight and profile decoding accept flexible legacy values', () {
    final insight = PersonInsight.fromJson({
      'displayName': 123,
      'alias': '小林，Lin、lin、林同学',
      'personalityTraits': '稳,慢热；靠谱；稳',
      'confidence-score': '0.85',
    });
    final profile = PersonProfile.fromJson({
      'name': '小林',
      'alsoKnownAs': 'Lin，lin，林同学',
      'relationshipGuess': '同事',
      'communicationAdvice': ['轻松一点', '别催', '轻松一点'],
      'traits': '稳,慢热,稳',
      'needs': '确定性',
      'importantNotes': ['喜欢提前确认时间'],
      'observations': '常发项目复盘',
      'avoidTopics': '临时变卦',
      'stableFacts': '项目负责人；常加班',
      'confidence_score': '1.2',
    });

    expect(insight.displayName, '123');
    expect(insight.aliases, ['小林', 'Lin', '林同学']);
    expect(insight.personalityTraits, ['稳', '慢热', '靠谱']);
    expect(insight.confidence, 0.85);
    expect(profile.displayName, '小林');
    expect(profile.aliases, ['Lin', '林同学']);
    expect(profile.relationship, '同事');
    expect(profile.communicationStyle, '轻松一点；别催');
    expect(profile.personalityTraits, ['稳', '慢热']);
    expect(profile.innerNeeds, ['确定性']);
    expect(profile.keyPersonPoints, ['喜欢提前确认时间']);
    expect(profile.momentsInsights, ['常发项目复盘']);
    expect(profile.tonePreferences, ['轻松一点', '别催']);
    expect(profile.boundaries, ['临时变卦']);
    expect(profile.facts, ['项目负责人', '常加班']);
    expect(profile.confidence, 1);
  });

  test('person profiles accept reply insight field aliases', () {
    final profile = PersonProfile.fromJson({
      'contactName': '小陈',
      'connection': '同学',
      'preferredTones': '轻松；少说教',
      'characterTraits': '外向',
      'motivations': '被认可',
      'highlights': '喜欢线下聚会',
      'recentSignals': '最近在准备考试',
      'doNotMention': '挂科',
      'profileFacts': '学生会成员',
      'score': '0.66',
    });

    expect(profile.displayName, '小陈');
    expect(profile.relationship, '同学');
    expect(profile.communicationStyle, '轻松；少说教');
    expect(profile.tonePreferences, ['轻松', '少说教']);
    expect(profile.personalityTraits, ['外向']);
    expect(profile.innerNeeds, ['被认可']);
    expect(profile.keyPersonPoints, ['喜欢线下聚会']);
    expect(profile.momentsInsights, ['最近在准备考试']);
    expect(profile.boundaries, ['挂科']);
    expect(profile.facts, ['学生会成员']);
    expect(profile.confidence, 0.66);
  });

  test('local store falls back from corrupt personalization and appearance',
      () async {
    SharedPreferences.setMockInitialValues({
      'replyPersonalizationSettings': '{not json',
      'appearanceSettings': '{not json',
    });
    final store = LocalStore();

    final personalization = await store.loadPersonalization();
    final appearance = await store.loadAppearance();

    expect(personalization.enabledFeatureSummary,
        ReplyPersonalizationSettings.defaults.enabledFeatureSummary);
    expect(appearance.isBackgroundBlurEnabled,
        AppearanceSettings.defaults.isBackgroundBlurEnabled);
    expect(appearance.backgroundBlurRadius,
        AppearanceSettings.defaults.backgroundBlurRadius);
  });

  test('local store accepts legacy iOS appearance keys', () async {
    SharedPreferences.setMockInitialValues({
      'appearance.isBackgroundBlurEnabled': '否',
      'appearance.backgroundBlurRadius': ' 22.0 ',
      'appearance.backgroundDimOpacity': ' 0.35 ',
      'appearance.glassTintStrength': ' 1.4 ',
      'appearance.glassBorderStrength': ' 0.7 ',
      'appearance.accentColorName': 'rose',
      'appearance.textSizeName': 'large',
    });
    final store = LocalStore();

    final appearance = await store.loadAppearance();

    expect(appearance.isBackgroundBlurEnabled, isFalse);
    expect(appearance.backgroundBlurRadius, 22);
    expect(appearance.backgroundDimOpacity, 0.35);
    expect(appearance.glassTintStrength, 1.4);
    expect(appearance.glassBorderStrength, 0.7);
    expect(appearance.accentColorName, 'rose');
    expect(appearance.textSizeName, 'large');

    final source = File('lib/core/storage_preferences.dart').readAsStringSync();
    expect(source, contains('final text = cleanNonEmptyText(value);'));
    expect(source, isNot(contains('double.tryParse(value.trim())')));
  });

  test('saving appearance removes obsolete legacy appearance keys', () async {
    SharedPreferences.setMockInitialValues({
      'appearance.isBackgroundBlurEnabled': false,
      'appearance.backgroundBlurRadius': 22.0,
      'appearance.backgroundDimOpacity': 0.35,
      'appearance.glassTintStrength': 1.4,
      'appearance.glassBorderStrength': 0.7,
      'appearance.accentColorName': 'rose',
      'appearance.textSizeName': 'large',
      'appearance.customBackgroundVersion': 2,
    });
    final store = LocalStore();

    await store.saveAppearance(
      const AppearanceSettings(accentColorName: 'mint'),
    );

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('appearanceSettings'), isNotNull);
    expect(prefs.getBool('appearance.isBackgroundBlurEnabled'), isNull);
    expect(prefs.getDouble('appearance.backgroundBlurRadius'), isNull);
    expect(prefs.getDouble('appearance.backgroundDimOpacity'), isNull);
    expect(prefs.getDouble('appearance.glassTintStrength'), isNull);
    expect(prefs.getDouble('appearance.glassBorderStrength'), isNull);
    expect(prefs.getString('appearance.accentColorName'), isNull);
    expect(prefs.getString('appearance.textSizeName'), isNull);
    expect(prefs.getInt('appearance.customBackgroundVersion'), isNull);

    final appearance = await store.loadAppearance();
    expect(appearance.accentColorName, 'mint');
  });

  test('local store accepts trimmed iOS default style name key', () async {
    SharedPreferences.setMockInitialValues({'defaultChatStyleName': '  职场  '});
    final store = LocalStore();

    expect(await store.loadDefaultStyleId(), '职场');

    await store.saveDefaultStyleId('official-gentle');
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('defaultChatStyleId'), 'official-gentle');
    expect(prefs.getString('defaultChatStyleName'), isNull);

    final source =
        File('lib/core/storage_user_settings.dart').readAsStringSync();
    expect(source, contains('return cleanIdentifierText(value);'));
    expect(source, isNot(contains('final trimmed = value?.trim();')));
  });

  test('local store cleans default style ids before saving', () async {
    SharedPreferences.setMockInitialValues({
      'defaultChatStyleId': 'official-natural',
      'defaultChatStyleName': '职场',
    });
    final store = LocalStore();

    await store.saveDefaultStyleId('  official-gentle  ');

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('defaultChatStyleId'), 'official-gentle');
    expect(prefs.getString('defaultChatStyleName'), isNull);
    expect(await store.loadDefaultStyleId(), 'official-gentle');

    await store.saveDefaultStyleId('   \n  ');

    expect(prefs.getString('defaultChatStyleId'), isNull);
    expect(prefs.getString('defaultChatStyleName'), isNull);
    expect(await store.loadDefaultStyleId(), isNull);
  });

  test('clear all removes both current and legacy default style keys',
      () async {
    SharedPreferences.setMockInitialValues({
      'defaultChatStyleId': 'official-gentle',
      'defaultChatStyleName': '职场',
      'pendingQuickImageRequest': true,
      'appearanceSettings': jsonEncode(
        const AppearanceSettings(accentColorName: 'mint').toJson(),
      ),
      'appearance.isBackgroundBlurEnabled': false,
      'appearance.backgroundBlurRadius': 22.0,
      'appearance.backgroundDimOpacity': 0.35,
      'appearance.glassTintStrength': 1.4,
      'appearance.glassBorderStrength': 0.7,
      'appearance.accentColorName': 'rose',
      'appearance.textSizeName': 'large',
      'appearance.customBackgroundVersion': 2,
    });
    const secureStorageChannel =
        MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(secureStorageChannel, (_) async => null);
    final store = LocalStore();

    try {
      await store.clearAll();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('defaultChatStyleId'), isNull);
      expect(prefs.getString('defaultChatStyleName'), isNull);
      expect(prefs.getBool('pendingQuickImageRequest'), isNull);
      expect(prefs.getString('appearanceSettings'), isNull);
      expect(prefs.getBool('appearance.isBackgroundBlurEnabled'), isNull);
      expect(prefs.getDouble('appearance.backgroundBlurRadius'), isNull);
      expect(prefs.getDouble('appearance.backgroundDimOpacity'), isNull);
      expect(prefs.getDouble('appearance.glassTintStrength'), isNull);
      expect(prefs.getDouble('appearance.glassBorderStrength'), isNull);
      expect(prefs.getString('appearance.accentColorName'), isNull);
      expect(prefs.getString('appearance.textSizeName'), isNull);
      expect(prefs.getInt('appearance.customBackgroundVersion'), isNull);
    } finally {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(secureStorageChannel, null);
    }
  });

  test('api key storage falls back when secure storage is unavailable',
      () async {
    SharedPreferences.setMockInitialValues({});
    const secureStorageChannel =
        MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      secureStorageChannel,
      (_) async => throw PlatformException(code: 'unavailable'),
    );
    final store = LocalStore();

    try {
      await store.saveAPIKey('  sk-fallback  ');

      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getString('apiKey.keychainUnavailableFallback'),
        'sk-fallback',
      );
      expect(await store.loadAPIKey(), 'sk-fallback');

      await store.saveAPIKey('   \n  ');

      expect(prefs.getString('apiKey.keychainUnavailableFallback'), isNull);
    } finally {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(secureStorageChannel, null);
    }
  });

  test('api key loading cleans secure values and skips blank secure storage',
      () async {
    SharedPreferences.setMockInitialValues({
      'apiKey.keychainUnavailableFallback': 'sk-fallback',
    });
    const secureStorageChannel =
        MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
    var secureValue = '  sk-secure  ';
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      secureStorageChannel,
      (call) async => call.method == 'read' ? secureValue : null,
    );
    final store = LocalStore();

    try {
      expect(await store.loadAPIKey(), 'sk-secure');

      secureValue = '   \n  ';

      expect(await store.loadAPIKey(), 'sk-fallback');

      final storageSource =
          File('lib/core/storage_api_key.dart').readAsStringSync();
      expect(storageSource,
          contains('return cleanAPIKeyInput(value) ?? fallback;'));
    } finally {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(secureStorageChannel, null);
    }
  });

  test('local store ignores wrong typed migrated preference values', () async {
    SharedPreferences.setMockInitialValues({
      'apiConfig': 7,
      'generationHistory': false,
      'personProfiles': 3.14,
      'replyPersonalizationSettings': ['not a json object'],
      'appearanceSettings': 42,
      'defaultChatStyleId': true,
      'defaultChatStyleName': 99,
      'apiKey.keychainUnavailableFallback': 12345,
      'hasSeenPrivacyNotice': 'yes',
    });
    const secureStorageChannel =
        MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      secureStorageChannel,
      (_) async => throw PlatformException(code: 'unavailable'),
    );
    final store = LocalStore();

    try {
      expect(await store.loadConfig(), APIConfig.defaults);
      expect(await store.loadHistory(), isEmpty);
      expect(await store.loadProfiles(), isEmpty);
      expect(
        await store.loadPersonalization(),
        ReplyPersonalizationSettings.defaults,
      );
      expect(await store.loadAppearance(), AppearanceSettings.defaults);
      expect(await store.loadDefaultStyleId(), isNull);
      expect(await store.loadAPIKey(), isEmpty);
      expect(await store.hasSeenPrivacyNotice(), isTrue);

      final storageSource = File('lib/core/storage.dart').readAsStringSync();
      final preferencesSource =
          File('lib/core/storage_preferences.dart').readAsStringSync();
      expect(storageSource, contains("import 'text_cleaning.dart';"));
      expect(
        preferencesSource,
        contains(
          'return cleanNonEmptyText(_preferenceValue(prefs, key)?.toString());',
        ),
      );
      expect(
        preferencesSource,
        contains('return cleanNonEmptyText(value);'),
      );
      expect(preferencesSource, isNot(contains('value.toString().trim()')));
    } finally {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(secureStorageChannel, null);
    }
  });

  test('personalization settings accepts legacy boolean-like values', () {
    final settings = ReplyPersonalizationSettings.fromJson({
      'isColloquialExpressionEnabled': 'off',
      'isConversationMemoryEnabled': 0,
      'isAdaptiveStyleEnabled': 'enabled',
      'customStyles': [
        {
          'name': '克制',
          'description': '短句',
          'rules': ['少问'],
          'isOfficial': '否',
        }
      ],
    });

    expect(settings.isColloquialExpressionEnabled, isFalse);
    expect(settings.isConversationMemoryEnabled, isFalse);
    expect(settings.isAdaptiveStyleEnabled, isTrue);
    expect(settings.customStyles.single.isOfficial, isFalse);
  });

  test('personalization settings accepts localized gender values', () {
    expect(
      ReplyPersonalizationSettings.fromJson({'userGender': ' 女 '}).userGender,
      UserGender.female,
    );
    expect(
      ReplyPersonalizationSettings.fromJson({'userGender': 'male'}).userGender,
      UserGender.male,
    );
    expect(
      ReplyPersonalizationSettings.fromJson({'userGender': '用户自定义/非二元'})
          .userGender,
      UserGender.nonBinary,
    );
    expect(
      ReplyPersonalizationSettings.fromJson({'userGender': 'non_binary'})
          .userGender,
      UserGender.nonBinary,
    );
    expect(
      ReplyPersonalizationSettings.fromJson({'userGender': 'non-binary'})
          .userGender,
      UserGender.nonBinary,
    );
    expect(
      ReplyPersonalizationSettings.fromJson({'userGender': 'non binary'})
          .userGender,
      UserGender.nonBinary,
    );
    expect(
      ReplyPersonalizationSettings.fromJson({'userGender': '其他'}).userGender,
      UserGender.nonBinary,
    );
    expect(
      ReplyPersonalizationSettings.fromJson({'userGender': '不填写'}).userGender,
      UserGender.unspecified,
    );
    expect(
      ReplyPersonalizationSettings.fromJson({'userGender': '   '}).userGender,
      UserGender.unspecified,
    );

    final source =
        File('lib/core/personalization_json.dart').readAsStringSync();
    expect(
        source, contains('final text = cleanNonEmptyText(raw?.toString());'));
    expect(source, isNot(contains('raw?.toString().trim()')));
  });

  test('personalization settings preserves string custom style rules', () {
    final settings = ReplyPersonalizationSettings.fromJson({
      'customStyles': [
        {
          'name': '  克制  ',
          'description': '  不催促  ',
          'rules': '短句\n少问、别连续追问；语气轻一点',
        }
      ],
    });

    expect(settings.customStyles.single.name, '克制');
    expect(settings.customStyles.single.description, '不催促');
    expect(settings.customStyles.single.rules, [
      '短句',
      '少问',
      '别连续追问',
      '语气轻一点',
    ]);
    expect(settings.customStyles.single.isOfficial, isFalse);
  });

  test('personalization settings accepts snake case imported fields', () {
    final settings = ReplyPersonalizationSettings.fromJson({
      'is_colloquial_expression_enabled': 'false',
      'user_gender': '女',
      'user_age_text': '25',
      'custom_styles': [
        {
          'id': 'custom-soft',
          'name': '柔和',
          'desc': '慢一点回应',
          'style_rules': '短句；先接情绪',
          'is_official': 'false',
        }
      ],
      'is_conversation_memory_enabled': '0',
      'is_adaptive_style_enabled': 'yes',
      'memory_notes': '不要连续追问',
    });

    expect(settings.isColloquialExpressionEnabled, isFalse);
    expect(settings.userGender, UserGender.female);
    expect(settings.userAgeText, '25');
    expect(settings.customStyles.single.id, 'custom-soft');
    expect(settings.customStyles.single.description, '慢一点回应');
    expect(settings.customStyles.single.rules, ['短句', '先接情绪']);
    expect(settings.customStyles.single.isOfficial, isFalse);
    expect(settings.isConversationMemoryEnabled, isFalse);
    expect(settings.isAdaptiveStyleEnabled, isTrue);
    expect(settings.memoryNotes, '不要连续追问');
  });

  test('personalization settings accepts compatible custom style containers',
      () {
    final single = ReplyPersonalizationSettings.fromJson({
      'customStyle': {
        'name': '克制',
        'description': '短一点',
        'rules': '少问；别催',
      },
    });
    final styles = ReplyPersonalizationSettings.fromJson({
      'styles': [
        {
          'title': '轻松',
          'desc': '像朋友',
          'styleRules': '口语化；别端着',
        }
      ],
    });

    expect(single.customStyles.single.name, '克制');
    expect(single.customStyles.single.rules, ['少问', '别催']);
    expect(styles.customStyles.single.name, '轻松');
    expect(styles.customStyles.single.description, '像朋友');
    expect(styles.customStyles.single.rules, ['口语化', '别端着']);
  });

  test('personalization settings accepts map shaped custom style exports', () {
    final settings = ReplyPersonalizationSettings.fromJson({
      'customStyles': {
        'style-soft': {
          'title': '轻一点',
          'desc': '像朋友聊天',
          'styleRules': '短句；先接情绪',
        },
        'style-direct': {
          'id': 'explicit-direct',
          'name': '直接',
          'rules': ['先给结论', '少绕弯'],
        },
        'metadata': {'count': 2},
      },
    });

    expect(settings.customStyles.map((style) => style.id), [
      'style-soft',
      'explicit-direct',
    ]);
    expect(settings.customStyles.map((style) => style.name), ['轻一点', '直接']);
    expect(settings.customStyles.first.description, '像朋友聊天');
    expect(settings.customStyles.first.rules, ['短句', '先接情绪']);
    expect(settings.customStyles[1].rules, ['先给结论', '少绕弯']);
  });

  test('chat styles accept common exported aliases', () {
    final style = ChatStyle.fromJson({
      'customStyleId': 'style-export-1',
      'styleName': '轻一点',
      'summary': '像朋友聊天',
      'instructions': '短句；先接情绪',
      'builtin': 'no',
    });

    expect(style.id, 'style-export-1');
    expect(style.name, '轻一点');
    expect(style.description, '像朋友聊天');
    expect(style.rules, ['短句', '先接情绪']);
    expect(style.isOfficial, isFalse);
  });

  test('personalization settings accepts common exported aliases', () {
    final settings = ReplyPersonalizationSettings.fromJson({
      'colloquialEnabled': 'no',
      'gender': 'girl',
      'age': '00 后',
      'conversationMemory': 'yes',
      'adaptiveStyle': 0,
      'memory': '别太正式',
      'stylePresets': [
        {
          'title': '像我',
          'desc': '朋友感',
          'styleRules': '短一点；自然一点',
        }
      ],
    });

    expect(settings.isColloquialExpressionEnabled, isFalse);
    expect(settings.userGender, UserGender.female);
    expect(settings.userAgeText, '00 后');
    expect(settings.isConversationMemoryEnabled, isTrue);
    expect(settings.isAdaptiveStyleEnabled, isFalse);
    expect(settings.memoryNotes, '别太正式');
    expect(settings.customStyles.single.name, '像我');
    expect(settings.customStyles.single.rules, ['短一点', '自然一点']);
  });

  test('personalization settings accepts wrapped exported preferences', () {
    final settings = ReplyPersonalizationSettings.fromJson({
      'replyPersonalization': {
        'casualTone': 'false',
        'sex': 'man',
        'ageGroup': '90 后',
        'rememberContext': '1',
        'styleLearning': 'no',
        'personalMemory': '别连续追问',
        'customStyle': {
          'title': '慢一点',
          'desc': '先接情绪',
          'styleRules': '短句；少解释',
        },
      },
    });
    final nestedSettings = ReplyPersonalizationSettings.fromJson({
      'settings': {
        'replyPersonalizationSettings': {
          'gender': 'female',
          'memoryNotes': '少用感叹号',
        },
      },
    });

    expect(settings.isColloquialExpressionEnabled, isFalse);
    expect(settings.userGender, UserGender.male);
    expect(settings.userAgeText, '90 后');
    expect(settings.isConversationMemoryEnabled, isTrue);
    expect(settings.isAdaptiveStyleEnabled, isFalse);
    expect(settings.memoryNotes, '别连续追问');
    expect(settings.customStyles.single.name, '慢一点');
    expect(settings.customStyles.single.rules, ['短句', '少解释']);
    expect(nestedSettings.userGender, UserGender.female);
    expect(nestedSettings.memoryNotes, '少用感叹号');
  });

  test('API key paste helper trims usable clipboard text', () {
    expect(
      app_shell.pastedAPIKeyFromClipboardText('  sk-live-test \n'),
      'sk-live-test',
    );
    expect(app_shell.cleanAPIKeyInput('  sk-live-test \n'), 'sk-live-test');
    expect(app_shell.hasUsableAPIKey('  sk-live-test \n'), isTrue);
    expect(app_shell.pastedAPIKeyFromClipboardText('   '), isNull);
    expect(app_shell.cleanAPIKeyInput('   '), isNull);
    expect(app_shell.hasUsableAPIKey('   '), isFalse);
    expect(app_shell.pastedAPIKeyFromClipboardText(null), isNull);
    expect(app_shell.hasUsableAPIKey(null), isFalse);

    final feedbackSource =
        File('lib/core/app_feedback.dart').readAsStringSync();
    expect(feedbackSource, contains('cleanAPIKeyInput(String? value)'));
    expect(feedbackSource, contains('=> cleanNonEmptyText(value);'));
    expect(feedbackSource, isNot(contains('final trimmed = value?.trim();')));

    final transportSource =
        File('lib/core/api_transport.dart').readAsStringSync();
    final rulesSource =
        File('lib/core/api_config_rules.dart').readAsStringSync();
    final modelFetchSource =
        File('lib/core/app_state_model_fetching.dart').readAsStringSync();
    final storageSource =
        File('lib/core/storage_api_key.dart').readAsStringSync();
    final appSettingsSource =
        File('lib/core/app_state_api_settings.dart').readAsStringSync();
    expect(transportSource, contains('cleanAPIKeyInput(apiKey)'));
    expect(transportSource, contains('hasUsableAPIKey(apiKey)'));
    expect(transportSource, isNot(contains('apiKey.trim()')));
    expect(rulesSource, contains('hasUsableAPIKey(key)'));
    expect(rulesSource, contains("cleanAPIKeyInput(apiKey) ?? ''"));
    expect(rulesSource, isNot(contains('key.trim().isEmpty')));
    expect(modelFetchSource, contains("cleanAPIKeyInput(draftKey) ?? ''"));
    expect(modelFetchSource, contains('hasUsableAPIKey(draftKey)'));
    expect(modelFetchSource, isNot(contains('draftKey.trim()')));
    expect(
        storageSource, contains('final cleanedKey = cleanAPIKeyInput(key);'));
    expect(storageSource, contains('if (cleanedKey == null)'));
    expect(storageSource, isNot(contains('key.trim()')));
    expect(appSettingsSource,
        contains("apiKey = cleanAPIKeyInput(nextKey) ?? '';"));
    expect(appSettingsSource, isNot(contains('nextKey.trim()')));
  });

  test('API settings status filters keep feedback page-local like iOS', () {
    expect(app_shell.isAPISettingsStatusMessage('配置已保存'), isTrue);
    expect(
      app_shell.isAPISettingsStatusMessage(app_shell.apiKeyPasteSuccessMessage),
      isTrue,
    );
    expect(app_shell.isAPISettingsStatusMessage('已复制'), isFalse);
    expect(app_shell.isAPISettingsStatusMessage('背景已导入'), isFalse);
    expect(app_shell.isAPISettingsErrorMessage('配置已保存'), isFalse);
    expect(
        app_shell
            .isAPISettingsErrorMessage(app_shell.apiKeyPasteSuccessMessage),
        isFalse);
    expect(app_shell.isAPISettingsErrorMessage('请先输入聊天文本。'), isFalse);
    expect(app_shell.isAPISettingsErrorMessage('剪贴板里没有可用的 API Key。'), isTrue);
    expect(app_shell.isAPISettingsErrorMessage('视觉模型测试失败：请先标记模型'), isTrue);
    expect(app_shell.isAPISettingsErrorMessage('读取剪贴板失败：剪贴板不可用'), isTrue);
  });

  testWidgets('API generation sliders use shared config ranges',
      (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        app_shell.appProvider.overrideWith((ref) => AppController(
              store: FakeStore(),
            )),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: APIGenerationParametersSection(
              imageMaxWidth: APIConfig.defaults.imageMaxWidth,
              imageQuality: APIConfig.defaults.imageCompressionQuality,
              temperature: APIConfig.defaults.temperature,
              maxTokens: APIConfig.defaults.maxTokens.toDouble(),
              timeout: APIConfig.defaults.timeout.toDouble(),
              onImageMaxWidthChanged: (_) {},
              onImageQualityChanged: (_) {},
              onTemperatureChanged: (_) {},
              onMaxTokensChanged: (_) {},
              onTimeoutChanged: (_) {},
            ),
          ),
        ),
      ),
    ));

    final sliders = tester.widgetList<Slider>(find.byType(Slider)).toList();

    expect(sliders, hasLength(5));
    expect(sliders[0].min, APIConfig.imageMaxWidthMin);
    expect(sliders[0].max, APIConfig.imageMaxWidthMax);
    expect(sliders[1].min, APIConfig.imageCompressionQualityMin);
    expect(sliders[1].max, APIConfig.imageCompressionQualityMax);
    expect(sliders[2].min, APIConfig.temperatureMin);
    expect(sliders[2].max, APIConfig.temperatureMax);
    expect(sliders[3].min, APIConfig.maxTokensMin);
    expect(sliders[3].max, APIConfig.maxTokensMax);
    expect(sliders[4].min, APIConfig.timeoutMin);
    expect(sliders[4].max, APIConfig.timeoutMax);
  });

  testWidgets('API settings initializes generation draft from current config',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 1500));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final controller = AppController(store: FakeStore())
      ..config = APIConfig.defaults.copyWith(
        imageMaxWidth: 960,
        imageCompressionQuality: 0.55,
        temperature: 1.2,
        maxTokens: 1800,
        timeout: 45,
      );

    await tester.pumpWidget(ProviderScope(
      overrides: [
        app_shell.appProvider.overrideWith((ref) => controller),
      ],
      child: const MaterialApp(home: app_shell.ApiSettingsScreen()),
    ));
    await tester.scrollUntilVisible(
      find.textContaining('请求超时'),
      200,
      scrollable: find.byType(Scrollable).first,
    );

    final sliders = tester.widgetList<Slider>(find.byType(Slider)).toList();

    expect(sliders, hasLength(5));
    expect(sliders[0].value, 960);
    expect(sliders[1].value, 0.55);
    expect(sliders[2].value, 1.2);
    expect(sliders[3].value, 1800);
    expect(sliders[4].value, 45);
  });

  testWidgets('API settings model capability edits stay draft until saved',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final store = FakeStore();
    final controller = AppController(store: store)
      ..config = APIConfig.defaults.copyWith(
        visionModelName: 'plain-model',
        textModelName: 'plain-model',
        modelCapabilities: const {
          'plain-model': ModelCapability(),
        },
      )
      ..availableModels = const [APIModel(id: 'plain-model')];

    await tester.pumpWidget(ProviderScope(
      overrides: [
        app_shell.appProvider.overrideWith((ref) => controller),
      ],
      child: const MaterialApp(home: app_shell.ApiSettingsScreen()),
    ));

    await tester.tap(find.widgetWithText(FilterChip, '多模态'));
    await tester.pump();

    expect(controller.config.capability('plain-model').isMultimodal, isFalse);

    await tester.scrollUntilVisible(
      find.text('保存配置'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.ancestor(
      of: find.text('保存配置'),
      matching: find.byType(FilledButton),
    ));
    await tester.pump();

    expect(controller.config.capability('plain-model').isMultimodal, isTrue);
    expect(store.savedConfig!.capability('plain-model').isMultimodal, isTrue);
  });

  testWidgets('API settings capability chips use normalized model ids',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final controller = AppController(store: FakeStore())
      ..config = APIConfig.defaults.copyWith(
        visionModelName: 'QWEN2.5-VL-72B',
        textModelName: 'qwen2.5-vl-72b',
        modelCapabilities: const {
          'qwen2.5-vl-72b': ModelCapability(isMultimodal: true),
        },
      )
      ..availableModels = const [APIModel(id: 'QWEN2.5-VL-72B')];

    await tester.pumpWidget(ProviderScope(
      overrides: [
        app_shell.appProvider.overrideWith((ref) => controller),
      ],
      child: const MaterialApp(home: app_shell.ApiSettingsScreen()),
    ));

    final multimodalChip =
        tester.widget<FilterChip>(find.widgetWithText(FilterChip, '多模态'));

    expect(multimodalChip.selected, isTrue);
  });

  testWidgets(
      'model selector can mark manually selected models beyond list preview',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final updates = <String, ModelCapability>{};
    final models = List.generate(16, (index) => APIModel(id: 'model-$index'));

    await tester.pumpWidget(ProviderScope(
      child: MaterialApp(
        home: Scaffold(
          body: app_shell.ModelSelectCard(
            models: models,
            visionModel: 'manual-vision-model',
            textModel: 'model-15',
            onVision: (_) {},
            onText: (_) {},
            capabilityFor: (modelId) =>
                updates[modelId] ?? const ModelCapability(),
            onCapability: (modelId, {isMultimodal, isReasoning}) {
              final current = updates[modelId] ?? const ModelCapability();
              updates[modelId] = ModelCapability(
                isMultimodal: isMultimodal ?? current.isMultimodal,
                isReasoning: isReasoning ?? current.isReasoning,
              );
            },
          ),
        ),
      ),
    ));

    expect(find.text('当前视觉模型'), findsOneWidget);
    expect(find.text('manual-vision-model'), findsAtLeastNWidgets(1));
    expect(find.text('当前文本模型'), findsOneWidget);
    expect(find.text('model-15'), findsAtLeastNWidgets(1));

    await tester.tap(find.widgetWithText(FilterChip, '多模态').first);
    await tester.pump();

    expect(updates['manual-vision-model']?.isMultimodal, isTrue);
    expect(updates.containsKey('model-0'), isFalse);
  });

  testWidgets('model selector folds selected model ids through shared matcher',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(ProviderScope(
      child: MaterialApp(
        home: Scaffold(
          body: app_shell.ModelSelectCard(
            models: const [
              APIModel(id: ' qwen2.5-vl-72b '),
              APIModel(id: 'backup-model'),
            ],
            visionModel: ' QWEN2.5-VL-72B ',
            textModel: 'qwen2.5-vl-72b',
            onVision: (_) {},
            onText: (_) {},
            capabilityFor: (_) => const ModelCapability(),
            onCapability: (_, {isMultimodal, isReasoning}) {},
          ),
        ),
      ),
    ));

    expect(find.text('当前视觉/文本模型'), findsOneWidget);
    expect(find.text('当前视觉模型'), findsNothing);
    expect(find.text('当前文本模型'), findsNothing);
    expect(find.text(' qwen2.5-vl-72b '), findsNothing);
    expect(find.text('backup-model'), findsOneWidget);

    final source =
        File('lib/widgets/model_select_widgets.dart').readAsStringSync();
    expect(source, contains('final selectedValue = cleanModelId(value);'));
    expect(source, contains('return cleanModelId(model.displayTitle);'));
    expect(source, contains('final vision = cleanModelId(visionModel);'));
    expect(source, contains('final text = cleanModelId(textModel);'));
    expect(source, isNot(contains('.trim()')));
  });

  testWidgets('model selector titles use normalized model metadata',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(ProviderScope(
      child: MaterialApp(
        home: Scaffold(
          body: app_shell.ModelSelectCard(
            models: const [
              APIModel(id: 'text-embedding-3-large'),
              APIModel(id: 'backup-model'),
            ],
            visionModel: ' TEXT-EMBEDDING-3-LARGE ',
            textModel: 'backup-model',
            onVision: (_) {},
            onText: (_) {},
            capabilityFor: (_) => const ModelCapability(),
            onCapability: (_, {isMultimodal, isReasoning}) {},
          ),
        ),
      ),
    ));

    expect(find.text('text-embedding-3-large · 非聊天'), findsOneWidget);
    expect(find.text(' TEXT-EMBEDDING-3-LARGE '), findsNothing);
  });

  testWidgets('API settings clears fetched models when draft key changes',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final controller = AppController(store: FakeStore())
      ..apiKey = 'sk-old'
      ..availableModels = const [
        APIModel(id: 'gpt-4o-mini'),
        APIModel(id: 'qwen2.5-vl-72b'),
      ];

    await tester.pumpWidget(ProviderScope(
      overrides: [
        app_shell.appProvider.overrideWith((ref) => controller),
      ],
      child: const MaterialApp(home: app_shell.ApiSettingsScreen()),
    ));

    expect(find.byType(app_shell.ModelSelectCard), findsOneWidget);

    final keyField = find.byWidgetPredicate(
      (widget) =>
          widget is TextField && widget.decoration?.labelText == 'API Key',
    );
    await tester.enterText(keyField, '');
    await tester.pump();

    expect(controller.availableModels, isEmpty);
    expect(find.byType(app_shell.ModelSelectCard), findsNothing);
  });

  testWidgets('stale API settings model fetch cannot overwrite edited draft',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final api = DeferredModelsApi();
    final controller = AppController(
      store: FakeStore(),
      api: api,
    )..apiKey = 'sk-test';

    await tester.pumpWidget(ProviderScope(
      overrides: [
        app_shell.appProvider.overrideWith((ref) => controller),
      ],
      child: const MaterialApp(home: app_shell.ApiSettingsScreen()),
    ));
    await tester.pump();
    expect(controller.isFetchingModels, isTrue);

    final textField = find.byWidgetPredicate(
      (widget) =>
          widget is TextField && widget.decoration?.labelText == '文本模型名称',
    );
    await tester.enterText(textField, 'manual-text-model');
    await tester.pump();

    api.completer.complete(const [
      APIModel(id: 'gpt-4o-mini'),
      APIModel(id: 'qwen2.5-vl-72b'),
    ]);
    await tester.pumpAndSettle();

    final editedTextField = tester.widget<TextField>(textField);
    expect(editedTextField.controller?.text, 'manual-text-model');
    expect(controller.availableModels.map((model) => model.id),
        ['gpt-4o-mini', 'qwen2.5-vl-72b']);
    expect(controller.isFetchingModels, isFalse);
  });

  testWidgets('API settings model fetch button follows iOS readiness gate',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final controller = AppController(store: FakeStore());

    await tester.pumpWidget(ProviderScope(
      overrides: [
        app_shell.appProvider.overrideWith((ref) => controller),
      ],
      child: const MaterialApp(home: app_shell.ApiSettingsScreen()),
    ));

    FilledButton fetchButton() => tester.widget<FilledButton>(find.ancestor(
          of: find.text('自动拉取模型列表'),
          matching: find.byType(FilledButton),
        ));

    expect(fetchButton().onPressed, isNull);

    final keyField = find.byWidgetPredicate(
      (widget) =>
          widget is TextField && widget.decoration?.labelText == 'API Key',
    );
    await tester.enterText(keyField, 'sk-test');
    await tester.pump();

    expect(fetchButton().onPressed, isNotNull);
  });

  test('API settings draft helpers preserve editor state', () {
    final source = APIConfig.defaults.copyWith(
      baseURL: 'https://old.example/v1',
      textModelName: 'old-text',
      visionModelName: 'old-vision',
    );
    final draft = apiSettingsDraftConfigFrom(
      source: source,
      baseURL: ' https://api.example/v1 ',
      visionModelName: ' vision-model ',
      textModelName: ' text-model ',
      modelCapabilities: const {
        'vision-model': ModelCapability(isMultimodal: true),
      },
      imageMaxWidth: 1536,
      imageCompressionQuality: 0.75,
      enableImageInput: false,
      enableTwoStepVision: true,
      temperature: 0.65,
      maxTokens: 888.6,
      timeout: 42.2,
    );

    expect(draft.baseURL, ' https://api.example/v1 ');
    expect(draft.visionModelName, ' vision-model ');
    expect(draft.textModelName, ' text-model ');
    expect(draft.modelCapabilities['vision-model']?.isMultimodal, isTrue);
    expect(draft.imageMaxWidth, 1536);
    expect(draft.imageCompressionQuality, 0.75);
    expect(draft.enableImageInput, isFalse);
    expect(draft.enableTwoStepVision, isTrue);
    expect(draft.temperature, 0.65);
    expect(draft.maxTokens, 889);
    expect(draft.timeout, 42);

    final updated = apiSettingsDraftCapabilitiesWith(
      draft.modelCapabilities,
      ' vision-model ',
      isReasoning: true,
    );
    expect(updated, isNot(same(draft.modelCapabilities)));
    expect(updated['vision-model']?.isMultimodal, isTrue);
    expect(updated['vision-model']?.isReasoning, isTrue);
    expect(
      apiSettingsDraftCapabilitiesWith(updated, '未知'),
      same(updated),
    );
  });

  test('API settings action helper centralizes button readiness', () {
    final readyConfig = APIConfig.defaults.copyWith(
      baseURL: ' https://api.example/v1 ',
      textModelName: ' gpt-4o-mini ',
      visionModelName: ' gpt-4o ',
      modelCapabilities: const {
        'gpt-4o': ModelCapability(isMultimodal: true),
      },
    );

    final ready = apiSettingsActionState(
      draftConfig: readyConfig,
      apiKey: ' sk-test ',
      isFetchingModels: false,
      isTestingConnection: false,
      isTestingVision: false,
    );

    expect(ready.normalizedDraftConfig.baseURL, 'https://api.example/v1');
    expect(ready.hasUsableKey, isTrue);
    expect(ready.canFetchModels, isTrue);
    expect(ready.canRunConnectionTest, isTrue);
    expect(ready.canTestVisionModel, isTrue);

    expect(
      apiSettingsActionState(
        draftConfig: readyConfig,
        apiKey: '',
        isFetchingModels: false,
        isTestingConnection: false,
        isTestingVision: false,
      ).canRunConnectionTest,
      isFalse,
    );
    expect(
      apiSettingsActionState(
        draftConfig: readyConfig.copyWith(textModelName: '未知'),
        apiKey: 'sk-test',
        isFetchingModels: false,
        isTestingConnection: false,
        isTestingVision: false,
      ).canRunConnectionTest,
      isFalse,
    );
    expect(
      apiSettingsActionState(
        draftConfig: readyConfig,
        apiKey: 'sk-test',
        isFetchingModels: true,
        isTestingConnection: false,
        isTestingVision: false,
      ).canRunConnectionTest,
      isFalse,
    );
    expect(
      apiSettingsActionState(
        draftConfig: readyConfig,
        apiKey: 'sk-test',
        isFetchingModels: false,
        isTestingConnection: false,
        isTestingVision: true,
      ).canFetchModels,
      isFalse,
    );
    expect(
      apiSettingsActionState(
        draftConfig: readyConfig.copyWith(visionModelName: 'whisper-1'),
        apiKey: 'sk-test',
        isFetchingModels: false,
        isTestingConnection: false,
        isTestingVision: false,
      ).canTestVisionModel,
      isFalse,
    );
    expect(
      apiSettingsActionState(
        draftConfig: readyConfig.copyWith(enableImageInput: false),
        apiKey: 'sk-test',
        isFetchingModels: false,
        isTestingConnection: false,
        isTestingVision: false,
      ).canTestVisionModel,
      isFalse,
    );
  });

  testWidgets('API settings connection test follows required fields gate',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final controller = AppController(store: FakeStore());

    await tester.pumpWidget(ProviderScope(
      overrides: [
        app_shell.appProvider.overrideWith((ref) => controller),
      ],
      child: const MaterialApp(home: app_shell.ApiSettingsScreen()),
    ));

    OutlinedButton connectionButton() =>
        tester.widget<OutlinedButton>(find.ancestor(
          of: find.text('测试连接'),
          matching: find.byType(OutlinedButton),
        ));

    await tester.scrollUntilVisible(
      find.text('测试连接'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(connectionButton().onPressed, isNull);

    final keyField = find.byWidgetPredicate(
      (widget) =>
          widget is TextField && widget.decoration?.labelText == 'API Key',
    );
    await tester.enterText(keyField, 'sk-test');
    await tester.pump();
    expect(connectionButton().onPressed, isNotNull);

    final textField = find.byWidgetPredicate(
      (widget) =>
          widget is TextField && widget.decoration?.labelText == '文本模型名称',
    );
    await tester.enterText(textField, '未知');
    await tester.pump();
    expect(connectionButton().onPressed, isNull);

    await tester.enterText(textField, 'gpt-4o-mini');
    await tester.pump();
    expect(connectionButton().onPressed, isNotNull);
  });

  testWidgets('API settings disables connection test while vision is testing',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final controller = AppController(
      store: FakeStore(),
      api: FakeModelsApi(const []),
    )
      ..apiKey = 'sk-test'
      ..availableModels = const [APIModel(id: 'gpt-4o-mini')]
      ..isTestingVision = true;

    await tester.pumpWidget(ProviderScope(
      overrides: [
        app_shell.appProvider.overrideWith((ref) => controller),
      ],
      child: const MaterialApp(home: app_shell.ApiSettingsScreen()),
    ));
    await tester.scrollUntilVisible(
      find.text('测试连接'),
      200,
      scrollable: find.byType(Scrollable).first,
    );

    final connectionButton = tester.widget<OutlinedButton>(find.ancestor(
      of: find.text('测试连接'),
      matching: find.byType(OutlinedButton),
    ));
    expect(connectionButton.onPressed, isNull);
  });

  testWidgets('API settings disables vision test while connection is testing',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final controller = AppController(
      store: FakeStore(),
      api: FakeModelsApi(const []),
    )
      ..apiKey = 'sk-test'
      ..availableModels = const [APIModel(id: 'gpt-4o-mini')]
      ..isTestingConnection = true;

    await tester.pumpWidget(ProviderScope(
      overrides: [
        app_shell.appProvider.overrideWith((ref) => controller),
      ],
      child: const MaterialApp(home: app_shell.ApiSettingsScreen()),
    ));
    await tester.scrollUntilVisible(
      find.text('测试视觉模型'),
      200,
      scrollable: find.byType(Scrollable).first,
    );

    final visionButton = tester.widget<OutlinedButton>(find.ancestor(
      of: find.text('测试视觉模型'),
      matching: find.byType(OutlinedButton),
    ));
    expect(visionButton.onPressed, isNull);
  });

  testWidgets('API settings vision test rejects non chat model ids',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final controller = AppController(store: FakeStore())
      ..apiKey = 'sk-test'
      ..config = APIConfig.defaults.copyWith(
        visionModelName: 'whisper-1',
        textModelName: 'gpt-4o-mini',
        modelCapabilities: const {
          'whisper-1': ModelCapability(isMultimodal: true),
          'gpt-4o-mini': ModelCapability(isMultimodal: true),
        },
      );

    await tester.pumpWidget(ProviderScope(
      overrides: [
        app_shell.appProvider.overrideWith((ref) => controller),
      ],
      child: const MaterialApp(home: app_shell.ApiSettingsScreen()),
    ));
    await tester.scrollUntilVisible(
      find.text('测试视觉模型'),
      200,
      scrollable: find.byType(Scrollable).first,
    );

    OutlinedButton visionButton() =>
        tester.widget<OutlinedButton>(find.ancestor(
          of: find.text('测试视觉模型'),
          matching: find.byType(OutlinedButton),
        ));

    expect(visionButton().onPressed, isNull);

    final visionField = find.byWidgetPredicate(
      (widget) =>
          widget is TextField && widget.decoration?.labelText == '视觉模型名称',
    );
    await tester.enterText(visionField, 'gpt-4o-mini');
    await tester.pump();
    await tester.scrollUntilVisible(
      find.text('测试视觉模型'),
      200,
      scrollable: find.byType(Scrollable).first,
    );

    expect(visionButton().onPressed, isNotNull);
  });

  testWidgets('API settings save reads current manual model field values',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final store = FakeStore();
    final controller = AppController(store: store);

    await tester.pumpWidget(ProviderScope(
      overrides: [
        app_shell.appProvider.overrideWith((ref) => controller),
      ],
      child: const MaterialApp(home: app_shell.ApiSettingsScreen()),
    ));

    final visionField = find.byWidgetPredicate(
      (widget) =>
          widget is TextField && widget.decoration?.labelText == '视觉模型名称',
    );
    final textField = find.byWidgetPredicate(
      (widget) =>
          widget is TextField && widget.decoration?.labelText == '文本模型名称',
    );

    await tester.enterText(visionField, 'manual-vision-model');
    await tester.enterText(textField, 'manual-text-model');
    await tester.scrollUntilVisible(
      find.text('保存配置'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.ancestor(
      of: find.text('保存配置'),
      matching: find.byType(FilledButton),
    ));
    await tester.pump();

    expect(store.savedConfig!.visionModelName, 'manual-vision-model');
    expect(store.savedConfig!.textModelName, 'manual-text-model');
  });

  test('API settings manual model fields refresh local readiness state', () {
    final source =
        File('lib/screens/api_settings_screen.dart').readAsStringSync();
    final visionFieldStart = source.indexOf("label: '视觉模型名称'");
    final textFieldStart = source.indexOf("label: '文本模型名称'");
    final nextSectionStart =
        source.indexOf('GlassCard(\n            tint:', textFieldStart);

    expect(visionFieldStart, isNonNegative);
    expect(textFieldStart, greaterThan(visionFieldStart));
    expect(nextSectionStart, greaterThan(textFieldStart));
    expect(
      source.substring(visionFieldStart, textFieldStart),
      contains('onChanged: (_) => _updateDraftState()'),
    );
    expect(
      source.substring(textFieldStart, nextSectionStart),
      contains('onChanged: (_) => _updateDraftState()'),
    );
  });

  test('API settings model fetch paths share draft sync helper', () {
    final source =
        File('lib/screens/api_settings_screen.dart').readAsStringSync();
    final autoStart = source.indexOf('Future<void> _autoFetchModelsIfReady()');
    final manualStart = source.indexOf('Future<void> _fetchModelsNow()');
    final buildStart = source.indexOf('@override\n  Widget build', manualStart);
    final helperStart = source.indexOf('void _applyFetchedModelsConfig');

    expect(autoStart, isNonNegative);
    expect(manualStart, greaterThan(autoStart));
    expect(buildStart, greaterThan(manualStart));
    expect(helperStart, greaterThan(buildStart));

    final autoBody = source.substring(autoStart, manualStart);
    final manualBody = source.substring(manualStart, buildStart);
    final helperBody = source.substring(helperStart);

    expect(autoBody, contains('_applyFetchedModelsConfig(fetchedConfig)'));
    expect(manualBody, contains('_applyFetchedModelsConfig(fetchedConfig)'));
    expect(autoBody, contains('final requestDraftRevision = draftRevision;'));
    expect(manualBody, contains('final requestDraftRevision = draftRevision;'));
    expect(autoBody, contains('if (!_isCurrentDraftRevision'));
    expect(manualBody, contains('if (!_isCurrentDraftRevision'));
    expect(helperBody, contains('vision.text = config.visionModelName'));
    expect(helperBody, contains('text.text = config.textModelName'));
    expect(helperBody, contains('config.modelCapabilities'));
    expect(source, contains('void _markDraftChanged()'));
    expect(source, contains('bool _isCurrentDraftRevision'));
  });

  test('API settings auto fetch microtask checks mounted before provider read',
      () {
    final source =
        File('lib/screens/api_settings_screen.dart').readAsStringSync();
    final screenStart = source.indexOf('class _ApiSettingsScreenState');
    final initStart = source.indexOf('void initState()', screenStart);
    final disposeStart = source.indexOf('void dispose()', initStart);

    expect(screenStart, isNonNegative);
    expect(initStart, greaterThan(screenStart));
    expect(disposeStart, greaterThan(initStart));

    final initSource = source.substring(initStart, disposeStart);
    final microtaskStart = initSource.indexOf('Future.microtask(() {');
    final microtaskEnd = initSource.indexOf('});', microtaskStart);
    final microtaskSource = initSource.substring(microtaskStart, microtaskEnd);
    final mountedGuard = microtaskSource.indexOf('if (!mounted) return;');
    final providerRead = microtaskSource.indexOf('ref.read(appProvider)');

    expect(microtaskStart, isNonNegative);
    expect(microtaskEnd, greaterThan(microtaskStart));
    expect(mountedGuard, isNonNegative);
    expect(providerRead, greaterThan(mountedGuard));
  });

  testWidgets('API settings ignores unrelated global feedback messages',
      (tester) async {
    final controller = AppController(store: FakeStore())
      ..statusMessage = '已复制'
      ..errorMessage = '请先输入聊天文本。';

    await tester.pumpWidget(ProviderScope(
      overrides: [
        app_shell.appProvider.overrideWith((ref) => controller),
      ],
      child: const MaterialApp(home: app_shell.ApiSettingsScreen()),
    ));

    expect(find.text('已复制'), findsNothing);
    expect(find.text('请先输入聊天文本。'), findsNothing);
    expect(find.text('API 设置'), findsOneWidget);
  });

  testWidgets('API settings displays cleaned scoped feedback messages',
      (tester) async {
    final controller = AppController(store: FakeStore())
      ..statusMessage = '  配置已保存  '
      ..errorMessage = '  读取剪贴板失败：剪贴板不可用  ';

    await tester.pumpWidget(ProviderScope(
      overrides: [
        app_shell.appProvider.overrideWith((ref) => controller),
      ],
      child: const MaterialApp(home: app_shell.ApiSettingsScreen()),
    ));
    await tester.scrollUntilVisible(
      find.text('配置已保存'),
      220,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.scrollUntilVisible(
      find.text('读取剪贴板失败：剪贴板不可用'),
      220,
      scrollable: find.byType(Scrollable).first,
    );

    expect(find.text('配置已保存'), findsOneWidget);
    expect(find.text('读取剪贴板失败：剪贴板不可用'), findsOneWidget);
    expect(find.text('  配置已保存  '), findsNothing);
    expect(find.text('  读取剪贴板失败：剪贴板不可用  '), findsNothing);

    final source =
        File('lib/screens/api_settings_screen.dart').readAsStringSync();
    expect(source, contains('final visibleStatusMessage ='));
    expect(source, contains('cleanFeedbackMessage(app.statusMessage)'));
    expect(source, contains('cleanFeedbackMessage(app.errorMessage)'));
    expect(source, contains('SuccessBanner(visibleStatusMessage)'));
    expect(source, contains('ErrorBanner(visibleErrorMessage)'));
    expect(source, isNot(contains('app.statusMessage!.trim()')));
    expect(source, isNot(contains('app.errorMessage!.trim()')));
  });

  test('destructive actions share the confirmation dialog helper', () {
    final helperSource =
        File('lib/widgets/glass_feedback_widgets.dart').readAsStringSync();

    expect(helperSource, contains('Future<bool> showConfirmationDialog('));

    for (final path in [
      'lib/screens/api_settings_screen.dart',
      'lib/screens/history_people_screens.dart',
      'lib/screens/privacy_screen.dart',
    ]) {
      final source = File(path).readAsStringSync();

      expect(source, contains('showConfirmationDialog('), reason: path);
      expect(source, isNot(contains('showDialog<bool>(')), reason: path);
      expect(source, isNot(contains('AlertDialog(')), reason: path);
    }
  });

  testWidgets('API settings reset requires confirmation like iOS',
      (tester) async {
    final controller = AppController(store: FakeStore())
      ..apiKey = 'sk-live-before-reset'
      ..config = APIConfig.defaults.copyWith(
        baseURL: 'https://api.example/v1',
        textModelName: 'custom-text-model',
      );

    await tester.pumpWidget(ProviderScope(
      overrides: [
        app_shell.appProvider.overrideWith((ref) => controller),
      ],
      child: const MaterialApp(home: app_shell.ApiSettingsScreen()),
    ));

    await tester.scrollUntilVisible(
      find.widgetWithText(OutlinedButton, '恢复默认并清除 Key'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.widgetWithText(OutlinedButton, '恢复默认并清除 Key'));
    await tester.pumpAndSettle();

    expect(find.text('恢复默认配置？'), findsOneWidget);
    expect(controller.apiKey, 'sk-live-before-reset');
    expect(controller.config.baseURL, 'https://api.example/v1');

    await tester.tap(find.widgetWithText(FilledButton, '恢复默认并清除 Key'));
    await tester.pumpAndSettle();

    expect(controller.apiKey, isEmpty);
    expect(controller.config.baseURL, APIConfig.defaults.baseURL);
    expect(controller.config.textModelName, APIConfig.defaults.textModelName);
  });

  testWidgets('generation page clears stale feedback from other pages',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final controller = AppController(store: FakeStore())
      ..statusMessage = '配置已保存'
      ..errorMessage = '测试连接失败';

    await tester.pumpWidget(ProviderScope(
      overrides: [
        app_shell.appProvider.overrideWith((ref) => controller),
      ],
      child: const MaterialApp(home: app_shell.TextInputScreen()),
    ));

    expect(controller.statusMessage, isNull);
    expect(controller.errorMessage, isNull);
    expect(find.text('配置已保存'), findsNothing);
    expect(find.text('测试连接失败'), findsNothing);

    controller.setError('请先输入聊天文本。');
    await tester.pump();

    expect(find.text('请先输入聊天文本。'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  test('image share handoff resets even when already displayed', () {
    final source =
        File('lib/screens/image_generation_screens.dart').readAsStringSync();
    final scheduleStart = source.indexOf('void _schedulePendingSharedImage');
    final consumeIndex =
        source.indexOf('consumeSharedImagePath()', scheduleStart);
    final scheduleEnd =
        source.indexOf('void _scheduleClipboardFeedbackReset', scheduleStart);

    expect(scheduleStart, isNot(-1));
    expect(scheduleEnd, greaterThan(scheduleStart));
    expect(consumeIndex, isNot(-1));
    final methodSource = source.substring(scheduleStart, scheduleEnd);

    expect(
        methodSource, isNot(contains('if (sharedPath == imagePath) return')));
    expect(methodSource, contains('if (sharedPath != imagePath)'));
    expect(methodSource, contains('goal.clear();'));
  });

  test('image share handoff resets mounted image page draft controls', () {
    final source =
        File('lib/screens/image_generation_screens.dart').readAsStringSync();
    final scheduleStart = source.indexOf('void _schedulePendingSharedImage');
    final scheduleEnd =
        source.indexOf('void _scheduleClipboardFeedbackReset', scheduleStart);

    expect(scheduleStart, isNot(-1));
    expect(scheduleEnd, greaterThan(scheduleStart));
    final methodSource = source.substring(scheduleStart, scheduleEnd);

    expect(methodSource, contains('final controller = ref.read(appProvider);'));
    expect(methodSource, contains('goal.clear();'));
    expect(methodSource, contains('style = controller.currentStyle;'));
    expect(methodSource,
        contains('selectedProfileId = restorableScreenProfileId(controller);'));
  });

  testWidgets('floating guide requires accessibility before starting overlay',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    const floatingChannel = MethodChannel('ai_reply/floating');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(floatingChannel, (call) async {
      return switch (call.method) {
        'hasOverlayPermission' => true,
        'hasNotificationPermission' => true,
        'isAccessibilityEnabled' => false,
        _ => null,
      };
    });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(floatingChannel, null);
    });
    final controller = AppController(store: FakeStore())..apiKey = 'sk-test';

    await tester.pumpWidget(ProviderScope(
      overrides: [
        app_shell.appProvider.overrideWith((ref) => controller),
      ],
      child: const MaterialApp(home: app_shell.FloatingGuideScreen()),
    ));
    await tester.pumpAndSettle();

    expect(find.text('悬浮截图必需'), findsOneWidget);
    expect(find.text('快捷入口可用'), findsNothing);
    expect(find.text('快捷回复配置可用'), findsOneWidget);
    expect(
      find.textContaining('默认使用 MediaProjection 系统授权'),
      findsNothing,
    );
    final startButtonFinder = find.widgetWithText(FilledButton, '启动悬浮窗');
    await tester.scrollUntilVisible(
      startButtonFinder,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    final startButton = tester.widget<FilledButton>(startButtonFinder);
    expect(startButton.onPressed, isNull);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('floating guide exposes style selection for floating replies',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    const floatingChannel = MethodChannel('ai_reply/floating');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(floatingChannel, (call) async {
      return switch (call.method) {
        'hasOverlayPermission' => true,
        'hasNotificationPermission' => true,
        'isAccessibilityEnabled' => true,
        _ => null,
      };
    });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(floatingChannel, null);
    });
    final controller = AppController(store: FakeStore())..apiKey = 'sk-test';

    await tester.pumpWidget(ProviderScope(
      overrides: [
        app_shell.appProvider.overrideWith((ref) => controller),
      ],
      child: const MaterialApp(home: app_shell.FloatingGuideScreen()),
    ));
    await tester.pumpAndSettle();

    expect(find.text('悬浮窗回复风格'), findsOneWidget);
    expect(find.text('当前：自然'), findsOneWidget);

    await tester.tap(find.text('松弛'));
    await tester.pumpAndSettle();

    expect(controller.defaultStyle.name, '松弛');
    expect(find.text('当前：松弛'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  test('floating background capture generation uses selected default style',
      () {
    final source = File('lib/app_shell.dart').readAsStringSync();
    final handlerStart = source.indexOf('Future<void> _handleFloatingCapture');
    final disposeStart =
        source.indexOf('@override\n  void dispose()', handlerStart);

    expect(handlerStart, isNot(-1));
    expect(disposeStart, greaterThan(handlerStart));
    final handlerSource = source.substring(handlerStart, disposeStart);

    expect(handlerSource, contains('final selectedStyle = app.defaultStyle;'));
    expect(
        handlerSource, contains('app.generateImage(imagePath, selectedStyle'));
    expect(handlerSource, isNot(contains('ChatStyle.defaultStyle')));
  });

  testWidgets('floating guide reports permission bridge failures',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    const floatingChannel = MethodChannel('ai_reply/floating');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(floatingChannel, (call) async {
      if (call.method == 'hasOverlayPermission') {
        throw PlatformException(code: 'missing', message: '悬浮窗桥接不可用');
      }
      return null;
    });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(floatingChannel, null);
    });
    final controller = AppController(store: FakeStore())..apiKey = 'sk-test';

    await tester.pumpWidget(ProviderScope(
      overrides: [
        app_shell.appProvider.overrideWith((ref) => controller),
      ],
      child: const MaterialApp(home: app_shell.FloatingGuideScreen()),
    ));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.textContaining('权限状态读取失败：悬浮窗桥接不可用'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.textContaining('权限状态读取失败：悬浮窗桥接不可用'), findsOneWidget);
    expect(find.text('未授权'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('floating guide reports quick url clipboard failure',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    const floatingChannel = MethodChannel('ai_reply/floating');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(floatingChannel, (call) async {
      return switch (call.method) {
        'hasOverlayPermission' => true,
        'hasNotificationPermission' => true,
        'isAccessibilityEnabled' => true,
        _ => null,
      };
    });
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        throw PlatformException(code: 'clipboard', message: '剪贴板不可用');
      }
      return null;
    });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(floatingChannel, null);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });
    final controller = AppController(store: FakeStore())..apiKey = 'sk-test';

    await tester.pumpWidget(ProviderScope(
      overrides: [
        app_shell.appProvider.overrideWith((ref) => controller),
      ],
      child: const MaterialApp(home: app_shell.FloatingGuideScreen()),
    ));
    await tester.pumpAndSettle();

    final copyButtonFinder = find.widgetWithText(TextButton, '复制');
    await tester.scrollUntilVisible(
      copyButtonFinder,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(copyButtonFinder);
    await tester.pump();

    expect(find.text('复制备用 URL 失败：剪贴板不可用'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('floating guide reports floating startup failure',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    const floatingChannel = MethodChannel('ai_reply/floating');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(floatingChannel, (call) async {
      return switch (call.method) {
        'hasOverlayPermission' => true,
        'hasNotificationPermission' => true,
        'isAccessibilityEnabled' => true,
        'startFloatingWindow' =>
          throw PlatformException(code: 'service', message: '前台服务启动失败'),
        _ => null,
      };
    });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(floatingChannel, null);
    });
    final controller = AppController(store: FakeStore())..apiKey = 'sk-test';

    await tester.pumpWidget(ProviderScope(
      overrides: [
        app_shell.appProvider.overrideWith((ref) => controller),
      ],
      child: const MaterialApp(home: app_shell.FloatingGuideScreen()),
    ));
    await tester.pumpAndSettle();

    final startButtonFinder = find.widgetWithText(FilledButton, '启动悬浮窗');
    await tester.scrollUntilVisible(
      startButtonFinder,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(startButtonFinder);
    await tester.pumpAndSettle();
    await tester.tap(startButtonFinder);
    await tester.pump();

    expect(find.text('启动悬浮窗失败：前台服务启动失败'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('floating guide reports permission action failures',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    const floatingChannel = MethodChannel('ai_reply/floating');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(floatingChannel, (call) async {
      return switch (call.method) {
        'hasOverlayPermission' => false,
        'hasNotificationPermission' => false,
        'isAccessibilityEnabled' => false,
        'openOverlaySettings' =>
          throw PlatformException(code: 'overlay', message: '无法打开悬浮窗设置'),
        'requestNotificationPermission' =>
          throw PlatformException(code: 'notice', message: '通知授权不可用'),
        'openAccessibilitySettings' =>
          throw PlatformException(code: 'access', message: '无法打开无障碍设置'),
        'stopFloatingWindow' =>
          throw PlatformException(code: 'stop', message: '服务停止失败'),
        _ => null,
      };
    });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(floatingChannel, null);
    });
    final controller = AppController(store: FakeStore())..apiKey = 'sk-test';

    await tester.pumpWidget(ProviderScope(
      overrides: [
        app_shell.appProvider.overrideWith((ref) => controller),
      ],
      child: const MaterialApp(home: app_shell.FloatingGuideScreen()),
    ));
    await tester.pumpAndSettle();
    Future<void> dismissSnack() async {
      final context =
          tester.element(find.byType(app_shell.FloatingGuideScreen));
      ScaffoldMessenger.of(context).clearSnackBars();
      await tester.pumpAndSettle();
    }

    await tester.tap(find.text('授权悬浮窗'));
    await tester.pump();
    expect(find.text('打开悬浮窗权限失败：无法打开悬浮窗设置'), findsOneWidget);
    await dismissSnack();

    await tester.tap(find.text('开启通知权限'));
    await tester.pump();
    expect(find.text('请求通知权限失败：通知授权不可用'), findsOneWidget);
    await dismissSnack();

    await tester.tap(find.text('开启无障碍增强'));
    await tester.pump();
    expect(find.text('打开无障碍设置失败：无法打开无障碍设置'), findsOneWidget);
    await dismissSnack();

    final stopButtonFinder = find.widgetWithText(OutlinedButton, '关闭悬浮窗');
    await tester.scrollUntilVisible(
      stopButtonFinder,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(stopButtonFinder);
    await tester.pump();
    expect(find.text('关闭悬浮窗失败：服务停止失败'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  test('floating startup has no stale secondary settings sheet', () {
    final source =
        File('lib/screens/floating_guide_screen.dart').readAsStringSync();

    expect(source, isNot(contains('FloatingSettingsSheet')));
    expect(source, isNot(contains('显示悬浮窗')));
    expect(source, contains('readiness.isReady && overlay && accessibility'));
  });

  test('floating guide does not expose android input method actions', () {
    final floatingSource =
        File('lib/screens/floating_guide_screen.dart').readAsStringSync();
    final bridgeSource =
        File('lib/core/platform_bridge.dart').readAsStringSync();

    expect(floatingSource, isNot(contains('AI Reply 键盘入口')));
    expect(floatingSource, isNot(contains('打开输入法设置')));
    expect(floatingSource, isNot(contains('切换输入法')));
    expect(
      floatingSource,
      isNot(contains('FloatingCaptureBridge.openInputMethodSettings()')),
    );
    expect(
      floatingSource,
      isNot(contains('FloatingCaptureBridge.showInputMethodPicker()')),
    );
    expect(
      bridgeSource,
      isNot(contains("_method.invokeMethod('openInputMethodSettings')")),
    );
    expect(
      bridgeSource,
      isNot(contains("_method.invokeMethod('showInputMethodPicker')")),
    );
  });

  test('floating guide resumes startup after accessibility setup', () {
    final source =
        File('lib/screens/floating_guide_screen.dart').readAsStringSync();
    final overlayStart = source.indexOf('Future<void> _openOverlaySettings()');
    final methodStart =
        source.indexOf('Future<void> _openAccessibilitySettings()');
    final nextMethodStart =
        source.indexOf('Future<void> _startFloatingWindow()', methodStart);

    expect(overlayStart, isNonNegative);
    expect(methodStart, isNonNegative);
    expect(nextMethodStart, greaterThan(methodStart));
    final overlayMethodSource = source.substring(overlayStart, methodStart);
    final methodSource = source.substring(methodStart, nextMethodStart);
    expect(overlayMethodSource,
        contains('shouldStartFloatingAfterPermission = !overlay'));
    expect(methodSource,
        contains('shouldStartFloatingAfterPermission = !accessibility'));
    expect(
        methodSource, contains('shouldStartFloatingAfterPermission = false'));
    expect(
      methodSource,
      contains('FloatingCaptureBridge.openAccessibilitySettings()'),
    );
    expect(
      methodSource,
      contains('await _refreshStatus(autoStartWhenReady: true)'),
    );
    expect(methodSource, isNot(contains('await _refresh();')));
  });

  testWidgets('API settings paste key shows iOS-style success feedback',
      (tester) async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.getData') {
        return <String, dynamic>{'text': '  sk-live-success  '};
      }
      return null;
    });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });
    final controller = AppController(store: FakeStore())
      ..statusMessage = null
      ..errorMessage = '旧错误';

    await tester.pumpWidget(ProviderScope(
      overrides: [
        app_shell.appProvider.overrideWith((ref) => controller),
      ],
      child: const MaterialApp(home: app_shell.ApiSettingsScreen()),
    ));

    await tester.tap(find.text('粘贴 Key'));
    await tester.pump();

    expect(find.text('已粘贴'), findsOneWidget);
    final keyField = tester.widget<TextField>(find.byWidgetPredicate(
      (widget) =>
          widget is TextField && widget.decoration?.labelText == 'API Key',
    ));
    expect(keyField.controller?.text, 'sk-live-success');
    expect(controller.statusMessage, app_shell.apiKeyPasteSuccessMessage);
    expect(controller.errorMessage, isNull);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('API settings paste key reports an empty clipboard',
      (tester) async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.getData') {
        return <String, dynamic>{'text': '   '};
      }
      return null;
    });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });
    final controller = AppController(store: FakeStore())
      ..statusMessage = '旧成功'
      ..errorMessage = null;

    await tester.pumpWidget(ProviderScope(
      overrides: [
        app_shell.appProvider.overrideWith((ref) => controller),
      ],
      child: const MaterialApp(home: app_shell.ApiSettingsScreen()),
    ));

    await tester.tap(find.text('粘贴 Key'));
    await tester.pump();

    expect(find.text('已粘贴'), findsNothing);
    expect(controller.statusMessage, isNull);
    expect(controller.errorMessage, app_shell.apiKeyPasteEmptyMessage);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('API settings empty paste clears stale success feedback',
      (tester) async {
    var clipboardText = '  sk-live-success  ';
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.getData') {
        return <String, dynamic>{'text': clipboardText};
      }
      return null;
    });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });
    final controller = AppController(store: FakeStore());

    await tester.pumpWidget(ProviderScope(
      overrides: [
        app_shell.appProvider.overrideWith((ref) => controller),
      ],
      child: const MaterialApp(home: app_shell.ApiSettingsScreen()),
    ));

    await tester.tap(find.text('粘贴 Key'));
    await tester.pump();

    expect(find.text('已粘贴'), findsOneWidget);

    clipboardText = '   ';
    await tester.tap(find.text('已粘贴'));
    await tester.pump();

    expect(find.text('已粘贴'), findsNothing);
    expect(find.text('粘贴 Key'), findsOneWidget);
    expect(controller.statusMessage, isNull);
    expect(controller.errorMessage, app_shell.apiKeyPasteEmptyMessage);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('API settings paste key reports clipboard read failures',
      (tester) async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.getData') {
        throw PlatformException(code: 'clipboard', message: '剪贴板不可用');
      }
      return null;
    });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });
    final controller = AppController(store: FakeStore())
      ..statusMessage = '旧成功'
      ..errorMessage = null;

    await tester.pumpWidget(ProviderScope(
      overrides: [
        app_shell.appProvider.overrideWith((ref) => controller),
      ],
      child: const MaterialApp(home: app_shell.ApiSettingsScreen()),
    ));

    await tester.tap(find.text('粘贴 Key'));
    await tester.pump();

    expect(find.text('已粘贴'), findsNothing);
    expect(controller.statusMessage, isNull);
    expect(controller.errorMessage, '读取剪贴板失败：剪贴板不可用');
    expect(
        app_shell.isAPISettingsErrorMessage(controller.errorMessage), isTrue);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('Personalization add style button follows iOS name validation',
      (tester) async {
    final controller = AppController(store: FakeStore());

    await tester.pumpWidget(ProviderScope(
      overrides: [
        app_shell.appProvider.overrideWith((ref) => controller),
      ],
      child: const MaterialApp(home: app_shell.PersonalizationScreen()),
    ));
    await tester.scrollUntilVisible(
      find.text('添加风格'),
      500,
      scrollable: find.byType(Scrollable).first,
    );

    OutlinedButton addButton() => tester.widget<OutlinedButton>(find.ancestor(
          of: find.text('添加风格'),
          matching: find.byType(OutlinedButton),
        ));

    expect(addButton().onPressed, isNull);

    final nameField = find.byWidgetPredicate(
      (widget) => widget is TextField && widget.decoration?.labelText == '风格名称',
    );
    final descriptionField = find.byWidgetPredicate(
      (widget) => widget is TextField && widget.decoration?.labelText == '风格描述',
    );
    final rulesField = find.byWidgetPredicate(
      (widget) => widget is TextField && widget.decoration?.labelText == '规则',
    );
    await tester.enterText(nameField, '未知');
    await tester.pump();

    expect(addButton().onPressed, isNull);

    await tester.enterText(nameField, '  我平时说话  ');
    await tester.enterText(descriptionField, '未知');
    await tester.enterText(rulesField, '  短一点，少问  \n未知\n ');
    await tester.pump();

    expect(addButton().onPressed, isNotNull);

    await tester.tap(find.ancestor(
      of: find.text('添加风格'),
      matching: find.byType(OutlinedButton),
    ));
    await tester.pump();

    expect(controller.personalization.customStyles.single.name, '我平时说话');
    expect(controller.personalization.customStyles.single.description,
        '按我的日常聊天习惯生成');
    expect(controller.personalization.customStyles.single.rules, ['短一点', '少问']);
    expect(addButton().onPressed, isNull);
  });

  testWidgets('StylePicker labels custom styles like iOS cards',
      (tester) async {
    final customStyle = ChatStyle(
      name: '我平时说话',
      description: '短句、轻松',
      rules: const ['少问'],
      isOfficial: false,
    );

    await tester.pumpWidget(ProviderScope(
      overrides: [
        app_shell.appProvider.overrideWith((ref) => AppController()),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: app_shell.StylePicker(
            selected: customStyle,
            styles: [customStyle],
            onChanged: (_) {},
          ),
        ),
      ),
    ));

    expect(find.text('我平时说话'), findsOneWidget);
    expect(find.text('自定义'), findsOneWidget);
  });

  testWidgets('settings personalization entry and page title match iOS copy',
      (tester) async {
    final controller = AppController(store: FakeStore());

    await tester.pumpWidget(ProviderScope(
      overrides: [
        app_shell.appProvider.overrideWith((ref) => controller),
      ],
      child: const MaterialApp(home: app_shell.SettingsScreen()),
    ));

    expect(find.text('设置中心'), findsNothing);

    await tester.scrollUntilVisible(
      find.text('个性化回复'),
      500,
      scrollable: find.byType(Scrollable).first,
    );

    expect(find.text('个性化回复'), findsOneWidget);
    expect(find.text('个性化设置'), findsNothing);

    await tester.pumpWidget(ProviderScope(
      overrides: [
        app_shell.appProvider.overrideWith((ref) => controller),
      ],
      child: const MaterialApp(home: app_shell.PersonalizationScreen()),
    ));

    expect(find.text('个性化回复'), findsOneWidget);
    expect(find.text('个性化设置'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('generation page titles match iOS navigation copy',
      (tester) async {
    final controller = AppController(store: FakeStore());

    await tester.pumpWidget(ProviderScope(
      overrides: [
        app_shell.appProvider.overrideWith((ref) => controller),
      ],
      child: const MaterialApp(home: app_shell.ImageInputScreen()),
    ));

    expect(find.text('截图生成'), findsOneWidget);
    expect(find.text('选择截图'), findsNothing);

    await tester.pumpWidget(ProviderScope(
      overrides: [
        app_shell.appProvider.overrideWith((ref) => controller),
      ],
      child: const MaterialApp(home: app_shell.TextInputScreen()),
    ));

    expect(find.text('文本生成'), findsOneWidget);
    expect(find.text('粘贴文本'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('Personalization flushes pending draft on page dispose like iOS',
      (tester) async {
    final store = FakeStore();
    final controller = AppController(store: store);

    await tester.pumpWidget(ProviderScope(
      overrides: [
        app_shell.appProvider.overrideWith((ref) => controller),
      ],
      child: const MaterialApp(home: app_shell.PersonalizationScreen()),
    ));

    final memoryField = find.byWidgetPredicate(
      (widget) => widget is TextField && widget.decoration?.labelText == '手动记忆',
    );
    await tester.scrollUntilVisible(
      memoryField,
      500,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.enterText(memoryField, '  刚输入就返回也要保存  ');
    await tester.pump();

    expect(controller.personalization.memoryNotes, isEmpty);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();

    expect(controller.personalization.memoryNotes, '刚输入就返回也要保存');
    expect(store.savedPersonalization?.memoryNotes, '刚输入就返回也要保存');
  });

  testWidgets('Text input screen restores editable result source state',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final controller = AppController(store: FakeStore())
      ..apiKey = 'key'
      ..profiles = [
        PersonProfile(id: 'target', displayName: '小林'),
      ]
      ..currentInputType = ChatInputType.text
      ..currentStyle = ChatStyle.presets[1]
      ..currentGoal = '轻松一点'
      ..currentTextInput = '对方：晚上吃啥'
      ..currentSelectedProfileId = ' target ';

    await tester.pumpWidget(ProviderScope(
      overrides: [
        app_shell.appProvider.overrideWith((ref) => controller),
      ],
      child: const MaterialApp(home: app_shell.TextInputScreen()),
    ));

    final chatField = find.byWidgetPredicate(
      (widget) => widget is TextField && widget.decoration?.labelText == '聊天内容',
    );
    final goalField = find.byWidgetPredicate(
      (widget) => widget is TextField && widget.decoration?.labelText == '我的目标',
    );

    expect(tester.widget<TextField>(chatField).controller?.text, '对方：晚上吃啥');
    expect(tester.widget<TextField>(goalField).controller?.text, '轻松一点');
    expect(find.text('将按「小林」制定回复。'), findsOneWidget);
  });

  testWidgets('Text input paste shows transient iOS-style success feedback',
      (tester) async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.getData') {
        return <String, dynamic>{'text': '  对方：明天见  '};
      }
      return null;
    });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });
    final controller = AppController(store: FakeStore());

    await tester.pumpWidget(ProviderScope(
      overrides: [
        app_shell.appProvider.overrideWith((ref) => controller),
      ],
      child: const MaterialApp(home: app_shell.TextInputScreen()),
    ));

    await tester.tap(find.text('粘贴'));
    await tester.pump();

    final chatField = tester.widget<TextField>(find.byWidgetPredicate(
      (widget) => widget is TextField && widget.decoration?.labelText == '聊天内容',
    ));
    expect(chatField.controller?.text, '对方：明天见');
    expect(find.text('已粘贴'), findsOneWidget);
    expect(find.text('剪贴板里没有可用文本。'), findsNothing);

    await tester.pump(const Duration(milliseconds: 1200));
    expect(find.text('粘贴'), findsOneWidget);
  });

  testWidgets('text input edits clear stale global feedback like iOS',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.getData') {
        return <String, dynamic>{'text': '  对方：明天见  '};
      }
      return null;
    });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });
    final controller = AppController(store: FakeStore());

    await tester.pumpWidget(ProviderScope(
      overrides: [
        app_shell.appProvider.overrideWith((ref) => controller),
      ],
      child: const MaterialApp(home: app_shell.TextInputScreen()),
    ));

    final chatField = find.byWidgetPredicate(
      (widget) => widget is TextField && widget.decoration?.labelText == '聊天内容',
    );

    controller.setError('旧生成错误');
    await tester.pump();
    expect(find.text('旧生成错误'), findsOneWidget);

    await tester.tap(find.text('粘贴'));
    await tester.pump();
    expect(controller.errorMessage, isNull);
    expect(find.text('旧生成错误'), findsNothing);

    controller.setError('旧粘贴后错误');
    await tester.pump();
    await tester.enterText(chatField, '我：好的');
    await tester.pump();
    expect(controller.errorMessage, isNull);
    expect(find.text('旧粘贴后错误'), findsNothing);

    controller.setError('旧清空前错误');
    await tester.pump();
    await tester.tap(find.byTooltip('清空文本'));
    await tester.pump();
    expect(controller.errorMessage, isNull);
    expect(find.text('旧清空前错误'), findsNothing);
    expect(tester.widget<TextField>(chatField).controller?.text, isEmpty);
  });

  testWidgets('text generation options clear stale global feedback',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final controller = AppController(store: FakeStore())
      ..profiles = [
        PersonProfile(id: 'target', displayName: '小林'),
      ];

    await tester.pumpWidget(ProviderScope(
      overrides: [
        app_shell.appProvider.overrideWith((ref) => controller),
      ],
      child: const MaterialApp(home: app_shell.TextInputScreen()),
    ));

    controller.setError('旧风格错误');
    await tester.pump();
    await tester.tap(find.text(ChatStyle.presets[1].name).first);
    await tester.pump();
    expect(controller.errorMessage, isNull);
    expect(find.text('旧风格错误'), findsNothing);

    controller.setError('旧目标错误');
    await tester.pump();
    await tester.tap(find.text('自然接话'));
    await tester.pump();
    expect(controller.errorMessage, isNull);
    expect(find.text('旧目标错误'), findsNothing);

    controller.setError('旧对象错误');
    await tester.pump();
    await tester.tap(find.text('小林').first);
    await tester.pump();
    expect(controller.errorMessage, isNull);
    expect(find.text('旧对象错误'), findsNothing);
  });

  testWidgets('image generation options clear stale global feedback',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 1800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final controller = AppController(store: FakeStore())
      ..profiles = [
        PersonProfile(id: 'target', displayName: '小林'),
      ];
    final goal = TextEditingController();
    addTearDown(goal.dispose);
    var selectedStyle = ChatStyle.defaultStyle;
    String? selectedProfileId;

    await tester.pumpWidget(ProviderScope(
      overrides: [
        app_shell.appProvider.overrideWith((ref) => controller),
      ],
      child: MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) => app_shell.GenerateImageShell(
            title: '截图生成',
            isQuickReply: false,
            imagePath: null,
            goal: goal,
            style: selectedStyle,
            onStyle: (next) => setState(() => selectedStyle = next),
            selectedProfileId: selectedProfileId,
            onProfileChanged: (next) =>
                setState(() => selectedProfileId = next),
            onPick: () {},
            onClearImage: () {},
            onCaptureScreen: null,
            onReadClipboard: null,
            onGenerate: null,
          ),
        ),
      ),
    ));

    controller.setError('旧图片风格错误');
    await tester.pump();
    await tester.ensureVisible(find.text(ChatStyle.presets[1].name).first);
    await tester.tap(find.text(ChatStyle.presets[1].name).first);
    await tester.pump();
    expect(controller.errorMessage, isNull);
    expect(find.text('旧图片风格错误'), findsNothing);

    controller.setError('旧图片目标错误');
    await tester.pump();
    final goalField = find.byWidgetPredicate(
      (widget) => widget is TextField && widget.decoration?.labelText == '我的目标',
    );
    await tester.ensureVisible(goalField);
    await tester.enterText(goalField, '自然一点');
    await tester.pump();
    expect(controller.errorMessage, isNull);
    expect(find.text('旧图片目标错误'), findsNothing);

    controller.setError('旧图片对象错误');
    await tester.pump();
    await tester.ensureVisible(find.text('小林').first);
    await tester.tap(find.text('小林').first);
    await tester.pump();
    expect(controller.errorMessage, isNull);
    expect(find.text('旧图片对象错误'), findsNothing);
  });

  testWidgets('Text input paste reports clipboard read failures',
      (tester) async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.getData') {
        throw PlatformException(code: 'clipboard', message: '剪贴板不可用');
      }
      return null;
    });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });
    final controller = AppController(store: FakeStore());

    await tester.pumpWidget(ProviderScope(
      overrides: [
        app_shell.appProvider.overrideWith((ref) => controller),
      ],
      child: const MaterialApp(home: app_shell.TextInputScreen()),
    ));

    await tester.tap(find.text('粘贴'));
    await tester.pump();

    final chatField = tester.widget<TextField>(find.byWidgetPredicate(
      (widget) => widget is TextField && widget.decoration?.labelText == '聊天内容',
    ));
    expect(chatField.controller?.text, isEmpty);
    expect(find.text('已粘贴'), findsNothing);
    expect(find.text('读取剪贴板失败：剪贴板不可用'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 1800));
    expect(find.text('读取剪贴板失败：剪贴板不可用'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
      'Text input empty clipboard feedback clears like iOS paste message',
      (tester) async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.getData') {
        return <String, dynamic>{'text': '   '};
      }
      return null;
    });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });

    await tester.pumpWidget(const ProviderScope(
      child: MaterialApp(home: app_shell.TextInputScreen()),
    ));

    await tester.tap(find.text('粘贴'));
    await tester.pump();

    expect(find.text('剪贴板里没有可用文本。'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 1800));
    expect(find.text('剪贴板里没有可用文本。'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('Moment profile clipboard button mirrors iOS read feedback',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Column(
        children: [
          app_shell.MomentProfileClipboardButton(
            isReadingClipboard: false,
            didReadClipboard: false,
            onPressed: () {},
          ),
          app_shell.MomentProfileClipboardButton(
            isReadingClipboard: false,
            didReadClipboard: false,
            compact: true,
            onPressed: () {},
          ),
          app_shell.MomentProfileClipboardButton(
            isReadingClipboard: false,
            didReadClipboard: true,
            onPressed: () {},
          ),
        ],
      ),
    ));

    expect(find.text('读取剪贴板截图'), findsOneWidget);
    expect(find.text('剪贴板'), findsOneWidget);
    expect(find.text('已读取'), findsOneWidget);
  });

  testWidgets('Image input clipboard controls show iOS-style read feedback',
      (tester) async {
    var tapped = 0;
    await tester.pumpWidget(MaterialApp(
      home: Column(
        children: [
          app_shell.GenerateImageClipboardButton(
            isReadingClipboard: false,
            didReadClipboard: true,
            onPressed: () => tapped += 1,
          ),
          app_shell.GenerateImageClipboardButton(
            isReadingClipboard: false,
            didReadClipboard: false,
            compact: true,
            onPressed: () => tapped += 1,
          ),
          app_shell.GenerateImageClipboardButton(
            isReadingClipboard: true,
            didReadClipboard: false,
            onPressed: () => tapped += 1,
          ),
        ],
      ),
    ));

    expect(find.text('已读取'), findsOneWidget);
    expect(find.text('剪贴板'), findsOneWidget);
    expect(find.text('读取剪贴板截图'), findsOneWidget);

    await tester.tap(find.text('剪贴板'));
    await tester.tap(find.text('读取剪贴板截图'));

    expect(tapped, 1);
  });

  test('image clipboard readers report empty clipboard like iOS image input',
      () {
    expect(
        app_shell.noClipboardScreenshotMessage, '剪贴板里没有可用截图。请先截屏并复制，或使用相册选择。');
    final mainSource =
        File('lib/screens/image_generation_screens.dart').readAsStringSync();
    final momentSource =
        File('lib/screens/moment_profile_screen.dart').readAsStringSync();

    void expectClipboardReaderReportsEmptyClipboard({
      required String source,
      required String className,
      required String methodSignature,
      required String classEndMarker,
    }) {
      final classStart = source.indexOf(className);
      expect(classStart, isNonNegative);

      final methodStart = source.indexOf(methodSignature, classStart);
      expect(methodStart, greaterThan(classStart));

      final methodEnd =
          source.indexOf('void _clearClipboardReadFeedback()', methodStart);
      expect(methodEnd, greaterThan(methodStart));

      final classEnd = classEndMarker.isEmpty
          ? source.length
          : source.indexOf(classEndMarker, methodStart);
      expect(classEnd, greaterThan(methodStart));

      final classBody = source.substring(classStart, classEnd);
      final methodBody = source.substring(methodStart, methodEnd);

      expect(classBody, contains('void _clearClipboardReadFeedback()'));
      expect(methodBody, contains('} else {'));
      expect(methodBody, contains('_clearClipboardReadFeedback();'));
      expect(methodBody, contains('setError(noClipboardScreenshotMessage)'));
      if (className == 'class _QuickReplyScreenState') {
        expect(methodBody, contains('clearPendingQuickAutoGenerate()'));
      }
      expect(
        methodBody,
        contains('catch (error) {\n      _clearClipboardReadFeedback();'),
      );
    }

    expectClipboardReaderReportsEmptyClipboard(
      source: mainSource,
      className: 'class _ImageInputScreenState',
      methodSignature: 'Future<void> _readClipboardImage() async',
      classEndMarker: 'class QuickReplyScreen',
    );
    expectClipboardReaderReportsEmptyClipboard(
      source: mainSource,
      className: 'class _QuickReplyScreenState',
      methodSignature:
          'Future<void> _readClipboardImage({bool autoGenerate = true}) async',
      classEndMarker: '',
    );
    expectClipboardReaderReportsEmptyClipboard(
      source: momentSource,
      className: 'class _MomentProfileScreenState',
      methodSignature: 'Future<void> _readClipboardImage() async',
      classEndMarker: '',
    );
  });

  test('image inputs clear stale global errors when a new screenshot is ready',
      () {
    final source =
        File('lib/screens/image_generation_screens.dart').readAsStringSync();

    String methodBody({
      required String className,
      required String methodSignature,
      required String endMarker,
    }) {
      final classStart = source.indexOf(className);
      expect(classStart, isNonNegative);
      final methodStart = source.indexOf(methodSignature, classStart);
      expect(methodStart, greaterThan(classStart));
      final methodEnd = source.indexOf(endMarker, methodStart);
      expect(methodEnd, greaterThan(methodStart));
      return source.substring(methodStart, methodEnd);
    }

    final imagePick = methodBody(
      className: 'class _ImageInputScreenState',
      methodSignature: 'Future<void> _pick() async',
      endMarker: 'Future<void> _readClipboardImage() async',
    );
    final imageClipboard = methodBody(
      className: 'class _ImageInputScreenState',
      methodSignature: 'Future<void> _readClipboardImage() async',
      endMarker: 'void _schedulePendingSharedImage',
    );
    final quickCapture = methodBody(
      className: 'class _QuickReplyScreenState',
      methodSignature: 'Future<void> _captureCurrentScreen() async',
      endMarker:
          'Future<void> _readClipboardImage({bool autoGenerate = true}) async',
    );
    final quickClipboard = methodBody(
      className: 'class _QuickReplyScreenState',
      methodSignature:
          'Future<void> _readClipboardImage({bool autoGenerate = true}) async',
      endMarker: 'void _clearClipboardReadFeedback()',
    );

    for (final body in [
      imagePick,
      imageClipboard,
      quickCapture,
      quickClipboard,
    ]) {
      expect(body, contains('clearFeedback(notify: false)'));
    }

    expect(imagePick.indexOf('clearFeedback(notify: false)'),
        lessThan(imagePick.indexOf('setState(() {')));
    expect(imageClipboard.indexOf('clearFeedback(notify: false)'),
        lessThan(imageClipboard.indexOf('setState(() {')));
    expect(quickCapture.indexOf('clearFeedback(notify: false)'),
        lessThan(quickCapture.indexOf('setQuickImagePath(')));
    expect(quickClipboard.indexOf('clearFeedback(notify: false)'),
        lessThan(quickClipboard.indexOf('setQuickImagePath(')));
  });

  test('async UI handoffs check mounted before provider or state use', () {
    final source = File('lib/main.dart').readAsStringSync();
    final imageGenerationSource =
        File('lib/screens/image_generation_screens.dart').readAsStringSync();
    final apiSettingsSource =
        File('lib/screens/api_settings_screen.dart').readAsStringSync();
    final momentSource =
        File('lib/screens/moment_profile_screen.dart').readAsStringSync();
    final textInputSource =
        File('lib/screens/text_input_screen.dart').readAsStringSync();

    String methodBody({
      String? sourceOverride,
      required String className,
      required String methodSignature,
      required String endMarker,
    }) {
      final effectiveSource = sourceOverride ?? source;
      final classStart = effectiveSource.indexOf(className);
      expect(classStart, isNonNegative);
      final methodStart = effectiveSource.indexOf(methodSignature, classStart);
      expect(methodStart, greaterThan(classStart));
      final methodEnd = effectiveSource.indexOf(endMarker, methodStart);
      expect(methodEnd, greaterThan(methodStart));
      return effectiveSource.substring(methodStart, methodEnd);
    }

    void expectGuardBefore(String body, String guard, String laterUse) {
      final guardIndex = body.indexOf(guard);
      final useIndex = body.indexOf(laterUse, guardIndex + guard.length);
      expect(guardIndex, isNonNegative);
      expect(useIndex, greaterThan(guardIndex));
    }

    final imagePick = methodBody(
      sourceOverride: imageGenerationSource,
      className: 'class _ImageInputScreenState',
      methodSignature: 'Future<void> _pick() async',
      endMarker: 'Future<void> _readClipboardImage() async',
    );
    expectGuardBefore(
      imagePick,
      'if (!mounted) return;',
      'ref.read(appProvider)',
    );

    final quickCapture = methodBody(
      sourceOverride: imageGenerationSource,
      className: 'class _QuickReplyScreenState',
      methodSignature: 'Future<void> _captureCurrentScreen() async',
      endMarker:
          'Future<void> _readClipboardImage({bool autoGenerate = true}) async',
    );
    expectGuardBefore(
      quickCapture,
      'if (!mounted) return;',
      'ref.read(appProvider)',
    );

    final quickClipboard = methodBody(
      sourceOverride: imageGenerationSource,
      className: 'class _QuickReplyScreenState',
      methodSignature:
          'Future<void> _readClipboardImage({bool autoGenerate = true}) async',
      endMarker: 'void _clearClipboardReadFeedback()',
    );
    expectGuardBefore(
      quickClipboard,
      'if (!mounted) return;',
      'ref.read(appProvider)',
    );

    final textPaste = methodBody(
      sourceOverride: textInputSource,
      className: 'class _TextInputScreenState',
      methodSignature: 'Future<void> _pasteClipboardText() async',
      endMarker: 'void _schedulePendingSharedText',
    );
    expectGuardBefore(
      textPaste,
      'if (!mounted) return;',
      'ref.read(appProvider)',
    );

    final momentPick = methodBody(
      sourceOverride: momentSource,
      className: 'class _MomentProfileScreenState',
      methodSignature: 'Future<void> _pick() async',
      endMarker: 'Future<void> _readClipboardImage() async',
    );
    expectGuardBefore(
      momentPick,
      'if (!mounted) return;',
      'ref.read(appProvider)',
    );

    final apiSettingsStart =
        apiSettingsSource.indexOf('class _ApiSettingsScreenState');
    expect(apiSettingsStart, isNonNegative);
    final apiPasteStart = apiSettingsSource.indexOf(
      'data = await Clipboard.getData(Clipboard.kTextPlain);',
      apiSettingsStart,
    );
    final apiPasteEnd = apiSettingsSource.indexOf(
      'final pastedKey = pastedAPIKeyFromClipboardText(data?.text);',
      apiPasteStart,
    );
    expect(apiPasteStart, isNonNegative);
    expect(apiPasteEnd, greaterThan(apiPasteStart));
    final apiPasteBeforeKey =
        apiSettingsSource.substring(apiPasteStart, apiPasteEnd);
    expectGuardBefore(
      apiPasteBeforeKey,
      'if (!mounted) return;',
      'ref.read(appProvider)',
    );
  });

  test('chat completions base url is not duplicated', () async {
    final paths = <String>[];
    final dio = _fakeDio(
      paths: paths,
      responses: const [
        _FakeApiResponse(200, {
          'choices': [
            {
              'message': {
                'content':
                    '{"sceneSummary":"ok","replies":[{"text":"收到","styleLabel":"自然"}]}',
              },
            },
          ],
        }),
      ],
    );
    final config = APIConfig.defaults
        .copyWith(baseURL: 'https://api.example/v1/chat/completions');

    final response =
        await OpenAICompatibleApi(dioFactory: (_) => dio).generateReplyFromText(
      '你好',
      ChatStyle.defaultStyle,
      null,
      null,
      null,
      config,
      'sk-test',
    );

    expect(paths, ['/v1/chat/completions']);
    expect(response.replies.single.text, '收到');
  });

  test('chat completions accepts delta and text content aliases', () async {
    final paths = <String>[];
    final dio = _fakeDio(
      paths: paths,
      responses: const [
        _FakeApiResponse(200, {
          'choices': [
            {
              'delta': {
                'content':
                    '{"sceneSummary":"delta","replies":[{"text":"先这样","styleLabel":"自然"}]}',
              },
            },
          ],
        }),
        _FakeApiResponse(200, {
          'choices': [
            {
              'text':
                  '{"sceneSummary":"text","replies":[{"text":"再看看","styleLabel":"自然"}]}',
            },
          ],
        }),
      ],
    );
    final api = OpenAICompatibleApi(dioFactory: (_) => dio);

    final deltaReply = await api.generateReplyFromText(
      '对方：明天呢',
      ChatStyle.defaultStyle,
      null,
      null,
      null,
      APIConfig.defaults,
      'sk-test',
    );
    final textReply = await api.generateReplyFromText(
      '对方：后天呢',
      ChatStyle.defaultStyle,
      null,
      null,
      null,
      APIConfig.defaults,
      'sk-test',
    );

    expect(paths, ['/v1/chat/completions', '/v1/chat/completions']);
    expect(deltaReply.sceneSummary, 'delta');
    expect(deltaReply.replies.single.text, '先这样');
    expect(textReply.sceneSummary, 'text');
    expect(textReply.replies.single.text, '再看看');
  });

  test('chat completions accepts list content text parts', () async {
    final paths = <String>[];
    final dio = _fakeDio(
      paths: paths,
      responses: const [
        _FakeApiResponse(200, {
          'choices': [
            {
              'message': {
                'content': [
                  {
                    'type': 'text',
                    'text': {
                      'value':
                          '  {"sceneSummary":"list","replies":[{"text":"列表文本","styleLabel":"自然"}]}  ',
                    },
                  },
                ],
              },
            },
          ],
        }),
      ],
    );

    final response =
        await OpenAICompatibleApi(dioFactory: (_) => dio).generateReplyFromText(
      '对方：你怎么看',
      ChatStyle.defaultStyle,
      null,
      null,
      null,
      APIConfig.defaults,
      'sk-test',
    );

    expect(paths, ['/v1/chat/completions']);
    expect(response.sceneSummary, 'list');
    expect(response.replies.single.text, '列表文本');

    final serviceSource = File('lib/core/api_service.dart').readAsStringSync();
    final contentSource =
        File('lib/core/api_content_text_helpers.dart').readAsStringSync();
    expect(serviceSource, contains("import 'text_cleaning.dart';"));
    expect(contentSource, contains('return cleanNonEmptyText(text);'));
    expect(contentSource, isNot(contains('final trimmed = text.trim();')));
    expect(contentSource, isNot(contains('trimmed.isEmpty ? null : text')));
  });

  test('chat completions accepts normalized response content keys', () async {
    final paths = <String>[];
    final dio = _fakeDio(
      paths: paths,
      responses: const [
        _FakeApiResponse(200, {
          'choices': [
            {
              'message': {
                'message_text':
                    '{"sceneSummary":"message key","replies":[{"text":"收到变体","styleLabel":"自然"}]}',
              },
            },
          ],
        }),
        _FakeApiResponse(200, {
          'choices': [
            {
              'output-text':
                  '{"sceneSummary":"choice key","replies":[{"text":"顶层变体","styleLabel":"自然"}]}',
            },
          ],
        }),
        _FakeApiResponse(200, {
          'choices': [
            {
              'message': {
                'payload': {
                  'result':
                      '{"sceneSummary":"wrapped key","replies":[{"text":"包装变体","styleLabel":"自然"}]}',
                },
              },
            },
          ],
        }),
      ],
    );
    final api = OpenAICompatibleApi(dioFactory: (_) => dio);

    final messageKey = await api.generateReplyFromText(
      '对方：现在方便吗',
      ChatStyle.defaultStyle,
      null,
      null,
      null,
      APIConfig.defaults,
      'sk-test',
    );
    final choiceKey = await api.generateReplyFromText(
      '对方：再确认下',
      ChatStyle.defaultStyle,
      null,
      null,
      null,
      APIConfig.defaults,
      'sk-test',
    );
    final wrappedKey = await api.generateReplyFromText(
      '对方：包装返回',
      ChatStyle.defaultStyle,
      null,
      null,
      null,
      APIConfig.defaults,
      'sk-test',
    );

    expect(paths, [
      '/v1/chat/completions',
      '/v1/chat/completions',
      '/v1/chat/completions',
    ]);
    expect(messageKey.sceneSummary, 'message key');
    expect(messageKey.replies.single.text, '收到变体');
    expect(choiceKey.sceneSummary, 'choice key');
    expect(choiceKey.replies.single.text, '顶层变体');
    expect(wrappedKey.sceneSummary, 'wrapped key');
    expect(wrappedKey.replies.single.text, '包装变体');
  });

  test('chat completions unwraps provider response envelopes', () async {
    final paths = <String>[];
    final dio = _fakeDio(
      paths: paths,
      responses: const [
        _FakeApiResponse(200, {
          'data': {
            'choices': [
              {
                'message': {
                  'content':
                      '{"sceneSummary":"data envelope","replies":[{"text":"数据包裹","styleLabel":"自然"}]}',
                },
              },
            ],
          },
        }),
        _FakeApiResponse(200, {
          'payload': {
            'result': {
              'choices': [
                {
                  'message': {
                    'content':
                        '{"sceneSummary":"nested envelope","replies":[{"text":"多层包裹","styleLabel":"自然"}]}',
                  },
                },
              ],
            },
          },
        }),
        _FakeApiResponse(200, {
          'message': {
            'content':
                '{"sceneSummary":"direct message","replies":[{"text":"直接消息","styleLabel":"自然"}]}',
          },
        }),
      ],
    );
    final api = OpenAICompatibleApi(dioFactory: (_) => dio);

    final dataEnvelope = await api.generateReplyFromText(
      '对方：现在呢',
      ChatStyle.defaultStyle,
      null,
      null,
      null,
      APIConfig.defaults,
      'sk-test',
    );
    final nestedEnvelope = await api.generateReplyFromText(
      '对方：还有吗',
      ChatStyle.defaultStyle,
      null,
      null,
      null,
      APIConfig.defaults,
      'sk-test',
    );
    final directMessage = await api.generateReplyFromText(
      '对方：直接返回',
      ChatStyle.defaultStyle,
      null,
      null,
      null,
      APIConfig.defaults,
      'sk-test',
    );

    expect(paths, [
      '/v1/chat/completions',
      '/v1/chat/completions',
      '/v1/chat/completions',
    ]);
    expect(dataEnvelope.sceneSummary, 'data envelope');
    expect(dataEnvelope.replies.single.text, '数据包裹');
    expect(nestedEnvelope.sceneSummary, 'nested envelope');
    expect(nestedEnvelope.replies.single.text, '多层包裹');
    expect(directMessage.sceneSummary, 'direct message');
    expect(directMessage.replies.single.text, '直接消息');
  });

  test('chat completions accepts structured parsed content keys', () async {
    final paths = <String>[];
    final dio = _fakeDio(
      paths: paths,
      responses: const [
        _FakeApiResponse(200, {
          'choices': [
            {
              'message': {
                'parsed': {
                  'sceneSummary': 'parsed key',
                  'replies': [
                    {'text': '结构化解析', 'styleLabel': '自然'}
                  ],
                },
              },
            },
          ],
        }),
        _FakeApiResponse(200, {
          'choices': [
            {
              'message': {
                'json': {
                  'sceneSummary': 'json key',
                  'replies': [
                    {'text': '结构化 JSON', 'styleLabel': '自然'}
                  ],
                },
              },
            },
          ],
        }),
        _FakeApiResponse(200, {
          'choices': [
            {
              'delta': {
                'structured_content': {
                  'sceneSummary': 'delta structured',
                  'replies': [
                    {'text': '增量结构化', 'styleLabel': '自然'}
                  ],
                },
              },
            },
          ],
        }),
      ],
    );
    final api = OpenAICompatibleApi(dioFactory: (_) => dio);

    final parsed = await api.generateReplyFromText(
      '对方：你觉得呢',
      ChatStyle.defaultStyle,
      null,
      null,
      null,
      APIConfig.defaults,
      'sk-test',
    );
    final json = await api.generateReplyFromText(
      '对方：那这样呢',
      ChatStyle.defaultStyle,
      null,
      null,
      null,
      APIConfig.defaults,
      'sk-test',
    );
    final delta = await api.generateReplyFromText(
      '对方：还有别的吗',
      ChatStyle.defaultStyle,
      null,
      null,
      null,
      APIConfig.defaults,
      'sk-test',
    );

    expect(paths, [
      '/v1/chat/completions',
      '/v1/chat/completions',
      '/v1/chat/completions',
    ]);
    expect(parsed.sceneSummary, 'parsed key');
    expect(parsed.replies.single.text, '结构化解析');
    expect(json.sceneSummary, 'json key');
    expect(json.replies.single.text, '结构化 JSON');
    expect(delta.sceneSummary, 'delta structured');
    expect(delta.replies.single.text, '增量结构化');
  });

  test('chat completions scans later choices for usable content', () async {
    final paths = <String>[];
    final dio = _fakeDio(
      paths: paths,
      responses: const [
        _FakeApiResponse(200, {
          'choices': [
            {
              'message': {'content': '   '},
              'finish_reason': 'content_filter',
            },
            {
              'message': {
                'content':
                    '{"sceneSummary":"second choice","replies":[{"text":"读到第二个","styleLabel":"自然"}]}',
              },
            },
          ],
        }),
        _FakeApiResponse(200, {
          'choices': [
            {
              'delta': {'content': ''},
            },
            {
              'delta': {
                'structured_content': {
                  'sceneSummary': 'second delta',
                  'replies': [
                    {'text': '增量第二个', 'styleLabel': '自然'}
                  ],
                },
              },
            },
          ],
        }),
      ],
    );
    final api = OpenAICompatibleApi(dioFactory: (_) => dio);

    final messageChoice = await api.generateReplyFromText(
      '对方：还有方案吗',
      ChatStyle.defaultStyle,
      null,
      null,
      null,
      APIConfig.defaults,
      'sk-test',
    );
    final deltaChoice = await api.generateReplyFromText(
      '对方：再想想',
      ChatStyle.defaultStyle,
      null,
      null,
      null,
      APIConfig.defaults,
      'sk-test',
    );

    expect(paths, ['/v1/chat/completions', '/v1/chat/completions']);
    expect(messageChoice.sceneSummary, 'second choice');
    expect(messageChoice.replies.single.text, '读到第二个');
    expect(deltaChoice.sceneSummary, 'second delta');
    expect(deltaChoice.replies.single.text, '增量第二个');
  });

  test('chat completions accepts tool call argument content', () async {
    final paths = <String>[];
    final dio = _fakeDio(
      paths: paths,
      responses: const [
        _FakeApiResponse(200, {
          'choices': [
            {
              'message': {
                'tool_calls': [
                  {
                    'function': {
                      'arguments':
                          '{"sceneSummary":"tool","replies":[{"text":"工具参数","styleLabel":"自然"}]}',
                    },
                  },
                ],
              },
            },
          ],
        }),
        _FakeApiResponse(200, {
          'choices': [
            {
              'message': {
                'function_call': {
                  'arguments':
                      '{"sceneSummary":"legacy function","replies":[{"text":"旧函数参数","styleLabel":"自然"}]}',
                },
              },
            },
          ],
        }),
        _FakeApiResponse(200, {
          'choices': [
            {
              'delta': {
                'tool_calls': [
                  {
                    'function': {
                      'arguments':
                          '{"sceneSummary":"delta tool","replies":[{"text":"增量工具参数","styleLabel":"自然"}]}',
                    },
                  },
                ],
              },
            },
          ],
        }),
      ],
    );
    final api = OpenAICompatibleApi(dioFactory: (_) => dio);

    final toolCall = await api.generateReplyFromText(
      '对方：现在方便吗',
      ChatStyle.defaultStyle,
      null,
      null,
      null,
      APIConfig.defaults,
      'sk-test',
    );
    final legacyFunction = await api.generateReplyFromText(
      '对方：再确认下',
      ChatStyle.defaultStyle,
      null,
      null,
      null,
      APIConfig.defaults,
      'sk-test',
    );
    final deltaToolCall = await api.generateReplyFromText(
      '对方：还有吗',
      ChatStyle.defaultStyle,
      null,
      null,
      null,
      APIConfig.defaults,
      'sk-test',
    );

    expect(paths, [
      '/v1/chat/completions',
      '/v1/chat/completions',
      '/v1/chat/completions',
    ]);
    expect(toolCall.sceneSummary, 'tool');
    expect(toolCall.replies.single.text, '工具参数');
    expect(legacyFunction.sceneSummary, 'legacy function');
    expect(legacyFunction.replies.single.text, '旧函数参数');
    expect(deltaToolCall.sceneSummary, 'delta tool');
    expect(deltaToolCall.replies.single.text, '增量工具参数');
  });

  test(
      'fallback reply parser extracts alias fields from broken suggestions json',
      () async {
    final paths = <String>[];
    final dio = _fakeDio(
      paths: paths,
      responses: const [
        _FakeApiResponse(200, {
          'choices': [
            {
              'message': {
                'content':
                    '{"sceneSummary":"broken","suggestions":[{"message":"可以呀，你定时间","explanation":"接住邀约"},{"reply":"我都行，看你方便"',
              },
            },
          ],
        }),
      ],
    );

    final response =
        await OpenAICompatibleApi(dioFactory: (_) => dio).generateReplyFromText(
      '对方：今晚见吗',
      ChatStyle.defaultStyle,
      null,
      null,
      null,
      APIConfig.defaults,
      'sk-test',
    );

    expect(paths, ['/v1/chat/completions']);
    expect(response.sceneSummary, '模型返回格式不标准，已尽量提取可用回复。');
    expect(response.replies.map((reply) => reply.text), [
      '可以呀，你定时间',
      '我都行，看你方便',
    ]);
  });

  test('fallback reply parser extracts compatible reply option fields',
      () async {
    final paths = <String>[];
    final dio = _fakeDio(
      paths: paths,
      responses: const [
        _FakeApiResponse(200, {
          'choices': [
            {
              'message': {
                'content':
                    '{"sceneSummary":"broken","replyOptions":[{"answer":"可以呀，周六下午方便吗？","why":"给出具体时间"},{"reply":"那我先看看安排"',
              },
            },
          ],
        }),
      ],
    );

    final response =
        await OpenAICompatibleApi(dioFactory: (_) => dio).generateReplyFromText(
      '对方：周末见吗',
      ChatStyle.defaultStyle,
      null,
      null,
      null,
      APIConfig.defaults,
      'sk-test',
    );

    expect(paths, ['/v1/chat/completions']);
    expect(response.sceneSummary, '模型返回格式不标准，已尽量提取可用回复。');
    expect(response.replies.map((reply) => reply.text), [
      '可以呀，周六下午方便吗？',
      '那我先看看安排',
    ]);
  });

  test('fallback reply parser extracts broken string reply arrays', () async {
    final dio = _fakeDio(
      paths: <String>[],
      responses: const [
        _FakeApiResponse(200, {
          'choices': [
            {
              'message': {
                'content':
                    '{"sceneSummary":"broken","replies":["可以呀，你定时间","我都行，看你方便","那我们先轻松聊聊"',
              },
            },
          ],
        }),
      ],
    );

    final response =
        await OpenAICompatibleApi(dioFactory: (_) => dio).generateReplyFromText(
      '对方：今晚见吗',
      ChatStyle.defaultStyle,
      null,
      null,
      null,
      APIConfig.defaults,
      'sk-test',
    );

    expect(response.sceneSummary, '模型返回格式不标准，已尽量提取可用回复。');
    expect(response.replies.map((reply) => reply.text), [
      '可以呀，你定时间',
      '我都行，看你方便',
      '那我们先轻松聊聊',
    ]);
  });

  test('fallback string-array replies ignore later broken profile fields',
      () async {
    final dio = _fakeDio(
      paths: <String>[],
      responses: const [
        _FakeApiResponse(200, {
          'choices': [
            {
              'message': {
                'content':
                    '{"sceneSummary":"broken","replies":["第一条","第二条"],"personInsight":{"displayName":"小林",',
              },
            },
          ],
        }),
      ],
    );

    final response =
        await OpenAICompatibleApi(dioFactory: (_) => dio).generateReplyFromText(
      '对方：今晚见吗',
      ChatStyle.defaultStyle,
      null,
      null,
      null,
      APIConfig.defaults,
      'sk-test',
    );

    expect(response.replies.map((reply) => reply.text), ['第一条', '第二条']);
  });

  test('fallback object replies ignore later broken profile text fields',
      () async {
    final dio = _fakeDio(
      paths: <String>[],
      responses: const [
        _FakeApiResponse(200, {
          'choices': [
            {
              'message': {
                'content':
                    '{"sceneSummary":"broken","replies":[{"text":"第一条"},{"text":"第二条"}],"personInsight":{"facts":[{"text":"不要取画像字段"}],',
              },
            },
          ],
        }),
      ],
    );

    final response =
        await OpenAICompatibleApi(dioFactory: (_) => dio).generateReplyFromText(
      '对方：今晚见吗',
      ChatStyle.defaultStyle,
      null,
      null,
      null,
      APIConfig.defaults,
      'sk-test',
    );

    expect(response.replies.map((reply) => reply.text), ['第一条', '第二条']);
  });

  test('fallback reply parser cleans numbered quoted plain text lines',
      () async {
    final dio = _fakeDio(
      paths: <String>[],
      responses: const [
        _FakeApiResponse(200, {
          'choices': [
            {
              'message': {
                'content': '  1. "可以呀，你定时间"  \n- “我都行，看你方便”\n• \'那我们先轻松聊聊\'  ',
              },
            },
          ],
        }),
      ],
    );

    final response =
        await OpenAICompatibleApi(dioFactory: (_) => dio).generateReplyFromText(
      '对方：今晚见吗',
      ChatStyle.defaultStyle,
      null,
      null,
      null,
      APIConfig.defaults,
      'sk-test',
    );

    expect(response.sceneSummary, '模型返回格式不标准，已尽量提取可用回复。');
    expect(response.replies.map((reply) => reply.text), [
      '可以呀，你定时间',
      '我都行，看你方便',
      '那我们先轻松聊聊',
    ]);

    final source =
        File('lib/core/api_reply_text_fallback.dart').readAsStringSync();
    expect(
      source,
      contains(
          "final text = cleanNonEmptyText(_stripJsonCodeFence(content)) ?? '';"),
    );
    expect(source, contains('var text = cleanNonEmptyText(line) ?? \'\';'));
    expect(source, contains('final trimmed = cleanNonEmptyText(text);'));
    expect(source, isNot(contains('var text = line.trim();')));
  });

  test('fallback reply truncation keeps visible characters intact', () async {
    final visible = List.filled(45, '👩‍💻').join();
    final dio = _fakeDio(
      paths: <String>[],
      responses: [
        _FakeApiResponse(200, {
          'choices': [
            {
              'message': {'content': visible},
            },
          ],
        }),
      ],
    );

    final response =
        await OpenAICompatibleApi(dioFactory: (_) => dio).generateReplyFromText(
      '对方：发来一段消息',
      ChatStyle.defaultStyle,
      null,
      null,
      null,
      APIConfig.defaults,
      'sk-test',
    );

    expect(response.replies.single.text, List.filled(40, '👩‍💻').join());
    expect(visibleTextLength(response.replies.single.text), 40);
  });

  test('reply parser keeps first balanced JSON object from noisy output',
      () async {
    final dio = _fakeDio(
      paths: <String>[],
      responses: const [
        _FakeApiResponse(200, {
          'choices': [
            {
              'message': {
                'content':
                    '结果：{"sceneSummary":"约时间","replies":[{"text":"可以呀，你定时间","styleLabel":"自然"}]} 另一个示例：{"replies":[{"text":"不要取这个"}]}',
              },
            },
          ],
        }),
      ],
    );

    final response =
        await OpenAICompatibleApi(dioFactory: (_) => dio).generateReplyFromText(
      '对方：今晚见吗',
      ChatStyle.defaultStyle,
      null,
      null,
      null,
      APIConfig.defaults,
      'sk-test',
    );

    expect(response.sceneSummary, '约时间');
    expect(response.replies.single.text, '可以呀，你定时间');
  });

  test('reply parser accepts top-level suggestion arrays from providers',
      () async {
    final paths = <String>[];
    final dio = _fakeDio(
      paths: paths,
      responses: const [
        _FakeApiResponse(200, {
          'choices': [
            {
              'message': {
                'content':
                    '  ```json\n[{"style":"自然","text":"可以呀，你定时间","reason":"接住邀约"},{"style":"重复","text":"可以呀，你定时间"},{"message":"我都行，看你方便","label":"轻松"},"那我先确认一下安排"]\n```  ',
              },
            },
          ],
        }),
      ],
    );

    final response =
        await OpenAICompatibleApi(dioFactory: (_) => dio).generateReplyFromText(
      '对方：今晚见吗',
      ChatStyle.defaultStyle,
      null,
      null,
      null,
      APIConfig.defaults,
      'sk-test',
    );

    expect(paths, ['/v1/chat/completions']);
    expect(response.sceneSummary, '模型返回候选回复列表，已尽量提取可用回复。');
    expect(response.riskNotice, '建议检查模型是否支持完整 JSON 输出。');
    expect(response.replies.map((reply) => reply.text), [
      '可以呀，你定时间',
      '我都行，看你方便',
      '那我先确认一下安排',
    ]);
    expect(response.replies.map((reply) => reply.styleLabel), [
      '自然',
      '轻松',
      '建议',
    ]);

    final source =
        File('lib/core/api_reply_array_fallback.dart').readAsStringSync();
    expect(
      source,
      contains(
          "final text = cleanNonEmptyText(_stripJsonCodeFence(content)) ?? '';"),
    );
    expect(
      source,
      contains('final text = cleanNonEmptyText(_stripJsonCodeFence(content));'),
    );
    expect(source, isNot(contains('_stripJsonCodeFence(content).trim()')));
    expect(source, isNot(contains('_stripJsonCodeFence(content).trimLeft()')));
  });

  test('reply parser skips leading bracket noise before suggestion arrays',
      () async {
    final paths = <String>[];
    final dio = _fakeDio(
      paths: paths,
      responses: const [
        _FakeApiResponse(200, {
          'choices': [
            {
              'message': {
                'content':
                    '参考[1]，不是候选回复；截图标记：[截图]\n[{"message":"可以呀，你定时间","label":"自然"},{"text":"我都行，看你方便","style":"轻松"}]',
              },
            },
          ],
        }),
      ],
    );

    final response =
        await OpenAICompatibleApi(dioFactory: (_) => dio).generateReplyFromText(
      '对方：今晚见吗',
      ChatStyle.defaultStyle,
      null,
      null,
      null,
      APIConfig.defaults,
      'sk-test',
    );

    expect(paths, ['/v1/chat/completions']);
    expect(response.sceneSummary, '模型返回候选回复列表，已尽量提取可用回复。');
    expect(response.replies.map((reply) => reply.text), [
      '可以呀，你定时间',
      '我都行，看你方便',
    ]);

    final source =
        File('lib/core/api_reply_array_fallback.dart').readAsStringSync();
    expect(source, contains('_decodeFirstReplyJsonArray(text)'));
    expect(source, contains('_matchingJsonArrayEnd(text, start)'));
    expect(source, contains('arrayStart < firstObjectStart'));
  });

  test('reply parser does not treat nested profile arrays as replies',
      () async {
    final paths = <String>[];
    final dio = _fakeDio(
      paths: paths,
      responses: const [
        _FakeApiResponse(200, {
          'choices': [
            {
              'message': {
                'content':
                    '{"sceneSummary":"empty","replies":[],"personInsight":{"displayName":"小林","facts":["在上海"]}}',
              },
            },
          ],
        }),
      ],
    );

    final response =
        await OpenAICompatibleApi(dioFactory: (_) => dio).generateReplyFromText(
      '对方：今晚见吗',
      ChatStyle.defaultStyle,
      null,
      null,
      null,
      APIConfig.defaults,
      'sk-test',
    );

    expect(paths, ['/v1/chat/completions']);
    expect(response.sceneSummary, '模型返回格式不标准，已尽量提取可用回复。');
    expect(response.replies.single.text, '模型返回内容不完整，请重新生成一次。');
    expect(response.replies.map((reply) => reply.text), isNot(contains('在上海')));
  });

  test('reply generation keeps iOS minimum output token budget', () async {
    final paths = <String>[];
    final bodies = <Map<String, dynamic>>[];
    final dio = _fakeDio(
      paths: paths,
      bodies: bodies,
      responses: const [
        _FakeApiResponse(200, {
          'choices': [
            {
              'message': {
                'content':
                    '{"sceneSummary":"ok","replies":[{"text":"收到","styleLabel":"自然"}]}',
              },
            },
          ],
        }),
      ],
    );
    final config =
        APIConfig.defaults.copyWith(baseURL: 'https://api.example/v1');

    await OpenAICompatibleApi(dioFactory: (_) => dio).generateReplyFromText(
      '你好',
      ChatStyle.defaultStyle,
      null,
      null,
      null,
      config,
      'sk-test',
    );

    expect(paths, ['/v1/chat/completions']);
    expect(bodies.single['max_tokens'], 1800);
  });

  test('reply request bodies preserve iOS JSON generation contract', () async {
    final chatPaths = <String>[];
    final chatBodies = <Map<String, dynamic>>[];
    final chatDio = _fakeDio(
      paths: chatPaths,
      bodies: chatBodies,
      responses: const [
        _FakeApiResponse(200, {
          'choices': [
            {
              'message': {
                'content':
                    '{"sceneSummary":"chat","replies":[{"text":"收到","styleLabel":"自然"}]}',
              },
            },
          ],
        }),
      ],
    );
    final responsesPaths = <String>[];
    final responsesBodies = <Map<String, dynamic>>[];
    final responsesDio = _fakeDio(
      paths: responsesPaths,
      bodies: responsesBodies,
      responses: const [
        _FakeApiResponse(200, {
          'output_text':
              '{"sceneSummary":"responses","replies":[{"text":"收到","styleLabel":"自然"}]}',
        }),
      ],
    );
    final config = APIConfig.defaults.copyWith(
      baseURL: 'https://api.example/v1',
      temperature: 0.42,
      maxTokens: 1200,
    );

    await OpenAICompatibleApi(dioFactory: (_) => chatDio).generateReplyFromText(
      '你好',
      ChatStyle.defaultStyle,
      null,
      null,
      null,
      config,
      'sk-test',
    );
    await OpenAICompatibleApi(dioFactory: (_) => responsesDio)
        .generateReplyFromText(
      '你好',
      ChatStyle.defaultStyle,
      null,
      null,
      null,
      config.copyWith(baseURL: 'https://api.example/v1/responses'),
      'sk-test',
    );

    final chatBody = chatBodies.single;
    expect(chatPaths, ['/v1/chat/completions']);
    expect(chatBody['model'], APIConfig.defaults.textModelName);
    expect(chatBody['temperature'], 0.42);
    expect(chatBody['max_tokens'], 1800);
    expect(chatBody['response_format'], {'type': 'json_object'});
    expect(chatBody, isNot(contains('store')));
    final chatMessages = chatBody['messages'] as List;
    expect((chatMessages.first as Map)['role'], 'system');
    expect((chatMessages.last as Map)['role'], 'user');

    final responsesBody = responsesBodies.single;
    expect(responsesPaths, ['/v1/responses']);
    expect(responsesBody['model'], APIConfig.defaults.textModelName);
    expect(responsesBody['temperature'], 0.42);
    expect(responsesBody['max_output_tokens'], 1800);
    expect(responsesBody['store'], isFalse);
    expect(responsesBody['text'], {
      'format': {'type': 'json_object'},
    });
    expect(responsesBody, isNot(contains('response_format')));
    final responsesInput = responsesBody['input'] as List;
    expect((responsesInput.first as Map)['role'], 'system');
    expect((responsesInput.last as Map)['role'], 'user');
  });

  test('api request bodies use cleaned model names', () async {
    final textBodies = <Map<String, dynamic>>[];
    final textDio = _fakeDio(
      paths: <String>[],
      bodies: textBodies,
      responses: const [
        _FakeApiResponse(200, {
          'choices': [
            {
              'message': {
                'content':
                    '{"sceneSummary":"ok","replies":[{"text":"收到","styleLabel":"自然"}]}',
              },
            },
          ],
        }),
      ],
    );
    final visionBodies = <Map<String, dynamic>>[];
    final visionDio = _fakeDio(
      paths: <String>[],
      bodies: visionBodies,
      responses: const [
        _FakeApiResponse(200, {
          'choices': [
            {
              'message': {
                'content':
                    '{"sceneSummary":"ok","replies":[{"text":"看到了","styleLabel":"自然"}]}',
              },
            },
          ],
        }),
      ],
    );
    final responsesBodies = <Map<String, dynamic>>[];
    final responsesDio = _fakeDio(
      paths: <String>[],
      bodies: responsesBodies,
      responses: const [
        _FakeApiResponse(200, {
          'output_text':
              '{"sceneSummary":"ok","replies":[{"text":"响应","styleLabel":"自然"}]}',
        }),
      ],
    );
    final config = APIConfig.defaults.copyWith(
      textModelName: '  gpt-text-clean  ',
      visionModelName: '  gpt-vision-clean  ',
      modelCapabilities: const {
        'gpt-vision-clean': ModelCapability(isMultimodal: true),
      },
    );

    await OpenAICompatibleApi(dioFactory: (_) => textDio).generateReplyFromText(
      '你好',
      ChatStyle.defaultStyle,
      null,
      null,
      null,
      config,
      'sk-test',
    );
    await OpenAICompatibleApi(dioFactory: (_) => responsesDio)
        .generateReplyFromText(
      '你好',
      ChatStyle.defaultStyle,
      null,
      null,
      null,
      config.copyWith(baseURL: 'https://api.example/v1/responses'),
      'sk-test',
    );
    await OpenAICompatibleApi(dioFactory: (_) => visionDio)
        .generateReplyFromImage(
      const ImagePayload(
        base64: 'abc',
        mimeType: 'image/jpeg',
        width: 1,
        height: 1,
        sizeInBytes: 3,
      ),
      ChatStyle.defaultStyle,
      null,
      null,
      null,
      config,
      'sk-test',
    );

    expect(textBodies.single['model'], 'gpt-text-clean');
    expect(responsesBodies.single['model'], 'gpt-text-clean');
    expect(visionBodies.single['model'], 'gpt-vision-clean');

    final replySource =
        File('lib/core/api_reply_generation.dart').readAsStringSync();
    expect(
        replySource, contains('final text = cleanChatTextInput(input.text);'));
    expect(replySource, isNot(contains('input.text?.trim()')));
  });

  test('chat reply system prompt carries iOS safety boundaries', () async {
    final paths = <String>[];
    final bodies = <Map<String, dynamic>>[];
    final dio = _fakeDio(
      paths: paths,
      bodies: bodies,
      responses: const [
        _FakeApiResponse(200, {
          'choices': [
            {
              'message': {
                'content':
                    '{"sceneSummary":"ok","replies":[{"text":"收到","styleLabel":"自然"}]}',
              },
            },
          ],
        }),
      ],
    );
    final config =
        APIConfig.defaults.copyWith(baseURL: 'https://api.example/v1');

    await OpenAICompatibleApi(dioFactory: (_) => dio).generateReplyFromText(
      '你好',
      ChatStyle.defaultStyle,
      null,
      '候选画像：\n避雷点：不要催促',
      null,
      config,
      'sk-test',
    );

    final messages = bodies.single['messages'] as List;
    final system = messages.first as Map;
    expect(system['role'], 'system');
    expect(system['content'], contains('人物库信息只能用于更体面、更有分寸地沟通'));
    expect(system['content'], contains('不能用于操控、施压或诱导对方'));
    expect(system['content'], contains('过度性暗示或诱导他人不适'));
  });

  test('simulation fallback cleans and bounds persona message like iOS',
      () async {
    final longLine = '1. ${'我理解你的意思，'.padRight(120, '先')}';
    final dio = _fakeDio(
      paths: <String>[],
      responses: [
        _FakeApiResponse(200, {
          'choices': [
            {
              'message': {'content': '$longLine\n第二行不用取'},
            },
          ],
        }),
      ],
    );

    final response =
        await OpenAICompatibleApi(dioFactory: (_) => dio).runSimulationTurn(
      profile: PersonProfile(displayName: '小林'),
      scenario: SimulationScenario.dailyChat,
      history: const [],
      userReply: null,
      personalizationContext: '',
      config: APIConfig.defaults.copyWith(baseURL: 'https://api.example/v1'),
      apiKey: 'sk-test',
    );

    expect(response.personaMessage, isNot(startsWith('1.')));
    expect(response.personaMessage.length, lessThanOrEqualTo(90));
    expect(response.sceneState, contains('模型返回格式不标准'));
    expect(response.favorability, 58);
    expect(response.tension, 42);
    expect(response.trust, 55);
    expect(response.interest, 60);
    expect(response.feedback, contains('模型没有返回标准结构'));
    expect(response.metrics, hasLength(8));
    expect(response.metrics.map((metric) => metric.name), [
      '好感度',
      '自然度',
      '边界感',
      '推进度',
      '情绪接住',
      '风险控制',
      '共情感',
      '推进力',
    ]);
    expect(response.metrics[1].score, 58);
    expect(response.metrics[1].insight, '回复可以更像日常聊天。');
    expect(
        response.options.map((option) => option.label), ['先共情', '给选择', '修复感']);
  });

  test('simulation fallback skips broken json fragments before persona text',
      () async {
    final dio = _fakeDio(
      paths: <String>[],
      responses: const [
        _FakeApiResponse(200, {
          'choices': [
            {
              'message': {
                'content': '{"personaMessage":"不要取这个",\n2. "可以先慢一点，我想听你说完"\n}',
              },
            },
          ],
        }),
      ],
    );

    final response =
        await OpenAICompatibleApi(dioFactory: (_) => dio).runSimulationTurn(
      profile: PersonProfile(displayName: '小林'),
      scenario: SimulationScenario.dailyChat,
      history: const [],
      userReply: null,
      personalizationContext: '',
      config: APIConfig.defaults.copyWith(baseURL: 'https://api.example/v1'),
      apiKey: 'sk-test',
    );

    expect(response.personaMessage, '可以先慢一点，我想听你说完');
    expect(response.personaMessage, isNot(contains('personaMessage')));

    final source =
        File('lib/core/api_simulation_fallback.dart').readAsStringSync();
    expect(source, contains('.where((line) => !_looksLikeJsonFragment(line))'));
  });

  test('simulation prompt cleans noisy history before model context', () async {
    final paths = <String>[];
    final bodies = <Map<String, dynamic>>[];
    final dio = _fakeDio(
      paths: paths,
      bodies: bodies,
      responses: const [
        _FakeApiResponse(200, {
          'choices': [
            {
              'message': {
                'content':
                    '{"personaMessage":"我听到了","sceneState":"继续","options":[{"text":"我再想想","label":"稳妥","reason":"更自然"}],"coachTip":"慢一点"}',
              },
            },
          ],
        }),
      ],
    );

    await OpenAICompatibleApi(dioFactory: (_) => dio).runSimulationTurn(
      profile: PersonProfile(displayName: '小林'),
      scenario: SimulationScenario.conflict,
      history: [
        SimulationMessage(speaker: SimulationSpeaker.persona, text: '  开场  '),
        SimulationMessage(speaker: SimulationSpeaker.user, text: '未知'),
        SimulationMessage(speaker: SimulationSpeaker.user, text: '   '),
        SimulationMessage(speaker: SimulationSpeaker.user, text: '  我会认真说  '),
      ],
      userReply: '我会认真说',
      personalizationContext: '',
      config: APIConfig.defaults.copyWith(baseURL: 'https://api.example/v1'),
      apiKey: 'sk-test',
    );

    expect(paths, ['/v1/chat/completions']);
    final messages = bodies.single['messages'] as List;
    final prompt = (messages.last as Map)['content'] as String;
    expect(prompt, contains('对方：开场'));
    expect(prompt, contains('我：我会认真说'));
    expect(prompt, isNot(contains('未知')));
    expect(prompt, isNot(contains('我：   ')));
  });

  test('moment profile system prompt carries iOS analysis boundaries',
      () async {
    final paths = <String>[];
    final bodies = <Map<String, dynamic>>[];
    final dio = _fakeDio(
      paths: paths,
      bodies: bodies,
      responses: const [
        _FakeApiResponse(200, {
          'choices': [
            {
              'message': {
                'content':
                    '{"sceneSummary":"动态画像","sourcePlatform":"微信朋友圈","confidence":0.7}',
              },
            },
          ],
        }),
      ],
    );
    final config =
        APIConfig.defaults.copyWith(baseURL: 'https://api.example/v1');

    await OpenAICompatibleApi(dioFactory: (_) => dio).analyzeMomentScreenshot(
      const ImagePayload(
        base64: 'abc',
        mimeType: 'image/jpeg',
        width: 1,
        height: 1,
        sizeInBytes: 3,
      ),
      null,
      config,
      'sk-test',
    );

    final messages = bodies.single['messages'] as List;
    final system = messages.first as Map;
    expect(system['role'], 'system');
    expect(system['content'], contains('低确定性的内容画像'));
    expect(system['content'], contains('不要做诊断，不要断言心理疾病'));
    expect(system['content'], contains('不是操控对方'));
  });

  test('responses endpoint falls back to chat completions when unavailable',
      () async {
    final paths = <String>[];
    final dio = _fakeDio(
      paths: paths,
      responses: const [
        _FakeApiResponse(400, {
          'error': {'message': 'unsupported endpoint: /v1/responses'},
        }),
        _FakeApiResponse(200, {
          'choices': [
            {
              'message': {
                'content':
                    '{"sceneSummary":"fallback","replies":[{"text":"已回退","styleLabel":"自然"}]}',
              },
            },
          ],
        }),
      ],
    );
    final config = APIConfig.defaults
        .copyWith(baseURL: 'https://api.example/v1/responses');

    final response =
        await OpenAICompatibleApi(dioFactory: (_) => dio).generateReplyFromText(
      '你好',
      ChatStyle.defaultStyle,
      null,
      null,
      null,
      config,
      'sk-test',
    );

    expect(paths, ['/v1/responses', '/v1/chat/completions']);
    expect(response.replies.single.text, '已回退');
  });

  test('responses endpoint falls back on network errors like iOS', () async {
    final paths = <String>[];
    var index = 0;
    final dio = Dio();
    dio.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) {
      paths.add(options.uri.path);
      if (index++ == 0) {
        handler.reject(DioException.connectionTimeout(
          timeout: const Duration(seconds: 1),
          requestOptions: options,
        ));
        return;
      }
      handler.resolve(Response(
        requestOptions: options,
        statusCode: 200,
        data: const {
          'choices': [
            {
              'message': {
                'content':
                    '{"sceneSummary":"network fallback","replies":[{"text":"网络回退成功","styleLabel":"自然"}]}',
              },
            },
          ],
        },
      ));
    }));
    final config = APIConfig.defaults
        .copyWith(baseURL: 'https://api.example/v1/responses');

    final response =
        await OpenAICompatibleApi(dioFactory: (_) => dio).generateReplyFromText(
      '你好',
      ChatStyle.defaultStyle,
      null,
      null,
      null,
      config,
      'sk-test',
    );

    expect(paths, ['/v1/responses', '/v1/chat/completions']);
    expect(response.replies.single.text, '网络回退成功');
  });

  test('responses endpoint falls back when connection is interrupted',
      () async {
    final paths = <String>[];
    var index = 0;
    final dio = Dio();
    dio.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) {
      paths.add(options.uri.path);
      if (index++ == 0) {
        handler.reject(DioException.connectionError(
          requestOptions: options,
          reason: 'Connection reset by peer',
        ));
        return;
      }
      handler.resolve(Response(
        requestOptions: options,
        statusCode: 200,
        data: const {
          'choices': [
            {
              'message': {
                'content':
                    '{"sceneSummary":"interrupted fallback","replies":[{"text":"连接中断后回退成功","styleLabel":"自然"}]}',
              },
            },
          ],
        },
      ));
    }));
    final config = APIConfig.defaults
        .copyWith(baseURL: 'https://api.example/v1/responses');

    final response =
        await OpenAICompatibleApi(dioFactory: (_) => dio).generateReplyFromText(
      '你好',
      ChatStyle.defaultStyle,
      null,
      null,
      null,
      config,
      'sk-test',
    );

    expect(paths, ['/v1/responses', '/v1/chat/completions']);
    expect(response.replies.single.text, '连接中断后回退成功');
  });

  test('responses fallback chat retry removes unsupported response format',
      () async {
    final paths = <String>[];
    final bodies = <Map<String, dynamic>>[];
    final dio = _fakeDio(
      paths: paths,
      bodies: bodies,
      responses: const [
        _FakeApiResponse(400, {
          'error': {'message': 'unsupported endpoint: /v1/responses'},
        }),
        _FakeApiResponse(400, {
          'error': 'unsupported response_format json_object',
        }),
        _FakeApiResponse(200, {
          'choices': [
            {
              'message': {
                'content':
                    '{"sceneSummary":"fallback retry","replies":[{"text":"回退重试成功","styleLabel":"自然"}]}',
              },
            },
          ],
        }),
      ],
    );
    final config = APIConfig.defaults
        .copyWith(baseURL: 'https://api.example/v1/responses');

    final response =
        await OpenAICompatibleApi(dioFactory: (_) => dio).generateReplyFromText(
      '你好',
      ChatStyle.defaultStyle,
      null,
      null,
      null,
      config,
      'sk-test',
    );

    expect(paths, [
      '/v1/responses',
      '/v1/chat/completions',
      '/v1/chat/completions',
    ]);
    expect(bodies.map((body) => body.containsKey('response_format')),
        [false, true, false]);
    expect(response.replies.single.text, '回退重试成功');
  });

  test('responses endpoint accepts nested text value content', () async {
    final paths = <String>[];
    final dio = _fakeDio(
      paths: paths,
      responses: const [
        _FakeApiResponse(200, {
          'output_text': {
            'value':
                '{"sceneSummary":"direct","replies":[{"text":"直接对象","styleLabel":"自然"}]}',
          },
        }),
        _FakeApiResponse(200, {
          'output': [
            {
              'type': 'message',
              'content': [
                {
                  'type': 'output_text',
                  'text': {
                    'value':
                        '{"sceneSummary":"nested","replies":[{"text":"嵌套对象","styleLabel":"自然"}]}',
                  },
                },
              ],
            },
          ],
        }),
      ],
    );
    final api = OpenAICompatibleApi(dioFactory: (_) => dio);
    final config = APIConfig.defaults
        .copyWith(baseURL: 'https://api.example/v1/responses');

    final direct = await api.generateReplyFromText(
      '你好',
      ChatStyle.defaultStyle,
      null,
      null,
      null,
      config,
      'sk-test',
    );
    final nested = await api.generateReplyFromText(
      '再说一次',
      ChatStyle.defaultStyle,
      null,
      null,
      null,
      config,
      'sk-test',
    );

    expect(paths, ['/v1/responses', '/v1/responses']);
    expect(direct.replies.single.text, '直接对象');
    expect(nested.replies.single.text, '嵌套对象');
  });

  test('responses endpoint accepts normalized content keys', () async {
    final paths = <String>[];
    final dio = _fakeDio(
      paths: paths,
      responses: const [
        _FakeApiResponse(200, {
          'outputText': {
            'message_text':
                '{"sceneSummary":"direct key","replies":[{"text":"直接变体","styleLabel":"自然"}]}',
          },
        }),
        _FakeApiResponse(200, {
          'output': [
            {
              'message-text':
                  '{"sceneSummary":"nested key","replies":[{"text":"嵌套变体","styleLabel":"自然"}]}',
            },
          ],
        }),
        _FakeApiResponse(200, {
          'payload': {
            'data': {
              'message_text':
                  '{"sceneSummary":"wrapped response","replies":[{"text":"包装响应","styleLabel":"自然"}]}',
            },
          },
        }),
      ],
    );
    final api = OpenAICompatibleApi(dioFactory: (_) => dio);
    final config = APIConfig.defaults
        .copyWith(baseURL: 'https://api.example/v1/responses');

    final direct = await api.generateReplyFromText(
      '你好',
      ChatStyle.defaultStyle,
      null,
      null,
      null,
      config,
      'sk-test',
    );
    final nested = await api.generateReplyFromText(
      '再说一次',
      ChatStyle.defaultStyle,
      null,
      null,
      null,
      config,
      'sk-test',
    );
    final wrapped = await api.generateReplyFromText(
      '包装响应',
      ChatStyle.defaultStyle,
      null,
      null,
      null,
      config,
      'sk-test',
    );

    expect(paths, ['/v1/responses', '/v1/responses', '/v1/responses']);
    expect(direct.sceneSummary, 'direct key');
    expect(direct.replies.single.text, '直接变体');
    expect(nested.sceneSummary, 'nested key');
    expect(nested.replies.single.text, '嵌套变体');
    expect(wrapped.sceneSummary, 'wrapped response');
    expect(wrapped.replies.single.text, '包装响应');
  });

  test('responses endpoint accepts structured json output content', () async {
    final paths = <String>[];
    final dio = _fakeDio(
      paths: paths,
      responses: const [
        _FakeApiResponse(200, {
          'output': [
            {
              'type': 'message',
              'content': [
                {
                  'type': 'output_json',
                  'json': {
                    'sceneSummary': 'json output',
                    'replies': [
                      {'text': 'JSON对象回复', 'styleLabel': '自然'}
                    ],
                  },
                },
              ],
            },
          ],
        }),
        _FakeApiResponse(200, {
          'output': [
            {
              'type': 'message',
              'parsed': {
                'scene_summary': 'parsed output',
                'reply_suggestions': [
                  {'message': 'Parsed对象回复', 'style_label': '轻松'}
                ],
              },
            },
          ],
        }),
      ],
    );
    final api = OpenAICompatibleApi(dioFactory: (_) => dio);
    final config = APIConfig.defaults
        .copyWith(baseURL: 'https://api.example/v1/responses');

    final jsonOutput = await api.generateReplyFromText(
      '你好',
      ChatStyle.defaultStyle,
      null,
      null,
      null,
      config,
      'sk-test',
    );
    final parsedOutput = await api.generateReplyFromText(
      '再说一次',
      ChatStyle.defaultStyle,
      null,
      null,
      null,
      config,
      'sk-test',
    );

    expect(paths, ['/v1/responses', '/v1/responses']);
    expect(jsonOutput.sceneSummary, 'json output');
    expect(jsonOutput.replies.single.text, 'JSON对象回复');
    expect(parsedOutput.sceneSummary, 'parsed output');
    expect(parsedOutput.replies.single.styleLabel, '轻松');
    expect(parsedOutput.replies.single.text, 'Parsed对象回复');
  });

  test('responses endpoint accepts function argument output content', () async {
    final paths = <String>[];
    final dio = _fakeDio(
      paths: paths,
      responses: const [
        _FakeApiResponse(200, {
          'output': [
            {
              'type': 'function_call',
              'arguments':
                  '{"sceneSummary":"direct args","replies":[{"text":"直接参数","styleLabel":"自然"}]}',
            },
          ],
        }),
        _FakeApiResponse(200, {
          'output': [
            {
              'type': 'tool_call',
              'function': {
                'arguments':
                    '{"sceneSummary":"nested args","replies":[{"text":"嵌套参数","styleLabel":"自然"}]}',
              },
            },
          ],
        }),
      ],
    );
    final api = OpenAICompatibleApi(dioFactory: (_) => dio);
    final config = APIConfig.defaults
        .copyWith(baseURL: 'https://api.example/v1/responses');

    final direct = await api.generateReplyFromText(
      '你好',
      ChatStyle.defaultStyle,
      null,
      null,
      null,
      config,
      'sk-test',
    );
    final nested = await api.generateReplyFromText(
      '再说一次',
      ChatStyle.defaultStyle,
      null,
      null,
      null,
      config,
      'sk-test',
    );

    expect(paths, ['/v1/responses', '/v1/responses']);
    expect(direct.sceneSummary, 'direct args');
    expect(direct.replies.single.text, '直接参数');
    expect(nested.sceneSummary, 'nested args');
    expect(nested.replies.single.text, '嵌套参数');
  });

  test('responses endpoint accepts chat completions shaped content', () async {
    final paths = <String>[];
    final dio = _fakeDio(
      paths: paths,
      responses: const [
        _FakeApiResponse(200, {
          'choices': [
            {
              'message': {
                'content':
                    '{"sceneSummary":"chat shape","replies":[{"text":"单次解析","styleLabel":"自然"}]}',
              },
            },
          ],
        }),
      ],
    );
    final api = OpenAICompatibleApi(dioFactory: (_) => dio);
    final config = APIConfig.defaults
        .copyWith(baseURL: 'https://api.example/v1/responses');

    final response = await api.generateReplyFromText(
      '你好',
      ChatStyle.defaultStyle,
      null,
      null,
      null,
      config,
      'sk-test',
    );

    expect(paths, ['/v1/responses']);
    expect(response.sceneSummary, 'chat shape');
    expect(response.replies.single.text, '单次解析');
  });

  test('api error mapping skips blank nested messages for detail', () async {
    final dio = _fakeDio(
      paths: <String>[],
      responses: const [
        _FakeApiResponse(500, {
          'error': {'message': '   '},
          'detail': 'provider overloaded',
        }),
      ],
    );

    await expectLater(
      OpenAICompatibleApi(dioFactory: (_) => dio).generateReplyFromText(
        '你好',
        ChatStyle.defaultStyle,
        null,
        null,
        null,
        APIConfig.defaults,
        'sk-test',
      ),
      throwsA(
        isA<AppException>().having(
          (error) => error.message,
          'message',
          '模型接口返回错误（500）：provider overloaded',
        ),
      ),
    );
  });

  test('api error mapping accepts normalized provider keys', () async {
    final dio = _fakeDio(
      paths: <String>[],
      responses: const [
        _FakeApiResponse(429, {
          'error': {'error_message': 'rate limit reached'},
        }),
        _FakeApiResponse(503, {
          'error-message': 'provider busy',
        }),
      ],
    );
    final api = OpenAICompatibleApi(dioFactory: (_) => dio);

    await expectLater(
      api.generateReplyFromText(
        '你好',
        ChatStyle.defaultStyle,
        null,
        null,
        null,
        APIConfig.defaults,
        'sk-test',
      ),
      throwsA(
        isA<AppException>().having(
          (error) => error.message,
          'message',
          '模型接口返回错误（429）：rate limit reached',
        ),
      ),
    );
    await expectLater(
      api.generateReplyFromText(
        '你好',
        ChatStyle.defaultStyle,
        null,
        null,
        null,
        APIConfig.defaults,
        'sk-test',
      ),
      throwsA(
        isA<AppException>().having(
          (error) => error.message,
          'message',
          '模型接口返回错误（503）：provider busy',
        ),
      ),
    );
  });

  test('api error mapping accepts descriptions and error arrays', () async {
    final dio = _fakeDio(
      paths: <String>[],
      responses: const [
        _FakeApiResponse(400, {
          'error': {
            'error_description': 'invalid request shape',
          },
        }),
        _FakeApiResponse(422, {
          'errors': [
            {'message': 'model is required'},
          ],
        }),
        _FakeApiResponse(429, {
          'error': {'msg': 'too many requests'},
        }),
        _FakeApiResponse(400, {
          'reason': 'invalid base64 image',
        }),
        _FakeApiResponse(400, {
          'error': {'code': 'invalid_api_key'},
        }),
        _FakeApiResponse(503, {
          'type': 'provider_unavailable',
        }),
      ],
    );
    final api = OpenAICompatibleApi(dioFactory: (_) => dio);

    await expectLater(
      api.generateReplyFromText(
        '你好',
        ChatStyle.defaultStyle,
        null,
        null,
        null,
        APIConfig.defaults,
        'sk-test',
      ),
      throwsA(
        isA<AppException>().having(
          (error) => error.message,
          'message',
          '模型接口返回错误（400）：invalid request shape',
        ),
      ),
    );
    await expectLater(
      api.generateReplyFromText(
        '你好',
        ChatStyle.defaultStyle,
        null,
        null,
        null,
        APIConfig.defaults,
        'sk-test',
      ),
      throwsA(
        isA<AppException>().having(
          (error) => error.message,
          'message',
          '模型接口返回错误（422）：model is required',
        ),
      ),
    );
    await expectLater(
      api.generateReplyFromText(
        '你好',
        ChatStyle.defaultStyle,
        null,
        null,
        null,
        APIConfig.defaults,
        'sk-test',
      ),
      throwsA(
        isA<AppException>().having(
          (error) => error.message,
          'message',
          '模型接口返回错误（429）：too many requests',
        ),
      ),
    );
    await expectLater(
      api.generateReplyFromText(
        '你好',
        ChatStyle.defaultStyle,
        null,
        null,
        null,
        APIConfig.defaults,
        'sk-test',
      ),
      throwsA(
        isA<AppException>().having(
          (error) => error.message,
          'message',
          '模型接口返回错误（400）：invalid base64 image',
        ),
      ),
    );
    await expectLater(
      api.generateReplyFromText(
        '你好',
        ChatStyle.defaultStyle,
        null,
        null,
        null,
        APIConfig.defaults,
        'sk-test',
      ),
      throwsA(
        isA<AppException>().having(
          (error) => error.message,
          'message',
          '模型接口返回错误（400）：invalid_api_key',
        ),
      ),
    );
    await expectLater(
      api.generateReplyFromText(
        '你好',
        ChatStyle.defaultStyle,
        null,
        null,
        null,
        APIConfig.defaults,
        'sk-test',
      ),
      throwsA(
        isA<AppException>().having(
          (error) => error.message,
          'message',
          '模型接口返回错误（503）：provider_unavailable',
        ),
      ),
    );
  });

  test('chat completions retries without response_format when unsupported',
      () async {
    final paths = <String>[];
    final bodies = <Map<String, dynamic>>[];
    final dio = _fakeDio(
      paths: paths,
      bodies: bodies,
      responses: const [
        _FakeApiResponse(400, {
          'error': 'unsupported response_format json_object',
        }),
        _FakeApiResponse(200, {
          'choices': [
            {
              'message': {
                'content':
                    '{"sceneSummary":"retry","replies":[{"text":"重试成功","styleLabel":"自然"}]}',
              },
            },
          ],
        }),
      ],
    );
    final config =
        APIConfig.defaults.copyWith(baseURL: 'https://api.example/v1');

    final response =
        await OpenAICompatibleApi(dioFactory: (_) => dio).generateReplyFromText(
      '你好',
      ChatStyle.defaultStyle,
      null,
      null,
      null,
      config,
      'sk-test',
    );

    expect(paths, ['/v1/chat/completions', '/v1/chat/completions']);
    expect(bodies.map((body) => body.containsKey('response_format')),
        [true, false]);
    expect(response.replies.single.text, '重试成功');
  });

  test('vision api transport rejects non-chat models before request', () async {
    final paths = <String>[];
    final dio = _fakeDio(
      paths: paths,
      responses: const <_FakeApiResponse>[],
    );
    final config = APIConfig.defaults.copyWith(
      baseURL: 'https://api.example/v1',
      visionModelName: 'omni-moderation-latest',
      modelCapabilities: const {
        'omni-moderation-latest': ModelCapability(isMultimodal: true),
      },
    );

    await expectLater(
      OpenAICompatibleApi(dioFactory: (_) => dio).generateReplyFromImage(
        const ImagePayload(
          base64: 'abc',
          mimeType: 'image/jpeg',
          width: 1,
          height: 1,
          sizeInBytes: 3,
        ),
        ChatStyle.defaultStyle,
        null,
        null,
        null,
        config,
        'sk-test',
      ),
      throwsA(isA<AppException>().having(
        (error) => error.message,
        'message',
        visionChatModelRequiredMessage,
      )),
    );
    expect(paths, isEmpty);
  });

  test('two step vision extracts text before generating reply', () async {
    final paths = <String>[];
    final bodies = <Map<String, dynamic>>[];
    final dio = _fakeDio(
      paths: paths,
      bodies: bodies,
      responses: const [
        _FakeApiResponse(200, {
          'choices': [
            {
              'message': {
                'content':
                    '{"conversationText":"对方：今晚见吗","sceneSummary":"约见","latestMessage":"今晚见吗"}',
              },
            },
          ],
        }),
        _FakeApiResponse(200, {
          'choices': [
            {
              'message': {
                'content':
                    '{"sceneSummary":"约见","replies":[{"text":"可以呀，几点？","styleLabel":"自然"}]}',
              },
            },
          ],
        }),
      ],
    );
    final config = APIConfig.defaults.copyWith(
      baseURL: 'https://api.example/v1',
      enableTwoStepVision: true,
    );

    final response = await OpenAICompatibleApi(dioFactory: (_) => dio)
        .generateReplyFromImage(
      const ImagePayload(
        base64: 'abc',
        mimeType: 'image/jpeg',
        width: 1,
        height: 1,
        sizeInBytes: 3,
      ),
      ChatStyle.defaultStyle,
      null,
      null,
      null,
      config,
      'sk-test',
    );

    expect(paths, ['/v1/chat/completions', '/v1/chat/completions']);
    expect((bodies.first['messages'] as List).last['content'], isA<List>());
    expect(
        ((bodies.last['messages'] as List).last as Map)['content'].toString(),
        contains('对方：今晚见吗'));
    expect(response.replies.single.text, '可以呀，几点？');

    final visionSource =
        File('lib/core/api_vision_extraction.dart').readAsStringSync();
    expect(visionSource, contains('if (cleanChatTextInput(text) == null)'));
    expect(visionSource, isNot(contains('text.trim().isEmpty')));
  });

  test('two step vision falls back to direct image reply on extraction errors',
      () async {
    final paths = <String>[];
    final bodies = <Map<String, dynamic>>[];
    final dio = _fakeDio(
      paths: paths,
      bodies: bodies,
      responses: const [
        _FakeApiResponse(200, {
          'choices': [
            {
              'message': {'content': '模型只返回了普通文字，无法解析成 JSON'},
            },
          ],
        }),
        _FakeApiResponse(200, {
          'choices': [
            {
              'message': {
                'content':
                    '{"sceneSummary":"direct fallback","replies":[{"text":"那我们先按你方便的时间来。","styleLabel":"自然"}]}',
              },
            },
          ],
        }),
      ],
    );
    final config = APIConfig.defaults.copyWith(
      baseURL: 'https://api.example/v1',
      enableTwoStepVision: true,
    );

    final response = await OpenAICompatibleApi(dioFactory: (_) => dio)
        .generateReplyFromImage(
      const ImagePayload(
        base64: 'abc',
        mimeType: 'image/jpeg',
        width: 1,
        height: 1,
        sizeInBytes: 3,
      ),
      ChatStyle.defaultStyle,
      null,
      null,
      null,
      config,
      'sk-test',
    );

    expect(paths, ['/v1/chat/completions', '/v1/chat/completions']);
    expect(bodies, hasLength(2));
    final extractionSystem = (bodies.first['messages'] as List).first as Map;
    final directSystem = (bodies.last['messages'] as List).first as Map;
    expect(extractionSystem['content'], '你只负责读取截图中的文字并输出 JSON。');
    expect(directSystem['content'], systemPromptChatReplyAssistant);
    expect(response.sceneSummary, 'direct fallback');
    expect(response.replies.single.text, '那我们先按你方便的时间来。');
  });

  test('two step vision accepts message array extraction aliases', () async {
    final paths = <String>[];
    final bodies = <Map<String, dynamic>>[];
    final dio = _fakeDio(
      paths: paths,
      bodies: bodies,
      responses: const [
        _FakeApiResponse(200, {
          'choices': [
            {
              'message': {
                'content':
                    '{"messages":[{"sender":"对方","content":"你今天怎么没回我"},{"role":"我","text":"刚在忙"}],"summary":"对方在确认回复节奏","last":"你今天怎么没回我","nickname":"小林"}',
              },
            },
          ],
        }),
        _FakeApiResponse(200, {
          'choices': [
            {
              'message': {
                'content':
                    '{"sceneSummary":"确认回复节奏","replies":[{"text":"刚忙完，才看到你消息","styleLabel":"自然"}]}',
              },
            },
          ],
        }),
      ],
    );
    final config = APIConfig.defaults.copyWith(
      baseURL: 'https://api.example/v1',
      enableTwoStepVision: true,
    );

    final response = await OpenAICompatibleApi(dioFactory: (_) => dio)
        .generateReplyFromImage(
      const ImagePayload(
        base64: 'abc',
        mimeType: 'image/jpeg',
        width: 1,
        height: 1,
        sizeInBytes: 3,
      ),
      ChatStyle.defaultStyle,
      null,
      null,
      null,
      config,
      'sk-test',
    );

    expect(paths, ['/v1/chat/completions', '/v1/chat/completions']);
    final secondUserMessage = ((bodies.last['messages'] as List).last as Map);
    expect(secondUserMessage['content'], isA<String>());
    expect(secondUserMessage['content'], contains('对方：你今天怎么没回我'));
    expect(secondUserMessage['content'], contains('我：刚在忙'));
    expect(secondUserMessage['content'], contains('可见昵称：小林'));
    expect(response.replies.single.text, '刚忙完，才看到你消息');
  });

  test('two step vision accepts nested conversation extraction containers',
      () async {
    final paths = <String>[];
    final bodies = <Map<String, dynamic>>[];
    final dio = _fakeDio(
      paths: paths,
      bodies: bodies,
      responses: const [
        _FakeApiResponse(200, {
          'choices': [
            {
              'message': {
                'content':
                    '{"conversation":{"messages":[{"speaker":"对方","text":"周末还去吗"},{"speaker":"我","text":"看你时间"}]},"context":"确认周末安排","latest":"周末还去吗"}',
              },
            },
          ],
        }),
        _FakeApiResponse(200, {
          'choices': [
            {
              'message': {
                'content':
                    '{"sceneSummary":"确认周末安排","replies":[{"text":"去呀，你几点方便？","styleLabel":"自然"}]}',
              },
            },
          ],
        }),
      ],
    );
    final config = APIConfig.defaults.copyWith(
      baseURL: 'https://api.example/v1',
      enableTwoStepVision: true,
    );

    final response = await OpenAICompatibleApi(dioFactory: (_) => dio)
        .generateReplyFromImage(
      const ImagePayload(
        base64: 'abc',
        mimeType: 'image/jpeg',
        width: 1,
        height: 1,
        sizeInBytes: 3,
      ),
      ChatStyle.defaultStyle,
      null,
      null,
      null,
      config,
      'sk-test',
    );

    expect(paths, ['/v1/chat/completions', '/v1/chat/completions']);
    final secondUserMessage = ((bodies.last['messages'] as List).last as Map);
    expect(secondUserMessage['content'], contains('对方：周末还去吗'));
    expect(secondUserMessage['content'], contains('我：看你时间'));
    expect(secondUserMessage['content'], contains('截图场景：确认周末安排'));
    expect(response.replies.single.text, '去呀，你几点方便？');
  });

  test('two step vision accepts OCR line extraction aliases', () async {
    final paths = <String>[];
    final bodies = <Map<String, dynamic>>[];
    final dio = _fakeDio(
      paths: paths,
      bodies: bodies,
      responses: const [
        _FakeApiResponse(200, {
          'choices': [
            {
              'message': {
                'content':
                    '{"ocrLines":["对方：今晚几点","我：七点后都行"],"summary":"约晚饭","last":"今晚几点"}',
              },
            },
          ],
        }),
        _FakeApiResponse(200, {
          'choices': [
            {
              'message': {
                'content':
                    '{"sceneSummary":"约晚饭","replies":[{"text":"七点半可以吗？","styleLabel":"自然"}]}',
              },
            },
          ],
        }),
      ],
    );
    final config = APIConfig.defaults.copyWith(
      baseURL: 'https://api.example/v1',
      enableTwoStepVision: true,
    );

    final response = await OpenAICompatibleApi(dioFactory: (_) => dio)
        .generateReplyFromImage(
      const ImagePayload(
        base64: 'abc',
        mimeType: 'image/jpeg',
        width: 1,
        height: 1,
        sizeInBytes: 3,
      ),
      ChatStyle.defaultStyle,
      null,
      null,
      null,
      config,
      'sk-test',
    );

    expect(paths, ['/v1/chat/completions', '/v1/chat/completions']);
    final secondUserMessage = ((bodies.last['messages'] as List).last as Map);
    expect(secondUserMessage['content'], contains('对方：今晚几点'));
    expect(secondUserMessage['content'], contains('我：七点后都行'));
    expect(response.replies.single.text, '七点半可以吗？');
  });

  test('two step vision accepts snake case extraction fields', () async {
    final paths = <String>[];
    final bodies = <Map<String, dynamic>>[];
    final dio = _fakeDio(
      paths: paths,
      bodies: bodies,
      responses: const [
        _FakeApiResponse(200, {
          'choices': [
            {
              'message': {
                'content':
                    '{"ocr_lines":[{"sender_name":"对方","message_text":"你到哪了"},{"sender_name":"我","message_text":"马上到"}],"scene_summary":"迟到解释","latest_message":"你到哪了","visible_name":"小林","note":"语气有点急"}',
              },
            },
          ],
        }),
        _FakeApiResponse(200, {
          'choices': [
            {
              'message': {
                'content':
                    '{"scene_summary":"迟到解释","reply_suggestions":[{"text":"抱歉让你等了，我马上到。","style_label":"修复"}]}',
              },
            },
          ],
        }),
      ],
    );
    final config = APIConfig.defaults.copyWith(
      baseURL: 'https://api.example/v1',
      enableTwoStepVision: true,
    );

    final response = await OpenAICompatibleApi(dioFactory: (_) => dio)
        .generateReplyFromImage(
      const ImagePayload(
        base64: 'abc',
        mimeType: 'image/jpeg',
        width: 1,
        height: 1,
        sizeInBytes: 3,
      ),
      ChatStyle.defaultStyle,
      null,
      null,
      null,
      config,
      'sk-test',
    );

    expect(paths, ['/v1/chat/completions', '/v1/chat/completions']);
    final secondUserMessage = ((bodies.last['messages'] as List).last as Map);
    expect(secondUserMessage['content'], contains('对方：你到哪了'));
    expect(secondUserMessage['content'], contains('我：马上到'));
    expect(secondUserMessage['content'], contains('截图场景：迟到解释'));
    expect(secondUserMessage['content'], contains('对方最后一句：你到哪了'));
    expect(secondUserMessage['content'], contains('可见昵称：小林'));
    expect(secondUserMessage['content'], contains('识别备注：语气有点急'));
    expect(response.sceneSummary, '迟到解释');
    expect(response.replies.single.styleLabel, '修复');
    expect(response.replies.single.text, '抱歉让你等了，我马上到。');
  });

  test('two step vision accepts common OCR speaker and text aliases', () async {
    final paths = <String>[];
    final bodies = <Map<String, dynamic>>[];
    final dio = _fakeDio(
      paths: paths,
      bodies: bodies,
      responses: const [
        _FakeApiResponse(200, {
          'choices': [
            {
              'message': {
                'content':
                    '{"lines":[{"from":"对方","utterance":"你几点能到"},{"user":"我","lineText":"七点左右"},{"displayName":"对方","ocrText":"那我先过去"}],"scene":"到达时间确认","latest":"那我先过去"}',
              },
            },
          ],
        }),
        _FakeApiResponse(200, {
          'choices': [
            {
              'message': {
                'content':
                    '{"sceneSummary":"到达时间确认","replies":[{"text":"好，我七点左右到，到了联系你。","styleLabel":"自然"}]}',
              },
            },
          ],
        }),
      ],
    );
    final config = APIConfig.defaults.copyWith(
      baseURL: 'https://api.example/v1',
      enableTwoStepVision: true,
    );

    final response = await OpenAICompatibleApi(dioFactory: (_) => dio)
        .generateReplyFromImage(
      const ImagePayload(
        base64: 'abc',
        mimeType: 'image/jpeg',
        width: 1,
        height: 1,
        sizeInBytes: 3,
      ),
      ChatStyle.defaultStyle,
      null,
      null,
      null,
      config,
      'sk-test',
    );

    expect(paths, ['/v1/chat/completions', '/v1/chat/completions']);
    final secondUserMessage = ((bodies.last['messages'] as List).last as Map);
    expect(secondUserMessage['content'], contains('对方：你几点能到'));
    expect(secondUserMessage['content'], contains('我：七点左右'));
    expect(secondUserMessage['content'], contains('对方：那我先过去'));
    expect(secondUserMessage['content'], contains('截图场景：到达时间确认'));
    expect(secondUserMessage['content'], contains('对方最后一句：那我先过去'));
    expect(response.sceneSummary, '到达时间确认');
    expect(response.replies.single.text, '好，我七点左右到，到了联系你。');
  });

  test('two step vision extracts nested provider message containers', () async {
    final paths = <String>[];
    final bodies = <Map<String, dynamic>>[];
    final dio = _fakeDio(
      paths: paths,
      bodies: bodies,
      responses: const [
        _FakeApiResponse(200, {
          'choices': [
            {
              'message': {
                'content':
                    '{"conversation":{"items":[{"sender":"对方","message":"今晚见吗"},{"sender":"我","message":"可以，几点"}]},"scene":"确认见面时间"}',
              },
            },
          ],
        }),
        _FakeApiResponse(200, {
          'choices': [
            {
              'message': {
                'content':
                    '{"sceneSummary":"确认见面时间","replies":[{"text":"可以呀，你几点方便？","styleLabel":"自然"}]}',
              },
            },
          ],
        }),
      ],
    );
    final config = APIConfig.defaults.copyWith(
      baseURL: 'https://api.example/v1',
      enableTwoStepVision: true,
    );

    final response = await OpenAICompatibleApi(dioFactory: (_) => dio)
        .generateReplyFromImage(
      const ImagePayload(
        base64: 'abc',
        mimeType: 'image/jpeg',
        width: 1,
        height: 1,
        sizeInBytes: 3,
      ),
      ChatStyle.defaultStyle,
      null,
      null,
      null,
      config,
      'sk-test',
    );

    expect(paths, ['/v1/chat/completions', '/v1/chat/completions']);
    final secondUserMessage = ((bodies.last['messages'] as List).last as Map);
    expect(secondUserMessage['content'], contains('对方：今晚见吗'));
    expect(secondUserMessage['content'], contains('我：可以，几点'));
    expect(secondUserMessage['content'], contains('截图场景：确认见面时间'));
    expect(secondUserMessage['content'], isNot(contains('{items:')));
    expect(response.replies.single.text, '可以呀，你几点方便？');
  });

  test('two step vision accepts provider data row containers', () async {
    final paths = <String>[];
    final bodies = <Map<String, dynamic>>[];
    final dio = _fakeDio(
      paths: paths,
      bodies: bodies,
      responses: const [
        _FakeApiResponse(200, {
          'choices': [
            {
              'message': {
                'content':
                    '{"data":{"rows":[{"sender":"对方","text":"明天还开会吗"},{"sender":"我","text":"等通知"}]},"summary":"确认会议","latest":"明天还开会吗"}',
              },
            },
          ],
        }),
        _FakeApiResponse(200, {
          'choices': [
            {
              'message': {
                'content':
                    '{"sceneSummary":"确认会议","replies":[{"text":"目前等通知，有消息我跟你说。","styleLabel":"自然"}]}',
              },
            },
          ],
        }),
      ],
    );
    final config = APIConfig.defaults.copyWith(
      baseURL: 'https://api.example/v1',
      enableTwoStepVision: true,
    );

    final response = await OpenAICompatibleApi(dioFactory: (_) => dio)
        .generateReplyFromImage(
      const ImagePayload(
        base64: 'abc',
        mimeType: 'image/jpeg',
        width: 1,
        height: 1,
        sizeInBytes: 3,
      ),
      ChatStyle.defaultStyle,
      null,
      null,
      null,
      config,
      'sk-test',
    );

    expect(paths, ['/v1/chat/completions', '/v1/chat/completions']);
    final secondUserMessage = ((bodies.last['messages'] as List).last as Map);
    expect(secondUserMessage['content'], contains('对方：明天还开会吗'));
    expect(secondUserMessage['content'], contains('我：等通知'));
    expect(secondUserMessage['content'], contains('截图场景：确认会议'));
    expect(secondUserMessage['content'], isNot(contains('{rows:')));
    expect(response.replies.single.text, '目前等通知，有消息我跟你说。');
  });

  test('official styles preserve original iOS presets', () {
    expect(ChatStyle.presets.map((e) => e.name),
        ['自然', '松弛', '暧昧', '幽默', '温柔', '安慰', '道歉', '职场']);
    expect(ChatStyle.presets.map((e) => e.id), [
      'official-natural',
      'official-relaxed',
      'official-flirty',
      'official-humor',
      'official-gentle',
      'official-comfort',
      'official-apology',
      'official-workplace',
    ]);
    expect(
      ChatStyle.presets
          .map((style) => {
                'name': style.name,
                'description': style.description,
                'rules': style.rules,
                'isOfficial': style.isOfficial,
              })
          .toList(),
      [
        {
          'name': '自然',
          'description': '像真人日常聊天，不刻意、不油腻',
          'rules': ['语气自然', '不要太正式', '不要过度讨好', '每条回复不超过40字'],
          'isOfficial': true,
        },
        {
          'name': '松弛',
          'description': '轻一点接住话题，给对方舒服空间',
          'rules': ['语气放松', '避免压迫感', '不要连环追问', '保留一点余地'],
          'isOfficial': true,
        },
        {
          'name': '暧昧',
          'description': '有一点心动感，但不过界',
          'rules': ['轻微暧昧', '不低俗', '不强行推进关系', '保持分寸'],
          'isOfficial': true,
        },
        {
          'name': '幽默',
          'description': '用轻松玩笑缓和氛围',
          'rules': ['自然幽默', '不要阴阳怪气', '不冒犯对方', '优先让对方好接'],
          'isOfficial': true,
        },
        {
          'name': '温柔',
          'description': '柔和、体贴、稳定地回应',
          'rules': ['语气温柔', '表达理解', '不说教', '不过度煽情'],
          'isOfficial': true,
        },
        {
          'name': '安慰',
          'description': '先接住情绪，再给一点陪伴',
          'rules': ['先共情', '避免空洞鸡汤', '不要否定对方感受', '表达陪伴'],
          'isOfficial': true,
        },
        {
          'name': '道歉',
          'description': '解释但不卑微，承担该承担的部分',
          'rules': ['真诚道歉', '不甩锅', '解释克制', '给出改进态度'],
          'isOfficial': true,
        },
        {
          'name': '职场',
          'description': '清晰、有边界、礼貌专业',
          'rules': ['表达清楚', '语气礼貌', '不情绪化', '保留边界'],
          'isOfficial': true,
        },
      ],
    );
  });

  test('personalization trims custom styles and notes', () {
    final settings = ReplyPersonalizationSettings(
      userAgeText: '未知',
      memoryNotes: '  少一点 AI 腔  ',
      customStyles: [
        ChatStyle(
          id: ' custom-style ',
          name: '  克制  ',
          description: '未知',
          rules: [' 短句 ', '未知', ' '],
        ),
        ChatStyle(
          id: ' ignored-style ',
          name: '未知',
          description: '不应保留',
          rules: ['无效'],
        ),
      ],
    ).normalized();
    expect(settings.userAgeText, '');
    expect(settings.memoryNotes, '少一点 AI 腔');
    expect(settings.customStyles, hasLength(1));
    expect(settings.customStyles.single.id, 'custom-style');
    expect(settings.customStyles.single.name, '克制');
    expect(settings.customStyles.single.description, '');
    expect(settings.customStyles.single.rules, ['短句']);
  });

  test('custom style draft helper cleans name description and rule text', () {
    expect(canCreateCustomChatStyleDraft('未知'), isFalse);
    expect(canCreateCustomChatStyleDraft('  我平时说话  '), isTrue);

    final style = customChatStyleFromDraft(
      name: '  我平时说话  ',
      description: '未知',
      rulesText: '  短一点，少问；自然一点\n未知 ',
    );

    expect(style?.name, '我平时说话');
    expect(style?.description, '按我的日常聊天习惯生成');
    expect(style?.rules, ['短一点', '少问', '自然一点']);

    final fallback = customChatStyleFromDraft(
      name: '克制',
      description: '少解释',
      rulesText: '未知',
    );
    expect(fallback?.rules, ['少解释']);
  });

  test('chat style json cleans noisy presentation values', () {
    final style = ChatStyle(
      id: ' custom-style ',
      name: '  克制  ',
      description: '未知',
      rules: [' 短句 ', '未知', ' '],
      isOfficial: false,
    );

    expect(style.id, 'custom-style');

    final json = style.toJson();
    final restored = ChatStyle.fromJson(json);

    expect(json['id'], 'custom-style');
    expect(json['name'], '克制');
    expect(json['description'], '');
    expect(json['rules'], ['短句']);
    expect(json['isOfficial'], isFalse);
    expect(restored.id, 'custom-style');
    expect(restored.name, '克制');
    expect(restored.description, '');
    expect(restored.rules, ['短句']);
    expect(restored.isOfficial, isFalse);

    final styleSource =
        File('lib/core/chat_style_models.dart').readAsStringSync();
    final personalizationSource =
        File('lib/core/personalization_models.dart').readAsStringSync();
    expect(
      styleSource,
      contains('}) : id = cleanIdentifierText(id) ?? _uuid.v4();'),
    );
    expect(
      styleSource,
      contains("'id': cleanIdentifierText(id) ?? _uuid.v4(),"),
    );
    expect(styleSource, isNot(contains('id.trim().isEmpty')));
    expect(personalizationSource, contains('normalizedChatStyleId(style.id)'));
    expect(
      personalizationSource,
      contains("var id = cleanIdentifierText(style.id) ?? '';"),
    );
    expect(personalizationSource, isNot(contains('style.id.trim()')));
  });

  test('chat style id helpers ignore spacing and case drift', () {
    final officialStyle = ChatStyle(
      id: 'official-calm',
      name: ' Calm ',
      description: '官方',
      rules: const ['短句'],
    );
    final duplicateCustomStyle = ChatStyle(
      id: 'custom-calm',
      name: 'calm',
      description: '自定义',
      rules: const ['少问'],
      isOfficial: false,
    );
    final styles = [
      ChatStyle(
        id: 'Custom-Soft',
        name: '克制',
        description: '短一点',
        rules: const ['少问'],
        isOfficial: false,
      ),
    ];
    final spacedRuntimeStyle = ChatStyle(
      id: ' Custom-Soft ',
      name: '带空格',
      description: '运行态清理',
      rules: const ['短句'],
      isOfficial: false,
    );

    expect(spacedRuntimeStyle.id, 'Custom-Soft');
    expect(normalizedChatStyleId(' Custom-Soft '), 'custom-soft');
    expect(normalizedChatStyleId('   '), isNull);
    expect(cleanIdentifierText('  未知  '), '未知');
    expect(chatStyleIdsMatch(' Custom-Soft ', 'custom-soft'), isTrue);
    expect(chatStyleIdsMatch('Custom-Soft', 'other'), isFalse);
    expect(chatStyleById(styles, ' custom-soft '), same(styles.single));
    expect(chatStyleById(styles, null), isNull);
    expect(normalizedChatStyleName(' Calm '), 'calm');
    expect(normalizedChatStyleName('未知'), isNull);
    expect(chatStyleNamesMatch(' Calm ', 'calm'), isTrue);
    expect(
      chatStyleByName([officialStyle, duplicateCustomStyle], ' CALM ',
          preferOfficial: true),
      same(officialStyle),
    );
    expect(
      chatStyleByName([officialStyle, duplicateCustomStyle], ' CALM '),
      isNull,
    );
  });

  test('personalization json writes normalized settings', () {
    final settings = ReplyPersonalizationSettings(
      userAgeText: '未知',
      memoryNotes: '  少一点 AI 腔  ',
      customStyles: [
        ChatStyle(
          id: ' custom-style ',
          name: '  克制  ',
          description: '未知',
          rules: [' 短句 ', '未知', ' '],
        ),
        ChatStyle(
          id: ' ignored-style ',
          name: '未知',
          description: '不应保留',
          rules: ['无效'],
        ),
      ],
    );

    final json = settings.toJson();
    final styles = json['customStyles'] as List<Object?>;
    final firstStyle = Map<String, dynamic>.from(styles.single as Map);
    final restored = ReplyPersonalizationSettings.fromJson(json);

    expect(json['userAgeText'], '');
    expect(json['memoryNotes'], '少一点 AI 腔');
    expect(styles, hasLength(1));
    expect(firstStyle['id'], 'custom-style');
    expect(firstStyle['name'], '克制');
    expect(firstStyle['description'], '');
    expect(firstStyle['rules'], ['短句']);
    expect(firstStyle['isOfficial'], isFalse);
    expect(restored.userAgeText, '');
    expect(restored.memoryNotes, '少一点 AI 腔');
    expect(restored.customStyles, hasLength(1));
    expect(restored.customStyles.single.id, 'custom-style');
    expect(restored.customStyles.single.name, '克制');
    expect(restored.customStyles.single.description, '');
    expect(restored.customStyles.single.rules, ['短句']);
    expect(restored.customStyles.single.isOfficial, isFalse);
  });

  test('personalization assigns safe ids to imported custom style conflicts',
      () {
    final settings = ReplyPersonalizationSettings(
      customStyles: [
        ChatStyle(
          id: 'official-natural',
          name: '撞官方',
          description: '导入数据',
          rules: const ['短句'],
          isOfficial: false,
        ),
        ChatStyle(
          id: 'OFFICIAL-WORKPLACE',
          name: '大小写撞官方',
          description: '导入数据',
          rules: const ['清楚'],
          isOfficial: false,
        ),
        ChatStyle(
          id: 'duplicate-custom',
          name: '保留第一个',
          description: '导入数据',
          rules: const ['少问'],
          isOfficial: false,
        ),
        ChatStyle(
          id: 'Duplicate-Custom',
          name: '修复大小写重复',
          description: '导入数据',
          rules: const ['轻一点'],
          isOfficial: false,
        ),
        ChatStyle(
          id: '',
          name: '修复空 id',
          description: '导入数据',
          rules: const ['自然点'],
          isOfficial: false,
        ),
      ],
    ).normalized();

    final ids = settings.customStyles.map((style) => style.id).toList();

    expect(settings.customStyles.map((style) => style.isOfficial),
        everyElement(isFalse));
    expect(ids.toSet(), hasLength(ids.length));
    expect(ids, isNot(contains('official-natural')));
    expect(ids.map((id) => id.toLowerCase()),
        isNot(contains('official-workplace')));
    expect(ids.where((id) => id == 'duplicate-custom'), hasLength(1));
    expect(
        ids
            .map((id) => id.toLowerCase())
            .where((id) => id == 'duplicate-custom'),
        hasLength(1));
    expect(ids.every((id) => id.isNotEmpty), isTrue);
  });

  test('personalization summary reflects enabled features', () {
    final settings = ReplyPersonalizationSettings(
      userGender: UserGender.female,
      userAgeText: '  95 后  ',
      memoryNotes: '少追问',
      customStyles: [
        ChatStyle(name: '克制', description: '短句', rules: ['少问'])
      ],
    );

    expect(settings.enabledFeatureSummary, contains('口语化'));
    expect(settings.enabledFeatureSummary, contains('我的资料'));
    expect(settings.enabledFeatureSummary, contains('记忆'));
    expect(settings.enabledFeatureSummary, contains('自适应'));
    expect(settings.enabledFeatureSummary, contains('自定义风格 1'));
    expect(settings.enabledFeatureSummary, isNot(contains('有手动记忆')));

    const quiet = ReplyPersonalizationSettings(
      isConversationMemoryEnabled: false,
      isAdaptiveStyleEnabled: false,
    );
    expect(quiet.enabledFeatureSummary, '口语化');

    const noisyAge = ReplyPersonalizationSettings(
      isConversationMemoryEnabled: false,
      isAdaptiveStyleEnabled: false,
      userAgeText: '未知',
    );
    expect(noisyAge.enabledFeatureSummary, isNot(contains('我的资料')));
    final noisyCustomStyle = ReplyPersonalizationSettings(
      isConversationMemoryEnabled: false,
      isAdaptiveStyleEnabled: false,
      customStyles: [
        ChatStyle(name: '未知', description: '占位', rules: const ['短句']),
      ],
    );
    expect(
      noisyCustomStyle.enabledFeatureSummary,
      isNot(contains('自定义风格')),
    );
  });

  test('personalization prompt mirrors iOS memory and adaptive style context',
      () {
    final app = AppController()
      ..personalization = const ReplyPersonalizationSettings(
        memoryNotes: '少追问',
      )
      ..history = [
        GenerationRecord(
          inputType: ChatInputType.text,
          sceneSummary: '较早的约饭',
          latestMessage: '中午吃什么',
          selectedStyleName: '轻松',
          copiedReply: '你定，我跟着',
          replies: [
            ReplySuggestion(styleLabel: '轻松', text: '你定，我跟着', reason: ''),
          ],
          createdAt: DateTime(2026, 1, 1),
        ),
        GenerationRecord(
          inputType: ChatInputType.text,
          sceneSummary: '最新的约饭',
          latestMessage: '晚上吃什么',
          selectedStyleName: '自然',
          copiedReply: '都可以，看你想吃啥',
          replies: [
            ReplySuggestion(styleLabel: '自然', text: '都可以，看你想吃啥', reason: ''),
            ReplySuggestion(styleLabel: '轻松', text: '我都行，你定一个？', reason: ''),
          ],
          createdAt: DateTime(2026, 1, 2),
        ),
      ];

    final context = app.personalizationPromptContext();

    expect(context, contains('用户手动记忆'));
    expect(context, contains('少追问'));
    expect(context, contains('1. 对方最后一句：晚上吃什么'));
    expect(context, contains('2. 对方最后一句：中午吃什么'));
    expect(context.indexOf('最新的约饭'), lessThan(context.indexOf('较早的约饭')));
    expect(context, contains('当时候选示例：都可以，看你想吃啥 / 我都行，你定一个？'));
    expect(context, contains('自适应我的风格'));
    expect(context, contains('用户最近采用过的回复'));
    expect(context, contains('“都可以，看你想吃啥”（自然）'));
    expect(context.indexOf('“都可以，看你想吃啥”（自然）'),
        lessThan(context.indexOf('“你定，我跟着”（轻松）')));
    expect(context, contains('当前选择风格优先级高于人物库、历史记忆、已采用回复和自定义偏好'));
    expect(context, contains('如果历史采用回复或人物库语气与当前风格冲突'));
    expect(context, contains('先选清楚每条候选的策略'));
    expect(context, contains('不要为了显得高情商而过度解释'));
    expect(context, contains('如果冲突，以当前选择风格为准'));
    expect(context, contains('不要复读原句'));
    expect(context, contains('不要突然暧昧或过度亲密'));
  });

  test('personalization prompt cleans noisy history before model context', () {
    final app = AppController()
      ..personalization = const ReplyPersonalizationSettings(
        userAgeText: '未知',
        memoryNotes: '  未知  ',
      )
      ..history = [
        GenerationRecord(
          inputType: ChatInputType.text,
          sceneSummary: '  晚饭安排  ',
          latestMessage: '  晚上吃啥  ',
          selectedStyleName: '未知',
          copiedReply: '  好呀  ',
          replies: [
            ReplySuggestion(styleLabel: '自然', text: '  ', reason: ''),
            ReplySuggestion(styleLabel: '自然', text: '未知', reason: ''),
            ReplySuggestion(styleLabel: '自然', text: '可以呀', reason: ''),
            ReplySuggestion(styleLabel: '自然', text: '可以呀', reason: '重复'),
            ReplySuggestion(styleLabel: '自然', text: '另一句', reason: ''),
          ],
          createdAt: DateTime(2026, 1, 1),
        ),
      ];

    final context = app.personalizationPromptContext();

    expect(context, isNot(contains('我的年龄')));
    expect(context, isNot(contains('用户手动记忆')));
    expect(context, isNot(contains('未知')));
    expect(context, contains('对方最后一句：晚上吃啥'));
    expect(context, contains('场景：晚饭安排'));
    expect(context, contains('用户采用过：好呀'));
    expect(context, contains('当时风格：自然'));
    expect(context, contains('当时候选示例：可以呀 / 另一句'));
    expect(context, isNot(contains('当时候选示例：可以呀 / 可以呀')));
    expect(context, contains('“好呀”（自然）'));
  });

  test(
      'personalization prompt keeps adaptive style enabled without copy history',
      () {
    final app = AppController();

    final context = app.personalizationPromptContext();

    expect(context, contains('自适应我的风格：开启'));
    expect(context, contains('候选回复质量要求'));
  });

  test('prompt context caches refresh when history or profiles change', () {
    final oldHistory = GenerationRecord(
      inputType: ChatInputType.text,
      sceneSummary: '旧场景',
      latestMessage: '旧消息',
      selectedStyleName: '自然',
      replies: [
        ReplySuggestion(styleLabel: '自然', text: '旧回复', reason: ''),
      ],
      createdAt: DateTime(2026, 1, 1),
    );
    final newHistory = GenerationRecord(
      inputType: ChatInputType.text,
      sceneSummary: '新场景',
      latestMessage: '新消息',
      selectedStyleName: '松弛',
      copiedReply: '新采用',
      replies: [
        ReplySuggestion(styleLabel: '松弛', text: '新回复', reason: ''),
      ],
      createdAt: DateTime(2026, 1, 2),
    );
    final oldProfile = PersonProfile(
      id: 'target',
      displayName: '小林',
      tonePreferences: const ['旧语气'],
    );
    final newProfile = PersonProfile(
      id: 'target',
      displayName: '小林',
      tonePreferences: const ['新语气'],
    );
    final app = AppController()
      ..history = [oldHistory]
      ..profiles = [oldProfile];

    expect(app.personalizationPromptContext(), contains('旧消息'));
    expect(app.makePersonProfileContext(selectedProfileId: 'target'),
        contains('旧语气'));

    app.history.insert(0, newHistory);
    app.profiles = [newProfile];

    final refreshedPersonalization = app.personalizationPromptContext();
    final refreshedProfile =
        app.makePersonProfileContext(selectedProfileId: 'target');
    expect(refreshedPersonalization, contains('新消息'));
    expect(refreshedPersonalization, contains('新采用'));
    expect(refreshedPersonalization.indexOf('新消息'),
        lessThan(refreshedPersonalization.indexOf('旧消息')));
    expect(refreshedProfile, contains('新语气'));
    expect(refreshedProfile, isNot(contains('旧语气')));
  });

  test('profile prompt cache marker reuses prompt summary lines', () {
    final source =
        File('lib/core/prompt_context_builder.dart').readAsStringSync();
    final markerStart = source.indexOf('String _profilePromptMarker(');
    final markerEnd = source.indexOf('\n  }\n}', markerStart);
    final markerSource = source.substring(markerStart, markerEnd);

    expect(markerSource, contains('profile.promptSummaryLines.join'));
    expect(markerSource, isNot(contains('profile.summaryForPrompt')));
    expect(markerSource, isNot(contains('profile.tonePreferences.join')));
    expect(markerSource, isNot(contains('profile.boundaries.join')));
  });

  test('default chat style persists and restores by id', () async {
    final customStyle = ChatStyle(
      id: 'custom-style',
      name: '自然',
      description: '同名自定义风格',
      rules: const ['只用短句'],
      isOfficial: false,
    );
    final store = FakeStore()
      ..loadedDefaultStyleId = customStyle.id
      ..loadedPersonalization =
          ReplyPersonalizationSettings(customStyles: [customStyle]);
    final app = AppController(store: store);

    await app.load();

    expect(app.defaultStyle.id, customStyle.id);
    await app.setDefaultStyle(ChatStyle.presets.last);
    expect(store.savedDefaultStyleId, ChatStyle.presets.last.id);
  });

  test('default chat style restores by normalized custom style id', () async {
    final customStyle = ChatStyle(
      id: 'Custom-Style',
      name: '克制',
      description: '同名自定义风格',
      rules: const ['只用短句'],
      isOfficial: false,
    );
    final store = FakeStore()
      ..loadedDefaultStyleId = ' custom-style '
      ..loadedPersonalization =
          ReplyPersonalizationSettings(customStyles: [customStyle]);
    final app = AppController(store: store);

    await app.load();

    expect(app.defaultStyle, same(app.personalization.customStyles.single));
    expect(app.defaultStyle.id, 'Custom-Style');
  });

  test('default chat style restores after load-time personalization cleanup',
      () async {
    final store = FakeStore()
      ..loadedDefaultStyleId = '  自定义慢回  '
      ..loadedPersonalization = ReplyPersonalizationSettings(customStyles: [
        ChatStyle(
          id: ' official-natural ',
          name: '  自定义慢回  ',
          description: '  保留空间  ',
          rules: const ['  慢一点  ', ''],
          isOfficial: false,
        ),
      ]);
    final app = AppController(store: store);

    await app.load();

    final restoredStyle = app.personalization.customStyles.single;
    expect(restoredStyle.name, '自定义慢回');
    expect(restoredStyle.description, '保留空间');
    expect(restoredStyle.rules, ['慢一点']);
    expect(normalizedChatStyleId(restoredStyle.id),
        isNot(normalizedChatStyleId('official-natural')));
    expect(app.defaultStyle, same(restoredStyle));
  });

  test('removing a custom style clears stale generation style references',
      () async {
    final customStyle = ChatStyle(
      id: 'deleted-custom-style',
      name: '旧自定义',
      description: '待删除风格',
      rules: const ['只用短句'],
      isOfficial: false,
    );
    final store = FakeStore();
    final app = AppController(store: store)
      ..personalization =
          ReplyPersonalizationSettings(customStyles: [customStyle])
      ..defaultStyle = customStyle
      ..currentStyle = customStyle
      ..lastInput = ChatInput(
        type: ChatInputType.text,
        text: '对方：晚上吃啥',
        selectedStyle: customStyle,
      );

    await app.savePersonalization(ReplyPersonalizationSettings.defaults);

    expect(app.personalization.customStyles, isEmpty);
    expect(app.defaultStyle, ChatStyle.defaultStyle);
    expect(app.currentStyle, ChatStyle.defaultStyle);
    expect(app.lastInput?.selectedStyle, ChatStyle.defaultStyle);
    expect(store.savedDefaultStyleId, ChatStyle.defaultStyle.id);
  });

  test('default style setter rejects stale custom styles', () async {
    final staleStyle = ChatStyle(
      id: 'deleted-custom-style',
      name: '旧自定义',
      description: '已被删除',
      rules: const ['旧规则'],
      isOfficial: false,
    );
    final store = FakeStore();
    final app = AppController(store: store);

    await app.setDefaultStyle(staleStyle);

    expect(app.defaultStyle, ChatStyle.defaultStyle);
    expect(store.savedDefaultStyleId, ChatStyle.defaultStyle.id);
  });

  test('default style setter accepts legacy iOS official style names',
      () async {
    final store = FakeStore();
    final app = AppController(store: store);
    final legacyWorkplace = ChatStyle(
      id: 'legacy-ios-workplace',
      name: '职场',
      description: '旧 iOS 风格对象',
      rules: const ['清晰'],
    );

    await app.setDefaultStyle(legacyWorkplace);

    expect(app.defaultStyle.id, 'official-workplace');
    expect(store.savedDefaultStyleId, 'official-workplace');
  });

  test('default style setter refreshes current style from previous default',
      () async {
    final nextDefaultStyle = ChatStyle.presets.last;
    final store = FakeStore();
    final app = AppController(store: store)
      ..defaultStyle = ChatStyle.defaultStyle
      ..currentStyle = ChatStyle.defaultStyle;

    await app.setDefaultStyle(nextDefaultStyle);

    expect(app.defaultStyle, nextDefaultStyle);
    expect(app.currentStyle, same(app.defaultStyle));
    expect(store.savedDefaultStyleId, nextDefaultStyle.id);
  });

  test('default style setter preserves active non default current style',
      () async {
    final activeStyle = ChatStyle.presets[1];
    final nextDefaultStyle = ChatStyle.presets.last;
    final store = FakeStore();
    final app = AppController(store: store)
      ..defaultStyle = ChatStyle.defaultStyle
      ..currentStyle = activeStyle;

    await app.setDefaultStyle(nextDefaultStyle);

    expect(app.defaultStyle, nextDefaultStyle);
    expect(app.currentStyle, same(activeStyle));
    expect(store.savedDefaultStyleId, nextDefaultStyle.id);
  });

  test('default style setter does not name-match duplicate custom conflicts',
      () async {
    final duplicateNameCustomStyle = ChatStyle(
      id: 'custom-natural',
      name: '自然',
      description: '同名自定义',
      rules: const ['短句'],
      isOfficial: false,
    );
    final staleDuplicateCustomStyle = ChatStyle(
      id: 'deleted-natural',
      name: '自然',
      description: '已删除同名自定义',
      rules: const ['旧规则'],
      isOfficial: false,
    );
    final store = FakeStore();
    final app = AppController(store: store)
      ..personalization = ReplyPersonalizationSettings(
        customStyles: [duplicateNameCustomStyle],
      );

    await app.setDefaultStyle(staleDuplicateCustomStyle);

    expect(app.defaultStyle, ChatStyle.defaultStyle);
    expect(store.savedDefaultStyleId, ChatStyle.defaultStyle.id);
  });

  test('stale default style save cannot recreate key after clear all',
      () async {
    final store = DeferredPreferenceStore()..delayDefaultStyleSave = true;
    final app = AppController(store: store);

    final pending = app.setDefaultStyle(ChatStyle.presets.last);
    await store.defaultStyleStarted.future;

    await app.clearAllLocalData();
    store.defaultStyleRelease.complete();
    await pending;

    expect(app.defaultStyle, ChatStyle.defaultStyle);
    expect(store.savedDefaultStyleId, isNull);
    expect(store.didClearAll, isTrue);
  });

  test('personalization save paths share revision guard', () {
    final source =
        File('lib/core/app_state_personalization.dart').readAsStringSync();
    final runtimeSource =
        File('lib/core/app_state_runtime_helpers.dart').readAsStringSync();

    expect(source, contains('Future<bool> _persistPreferencesForRevision({'));
    expect(runtimeSource, contains('int _beginPreferencesMutation()'));
    expect(runtimeSource, contains('bool _isCurrentPreferencesRevision('));
    expect(runtimeSource, contains('int _captureLocalDataClearRevision()'));
    expect(runtimeSource, contains('bool _isCurrentLocalDataClearRevision('));
    expect(
      RegExp(r'_persistPreferencesForRevision\(').allMatches(source).length,
      3,
    );
    expect(
      RegExp(r'_beginPreferencesMutation\(\);').allMatches(source).length,
      2,
    );
    expect(source, contains('_isCurrentPreferencesRevision('));
    expect(source, contains('_captureLocalDataClearRevision();'));
    expect(source, contains('_isCurrentLocalDataClearRevision('));
    expect(source, contains('clearPersisted: _clearPersistedPersonalization'));
    expect(source, contains('persistLatest: _persistDefaultStyleId'));
    expect(
      source,
      isNot(contains('if (requestRevision != _preferencesRevision)')),
    );
    expect(source, isNot(contains('++_preferencesRevision')));
    expect(source, isNot(contains('revision == _preferencesRevision')));
    expect(source, isNot(contains('_localDataClearRevision')));
  });

  test('stale default style save rewrites latest preference when not cleared',
      () async {
    final store = DeferredPreferenceStore()..delayDefaultStyleSave = true;
    final app = AppController(store: store);
    final firstStyle = ChatStyle.presets.firstWhere(
      (style) => style.id != ChatStyle.presets.last.id,
    );
    final latestStyle = ChatStyle.presets.last;

    final first = app.setDefaultStyle(firstStyle);
    await store.defaultStyleStarted.future;

    await app.setDefaultStyle(latestStyle);
    expect(app.defaultStyle, latestStyle);
    expect(store.savedDefaultStyleId, latestStyle.id);

    store.defaultStyleRelease.complete();
    await first;

    expect(app.defaultStyle, latestStyle);
    expect(store.savedDefaultStyleId, latestStyle.id);
  });

  test('updating a custom style refreshes active generation style references',
      () async {
    final oldStyle = ChatStyle(
      id: 'custom-style-to-update',
      name: '旧自定义',
      description: '旧说明',
      rules: const ['旧规则'],
      isOfficial: false,
    );
    final updatedStyle = ChatStyle(
      id: oldStyle.id,
      name: '新自定义',
      description: '新说明',
      rules: const ['新规则'],
      isOfficial: false,
    );
    final store = FakeStore();
    final app = AppController(store: store)
      ..personalization = ReplyPersonalizationSettings(customStyles: [oldStyle])
      ..defaultStyle = oldStyle
      ..currentStyle = oldStyle
      ..lastInput = ChatInput(
        type: ChatInputType.text,
        text: '对方：晚上吃啥',
        selectedStyle: oldStyle,
      );

    await app.savePersonalization(
      ReplyPersonalizationSettings(customStyles: [updatedStyle]),
    );

    expect(app.defaultStyle.name, '新自定义');
    expect(app.defaultStyle.description, '新说明');
    expect(app.defaultStyle.rules, ['新规则']);
    expect(app.currentStyle, same(app.defaultStyle));
    expect(app.lastInput?.selectedStyle, same(app.defaultStyle));
    expect(store.savedDefaultStyleId, isNull);
  });

  test('updating a custom style refreshes spaced active style ids', () async {
    final oldStyle = ChatStyle(
      id: ' custom-style-to-update ',
      name: '旧自定义',
      description: '旧说明',
      rules: const ['旧规则'],
      isOfficial: false,
    );
    final updatedStyle = ChatStyle(
      id: 'CUSTOM-STYLE-TO-UPDATE',
      name: '新自定义',
      description: '新说明',
      rules: const ['新规则'],
      isOfficial: false,
    );
    final store = FakeStore();
    final app = AppController(store: store)
      ..personalization = ReplyPersonalizationSettings(customStyles: [oldStyle])
      ..defaultStyle = oldStyle
      ..currentStyle = oldStyle
      ..lastInput = ChatInput(
        type: ChatInputType.text,
        text: '对方：晚上吃啥',
        selectedStyle: oldStyle,
      );

    await app.savePersonalization(
      ReplyPersonalizationSettings(customStyles: [updatedStyle]),
    );

    expect(app.defaultStyle.name, '新自定义');
    expect(app.defaultStyle.id, 'CUSTOM-STYLE-TO-UPDATE');
    expect(app.currentStyle, same(app.defaultStyle));
    expect(app.lastInput?.selectedStyle, same(app.defaultStyle));
    expect(store.savedDefaultStyleId, isNull);
  });

  test('default chat style restores legacy iOS style name', () async {
    final store = FakeStore()..loadedDefaultStyleId = '  职场  ';
    final app = AppController(store: store);

    await app.load();

    expect(app.defaultStyle.name, '职场');
    expect(app.defaultStyle.id, 'official-workplace');
  });

  test(
      'initial load applies restored default style to current generation style',
      () async {
    final store = FakeStore()..loadedDefaultStyleId = 'official-workplace';
    final app = AppController(store: store);

    await app.load();

    expect(app.defaultStyle.id, 'official-workplace');
    expect(app.currentStyle, same(app.defaultStyle));
  });

  test('api readiness reports text and vision requirements', () {
    const textReady = GenerateAPIReadiness(
      config: APIConfig.defaults,
      hasAPIKey: true,
      capability: GenerateAPICapability.text,
    );
    const visionReady = GenerateAPIReadiness(
      config: APIConfig.defaults,
      hasAPIKey: true,
      capability: GenerateAPICapability.vision,
    );
    const missingKey = GenerateAPIReadiness(
      config: APIConfig.defaults,
      hasAPIKey: false,
      capability: GenerateAPICapability.text,
    );

    expect(textReady.isReady, isTrue);
    expect(textReady.statusText, contains(APIConfig.defaults.textModelName));
    expect(visionReady.isReady, isTrue);
    expect(
        visionReady.statusText, contains(APIConfig.defaults.visionModelName));
    expect(missingKey.isReady, isFalse);
    expect(missingKey.statusText, contains('填写 Key'));
  });

  test('api readiness treats placeholder model names as missing', () {
    final missingText = GenerateAPIReadiness(
      config: APIConfig.defaults.copyWith(textModelName: '  未知  '),
      hasAPIKey: true,
      capability: GenerateAPICapability.text,
    );
    final missingVision = GenerateAPIReadiness(
      config: APIConfig.defaults.copyWith(
        visionModelName: '  未知  ',
        modelCapabilities: const {
          '未知': ModelCapability(isMultimodal: true),
        },
      ),
      hasAPIKey: true,
      capability: GenerateAPICapability.vision,
    );
    final trimmedText = GenerateAPIReadiness(
      config: APIConfig.defaults.copyWith(textModelName: ' gpt-text '),
      hasAPIKey: true,
      capability: GenerateAPICapability.text,
    );

    expect(missingText.hasTextModel, isFalse);
    expect(missingText.isReady, isFalse);
    expect(missingText.statusText, contains('文本模型名称为空'));
    expect(missingVision.hasVisionModel, isFalse);
    expect(missingVision.hasUsableVisionModel, isFalse);
    expect(missingVision.hasMultimodalVisionModel, isFalse);
    expect(missingVision.isReady, isFalse);
    expect(missingVision.statusText, contains('视觉模型名称为空'));
    expect(isUsableVisionChatModelId('  未知  '), isFalse);
    expect(trimmedText.isReady, isTrue);
    expect(trimmedText.statusText, '文本：gpt-text');
  });

  test('api status snapshot summarizes home readiness state', () {
    const missingKey = APIStatusSnapshot(
      config: APIConfig.defaults,
      hasAPIKey: false,
    );
    final missingText = APIStatusSnapshot(
      config: APIConfig.defaults.copyWith(textModelName: ''),
      hasAPIKey: true,
    );
    final screenshotDisabled = APIStatusSnapshot(
      config: APIConfig.defaults.copyWith(enableImageInput: false),
      hasAPIKey: true,
    );
    const ready = APIStatusSnapshot(
      config: APIConfig.defaults,
      hasAPIKey: true,
    );

    expect(missingKey.isReady, isFalse);
    expect(missingKey.title, '还没有配置 API Key');
    expect(missingKey.subtitle, contains('填写 Key'));
    expect(missingText.isReady, isFalse);
    expect(missingText.title, '文本生成待完善');
    expect(missingText.subtitle, contains('文本模型名称为空'));
    expect(screenshotDisabled.isReady, isFalse);
    expect(screenshotDisabled.title, '截图回复待完善');
    expect(screenshotDisabled.subtitle, contains('截图模式已关闭'));
    expect(ready.isReady, isTrue);
    expect(ready.title, 'API 已就绪');
    expect(ready.subtitle, contains(APIConfig.defaults.visionModelName));
  });

  testWidgets('home api status card follows generation readiness',
      (tester) async {
    Future<void> pumpStatusCard(APIConfig config) {
      return tester.pumpWidget(ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: app_shell.APIStatusCard(config: config, hasKey: true),
          ),
        ),
      ));
    }

    final missingTextModel = APIConfig.defaults.copyWith(textModelName: '');
    await pumpStatusCard(missingTextModel);

    expect(find.text('文本生成待完善'), findsOneWidget);
    expect(find.text('API 已就绪'), findsNothing);
    expect(find.textContaining('文本模型名称为空'), findsOneWidget);

    await pumpStatusCard(APIConfig.defaults);

    expect(find.text('API 已就绪'), findsOneWidget);
    expect(find.textContaining(APIConfig.defaults.visionModelName),
        findsOneWidget);
  });

  test('floating capture event parses quick route deep link', () {
    final event = FloatingCaptureEvent.fromMap({'route': 'quick-image'});
    final floatingEvent = FloatingCaptureEvent.fromMap(
        {'path': '/tmp/a.jpg', 'source': 'floating'});
    final sharedEvent = FloatingCaptureEvent.fromMap(
        {'path': '/tmp/shared.jpg', 'source': 'share'});
    final normalizedEvent = FloatingCaptureEvent.fromMap(
        {'path': ' /tmp/shared.jpg ', 'source': ' Share '});
    final legacySharedEvent = FloatingCaptureEvent.fromMap(
        {'path': '/tmp/legacy-shared.jpg', 'source': 'shared_image'});
    final androidSharedImageEvent = FloatingCaptureEvent.fromMap(
        {'path': '/tmp/android-shared.jpg', 'source': 'androidShareImage'});
    final systemSharedTextEvent = FloatingCaptureEvent.fromMap(
        {'text': '明天见', 'source': 'system-share-text'});
    final encodedSharedTextEvent = FloatingCaptureEvent.fromMap(
        {'text': '明天见', 'source': 'shared%5Ftext'});
    final floatingAliasEvent = FloatingCaptureEvent.fromMap(
        {'path': '/tmp/floating.jpg', 'source': 'floating-capture'});
    final quickAliasEvent = FloatingCaptureEvent.fromMap(
        {'path': '/tmp/quick.jpg', 'source': 'quickImage'});
    final aliasedSourceEvent = FloatingCaptureEvent.fromMap({
      'path': '/tmp/event-source.jpg',
      'eventSource': 'android-share',
    });
    final sourceTypeEvent = FloatingCaptureEvent.fromMap({
      'path': '/tmp/source-type.jpg',
      'source_type': 'sharedText',
    });
    final handoffTypeEvent = FloatingCaptureEvent.fromMap({
      'path': '/tmp/handoff-type.jpg',
      'handoff-type': 'quickShortcut',
    });
    final sendIntentEvent = FloatingCaptureEvent.fromMap({
      'path': '/tmp/send-intent.jpg',
      'intentAction': 'android.intent.action.SEND_MULTIPLE',
    });
    final processTextIntentEvent = FloatingCaptureEvent.fromMap({
      'text': '系统选中文字',
      'intent-action': 'ACTION_PROCESS_TEXT',
    });
    final aliasedPathEvent = FloatingCaptureEvent.fromMap({
      'image_path': ' /tmp/aliased.jpg ',
      'source': 'shared-image',
    });
    final blankPathEvent =
        FloatingCaptureEvent.fromMap({'path': '   ', 'error': ' 失败 '});
    final sharedTextEvent =
        FloatingCaptureEvent.fromMap({'text': '你好呀', 'source': 'share'});
    final selectedTextEvent =
        FloatingCaptureEvent.fromMap({'text': '晚上见', 'source': 'process_text'});
    final systemProcessTextEvent = FloatingCaptureEvent.fromMap(
        {'text': '系统选中文字', 'source': 'system-process-text'});
    final aliasedTextEvent =
        FloatingCaptureEvent.fromMap({'selectedText': ' 选中文字 '});
    final copiedReplyEvent =
        FloatingCaptureEvent.fromMap({'copiedReply': '第一条'});
    final snakeCaseCopiedReplyEvent =
        FloatingCaptureEvent.fromMap({'copied_reply': '第二条'});
    final aliasedCopiedReplyEvent =
        FloatingCaptureEvent.fromMap({'replyText': '第三条'});
    final separatedErrorEvent =
        FloatingCaptureEvent.fromMap({'error-message': '  桥接失败  '});
    final aliasedRouteEvent =
        FloatingCaptureEvent.fromMap({'deep_link': 'aichathelper://api'});
    final uriRouteEvent =
        FloatingCaptureEvent.fromMap({'uri': 'aichathelper://settings/api'});
    final linkRouteEvent = FloatingCaptureEvent.fromMap({'link': 'people/new'});
    final destinationRouteEvent =
        FloatingCaptureEvent.fromMap({'destination': 'privacy-settings'});
    final screenRouteEvent =
        FloatingCaptureEvent.fromMap({'screen': 'settings/privacy'});
    final pageRouteEvent = FloatingCaptureEvent.fromMap({'page': 'shortcut'});
    final targetRouteEvent =
        FloatingCaptureEvent.fromMap({'targetRoute': 'people/new'});
    final payloadWrappedEvent = FloatingCaptureEvent.fromMap({
      'payload': {
        'shared_text': ' 包装文本 ',
        'source_type': 'processText',
      },
    });
    final metadataWrappedEvent = FloatingCaptureEvent.fromMap({
      'source': 'process-text',
      'payload': {
        'shared_text': ' 外层元信息包装文本 ',
      },
    });
    final outerRouteWrappedEvent = FloatingCaptureEvent.fromMap({
      'route': 'text',
      'payload': {
        'shared_text': ' 带路由包装文本 ',
      },
    });
    final outerErrorWrappedEvent = FloatingCaptureEvent.fromMap({
      'error': ' 外层错误 ',
      'payload': {
        'image_path': ' /tmp/error-wrapped.jpg ',
      },
    });
    final innerFieldPriorityWrappedEvent = FloatingCaptureEvent.fromMap({
      'text': ' 外层旧文本 ',
      'source': 'share',
      'payload': {
        'shared_text': ' 内层新文本 ',
        'source_type': 'processText',
      },
    });
    final dataWrappedEvent = FloatingCaptureEvent.fromMap({
      'data': {
        'image_path': ' /tmp/wrapped.jpg ',
        'event_source': 'androidShareImage',
      },
    });
    final jsonWrappedEvent = FloatingCaptureEvent.fromMap(
      '{"event":{"target_route":"settings/api","handoff_source":"shortcut"}}',
    );
    final jsonStringEvent = FloatingCaptureEvent.fromMap(
      '{"image_path":" /tmp/json-event.jpg ","source_type":"sharedText","reply_text":" JSON回复 "}',
    );
    final badStringEvent = FloatingCaptureEvent.fromMap('not json');

    expect(quickShortcutUrl, 'aichathelper://quick-image');
    expect(event.route, 'quick-image');
    expect(event.path, isNull);
    expect(event.error, isNull);
    expect(floatingEvent.path, '/tmp/a.jpg');
    expect(floatingEvent.source, 'floating');
    expect(sharedEvent.path, '/tmp/shared.jpg');
    expect(sharedEvent.source, 'share');
    expect(normalizedEvent.path, '/tmp/shared.jpg');
    expect(normalizedEvent.source, 'share');
    expect(legacySharedEvent.source, 'share');
    expect(androidSharedImageEvent.source, 'share');
    expect(systemSharedTextEvent.source, 'share');
    expect(encodedSharedTextEvent.source, 'share');
    expect(floatingAliasEvent.source, 'floating');
    expect(quickAliasEvent.source, 'quick');
    expect(aliasedSourceEvent.source, 'share');
    expect(sourceTypeEvent.source, 'share');
    expect(handoffTypeEvent.source, 'quick');
    expect(sendIntentEvent.source, 'share');
    expect(processTextIntentEvent.source, 'selected-text');
    expect(aliasedPathEvent.path, '/tmp/aliased.jpg');
    expect(aliasedPathEvent.source, 'share');
    expect(blankPathEvent.path, isNull);
    expect(blankPathEvent.error, '失败');
    expect(sharedTextEvent.text, '你好呀');
    expect(sharedTextEvent.source, 'share');
    expect(selectedTextEvent.text, '晚上见');
    expect(selectedTextEvent.source, 'selected-text');
    expect(systemProcessTextEvent.text, '系统选中文字');
    expect(systemProcessTextEvent.source, 'selected-text');
    expect(aliasedTextEvent.text, '选中文字');
    expect(copiedReplyEvent.copiedReply, '第一条');
    expect(snakeCaseCopiedReplyEvent.copiedReply, '第二条');
    expect(aliasedCopiedReplyEvent.copiedReply, '第三条');
    expect(separatedErrorEvent.error, '桥接失败');
    expect(aliasedRouteEvent.route, 'aichathelper://api');
    expect(uriRouteEvent.route, 'aichathelper://settings/api');
    expect(linkRouteEvent.route, 'people/new');
    expect(destinationRouteEvent.route, 'privacy-settings');
    expect(screenRouteEvent.route, 'settings/privacy');
    expect(pageRouteEvent.route, 'shortcut');
    expect(targetRouteEvent.route, 'people/new');
    expect(payloadWrappedEvent.text, '包装文本');
    expect(payloadWrappedEvent.source, 'selected-text');
    expect(metadataWrappedEvent.text, '外层元信息包装文本');
    expect(metadataWrappedEvent.source, 'selected-text');
    expect(outerRouteWrappedEvent.text, '带路由包装文本');
    expect(outerRouteWrappedEvent.route, 'text');
    expect(outerErrorWrappedEvent.path, '/tmp/error-wrapped.jpg');
    expect(outerErrorWrappedEvent.error, '外层错误');
    expect(innerFieldPriorityWrappedEvent.text, '内层新文本');
    expect(innerFieldPriorityWrappedEvent.source, 'selected-text');
    expect(dataWrappedEvent.path, '/tmp/wrapped.jpg');
    expect(dataWrappedEvent.source, 'share');
    expect(jsonWrappedEvent.route, 'settings/api');
    expect(jsonWrappedEvent.source, 'quick');
    expect(jsonStringEvent.path, '/tmp/json-event.jpg');
    expect(jsonStringEvent.source, 'share');
    expect(jsonStringEvent.copiedReply, 'JSON回复');
    expect(badStringEvent.error, '未知悬浮窗事件。');
    expect(appPathForExternalRoute(screenRouteEvent.route), AppRoutes.privacy);
    expect(appPathForExternalRoute(uriRouteEvent.route), AppRoutes.api);
    expect(appPathForExternalRoute(linkRouteEvent.route), AppRoutes.peopleEdit);
    expect(appPathForExternalRoute(destinationRouteEvent.route),
        AppRoutes.privacy);
    expect(
        appPathForExternalRoute(pageRouteEvent.route), AppRoutes.floatingGuide);
    expect(
        appPathForExternalRoute(targetRouteEvent.route), AppRoutes.peopleEdit);

    final eventSource =
        File('lib/core/floating_capture_event.dart').readAsStringSync();
    final fieldSource =
        File('lib/core/floating_capture_event_fields.dart').readAsStringSync();
    expect(eventSource, contains("import 'text_cleaning.dart';"));
    expect(fieldSource, contains('const _eventDirectFieldKeys = ['));
    expect(fieldSource, contains('for (final key in _eventDirectFieldKeys)'));
    expect(fieldSource, contains('return _mergedEventPayload('));
    expect(
      fieldSource,
      contains(
        'String? _cleanEventField(Object? value) => cleanNonEmptyText(value?.toString());',
      ),
    );
    expect(fieldSource, isNot(contains('value?.toString().trim()')));
  });

  test('external deep link routes match iOS navigation commands', () {
    expect(appPathForExternalRoute('quick-image'), AppRoutes.quick);
    expect(appPathForExternalRoute(' QUICK-IMAGE '), AppRoutes.quick);
    expect(appPathForExternalRoute('quick-reply'), AppRoutes.quick);
    expect(appPathForExternalRoute('quickReply'), AppRoutes.quick);
    expect(appPathForExternalRoute('quick-image?source=shortcut'),
        AppRoutes.quick);
    expect(
        appPathForExternalRoute('aichathelper://quick-image'), AppRoutes.quick);
    expect(appPathForExternalRoute('aichathelper:quick-image?source=shortcut'),
        AppRoutes.quick);
    expect(appPathForExternalRoute('/image/'), AppRoutes.image);
    expect(appPathForExternalRoute('aichathelper:///image?from=shortcut#top'),
        AppRoutes.image);
    expect(appPathForExternalRoute('aichathelper://open?route=image'),
        AppRoutes.image);
    expect(appPathForExternalRoute('aichathelper://open?route=%20image%20'),
        AppRoutes.image);
    expect(appPathForExternalRoute('imageInput'), AppRoutes.image);
    expect(appPathForExternalRoute('image_input'), AppRoutes.image);
    expect(appPathForExternalRoute('screenshot'), AppRoutes.image);
    expect(appPathForExternalRoute('text'), AppRoutes.text);
    expect(appPathForExternalRoute('aichathelper://textInput'), AppRoutes.text);
    expect(appPathForExternalRoute('text input'), AppRoutes.text);
    expect(appPathForExternalRoute('moments'), AppRoutes.moments);
    expect(appPathForExternalRoute('momentProfile'), AppRoutes.moments);
    expect(appPathForExternalRoute('profile-image'), AppRoutes.moments);
    expect(appPathForExternalRoute('history'), AppRoutes.history);
    expect(appPathForExternalRoute('personLibrary'), AppRoutes.people);
    expect(appPathForExternalRoute('person-library'), AppRoutes.people);
    expect(appPathForExternalRoute('aichathelper://addPerson'),
        AppRoutes.peopleEdit);
    expect(appPathForExternalRoute('add-person'), AppRoutes.peopleEdit);
    expect(appPathForExternalRoute('newPerson'), AppRoutes.peopleEdit);
    expect(appPathForExternalRoute('people/new'), AppRoutes.peopleEdit);
    expect(appPathForExternalRoute('people//new'), AppRoutes.peopleEdit);
    expect(appPathForExternalRoute('people%2Fnew'), AppRoutes.peopleEdit);
    expect(
        appPathForExternalRoute(' %2Fpeople%2Fnew%2F '), AppRoutes.peopleEdit);
    expect(appPathForExternalRoute('aichathelper://route?path=people/new'),
        AppRoutes.peopleEdit);
    expect(appPathForExternalRoute('person-library/add'), AppRoutes.peopleEdit);
    expect(appPathForExternalRoute('/people/edit/'), AppRoutes.peopleEdit);
    expect(appPathForExternalRoute('People/Edit'), AppRoutes.peopleEdit);
    expect(appPathForExternalRoute('aichathelper://people/edit?draft=1#form'),
        AppRoutes.peopleEdit);
    expect(appPathForExternalRoute('simulation'), AppRoutes.simulation);
    expect(appPathForExternalRoute('conversation-simulation'),
        AppRoutes.simulation);
    expect(appPathForExternalRoute('people/simulation'), AppRoutes.simulation);
    expect(appPathForExternalRoute('aichathelper://simulation'),
        AppRoutes.simulation);
    expect(appPathForExternalRoute('people/select-simulation'),
        AppRoutes.peopleSelectSimulation);
    expect(appPathForExternalRoute('simulation/select'),
        AppRoutes.peopleSelectSimulation);
    expect(
        appPathForExternalRoute(
            'aichathelper://open?route=people/select-simulation'),
        AppRoutes.peopleSelectSimulation);
    expect(appPathForExternalRoute('settings'), AppRoutes.settings);
    expect(
        appPathForExternalRoute('personalization'), AppRoutes.personalization);
    expect(appPathForExternalRoute('personalizationSettings'),
        AppRoutes.personalization);
    expect(
        appPathForExternalRoute('reply-settings'), AppRoutes.personalization);
    expect(
        appPathForExternalRoute('style-settings'), AppRoutes.personalization);
    expect(appPathForExternalRoute('aichathelper://settings/personalization'),
        AppRoutes.personalization);
    expect(appPathForExternalRoute('apiSettings'), AppRoutes.api);
    expect(appPathForExternalRoute('api-settings'), AppRoutes.api);
    expect(appPathForExternalRoute('api'), AppRoutes.api);
    expect(
        appPathForExternalRoute('aichathelper://settings/api'), AppRoutes.api);
    expect(
        appPathForExternalRoute('aichathelper://settings//api'), AppRoutes.api);
    expect(
        appPathForExternalRoute('aichathelper://open?targetRoute=settings/api'),
        AppRoutes.api);
    expect(appPathForExternalRoute('aichathelper://settings/api?route=privacy'),
        AppRoutes.api);
    expect(appPathForExternalRoute('aichathelper://settings?screen=privacy'),
        AppRoutes.privacy);
    expect(appPathForExternalRoute('aichathelper://settings?page=api'),
        AppRoutes.api);
    expect(appPathForExternalRoute('aichathelper://settings?page=%20api%20'),
        AppRoutes.api);
    expect(
        appPathForExternalRoute(
            'aichathelper://settings?destination=floating-guide'),
        AppRoutes.floatingGuide);
    expect(appPathForExternalRoute('privacySettings'), AppRoutes.privacy);
    expect(appPathForExternalRoute('privacy'), AppRoutes.privacy);
    expect(appPathForExternalRoute('privacy-settings'), AppRoutes.privacy);
    expect(appPathForExternalRoute('aichathelper://settings/privacy'),
        AppRoutes.privacy);
    expect(appPathForExternalRoute('aichathelper://settings///privacy'),
        AppRoutes.privacy);
    expect(appPathForExternalRoute('aichathelper://screen?page=privacy'),
        AppRoutes.privacy);
    expect(appPathForExternalRoute('shortcut'), AppRoutes.floatingGuide);
    expect(appPathForExternalRoute('shortcutGuide'), AppRoutes.floatingGuide);
    expect(appPathForExternalRoute('shortcuts'), AppRoutes.floatingGuide);
    expect(appPathForExternalRoute('shortcut-guide'), AppRoutes.floatingGuide);
    expect(appPathForExternalRoute('floating-guide'), AppRoutes.floatingGuide);
    expect(appPathForExternalRoute('floatingWindow'), AppRoutes.floatingGuide);
    expect(appPathForExternalRoute('aichathelper://settings/shortcut'),
        AppRoutes.floatingGuide);
    expect(appPathForExternalRoute('aichathelper://settings/floating-guide'),
        AppRoutes.floatingGuide);
    expect(appPathForExternalRoute('aichathelper://?deeplink=shortcut-guide'),
        AppRoutes.floatingGuide);
    expect(appPathForExternalRoute('aichathelper://open?uri=settings/api'),
        AppRoutes.api);
    expect(appPathForExternalRoute('aichathelper://go?link=people/new'),
        AppRoutes.peopleEdit);
    expect(
        appPathForExternalRoute(
            'aichathelper://navigate?destination=privacy-settings'),
        AppRoutes.privacy);
    expect(appPathForExternalRoute('aichathelper://deeplink?route=privacy'),
        AppRoutes.privacy);
    expect(
        appPathForExternalRoute('aichathelper://url?targetRoute=settings/api'),
        AppRoutes.api);
    expect(appPathForExternalRoute('aichathelper://link?uri=people/new'),
        AppRoutes.peopleEdit);
    expect(
        appPathForExternalRoute(
            'aichathelper://destination?page=floating-guide'),
        AppRoutes.floatingGuide);
    expect(appPathForExternalRoute('https://people/edit'), isNull);
    expect(appPathForExternalRoute('unknown'), isNull);
    expect(isQuickExternalRoute('quick'), isTrue);
    expect(isQuickExternalRoute('image'), isFalse);
    expect(isImageExternalRoute('image'), isTrue);
    expect(isImageExternalRoute('text'), isFalse);
    expect(isTextExternalRoute('text'), isTrue);
    expect(isTextExternalRoute('quick'), isFalse);
    expect(isNewProfileExternalRoute('new-person'), isTrue);
    expect(isNewProfileExternalRoute('aichathelper://addPerson'), isTrue);
    expect(isNewProfileExternalRoute('newPerson'), isTrue);
    expect(isNewProfileExternalRoute('/people/edit/'), isTrue);
    expect(isNewProfileExternalRoute('personLibrary'), isFalse);
    expect(isNewProfileExternalRoute('people'), isFalse);

    final routeSource =
        File('lib/core/platform_route_normalization.dart').readAsStringSync();
    final routesSource =
        File('lib/core/platform_routes.dart').readAsStringSync();
    final pathSource =
        File('lib/core/route_path_normalization.dart').readAsStringSync();
    expect(routesSource, contains("import 'text_cleaning.dart';"));
    expect(routeSource, contains('String? _cleanRouteText(String? value)'));
    expect(routeSource, contains('=> cleanNonEmptyText(value);'));
    expect(routeSource, isNot(contains('route?.trim()')));
    expect(routeSource, isNot(contains('uri.host.trim()')));
    expect(routeSource, isNot(contains('entry.value.trim()')));
    expect(pathSource, contains("import 'text_cleaning.dart';"));
    expect(pathSource, contains('final trimmed = cleanNonEmptyText(decoded)'));
    expect(pathSource, contains("replaceAll(RegExp(r'/+'), '/')"));
    expect(pathSource, isNot(contains('decoded.trim()')));
  });

  test('android manifest accepts broad text handoff mime types', () {
    final manifest =
        File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
    final filters = RegExp(r'<intent-filter>[\s\S]*?</intent-filter>')
        .allMatches(manifest)
        .map((match) => match.group(0)!)
        .toList();
    final queryIntents = RegExp(r'<intent>[\s\S]*?</intent>')
        .allMatches(manifest)
        .map((match) => match.group(0)!)
        .toList();

    bool hasTextFilter(String action) {
      return filters.any((filter) =>
          filter.contains('android.intent.action.$action') &&
          filter.contains('android:mimeType="text/*"'));
    }

    expect(hasTextFilter('SEND'), isTrue);
    expect(hasTextFilter('SEND_MULTIPLE'), isTrue);
    expect(hasTextFilter('PROCESS_TEXT'), isTrue);
    expect(
      queryIntents.any((intent) =>
          intent.contains('android.intent.action.PROCESS_TEXT') &&
          intent.contains('android:mimeType="text/*"')),
      isTrue,
    );
  });

  test('android manifest accepts untyped share and view handoffs', () {
    final manifest =
        File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
    final filters = RegExp(r'<intent-filter>[\s\S]*?</intent-filter>')
        .allMatches(manifest)
        .map((match) => match.group(0)!)
        .toList();

    bool hasUntypedFilter(String action, {String? scheme}) {
      return filters.any((filter) =>
          filter.contains('android.intent.action.$action') &&
          !filter.contains('android:mimeType=') &&
          (scheme == null || filter.contains('android:scheme="$scheme"')));
    }

    expect(hasUntypedFilter('SEND'), isTrue);
    expect(hasUntypedFilter('SEND_MULTIPLE'), isTrue);
    expect(hasUntypedFilter('VIEW', scheme: 'content'), isTrue);
    expect(hasUntypedFilter('VIEW', scheme: 'file'), isTrue);
  });

  test('android launcher shortcut covers iOS screenshot app shortcut', () {
    final manifest =
        File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
    final shortcuts =
        File('android/app/src/main/res/xml/shortcuts.xml').readAsStringSync();
    final strings =
        File('android/app/src/main/res/values/strings.xml').readAsStringSync();
    final buildGradle = File('android/app/build.gradle').readAsStringSync();
    final readme = File('README.md').readAsStringSync();
    final audit = File('docs/MIGRATION_AUDIT.md').readAsStringSync();
    final applicationId = RegExp(r'applicationId\s*=\s*"([^"]+)"')
        .firstMatch(buildGradle)
        ?.group(1);

    expect(applicationId, 'com.local.aichathelper');
    expect(manifest, contains('android:name="android.app.shortcuts"'));
    expect(manifest, contains('android:resource="@xml/shortcuts"'));
    expect(shortcuts, contains('android:shortcutId="quick_image_reply"'));
    expect(shortcuts, contains('android:icon="@mipmap/ic_launcher"'));
    expect(shortcuts, contains('android.intent.action.VIEW'));
    expect(shortcuts, contains('android:data="aichathelper://quick-image"'));
    expect(shortcuts,
        contains('android:targetClass="$applicationId.MainActivity"'));
    expect(shortcuts, contains('android:targetPackage="$applicationId"'));
    expect(
        shortcuts,
        contains(
            'android:shortcutShortLabel="@string/shortcut_quick_image_short_label"'));
    expect(strings, contains('name="shortcut_quick_image_short_label"'));
    expect(strings, contains('处理截图'));
    expect(readme, contains('Android Launcher App Shortcut'));
    expect(audit, contains('Android Launcher App Shortcut'));
  });

  test('android adb smoke helper covers migrated external entry points', () {
    final script = File('scripts/android_smoke.sh').readAsStringSync();
    final readme = File('README.md').readAsStringSync();
    final audit = File('docs/MIGRATION_AUDIT.md').readAsStringSync();

    expect(script, startsWith('#!/usr/bin/env bash'));
    expect(script, contains('set -euo pipefail'));
    expect(script,
        contains(r'PACKAGE_NAME="${PACKAGE_NAME:-com.local.aichathelper}"'));
    expect(script, contains(r'adb_cmd install -r "${APK_PATH}"'));
    expect(script, contains('assert_launcher_shortcut()'));
    expect(script, contains('cmd shortcut get-shortcuts'));
    expect(script, contains('id=quick_image_reply'));
    expect(script, contains('shortLabel=处理截图'));
    expect(script, contains(r'cmp=${PACKAGE_NAME}/.MainActivity'));
    expect(script, contains('assert_native_components()'));
    expect(script, contains(r'dumpsys package "${PACKAGE_NAME}"'));
    expect(script, contains('assert_component_registered'));
    expect(script, contains('component_is_registered()'));
    expect(script, contains(r'${PACKAGE_NAME}/\\.${class_name}'));
    expect(
        script, contains(r'${PACKAGE_NAME}/${PACKAGE_NAME}\\.${class_name}'));
    expect(script, contains('"FloatingCaptureService"'));
    expect(script, contains('"ProjectionForegroundService"'));
    expect(script, contains('"ScreenshotAccessibilityService"'));
    expect(script, isNot(contains('"AIReplyInputMethodService"')));
    expect(script, contains('android.permission.BIND_ACCESSIBILITY_SERVICE'));
    expect(script, isNot(contains('android.permission.BIND_INPUT_METHOD')));
    expect(script,
        contains('android.permission.FOREGROUND_SERVICE_MEDIA_PROJECTION'));
    expect(script, contains('android.permission.SYSTEM_ALERT_WINDOW'));
    expect(script, contains('android.permission.POST_NOTIFICATIONS'));
    expect(script, isNot(contains('ime list -a')));
    expect(
        script,
        isNot(contains(
            r'component_is_registered "${ime_dump}" "AIReplyInputMethodService"')));
    expect(readme, isNot(contains('input-method registration')));
    expect(audit, isNot(contains('input-method registration')));
    expect(audit, isNot(contains('accessibility/input-method services')));
    expect(script, contains('adb_cmd logcat -c'));
    expect(script, contains('current_pid()'));
    expect(script, contains(r'pidof "${PACKAGE_NAME}"'));
    expect(script, contains(r'--pid="${app_pid}"'));
    expect(script, contains('aichathelper://settings/api'));
    expect(script, contains('android.intent.action.SEND'));
    expect(script, contains('android.intent.action.SEND_MULTIPLE'));
    expect(script, contains('android.intent.extra.TEXT'));
    expect(script, contains('SMOKE_TEXT_SECOND'));
    expect(script, contains('escape_am_array_item()'));
    expect(script, contains('--esa android.intent.extra.TEXT'));
    expect(script, contains('base64_decode_file()'));
    expect(script, contains('base64 --decode'));
    expect(script, contains('base64 -D'));
    expect(script, contains(r'base64_decode_file "${tmp_png}"'));
    expect(
        script, contains('device_png="/sdcard/Download/ai-reply-smoke.png"'));
    expect(script, contains('cleanup_smoke_files()'));
    expect(script, contains(r'adb_cmd shell rm -f "${device_png}"'));
    expect(script, contains(r'adb_cmd push "${tmp_png}" "${device_png}"'));
    expect(script, contains('android.intent.action.PROCESS_TEXT'));
    expect(script, contains('android.intent.extra.PROCESS_TEXT'));
    expect(script, contains('android.intent.extra.PROCESS_TEXT_READONLY'));
    expect(script, contains('android.intent.extra.STREAM'));
    expect(script, contains(r'file://${device_png}'));
    expect(script, contains('image ACTION_SEND untyped file URI'));
    expect(script, contains('image ACTION_VIEW file URI'));
    expect(script, contains('image ACTION_VIEW untyped file URI'));
    expect(script, contains('android.intent.action.VIEW'));
    expect(script, contains(r'-d "file://${device_png}"'));
    expect(script, contains('aichathelper://quick-image'));
    expect(script, contains('FATAL EXCEPTION'));
    expect(script, contains('AndroidRuntime'));
    expect(script, contains('Force finishing'));
    expect(script, contains('ANR'));
    expect(readme, contains('scripts/android_smoke.sh'));
    expect(audit, contains('scripts/android_smoke.sh'));
  });

  test('android launcher icons use density-specific dimensions', () {
    const expectedSizes = {
      'mipmap-mdpi': 48,
      'mipmap-hdpi': 72,
      'mipmap-xhdpi': 96,
      'mipmap-xxhdpi': 144,
      'mipmap-xxxhdpi': 192,
    };

    for (final entry in expectedSizes.entries) {
      final file =
          File('android/app/src/main/res/${entry.key}/ic_launcher.png');
      final icon = img.decodePng(file.readAsBytesSync());

      expect(icon, isNotNull, reason: file.path);
      expect(icon!.width, entry.value, reason: file.path);
      expect(icon.height, entry.value, reason: file.path);
    }
  });

  test('android share text intake skips untyped uri handoffs', () {
    final source = File(
            'android/app/src/main/kotlin/com/local/aichathelper/MainActivity.kt')
        .readAsStringSync();
    final textStart = source.indexOf('private fun sharedText(intent: Intent)');
    final imageCopyStart = source.indexOf('private fun copyClipboardUri');

    expect(
      source,
      contains('if (item.uri != null || item.intent?.data != null) continue'),
    );
    expect(source, contains('val hasSharedUri = intent.hasSharedUri()'));
    expect(
      source,
      contains(
          'if (hasSharedUri && (mimeType.isNullOrBlank() || mimeType == "*/*")) return null'),
    );
    expect(source, contains('private fun Intent.streamUris(): List<Uri>'));
    expect(source, contains('if (streamUris().isNotEmpty()) return true'));
    expect(source, isNot(contains('hasExtra(Intent.EXTRA_STREAM)')));
    expect(source, isNot(contains('getStringExtra(Intent.EXTRA_TEXT)')));
    final guardIndex = source.indexOf(
        'if (hasSharedUri && (mimeType.isNullOrBlank() || mimeType == "*/*")) return null');
    final extraTextIndex = source.indexOf('val extraText = intent.extraText()');
    expect(extraTextIndex, isNonNegative);
    expect(guardIndex, greaterThan(extraTextIndex));
    expect('intent.extraText()'.allMatches(source), hasLength(2));
    expect(
      source.indexOf('Intent.ACTION_SEND_MULTIPLE', textStart),
      lessThan(imageCopyStart),
    );
    expect(
        source,
        contains(
            'private fun Intent.extraText(): String? = extraTextValue(Intent.EXTRA_TEXT)'));
    expect(source, isNot(contains('getCharSequenceExtra(Intent.EXTRA_TEXT)')));
    expect(source,
        isNot(contains('getCharSequenceArrayListExtra(Intent.EXTRA_TEXT)')));
  });

  test('android extra text intake avoids bundle class cast warnings', () {
    final source = File(
            'android/app/src/main/kotlin/com/local/aichathelper/MainActivity.kt')
        .readAsStringSync();
    final extraTextStart = source.indexOf(
        '@Suppress("DEPRECATION")\n    private fun Intent.extraTextValue(key: String)');
    final hasSharedUriStart =
        source.indexOf('private fun Intent.hasSharedUri()', extraTextStart);

    expect(extraTextStart, isNonNegative);
    expect(hasSharedUriStart, greaterThan(extraTextStart));
    final extraTextBody = source.substring(extraTextStart, hasSharedUriStart);

    expect(extraTextBody, contains('@Suppress("DEPRECATION")'));
    expect(extraTextBody, contains('extras?.get(key)'));
    expect(extraTextBody,
        contains('is CharSequence -> listOf(rawText.toString())'));
    expect(extraTextBody, contains('is ArrayList<*> -> rawText.textItems()'));
    expect(extraTextBody,
        contains('is Array<*> -> rawText.asIterable().textItems()'));
    expect(extraTextBody, contains('is Iterable<*> -> rawText.textItems()'));
    expect(extraTextBody, contains('else -> emptyList()'));
    expect(extraTextBody,
        contains('mapNotNull { (it as? CharSequence)?.toString() }'));
    expect(extraTextBody, contains('textItems.joinToString("\\n")'));
    expect(
        extraTextBody, isNot(contains('else -> listOf(rawText.toString())')));
    expect(extraTextBody,
        isNot(contains('getCharSequenceExtra(Intent.EXTRA_TEXT)')));
    expect(extraTextBody,
        isNot(contains('getCharSequenceArrayListExtra(Intent.EXTRA_TEXT)')));
    expect(
        source,
        contains(
            'private fun Intent.processText(): String? = extraTextValue(Intent.EXTRA_PROCESS_TEXT)'));
    expect(source,
        isNot(contains('getCharSequenceExtra(Intent.EXTRA_PROCESS_TEXT)')));
  });

  test('android clipdata multi text shares preserve all text items', () {
    final source = File(
            'android/app/src/main/kotlin/com/local/aichathelper/MainActivity.kt')
        .readAsStringSync();
    final sharedTextStart =
        source.indexOf('private fun sharedText(intent: Intent)');
    final processTextStart =
        source.indexOf('private fun Intent.processText()', sharedTextStart);
    final clipTextStart = source.indexOf(
        'private fun android.content.ClipData?.textItems(context: Context)');
    final hasSharedUriStart =
        source.indexOf('private fun Intent.hasSharedUri()', clipTextStart);

    expect(sharedTextStart, isNonNegative);
    expect(processTextStart, greaterThan(sharedTextStart));
    final sharedTextBody = source.substring(sharedTextStart, processTextStart);
    expect(sharedTextBody, contains('intent.clipData.textItems(this)'));
    expect(sharedTextBody, contains('joinToString("\\n")'));
    expect(sharedTextBody, isNot(contains('return text')));

    expect(clipTextStart, isNonNegative);
    expect(hasSharedUriStart, greaterThan(clipTextStart));
    final clipTextBody = source.substring(clipTextStart, hasSharedUriStart);
    expect(clipTextBody, contains('mutableListOf<String>()'));
    expect(
        clipTextBody,
        contains(
            'if (item.uri != null || item.intent?.data != null) continue'));
    expect(clipTextBody, contains('textItems.add(text)'));
    expect(clipTextBody, contains('return textItems'));
  });

  test('android stream uri intake avoids bundle class cast warnings', () {
    final source = File(
            'android/app/src/main/kotlin/com/local/aichathelper/MainActivity.kt')
        .readAsStringSync();
    final streamStart = source.indexOf('private fun Intent.streamUris()');
    final clipStart = source.indexOf(
      'private fun android.content.ClipData?.uriItems()',
      streamStart,
    );

    expect(streamStart, isNonNegative);
    expect(clipStart, greaterThan(streamStart));
    final streamBody = source.substring(streamStart, clipStart);

    expect(streamBody, contains('extras?.get(Intent.EXTRA_STREAM)'));
    expect(streamBody, contains('is Uri -> listOf(rawStream)'));
    expect(streamBody,
        contains('is ArrayList<*> -> rawStream.filterIsInstance<Uri>()'));
    expect(streamBody,
        contains('is Array<*> -> rawStream.filterIsInstance<Uri>()'));
    expect(streamBody,
        contains('is Iterable<*> -> rawStream.filterIsInstance<Uri>()'));
    expect(streamBody, isNot(contains('getParcelableArrayListExtra')));
    expect(
        streamBody, isNot(contains('getParcelableExtra(Intent.EXTRA_STREAM')));
  });

  test('android image share failures can fall back to explicit shared text',
      () {
    final source = File(
            'android/app/src/main/kotlin/com/local/aichathelper/MainActivity.kt')
        .readAsStringSync();
    final handleStart = source.indexOf('private fun handleIntent');
    final routeStart = source.indexOf('private fun externalRoute');

    expect(handleStart, isNonNegative);
    expect(routeStart, greaterThan(handleStart));
    final handleBody = source.substring(handleStart, routeStart);

    final imageStart = handleBody.indexOf('if (sharedUris.isNotEmpty())');
    final imageErrorIndex = handleBody.indexOf(
        'FloatingEvents.error(lastImageError?.message ?: "无法读取分享的图片。")',
        imageStart);
    final fallbackTextIndex =
        handleBody.indexOf('val fallbackText = sharedText(intent)', imageStart);
    final fallbackEventIndex = handleBody.indexOf(
        'FloatingEvents.text(fallbackText.trim(), "share")', imageStart);

    expect(imageStart, isNonNegative);
    expect(fallbackTextIndex, isNonNegative);
    expect(fallbackEventIndex, greaterThan(fallbackTextIndex));
    expect(imageErrorIndex, greaterThan(fallbackEventIndex));
  });

  test('android share text intake rejects non text mime before extra text', () {
    final source = File(
            'android/app/src/main/kotlin/com/local/aichathelper/MainActivity.kt')
        .readAsStringSync();
    final textStart = source.indexOf('private fun sharedText(intent: Intent)');
    final extraTextMethodStart =
        source.indexOf('private fun Intent.extraText()');

    expect(textStart, isNonNegative);
    expect(extraTextMethodStart, greaterThan(textStart));
    final methodBody = source.substring(textStart, extraTextMethodStart);

    final rejectNonTextIndex =
        methodBody.indexOf('if (!looksTextShare) return null');
    final extraTextIndex =
        methodBody.indexOf('val extraText = intent.extraText()');

    expect(rejectNonTextIndex, isNonNegative);
    expect(extraTextIndex, isNonNegative);
    expect(rejectNonTextIndex, lessThan(extraTextIndex));
  });

  test('android process text intake falls back to extra text', () {
    final source = File(
            'android/app/src/main/kotlin/com/local/aichathelper/MainActivity.kt')
        .readAsStringSync();
    final processStart =
        source.indexOf('if (intent.action == Intent.ACTION_PROCESS_TEXT)');
    final sendStart = source.indexOf('intent.action != Intent.ACTION_SEND &&');

    expect(processStart, isNonNegative);
    expect(sendStart, greaterThan(processStart));
    final methodBody = source.substring(processStart, sendStart);
    expect(methodBody, contains('val processText = intent.processText()'));
    expect(methodBody,
        contains('if (!processText.isNullOrBlank()) return processText'));
    expect(
      methodBody,
      contains('return intent.extraText()'),
    );
    expect(
        source,
        contains(
            'private fun Intent.processText(): String? = extraTextValue(Intent.EXTRA_PROCESS_TEXT)'));
    expect(
      source,
      contains(
          'val textSource = if (intent.action == Intent.ACTION_PROCESS_TEXT) "selected-text" else "share"'),
    );
    expect(
        source, contains('FloatingEvents.text(sharedText.trim(), textSource)'));
  });

  test('android custom view routes win over incidental image clip data', () {
    final source = File(
            'android/app/src/main/kotlin/com/local/aichathelper/MainActivity.kt')
        .readAsStringSync();
    final handleStart = source.indexOf('private fun handleIntent');
    final routeStart = source.indexOf('private fun externalRoute');

    expect(handleStart, isNonNegative);
    expect(routeStart, greaterThan(handleStart));
    final handleBody = source.substring(handleStart, routeStart);

    final actionViewIndex =
        handleBody.indexOf('if (intent.action == Intent.ACTION_VIEW)');
    final sharedImageIndex =
        handleBody.indexOf('val sharedUris = sharedImageUris(intent)');
    final sharedTextIndex =
        handleBody.indexOf('val sharedText = sharedText(intent)');

    expect(actionViewIndex, isNonNegative);
    expect(sharedImageIndex, isNonNegative);
    expect(sharedTextIndex, isNonNegative);
    expect(actionViewIndex, lessThan(sharedImageIndex));
    expect(actionViewIndex, lessThan(sharedTextIndex));
    expect(
      handleBody.indexOf('FloatingEvents.route(route)', actionViewIndex),
      lessThan(sharedImageIndex),
    );
  });

  test('android native deep links accept query route aliases', () {
    final source = File(
            'android/app/src/main/kotlin/com/local/aichathelper/MainActivity.kt')
        .readAsStringSync();
    final routeStart = source.indexOf('private fun externalRoute');
    final shareStart = source.indexOf('private fun sharedImageUris');

    expect(routeStart, isNonNegative);
    expect(shareStart, greaterThan(routeStart));
    final routeBody = source.substring(routeStart, shareStart);

    expect(routeBody, contains('if (!uri.isHierarchical)'));
    expect(routeBody, contains('uri.schemeSpecificPart'));
    expect(routeBody, contains('val queryRoute = externalRouteQuery(uri)'));
    expect(routeBody, contains('private fun externalRouteQuery(uri: Uri)'));
    expect(routeBody, contains('"targetroute"'));
    expect(routeBody, contains('"deeplink"'));
    expect(routeBody, contains('"url"'));
    expect(routeBody, contains('"uri"'));
    expect(routeBody, contains('"link"'));
    expect(routeBody, contains('"destination"'));
    expect(routeBody, contains('uri.queryParameterNames'));
    expect(routeBody, contains('uri.getQueryParameter(name)'));
    expect(routeBody, contains('private fun isExternalRouteWrapper'));
    expect(routeBody, contains('private fun isExternalRouteContainer'));
    final wrapperStart =
        routeBody.indexOf('private fun isExternalRouteWrapper');
    final containerStart =
        routeBody.indexOf('private fun isExternalRouteContainer');
    expect(wrapperStart, isNonNegative);
    expect(containerStart, greaterThan(wrapperStart));
    final wrapperBody = routeBody.substring(wrapperStart, containerStart);
    for (final alias in const [
      'open',
      'route',
      'router',
      'navigate',
      'navigation',
      'go',
      'screen',
      'page',
      'target',
      'deeplink',
      'url',
      'uri',
      'link',
      'destination',
    ]) {
      expect(wrapperBody, contains('"$alias"'));
    }
    expect(routeBody, contains('"settings"'));
    expect(routeBody, contains('return "\$pathRoute/\$queryRoute"'));
    expect(routeBody.indexOf('isExternalRouteContainer(pathRoute)'),
        lessThan(routeBody.indexOf('return pathRoute ?: queryRoute')));
  });

  test('android native handoffs are marked consumed after first delivery', () {
    final source = File(
            'android/app/src/main/kotlin/com/local/aichathelper/MainActivity.kt')
        .readAsStringSync();
    final handleStart = source.indexOf('private fun handleIntent');
    final routeStart = source.indexOf('private fun externalRoute');

    expect(handleStart, isNonNegative);
    expect(routeStart, greaterThan(handleStart));
    final handleBody = source.substring(handleStart, routeStart);

    expect(source, contains('nativeHandoffConsumedExtra'));
    expect(
      handleBody,
      contains(
          'if (intent.getBooleanExtra(nativeHandoffConsumedExtra, false)) return'),
    );
    expect(
      handleBody.indexOf('markNativeHandoffConsumed(intent)'),
      lessThan(handleBody.indexOf('FloatingEvents.screenshot')),
    );
    expect(
      handleBody.indexOf(
        'markNativeHandoffConsumed(intent)',
        handleBody.indexOf('if (!sharedText.isNullOrBlank())'),
      ),
      lessThan(
        handleBody.indexOf(
          'FloatingEvents.text(sharedText.trim(), textSource)',
          handleBody.indexOf('if (!sharedText.isNullOrBlank())'),
        ),
      ),
    );
    expect(
      handleBody.indexOf(
        'markNativeHandoffConsumed(intent)',
        handleBody.indexOf('if (!route.isNullOrBlank())'),
      ),
      lessThan(handleBody.indexOf('FloatingEvents.route')),
    );
    expect(
        source, contains('intent.putExtra(nativeHandoffConsumedExtra, true)'));
    expect(source, contains('setIntent(intent)'));
  });

  test('android custom input method service is removed', () {
    final manifest =
        File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
    expect(manifest, isNot(contains('.AIReplyInputMethodService')));
    expect(manifest, isNot(contains('android.permission.BIND_INPUT_METHOD')));
    expect(manifest, isNot(contains('android.view.InputMethod')));
    expect(manifest, isNot(contains('@xml/input_method_config')));
    expect(
        File('android/app/src/main/kotlin/com/local/aichathelper/AIReplyInputMethodService.kt')
            .existsSync(),
        isFalse);
    expect(
        File('android/app/src/main/kotlin/com/local/aichathelper/PinyinDictionary.kt')
            .existsSync(),
        isFalse);
    expect(
        File('android/app/src/main/kotlin/com/local/aichathelper/OpenSourcePinyinLexicon.kt')
            .existsSync(),
        isFalse);
    expect(
        File('android/app/src/main/res/xml/input_method_config.xml')
            .existsSync(),
        isFalse);
    expect(
        File('android/app/src/main/assets/ime/rime_ice_core.tsv').existsSync(),
        isFalse);
    expect(File('scripts/generate_rime_ice_lexicon.py').existsSync(), isFalse);
    expect(File('third_party/rime-ice/NOTICE.md').existsSync(), isFalse);
    expect(File('third_party/rime-ice/LICENSE').existsSync(), isFalse);
  });

  test(
      'android selected text process text route remains available without custom ime',
      () {
    final manifest =
        File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
    final mainActivity = File(
            'android/app/src/main/kotlin/com/local/aichathelper/MainActivity.kt')
        .readAsStringSync();
    final appShell = File('lib/app_shell.dart').readAsStringSync();

    expect(manifest, contains('android.intent.action.PROCESS_TEXT'));
    expect(mainActivity, contains('Intent.ACTION_PROCESS_TEXT'));
    expect(mainActivity, contains('Intent.EXTRA_PROCESS_TEXT'));
    expect(
        mainActivity,
        contains(
            'val textSource = if (intent.action == Intent.ACTION_PROCESS_TEXT) "selected-text" else "share"'));
    expect(appPathForExternalRoute('aichathelper://text'), AppRoutes.text);
    expect(isTextExternalRoute('aichathelper://text'), isTrue);
    expect(isQuickExternalRoute('aichathelper://text'), isFalse);
    expect(appShell, contains('isTextExternalRoute(event.route)'));
    expect(appShell, contains('prepareExternalTextInput()'));
  });

  test('README reflects selected text replacement without native input method',
      () {
    final readme = File('README.md').readAsStringSync();
    final floatingSource =
        File('lib/screens/floating_guide_screen.dart').readAsStringSync();

    expect(readme, contains('without shipping a custom system input method'));
    expect(floatingSource, isNot(contains('AI Reply 键盘入口')));
    expect(floatingSource, isNot(contains('打开输入法设置')));
    expect(floatingSource, isNot(contains('切换输入法')));
    expect(readme, isNot(contains('rime-ice')));
    expect(readme, isNot(contains('previous-keyboard return')));
    expect(readme,
        isNot(contains('horizontally scrollable Chinese candidate strip')));
    expect(readme, isNot(contains('Android input-method registration')));
  });

  test('visible profile fallback copy mirrors iOS profile wording', () {
    final cardSource =
        File('lib/widgets/history_people_widgets.dart').readAsStringSync();
    final presentationSource =
        File('lib/core/presentation_helpers.dart').readAsStringSync();

    expect(cardSource, contains('profile.listSubtitleLabel'));
    expect(presentationSource, contains('等待更多聊天样本完善画像'));
    expect(cardSource, isNot(contains('画像待完善')));
    expect(presentationSource, isNot(contains('画像待完善')));
  });

  test('README android delivery instructions match current build gates', () {
    final readme = File('README.md').readAsStringSync();
    final gradle = File('android/app/build.gradle').readAsStringSync();

    expect(gradle, contains('compileSdk = 36'));
    expect(gradle, contains('targetSdk = 36'));
    expect(readme, contains('Android SDK Platform 36+'));
    expect(readme, contains('flutter build appbundle --release'));
    expect(readme, contains('cd android && ./gradlew lintVitalRelease'));
    expect(readme, contains('does not run local OCR'));
    expect(readme, contains('optional two-step vision'));
    expect(readme, contains('is not long-term cached'));
  });

  test('android project gradle files avoid deprecated repository url syntax',
      () {
    for (final path in const [
      'android/settings.gradle',
      'android/build.gradle',
    ]) {
      final source = File(path).readAsStringSync();

      expect(source, isNot(contains(RegExp(r'maven\s*\{\s*url\s+"'))));
      expect(source, contains('url = uri("https://maven.aliyun.com'));
    }
  });

  test('flutter crash reports stay out of source audit', () {
    final gitignore = File('.gitignore').readAsStringSync();

    expect(gitignore, contains('flutter_*.log'));
  });

  test('android release signing can be enforced for distributable builds', () {
    final gradle = File('android/app/build.gradle').readAsStringSync();
    final example = File('android/local.properties.example').readAsStringSync();
    final audit = File('docs/MIGRATION_AUDIT.md').readAsStringSync();

    expect(gradle, contains('ENFORCE_RELEASE_SIGNING'));
    expect(gradle, contains('hasReleaseSigningCredentials'));
    expect(gradle, contains('"assembleRelease", "bundleRelease"'));
    expect(gradle, contains('requestedReleaseDistribution'));
    expect(gradle, contains('throw new GradleException(message)'));
    expect(gradle, contains('logger.lifecycle("WARNING:'));
    for (final property in const [
      'RELEASE_STORE_FILE',
      'RELEASE_STORE_PASSWORD',
      'RELEASE_KEY_ALIAS',
      'RELEASE_KEY_PASSWORD',
    ]) {
      expect(gradle, contains(property));
      expect(example, contains(property));
    }
    expect(example, contains('ENFORCE_RELEASE_SIGNING=true'));
    expect(audit, contains('ENFORCE_RELEASE_SIGNING=true'));
    expect(audit, contains('flutter build appbundle --release'));
    expect(audit, contains('distributable APKs or app bundles'));
  });

  test('android release builds use flutter version metadata', () {
    final gradle = File('android/app/build.gradle').readAsStringSync();

    expect(gradle, contains('def localProperties = new Properties()'));
    expect(gradle, contains('rootProject.file("local.properties")'));
    expect(gradle, contains('project.findProperty("flutter.versionCode")'));
    expect(
        gradle, contains('localProperties.getProperty("flutter.versionCode")'));
    expect(gradle, contains('project.findProperty("flutter.versionName")'));
    expect(
        gradle, contains('localProperties.getProperty("flutter.versionName")'));
    expect(gradle, contains('versionCode = flutterVersionCode.toInteger()'));
    expect(gradle, contains('versionName = flutterVersionName'));
    expect(gradle, isNot(contains('versionCode = 1\n')));
    expect(gradle, isNot(contains('versionName = "1.0"')));
  });

  test('android image handoffs accept clip description image mime', () {
    final source = File(
            'android/app/src/main/kotlin/com/local/aichathelper/MainActivity.kt')
        .readAsStringSync();

    expect('clipHasImageMime(it)'.allMatches(source), hasLength(3));
    expect(source, contains('usableImageUris('));
    expect(
      'intent.streamUris() + intent.clipData.uriItems()'.allMatches(source),
      hasLength(2),
    );
    expect(source,
        contains('val imageUris = distinctUris.filter { isImageUri(it) }'));
    expect(source, contains('trustDeclaredImage = isImage || clipLooksImage'));
  });

  test(
      'android image handoffs try untyped content uris without stealing routes',
      () {
    final source = File(
            'android/app/src/main/kotlin/com/local/aichathelper/MainActivity.kt')
        .readAsStringSync();
    final uriStart = source.indexOf('private fun usableImageUris');
    final overlayStart = source.indexOf('private fun showReplyOverlay');
    final uriBlock = source.substring(uriStart, overlayStart);

    expect(uriBlock, contains('distinctUris.filter { isUntypedFileUri(it) }'));
    expect(uriBlock, contains('ContentResolver.SCHEME_CONTENT'));
    expect(uriBlock, contains('ContentResolver.SCHEME_FILE'));
    expect(uriBlock, contains('application/octet-stream'));
  });

  test('android image share handoff tries later uri candidates after failures',
      () {
    final source = File(
            'android/app/src/main/kotlin/com/local/aichathelper/MainActivity.kt')
        .readAsStringSync();
    final handleStart = source.indexOf('private fun handleIntent');
    final routeStart = source.indexOf('private fun externalRoute');
    final uriStart = source.indexOf('private fun usableImageUris');
    final overlayStart = source.indexOf('private fun showReplyOverlay');

    expect(handleStart, isNonNegative);
    expect(routeStart, greaterThan(handleStart));
    final handleBody = source.substring(handleStart, routeStart);
    expect(handleBody, contains('val sharedUris = sharedImageUris(intent)'));
    expect(handleBody, contains('var lastImageError: Throwable? = null'));
    expect(handleBody, contains('for (uri in sharedUris)'));
    expect(handleBody,
        contains('FloatingEvents.screenshot(copyClipboardUri(uri), "share")'));
    expect(handleBody, contains('lastImageError = error'));
    expect(
        handleBody,
        contains(
            'FloatingEvents.error(lastImageError?.message ?: "无法读取分享的图片。")'));

    expect(uriStart, isNonNegative);
    expect(overlayStart, greaterThan(uriStart));
    final uriBody = source.substring(uriStart, overlayStart);
    expect(uriBody, contains('return imageUris + fallbackUris.filterNot'));
  });

  test('android image uri detection checks path segments for extensions', () {
    final source = File(
            'android/app/src/main/kotlin/com/local/aichathelper/MainActivity.kt')
        .readAsStringSync();
    final uriStart = source.indexOf('private fun isImageUri');
    final textStart = source.indexOf('private fun sharedText');

    expect(uriStart, isNonNegative);
    expect(textStart, greaterThan(uriStart));

    final uriBlock = source.substring(uriStart, textStart);
    expect(uriBlock, contains('private fun imageMimeFromExtension'));
    expect(uriBlock, contains('MimeTypeMap.getFileExtensionFromUrl'));
    expect(uriBlock, contains('extensionFromPathSegment(uri.lastPathSegment)'));
    expect(uriBlock, contains('extensionFromPathSegment(uri.path)'));
    expect(uriBlock, contains("substringBefore('?')"));
    expect(uriBlock, contains("substringBefore('#')"));
    expect(uriBlock, contains('getMimeTypeFromExtension(extension)'));
  });

  test('android clipboard image import tries later uri items after failures',
      () {
    final source = File(
            'android/app/src/main/kotlin/com/local/aichathelper/MainActivity.kt')
        .readAsStringSync();
    final methodStart = source.indexOf('private fun readClipboardImage');
    final methodEnd =
        source.indexOf('private fun clipHasImageMime', methodStart);

    expect(methodStart, isNonNegative);
    expect(methodEnd, greaterThan(methodStart));
    final method = source.substring(methodStart, methodEnd);
    expect(method, contains('var lastImageError: Throwable? = null'));
    expect(method, contains('try {'));
    expect(method, contains('isUntypedFileUri(uri)'));
    expect(method, contains('val path = copyClipboardUri(uri)'));
    expect(method, contains('lastImageError = error'));
    expect(method, contains('if (lastImageError != null)'));
    expect(method, contains('clipboard_no_image'));
  });

  test('android image handoff copy cleans up partial files on failure', () {
    final source = File(
            'android/app/src/main/kotlin/com/local/aichathelper/MainActivity.kt')
        .readAsStringSync();

    expect(source, contains('import android.graphics.BitmapFactory'));
    expect(source, contains('private fun copyClipboardUri(uri: Uri): String'));
    expect(source,
        contains('File.createTempFile("clipboard-image-", ".img", cacheDir)'));
    expect(source, contains('ensureCopiedImageFile(file)'));
    expect(source, contains('private fun ensureCopiedImageFile(file: File)'));
    expect(source, contains('inJustDecodeBounds = true'));
    expect(
      source,
      contains('throw IllegalStateException("剪贴板或分享内容不是可读取的图片。")'),
    );
    expect(source, contains('} catch (error: Throwable) {'));
    expect(
        source, contains('runCatching { if (file.exists()) file.delete() }'));
    expect(source, contains('throw error'));
  });

  test('android floating overlay view operations are guarded', () {
    final source = File(
            'android/app/src/main/kotlin/com/local/aichathelper/FloatingCaptureService.kt')
        .readAsStringSync();
    final createStart = source.indexOf('override fun onCreate()');
    final commandStart = source.indexOf('override fun onStartCommand');
    final destroyStart = source.indexOf('override fun onDestroy()');

    expect(
      source,
      contains('runCatching {\n            windowManager?.addView'),
    );
    expect(source, contains('runCatching {\n            manager.addView'));
    expect(source, contains('private fun removeViewSafely(view: View)'));
    expect(
      source,
      contains('FloatingEvents.error(error.message ?: "无法显示悬浮窗。")'),
    );
    expect(source, contains('FloatingEvents.error("请先开启悬浮窗权限。")'));
    expect(source, contains('stopSelf()'));
    expect(
      source,
      contains('FloatingEvents.error(error.message ?: "无法显示快捷回复面板。")'),
    );
    expect(
      source,
      contains('FloatingEvents.error(error.message ?: "无法移除悬浮窗视图。")'),
    );
    expect(source, contains('windowManager?.updateViewLayout(view, params)'));
    expect(
        source, contains('FloatingEvents.error(error.message ?: "无法移动悬浮窗。")'));
    expect(createStart, isNonNegative);
    expect(commandStart, greaterThan(createStart));
    expect(destroyStart, greaterThan(commandStart));
    expect(
      source.substring(createStart, commandStart),
      isNot(contains('showFloatingButton()')),
    );
    expect(
      source.substring(commandStart, destroyStart),
      contains('else -> showFloatingButton()'),
    );
    expect(source, contains('hideReplyPanel(stopIfEmpty = false)'));
    expect(source,
        contains('private fun hideReplyPanel(stopIfEmpty: Boolean = true)'));
    expect(source, contains('if (stopIfEmpty) stopIfNoVisibleWindows()'));
    expect(source, contains('private fun stopIfNoVisibleWindows()'));
    expect(source, contains('if (floatingView == null && replyView == null)'));

    final panelStart = source.indexOf('private fun showReplyPanel(');
    final panelEnd = source.indexOf('private fun hideReplyPanel', panelStart);
    expect(panelStart, isNonNegative);
    expect(panelEnd, greaterThan(panelStart));
    final panelBody = source.substring(panelStart, panelEnd);
    expect(
      panelBody,
      contains(
          'if (!Settings.canDrawOverlays(this)) {\n            FloatingEvents.error("请先开启悬浮窗权限。")\n            stopSelf()\n            return\n        }'),
    );
    expect(
      panelBody,
      contains(
          'FloatingEvents.error(error.message ?: "无法显示快捷回复面板。")\n            stopIfNoVisibleWindows()'),
    );
  });

  test('android floating capture errors are not copyable replies', () {
    final source = File(
            'android/app/src/main/kotlin/com/local/aichathelper/FloatingCaptureService.kt')
        .readAsStringSync();
    final panelStart = source.indexOf('private fun showReplyPanel(');
    final panelEnd = source.indexOf('private fun hideReplyPanel', panelStart);
    final captureStart = source.indexOf('private fun captureCurrentScreen(');
    final channelStart =
        source.indexOf('private fun createChannel()', captureStart);

    expect(panelStart, isNonNegative);
    expect(panelEnd, greaterThan(panelStart));
    final panelBody = source.substring(panelStart, panelEnd);
    expect(panelBody, contains('message: String? = null'));
    expect(
      panelBody,
      contains(
          'text = message ?: if (loading) "请稍等，完成后会自动更新。" else "暂时没有可复制的回复。"'),
    );

    expect(captureStart, isNonNegative);
    expect(channelStart, greaterThan(captureStart));
    final captureBody = source.substring(captureStart, channelStart);
    expect(captureBody, contains('emptyList()'));
    expect(
      captureBody,
      isNot(contains('listOf(error ?: "无障碍截图失败，请重试。")')),
    );
    expect(
      captureBody,
      isNot(contains('listOf("为避免跳回 App，悬浮窗截图需要使用无障碍增强')),
    );
    expect(captureBody, contains('FloatingEvents.error(message)'));
  });

  test('android floating capture flow has no input method trigger', () {
    final appShellSource = File('lib/app_shell.dart').readAsStringSync();
    final bridgeSource =
        File('lib/core/platform_bridge.dart').readAsStringSync();
    final mainActivity = File(
            'android/app/src/main/kotlin/com/local/aichathelper/MainActivity.kt')
        .readAsStringSync();
    final floatingService = File(
            'android/app/src/main/kotlin/com/local/aichathelper/FloatingCaptureService.kt')
        .readAsStringSync();

    expect(bridgeSource, isNot(contains('keyboard-screen')));
    expect(bridgeSource, isNot(contains('ime-capture')));
    expect(appShellSource, contains("event.source == 'floating'"));
    expect(
        appShellSource, isNot(contains("event.source == 'keyboard-screen'")));
    expect(appShellSource,
        contains('unawaited(_handleFloatingCapture(event.path!));'));
    expect(floatingService,
        isNot(contains('const val ACTION_CAPTURE_SCREEN_REPLY')));
    expect(floatingService, isNot(contains('const val EXTRA_CAPTURE_SOURCE')));
    expect(floatingService,
        isNot(contains('ACTION_CAPTURE_SCREEN_REPLY -> captureCurrentScreen')));
    expect(
        floatingService, contains('FloatingEvents.screenshot(path, source)'));
    expect(floatingService, contains('openAppIfNeededForCapture(source)'));
    expect(
        mainActivity, contains('fun hasActiveSink(): Boolean = sink != null'));
  });

  test('android quick reply overlay supports non copyable messages', () {
    final mainActivity = File(
            'android/app/src/main/kotlin/com/local/aichathelper/MainActivity.kt')
        .readAsStringSync();
    final floatingService = File(
            'android/app/src/main/kotlin/com/local/aichathelper/FloatingCaptureService.kt')
        .readAsStringSync();
    final bridge = File('lib/core/platform_bridge.dart').readAsStringSync();

    expect(floatingService, contains('const val EXTRA_MESSAGE = "message"'));
    expect(floatingService, contains('intent.getStringExtra(EXTRA_MESSAGE)'));
    expect(floatingService, contains('replies.isEmpty() -> "当前没有可复制回复"'));
    expect(floatingService, contains('loading -> "正在理解聊天截图"'));
    expect(floatingService, contains('else -> "提示"'));
    expect(mainActivity, contains('val message = map?.get("message")'));
    expect(
      mainActivity,
      contains('putExtra(FloatingCaptureService.EXTRA_MESSAGE, message)'),
    );
    expect(bridge, contains('static Future<void> showMessageOverlay'));
    expect(bridge, contains("'message': message"));
    expect(bridge, contains("'replies': <String>[]"));
  });

  test('android system settings launches are guarded', () {
    final source = File(
            'android/app/src/main/kotlin/com/local/aichathelper/MainActivity.kt')
        .readAsStringSync();

    expect(source, contains('private fun startActivitySafely'));
    expect(source, contains('overlay_settings_failed'));
    expect(source, contains('accessibility_settings_failed'));
    expect(source, isNot(contains('input_method_settings_failed')));
    expect(source, isNot(contains('Settings.ACTION_INPUT_METHOD_SETTINGS')));
    expect(source, isNot(contains('private fun showInputMethodPickerSafely')));
    expect(source, isNot(contains('input_method_picker_failed')));
    expect(source, isNot(contains('manager.showInputMethodPicker()')));
    expect(
        source,
        contains(
            'startActivity(Intent(intent).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))'));
    expect(
        source,
        isNot(contains(
            'startActivity(intent)\n            result.success(null)')));
    expect(source,
        contains('FloatingEvents.error(error.message ?: "无法回到 AI Reply。")'));
  });

  test('android method channel service and permission actions are guarded', () {
    final source = File(
            'android/app/src/main/kotlin/com/local/aichathelper/MainActivity.kt')
        .readAsStringSync();
    final requestStart =
        source.indexOf('private fun requestNotificationPermission');
    final requestEnd =
        source.indexOf('override fun onRequestPermissionsResult');

    expect(
        source,
        contains(
            '"stopFloatingWindow" -> {\n                    stopFloatingServiceSafely(result)'));
    expect(
        source,
        contains(
            '"collapseQuickPanel" -> {\n                    collapseQuickPanelSafely(result)'));
    expect(
        source,
        isNot(contains(
            '"openInputMethodSettings" -> {\n                    startActivitySafely(')));
    expect(
        source,
        isNot(contains(
            '"showInputMethodPicker" -> showInputMethodPickerSafely(result)')));
    expect(source, contains('private fun stopFloatingServiceSafely'));
    expect(source, contains('private fun collapseQuickPanelSafely'));
    expect(source, isNot(contains('private fun showInputMethodPickerSafely')));
    expect(source, contains('floating_stop_failed'));
    expect(source, contains('quick_panel_collapse_failed'));
    expect(source, isNot(contains('input_method_picker_failed')));
    expect(source, contains('FloatingEvents.error(message)'));
    expect(requestStart, isNot(-1));
    expect(requestEnd, greaterThan(requestStart));
    final requestBody = source.substring(requestStart, requestEnd);
    expect(requestBody, contains('try {\n            requestPermissions'));
    expect(requestBody, contains('pendingNotificationPermissionResult = null'));
    expect(requestBody, contains('notification_permission_failed'));
  });

  test('android foreground service promotion is guarded', () {
    final floatingService = File(
            'android/app/src/main/kotlin/com/local/aichathelper/FloatingCaptureService.kt')
        .readAsStringSync();
    final projectionService = File(
            'android/app/src/main/kotlin/com/local/aichathelper/ProjectionForegroundService.kt')
        .readAsStringSync();

    expect(floatingService, contains('private fun enterForegroundSafely'));
    expect(floatingService,
        contains('FloatingEvents.error(error.message ?: "无法启动悬浮窗前台服务。")'));
    expect(floatingService, contains('if (!enterForegroundSafely())'));

    expect(projectionService, contains('private fun enterForegroundSafely'));
    expect(projectionService,
        contains('FloatingEvents.error(error.message ?: "无法启动截屏前台服务。")'));
    expect(projectionService, contains('if (!enterForegroundSafely())'));
  });

  test('android floating button drag does not trigger capture click', () {
    final source = File(
            'android/app/src/main/kotlin/com/local/aichathelper/FloatingCaptureService.kt')
        .readAsStringSync();
    final touchStart = source.indexOf('button.setOnTouchListener');
    final touchEnd =
        source.indexOf('runCatching {\n            windowManager?.addView');

    expect(touchStart, isNonNegative);
    expect(touchEnd, greaterThan(touchStart));
    final touchBody = source.substring(touchStart, touchEnd);
    expect(source, contains('import android.view.ViewConfiguration'));
    expect(source, contains('import kotlin.math.abs'));
    expect(
        source,
        contains(
            'val touchSlop = ViewConfiguration.get(this).scaledTouchSlop'));
    expect(source, contains('var moved = false'));
    expect(source,
        contains('private const val PREFS_NAME = "ai_reply_floating_prefs"'));
    expect(
        source, contains('private const val PREF_FLOATING_X = "floating_x"'));
    expect(
        source, contains('private const val PREF_FLOATING_Y = "floating_y"'));
    expect(source, contains('restoreFloatingButtonPosition(params)'));
    expect(touchBody, contains('MotionEvent.ACTION_DOWN'));
    expect(touchBody, contains('moved = false'));
    expect(touchBody,
        contains('if (abs(deltaX) > touchSlop || abs(deltaY) > touchSlop)'));
    expect(touchBody, contains('if (!moved) return@setOnTouchListener true'));
    expect(touchBody, contains('clampFloatingButtonPosition(params)'));
    expect(touchBody, contains('MotionEvent.ACTION_UP'));
    expect(touchBody, contains('if (moved) {'));
    expect(touchBody, contains('saveFloatingButtonPosition(params)'));
    expect(touchBody, contains('view.performClick()'));

    expect(source, contains('private fun clampFloatingButtonPosition'));
    expect(
        source,
        contains(
            'val maxX = (metrics.widthPixels - params.width).coerceAtLeast(0)'));
    expect(
        source,
        contains(
            'val maxY = (metrics.heightPixels - params.height).coerceAtLeast(0)'));
    expect(source, contains('params.x = params.x.coerceIn(0, maxX)'));
    expect(source, contains('params.y = params.y.coerceIn(0, maxY)'));
    expect(source, contains('private fun restoreFloatingButtonPosition'));
    expect(source, contains('prefs.getInt(PREF_FLOATING_X, params.x)'));
    expect(source, contains('prefs.getInt(PREF_FLOATING_Y, params.y)'));
    expect(source, contains('private fun saveFloatingButtonPosition'));
    expect(source, contains('.putInt(PREF_FLOATING_X, params.x)'));
    expect(source, contains('.putInt(PREF_FLOATING_Y, params.y)'));
  });

  test('android floating overlay uses polished assistant ui states', () {
    final source = File(
            'android/app/src/main/kotlin/com/local/aichathelper/FloatingCaptureService.kt')
        .readAsStringSync();
    final buttonStart = source.indexOf('private fun showFloatingButton()');
    final panelStart = source.indexOf('private fun showReplyPanel(');
    final panelEnd = source.indexOf('private fun hideReplyPanel', panelStart);

    expect(buttonStart, isNonNegative);
    expect(panelStart, greaterThan(buttonStart));
    expect(panelEnd, greaterThan(panelStart));

    final buttonBody = source.substring(buttonStart, panelStart);
    final panelBody = source.substring(panelStart, panelEnd);
    expect(source, contains('import android.view.HapticFeedbackConstants'));
    expect(source, contains('private fun performLightHaptic(view: View)'));
    expect(source, contains('HapticFeedbackConstants.VIRTUAL_KEY'));
    expect(buttonBody, contains('contentDescription = "AI Reply 悬浮截图"'));
    expect(buttonBody, contains('statefulGradientBackground('));
    expect(buttonBody,
        contains('intArrayOf(0xFF0F766E.toInt(), 0xFF38BDF8.toInt())'));
    expect(buttonBody, contains('text = "AI"'));
    expect(buttonBody, contains('text = "回复"'));
    expect(buttonBody, contains('setOnClickListener { view ->'));
    expect(buttonBody, contains('performLightHaptic(view)'));
    expect(buttonBody, contains('captureCurrentScreen("floating")'));
    expect(buttonBody, contains('view.alpha = 0.86f'));
    expect(
        buttonBody,
        isNot(contains(
            'setBackgroundResource(android.R.drawable.presence_online)')));

    expect(panelBody, contains('roundedBackground('));
    expect(panelBody, contains('text = "关闭"'));
    expect(panelBody, contains('statusChip(loading, replies.isNotEmpty())'));
    expect(panelBody, contains('replies.take(5).forEachIndexed'));
    expect(panelBody, contains('returnPackage.isNullOrBlank()'));
    expect(panelBody, contains('"复制后可回到聊天 App 粘贴"'));
    expect(panelBody, contains('"复制后会自动回到聊天 App"'));
    expect(panelBody, contains('MaxHeightScrollView('));
    expect(panelBody,
        contains('(resources.displayMetrics.heightPixels * 0.62f).toInt()'));
    expect(
        panelBody,
        contains(
            '(resources.displayMetrics.widthPixels * 0.86f).toInt().coerceAtMost(dp(420))'));
    expect(panelBody, contains('isVerticalScrollBarEnabled = true'));
    expect(source, contains('private class MaxHeightScrollView'));
    expect(source, contains('View.MeasureSpec.AT_MOST'));
    expect(source, contains('private fun statefulRoundedBackground'));
    expect(source, contains('private fun statefulGradientBackground'));
    expect(source, contains('private fun dp(value: Int): Int'));
    expect(source, contains('private fun overlayWindowType(): Int'));
    expect(source, contains('@Suppress("DEPRECATION")'));
    expect(source, isNot(contains('import android.widget.Button')));
  });

  test('android mediaprojection registers callback before virtual display', () {
    final source = File(
            'android/app/src/main/kotlin/com/local/aichathelper/MainActivity.kt')
        .readAsStringSync();
    final registerIndex = source.indexOf('projection.registerCallback');
    final displayIndex = source.indexOf('projection.createVirtualDisplay');

    expect(registerIndex, isNot(-1));
    expect(displayIndex, isNot(-1));
    expect(registerIndex, lessThan(displayIndex));
    expect(source, contains('projection.unregisterCallback'));
  });

  test('android screenshot launch and saved files are guarded', () {
    final activity = File(
            'android/app/src/main/kotlin/com/local/aichathelper/MainActivity.kt')
        .readAsStringSync();
    final accessibility = File(
            'android/app/src/main/kotlin/com/local/aichathelper/ScreenshotAccessibilityService.kt')
        .readAsStringSync();
    final accessibilityConfig =
        File('android/app/src/main/res/xml/accessibility_service_config.xml')
            .readAsStringSync();
    final strings =
        File('android/app/src/main/res/values/strings.xml').readAsStringSync();
    final styles =
        File('android/app/src/main/res/values/styles.xml').readAsStringSync();
    final requestStart = activity.indexOf('private fun requestProjection');
    final activityResultStart = activity.indexOf('@Deprecated', requestStart);
    final requestBody = activity.substring(requestStart, activityResultStart);
    final saveStart = activity.indexOf('private fun saveBitmap');
    final activityEnd = activity.indexOf('\n}', saveStart);
    final saveBody = activity.substring(saveStart, activityEnd);

    expect(requestBody,
        contains('try {\n            val manager = getSystemService'));
    expect(requestBody, contains('manager.createScreenCaptureIntent'));
    expect(requestBody,
        contains('startActivityForResult(intent, projectionRequestCode)'));
    expect(requestBody, contains('pendingProjectionResult = null'));
    expect(requestBody, contains('capture_launch_failed'));
    expect(saveBody,
        contains('File.createTempFile("floating-capture-", ".jpg", cacheDir)'));
    expect(saveBody, contains('if (!bitmap.compress'));
    expect(
        saveBody, contains('runCatching { if (file.exists()) file.delete() }'));

    expect(accessibility,
        contains('try {\n                service.takeScreenshot'));
    expect(accessibilityConfig, contains('android:canTakeScreenshot="true"'));
    expect(
        accessibilityConfig,
        contains(
            'android:description="@string/accessibility_service_description"'));
    expect(strings, contains('name="accessibility_service_description"'));
    expect(styles, isNot(contains('name="accessibility_service_description"')));
    expect(
        accessibility,
        contains(
            'File.createTempFile("accessibility-capture-", ".jpg", context.cacheDir)'));
    expect(accessibility, contains('if (!software.compress'));
    expect(accessibility,
        contains('runCatching { file?.takeIf { it.exists() }?.delete() }'));
    expect(
        accessibility, contains('callback(null, error.message ?: "无障碍截图失败。")'));
    expect(accessibility,
        contains('fun isConnected(): Boolean = instance != null'));
    expect(accessibility, contains('Settings.Secure.ACCESSIBILITY_ENABLED'));
    expect(accessibility,
        contains('Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES'));
    expect(accessibility,
        contains('ComponentName.unflattenFromString(splitter.next())'));
    expect(accessibility, contains('AI Reply 无障碍服务已开启但还在连接，请稍后再试。'));
    expect(accessibility, contains('override fun onUnbind(intent: Intent?)'));
    expect(accessibility, contains('if (instance === this) instance = null'));
    expect(
        activity, contains('ScreenshotAccessibilityService.isEnabled(this)'));
    expect(
        File('android/app/src/main/kotlin/com/local/aichathelper/FloatingCaptureService.kt')
            .readAsStringSync(),
        contains('ScreenshotAccessibilityService.isEnabled(this)'));
  });

  test('android pending native requests are cancelled on activity destroy', () {
    final activity = File(
            'android/app/src/main/kotlin/com/local/aichathelper/MainActivity.kt')
        .readAsStringSync();
    final destroyStart = activity.indexOf('override fun onDestroy()');
    final destroyEnd =
        activity.indexOf('private fun hasNotificationPermission');
    final cancelStart =
        activity.indexOf('private fun cancelPendingNativeResults');
    final handleIntentStart = activity.indexOf('private fun handleIntent');
    final captureDelayStart =
        activity.indexOf('Handler(Looper.getMainLooper()).postDelayed');
    final captureDelayEnd = activity.indexOf('}, 450)', captureDelayStart);

    expect(destroyStart, isNonNegative);
    expect(destroyEnd, greaterThan(destroyStart));
    expect(cancelStart, isNonNegative);
    expect(handleIntentStart, greaterThan(cancelStart));
    expect(captureDelayStart, isNonNegative);
    expect(captureDelayEnd, greaterThan(captureDelayStart));

    final destroyBody = activity.substring(destroyStart, destroyEnd);
    final cancelBody = activity.substring(cancelStart, handleIntentStart);
    final captureDelayBody =
        activity.substring(captureDelayStart, captureDelayEnd);

    expect(destroyBody, contains('cancelPendingNativeResults'));
    expect(destroyBody, contains('super.onDestroy()'));
    expect(cancelBody, contains('pendingProjectionResult?.error'));
    expect(cancelBody, contains('pendingProjectionResult = null'));
    expect(cancelBody, contains('pendingNotificationPermissionResult?.error'));
    expect(cancelBody, contains('pendingNotificationPermissionResult = null'));
    expect(cancelBody, contains('ProjectionForegroundService.stop(this)'));
    expect(cancelBody, contains('if (hadPendingResult) FloatingEvents.error'));
    expect(captureDelayBody,
        contains('if (pendingProjectionResult == null) return@postDelayed'));
  });

  test('android in-app screenshots do not replay as external quick events', () {
    final activity = File(
            'android/app/src/main/kotlin/com/local/aichathelper/MainActivity.kt')
        .readAsStringSync();
    final captureStart = activity.indexOf('private fun captureProjection');
    final accessibilityStart =
        activity.indexOf('private fun takeAccessibilityScreenshot');
    final saveStart = activity.indexOf('private fun saveBitmap');

    expect(captureStart, isNonNegative);
    expect(accessibilityStart, greaterThan(captureStart));
    expect(saveStart, greaterThan(accessibilityStart));

    final captureBody = activity.substring(captureStart, accessibilityStart);
    final accessibilityBody = activity.substring(accessibilityStart, saveStart);

    expect(captureBody, contains('pendingProjectionResult?.success(path)'));
    expect(captureBody, contains('bringAppToFront()'));
    expect(captureBody, isNot(contains('FloatingEvents.screenshot(path)')));
    expect(accessibilityBody, contains('result?.success(path)'));
    expect(accessibilityBody, contains('bringAppToFront()'));
    expect(
        accessibilityBody, isNot(contains('FloatingEvents.screenshot(path)')));
  });

  test('android floating events pending queue is bounded', () {
    final source = File(
            'android/app/src/main/kotlin/com/local/aichathelper/MainActivity.kt')
        .readAsStringSync();
    final eventsStart = source.indexOf('object FloatingEvents');
    final emitStart = source.indexOf('private fun emit', eventsStart);

    expect(eventsStart, isNonNegative);
    expect(emitStart, greaterThan(eventsStart));
    expect(
        source.indexOf('private const val maxPendingEvents = 20', eventsStart),
        lessThan(emitStart));
    expect(source.indexOf('if (pending.size >= maxPendingEvents)', emitStart),
        isNonNegative);
    expect(source.indexOf('pending.removeAt(0)', emitStart), isNonNegative);
  });

  test('android floating events clean blank payloads before enqueue', () {
    final source = File(
            'android/app/src/main/kotlin/com/local/aichathelper/MainActivity.kt')
        .readAsStringSync();
    final eventsStart = source.indexOf('object FloatingEvents');

    expect(eventsStart, isNonNegative);
    final eventsBody = source.substring(eventsStart);
    expect(eventsBody, contains('private fun cleanEventField(value: String?)'));
    expect(
      eventsBody,
      contains('value?.trim()?.takeIf { it.isNotEmpty() }'),
    );
    expect(eventsBody,
        contains('val cleanPath = cleanEventField(path) ?: return'));
    expect(eventsBody,
        contains('val cleanMessage = cleanEventField(message) ?: return'));
    expect(eventsBody,
        contains('val cleanRoute = cleanEventField(route) ?: return'));
    expect(eventsBody,
        contains('val cleanText = cleanEventField(text) ?: return'));
    expect(eventsBody, contains('cleanEventField(source)?.let'));
    expect(eventsBody, isNot(contains('if (!source.isNullOrBlank())')));
  });

  test('android quick reply return packages are queryable and native-handled',
      () {
    final manifest =
        File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
    final mainActivity = File(
            'android/app/src/main/kotlin/com/local/aichathelper/MainActivity.kt')
        .readAsStringSync();
    final floatingService = File(
            'android/app/src/main/kotlin/com/local/aichathelper/FloatingCaptureService.kt')
        .readAsStringSync();

    for (final packageName in const [
      'com.tencent.mm',
      'com.tencent.mobileqq',
      'com.xingin.xhs',
      'com.sina.weibo',
      'com.ss.android.ugc.aweme',
      'com.whatsapp',
      'org.telegram.messenger',
      'jp.naver.line.android',
      'com.alibaba.android.rimet',
      'com.ss.android.lark',
    ]) {
      expect(manifest, contains('<package android:name="$packageName" />'));
    }
    expect(mainActivity,
        contains('putExtra(FloatingCaptureService.EXTRA_RETURN_PACKAGE'));
    expect(mainActivity, contains('fun copiedReply(text: String)'));
    expect(
        floatingService, contains('getLaunchIntentForPackage(targetPackage)'));
    expect(floatingService,
        contains(r'FloatingEvents.error("无法回到聊天 App：未找到 $targetPackage。")'));
    expect(floatingService,
        contains('FloatingEvents.error(error.message ?: "无法回到聊天 App。")'));
    expect(floatingService, contains('private fun copyReplySafely'));
    expect(floatingService, contains('if (copyReplySafely(reply))'));
    expect(floatingService,
        contains('FloatingEvents.error(error.message ?: "无法复制回复到剪贴板。")'));
    expect(floatingService, contains('performLightHaptic(view)'));
    expect(floatingService, contains('import android.widget.Toast'));
    expect(floatingService, contains('private fun showCopiedToast()'));
    expect(floatingService, contains('Toast.makeText(this, "已复制到剪贴板"'));
    final copySuccessStart =
        floatingService.indexOf('if (copyReplySafely(reply))');
    final copySuccessEnd =
        floatingService.indexOf('private fun hideReplyPanel', copySuccessStart);
    expect(copySuccessStart, isNonNegative);
    expect(copySuccessEnd, greaterThan(copySuccessStart));
    final copySuccessBody =
        floatingService.substring(copySuccessStart, copySuccessEnd);
    expect(
      copySuccessBody.indexOf('showCopiedToast()'),
      lessThan(copySuccessBody.indexOf('hideReplyPanel()')),
    );
    expect(floatingService, contains('openReturnPackage(returnPackage)'));
    expect(floatingService, contains('FloatingEvents.copiedReply(reply)'));
  });

  test('image service resizes and encodes payload off the UI path', () async {
    final file = File(
        '${Directory.systemTemp.path}/ai-reply-image-service-${DateTime.now().microsecondsSinceEpoch}.png');
    final source = img.Image(width: 640, height: 320);
    img.fill(source, color: img.ColorRgb8(20, 120, 220));
    await file.writeAsBytes(img.encodePng(source));

    final payload = await ImageService()
        .prepareImagePayload(file.path, maxWidth: 320, quality: 0.7);

    expect(payload.mimeType, 'image/jpeg');
    expect(payload.width, 320);
    expect(payload.height, 160);
    expect(payload.sizeInBytes, greaterThan(0));
    expect(base64Decode(payload.base64).length, payload.sizeInBytes);

    await file.delete();
  });

  test('image payload data url matches iOS encoder format', () {
    const payload = ImagePayload(
      base64: 'abc123',
      mimeType: 'image/jpeg',
      width: 320,
      height: 160,
      sizeInBytes: 6,
    );

    expect(payload.dataURL, 'data:image/jpeg;base64,abc123');
  });

  test('image service maps missing or corrupt files to app errors', () async {
    final missing = File(
        '${Directory.systemTemp.path}/ai-reply-missing-${DateTime.now().microsecondsSinceEpoch}.png');
    final corrupt = File(
        '${Directory.systemTemp.path}/ai-reply-corrupt-${DateTime.now().microsecondsSinceEpoch}.png');
    await corrupt.writeAsBytes([0, 1, 2, 3, 4]);
    final service = ImageService();

    await expectLater(
      service.prepareImagePayload(missing.path, maxWidth: 320, quality: 0.7),
      throwsA(isA<AppException>()
          .having((error) => error.message, 'message', contains('无法读取所选图片'))),
    );
    await expectLater(
      service.prepareImagePayload(corrupt.path, maxWidth: 320, quality: 0.7),
      throwsA(isA<AppException>()
          .having((error) => error.message, 'message', contains('无法读取所选图片'))),
    );

    await corrupt.delete();
  });

  test('image service saves jpeg copies atomically without temp leftovers',
      () async {
    final dir = await Directory.systemTemp.createTemp('ai-reply-atomic-bg-');
    final source = File('${dir.path}/source.png');
    final output = File('${dir.path}/custom-background.jpg');
    final image = img.Image(width: 640, height: 320);
    img.fill(image, color: img.ColorRgb8(90, 40, 160));
    await source.writeAsBytes(img.encodePng(image));
    await output.writeAsBytes([1, 2, 3]);

    try {
      await ImageService().saveJpegCopy(
        source.path,
        output.path,
        maxWidth: 320,
        quality: 0.7,
      );

      final decoded = img.decodeJpg(await output.readAsBytes());
      expect(decoded, isNotNull);
      expect(decoded!.width, 320);
      expect(decoded.height, 160);
      expect(
        dir
            .listSync()
            .whereType<File>()
            .where((file) => file.path.contains('.tmp-')),
        isEmpty,
      );

      final sourceCode = File('lib/core/image_service.dart').readAsStringSync();
      expect(sourceCode, contains('.tmp-'));
      expect(sourceCode, contains('await temp.rename(output.path)'));
      expect(
          sourceCode, contains('if (await temp.exists()) await temp.delete()'));
    } finally {
      if (await dir.exists()) await dir.delete(recursive: true);
    }
  });

  test('image service maps jpeg copy write failures to app errors', () async {
    final dir = await Directory.systemTemp.createTemp('ai-reply-copy-fail-');
    final source = File('${dir.path}/source.png');
    final blockedParent = File('${dir.path}/blocked-parent');
    final image = img.Image(width: 64, height: 64);
    img.fill(image, color: img.ColorRgb8(30, 90, 180));
    await source.writeAsBytes(img.encodePng(image));
    await blockedParent.writeAsBytes([1, 2, 3]);

    try {
      await expectLater(
        ImageService().saveJpegCopy(
          source.path,
          '${blockedParent.path}/custom-background.jpg',
          maxWidth: 320,
          quality: 0.7,
        ),
        throwsA(isA<AppException>().having(
          (error) => error.message,
          'message',
          contains('无法保存图片副本'),
        )),
      );
      expect(
        dir
            .listSync()
            .whereType<File>()
            .where((file) => file.path.contains('.tmp-')),
        isEmpty,
      );
    } finally {
      if (await dir.exists()) await dir.delete(recursive: true);
    }
  });

  test('user-facing error mapping handles raw Dio failures', () {
    final options = RequestOptions(path: '/v1/models');

    expect(
      userMessageFor(DioException.connectionTimeout(
        requestOptions: options,
        timeout: const Duration(seconds: 1),
      )),
      '接口请求超时，请稍后重试或调大请求超时。',
    );
    expect(
      userMessageFor(DioException.connectionError(
        requestOptions: options,
        reason: 'Connection refused',
      )),
      '无法连接到接口服务器，请检查 Base URL、端口和服务状态。',
    );
    expect(
      userMessageFor(DioException.connectionError(
        requestOptions: options,
        reason: 'Connection reset by peer',
      )),
      '接口连接被中断，服务器可能已断开连接或没有返回完整响应。',
    );
    expect(
      userMessageFor(DioException.badResponse(
        statusCode: 401,
        requestOptions: options,
        response: Response(
          requestOptions: options,
          statusCode: 401,
          data: {
            'error': {'message': 'bad key'}
          },
        ),
      )),
      'API Key 无效或没有权限，请重新检查配置。',
    );
    expect(
      userMessageFor(DioException.badResponse(
        statusCode: 500,
        requestOptions: options,
        response: Response(
          requestOptions: options,
          statusCode: 500,
          data: {'message': 'server exploded'},
        ),
      )),
      '接口返回错误（500）：server exploded',
    );
    expect(
      userMessageFor(DioException.badResponse(
        statusCode: 400,
        requestOptions: options,
        response: Response(
          requestOptions: options,
          statusCode: 400,
          data: {'error': 'string error'},
        ),
      )),
      '接口返回错误（400）：string error',
    );
    expect(
      userMessageFor(DioException.badResponse(
        statusCode: 502,
        requestOptions: options,
        response: Response(
          requestOptions: options,
          statusCode: 502,
          data: {
            'error': {'message': '   '},
            'detail': 'provider overloaded',
          },
        ),
      )),
      '接口返回错误（502）：provider overloaded',
    );
    expect(
      userMessageFor(DioException.badResponse(
        statusCode: 429,
        requestOptions: options,
        response: Response(
          requestOptions: options,
          statusCode: 429,
          data: {
            'error': {'error_message': 'rate limit reached'},
          },
        ),
      )),
      '接口返回错误（429）：rate limit reached',
    );
    expect(
      userMessageFor(DioException.badResponse(
        statusCode: 503,
        requestOptions: options,
        response: Response(
          requestOptions: options,
          statusCode: 503,
          data: {'error-message': 'provider busy'},
        ),
      )),
      '接口返回错误（503）：provider busy',
    );
    expect(
      userMessageFor(DioException.badResponse(
        statusCode: 400,
        requestOptions: options,
        response: Response(
          requestOptions: options,
          statusCode: 400,
          data: {
            'error': {'error_description': 'invalid request shape'},
          },
        ),
      )),
      '接口返回错误（400）：invalid request shape',
    );
    expect(
      userMessageFor(DioException.badResponse(
        statusCode: 422,
        requestOptions: options,
        response: Response(
          requestOptions: options,
          statusCode: 422,
          data: {
            'errors': [
              {'message': 'model is required'},
            ],
          },
        ),
      )),
      '接口返回错误（422）：model is required',
    );
    expect(
      userMessageFor(DioException.badResponse(
        statusCode: 429,
        requestOptions: options,
        response: Response(
          requestOptions: options,
          statusCode: 429,
          data: {
            'error': {'msg': 'too many requests'},
          },
        ),
      )),
      '接口返回错误（429）：too many requests',
    );
    expect(
      userMessageFor(DioException.badResponse(
        statusCode: 400,
        requestOptions: options,
        response: Response(
          requestOptions: options,
          statusCode: 400,
          data: {'reason': 'invalid base64 image'},
        ),
      )),
      '接口返回错误（400）：invalid base64 image',
    );
    expect(
      userMessageFor(DioException.badResponse(
        statusCode: 400,
        requestOptions: options,
        response: Response(
          requestOptions: options,
          statusCode: 400,
          data: {
            'error': {'code': 'invalid_api_key'},
          },
        ),
      )),
      '接口返回错误（400）：invalid_api_key',
    );
    expect(
      userMessageFor(DioException.badResponse(
        statusCode: 503,
        requestOptions: options,
        response: Response(
          requestOptions: options,
          statusCode: 503,
          data: {'type': 'provider_unavailable'},
        ),
      )),
      '接口返回错误（503）：provider_unavailable',
    );
    expect(
      userMessageFor(
        PlatformException(code: 'clipboard', message: '剪贴板不可用'),
      ),
      '剪贴板不可用',
    );
    expect(
      userMessageFor(
        PlatformException(code: 'clipboard', message: '   '),
      ),
      '系统剪贴板暂不可用。',
    );
    expect(
      userMessageFor(TimeoutException('operation timed out')),
      '接口请求超时，请稍后重试或调大请求超时。',
    );
    expect(
      userMessageFor(const SocketException('Connection reset by peer')),
      '接口连接被中断，服务器可能已断开连接或没有返回完整响应。',
    );
    expect(
      userMessageFor(
        const FileSystemException('Permission denied', '/tmp/avatar.png'),
      ),
      '文件读写失败：Permission denied（/tmp/avatar.png）',
    );
    expect(
      userMessageFor(
        const FileSystemException(
            '  Permission denied  ', '  /tmp/avatar.png  '),
      ),
      '文件读写失败：Permission denied（/tmp/avatar.png）',
    );
    expect(
      userMessageFor(Exception('timeout while preparing request')),
      '接口请求超时，请稍后重试或调大请求超时。',
    );

    final errorSource =
        File('lib/core/app_error_messages.dart').readAsStringSync();
    final responseSource =
        File('lib/core/error_response_message.dart').readAsStringSync();
    expect(errorSource, contains('cleanFeedbackMessage(error.message)'));
    expect(errorSource, contains('cleanFeedbackMessage(error.path)'));
    expect(errorSource, isNot(contains('error.message?.trim()')));
    expect(errorSource, isNot(contains('error.message.trim()')));
    expect(responseSource, contains('cleanFeedbackMessage(error)'));
    expect(responseSource, contains('cleanFeedbackMessage(data)'));
    expect(responseSource, contains('cleanFeedbackMessage(value?.toString())'));
    expect(responseSource, contains("'code'"));
    expect(responseSource, contains("'type'"));
  });

  test('connection interruption helper normalizes transport errors', () {
    final options = RequestOptions(path: '/v1/chat/completions');

    expect(
      isConnectionInterrupted(DioException.connectionError(
        requestOptions: options,
        reason: 'Broken pipe',
      )),
      isTrue,
    );
    expect(
      isConnectionInterrupted(DioException(
        requestOptions: options,
        error: const SocketException('Connection closed before full header'),
      )),
      isTrue,
    );
    expect(isConnectionInterrupted('网络连接中断，请重试'), isTrue);
    expect(isConnectionInterrupted(Exception('plain server error')), isFalse);
  });

  test('api failure messages stay shared across validation and display', () {
    expect(
      () => validateApiConfig(APIConfig.defaults.copyWith(baseURL: 'not-url')),
      throwsA(isA<AppException>().having(
        (error) => error.message,
        'message',
        apiBaseUrlInvalidMessage,
      )),
    );
    expect(
      () => validateApiConfig(
        APIConfig.defaults.copyWith(textModelName: '  未知  '),
      ),
      throwsA(isA<AppException>().having(
        (error) => error.message,
        'message',
        textModelRequiredMessage,
      )),
    );
    expect(
      () => validateModelFetchSource(APIConfig.defaults, ''),
      throwsA(isA<AppException>().having(
        (error) => error.message,
        'message',
        apiKeyRequiredMessage,
      )),
    );
    expect(
      userMessageFor(TimeoutException('operation timed out')),
      apiRequestTimeoutMessage,
    );
    expect(
      userMessageFor(Exception('SocketException: Connection reset by peer')),
      apiConnectionInterruptedMessage,
    );
  });

  test('fetch models accepts common compatible response shapes', () async {
    final paths = <String>[];
    final headers = <Map<String, dynamic>>[];
    final dio = _fakeDio(
      paths: paths,
      headers: headers,
      responses: const [
        _FakeApiResponse(200, {
          'models': [
            {
              'id': 'deepseek-chat',
              'supported_features': ['reasoning'],
            },
            {
              'name': 'qwen2.5-vl-72b',
              'supported_capabilities': ['image_input'],
            },
            {
              'model': 'gpt-4o-mini',
              'capabilities': ['image_input', 'thinking'],
            },
            {'id': '   '},
          ],
        }),
        _FakeApiResponse(200, [
          'llama-3.1',
          {'id': 'tts-1', 'owned_by': 'openai'},
          {'name': 'gpt-3.5-turbo'},
        ]),
        _FakeApiResponse(200, {
          'items': [
            {'id': 'item-chat'},
            {'model_name': 'item-vision-vl'},
          ],
        }),
        _FakeApiResponse(200, {
          'model_list': [
            'list-chat',
            {'model': 'list-vision-vl'},
          ],
        }),
        _FakeApiResponse(200, {
          'model-list': [
            {'model_id': 'provider-chat', 'owned-by': 'compatible-provider'},
            {'model-id': 'provider-vl'},
          ],
        }),
        _FakeApiResponse(200, {
          'data': {
            'items': [
              {'id': 'nested-chat'},
              {'name': 'nested-vl'},
            ],
          },
        }),
        _FakeApiResponse(200, {
          'data': [],
          'models': [
            {'id': 'fallback-chat'},
            {'name': 'fallback-vl'},
          ],
        }),
        _FakeApiResponse(200, {
          'result': {
            'list': [
              {'id': 'result-chat'},
              {'modelName': 'result-vl'},
            ],
          },
        }),
        _FakeApiResponse(200, {
          'payload': {
            'rows': [
              {'id': 'row-chat'},
              {'model_id': 'row-vl'},
            ],
          },
        }),
        _FakeApiResponse(200, {
          'response': {
            'records': [
              {'id': 'record-chat'},
              {'name': 'record-vl'},
            ],
          },
        }),
        _FakeApiResponse(200, {
          'models': {
            'indexed-chat': {
              'owned_by': 'indexed-provider',
            },
            'indexed-vl': {
              'id': '   ',
              'capabilities': ['image_input'],
            },
            'indexed-reasoner': {
              'model': null,
              'supported_features': ['reasoning'],
            },
          },
        }),
      ],
    );
    final api = OpenAICompatibleApi(dioFactory: (_) => dio);

    final nested = await api.fetchModels(APIConfig.defaults, '  sk-test  ');
    final topLevel = await api.fetchModels(APIConfig.defaults, 'sk-test');
    final items = await api.fetchModels(APIConfig.defaults, 'sk-test');
    final modelList = await api.fetchModels(APIConfig.defaults, 'sk-test');
    final normalizedModelList =
        await api.fetchModels(APIConfig.defaults, 'sk-test');
    final nestedItems = await api.fetchModels(APIConfig.defaults, 'sk-test');
    final fallbackModels = await api.fetchModels(APIConfig.defaults, 'sk-test');
    final resultList = await api.fetchModels(APIConfig.defaults, 'sk-test');
    final payloadRows = await api.fetchModels(APIConfig.defaults, 'sk-test');
    final responseRecords =
        await api.fetchModels(APIConfig.defaults, 'sk-test');
    final indexedModels = await api.fetchModels(APIConfig.defaults, 'sk-test');

    expect(paths, [
      '/v1/models',
      '/v1/models',
      '/v1/models',
      '/v1/models',
      '/v1/models',
      '/v1/models',
      '/v1/models',
      '/v1/models',
      '/v1/models',
      '/v1/models',
      '/v1/models',
    ]);
    expect(headers.first['Authorization'], 'Bearer sk-test');
    expect(
      nested.map((model) => model.id),
      ['deepseek-chat', 'gpt-4o-mini', 'qwen2.5-vl-72b'],
    );
    expect(nested[0].capability?.isReasoning, isTrue);
    expect(nested[1].capability?.isMultimodal, isTrue);
    expect(nested[1].capability?.isReasoning, isTrue);
    expect(nested[2].capability?.isMultimodal, isTrue);
    expect(topLevel.map((model) => model.id),
        ['gpt-3.5-turbo', 'llama-3.1', 'tts-1']);
    expect(topLevel.last.ownedBy, 'openai');
    expect(topLevel.last.displayTitle, 'tts-1 · 语音');
    expect(items.map((model) => model.id), ['item-chat', 'item-vision-vl']);
    expect(
      modelList.map((model) => model.id),
      ['list-chat', 'list-vision-vl'],
    );
    expect(normalizedModelList.map((model) => model.id),
        ['provider-chat', 'provider-vl']);
    expect(normalizedModelList.first.ownedBy, 'compatible-provider');
    expect(nestedItems.map((model) => model.id), ['nested-chat', 'nested-vl']);
    expect(fallbackModels.map((model) => model.id),
        ['fallback-chat', 'fallback-vl']);
    expect(resultList.map((model) => model.id), ['result-chat', 'result-vl']);
    expect(payloadRows.map((model) => model.id), ['row-chat', 'row-vl']);
    expect(
        responseRecords.map((model) => model.id), ['record-chat', 'record-vl']);
    expect(indexedModels.map((model) => model.id),
        ['indexed-chat', 'indexed-reasoner', 'indexed-vl']);
    expect(indexedModels.first.ownedBy, 'indexed-provider');
    expect(indexedModels[1].capability?.isReasoning, isTrue);
    expect(indexedModels[2].capability?.isMultimodal, isTrue);

    final itemSource = File('lib/core/api_model_items.dart').readAsStringSync();
    expect(itemSource, contains('List<dynamic> _modelItemsFromMapEntries('));
    expect(itemSource, contains('_ensureIndexedModelId(item, id);'));
  });

  test('fetch models accepts top-level indexed model maps', () async {
    final dio = _fakeDio(
      paths: <String>[],
      responses: const [
        _FakeApiResponse(200, {
          'gpt-4o-mini': {
            'id': '   ',
            'owned_by': 'openai',
            'capabilities': ['image_input'],
          },
          'qwen-vl-plus': {
            'supported_features': ['reasoning'],
          },
          'metadata': {
            'total': 2,
          },
          'count': 2,
        }),
      ],
    );

    final models =
        await OpenAICompatibleApi(dioFactory: (_) => dio).fetchModels(
      APIConfig.defaults,
      'sk-test',
    );

    expect(models.map((model) => model.id), ['gpt-4o-mini', 'qwen-vl-plus']);
    expect(models.first.ownedBy, 'openai');
    expect(models.first.capability?.isMultimodal, isTrue);
    expect(models.last.capability?.isReasoning, isTrue);

    final itemSource = File('lib/core/api_model_items.dart').readAsStringSync();
    expect(itemSource, contains('return _modelItemsFromMapEntries(data);'));
    expect(itemSource, contains('void _ensureIndexedModelId('));
    expect(itemSource, contains('bool _looksLikeModelMapKey(String id)'));
    expect(itemSource, contains("'metadata'"));
  });

  test('fetch models sorts ids with iOS-style natural ordering', () async {
    final dio = _fakeDio(
      paths: <String>[],
      responses: const [
        _FakeApiResponse(200, {
          'data': [
            {'id': 'model-10'},
            {'id': 'Model-1'},
            {'id': 'alpha'},
            {'id': 'model-2'},
          ],
        }),
      ],
    );

    final models =
        await OpenAICompatibleApi(dioFactory: (_) => dio).fetchModels(
      APIConfig.defaults,
      'sk-test',
    );

    expect(models.map((model) => model.id),
        ['alpha', 'Model-1', 'model-2', 'model-10']);
  });

  test('fetch models maps auth failures with iOS list-specific detail',
      () async {
    final paths = <String>[];
    final dio = _fakeDio(
      paths: paths,
      responses: const [
        _FakeApiResponse(403, {
          'error': {'message': 'models scope missing'},
        }),
      ],
    );
    final api = OpenAICompatibleApi(dioFactory: (_) => dio);

    await expectLater(
      api.fetchModels(APIConfig.defaults, 'sk-test'),
      throwsA(isA<AppException>().having(
        (error) => error.message,
        'message',
        'API Key 无效或没有权限拉取模型列表，请重新生成 Key 后保存。服务端返回：models scope missing',
      )),
    );
    expect(paths, ['/v1/models']);
  });

  test('fetch models maps interrupted connections like iOS', () async {
    final paths = <String>[];
    final dio = Dio();
    dio.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) {
      paths.add(options.uri.path);
      handler.reject(DioException.connectionError(
        requestOptions: options,
        reason: 'Connection reset by peer',
      ));
    }));

    await expectLater(
      OpenAICompatibleApi(dioFactory: (_) => dio).fetchModels(
        APIConfig.defaults,
        'sk-test',
      ),
      throwsA(isA<AppException>().having(
        (error) => error.message,
        'message',
        '接口连接被中断，服务器可能已断开连接或没有返回完整响应。',
      )),
    );
    expect(paths, ['/v1/models']);
  });

  test('fetch models recommends chat and vision models automatically',
      () async {
    SharedPreferences.setMockInitialValues({});
    final app = AppController(
      api: FakeModelsApi(const [
        APIModel(id: 'text-embedding-3-large'),
        APIModel(id: 'tts-1'),
        APIModel(id: 'gpt-3.5-turbo'),
        APIModel(id: 'gpt-4o-mini'),
        APIModel(id: 'qwen2.5-vl-72b'),
      ]),
    )..apiKey = 'sk-test';

    await app.fetchModels();

    expect(app.availableModels.map((model) => model.id),
        containsAll(['gpt-4o-mini', 'qwen2.5-vl-72b']));
    expect(app.config.textModelName, 'gpt-4o-mini');
    expect(app.config.visionModelName, 'gpt-4o-mini');
    expect(app.config.capability('gpt-4o-mini').isMultimodal, isTrue);
    expect(app.config.capability('qwen2.5-vl-72b').isMultimodal, isTrue);
  });

  test('fetch models does not mark plain text models as vision-ready',
      () async {
    SharedPreferences.setMockInitialValues({});
    final app = AppController(
      api: FakeModelsApi(const [
        APIModel(id: 'gpt-3.5-turbo'),
        APIModel(id: 'text-embedding-3-large'),
      ]),
    )
      ..apiKey = 'sk-test'
      ..config = APIConfig.defaults.copyWith(
        visionModelName: 'missing-vision',
        modelCapabilities: const {},
      );

    await app.fetchModels();

    expect(app.config.textModelName, 'gpt-3.5-turbo');
    expect(app.config.visionModelName, 'missing-vision');
    expect(app.config.capability('gpt-3.5-turbo').isMultimodal, isFalse);
    expect(app.config.capability('missing-vision').isMultimodal, isFalse);
  });

  test('fetch models recommends common multimodal model ids for vision',
      () async {
    SharedPreferences.setMockInitialValues({});
    final app = AppController(
      api: FakeModelsApi(const [
        APIModel(id: 'text-only-chat'),
        APIModel(id: 'glm-4v-plus'),
        APIModel(id: 'internvl2.5'),
        APIModel(id: 'step-1v-32k'),
        APIModel(id: 'gemini-1.5-flash'),
        APIModel(id: 'llava-1.6'),
      ]),
    )
      ..apiKey = 'sk-test'
      ..config = APIConfig.defaults.copyWith(
        visionModelName: 'missing-vision',
        textModelName: 'text-only-chat',
        modelCapabilities: const {},
      );

    await app.fetchModels();

    expect(app.config.textModelName, 'text-only-chat');
    expect(app.config.visionModelName, 'gemini-1.5-flash');
    expect(app.config.capability('glm-4v-plus').isMultimodal, isTrue);
    expect(app.config.capability('internvl2.5').isMultimodal, isTrue);
    expect(app.config.capability('step-1v-32k').isMultimodal, isTrue);
    expect(app.config.capability('gemini-1.5-flash').isMultimodal, isTrue);
    expect(app.config.capability('llava-1.6').isMultimodal, isTrue);
  });

  test('fetch models uses provider-declared multimodal metadata', () async {
    SharedPreferences.setMockInitialValues({});
    const declaredVision = APIModel(
      id: 'provider-chat-pro',
      capability: ModelCapability(isMultimodal: true, isReasoning: true),
    );
    final app = AppController(
      api: FakeModelsApi(const [
        APIModel(id: 'text-only-chat'),
        declaredVision,
      ]),
    )
      ..apiKey = 'sk-test'
      ..config = APIConfig.defaults.copyWith(
        visionModelName: 'missing-vision',
        textModelName: 'text-only-chat',
        modelCapabilities: const {},
      );

    await app.fetchModels();

    expect(app.config.textModelName, 'text-only-chat');
    expect(app.config.visionModelName, 'provider-chat-pro');
    expect(app.config.capability('provider-chat-pro').isMultimodal, isTrue);
    expect(app.config.capability('provider-chat-pro').isReasoning, isTrue);
  });

  test('fetch models uses nested architecture modalities metadata', () async {
    SharedPreferences.setMockInitialValues({});
    final paths = <String>[];
    final dio = _fakeDio(
      paths: paths,
      responses: const [
        _FakeApiResponse(200, {
          'data': [
            {'id': 'provider-basic-chat'},
            {
              'id': 'provider-sonnet-chat',
              'architecture': {
                'input_modalities': ['text', 'image'],
                'modality': 'text+image->text',
              },
            },
            {
              'id': 'provider-reasoner',
              'metadata': {
                'features': ['reasoning'],
              },
            },
            {
              'model_name': 'provider-top-input',
              'input': ['text', 'image'],
            },
            {
              'id': 'provider-supported-inputs',
              'supported_inputs': ['text', 'vision', 'reasoning'],
            },
            {
              'id': 'provider-split-metadata',
              'supported_inputs': ['text', 'image'],
              'features': ['reasoning'],
            },
            {
              'id': 'provider-capability-flags',
              'capability_flags': ['thinking'],
            },
          ],
        }),
      ],
    );
    final app = AppController(api: OpenAICompatibleApi(dioFactory: (_) => dio))
      ..apiKey = 'sk-test'
      ..config = APIConfig.defaults.copyWith(
        visionModelName: 'missing-vision',
        textModelName: 'provider-basic-chat',
        modelCapabilities: const {},
      );

    await app.fetchModels();

    expect(paths, ['/v1/models']);
    expect(app.config.textModelName, 'provider-basic-chat');
    expect(app.config.visionModelName, 'provider-sonnet-chat');
    expect(app.config.capability('provider-sonnet-chat').isMultimodal, isTrue);
    expect(app.config.capability('provider-reasoner').isReasoning, isTrue);
    expect(app.config.capability('provider-top-input').isMultimodal, isTrue);
    expect(app.config.capability('provider-supported-inputs').isMultimodal,
        isTrue);
    expect(
        app.config.capability('provider-supported-inputs').isReasoning, isTrue);
    expect(
        app.config.capability('provider-split-metadata').isMultimodal, isTrue);
    expect(
        app.config.capability('provider-split-metadata').isReasoning, isTrue);
    expect(
        app.config.capability('provider-capability-flags').isReasoning, isTrue);
  });

  test('fetch models uses map-shaped modalities metadata', () async {
    SharedPreferences.setMockInitialValues({});
    final paths = <String>[];
    final dio = _fakeDio(
      paths: paths,
      responses: const [
        _FakeApiResponse(200, {
          'data': [
            {'id': 'provider-basic-chat'},
            {
              'id': 'provider-map-vision',
              'modalities': {
                'input': ['text', 'image'],
                'output': ['text'],
              },
            },
          ],
        }),
      ],
    );
    final app = AppController(api: OpenAICompatibleApi(dioFactory: (_) => dio))
      ..apiKey = 'sk-test'
      ..config = APIConfig.defaults.copyWith(
        visionModelName: 'missing-vision',
        textModelName: 'provider-basic-chat',
        modelCapabilities: const {},
      );

    await app.fetchModels();

    expect(paths, ['/v1/models']);
    expect(app.config.textModelName, 'provider-basic-chat');
    expect(app.config.visionModelName, 'provider-map-vision');
    expect(app.config.capability('provider-map-vision').isMultimodal, isTrue);
  });

  test('fetch models keeps manually selected models with normalized ids',
      () async {
    SharedPreferences.setMockInitialValues({});
    final app = AppController(
      api: FakeModelsApi(const [
        APIModel(id: 'GPT-4O-MINI'),
        APIModel(id: 'QWEN2.5-VL-72B'),
        APIModel(id: 'gemini-1.5-flash'),
      ]),
    )
      ..apiKey = 'sk-test'
      ..config = APIConfig.defaults.copyWith(
        textModelName: ' gpt-4o-mini ',
        visionModelName: ' qwen2.5-vl-72b ',
        modelCapabilities: const {
          ' qwen2.5-vl-72b ': ModelCapability(isMultimodal: true),
        },
      );

    await app.fetchModels();

    expect(app.config.textModelName, 'GPT-4O-MINI');
    expect(app.config.visionModelName, 'QWEN2.5-VL-72B');
    expect(app.config.capability('QWEN2.5-VL-72B').isMultimodal, isTrue);
    expect(app.config.capability('gemini-1.5-flash').isMultimodal, isTrue);
  });

  test('fetch models trims provider model ids before saving recommendations',
      () async {
    SharedPreferences.setMockInitialValues({});
    final app = AppController(
      api: FakeModelsApi(const [
        APIModel(id: ' GPT-4O-MINI '),
        APIModel(id: ' qwen2.5-vl-72b '),
      ]),
    )
      ..apiKey = 'sk-test'
      ..config = APIConfig.defaults.copyWith(
        textModelName: 'missing-text',
        visionModelName: 'missing-vision',
        modelCapabilities: const {},
      );

    await app.fetchModels();

    expect(app.config.textModelName, 'GPT-4O-MINI');
    expect(app.config.visionModelName, 'GPT-4O-MINI');
    expect(app.config.capability(' GPT-4O-MINI ').isMultimodal, isTrue);
    expect(
      app.config.modelCapabilities.keys.any((key) => key != key.trim()),
      isFalse,
    );
  });

  test('fetch models normalizes available models at controller boundary',
      () async {
    SharedPreferences.setMockInitialValues({});
    final app = AppController(
      api: FakeModelsApi(const [
        APIModel(id: ' qwen2.5-vl-72b ', ownedBy: '  Provider  '),
        APIModel(id: '   '),
        APIModel(id: 'GPT-4O-MINI'),
        APIModel(
          id: ' gpt-4o-mini ',
          capability: ModelCapability(isMultimodal: true, isReasoning: true),
        ),
      ]),
    )
      ..apiKey = 'sk-test'
      ..config = APIConfig.defaults.copyWith(
        textModelName: 'missing-text',
        visionModelName: 'missing-vision',
        modelCapabilities: const {},
      );

    await app.fetchModels();

    expect(app.availableModels.map((model) => model.id),
        ['GPT-4O-MINI', 'qwen2.5-vl-72b']);
    expect(app.availableModels.first.capability?.isMultimodal, isTrue);
    expect(app.availableModels.first.capability?.isReasoning, isTrue);
    expect(app.availableModels.last.ownedBy, 'Provider');
    expect(app.config.textModelName, 'GPT-4O-MINI');
    expect(app.config.visionModelName, 'GPT-4O-MINI');
    expect(app.statusMessage, contains('已拉取 2 个模型'));
  });

  test('fetch models cleans placeholder base model metadata before saving',
      () async {
    SharedPreferences.setMockInitialValues({});
    final app = AppController(
      api: FakeModelsApi(const [
        APIModel(id: 'gpt-4o-mini'),
      ]),
    )
      ..apiKey = 'sk-test'
      ..config = APIConfig.defaults.copyWith(
        textModelName: '  未知  ',
        visionModelName: '  未知  ',
        modelCapabilities: const {
          ' 未知 ': ModelCapability(isMultimodal: true),
          ' gpt-4o-mini ': ModelCapability(isReasoning: true),
        },
      );

    await app.fetchModels();

    expect(app.config.textModelName, 'gpt-4o-mini');
    expect(app.config.visionModelName, 'gpt-4o-mini');
    expect(app.config.modelCapabilities.keys, ['gpt-4o-mini']);
    expect(app.config.capability('gpt-4o-mini').isMultimodal, isTrue);
    expect(app.config.capability('gpt-4o-mini').isReasoning, isTrue);
  });

  test(
      'fetch models clears non-chat vision markers without losing manual vision',
      () async {
    SharedPreferences.setMockInitialValues({});
    final oldBadConfig = APIConfig.defaults.copyWith(
      visionModelName: 'omni-moderation-latest',
      textModelName: 'manual-chat-model',
      modelCapabilities: const {
        ' OMNI-MODERATION-LATEST ': ModelCapability(isMultimodal: true),
      },
    );
    final app = AppController(
      api: FakeModelsApi(const [
        APIModel(id: 'manual-chat-model'),
        APIModel(id: 'omni-moderation-latest'),
        APIModel(id: 'gemini-1.5-flash'),
      ]),
    )
      ..apiKey = 'sk-test'
      ..config = oldBadConfig;

    await app.fetchModels();

    expect(app.config.textModelName, 'manual-chat-model');
    expect(app.config.visionModelName, 'gemini-1.5-flash');
    expect(
      app.config.capability('omni-moderation-latest').isMultimodal,
      isFalse,
    );
    expect(
      app.config.modelCapabilities.keys
          .where((key) => key.trim().toLowerCase() == 'omni-moderation-latest')
          .toList(),
      ['omni-moderation-latest'],
    );
    expect(app.config.capability('gemini-1.5-flash').isMultimodal, isTrue);

    final manual = AppController(
      api: FakeModelsApi(const [
        APIModel(id: 'manual-chat-model'),
        APIModel(id: 'custom-visual-chat'),
      ]),
    )
      ..apiKey = 'sk-test'
      ..config = APIConfig.defaults.copyWith(
        visionModelName: 'custom-visual-chat',
        textModelName: 'manual-chat-model',
        modelCapabilities: const {
          'custom-visual-chat': ModelCapability(isMultimodal: true),
        },
      );

    await manual.fetchModels();

    expect(manual.config.visionModelName, 'custom-visual-chat');
    expect(manual.config.capability('custom-visual-chat').isMultimodal, isTrue);
  });

  test('fetch models does not recommend non-chat models for text', () async {
    SharedPreferences.setMockInitialValues({});
    final app = AppController(
      api: FakeModelsApi(const [
        APIModel(id: 'text-embedding-3-large'),
        APIModel(id: 'whisper-1'),
        APIModel(id: 'omni-moderation-latest'),
        APIModel(id: 'omni-safety-classifier'),
        APIModel(id: 'gpt-image-1'),
        APIModel(id: 'dall-e-3'),
        APIModel(id: 'sora-2'),
      ]),
    )
      ..apiKey = 'sk-test'
      ..config = APIConfig.defaults.copyWith(
        textModelName: 'manual-chat-model',
        visionModelName: 'missing-vision',
        modelCapabilities: const {},
      );

    await app.fetchModels();

    expect(
        app.availableModels.map((model) => model.displayTitle),
        containsAll([
          'dall-e-3 · 非聊天',
          'gpt-image-1 · 非聊天',
          'omni-moderation-latest · 非聊天',
          'omni-safety-classifier · 非聊天',
          'sora-2 · 非聊天',
          'text-embedding-3-large · 非聊天',
          'whisper-1 · 语音',
        ]));
    expect(app.config.textModelName, 'manual-chat-model');
    expect(app.config.visionModelName, 'missing-vision');
    expect(
        app.config.capability('text-embedding-3-large').isMultimodal, isFalse);
    expect(
        app.config.capability('omni-moderation-latest').isMultimodal, isFalse);
    expect(
        app.config.capability('omni-moderation-latest').isReasoning, isFalse);
    expect(
        app.config.capability('omni-safety-classifier').isMultimodal, isFalse);
    expect(
        app.config.capability('omni-safety-classifier').isReasoning, isFalse);
    expect(app.config.capability('gpt-image-1').isMultimodal, isFalse);
    expect(app.config.capability('sora-2').isMultimodal, isFalse);
  });

  test('fetch models for draft recommends without saving settings or key',
      () async {
    SharedPreferences.setMockInitialValues({});
    final store = FakeStore();
    final api = FakeModelsApi(const [
      APIModel(id: 'gpt-4o-mini'),
      APIModel(id: 'qwen2.5-vl-72b'),
    ]);
    final app = AppController(
      store: store,
      api: api,
    );
    final draft = APIConfig.defaults.copyWith(
      baseURL: 'https://proxy.example/v1',
      visionModelName: 'missing-vision',
      textModelName: 'missing-text',
      modelCapabilities: const {},
    );

    final recommended = await app.fetchModelsForDraft(draft, '  sk-test  ');

    expect(app.apiKey, isEmpty);
    expect(app.config.baseURL, APIConfig.defaults.baseURL);
    expect(store.savedAPIKey, isEmpty);
    expect(store.savedConfig!.baseURL, APIConfig.defaults.baseURL);
    expect(app.errorMessage, isNull);
    expect(app.availableModels.map((model) => model.id),
        containsAll(['gpt-4o-mini', 'qwen2.5-vl-72b']));
    expect(api.lastAPIKey, 'sk-test');
    expect(recommended?.baseURL, 'https://proxy.example/v1');
    expect(recommended?.textModelName, isNot('missing-text'));
    expect(recommended?.visionModelName, isNot('missing-vision'));
    expect(recommended?.capability('qwen2.5-vl-72b').isMultimodal, isTrue);
  });

  test('fetch models for draft can recover blank model names like iOS',
      () async {
    SharedPreferences.setMockInitialValues({});
    final app = AppController(
      api: FakeModelsApi(const [
        APIModel(id: 'gpt-4o-mini'),
        APIModel(id: 'qwen2.5-vl-72b'),
      ]),
    );
    final draft = APIConfig.defaults.copyWith(
      visionModelName: '',
      textModelName: '',
      modelCapabilities: const {},
    );

    final recommended = await app.fetchModelsForDraft(draft, 'sk-test');

    expect(app.errorMessage, isNull);
    expect(recommended?.textModelName, 'gpt-4o-mini');
    expect(recommended?.visionModelName, 'gpt-4o-mini');
    expect(recommended?.capability('gpt-4o-mini').isMultimodal, isTrue);
  });

  test('fetch models for draft requires api key', () async {
    SharedPreferences.setMockInitialValues({});
    final app = AppController(api: FakeModelsApi(const []));

    await app.fetchModelsForDraft(APIConfig.defaults, '   ');

    expect(app.availableModels, isEmpty);
    expect(app.errorMessage, contains('API Key'));
  });

  test('saved model fetch requires api key before API call', () async {
    SharedPreferences.setMockInitialValues({});
    final api = SequencedModelsApi();
    final app = AppController(api: api)
      ..apiKey = '   '
      ..availableModels = const [APIModel(id: 'old-model')];

    await app.fetchModels();

    expect(api.completers, isEmpty);
    expect(app.availableModels, isEmpty);
    expect(app.isFetchingModels, isFalse);
    expect(app.statusMessage, isNull);
    expect(app.errorMessage, contains('API Key'));
  });

  test('invalid draft model fetch clears loading and ignores older result',
      () async {
    SharedPreferences.setMockInitialValues({});
    final api = DeferredModelsApi();
    final app = AppController(api: api);

    final pending = app.fetchModelsForDraft(APIConfig.defaults, 'sk-test');
    expect(app.isFetchingModels, isTrue);

    final invalid = await app.fetchModelsForDraft(APIConfig.defaults, '   ');

    expect(invalid, isNull);
    expect(app.isFetchingModels, isFalse);
    expect(app.errorMessage, contains('API Key'));

    api.completer.complete(const [APIModel(id: 'gpt-4o-mini')]);
    final stale = await pending;

    expect(stale, isNull);
    expect(app.availableModels, isEmpty);
    expect(app.isFetchingModels, isFalse);
  });

  test('stale model fetch result is ignored when config changes', () async {
    SharedPreferences.setMockInitialValues({});
    final api = DeferredModelsApi();
    final app = AppController(api: api)..apiKey = 'sk-test';

    final pending = app.fetchModels();
    app.config = app.config.copyWith(baseURL: 'https://example.com/v1');
    api.completer.complete(const [APIModel(id: 'gpt-4o-mini')]);
    await pending;

    expect(app.availableModels, isEmpty);
    expect(app.statusMessage, isNull);
  });

  test('stale model fetch failure cannot overwrite newer settings', () async {
    SharedPreferences.setMockInitialValues({});
    final api = DeferredModelsApi();
    final app = AppController(api: api)..apiKey = 'sk-test';

    final pending = app.fetchModels();
    app.config = app.config.copyWith(baseURL: 'https://example.com/v1');
    app.statusMessage = '新配置已保存';
    api.completer.completeError(AppException('旧模型拉取失败'));
    await pending;

    expect(app.availableModels, isEmpty);
    expect(app.errorMessage, isNull);
    expect(app.statusMessage, '新配置已保存');
    expect(app.isFetchingModels, isFalse);
  });

  test('stale model recommendation save cannot recreate data after clear all',
      () async {
    SharedPreferences.setMockInitialValues({});
    final store = DeferredPreferenceStore()..delayConfigSave = true;
    final api = DeferredModelsApi();
    final app = AppController(store: store, api: api)
      ..config = APIConfig.defaults.copyWith(
        baseURL: 'https://models.example/v1',
        textModelName: '',
      )
      ..apiKey = 'sk-old';

    final pending = app.fetchModels();
    expect(app.isFetchingModels, isTrue);

    api.completer.complete(const [APIModel(id: 'gpt-4o-mini')]);
    await store.configStarted.future;
    await app.clearAllLocalData();
    store.configRelease.complete();
    await pending;

    expect(app.isFetchingModels, isFalse);
    expect(app.config, APIConfig.defaults);
    expect(app.apiKey, isEmpty);
    expect(app.availableModels, isEmpty);
    expect(store.savedConfig, isNull);
    expect(store.savedAPIKey, isEmpty);
    expect(store.didClearAll, isTrue);
    expect(app.statusMessage, '本地数据已清空，API 配置已恢复默认。');
  });

  test(
      'stale model recommendation save cannot overwrite newer settings feedback',
      () async {
    SharedPreferences.setMockInitialValues({});
    final store = DeferredPreferenceStore()..delayConfigSave = true;
    final api = DeferredModelsApi();
    final app = AppController(store: store, api: api)
      ..config = APIConfig.defaults.copyWith(
        baseURL: 'https://models.example/v1',
        textModelName: '',
      )
      ..apiKey = 'sk-old';

    final pending = app.fetchModels();
    expect(app.isFetchingModels, isTrue);

    api.completer.complete(const [APIModel(id: 'gpt-4o-mini')]);
    await store.configStarted.future;

    await app.saveConfig(
      APIConfig.defaults.copyWith(
        baseURL: 'https://new.example/v1',
        textModelName: 'manual-model',
        visionModelName: 'manual-vision',
      ),
      'sk-new',
    );
    expect(app.statusMessage, '配置已保存');

    store.configRelease.complete();
    await pending;

    expect(app.isFetchingModels, isFalse);
    expect(app.config.baseURL, 'https://new.example/v1');
    expect(app.apiKey, 'sk-new');
    expect(store.savedConfig!.baseURL, 'https://new.example/v1');
    expect(store.savedAPIKey, 'sk-new');
    expect(app.statusMessage, '配置已保存');
  });

  test('stale saved model fetch cannot clear newer draft loading', () async {
    SharedPreferences.setMockInitialValues({});
    final api = SequencedModelsApi();
    final app = AppController(api: api)..apiKey = 'sk-test';

    final oldFetch = app.fetchModels();
    expect(api.completers, hasLength(1));
    expect(app.isFetchingModels, isTrue);

    final draftFetch = app.fetchModelsForDraft(
      APIConfig.defaults.copyWith(baseURL: 'https://draft.example/v1'),
      'sk-draft',
    );
    expect(api.completers, hasLength(2));

    api.completers.first.complete(const [APIModel(id: 'old-model')]);
    await Future<void>.delayed(Duration.zero);

    expect(app.isFetchingModels, isTrue);
    expect(app.availableModels, isEmpty);

    api.completers.last.complete(const [APIModel(id: 'gpt-4o-mini')]);
    final recommended = await draftFetch;
    await oldFetch;

    expect(app.isFetchingModels, isFalse);
    expect(app.availableModels.map((model) => model.id), ['gpt-4o-mini']);
    expect(recommended?.textModelName, 'gpt-4o-mini');
    expect(app.statusMessage, contains('已拉取 1 个模型'));
  });

  test('model fetch operations share lifecycle helpers', () {
    final runtimeSource =
        File('lib/core/app_state_runtime_helpers.dart').readAsStringSync();
    final modelFetchingSource =
        File('lib/core/app_state_model_fetching.dart').readAsStringSync();

    expect(runtimeSource, contains('int _beginModelFetchOperation()'));
    expect(runtimeSource, contains('bool _isCurrentModelFetchOperation('));
    expect(runtimeSource, contains('void _finishModelFetchOperation('));
    expect(
      RegExp(r'_beginModelFetchOperation\(\)')
          .allMatches(modelFetchingSource)
          .length,
      2,
    );
    expect(
      RegExp(r'_finishModelFetchOperation\(requestGeneration')
          .allMatches(modelFetchingSource)
          .length,
      3,
    );
    expect(modelFetchingSource,
        contains('_isCurrentModelFetchOperation(requestGeneration)'));
    expect(modelFetchingSource, isNot(contains('++_modelFetchGeneration')));
    expect(modelFetchingSource, isNot(contains('isFetchingModels = true')));
    expect(modelFetchingSource, isNot(contains('isFetchingModels = false')));
  });

  test('stale connection test result cannot restore a cleared api key',
      () async {
    SharedPreferences.setMockInitialValues({});
    final store = FakeStore();
    final api = DeferredConnectionApi();
    final app = AppController(store: store, api: api)
      ..config = APIConfig.defaults.copyWith(baseURL: 'https://old.example/v1')
      ..apiKey = 'sk-old';
    final draft =
        APIConfig.defaults.copyWith(baseURL: 'https://new.example/v1');

    final pending = app.testConnection(draft, 'sk-new');
    expect(app.isTestingConnection, isTrue);
    expect(api.connectionKey, 'sk-new');

    await app.clearAPIKey();
    api.connectionCompleter.complete();
    await pending;

    expect(app.isTestingConnection, isFalse);
    expect(app.apiKey, isEmpty);
    expect(store.savedAPIKey, isEmpty);
    expect(app.config.baseURL, 'https://old.example/v1');
    expect(store.savedConfig!.baseURL, APIConfig.defaults.baseURL);
    expect(app.statusMessage, 'API Key 已清除，其他配置已保留');
  });

  test('stale connection test save cannot recreate data after clear all',
      () async {
    SharedPreferences.setMockInitialValues({});
    final store = DeferredPreferenceStore()..delayConfigSave = true;
    final api = DeferredConnectionApi();
    final app = AppController(store: store, api: api)
      ..config = APIConfig.defaults.copyWith(baseURL: 'https://old.example/v1')
      ..apiKey = 'sk-old';
    final draft =
        APIConfig.defaults.copyWith(baseURL: 'https://new.example/v1');

    final pending = app.testConnection(draft, 'sk-new');
    expect(app.isTestingConnection, isTrue);

    api.connectionCompleter.complete();
    await store.configStarted.future;
    await app.clearAllLocalData();
    store.configRelease.complete();
    await pending;

    expect(app.isTestingConnection, isFalse);
    expect(app.config, APIConfig.defaults);
    expect(app.apiKey, isEmpty);
    expect(store.savedConfig, isNull);
    expect(store.savedAPIKey, isEmpty);
    expect(store.didClearAll, isTrue);
    expect(app.statusMessage, '本地数据已清空，API 配置已恢复默认。');
  });

  test('stale connection test failure cannot overwrite api key clear',
      () async {
    SharedPreferences.setMockInitialValues({});
    final api = DeferredConnectionApi();
    final app = AppController(api: api)
      ..config = APIConfig.defaults.copyWith(baseURL: 'https://old.example/v1')
      ..apiKey = 'sk-old';
    final draft =
        APIConfig.defaults.copyWith(baseURL: 'https://new.example/v1');

    final pending = app.testConnection(draft, 'sk-new');
    expect(app.isTestingConnection, isTrue);

    await app.clearAPIKey();
    api.connectionCompleter.completeError(AppException('旧连接失败'));
    await pending;

    expect(app.isTestingConnection, isFalse);
    expect(app.apiKey, isEmpty);
    expect(app.errorMessage, isNull);
    expect(app.statusMessage, 'API Key 已清除，其他配置已保留');
  });

  test('stale connection test cannot clear newer connection loading', () async {
    SharedPreferences.setMockInitialValues({});
    final store = FakeStore();
    final api = SequencedSettingsTestApi();
    final app = AppController(store: store, api: api)
      ..config = APIConfig.defaults.copyWith(baseURL: 'https://old.example/v1')
      ..apiKey = 'sk-old';
    final firstDraft =
        APIConfig.defaults.copyWith(baseURL: 'https://first.example/v1');
    final secondDraft =
        APIConfig.defaults.copyWith(baseURL: 'https://second.example/v1');

    final first = app.testConnection(firstDraft, 'sk-first');
    expect(api.connectionCompleters, hasLength(1));
    expect(app.isTestingConnection, isTrue);

    await app.clearAPIKey();
    final second = app.testConnection(secondDraft, 'sk-second');
    expect(api.connectionCompleters, hasLength(2));
    expect(app.isTestingConnection, isTrue);

    api.connectionCompleters.first.complete();
    await first;

    expect(app.isTestingConnection, isTrue);
    expect(app.config.baseURL, 'https://old.example/v1');
    expect(app.apiKey, isEmpty);
    expect(app.statusMessage, isNull);

    api.connectionCompleters.last.complete();
    await second;

    expect(app.isTestingConnection, isFalse);
    expect(app.config.baseURL, 'https://second.example/v1');
    expect(app.apiKey, 'sk-second');
    expect(store.savedConfig!.baseURL, 'https://second.example/v1');
    expect(store.savedAPIKey, 'sk-second');
    expect(app.statusMessage, '连接测试成功，配置已保存');
  });

  test('busy settings tests ignore duplicate controller submissions', () async {
    SharedPreferences.setMockInitialValues({});
    final api = SequencedSettingsTestApi();
    final app = AppController(api: api);
    final draft = APIConfig.defaults.copyWith(
      baseURL: 'https://settings.example/v1',
      visionModelName: 'gpt-4o-mini',
      modelCapabilities: const {
        'gpt-4o-mini': ModelCapability(isMultimodal: true),
      },
    );

    final first = app.testConnection(draft, 'sk-first');
    expect(api.connectionCompleters, hasLength(1));
    expect(app.isTestingConnection, isTrue);

    await app.testConnection(draft, 'sk-second');
    await app.testVisionConnection(draft, 'sk-vision');

    expect(api.connectionCompleters, hasLength(1));
    expect(api.connectionKeys, ['sk-first']);
    expect(api.visionCompleters, isEmpty);
    expect(app.isTestingConnection, isTrue);
    expect(app.isTestingVision, isFalse);

    api.connectionCompleters.single.complete();
    await first;

    expect(app.isTestingConnection, isFalse);
    expect(app.config.baseURL, 'https://settings.example/v1');
    expect(app.apiKey, 'sk-first');
    expect(app.statusMessage, '连接测试成功，配置已保存');
  });

  test('model fetching blocks settings tests at controller boundary', () async {
    SharedPreferences.setMockInitialValues({});
    final api = SequencedSettingsTestApi();
    final app = AppController(api: api)..isFetchingModels = true;
    final draft = APIConfig.defaults.copyWith(
      baseURL: 'https://settings.example/v1',
      visionModelName: 'gpt-4o-mini',
      modelCapabilities: const {
        'gpt-4o-mini': ModelCapability(isMultimodal: true),
      },
    );

    await app.testConnection(draft, 'sk-connection');
    await app.testVisionConnection(draft, 'sk-vision');

    expect(api.connectionCompleters, isEmpty);
    expect(api.visionCompleters, isEmpty);
    expect(app.isFetchingModels, isTrue);
    expect(app.isTestingConnection, isFalse);
    expect(app.isTestingVision, isFalse);
    expect(app.statusMessage, isNull);
    expect(app.errorMessage, isNull);
  });

  test('connection test allows text-only mode without a vision model',
      () async {
    SharedPreferences.setMockInitialValues({});
    final store = FakeStore();
    final api = DeferredConnectionApi();
    final app = AppController(store: store, api: api);
    final textOnlyDraft = APIConfig.defaults.copyWith(
      baseURL: 'https://text.example/v1',
      enableImageInput: false,
      visionModelName: '',
      textModelName: 'text-chat',
    );

    final pending = app.testConnection(textOnlyDraft, ' sk-text ');
    expect(app.isTestingConnection, isTrue);
    expect(api.connectionConfig?.enableImageInput, isFalse);
    expect(api.connectionConfig?.visionModelName, isEmpty);
    expect(api.connectionConfig?.textModelName, 'text-chat');
    expect(api.connectionKey, 'sk-text');

    api.connectionCompleter.complete();
    await pending;

    expect(app.isTestingConnection, isFalse);
    expect(app.config.enableImageInput, isFalse);
    expect(app.config.visionModelName, isEmpty);
    expect(app.config.textModelName, 'text-chat');
    expect(app.apiKey, 'sk-text');
    expect(store.savedConfig!.visionModelName, isEmpty);
    expect(store.savedAPIKey, 'sk-text');
    expect(app.statusMessage, '连接测试成功，配置已保存');
    expect(app.errorMessage, isNull);
  });

  test('settings connection tests share successful apply helper', () {
    final source = File('lib/core/app_state_api_tests.dart').readAsStringSync();
    final runtimeSource =
        File('lib/core/app_state_runtime_helpers.dart').readAsStringSync();
    final settingsSource =
        File('lib/core/app_state_api_settings.dart').readAsStringSync();
    final modelFetchingSource =
        File('lib/core/app_state_model_fetching.dart').readAsStringSync();

    expect(source, contains('Future<bool> _applySuccessfulSettingsTest({'));
    expect(runtimeSource, contains('int _beginSettingsMutation()'));
    expect(runtimeSource, contains('int _captureSettingsRevision()'));
    expect(runtimeSource, contains('bool _isCurrentSettingsRevision('));
    expect(runtimeSource, contains('int _captureLocalDataClearRevision()'));
    expect(runtimeSource, contains('bool _isCurrentLocalDataClearRevision('));
    expect(
      RegExp(r'final didApply = await _applySuccessfulSettingsTest')
          .allMatches(source)
          .length,
      2,
    );
    expect(source, contains('final saveRevision = _beginSettingsMutation();'));
    expect(
        source,
        contains(
            'final saveClearRevision = _captureLocalDataClearRevision();'));
    expect(source, contains('return _persistCurrentSettingsForRevision('));
    expect(settingsSource,
        contains('Future<bool> _persistCurrentSettingsForRevision({'));
    expect(
      RegExp(r'final requestRevision = _beginSettingsMutation\(\);')
          .allMatches(settingsSource)
          .length,
      3,
    );
    expect(
      RegExp(r'_persistCurrentSettingsForRevision\(')
          .allMatches(settingsSource)
          .length,
      3,
    );
    expect(settingsSource, contains('await _clearPersistedSettings();'));
    expect(settingsSource, contains('_isCurrentSettingsRevision('));
    expect(settingsSource, contains('_captureLocalDataClearRevision();'));
    expect(settingsSource, contains('_isCurrentLocalDataClearRevision('));
    expect(
        modelFetchingSource,
        contains(
            'final didPersist = await _persistCurrentSettingsForRevision('));
    expect(modelFetchingSource,
        contains('final saveRevision = _beginSettingsMutation();'));
    expect(
        modelFetchingSource,
        contains(
            'final saveClearRevision = _captureLocalDataClearRevision();'));
    expect(modelFetchingSource,
        isNot(contains('await _store.saveConfig(config);')));
    expect(settingsSource, isNot(contains('_localDataClearRevision')));
    expect(source, isNot(contains('_localDataClearRevision')));
    expect(modelFetchingSource, isNot(contains('_localDataClearRevision')));
  });

  test('settings connection tests share lifecycle helpers', () {
    final runtimeSource =
        File('lib/core/app_state_runtime_helpers.dart').readAsStringSync();
    final source = File('lib/core/app_state_api_tests.dart').readAsStringSync();

    for (final helper in const [
      '_beginConnectionTestOperation',
      '_isCurrentConnectionTestOperation',
      '_finishConnectionTestOperation',
      '_beginVisionTestOperation',
      '_isCurrentVisionTestOperation',
      '_finishVisionTestOperation',
    ]) {
      expect(runtimeSource, contains(helper));
      expect(source, contains(helper));
    }

    expect(source, contains('_captureSettingsRevision();'));
    expect(source, contains('_isCurrentSettingsRevision('));
    expect(source, contains('bool get _isSettingsTestBusy'));
    expect(source, contains('if (_isSettingsTestBusy) return;'));
    expect(source, isNot(contains('= _settingsRevision')));
    expect(source, isNot(contains('== _settingsRevision')));
    expect(source, isNot(contains('!= _settingsRevision')));
    expect(source, isNot(contains('++_connectionTestGeneration')));
    expect(source, isNot(contains('++_visionTestGeneration')));
    expect(source, isNot(contains('isTestingConnection = true')));
    expect(source, isNot(contains('isTestingConnection = false')));
    expect(source, isNot(contains('isTestingVision = true')));
    expect(source, isNot(contains('isTestingVision = false')));
  });

  test('vision test still requires a vision model in screenshot mode',
      () async {
    SharedPreferences.setMockInitialValues({});
    final api = DeferredConnectionApi();
    final app = AppController(api: api);
    final draft = APIConfig.defaults.copyWith(
      enableImageInput: true,
      visionModelName: '',
      textModelName: 'text-chat',
    );

    await app.testVisionConnection(draft, 'sk-test');

    expect(api.visionConfig, isNull);
    expect(app.isTestingVision, isFalse);
    expect(app.errorMessage, '视觉模型测试失败：视觉模型名称不能为空。');

    final testSource =
        File('lib/core/app_state_api_tests.dart').readAsStringSync();
    final rulesSource =
        File('lib/core/api_config_rules.dart').readAsStringSync();
    expect(testSource, contains('validateVisionTestConfig(normalized);'));
    expect(
      testSource,
      isNot(contains('normalized.visionModelName.trim().isEmpty')),
    );
    expect(
      testSource,
      isNot(contains('isUsableVisionChatModelId(normalized.visionModelName)')),
    );
    expect(rulesSource,
        contains('void validateVisionTestConfig(APIConfig config)'));
    expect(
      rulesSource,
      contains(
          'final visionModelName = cleanPresentationText(config.visionModelName);'),
    );
  });

  test('stale vision test result cannot overwrite clear all local data',
      () async {
    SharedPreferences.setMockInitialValues({});
    final store = FakeStore();
    final api = DeferredConnectionApi();
    final app = AppController(store: store, api: api)
      ..config = APIConfig.defaults.copyWith(baseURL: 'https://old.example/v1')
      ..apiKey = 'sk-old'
      ..availableModels = const [APIModel(id: 'old-model')];
    final draft = APIConfig.defaults.copyWith(
      baseURL: 'https://vision.example/v1',
      visionModelName: 'gpt-4o-mini',
      modelCapabilities: const {
        'gpt-4o-mini': ModelCapability(isMultimodal: true),
      },
    );

    final pending = app.testVisionConnection(draft, 'sk-vision');
    expect(app.isTestingVision, isTrue);
    expect(api.visionKey, 'sk-vision');

    await app.clearAllLocalData();
    api.visionCompleter.complete();
    await pending;

    expect(app.isTestingVision, isFalse);
    expect(app.config, APIConfig.defaults);
    expect(app.apiKey, isEmpty);
    expect(app.availableModels, isEmpty);
    expect(store.didClearAll, isTrue);
    expect(store.savedAPIKey, isEmpty);
    expect(app.statusMessage, '本地数据已清空，API 配置已恢复默认。');
  });

  test('stale vision test save cannot recreate data after clear all', () async {
    SharedPreferences.setMockInitialValues({});
    final store = DeferredPreferenceStore()..delayConfigSave = true;
    final api = DeferredConnectionApi();
    final app = AppController(store: store, api: api)
      ..config = APIConfig.defaults.copyWith(baseURL: 'https://old.example/v1')
      ..apiKey = 'sk-old';
    final draft = APIConfig.defaults.copyWith(
      baseURL: 'https://vision.example/v1',
      visionModelName: 'gpt-4o-mini',
      modelCapabilities: const {
        'gpt-4o-mini': ModelCapability(isMultimodal: true),
      },
    );

    final pending = app.testVisionConnection(draft, 'sk-vision');
    expect(app.isTestingVision, isTrue);

    api.visionCompleter.complete();
    await store.configStarted.future;
    await app.clearAllLocalData();
    store.configRelease.complete();
    await pending;

    expect(app.isTestingVision, isFalse);
    expect(app.config, APIConfig.defaults);
    expect(app.apiKey, isEmpty);
    expect(store.savedConfig, isNull);
    expect(store.savedAPIKey, isEmpty);
    expect(store.didClearAll, isTrue);
    expect(app.statusMessage, '本地数据已清空，API 配置已恢复默认。');
  });

  test('stale vision test failure cannot overwrite clear all local data',
      () async {
    SharedPreferences.setMockInitialValues({});
    final api = DeferredConnectionApi();
    final app = AppController(api: api)
      ..config = APIConfig.defaults.copyWith(baseURL: 'https://old.example/v1')
      ..apiKey = 'sk-old';
    final draft = APIConfig.defaults.copyWith(
      baseURL: 'https://vision.example/v1',
      visionModelName: 'gpt-4o-mini',
      modelCapabilities: const {
        'gpt-4o-mini': ModelCapability(isMultimodal: true),
      },
    );

    final pending = app.testVisionConnection(draft, 'sk-vision');
    expect(app.isTestingVision, isTrue);

    await app.clearAllLocalData();
    api.visionCompleter.completeError(AppException('旧视觉测试失败'));
    await pending;

    expect(app.isTestingVision, isFalse);
    expect(app.config, APIConfig.defaults);
    expect(app.apiKey, isEmpty);
    expect(app.errorMessage, isNull);
    expect(app.statusMessage, '本地数据已清空，API 配置已恢复默认。');
  });

  test('stale vision test cannot clear newer vision loading', () async {
    SharedPreferences.setMockInitialValues({});
    final store = FakeStore();
    final api = SequencedSettingsTestApi();
    final app = AppController(store: store, api: api)
      ..config = APIConfig.defaults.copyWith(baseURL: 'https://old.example/v1')
      ..apiKey = 'sk-old';
    final firstDraft = APIConfig.defaults.copyWith(
      baseURL: 'https://first-vision.example/v1',
      visionModelName: 'gpt-4o-mini',
      modelCapabilities: const {
        'gpt-4o-mini': ModelCapability(isMultimodal: true),
      },
    );
    final secondDraft = APIConfig.defaults.copyWith(
      baseURL: 'https://second-vision.example/v1',
      visionModelName: 'gpt-4o-mini',
      modelCapabilities: const {
        'gpt-4o-mini': ModelCapability(isMultimodal: true),
      },
    );

    final first = app.testVisionConnection(firstDraft, 'sk-first');
    expect(api.visionCompleters, hasLength(1));
    expect(app.isTestingVision, isTrue);

    await app.clearAllLocalData();
    final second = app.testVisionConnection(secondDraft, 'sk-second');
    expect(api.visionCompleters, hasLength(2));
    expect(app.isTestingVision, isTrue);

    api.visionCompleters.first.complete();
    await first;

    expect(app.isTestingVision, isTrue);
    expect(app.config, APIConfig.defaults);
    expect(app.apiKey, isEmpty);
    expect(app.statusMessage, isNull);

    api.visionCompleters.last.complete();
    await second;

    expect(app.isTestingVision, isFalse);
    expect(app.config.baseURL, 'https://second-vision.example/v1');
    expect(app.apiKey, 'sk-second');
    expect(store.savedConfig!.baseURL, 'https://second-vision.example/v1');
    expect(store.savedAPIKey, 'sk-second');
    expect(app.statusMessage, '视觉模型测试成功，配置已保存');
  });

  test('stale generation result cannot recreate data after clear all',
      () async {
    SharedPreferences.setMockInitialValues({});
    final store = FakeStore();
    final api = DeferredConnectionApi();
    final app = AppController(store: store, api: api)..apiKey = 'sk-old';

    final pending = app.generateText('对方：晚上见', ChatStyle.defaultStyle, '自然一点');
    await api.generateStarted.future;
    expect(app.isBusy, isTrue);

    await app.clearAllLocalData();
    api.generateCompleter.complete(ChatReplyResponse(
      sceneSummary: '旧生成',
      replies: [
        ReplySuggestion(styleLabel: '自然', text: '旧回复', reason: '测试'),
      ],
      personInsight: const PersonInsight(
        displayName: '小林',
        communicationStyle: '旧画像',
      ),
    ));
    await pending;

    expect(app.isBusy, isFalse);
    expect(app.currentResponse, isNull);
    expect(app.currentGeneratedProfile, isNull);
    expect(app.currentRecordId, isNull);
    expect(app.history, isEmpty);
    expect(app.profiles, isEmpty);
    expect(store.savedHistory, isEmpty);
    expect(store.savedProfiles, isEmpty);
    expect(app.statusMessage, '本地数据已清空，API 配置已恢复默认。');
  });

  test('stale generation history save cannot persist after clear all',
      () async {
    SharedPreferences.setMockInitialValues({});
    final store = DeferredPreferenceStore()..delayHistorySave = true;
    final api = DeferredConnectionApi();
    final app = AppController(store: store, api: api)..apiKey = 'sk-old';

    final pending = app.generateText('对方：晚上见', ChatStyle.defaultStyle, '自然一点');
    await api.generateStarted.future;

    api.generateCompleter.complete(ChatReplyResponse(
      sceneSummary: '保存中的旧生成',
      replies: [
        ReplySuggestion(styleLabel: '自然', text: '旧回复', reason: '测试'),
      ],
    ));
    await store.historyStarted.future;

    await app.clearAllLocalData();
    store.historyRelease.complete();
    await pending;

    expect(app.isBusy, isFalse);
    expect(app.currentResponse, isNull);
    expect(app.currentRecordId, isNull);
    expect(app.history, isEmpty);
    expect(store.savedHistory, isEmpty);
    expect(store.didClearAll, isTrue);
    expect(app.statusMessage, '本地数据已清空，API 配置已恢复默认。');
  });

  test(
      'stale generation history save removes applied record after profile clear',
      () async {
    SharedPreferences.setMockInitialValues({});
    final store = DeferredPreferenceStore()..delayHistorySave = true;
    final api = DeferredConnectionApi();
    final app = AppController(store: store, api: api)
      ..apiKey = 'sk-old'
      ..profiles = [
        PersonProfile(id: 'target', displayName: '小林'),
      ];

    final pending = app.generateText('对方：晚上见', ChatStyle.defaultStyle, '自然一点');
    await api.generateStarted.future;

    api.generateCompleter.complete(ChatReplyResponse(
      sceneSummary: '保存中的旧生成',
      replies: [
        ReplySuggestion(styleLabel: '自然', text: '旧回复', reason: '测试'),
      ],
    ));
    await store.historyStarted.future;

    expect(app.currentResponse?.sceneSummary, '保存中的旧生成');
    expect(app.history.single.sceneSummary, '保存中的旧生成');

    await app.clearProfiles();
    store.historyRelease.complete();
    await pending;

    expect(app.isBusy, isFalse);
    expect(app.currentResponse, isNull);
    expect(app.currentRecordId, isNull);
    expect(app.history, isEmpty);
    expect(store.savedHistory, isEmpty);
    expect(app.profiles, isEmpty);
  });

  test('stale generation failure cannot overwrite clear all feedback',
      () async {
    SharedPreferences.setMockInitialValues({});
    final api = DeferredConnectionApi();
    final app = AppController(api: api)..apiKey = 'sk-old';

    final pending = app.generateText('对方：晚上见', ChatStyle.defaultStyle, '自然一点');
    await api.generateStarted.future;

    await app.clearAllLocalData();
    api.generateCompleter.completeError(AppException('旧生成失败'));
    await pending;

    expect(app.isBusy, isFalse);
    expect(app.currentResponse, isNull);
    expect(app.history, isEmpty);
    expect(app.errorMessage, isNull);
    expect(app.statusMessage, '本地数据已清空，API 配置已恢复默认。');
  });

  test('stale generation after history clear releases busy state', () async {
    SharedPreferences.setMockInitialValues({});
    final store = FakeStore();
    final api = DeferredConnectionApi();
    final app = AppController(store: store, api: api)
      ..apiKey = 'sk-old'
      ..history = [
        GenerationRecord(
          inputType: ChatInputType.text,
          sceneSummary: '旧历史',
          selectedStyleName: '自然',
          replies: [
            ReplySuggestion(styleLabel: '自然', text: '旧回复', reason: '测试'),
          ],
        ),
      ];

    final pending = app.generateText('对方：晚上见', ChatStyle.defaultStyle, '自然一点');
    await api.generateStarted.future;
    expect(app.isBusy, isTrue);

    await app.clearHistory();
    api.generateCompleter.complete(ChatReplyResponse(
      sceneSummary: '清空后的旧生成',
      replies: [
        ReplySuggestion(styleLabel: '自然', text: '不该出现', reason: '测试'),
      ],
    ));
    await pending;

    expect(app.isBusy, isFalse);
    expect(app.currentResponse, isNull);
    expect(app.currentRecordId, isNull);
    expect(app.history, isEmpty);
    expect(store.savedHistory, isEmpty);
  });

  test(
      'busy text generation ignores duplicate submissions like image generation',
      () async {
    SharedPreferences.setMockInitialValues({});
    final api = SequencedGenerationApi();
    final app = AppController(api: api);

    final first = app.generateText('对方：第一条', ChatStyle.defaultStyle, '第一目标');
    expect(api.generateCompleters, hasLength(1));
    expect(app.isBusy, isTrue);

    final second = app.generateText('对方：第二条', ChatStyle.defaultStyle, '第二目标');
    await second;
    expect(api.generateCompleters, hasLength(1));
    expect(app.isBusy, isTrue);
    expect(api.generatedInputs.map((input) => input.text), ['对方：第一条']);

    api.generateCompleters.single.complete(ChatReplyResponse(
      sceneSummary: '首个结果',
      latestMessage: '第一条',
      replies: [
        ReplySuggestion(styleLabel: '自然', text: '首个回复', reason: '测试'),
      ],
    ));
    await first;

    expect(app.isBusy, isFalse);
    expect(app.currentResponse?.sceneSummary, '首个结果');
    expect(app.history.single.sceneSummary, '首个结果');
    expect(app.history.single.userGoal, '第一目标');
  });

  test('stale moment analysis result cannot recreate profiles after clear',
      () async {
    SharedPreferences.setMockInitialValues({});
    final dir = await Directory.systemTemp.createTemp('ai-reply-moment-stale-');
    final imageFile = File('${dir.path}/moment.png');
    final source = img.Image(width: 16, height: 16);
    img.fill(source, color: img.ColorRgb8(20, 120, 220));
    await imageFile.writeAsBytes(img.encodePng(source));
    final store = FakeStore();
    final api = DeferredConnectionApi();
    final app = AppController(store: store, api: api)
      ..profiles = [
        PersonProfile(id: 'target', displayName: '小林'),
      ];

    try {
      final pending = app.analyzeMoment(imageFile.path);
      await api.momentStarted.future;
      expect(app.isBusy, isTrue);

      await app.clearProfiles();
      api.momentCompleter.complete(const MomentProfileAnalysis(
        sceneSummary: '旧朋友圈',
        visibleName: '小林',
        personalityTraits: ['旧画像'],
      ));
      await pending;

      expect(app.isBusy, isFalse);
      expect(app.currentMomentAnalysis, isNull);
      expect(app.currentMomentProfile, isNull);
      expect(app.profiles, isEmpty);
      expect(store.savedProfiles, isEmpty);
    } finally {
      if (await dir.exists()) await dir.delete(recursive: true);
    }
  });

  test('stale moment analysis failure cannot overwrite cleared profiles',
      () async {
    SharedPreferences.setMockInitialValues({});
    final dir =
        await Directory.systemTemp.createTemp('ai-reply-moment-stale-fail-');
    final imageFile = File('${dir.path}/moment.png');
    final source = img.Image(width: 16, height: 16);
    img.fill(source, color: img.ColorRgb8(20, 120, 220));
    await imageFile.writeAsBytes(img.encodePng(source));
    final api = DeferredConnectionApi();
    final app = AppController(api: api)
      ..profiles = [PersonProfile(id: 'target', displayName: '小林')];

    try {
      final pending = app.analyzeMoment(imageFile.path);
      await api.momentStarted.future;

      await app.clearProfiles();
      api.momentCompleter.completeError(AppException('旧画像失败'));
      await pending;

      expect(app.isBusy, isFalse);
      expect(app.currentMomentAnalysis, isNull);
      expect(app.currentMomentProfile, isNull);
      expect(app.profiles, isEmpty);
      expect(app.errorMessage, isNull);
    } finally {
      if (await dir.exists()) await dir.delete(recursive: true);
    }
  });

  test('busy moment analysis ignores duplicate submissions like generation',
      () async {
    SharedPreferences.setMockInitialValues({});
    final dir = await Directory.systemTemp.createTemp('ai-reply-moment-busy-');
    final imageFile = File('${dir.path}/moment.png');
    final source = img.Image(width: 16, height: 16);
    img.fill(source, color: img.ColorRgb8(90, 80, 180));
    await imageFile.writeAsBytes(img.encodePng(source));
    final api = SequencedMomentApi();
    final app = AppController(api: api);

    try {
      final first = app.analyzeMoment(imageFile.path);
      await waitForCondition(() => api.momentCompleters.length == 1);
      expect(api.momentCompleters, hasLength(1));
      expect(app.isBusy, isTrue);

      final second = app.analyzeMoment(imageFile.path);
      await second;
      expect(api.momentCompleters, hasLength(1));
      expect(app.isBusy, isTrue);

      api.momentCompleters.single.complete(const MomentProfileAnalysis(
        sceneSummary: '首个动态',
        visibleName: '首个人物',
        personalityTraits: ['首个画像'],
      ));
      await first;

      expect(app.isBusy, isFalse);
      expect(app.currentMomentAnalysis?.sceneSummary, '首个动态');
      expect(app.currentMomentProfile?.displayName, '首个人物');
      expect(app.profiles.single.displayName, '首个人物');
    } finally {
      if (await dir.exists()) await dir.delete(recursive: true);
    }
  });

  test('clearing moment result invalidates pending analysis', () async {
    SharedPreferences.setMockInitialValues({});
    final dir = await Directory.systemTemp.createTemp('ai-reply-moment-clear-');
    final imageFile = File('${dir.path}/moment.png');
    final source = img.Image(width: 16, height: 16);
    img.fill(source, color: img.ColorRgb8(20, 160, 120));
    await imageFile.writeAsBytes(img.encodePng(source));
    final api = SequencedMomentApi();
    final app = AppController(api: api);

    try {
      final pending = app.analyzeMoment(imageFile.path);
      await waitForCondition(() => api.momentCompleters.length == 1);
      expect(api.momentCompleters, hasLength(1));
      expect(app.isBusy, isTrue);

      app.clearMomentResult();
      api.momentCompleters.single.complete(const MomentProfileAnalysis(
        sceneSummary: '已清掉的动态',
        visibleName: '旧人物',
        personalityTraits: ['旧画像'],
      ));
      await pending;

      expect(app.isBusy, isFalse);
      expect(app.currentMomentAnalysis, isNull);
      expect(app.currentMomentProfile, isNull);
      expect(app.profiles, isEmpty);
      expect(app.errorMessage, isNull);
    } finally {
      if (await dir.exists()) await dir.delete(recursive: true);
    }
  });

  test('stale simulation result cannot append messages after profiles clear',
      () async {
    SharedPreferences.setMockInitialValues({});
    final api = DeferredConnectionApi();
    final profile = PersonProfile(id: 'target', displayName: '小林');
    final app = AppController(api: api)
      ..profiles = [profile]
      ..simulationProfile = profile;

    final pending = app.startSimulation(profile);
    await api.simulationStarted.future;
    expect(api.simulationRequestProfile?.id, profile.id);
    expect(app.isBusy, isTrue);

    await app.clearProfiles();
    api.simulationCompleter.complete(
      const SimulationTurnResponse(personaMessage: '旧模拟开场'),
    );
    await pending;

    expect(app.isBusy, isFalse);
    expect(app.simulationProfile, isNull);
    expect(app.simulationMessages, isEmpty);
    expect(app.simulationResponse, isNull);
    expect(app.profiles, isEmpty);
  });

  test('deleting simulated profile cancels pending simulation result',
      () async {
    SharedPreferences.setMockInitialValues({});
    final api = DeferredConnectionApi();
    final profile = PersonProfile(id: 'target', displayName: '小林');
    final app = AppController(api: api)
      ..profiles = [profile]
      ..simulationProfile = profile;

    final pending = app.startSimulation(profile);
    await api.simulationStarted.future;
    expect(app.isBusy, isTrue);

    await app.deleteProfile(profile);
    api.simulationCompleter.complete(
      const SimulationTurnResponse(personaMessage: '旧模拟开场'),
    );
    await pending;

    expect(app.isBusy, isFalse);
    expect(app.profiles, isEmpty);
    expect(app.simulationProfile, isNull);
    expect(app.simulationMessages, isEmpty);
    expect(app.simulationResponse, isNull);
    expect(app.errorMessage, isNull);
  });

  test('busy simulation ignores duplicate opening submissions like iOS',
      () async {
    SharedPreferences.setMockInitialValues({});
    final api = SequencedSimulationApi();
    final profile = PersonProfile(id: 'target', displayName: '小林');
    final app = AppController(api: api);

    final first = app.startSimulation(profile);
    await Future<void>.delayed(Duration.zero);
    expect(api.simulationCompleters, hasLength(1));

    final second = app.startSimulation(profile);
    await Future<void>.delayed(Duration.zero);
    await second;
    expect(api.simulationCompleters, hasLength(1));

    api.simulationCompleters.single.complete(
      const SimulationTurnResponse(personaMessage: '首个模拟开场'),
    );
    await first;

    expect(app.isBusy, isFalse);
    expect(app.simulationProfile, profile);
    expect(app.simulationMessages.map((message) => message.text), ['首个模拟开场']);
    expect(app.simulationResponse?.personaMessage, '首个模拟开场');
  });

  test('stale simulation turn cannot pollute restarted scenario session',
      () async {
    SharedPreferences.setMockInitialValues({});
    final api = SequencedSimulationApi();
    final profile = PersonProfile(id: 'target', displayName: '小林');
    final app = AppController(api: api);

    final first = app.startSimulation(profile);
    await Future<void>.delayed(Duration.zero);
    expect(api.simulationCompleters, hasLength(1));
    expect(app.isBusy, isTrue);

    app.simulationScenario = SimulationScenario.comfort;
    final second = app.startSimulation(profile);
    await Future<void>.delayed(Duration.zero);
    expect(api.simulationCompleters, hasLength(2));

    api.simulationCompleters[0].complete(
      const SimulationTurnResponse(personaMessage: '旧日常开场'),
    );
    await first;
    expect(app.isBusy, isTrue);
    expect(app.simulationMessages, isEmpty);
    expect(app.simulationResponse, isNull);

    api.simulationCompleters[1].complete(
      const SimulationTurnResponse(personaMessage: '新安慰开场'),
    );
    await second;

    expect(app.isBusy, isFalse);
    expect(app.simulationScenario, SimulationScenario.comfort);
    expect(app.simulationProfile, profile);
    expect(app.simulationMessages.map((message) => message.text), ['新安慰开场']);
    expect(app.simulationResponse?.personaMessage, '新安慰开场');
  });

  test('simulation completion cannot clear newer generation busy', () async {
    SharedPreferences.setMockInitialValues({});
    final api = SequencedGenerationAndSimulationApi();
    final profile = PersonProfile(id: 'target', displayName: '小林');
    final app = AppController(api: api);

    final simulation = app.startSimulation(profile);
    await Future<void>.delayed(Duration.zero);
    expect(api.simulationCompleters, hasLength(1));
    expect(app.isBusy, isTrue);

    final generation =
        app.generateText('对方：晚上见', ChatStyle.defaultStyle, '自然一点');
    expect(api.generateCompleters, hasLength(1));
    expect(app.isBusy, isTrue);

    api.simulationCompleters.single.complete(
      const SimulationTurnResponse(personaMessage: '模拟先返回'),
    );
    await simulation;

    expect(app.isBusy, isTrue);
    expect(app.simulationMessages.map((message) => message.text), ['模拟先返回']);
    expect(app.currentResponse, isNull);

    api.generateCompleters.single.complete(ChatReplyResponse(
      sceneSummary: '新生成',
      replies: [
        ReplySuggestion(styleLabel: '自然', text: '新回复', reason: '测试'),
      ],
    ));
    await generation;

    expect(app.isBusy, isFalse);
    expect(app.currentResponse?.sceneSummary, '新生成');
    expect(app.history.single.sceneSummary, '新生成');
  });

  test('generation completion cannot clear newer simulation busy', () async {
    SharedPreferences.setMockInitialValues({});
    final api = SequencedGenerationAndSimulationApi();
    final profile = PersonProfile(id: 'target', displayName: '小林');
    final app = AppController(api: api);

    final generation =
        app.generateText('对方：晚上见', ChatStyle.defaultStyle, '自然一点');
    expect(api.generateCompleters, hasLength(1));
    expect(app.isBusy, isTrue);

    final simulation = app.startSimulation(profile);
    await Future<void>.delayed(Duration.zero);
    expect(api.simulationCompleters, hasLength(1));
    expect(app.isBusy, isTrue);

    api.generateCompleters.single.complete(ChatReplyResponse(
      sceneSummary: '先完成的生成',
      replies: [
        ReplySuggestion(styleLabel: '自然', text: '生成回复', reason: '测试'),
      ],
    ));
    await generation;

    expect(app.isBusy, isTrue);
    expect(app.currentResponse?.sceneSummary, '先完成的生成');
    expect(app.history.single.sceneSummary, '先完成的生成');
    expect(app.simulationMessages, isEmpty);

    api.simulationCompleters.single.complete(
      const SimulationTurnResponse(personaMessage: '模拟后返回'),
    );
    await simulation;

    expect(app.isBusy, isFalse);
    expect(app.simulationMessages.map((message) => message.text), ['模拟后返回']);
  });

  test('vision readiness requires a multimodal model marker', () {
    final config = APIConfig.defaults.copyWith(
      visionModelName: 'plain-text-model',
      modelCapabilities: const {
        'plain-text-model': ModelCapability(),
      },
    );
    final readiness = GenerateAPIReadiness(
      config: config,
      hasAPIKey: true,
      capability: GenerateAPICapability.vision,
    );

    expect(readiness.isReady, isFalse);
    expect(readiness.statusText, contains('多模态'));
  });

  test('vision readiness rejects non-chat models marked multimodal', () {
    final config = APIConfig.defaults.copyWith(
      visionModelName: 'omni-moderation-latest',
      modelCapabilities: const {
        'omni-moderation-latest': ModelCapability(isMultimodal: true),
      },
    );
    final readiness = GenerateAPIReadiness(
      config: config,
      hasAPIKey: true,
      capability: GenerateAPICapability.vision,
    );

    expect(readiness.hasVisionModel, isTrue);
    expect(readiness.hasUsableVisionModel, isFalse);
    expect(readiness.hasMultimodalVisionModel, isFalse);
    expect(readiness.isReady, isFalse);
    expect(readiness.statusText, contains('聊天模型'));
    expect(readiness.statusText, contains('审核'));
  });

  test('vision connection test requires multimodal model marker', () async {
    final api = RecordingVisionApi();
    final app = AppController(api: api, store: FakeStore())
      ..config = APIConfig.defaults.copyWith(
        visionModelName: 'plain-text-model',
        modelCapabilities: const {
          'plain-text-model': ModelCapability(),
        },
      );

    await app.testVisionConnection(app.config, 'sk-test');

    expect(api.visionTestCalls, 0);
    expect(app.errorMessage, contains('多模态'));
    expect(app.statusMessage, isNull);
  });

  test('vision connection test rejects non-chat models marked multimodal',
      () async {
    final api = RecordingVisionApi();
    final app = AppController(api: api, store: FakeStore())
      ..config = APIConfig.defaults.copyWith(
        visionModelName: 'omni-moderation-latest',
        modelCapabilities: const {
          'omni-moderation-latest': ModelCapability(isMultimodal: true),
        },
      );

    await app.testVisionConnection(app.config, 'sk-test');

    expect(api.visionTestCalls, 0);
    expect(app.errorMessage, contains('聊天模型'));
    expect(app.statusMessage, isNull);
  });

  test('vision readiness respects screenshot mode switch', () {
    final config = APIConfig.defaults.copyWith(enableImageInput: false);
    final readiness = GenerateAPIReadiness(
      config: config,
      hasAPIKey: true,
      capability: GenerateAPICapability.vision,
    );

    expect(readiness.isReady, isFalse);
    expect(readiness.statusText, contains('截图模式已关闭'));
  });

  test('history filter searches content and copied replies', () {
    final imageRecord = GenerationRecord(
      inputType: ChatInputType.image,
      sceneSummary: '聚餐邀约',
      latestMessage: '周五一起吃饭吗',
      selectedStyleName: '自然',
      replies: [
        ReplySuggestion(styleLabel: '自然', text: '可以呀', reason: '接住邀约'),
      ],
      copiedReply: '可以呀，周五几点？',
    );
    final textRecord = GenerationRecord(
      inputType: ChatInputType.text,
      sceneSummary: '工作同步',
      latestMessage: '方案今天能发吗',
      selectedStyleName: '职场',
      replies: [
        ReplySuggestion(styleLabel: '职场', text: '我下午发你', reason: '明确时间'),
      ],
    );
    final unknownCopiedRecord = GenerationRecord(
      inputType: ChatInputType.text,
      sceneSummary: '噪音记录',
      latestMessage: '不用展示',
      selectedStyleName: '自然',
      replies: [
        ReplySuggestion(styleLabel: '自然', text: '好的', reason: '回应'),
      ],
      copiedReply: '未知',
    );

    final records = [imageRecord, textRecord, unknownCopiedRecord];

    expect(
        filterHistoryRecords(records, mode: HistoryFilterMode.image, query: ''),
        [imageRecord]);
    expect(
        filterHistoryRecords(records,
            mode: HistoryFilterMode.copied, query: ''),
        [imageRecord]);
    expect(
        filterHistoryRecords(records, mode: HistoryFilterMode.all, query: '下午'),
        [textRecord]);
    expect(
        filterHistoryRecords(records,
            mode: HistoryFilterMode.all, query: '明确 时间'),
        [textRecord]);
    expect(
        filterHistoryRecords(records,
            mode: HistoryFilterMode.all, query: '周五 几点'),
        [imageRecord]);
    expect(textRecord.searchableText, contains('明确时间'));
    expect(imageRecord.searchableMetadataValues, contains('可以呀，周五几点？'));
    expect(unknownCopiedRecord.searchableMetadataValues, isNot(contains('未知')));
  });

  testWidgets('history screen counts copied records with presentation cleaning',
      (tester) async {
    final copiedRecord = GenerationRecord(
      inputType: ChatInputType.text,
      sceneSummary: '有效记录',
      latestMessage: '今晚见吗',
      selectedStyleName: '自然',
      replies: [
        ReplySuggestion(styleLabel: '自然', text: '今晚可以', reason: '顺接'),
      ],
      copiedReply: '今晚可以',
    );
    final unknownCopiedRecord = GenerationRecord(
      inputType: ChatInputType.text,
      sceneSummary: '噪音记录',
      latestMessage: '不用展示',
      selectedStyleName: '自然',
      replies: [
        ReplySuggestion(styleLabel: '自然', text: '好的', reason: '回应'),
      ],
      copiedReply: '未知',
    );
    final controller = AppController(store: FakeStore())
      ..history = [copiedRecord, unknownCopiedRecord];

    await tester.pumpWidget(ProviderScope(
      overrides: [
        app_shell.appProvider.overrideWith((ref) => controller),
      ],
      child: const MaterialApp(home: app_shell.HistoryScreen()),
    ));

    expect(find.text('已复制 1'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilterChip, '已复制'));
    await tester.pump();

    expect(find.text('有效记录'), findsOneWidget);
    expect(find.text('噪音记录'), findsNothing);
  });

  test('copying from history detail persists copied reply for that record',
      () async {
    final store = FakeStore();
    final record = GenerationRecord(
      inputType: ChatInputType.text,
      sceneSummary: '约见',
      latestMessage: '晚上见吗',
      selectedStyleName: '自然',
      replies: [
        ReplySuggestion(styleLabel: '自然', text: '晚上见', reason: '直接回应'),
      ],
    );
    final app = AppController(store: store)
      ..history = [record]
      ..selectedHistoryRecord = record;

    await app.copyHistoryText('  晚上见，几点方便？  ', record);

    expect(app.history.single.copiedReply, '晚上见，几点方便？');
    expect(app.selectedHistoryRecord?.copiedReply, '晚上见，几点方便？');
    expect(store.savedHistory.single.copiedReply, '晚上见，几点方便？');
    expect(app.statusMessage, '已复制');
  });

  test('history copy ignores noisy presentation text', () async {
    final store = FakeStore();
    final record = GenerationRecord(
      inputType: ChatInputType.text,
      sceneSummary: '约见',
      latestMessage: '晚上见吗',
      selectedStyleName: '自然',
      replies: [
        ReplySuggestion(styleLabel: '自然', text: '未知', reason: '占位'),
      ],
    );
    final app = AppController(store: store)
      ..history = [record]
      ..selectedHistoryRecord = record;

    final copied = await app.copyHistoryText('未知', record);

    expect(copied, isFalse);
    expect(app.history.single.copiedReply, isNull);
    expect(app.selectedHistoryRecord?.copiedReply, isNull);
    expect(store.savedHistory, isEmpty);
    expect(app.statusMessage, isNull);
  });

  test('current reply copy ignores noisy presentation text', () async {
    final store = FakeStore();
    final reply = ReplySuggestion(styleLabel: '自然', text: '未知', reason: '占位回复');
    final app = AppController(store: store)
      ..currentResponse = ChatReplyResponse(
        sceneSummary: '约见',
        replies: [reply],
      );

    final copied = await app.copyReply(reply);

    expect(copied, isFalse);
    expect(app.history, isEmpty);
    expect(store.savedHistory, isEmpty);
    expect(app.currentRecordId, isNull);
    expect(app.statusMessage, isNull);
  });

  test('successful history copy clears stale copy errors', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') return null;
      return null;
    });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });
    final record = GenerationRecord(
      inputType: ChatInputType.text,
      sceneSummary: '约见',
      selectedStyleName: '自然',
      replies: [
        ReplySuggestion(styleLabel: '自然', text: '晚上见', reason: '直接回应'),
      ],
    );
    final app = AppController(store: FakeStore())
      ..history = [record]
      ..selectedHistoryRecord = record
      ..errorMessage = '复制失败：旧错误';

    await app.copyHistoryText('晚上见', record);

    expect(app.statusMessage, '已复制');
    expect(app.errorMessage, isNull);
  });

  test('stale history copy save cannot persist or overwrite history clear',
      () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') return null;
      return null;
    });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });
    final store = DeferredPreferenceStore()..delayHistorySave = true;
    final record = GenerationRecord(
      inputType: ChatInputType.text,
      sceneSummary: '约见',
      latestMessage: '晚上见吗',
      selectedStyleName: '自然',
      replies: [
        ReplySuggestion(styleLabel: '自然', text: '晚上见', reason: '直接回应'),
      ],
    );
    final app = AppController(store: store)
      ..history = [record]
      ..selectedHistoryRecord = record;

    final pending = app.copyHistoryText('晚上见，几点方便？', record);
    await store.historyStarted.future;

    await app.clearHistory();
    app.setStatus('历史记录已清空');
    store.historyRelease.complete();
    final copied = await pending;

    expect(copied, isFalse);
    expect(app.history, isEmpty);
    expect(app.selectedHistoryRecord, isNull);
    expect(store.savedHistory, isEmpty);
    expect(app.statusMessage, '历史记录已清空');
  });

  test('copying from history detail reports clipboard failure without saving',
      () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        throw PlatformException(code: 'clipboard', message: '剪贴板不可用');
      }
      return null;
    });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });
    final store = FakeStore();
    final record = GenerationRecord(
      inputType: ChatInputType.text,
      sceneSummary: '约见',
      latestMessage: '晚上见吗',
      selectedStyleName: '自然',
      replies: [
        ReplySuggestion(styleLabel: '自然', text: '晚上见', reason: '直接回应'),
      ],
    );
    final app = AppController(store: store)
      ..history = [record]
      ..selectedHistoryRecord = record;

    await app.copyHistoryText('晚上见，几点方便？', record);

    expect(app.errorMessage, '复制失败：剪贴板不可用');
    expect(app.statusMessage, isNull);
    expect(app.history.single.copiedReply, isNull);
    expect(app.selectedHistoryRecord?.copiedReply, isNull);
    expect(store.savedHistory, isEmpty);
  });

  test('stale history copy failure cannot overwrite history clear feedback',
      () async {
    final clipboardStarted = Completer<void>();
    final clipboardRelease = Completer<void>();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        if (!clipboardStarted.isCompleted) clipboardStarted.complete();
        await clipboardRelease.future;
        throw PlatformException(code: 'clipboard', message: '剪贴板不可用');
      }
      return null;
    });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });
    final record = GenerationRecord(
      inputType: ChatInputType.text,
      sceneSummary: '约见',
      latestMessage: '晚上见吗',
      selectedStyleName: '自然',
      replies: [
        ReplySuggestion(styleLabel: '自然', text: '晚上见', reason: '直接回应'),
      ],
    );
    final app = AppController(store: FakeStore())
      ..history = [record]
      ..selectedHistoryRecord = record;

    final pending = app.copyHistoryText('晚上见，几点方便？', record);
    await clipboardStarted.future;

    await app.clearHistory();
    app.setStatus('历史记录已清空');
    clipboardRelease.complete();
    final copied = await pending;

    expect(copied, isFalse);
    expect(app.history, isEmpty);
    expect(app.selectedHistoryRecord, isNull);
    expect(app.statusMessage, '历史记录已清空');
    expect(app.errorMessage, isNull);
  });

  testWidgets('history detail copy all shows transient iOS-style feedback',
      (tester) async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') return null;
      return null;
    });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });
    final store = FakeStore();
    final record = GenerationRecord(
      id: 'history-copy-all',
      inputType: ChatInputType.text,
      sceneSummary: '约时间',
      selectedStyleName: '自然',
      replies: [
        ReplySuggestion(styleLabel: '未知', text: '未知', reason: '占位'),
        ReplySuggestion(styleLabel: '自然', text: '  ', reason: '空白'),
        ReplySuggestion(styleLabel: '自然', text: '今晚可以', reason: '顺接'),
        ReplySuggestion(styleLabel: '重复', text: '今晚可以', reason: '重复'),
        ReplySuggestion(styleLabel: '轻松', text: '那就晚点见', reason: '放松'),
      ],
      createdAt: DateTime(2026, 1, 2),
    );
    final controller = AppController(store: store)
      ..history = [record]
      ..selectedHistoryRecord = record;

    await tester.pumpWidget(ProviderScope(
      overrides: [
        app_shell.appProvider.overrideWith((ref) => controller),
      ],
      child: const MaterialApp(home: app_shell.HistoryDetailScreen()),
    ));

    expect(find.text('候选回复 2'), findsOneWidget);
    await tester.tap(find.text('复制全部'));
    await tester.pump();

    expect(find.text('已复制全部'), findsOneWidget);
    expect(
      controller.selectedHistoryRecord?.copiedReply,
      '1. 自然：今晚可以\n2. 轻松：那就晚点见',
    );
    expect(store.savedHistory.single.copiedReply, '1. 自然：今晚可以\n2. 轻松：那就晚点见');

    await tester.pump(const Duration(milliseconds: 1300));
    expect(find.text('复制全部'), findsOneWidget);
  });

  testWidgets('history detail copied reply marks that candidate like iOS',
      (tester) async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') return null;
      return null;
    });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });
    final store = FakeStore();
    final record = GenerationRecord(
      id: 'history-copy-one',
      inputType: ChatInputType.text,
      sceneSummary: '约时间',
      selectedStyleName: '自然',
      replies: [
        ReplySuggestion(styleLabel: '自然', text: '今晚可以', reason: '顺接'),
      ],
      createdAt: DateTime(2026, 1, 2),
    );
    final controller = AppController(store: store)
      ..history = [record]
      ..selectedHistoryRecord = record;

    await tester.pumpWidget(ProviderScope(
      overrides: [
        app_shell.appProvider.overrideWith((ref) => controller),
      ],
      child: const MaterialApp(home: app_shell.HistoryDetailScreen()),
    ));

    expect(find.text('复制这句'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, '复制这句').first);
    await tester.pump();

    expect(find.text('已复制这句'), findsOneWidget);
    expect(find.text('已复制到剪贴板'), findsOneWidget);
    expect(find.text('今晚可以'), findsWidgets);
    expect(controller.selectedHistoryRecord?.copiedReply, '今晚可以');
    expect(store.savedHistory.single.copiedReply, '今晚可以');

    await tester.pump(const Duration(milliseconds: 1600));
    expect(find.text('已复制到剪贴板'), findsNothing);
  });

  testWidgets(
      'history detail does not show copied feedback on clipboard failure',
      (tester) async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        throw PlatformException(code: 'clipboard', message: '剪贴板不可用');
      }
      return null;
    });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });
    final store = FakeStore();
    final record = GenerationRecord(
      id: 'history-copy-fail',
      inputType: ChatInputType.text,
      sceneSummary: '约时间',
      selectedStyleName: '自然',
      replies: [
        ReplySuggestion(styleLabel: '自然', text: '今晚可以', reason: '顺接'),
      ],
      createdAt: DateTime(2026, 1, 2),
    );
    final controller = AppController(store: store)
      ..history = [record]
      ..selectedHistoryRecord = record;

    await tester.pumpWidget(ProviderScope(
      overrides: [
        app_shell.appProvider.overrideWith((ref) => controller),
      ],
      child: const MaterialApp(home: app_shell.HistoryDetailScreen()),
    ));

    await tester.tap(find.widgetWithText(FilledButton, '复制这句').first);
    await tester.pump();

    expect(find.text('复制这句'), findsOneWidget);
    expect(find.text('已复制这句'), findsNothing);
    expect(find.text('已复制到剪贴板'), findsNothing);
    expect(controller.errorMessage, '复制失败：剪贴板不可用');
    expect(controller.selectedHistoryRecord?.copiedReply, isNull);
    expect(store.savedHistory, isEmpty);
  });

  testWidgets('history detail hides blank metadata and copied reply',
      (tester) async {
    final record = GenerationRecord(
      id: 'blank-history-detail',
      inputType: ChatInputType.text,
      sceneSummary: '  ',
      platform: '  ',
      relationshipGuess: '未知',
      latestMessage: '   ',
      emotion: '未知',
      riskNotice: '未知',
      selectedStyleName: '自然',
      userGoal: '  ',
      copiedReply: '未知',
      replies: [
        ReplySuggestion(styleLabel: '自然', text: '今晚可以', reason: '顺接'),
      ],
      createdAt: DateTime(2026, 1, 2),
    );
    final controller = AppController(store: FakeStore())
      ..history = [record]
      ..selectedHistoryRecord = record;

    await tester.pumpWidget(ProviderScope(
      overrides: [
        app_shell.appProvider.overrideWith((ref) => controller),
      ],
      child: const MaterialApp(home: app_shell.HistoryDetailScreen()),
    ));

    expect(find.text('未识别场景'), findsOneWidget);
    expect(find.text('平台'), findsNothing);
    expect(find.text('关系'), findsNothing);
    expect(find.text('最后一句'), findsNothing);
    expect(find.text('情绪'), findsNothing);
    expect(find.text('风险'), findsNothing);
    expect(find.text('目标'), findsNothing);
    expect(find.text('上次复制的回复'), findsNothing);
    expect(find.text('未知'), findsNothing);
  });

  testWidgets('history record card cleans placeholder style labels',
      (tester) async {
    final record = GenerationRecord(
      id: 'noisy-history-card',
      inputType: ChatInputType.text,
      sceneSummary: '旧记录',
      selectedStyleName: '未知',
      replies: [
        ReplySuggestion(styleLabel: '自然', text: '今晚可以', reason: '顺接'),
      ],
      createdAt: DateTime(2026, 1, 2),
    );

    await tester.pumpWidget(ProviderScope(
      child: MaterialApp(
        home: Scaffold(
          body: HistoryRecordCard(
            record: record,
            onOpen: () {},
            onDelete: () {},
          ),
        ),
      ),
    ));

    expect(find.text('自然'), findsOneWidget);
    expect(find.text('未知'), findsNothing);
  });

  testWidgets('history detail last copied card mirrors iOS copy feedback',
      (tester) async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') return null;
      return null;
    });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });
    final store = FakeStore();
    final record = GenerationRecord(
      id: 'history-last-copied',
      inputType: ChatInputType.text,
      sceneSummary: '约时间',
      selectedStyleName: '自然',
      replies: [
        ReplySuggestion(styleLabel: '自然', text: '今晚可以', reason: '顺接'),
      ],
      copiedReply: '  今晚可以  ',
      createdAt: DateTime(2026, 1, 2),
    );
    final controller = AppController(store: store)
      ..history = [record]
      ..selectedHistoryRecord = record;

    await tester.pumpWidget(ProviderScope(
      overrides: [
        app_shell.appProvider.overrideWith((ref) => controller),
      ],
      child: const MaterialApp(home: app_shell.HistoryDetailScreen()),
    ));

    expect(find.text('上次复制的回复'), findsOneWidget);
    expect(find.text('已复制这句'), findsOneWidget);
    expect(find.text('已复制到剪贴板'), findsNothing);

    await tester.tap(find.byTooltip('已复制这句').first);
    await tester.pump();

    expect(find.text('已复制到剪贴板'), findsOneWidget);
    expect(controller.selectedHistoryRecord?.copiedReply, '今晚可以');
    expect(store.savedHistory.single.copiedReply, '今晚可以');

    await tester.pump(const Duration(milliseconds: 1600));
    expect(find.text('已复制到剪贴板'), findsNothing);
  });

  testWidgets('history detail marks copy-all text as last copied like iOS',
      (tester) async {
    final record = GenerationRecord(
      id: 'history-copy-all-previous',
      inputType: ChatInputType.text,
      sceneSummary: '约时间',
      selectedStyleName: '自然',
      replies: [
        ReplySuggestion(styleLabel: '自然', text: '今晚可以', reason: '顺接'),
        ReplySuggestion(styleLabel: '轻松', text: '那就晚点见', reason: '放松'),
      ],
      copiedReply: '1. 自然：今晚可以\n2. 轻松：那就晚点见',
      createdAt: DateTime(2026, 1, 2),
    );
    final controller = AppController(store: FakeStore())
      ..history = [record]
      ..selectedHistoryRecord = record;

    await tester.pumpWidget(ProviderScope(
      overrides: [
        app_shell.appProvider.overrideWith((ref) => controller),
      ],
      child: const MaterialApp(home: app_shell.HistoryDetailScreen()),
    ));

    expect(find.text('上次复制的回复'), findsOneWidget);
    expect(find.byTooltip('已复制这句'), findsOneWidget);
    expect(find.byTooltip('复制这句'), findsNothing);
  });

  test('generation history preserves reply metadata for detail view', () async {
    SharedPreferences.setMockInitialValues({});
    final store = FakeStore();
    final app = AppController(store: store, api: MetadataApi());

    await app.generateText('对方：晚上吃啥', ChatStyle.defaultStyle, '别太主动');

    final record = app.history.single;
    expect(record.sceneSummary, '约晚饭');
    expect(record.platform, '微信');
    expect(record.relationshipGuess, '朋友');
    expect(record.latestMessage, '晚上吃啥');
    expect(record.emotion, '期待');
    expect(record.riskNotice, '别承诺太满');
    expect(record.searchableText, contains('微信'));
    expect(store.savedHistory.single.toJson()['platform'], '微信');
    expect(GenerationRecord.fromJson(record.toJson()).riskNotice, '别承诺太满');
  });

  test('generation normalizes current response before applying state',
      () async {
    SharedPreferences.setMockInitialValues({});
    final store = FakeStore();
    final app = AppController(store: store, api: DirtyResponseApi());

    await app.generateText('对方：今晚见吗', ChatStyle.defaultStyle, '自然一点');

    final response = app.currentResponse!;
    expect(response.sceneSummary, isNull);
    expect(response.platform, '微信');
    expect(response.relationshipGuess, isNull);
    expect(response.latestMessage, '今晚见吗');
    expect(response.emotion, isNull);
    expect(response.riskNotice, isNull);
    expect(response.replies, hasLength(1));
    expect(response.replies.single.styleLabel, '轻松');
    expect(response.replies.single.text, '可以呀');
    expect(response.replies.single.reason, '');
    expect(response.personInsight?.displayName, '小林');
    expect(response.personInsight?.aliases, ['Lin']);
    expect(response.personInsight?.relationship, isNull);
    expect(response.personInsight?.communicationStyle, '直接一点');
    expect(response.personInsight?.personalityTraits, ['稳']);
    expect(response.personInsight?.confidence, 1);
    expect(response.personInsight?.updateReason, isNull);
    expect(app.currentGeneratedProfile?.displayName, '小林');
    expect(app.currentGeneratedProfile?.lastSceneSummary, isNull);
    expect(app.history.single.platform, '微信');
    expect(app.history.single.replies.single.text, '可以呀');
    expect(store.savedHistory.single.replies.single.text, '可以呀');
  });

  test('generation keeps in-memory history capped like iOS store', () async {
    SharedPreferences.setMockInitialValues({});
    final store = FakeStore();
    final app = AppController(store: store, api: MetadataApi());
    final firstStoredInstant = DateTime(2025, 1, 1);
    app.history = List.generate(
      100,
      (index) => GenerationRecord(
        id: 'old-history-$index',
        inputType: ChatInputType.text,
        selectedStyleName: '自然',
        replies: [
          ReplySuggestion(styleLabel: '自然', text: '旧回复$index', reason: '测试'),
        ],
        createdAt: firstStoredInstant.add(Duration(days: index)),
      ),
    );
    app.selectHistoryRecord(app.history.first);

    await app.generateText('对方：晚上吃啥', ChatStyle.defaultStyle, '别太主动');

    expect(app.history, hasLength(100));
    expect(store.savedHistory, hasLength(100));
    expect(app.history.first.sceneSummary, '约晚饭');
    expect(store.savedHistory.first.id, app.history.first.id);
    expect(app.history.any((record) => record.id == 'old-history-0'), isFalse);
    expect(store.savedHistory.any((record) => record.id == 'old-history-0'),
        isFalse);
    expect(app.selectedHistoryRecord, isNull);
  });

  test('history persistence normalizes retained runtime records', () async {
    SharedPreferences.setMockInitialValues({});
    final store = FakeStore();
    final dirty = GenerationRecord(
      id: 'dirty-history',
      inputType: ChatInputType.text,
      sceneSummary: '未知',
      platform: '  微信  ',
      relationshipGuess: '未知',
      latestMessage: '  晚上吃啥  ',
      emotion: '  ',
      riskNotice: '未知',
      selectedStyleName: '未知',
      userGoal: '  未知  ',
      copiedReply: '未知',
      replies: [
        ReplySuggestion(styleLabel: '未知', text: '未知', reason: '  '),
        ReplySuggestion(styleLabel: '  自然  ', text: '  好呀  ', reason: ' 顺着说 '),
      ],
      createdAt: DateTime(2025, 1, 1),
    );
    final app = AppController(store: store, api: MetadataApi())
      ..history = [dirty]
      ..selectedHistoryRecord = dirty;

    await app.generateText('对方：晚上吃啥', ChatStyle.defaultStyle, '别太主动');

    final retained =
        app.history.singleWhere((record) => record.id == 'dirty-history');
    expect(retained.sceneSummary, isNull);
    expect(retained.platform, '微信');
    expect(retained.relationshipGuess, isNull);
    expect(retained.latestMessage, '晚上吃啥');
    expect(retained.emotion, isNull);
    expect(retained.riskNotice, isNull);
    expect(retained.selectedStyleName, '自然');
    expect(retained.userGoal, isNull);
    expect(retained.copiedReply, isNull);
    expect(retained.replies, hasLength(1));
    expect(retained.replies.single.text, '好呀');
    expect(retained.replies.single.reason, '顺着说');
    expect(app.selectedHistoryRecord, same(retained));
    expect(
        store.savedHistory
            .singleWhere((record) => record.id == 'dirty-history')
            .toJson(),
        retained.toJson());
  });

  test('history normalization preserves runtime record identity keys',
      () async {
    SharedPreferences.setMockInitialValues({});
    final store = FakeStore();
    final dirty = GenerationRecord(
      id: ' dirty-history ',
      inputType: ChatInputType.text,
      sceneSummary: '未知',
      selectedStyleName: '未知',
      replies: [
        ReplySuggestion(styleLabel: '自然', text: '  好呀  ', reason: '未知'),
      ],
      createdAt: DateTime(2025, 1, 1),
    );
    final app = AppController(store: store, api: MetadataApi())
      ..history = [dirty]
      ..selectedHistoryRecord = dirty;

    await app.generateText('对方：晚上吃啥', ChatStyle.defaultStyle, '别太主动');

    final retained =
        app.history.singleWhere((record) => record.id == ' dirty-history ');
    expect(retained.sceneSummary, isNull);
    expect(retained.selectedStyleName, '自然');
    expect(retained.replies.single.text, '好呀');
    expect(app.selectedHistoryRecord, same(retained));
    expect(
      store.savedHistory.any((record) => record.id == ' dirty-history '),
      isTrue,
    );
  });

  test('generation keeps saved person profile for result detail like iOS',
      () async {
    SharedPreferences.setMockInitialValues({});
    final store = FakeStore();
    final app = AppController(store: store, api: InsightApi());

    await app.generateText('对方：几点开会', ChatStyle.defaultStyle, '提前确认');

    expect(app.currentGeneratedProfile?.displayName, '小林');
    expect(app.currentGeneratedProfile?.aliases, ['Lin']);
    expect(app.currentGeneratedProfile?.keyPersonPoints, ['喜欢提前确认时间']);
    expect(app.currentGeneratedProfile?.lastUpdateReason, '聊天中强调提前确认');
    expect(app.profiles.single.id, app.currentGeneratedProfile?.id);
    expect(store.savedProfiles.single.id, app.currentGeneratedProfile?.id);

    await app.clearHistory();

    expect(app.currentResponse, isNotNull);
    expect(app.currentGeneratedProfile?.displayName, '小林');

    await app.deleteProfile(app.currentGeneratedProfile!);

    expect(app.currentGeneratedProfile, isNull);
  });

  test('new reply insight profiles clean list fields like iOS upsert',
      () async {
    SharedPreferences.setMockInitialValues({});
    final app = AppController(store: FakeStore(), api: DirtyInsightApi());

    await app.generateText('对方：几点开会', ChatStyle.defaultStyle, '提前确认');

    final profile = app.profiles.single;
    expect(profile.displayName, '小林');
    expect(profile.aliases, ['Lin']);
    expect(profile.relationship, '同事');
    expect(profile.communicationStyle, '直接一点');
    expect(profile.personalityTraits, ['稳']);
    expect(profile.innerNeeds, ['确定性']);
    expect(profile.keyPersonPoints, ['提前确认时间']);
    expect(profile.momentsInsights, ['常发工作动态']);
    expect(profile.tonePreferences, ['少绕弯']);
    expect(profile.boundaries, ['别催促']);
    expect(profile.facts, ['在上海']);
    expect(profile.lastSceneSummary, '新画像场景');
    expect(profile.lastUpdateReason, '聊天中强调提前确认');
    expect(profile.summaryForPrompt, isNot(contains('未知')));
    expect(profile.summaryForPrompt, isNot(contains('、 ')));
  });

  test('manual result profile save marks current generated profile like iOS',
      () async {
    SharedPreferences.setMockInitialValues({});
    final store = FakeStore();
    final app = AppController(store: store)
      ..currentResponse = ChatReplyResponse(
        sceneSummary: '聊项目',
        replies: [
          ReplySuggestion(styleLabel: '自然', text: '我确认下时间', reason: '稳妥'),
        ],
        personInsight: const PersonInsight(
          displayName: '小林',
          keyPersonPoints: ['喜欢提前确认时间'],
        ),
      );
    final draft = PersonProfile(
      id: ' draft-from-result ',
      displayName: '林同学',
      keyPersonPoints: const ['喜欢提前确认时间'],
    );
    app.selectProfile(draft);

    await app.saveProfile(PersonProfile(
      id: 'draft-from-result',
      displayName: '林同学',
      keyPersonPoints: const ['喜欢提前确认时间'],
    ));

    expect(app.currentGeneratedProfile?.id, 'draft-from-result');
    expect(app.currentGeneratedProfile?.displayName, '林同学');
    expect(store.savedProfiles.single.id, 'draft-from-result');
  });

  testWidgets('unsaved result profile draft does not leak selection',
      (tester) async {
    final controller = AppController(store: FakeStore())
      ..currentResponse = ChatReplyResponse(
        sceneSummary: '聊项目',
        replies: [
          ReplySuggestion(styleLabel: '自然', text: '我确认下时间', reason: '稳妥'),
        ],
        personInsight: const PersonInsight(
          displayName: '小林',
          keyPersonPoints: ['喜欢提前确认时间'],
        ),
      );
    final router = GoRouter(
      initialLocation: AppRoutes.result,
      routes: [
        GoRoute(
          path: AppRoutes.result,
          builder: (context, state) => const app_shell.ResultScreen(),
        ),
        GoRoute(
          path: AppRoutes.peopleEdit,
          builder: (context, state) => const app_shell.ProfileEditorScreen(),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(ProviderScope(
      overrides: [
        app_shell.appProvider.overrideWith((ref) => controller),
      ],
      child: MaterialApp.router(routerConfig: router),
    ));

    await tester.tap(find.text('命名并保存到人物库'));
    await tester.pumpAndSettle();

    expect(controller.selectedProfile?.displayName, '小林');
    expect(controller.profiles, isEmpty);

    router.pop();
    await tester.pumpAndSettle();

    expect(controller.selectedProfile, isNull);
    expect(controller.profiles, isEmpty);
  });

  test('profile save keeps in-memory people capped like iOS store', () async {
    SharedPreferences.setMockInitialValues({});
    final store = FakeStore();
    final app = AppController(store: store);
    final firstStoredInstant = DateTime(2025, 1, 1);
    app.profiles = List.generate(
      50,
      (index) => PersonProfile(
        id: 'old-profile-$index',
        displayName: '旧人物$index',
        createdAt: firstStoredInstant.add(Duration(days: index)),
        updatedAt: firstStoredInstant.add(Duration(days: index)),
      ),
    );
    app.currentGeneratedProfile = app.profiles.first;
    app.currentMomentProfile = app.profiles.first;
    app.currentSelectedProfileId = app.profiles.first.id;

    await app.saveProfile(PersonProfile(
      id: 'new-profile',
      displayName: '新人物',
    ));

    expect(app.profiles, hasLength(50));
    expect(store.savedProfiles, hasLength(50));
    expect(app.profiles.first.id, 'new-profile');
    expect(store.savedProfiles.first.id, 'new-profile');
    expect(
        app.profiles.any((profile) => profile.id == 'old-profile-0'), isFalse);
    expect(store.savedProfiles.any((profile) => profile.id == 'old-profile-0'),
        isFalse);
    expect(app.currentGeneratedProfile, isNull);
    expect(app.currentMomentProfile, isNull);
    expect(app.currentSelectedProfileId, isNull);
  });

  test('profile persistence normalizes retained runtime profiles', () async {
    SharedPreferences.setMockInitialValues({});
    final store = FakeStore();
    final dirty = PersonProfile(
      id: 'dirty-profile',
      displayName: '  ',
      aliases: const ['未知', ' Lin ', ' '],
      relationship: '未知',
      communicationStyle: '  ',
      personalityTraits: const ['未知', '稳'],
      innerNeeds: const [' '],
      keyPersonPoints: const [' 会提前确认 ', '未知'],
      momentsInsights: const ['未知'],
      tonePreferences: const ['短句回应', '未知'],
      boundaries: const [' '],
      facts: const [' 在上海 '],
      lastSceneSummary: '未知',
      lastUpdateReason: '  ',
      confidence: 1.4,
      updatedAt: DateTime(2025, 1, 1),
    );
    final app = AppController(store: store)
      ..profiles = [dirty]
      ..selectedProfile = dirty
      ..currentGeneratedProfile = dirty
      ..currentMomentProfile = dirty
      ..simulationProfile = dirty
      ..currentSelectedProfileId = ' dirty-profile ';

    await app.saveProfile(PersonProfile(id: 'new-profile', displayName: '小林'));

    final retained =
        app.profiles.singleWhere((profile) => profile.id == 'dirty-profile');
    expect(retained.displayName, '未命名人物');
    expect(retained.aliases, ['Lin']);
    expect(retained.relationship, isNull);
    expect(retained.communicationStyle, isNull);
    expect(retained.personalityTraits, ['稳']);
    expect(retained.innerNeeds, isEmpty);
    expect(retained.keyPersonPoints, ['会提前确认']);
    expect(retained.momentsInsights, isEmpty);
    expect(retained.tonePreferences, ['短句回应']);
    expect(retained.boundaries, isEmpty);
    expect(retained.facts, ['在上海']);
    expect(retained.lastSceneSummary, isNull);
    expect(retained.lastUpdateReason, isNull);
    expect(retained.confidence, 1);
    expect(app.selectedProfile?.id, 'new-profile');
    expect(app.currentGeneratedProfile, same(retained));
    expect(app.currentMomentProfile, same(retained));
    expect(app.simulationProfile, same(retained));
    expect(app.currentSelectedProfileId, 'dirty-profile');
    expect(
        store.savedProfiles
            .singleWhere((profile) => profile.id == 'dirty-profile')
            .toJson(),
        retained.toJson());
  });

  test('stale profile save cannot persist after clear all', () async {
    SharedPreferences.setMockInitialValues({});
    final store = DeferredPreferenceStore()..delayProfilesSave = true;
    final app = AppController(store: store);
    final draft = PersonProfile(
      id: 'delayed-profile',
      displayName: '延迟保存的人',
      keyPersonPoints: const ['旧画像'],
    );

    final pending = app.saveProfile(draft);
    await store.profilesStarted.future;

    await app.clearAllLocalData();
    store.profilesRelease.complete();
    await pending;

    expect(app.profiles, isEmpty);
    expect(app.selectedProfile, isNull);
    expect(store.savedProfiles, isEmpty);
    expect(store.didClearAll, isTrue);
  });

  test('history and profile persistence share normalized revision helper', () {
    final source =
        File('lib/core/app_state_runtime_helpers.dart').readAsStringSync();
    final retentionSource =
        File('lib/core/record_retention.dart').readAsStringSync();

    expect(source,
        contains('Future<void> _persistNormalizedListForRevision<T>({'));
    expect(source, contains('int _beginProfilesMutation()'));
    expect(source, contains('int _beginHistoryMutation()'));
    expect(source, contains('bool _isCurrentHistoryRevision('));
    expect(source, contains('bool _isCurrentProfilesRevision('));
    expect(
      RegExp(r'await _persistNormalizedListForRevision<')
          .allMatches(source)
          .length,
      2,
    );
    expect(source, contains('normalize: (items) => normalizedHistoryRecords('));
    expect(source, contains('normalize: (items) => normalizedPersonProfiles('));
    expect(source, contains('save: (items) => _store.saveHistory(items)'));
    expect(source, contains('save: (items) => _store.saveProfiles(items)'));
    expect(source, contains('isCurrentRevision: _isCurrentHistoryRevision'));
    expect(source, contains('isCurrentRevision: _isCurrentProfilesRevision'));
    expect(source, contains('required bool Function(int) isCurrentRevision'));
    expect(source, contains('if (!isCurrentRevision(revision))'));
    expect(source, contains('syncAfterStale: false'));
    final profilesStart = source.indexOf('Future<void> _persistProfiles()');
    final historyStart = source.indexOf('Future<void> _persistHistory()');
    final normalizedStart =
        source.indexOf('Future<void> _persistNormalizedListForRevision<T>');
    expect(profilesStart, isNonNegative);
    expect(historyStart, greaterThan(profilesStart));
    expect(normalizedStart, greaterThan(historyStart));
    final persistListBody = source.substring(profilesStart, normalizedStart);
    expect(persistListBody, isNot(contains('++_historyRevision')));
    expect(persistListBody, isNot(contains('++_profilesRevision')));
    expect(persistListBody,
        isNot(contains('currentRevision: () => _historyRevision')));
    expect(persistListBody,
        isNot(contains('currentRevision: () => _profilesRevision')));
    expect(
        retentionSource, contains('final normalized = record.normalized();'));
    expect(
        retentionSource, contains('final normalized = profile.normalized();'));
    expect(retentionSource,
        contains('bool personProfileValuesEqual(PersonProfile left'));
    expect(source,
        contains('personProfileValuesEqual(profile, normalizedProfile)'));
    expect(source, isNot(contains('_hasSamePersonProfileValues')));
    expect(retentionSource, isNot(contains('cleanPresentationText(record.')));
    expect(retentionSource, isNot(contains('cleanPresentationText(profile.')));
  });

  test('history removal paths share runtime clearing helpers', () {
    final runtimeSource =
        File('lib/core/app_state_runtime_helpers.dart').readAsStringSync();
    final recordsSource =
        File('lib/core/app_state_records.dart').readAsStringSync();
    final localDataSource =
        File('lib/core/app_state_local_data.dart').readAsStringSync();

    expect(runtimeSource, contains('void _clearHistoryRuntimeReferences()'));
    expect(runtimeSource,
        contains('void _clearHistoryRuntimeReferencesFor(String recordId)'));
    expect(runtimeSource, contains('void _invalidateContentOperations()'));
    expect(recordsSource, contains('_clearHistoryRuntimeReferencesFor('));
    expect(recordsSource, contains('_clearHistoryRuntimeReferences();'));
    expect(recordsSource, contains('_invalidateContentOperations();'));
    expect(localDataSource, contains('_clearHistoryRuntimeReferences();'));
    expect(recordsSource, isNot(contains('currentRecordId = null')));
    expect(recordsSource, isNot(contains('selectedHistoryRecord = null')));
    expect(recordsSource, isNot(contains('_contentRevision += 1')));
  });

  test('ordinary new profile save does not hijack current result profile',
      () async {
    SharedPreferences.setMockInitialValues({});
    final app = AppController()
      ..currentResponse = ChatReplyResponse(
        sceneSummary: '聊项目',
        replies: [
          ReplySuggestion(styleLabel: '自然', text: '我确认下时间', reason: '稳妥'),
        ],
        personInsight: const PersonInsight(displayName: '小林'),
      );

    await app.saveProfile(PersonProfile(
      id: 'ordinary-new-profile',
      displayName: '普通新增人物',
    ));

    expect(app.currentGeneratedProfile, isNull);
  });

  test('copying current result recreates history after history is cleared',
      () async {
    SharedPreferences.setMockInitialValues({});
    final store = FakeStore();
    final app = AppController(store: store, api: MetadataApi());

    await app.generateText('对方：晚上吃啥', ChatStyle.defaultStyle, '别太主动');
    await app.clearHistory();

    expect(app.history, isEmpty);
    await app.copyReply(app.currentResponse!.replies.single);

    expect(app.history, hasLength(1));
    expect(app.history.single.sceneSummary, '约晚饭');
    expect(app.history.single.copiedReply, '看你想吃啥');
    expect(app.history.single.platform, '微信');
    expect(store.savedHistory.single.copiedReply, '看你想吃啥');
  });

  test('copying current result refreshes selected history record', () async {
    SharedPreferences.setMockInitialValues({});
    final store = FakeStore();
    final app = AppController(store: store, api: MetadataApi());

    await app.generateText('对方：晚上吃啥', ChatStyle.defaultStyle, '别太主动');
    app.selectHistoryRecord(app.history.single);

    await app.copyReply(app.currentResponse!.replies.single);

    expect(app.history.single.copiedReply, '看你想吃啥');
    expect(app.selectedHistoryRecord?.copiedReply, '看你想吃啥');
    expect(store.savedHistory.single.copiedReply, '看你想吃啥');
  });

  test('copying current result matches spaced current history record id',
      () async {
    SharedPreferences.setMockInitialValues({});
    final store = FakeStore();
    final record = GenerationRecord(
      id: ' dirty-history ',
      inputType: ChatInputType.text,
      selectedStyleName: '自然',
      replies: [
        ReplySuggestion(styleLabel: '自然', text: '今晚可以', reason: '顺接'),
      ],
    );
    final app = AppController(store: store)
      ..history = [record]
      ..selectedHistoryRecord = record
      ..currentRecordId = 'dirty-history'
      ..currentResponse = ChatReplyResponse(
        replies: [
          ReplySuggestion(styleLabel: '自然', text: '今晚可以', reason: '顺接'),
        ],
      );

    await app.copyReply(app.currentResponse!.replies.single);

    expect(app.history.single.copiedReply, '今晚可以');
    expect(app.selectedHistoryRecord, same(app.history.single));
    expect(store.savedHistory.single.id, ' dirty-history ');
    expect(store.savedHistory.single.copiedReply, '今晚可以');
  });

  test('successful result copy clears stale copy errors', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') return null;
      return null;
    });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });
    SharedPreferences.setMockInitialValues({});
    final app = AppController(store: FakeStore(), api: MetadataApi())
      ..errorMessage = '复制失败：旧错误';

    await app.generateText('对方：晚上吃啥', ChatStyle.defaultStyle, '别太主动');
    app.errorMessage = '复制失败：旧错误';
    await app.copyReply(app.currentResponse!.replies.single);

    expect(app.statusMessage, '已复制');
    expect(app.errorMessage, isNull);
    expect(app.history.single.copiedReply, '看你想吃啥');
  });

  test('stale result copy cannot overwrite clear all feedback', () async {
    final clipboardStarted = Completer<void>();
    final clipboardRelease = Completer<void>();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        if (!clipboardStarted.isCompleted) clipboardStarted.complete();
        await clipboardRelease.future;
        return null;
      }
      return null;
    });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });
    SharedPreferences.setMockInitialValues({});
    final store = FakeStore();
    final app = AppController(store: store, api: MetadataApi());

    await app.generateText('对方：晚上吃啥', ChatStyle.defaultStyle, '别太主动');
    final pending = app.copyReply(app.currentResponse!.replies.single);
    await clipboardStarted.future;

    await app.clearAllLocalData();
    clipboardRelease.complete();
    final didCopy = await pending;

    expect(didCopy, isFalse);
    expect(app.currentResponse, isNull);
    expect(app.currentRecordId, isNull);
    expect(app.history, isEmpty);
    expect(store.savedHistory, isEmpty);
    expect(store.didClearAll, isTrue);
    expect(app.statusMessage, '本地数据已清空，API 配置已恢复默认。');
    expect(app.errorMessage, isNull);
  });

  test('stale result copy failure cannot overwrite clear all feedback',
      () async {
    final clipboardStarted = Completer<void>();
    final clipboardRelease = Completer<void>();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        if (!clipboardStarted.isCompleted) clipboardStarted.complete();
        await clipboardRelease.future;
        throw PlatformException(code: 'clipboard', message: '剪贴板不可用');
      }
      return null;
    });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });
    SharedPreferences.setMockInitialValues({});
    final store = FakeStore();
    final app = AppController(store: store, api: MetadataApi());

    await app.generateText('对方：晚上吃啥', ChatStyle.defaultStyle, '别太主动');
    final pending = app.copyReply(app.currentResponse!.replies.single);
    await clipboardStarted.future;

    await app.clearAllLocalData();
    clipboardRelease.complete();
    final didCopy = await pending;

    expect(didCopy, isFalse);
    expect(app.currentResponse, isNull);
    expect(app.currentRecordId, isNull);
    expect(app.history, isEmpty);
    expect(store.savedHistory, isEmpty);
    expect(store.didClearAll, isTrue);
    expect(app.statusMessage, '本地数据已清空，API 配置已恢复默认。');
    expect(app.errorMessage, isNull);
  });

  test('stale result copy history save is removed after new generation starts',
      () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') return null;
      return null;
    });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });
    SharedPreferences.setMockInitialValues({});
    final store = DeferredPreferenceStore()..delayHistorySave = true;
    final api = DeferredConnectionApi();
    final app = AppController(store: store, api: api)
      ..apiKey = 'sk-new'
      ..currentInputType = ChatInputType.text
      ..currentTextInput = '对方：旧消息'
      ..currentStyle = ChatStyle.defaultStyle
      ..currentResponse = ChatReplyResponse(
        sceneSummary: '旧结果',
        replies: [
          ReplySuggestion(styleLabel: '自然', text: '旧回复', reason: '测试'),
        ],
      );

    final copyPending = app.copyReply(app.currentResponse!.replies.single);
    await store.historyStarted.future;

    expect(app.history.single.sceneSummary, '旧结果');

    final generationPending =
        app.generateText('对方：新消息', ChatStyle.defaultStyle, '新目标');
    await api.generateStarted.future;

    store.historyRelease.complete();
    final didCopy = await copyPending;

    expect(didCopy, isFalse);
    expect(app.currentResponse, isNull);
    expect(app.currentRecordId, isNull);
    expect(app.history, isEmpty);
    expect(store.savedHistory, isEmpty);
    expect(app.statusMessage, isNull);

    api.generateCompleter.complete(ChatReplyResponse(
      sceneSummary: '新结果',
      replies: [
        ReplySuggestion(styleLabel: '自然', text: '新回复', reason: '测试'),
      ],
    ));
    await generationPending;

    expect(app.history.single.sceneSummary, '新结果');
    expect(store.savedHistory.single.sceneSummary, '新结果');
  });

  test(
      'copying current result reports clipboard failure without history writes',
      () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        throw PlatformException(code: 'clipboard', message: '剪贴板不可用');
      }
      return null;
    });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });
    SharedPreferences.setMockInitialValues({});
    final store = FakeStore();
    final app = AppController(store: store, api: MetadataApi());

    await app.generateText('对方：晚上吃啥', ChatStyle.defaultStyle, '别太主动');
    app.selectHistoryRecord(app.history.single);

    await app.copyReply(app.currentResponse!.replies.single);

    expect(app.errorMessage, '复制失败：剪贴板不可用');
    expect(app.statusMessage, isNull);
    expect(app.history.single.copiedReply, isNull);
    expect(app.selectedHistoryRecord?.copiedReply, isNull);
    expect(store.savedHistory.single.copiedReply, isNull);
  });

  testWidgets('result screen marks copied first reply like iOS',
      (tester) async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') return null;
      return null;
    });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });
    final store = FakeStore();
    final controller = AppController(store: store)
      ..currentInputType = ChatInputType.text
      ..currentStyle = ChatStyle.defaultStyle
      ..currentTextInput = '对方：今晚有空吗'
      ..statusMessage = '配置已保存'
      ..currentResponse = ChatReplyResponse(
        sceneSummary: '约时间',
        replies: [
          ReplySuggestion(styleLabel: '未知', text: '未知', reason: '占位'),
          ReplySuggestion(styleLabel: '自然', text: '  ', reason: '空白'),
          ReplySuggestion(styleLabel: '自然', text: '  今晚可以  ', reason: '顺接'),
          ReplySuggestion(styleLabel: '重复', text: '今晚可以', reason: '重复'),
          ReplySuggestion(styleLabel: '轻松', text: '那就晚点见', reason: '放松'),
        ],
      );

    await tester.pumpWidget(ProviderScope(
      overrides: [
        app_shell.appProvider.overrideWith((ref) => controller),
      ],
      child: const MaterialApp(home: app_shell.ResultScreen()),
    ));

    expect(find.text('配置已保存'), findsNothing);
    expect(find.text('候选回复 2'), findsOneWidget);
    await tester.tap(find.text('复制首条'));
    await tester.pump();

    expect(find.text('已复制首条'), findsOneWidget);
    expect(find.text('已复制，可以回聊天 App 粘贴'), findsOneWidget);
    expect(find.text('已复制'), findsWidgets);
    expect(controller.history.single.copiedReply, '今晚可以');
    expect(store.savedHistory.single.copiedReply, '今晚可以');
  });

  testWidgets('result screen hides missing latest message like iOS',
      (tester) async {
    final controller = AppController(store: FakeStore())
      ..currentInputType = ChatInputType.text
      ..currentStyle = ChatStyle.defaultStyle
      ..currentTextInput = '对方发来一段没有明确最后一句的聊天'
      ..currentResponse = ChatReplyResponse(
        sceneSummary: '闲聊片段',
        platform: '微信',
        relationshipGuess: '朋友',
        latestMessage: '   ',
        emotion: '轻松',
        riskNotice: '未知',
        replies: [
          ReplySuggestion(styleLabel: '自然', text: '那也挺好呀', reason: '接住'),
        ],
      );

    await tester.pumpWidget(ProviderScope(
      overrides: [
        app_shell.appProvider.overrideWith((ref) => controller),
      ],
      child: const MaterialApp(home: app_shell.ResultScreen()),
    ));

    expect(find.text('最后一句'), findsNothing);
    expect(find.text('风险'), findsNothing);
    expect(find.text('未识别'), findsNothing);

    controller.currentResponse = ChatReplyResponse(
      sceneSummary: '闲聊片段',
      platform: '微信',
      relationshipGuess: '朋友',
      latestMessage: '今天有点累',
      emotion: '轻松',
      replies: [
        ReplySuggestion(styleLabel: '自然', text: '那早点休息呀', reason: '接住'),
      ],
    );
    controller.notifyListeners();
    await tester.pump();

    expect(find.text('最后一句'), findsOneWidget);
    expect(find.text('今天有点累'), findsOneWidget);
  });

  testWidgets('result screen hides noisy metadata fields', (tester) async {
    final controller = AppController(store: FakeStore())
      ..currentInputType = ChatInputType.text
      ..currentStyle = ChatStyle.defaultStyle
      ..currentTextInput = '对方发来一段聊天'
      ..currentRecordId = 'noisy-result'
      ..history = [
        GenerationRecord(
          id: 'noisy-result',
          inputType: ChatInputType.text,
          selectedStyleName: '自然',
          copiedReply: '未知',
          replies: [
            ReplySuggestion(styleLabel: '自然', text: '未知', reason: '占位'),
          ],
        ),
      ]
      ..currentResponse = ChatReplyResponse(
        sceneSummary: '闲聊片段',
        platform: '未知',
        relationshipGuess: '  ',
        latestMessage: '未知',
        emotion: '未知',
        riskNotice: '  ',
        replies: [
          ReplySuggestion(styleLabel: '未知', text: '未知', reason: '占位'),
          ReplySuggestion(styleLabel: '自然', text: '那也挺好呀', reason: '接住'),
          ReplySuggestion(styleLabel: '重复', text: '那也挺好呀', reason: '重复'),
        ],
      );

    expect(controller.currentResponse!.resultInfoLines, [
      ('场景', '闲聊片段'),
    ]);

    await tester.pumpWidget(ProviderScope(
      overrides: [
        app_shell.appProvider.overrideWith((ref) => controller),
      ],
      child: const MaterialApp(home: app_shell.ResultScreen()),
    ));

    expect(find.text('场景'), findsOneWidget);
    expect(find.text('闲聊片段'), findsOneWidget);
    expect(find.text('平台'), findsNothing);
    expect(find.text('关系'), findsNothing);
    expect(find.text('最后一句'), findsNothing);
    expect(find.text('情绪'), findsNothing);
    expect(find.text('风险'), findsNothing);
    expect(find.text('未知'), findsNothing);
    expect(find.text('候选回复 1'), findsOneWidget);
    expect(find.text('已复制，可以回聊天 App 粘贴'), findsNothing);
  });

  test('result copied text ignores stale local copies from older responses',
      () {
    final app = AppController();
    final response = ChatReplyResponse(
      sceneSummary: '新结果',
      replies: [
        ReplySuggestion(styleLabel: '自然', text: '新的回复', reason: '测试'),
      ],
    );

    expect(
      app_shell.resultCopiedTextFor(app, response, '旧的回复'),
      isNull,
    );
    expect(
      app_shell.resultCopiedTextFor(app, response, ' 新的回复 '),
      '新的回复',
    );
  });

  test('result copied text ignores noisy copied markers', () {
    final app = AppController()
      ..currentRecordId = 'current'
      ..history = [
        GenerationRecord(
          id: 'current',
          inputType: ChatInputType.text,
          sceneSummary: '旧结果',
          selectedStyleName: '自然',
          copiedReply: '未知',
          replies: [
            ReplySuggestion(styleLabel: '自然', text: '未知', reason: ''),
          ],
          createdAt: DateTime(2026, 1, 1),
        ),
      ];
    final noisyResponse = ChatReplyResponse(
      sceneSummary: '新结果',
      replies: [
        ReplySuggestion(styleLabel: '自然', text: '未知', reason: '占位'),
        ReplySuggestion(styleLabel: '自然', text: '  ', reason: '空白'),
      ],
    );

    expect(
      app_shell.resultCopiedTextFor(app, noisyResponse, '未知'),
      isNull,
    );

    final cleanResponse = ChatReplyResponse(
      sceneSummary: '新结果',
      replies: [
        ReplySuggestion(styleLabel: '自然', text: '可以呀', reason: '测试'),
      ],
    );

    expect(
      app_shell.resultCopiedTextFor(app, cleanResponse, ' 可以呀 '),
      '可以呀',
    );
  });

  testWidgets('result screen reflects native copied reply history adoption',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final store = FakeStore();
    final controller = AppController(store: store, api: MetadataApi());

    await controller.generateText('对方：晚上吃啥', ChatStyle.defaultStyle, '别太主动');
    await controller.markNativeCopiedReply('看你想吃啥');

    await tester.pumpWidget(ProviderScope(
      overrides: [
        app_shell.appProvider.overrideWith((ref) => controller),
      ],
      child: const MaterialApp(home: app_shell.ResultScreen()),
    ));

    expect(find.text('已复制首条'), findsOneWidget);
    expect(find.text('已复制，可以回聊天 App 粘贴'), findsOneWidget);
    expect(find.text('看你想吃啥'), findsWidgets);
  });

  testWidgets('result screen does not mark copied when clipboard fails',
      (tester) async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        throw PlatformException(code: 'clipboard', message: '剪贴板不可用');
      }
      return null;
    });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });
    final store = FakeStore();
    final controller = AppController(store: store)
      ..currentInputType = ChatInputType.text
      ..currentStyle = ChatStyle.defaultStyle
      ..currentTextInput = '对方：今晚有空吗'
      ..currentResponse = ChatReplyResponse(
        sceneSummary: '约时间',
        replies: [
          ReplySuggestion(styleLabel: '自然', text: '今晚可以', reason: '顺接'),
        ],
      );

    await tester.pumpWidget(ProviderScope(
      overrides: [
        app_shell.appProvider.overrideWith((ref) => controller),
      ],
      child: const MaterialApp(home: app_shell.ResultScreen()),
    ));

    await tester.tap(find.text('复制首条'));
    await tester.pump();

    expect(find.text('复制首条'), findsOneWidget);
    expect(find.text('已复制首条'), findsNothing);
    expect(find.text('已复制，可以回聊天 App 粘贴'), findsNothing);
    expect(controller.errorMessage, '复制失败：剪贴板不可用');
    expect(controller.history, isEmpty);
    expect(store.savedHistory, isEmpty);
  });

  test('deleting current history record clears stale record id', () async {
    SharedPreferences.setMockInitialValues({});
    final store = FakeStore();
    final app = AppController(store: store, api: MetadataApi());

    await app.generateText('对方：晚上吃啥', ChatStyle.defaultStyle, '别太主动');
    final deleted = app.history.single;
    app.selectHistoryRecord(deleted);

    await app.deleteHistory(deleted);

    expect(app.history, isEmpty);
    expect(app.selectedHistoryRecord, isNull);
    expect(app.currentRecordId, isNull);

    await app.copyReply(app.currentResponse!.replies.single);

    expect(app.history, hasLength(1));
    expect(app.currentRecordId, app.history.single.id);
    expect(app.history.single.sceneSummary, '约晚饭');
    expect(app.history.single.copiedReply, '看你想吃啥');
    expect(store.savedHistory.single.copiedReply, '看你想吃啥');
  });

  test('history delete clears legacy spaced record references', () async {
    SharedPreferences.setMockInitialValues({});
    final record = GenerationRecord(
      id: ' dirty-history ',
      inputType: ChatInputType.text,
      selectedStyleName: '自然',
      replies: [
        ReplySuggestion(styleLabel: '自然', text: '今晚可以', reason: '顺接'),
      ],
    );
    final app = AppController()
      ..history = [record]
      ..currentRecordId = 'dirty-history'
      ..selectedHistoryRecord = record;

    await app.deleteHistory(GenerationRecord(
      id: 'dirty-history',
      inputType: ChatInputType.text,
      selectedStyleName: '自然',
      replies: [
        ReplySuggestion(styleLabel: '自然', text: '今晚可以', reason: '顺接'),
      ],
    ));

    expect(app.history, isEmpty);
    expect(app.currentRecordId, isNull);
    expect(app.selectedHistoryRecord, isNull);
  });

  test('deleting unrelated history keeps active history references', () async {
    SharedPreferences.setMockInitialValues({});
    final active = GenerationRecord(
      id: 'active-record',
      inputType: ChatInputType.text,
      selectedStyleName: '自然',
      replies: [
        ReplySuggestion(styleLabel: '自然', text: '当前回复', reason: '测试'),
      ],
    );
    final removed = GenerationRecord(
      id: 'removed-record',
      inputType: ChatInputType.text,
      selectedStyleName: '自然',
      replies: [
        ReplySuggestion(styleLabel: '自然', text: '待删回复', reason: '测试'),
      ],
    );
    final app = AppController()
      ..history = [active, removed]
      ..currentRecordId = ' active-record '
      ..selectedHistoryRecord = active;

    await app.deleteHistory(removed);

    expect(app.history.map((record) => record.id), ['active-record']);
    expect(app.currentRecordId, active.id);
    expect(app.selectedHistoryRecord, same(active));
  });

  test('record selection adopts latest retained history instance', () {
    final stale = GenerationRecord(
      id: 'same-record',
      inputType: ChatInputType.text,
      selectedStyleName: '自然',
      copiedReply: '旧回复',
      replies: [
        ReplySuggestion(styleLabel: '自然', text: '旧', reason: '旧'),
      ],
    );
    final latest = GenerationRecord(
      id: 'same-record',
      inputType: ChatInputType.text,
      selectedStyleName: '自然',
      copiedReply: '新回复',
      replies: [
        ReplySuggestion(styleLabel: '自然', text: '新', reason: '新'),
      ],
    );
    final app = AppController()..history = [latest];

    app.selectHistoryRecord(stale);

    expect(app.selectedHistoryRecord, same(latest));
    expect(app.selectedHistoryRecord?.copiedReply, '新回复');
  });

  test('record selection adopts latest retained spaced history instance', () {
    final stale = GenerationRecord(
      id: 'same-record',
      inputType: ChatInputType.text,
      selectedStyleName: '自然',
      copiedReply: '旧回复',
      replies: [
        ReplySuggestion(styleLabel: '自然', text: '旧', reason: '旧'),
      ],
    );
    final latest = GenerationRecord(
      id: ' same-record ',
      inputType: ChatInputType.text,
      selectedStyleName: '自然',
      copiedReply: '新回复',
      replies: [
        ReplySuggestion(styleLabel: '自然', text: '新', reason: '新'),
      ],
    );
    final app = AppController()..history = [latest];

    app.selectHistoryRecord(stale);

    expect(app.selectedHistoryRecord, same(latest));
    expect(app.selectedHistoryRecord?.id, ' same-record ');
    expect(app.selectedHistoryRecord?.copiedReply, '新回复');
  });

  test('record selection clears missing history record like stale UI entries',
      () {
    final retained = GenerationRecord(
      id: 'retained-record',
      inputType: ChatInputType.text,
      selectedStyleName: '自然',
      replies: [
        ReplySuggestion(styleLabel: '自然', text: '当前回复', reason: '测试'),
      ],
    );
    final missing = GenerationRecord(
      id: 'missing-record',
      inputType: ChatInputType.text,
      selectedStyleName: '自然',
      replies: [
        ReplySuggestion(styleLabel: '自然', text: '旧回复', reason: '测试'),
      ],
    );
    final app = AppController()
      ..history = [retained]
      ..selectedHistoryRecord = retained;

    app.selectHistoryRecord(missing);

    expect(app.selectedHistoryRecord, isNull);
  });

  test('native quick overlay copied reply updates current history record',
      () async {
    SharedPreferences.setMockInitialValues({});
    final store = FakeStore();
    final app = AppController(store: store, api: MetadataApi());

    await app.generateText('对方：晚上吃啥', ChatStyle.defaultStyle, '别太主动');

    await app.markNativeCopiedReply('  看你想吃啥  ');

    expect(app.history.single.copiedReply, '看你想吃啥');
    expect(store.savedHistory.single.copiedReply, '看你想吃啥');
    expect(app.statusMessage, '已复制');
  });

  test('native quick overlay ignores non-reply copied text', () async {
    SharedPreferences.setMockInitialValues({});
    final store = FakeStore();
    final app = AppController(store: store, api: MetadataApi());

    await app.generateText('对方：晚上吃啥', ChatStyle.defaultStyle, '别太主动');

    await app.markNativeCopiedReply('模型失败，请稍后重试。');

    expect(app.history.single.copiedReply, isNull);
    expect(store.savedHistory.single.copiedReply, isNull);
    expect(app.statusMessage, isNull);
  });

  test('generation keeps last input for result regeneration', () async {
    SharedPreferences.setMockInitialValues({});
    final app = AppController(api: FakeApi());

    await app.generateText('你好', ChatStyle.defaultStyle, '自然一点');

    expect(app.canRegenerate, isTrue);
    expect(app.lastInput?.type, ChatInputType.text);
    expect(app.currentResponse?.replies.single.text, '收到');
  });

  test('regeneration refreshes stale person profile context', () async {
    SharedPreferences.setMockInitialValues({});
    final api = RecordingInputApi();
    final profile = PersonProfile(
      id: 'target',
      displayName: '小林',
      tonePreferences: const ['旧语气'],
    );
    final updated = PersonProfile(
      id: 'target',
      displayName: '小林',
      tonePreferences: const ['新语气'],
    );
    final app = AppController(api: api)..profiles = [profile];

    await app.generateText('对方：晚上吃啥', ChatStyle.defaultStyle, '自然一点',
        selectedProfileId: profile.id);

    expect(api.inputs.last.personProfileContext, contains('旧语气'));

    await app.saveProfile(updated);
    await app.regenerateLast();

    expect(api.inputs.last.personProfileContext, contains('新语气'));
    expect(api.inputs.last.personProfileContext, isNot(contains('旧语气')));

    await app.deleteProfile(updated);
    await app.regenerateLast();

    expect(api.inputs.last.personProfileContext, contains('暂无人物库记录'));
    expect(api.inputs.last.personProfileContext, isNot(contains('新语气')));
  });

  test('text generation sends prebuilt prompt contexts to api', () async {
    SharedPreferences.setMockInitialValues({});
    final api = RecordingInputApi();
    final profile = PersonProfile(
      id: 'target',
      displayName: '小林',
      tonePreferences: const ['少绕弯'],
    );
    final app = AppController(api: api)
      ..profiles = [profile]
      ..history = [
        GenerationRecord(
          inputType: ChatInputType.text,
          sceneSummary: '约饭',
          latestMessage: '晚上吃什么',
          selectedStyleName: '自然',
          copiedReply: '看你想吃啥',
          replies: [
            ReplySuggestion(styleLabel: '自然', text: '看你想吃啥', reason: ''),
          ],
        ),
      ];

    await app.generateText('对方：晚上吃什么', ChatStyle.defaultStyle, '自然一点',
        selectedProfileId: profile.id);

    expect(api.inputs.single.personProfileContext, contains('少绕弯'));
    expect(api.inputs.single.personalizationContext, contains('看你想吃啥'));
    expect(api.inputs.single.personalizationContext, contains('候选回复质量要求'));

    final flowSource = File('lib/core/app_state_reply_generation_flow.dart')
        .readAsStringSync();
    expect(
        flowSource,
        contains(
            'makePersonProfileContext(selectedProfileId: selectedProfileId)'));
    expect(flowSource,
        isNot(contains('??\n                makePersonProfileContext(),')));
  });

  test('text generation preserves source state for return-to-edit', () async {
    SharedPreferences.setMockInitialValues({});
    final style = ChatStyle.presets[1];
    final app = AppController(api: FakeApi())
      ..profiles = [
        PersonProfile(id: 'target', displayName: '小林'),
      ];

    await app.generateText('  对方：晚上吃啥  ', style, '  轻松一点  ',
        selectedProfileId: ' target ');

    expect(app.currentTextInput, '对方：晚上吃啥');
    expect(app.currentImagePath, isNull);
    expect(app.currentSelectedProfileId, 'target');
    expect(app.currentGoal, '轻松一点');
    expect(app.currentStyle, style);
    expect(app.lastInput?.text, '对方：晚上吃啥');
  });

  test('text generation treats placeholder goal as empty', () async {
    SharedPreferences.setMockInitialValues({});
    final api = RecordingInputApi();
    final app = AppController(api: api);

    await app.generateText('对方：晚上吃啥', ChatStyle.defaultStyle, '  未知  ');

    expect(api.inputs.single.userGoal, isNull);
    expect(app.currentGoal, isNull);
    expect(app.lastInput?.userGoal, isNull);
    expect(app.history.single.userGoal, isNull);
    expect(app.history.single.toJson()['userGoal'], isNull);
  });

  test('clearing editable text draft prevents return-to-edit resurrection',
      () async {
    SharedPreferences.setMockInitialValues({});
    final app = AppController(api: FakeApi());

    await app.generateText('对方：晚上吃啥', ChatStyle.presets[1], '轻松一点');

    app.clearEditableTextDraft();

    expect(app.currentInputType, ChatInputType.text);
    expect(app.currentTextInput, isNull);
    expect(app.currentGoal, '轻松一点');
    expect(app.lastInput, isNull);
    expect(app.canRegenerate, isFalse);
  });

  test('clearing editable text draft preserves image regeneration source', () {
    const payload = ImagePayload(
      base64: 'abc',
      mimeType: 'image/jpeg',
      width: 1,
      height: 1,
      sizeInBytes: 3,
    );
    final imageInput = ChatInput(
      type: ChatInputType.image,
      imagePayload: payload,
      selectedStyle: ChatStyle.defaultStyle,
    );
    final app = AppController()
      ..currentInputType = ChatInputType.text
      ..currentTextInput = null
      ..lastInput = imageInput;

    app.clearEditableTextDraft();

    expect(app.lastInput, same(imageInput));
    expect(app.canRegenerate, isTrue);
  });

  test('editable draft clears use type-specific source helper', () {
    final source =
        File('lib/core/app_state_editable_drafts.dart').readAsStringSync();

    expect(
        source, contains('bool _clearEditableDraftSource(ChatInputType type)'));
    expect(
      RegExp(r'_clearEditableDraftSource\(ChatInputType\.').allMatches(source),
      hasLength(2),
    );
    expect(source, contains('if (lastInput?.type == type)'));
  });

  test('empty text generation clears stale result before reporting error',
      () async {
    SharedPreferences.setMockInitialValues({});
    final app = AppController(api: InsightApi())
      ..profiles = [
        PersonProfile(id: 'target', displayName: '小林'),
      ];

    await app.generateText('你好', ChatStyle.defaultStyle, '自然一点');
    expect(app.currentGeneratedProfile, isNotNull);
    expect(app.currentRecordId, isNotNull);
    expect(app.lastInput, isNotNull);

    await app.generateText('   ', ChatStyle.defaultStyle, '  未知  ',
        selectedProfileId: ' target ');

    expect(app.currentResponse, isNull);
    expect(app.currentGeneratedProfile, isNull);
    expect(app.currentRecordId, isNull);
    expect(app.currentInputType, ChatInputType.text);
    expect(app.currentTextInput, isNull);
    expect(app.currentImagePath, isNull);
    expect(app.currentSelectedProfileId, 'target');
    expect(app.currentGoal, isNull);
    expect(app.lastInput, isNull);
    expect(app.canRegenerate, isFalse);
    expect(app.errorMessage, '请先输入聊天文本。');
  });

  test('failed generation clears stale current record id', () async {
    SharedPreferences.setMockInitialValues({});
    final api = DeferredConnectionApi();
    final app = AppController(api: api)
      ..currentResponse = ChatReplyResponse(
        sceneSummary: '旧结果',
        replies: [
          ReplySuggestion(styleLabel: '自然', text: '旧回复', reason: '测试'),
        ],
      )
      ..currentRecordId = 'old-record'
      ..history = [
        GenerationRecord(
          id: 'old-record',
          inputType: ChatInputType.text,
          sceneSummary: '旧结果',
          selectedStyleName: '自然',
          replies: [
            ReplySuggestion(styleLabel: '自然', text: '旧回复', reason: '测试'),
          ],
        ),
      ];

    final pending = app.generateText('对方：新消息', ChatStyle.defaultStyle, '新目标');
    await api.generateStarted.future;

    expect(app.currentResponse, isNull);
    expect(app.currentRecordId, isNull);

    api.generateCompleter.completeError(AppException('模型失败'));
    await pending;

    expect(app.currentResponse, isNull);
    expect(app.currentRecordId, isNull);
    expect(app.history.single.sceneSummary, '旧结果');
    expect(app.errorMessage, '模型失败');
  });

  test('generation start paths share current result clearing helper', () {
    final runtimeSource =
        File('lib/core/app_state_runtime_helpers.dart').readAsStringSync();
    final textSource =
        File('lib/core/app_state_text_generation.dart').readAsStringSync();
    final imageSource =
        File('lib/core/app_state_image_generation.dart').readAsStringSync();
    final flowSource = File('lib/core/app_state_reply_generation_flow.dart')
        .readAsStringSync();
    final localDataSource =
        File('lib/core/app_state_local_data.dart').readAsStringSync();

    expect(runtimeSource, contains('void _clearCurrentResultReferences()'));
    expect(runtimeSource, contains('void _finishGenerationOperation({'));
    expect(runtimeSource, contains('int _beginGenerationOperation()'));
    expect(runtimeSource, contains('void _invalidateGenerationOperation()'));
    expect(runtimeSource, contains('bool _isCurrentGeneration('));
    expect(textSource, contains('_clearCurrentResultReferences();'));
    expect(imageSource, contains('_clearCurrentResultReferences();'));
    expect(flowSource, contains('_clearCurrentResultReferences();'));
    expect(textSource, contains('_invalidateGenerationOperation();'));
    expect(imageSource, contains('_beginGenerationOperation();'));
    expect(flowSource, contains('_beginGenerationOperation();'));
    expect(imageSource, contains('_finishGenerationOperation('));
    expect(flowSource, contains('_finishGenerationOperation('));
    expect(localDataSource, contains('_clearCurrentResultReferences();'));
    expect(textSource, isNot(contains('currentResponse = null')));
    expect(textSource, isNot(contains('_generationRevision += 1')));
    expect(imageSource, isNot(contains('++_generationRevision')));
    expect(imageSource, isNot(contains('currentGeneratedProfile = null')));
    expect(flowSource, isNot(contains('++_generationRevision')));
    expect(flowSource,
        isNot(contains('generationRevision == _generationRevision')));
    expect(flowSource, isNot(contains('currentRecordId = null')));
    expect(
        flowSource, isNot(contains('_finishBusyOperation(activeBusyRevision')));
    expect(localDataSource, isNot(contains('currentResponse = null')));
  });

  test('generation start paths share current source state helpers', () {
    final runtimeSource =
        File('lib/core/app_state_runtime_helpers.dart').readAsStringSync();
    final textSource =
        File('lib/core/app_state_text_generation.dart').readAsStringSync();
    final imageSource =
        File('lib/core/app_state_image_generation.dart').readAsStringSync();
    final flowSource = File('lib/core/app_state_reply_generation_flow.dart')
        .readAsStringSync();
    final regenerationSource =
        File('lib/core/app_state_regeneration.dart').readAsStringSync();

    expect(runtimeSource, contains('void _setCurrentGenerationSource({'));
    expect(runtimeSource, contains('void _setPendingGenerationSource({'));
    expect(runtimeSource, contains('currentGoal = optionalSanitizedGoal('));
    expect(runtimeSource, contains('_normalizedGenerationTextInput('));
    expect(runtimeSource, contains('_normalizedGenerationImagePath('));
    expect(textSource, contains('_setPendingGenerationSource('));
    expect(
        textSource, contains('final cleanedText = cleanChatTextInput(text);'));
    expect(imageSource, contains('_setPendingGenerationSource('));
    expect(flowSource, contains('_setCurrentGenerationSource('));
    expect(regenerationSource,
        contains('selectedProfileId: currentSelectedProfileId'));
    expect(regenerationSource, contains('imagePath: currentImagePath'));
    expect(regenerationSource, contains('bool get canRegenerate =>'));
    expect(regenerationSource, contains('&& !_isReplyGenerationBusy'));
    expect(regenerationSource,
        contains('if (input == null || isBusy || _isReplyGenerationBusy)'));
    expect(textSource, isNot(contains('currentTextInput = trimmed')));
    expect(textSource, isNot(contains('text.trim()')));
    expect(imageSource, isNot(contains('currentImagePath = imagePath;')));
    expect(flowSource, isNot(contains('lastInput = input;')));
  });

  test('text generation button follows readiness, busy, and content state', () {
    const ready = GenerateAPIReadiness(
      config: APIConfig.defaults,
      hasAPIKey: true,
      capability: GenerateAPICapability.text,
    );
    const missingKey = GenerateAPIReadiness(
      config: APIConfig.defaults,
      hasAPIKey: false,
      capability: GenerateAPICapability.text,
    );

    expect(
      app_shell.canSubmitTextGeneration(
          readiness: ready, isBusy: false, text: '  对方：你好  '),
      isTrue,
    );
    expect(
      app_shell.canSubmitTextGeneration(
          readiness: ready, isBusy: false, text: '   '),
      isFalse,
    );
    expect(
      app_shell.canSubmitTextGeneration(
          readiness: ready, isBusy: true, text: '对方：你好'),
      isFalse,
    );
    expect(
      app_shell.canSubmitTextGeneration(
          readiness: missingKey, isBusy: false, text: '对方：你好'),
      isFalse,
    );
  });

  test('image generation button follows readiness, image, and busy state', () {
    const ready = GenerateAPIReadiness(
      config: APIConfig.defaults,
      hasAPIKey: true,
      capability: GenerateAPICapability.vision,
    );
    const missingKey = GenerateAPIReadiness(
      config: APIConfig.defaults,
      hasAPIKey: false,
      capability: GenerateAPICapability.vision,
    );
    void generate() {}

    expect(
      app_shell.canSubmitImageGeneration(
        readiness: ready,
        isBusy: false,
        imagePath: '/tmp/chat.jpg',
        onGenerate: generate,
      ),
      isTrue,
    );
    expect(
      app_shell.canSubmitImageGeneration(
        readiness: ready,
        isBusy: false,
        imagePath: '   ',
        onGenerate: generate,
      ),
      isFalse,
    );
    expect(
      app_shell.canSubmitImageGeneration(
        readiness: ready,
        isBusy: false,
        imagePath: null,
        onGenerate: generate,
      ),
      isFalse,
    );
    expect(
      app_shell.canSubmitImageGeneration(
        readiness: ready,
        isBusy: true,
        imagePath: '/tmp/chat.jpg',
        onGenerate: generate,
      ),
      isFalse,
    );
    expect(
      app_shell.canSubmitImageGeneration(
        readiness: ready,
        isBusy: false,
        imagePath: '/tmp/chat.jpg',
        onGenerate: null,
      ),
      isFalse,
    );
    expect(
      app_shell.canSubmitImageGeneration(
        readiness: missingKey,
        isBusy: false,
        imagePath: '/tmp/chat.jpg',
        onGenerate: generate,
      ),
      isFalse,
    );
  });

  test('moment profile analysis button follows readiness busy and image state',
      () {
    const ready = GenerateAPIReadiness(
      config: APIConfig.defaults,
      hasAPIKey: true,
      capability: GenerateAPICapability.vision,
    );
    const missingKey = GenerateAPIReadiness(
      config: APIConfig.defaults,
      hasAPIKey: false,
      capability: GenerateAPICapability.vision,
    );

    expect(
      app_shell.canSubmitMomentProfileAnalysis(
        readiness: ready,
        isBusy: false,
        imagePath: ' /tmp/moment.jpg ',
      ),
      isTrue,
    );
    expect(
      app_shell.canSubmitMomentProfileAnalysis(
        readiness: ready,
        isBusy: false,
        imagePath: '   ',
      ),
      isFalse,
    );
    expect(
      app_shell.canSubmitMomentProfileAnalysis(
        readiness: ready,
        isBusy: true,
        imagePath: '/tmp/moment.jpg',
      ),
      isFalse,
    );
    expect(
      app_shell.canSubmitMomentProfileAnalysis(
        readiness: missingKey,
        isBusy: false,
        imagePath: '/tmp/moment.jpg',
      ),
      isFalse,
    );
  });

  test('successful image generation deletes only owned transient screenshot',
      () async {
    SharedPreferences.setMockInitialValues({});
    final dir = await Directory.systemTemp.createTemp('ai-reply-generate-');
    final owned = File('${dir.path}/clipboard-image-test.img');
    final picked = File('${dir.path}/picked-image.jpg');
    final source = img.Image(width: 24, height: 12);
    img.fill(source, color: img.ColorRgb8(80, 120, 160));
    final bytes = img.encodeJpg(source);
    await owned.writeAsBytes(bytes);
    await picked.writeAsBytes(bytes);
    final quick = File('${dir.path}/floating-capture-test.jpg');
    await quick.writeAsBytes(bytes);
    final app = AppController(
      api: FakeApi(),
      temporaryDirectoryProvider: () async => dir,
    );

    try {
      await app.generateImage(owned.path, ChatStyle.defaultStyle, '');
      expect(owned.existsSync(), isFalse);
      expect(app.lastInput?.imagePayload, isNotNull);
      expect(app.currentImagePath, isNull);

      await app.generateImage(picked.path, ChatStyle.defaultStyle, '');
      expect(picked.existsSync(), isTrue);
      expect(app.currentImagePath, picked.path);

      app.setQuickImagePath(quick.path);
      await app.generateImage(quick.path, ChatStyle.defaultStyle, '');
      expect(quick.existsSync(), isFalse);
      expect(app.currentImagePath, isNull);
      expect(app.quickImagePath, isNull);

      final spacedQuick = File('${dir.path}/floating-capture-spaced.jpg');
      await spacedQuick.writeAsBytes(bytes);
      app.quickImagePath = '  ${spacedQuick.path}  ';
      await app.generateImage(spacedQuick.path, ChatStyle.defaultStyle, '');
      expect(spacedQuick.existsSync(), isFalse);
      expect(app.currentImagePath, isNull);
      expect(app.quickImagePath, isNull);
    } finally {
      if (await dir.exists()) await dir.delete(recursive: true);
    }
  });

  test('image generation stays busy while preparing payload and blocks overlap',
      () async {
    SharedPreferences.setMockInitialValues({});
    final api = DeferredConnectionApi();
    final imageService = DeferredPayloadImageService();
    final app = AppController(api: api, imageService: imageService);
    const payload = ImagePayload(
      base64: 'abc',
      mimeType: 'image/jpeg',
      width: 1,
      height: 1,
      sizeInBytes: 3,
    );

    final first = app.generateImage(
      '/tmp/first-chat.jpg',
      ChatStyle.defaultStyle,
      '第一目标',
    );
    await imageService.started.future;

    expect(app.isBusy, isTrue);
    expect(app.currentImagePath, '/tmp/first-chat.jpg');
    expect(app.currentGoal, '第一目标');

    await app.generateImage(
      '/tmp/second-chat.jpg',
      ChatStyle.presets[1],
      '第二目标',
    );

    expect(imageService.prepareCalls, 1);
    expect(imageService.preparedPath, '/tmp/first-chat.jpg');
    expect(app.currentImagePath, '/tmp/first-chat.jpg');
    expect(app.currentGoal, '第一目标');

    imageService.completer.complete(payload);
    await api.generateStarted.future;

    expect(app.isBusy, isTrue);
    expect(api.generatedInput?.imagePayload, payload);

    api.generateCompleter.complete(ChatReplyResponse(
      sceneSummary: '图片生成',
      replies: [
        ReplySuggestion(styleLabel: '自然', text: '收到', reason: '测试'),
      ],
    ));
    await first;

    expect(app.isBusy, isFalse);
    expect(app.currentResponse?.sceneSummary, '图片生成');
    expect(app.history, hasLength(1));
  });

  test('empty image generation clears stale result before reporting error',
      () async {
    SharedPreferences.setMockInitialValues({});
    final imageService = DeferredPayloadImageService();
    final style = ChatStyle.presets[1];
    final app = AppController(imageService: imageService)
      ..profiles = [
        PersonProfile(id: 'target', displayName: '小林'),
      ]
      ..currentResponse = ChatReplyResponse(
        sceneSummary: '旧结果',
        replies: [
          ReplySuggestion(styleLabel: '自然', text: '旧回复', reason: '旧原因'),
        ],
      )
      ..currentRecordId = 'old-record'
      ..currentImagePath = '/tmp/old.jpg'
      ..currentGoal = '旧目标'
      ..isQuickReplySession = true;

    await app.generateImage('   ', style, '  新目标  ',
        selectedProfileId: ' target ');

    expect(imageService.prepareCalls, 0);
    expect(app.currentResponse, isNull);
    expect(app.currentRecordId, isNull);
    expect(app.currentInputType, ChatInputType.image);
    expect(app.currentImagePath, isNull);
    expect(app.currentSelectedProfileId, 'target');
    expect(app.currentGoal, '新目标');
    expect(app.currentStyle, style);
    expect(app.isBusy, isFalse);
    expect(app.isQuickReplySession, isFalse);
    expect(app.errorMessage, '请先选择截图。');
    expect(app.statusMessage, isNull);
  });

  test('image generation prepares prompt context while payload is pending',
      () async {
    SharedPreferences.setMockInitialValues({});
    final api = DeferredConnectionApi();
    final imageService = DeferredPayloadImageService();
    final oldProfile = PersonProfile(
      id: 'target',
      displayName: '小林',
      tonePreferences: const ['旧语气'],
    );
    final updatedProfile = PersonProfile(
      id: 'target',
      displayName: '小林',
      tonePreferences: const ['新语气'],
    );
    final app = AppController(
      store: FakeStore(),
      api: api,
      imageService: imageService,
    )..profiles = [oldProfile];
    const payload = ImagePayload(
      base64: 'abc',
      mimeType: 'image/jpeg',
      width: 1,
      height: 1,
      sizeInBytes: 3,
    );

    final pending = app.generateImage(
      '/tmp/chat.jpg',
      ChatStyle.defaultStyle,
      '自然一点',
      selectedProfileId: 'target',
    );
    await imageService.started.future;
    await Future<void>.delayed(Duration.zero);

    app.profiles = [updatedProfile];
    imageService.completer.complete(payload);
    await api.generateStarted.future;

    expect(api.generatedInput?.personProfileContext, contains('旧语气'));
    expect(api.generatedInput?.personProfileContext, isNot(contains('新语气')));

    api.generateCompleter.complete(ChatReplyResponse(
      sceneSummary: '图片生成',
      replies: [
        ReplySuggestion(styleLabel: '自然', text: '收到', reason: '测试'),
      ],
    ));
    await pending;
  });

  test('image generation preserves source state for return-to-edit', () async {
    SharedPreferences.setMockInitialValues({});
    final dir = await Directory.systemTemp.createTemp('ai-reply-image-edit-');
    final picked = File('${dir.path}/picked-image.jpg');
    final source = img.Image(width: 24, height: 12);
    img.fill(source, color: img.ColorRgb8(80, 120, 160));
    await picked.writeAsBytes(img.encodeJpg(source));
    final style = ChatStyle.presets[2];
    final app = AppController(api: FakeApi())
      ..profiles = [
        PersonProfile(id: 'target', displayName: '小林'),
      ];

    try {
      await app.generateImage(picked.path, style, '  轻松一点  ',
          selectedProfileId: ' target ');

      expect(app.currentTextInput, isNull);
      expect(app.currentImagePath, picked.path);
      expect(app.currentSelectedProfileId, 'target');
      expect(app.currentGoal, '轻松一点');
      expect(app.currentStyle, style);
      expect(app.lastInput?.imagePayload, isNotNull);
    } finally {
      if (await dir.exists()) await dir.delete(recursive: true);
    }
  });

  test('image generation normalizes source path for runtime state', () async {
    SharedPreferences.setMockInitialValues({});
    final imageService = DeferredPayloadImageService();
    final app = AppController(api: FakeApi(), imageService: imageService);
    const payload = ImagePayload(
      base64: 'abc',
      mimeType: 'image/jpeg',
      width: 1,
      height: 1,
      sizeInBytes: 3,
    );

    final pending = app.generateImage(
      '  /tmp/chat-source.jpg  ',
      ChatStyle.defaultStyle,
      '自然一点',
    );
    await imageService.started.future;

    expect(imageService.preparedPath, '/tmp/chat-source.jpg');
    expect(app.currentImagePath, '/tmp/chat-source.jpg');

    imageService.completer.complete(payload);
    await pending;

    expect(app.currentImagePath, '/tmp/chat-source.jpg');
  });

  test('clearing editable image draft preserves picked files only', () async {
    SharedPreferences.setMockInitialValues({});
    final dir = await Directory.systemTemp.createTemp('ai-reply-image-clear-');
    final owned = File('${dir.path}/clipboard-image-edit-clear.jpg');
    final picked = File('${dir.path}/picked-image.jpg');
    const payload = ImagePayload(
      base64: 'abc',
      mimeType: 'image/jpeg',
      width: 1,
      height: 1,
      sizeInBytes: 3,
    );

    try {
      await owned.writeAsBytes([1, 2, 3]);
      await picked.writeAsBytes([4, 5, 6]);
      final pickedApp = AppController(api: FakeApi())
        ..currentInputType = ChatInputType.image
        ..currentImagePath = picked.path
        ..lastInput = ChatInput(
          type: ChatInputType.image,
          imagePayload: payload,
          selectedStyle: ChatStyle.defaultStyle,
        );

      await pickedApp.clearEditableImageDraft();

      expect(picked.existsSync(), isTrue);
      expect(pickedApp.currentImagePath, isNull);
      expect(pickedApp.lastInput, isNull);
      expect(pickedApp.canRegenerate, isFalse);

      final ownedApp = AppController(
        api: FakeApi(),
        temporaryDirectoryProvider: () async => dir,
      )
        ..currentInputType = ChatInputType.image
        ..currentImagePath = owned.path
        ..lastInput = ChatInput(
          type: ChatInputType.image,
          imagePayload: payload,
          selectedStyle: ChatStyle.defaultStyle,
        );

      await ownedApp.clearEditableImageDraft();

      expect(owned.existsSync(), isFalse);
      expect(ownedApp.currentImagePath, isNull);
      expect(ownedApp.lastInput, isNull);
      expect(ownedApp.canRegenerate, isFalse);
    } finally {
      if (await dir.exists()) await dir.delete(recursive: true);
    }
  });

  test('image generation reports preparation errors through app state',
      () async {
    SharedPreferences.setMockInitialValues({});
    final missing = File(
        '${Directory.systemTemp.path}/ai-reply-missing-${DateTime.now().microsecondsSinceEpoch}.jpg');
    final app = AppController(api: FakeApi())
      ..currentResponse = ChatReplyResponse(
        sceneSummary: '旧结果',
        replies: [
          ReplySuggestion(styleLabel: '自然', text: '旧回复', reason: '测试'),
        ],
      )
      ..currentRecordId = 'old-record'
      ..currentTextInput = '旧文本'
      ..currentGoal = '旧目标'
      ..lastInput = ChatInput(
        type: ChatInputType.text,
        text: '旧文本',
        selectedStyle: ChatStyle.defaultStyle,
      );

    await app.generateImage(missing.path, ChatStyle.defaultStyle, '新目标');

    expect(app.currentResponse, isNull);
    expect(app.currentRecordId, isNull);
    expect(app.currentInputType, ChatInputType.image);
    expect(app.currentTextInput, isNull);
    expect(app.currentImagePath, missing.path);
    expect(app.currentGoal, '新目标');
    expect(app.lastInput, isNull);
    expect(app.canRegenerate, isFalse);
    expect(app.errorMessage, contains('无法读取所选图片'));
    expect(app.isBusy, isFalse);
  });

  test('successful moment analysis deletes only owned transient screenshot',
      () async {
    SharedPreferences.setMockInitialValues({});
    final dir = await Directory.systemTemp.createTemp('ai-reply-moment-');
    final owned = File('${dir.path}/clipboard-image-moment.img');
    final picked = File('${dir.path}/picked-moment.jpg');
    final source = img.Image(width: 24, height: 12);
    img.fill(source, color: img.ColorRgb8(120, 80, 160));
    final bytes = img.encodeJpg(source);
    await owned.writeAsBytes(bytes);
    await picked.writeAsBytes(bytes);
    final app = AppController(
      api: FakeApi(),
      temporaryDirectoryProvider: () async => dir,
    );

    try {
      await app.analyzeMoment(owned.path);
      expect(owned.existsSync(), isFalse);
      expect(app.currentMomentAnalysis?.visibleName, '小林');
      expect(app.currentMomentProfile?.displayName, '小林');

      await app.analyzeMoment(picked.path);
      expect(picked.existsSync(), isTrue);
      expect(app.currentMomentProfile?.displayName, '小林');
    } finally {
      if (await dir.exists()) await dir.delete(recursive: true);
    }
  });

  test('failed moment analysis clears stale success feedback', () async {
    SharedPreferences.setMockInitialValues({});
    final dir = await Directory.systemTemp.createTemp('ai-reply-moment-fail-');
    final imageFile = File('${dir.path}/picked-moment.jpg');
    final source = img.Image(width: 16, height: 16);
    img.fill(source, color: img.ColorRgb8(120, 80, 160));
    await imageFile.writeAsBytes(img.encodeJpg(source));
    final app = AppController(api: FailingMomentApi())
      ..statusMessage = '已分析并写入人物库';

    try {
      await app.analyzeMoment(imageFile.path);

      expect(app.currentMomentAnalysis, isNull);
      expect(app.currentMomentProfile, isNull);
      expect(app.statusMessage, isNull);
      expect(app.errorMessage, '画像失败');
      expect(app.isBusy, isFalse);
    } finally {
      app.dispose();
      if (await dir.exists()) await dir.delete(recursive: true);
    }
  });

  test('empty moment analysis clears stale result before reporting error',
      () async {
    SharedPreferences.setMockInitialValues({});
    final imageService = DeferredPayloadImageService();
    final app = AppController(imageService: imageService)
      ..currentMomentAnalysis = const MomentProfileAnalysis(
        sceneSummary: '旧动态',
        visibleName: '旧人物',
      )
      ..currentMomentProfile = PersonProfile(displayName: '旧人物')
      ..statusMessage = '已分析并写入人物库';

    await app.analyzeMoment('   ');

    expect(imageService.prepareCalls, 0);
    expect(app.currentMomentAnalysis, isNull);
    expect(app.currentMomentProfile, isNull);
    expect(app.statusMessage, isNull);
    expect(app.errorMessage, '请先选择动态截图。');
    expect(app.isBusy, isFalse);
  });

  test('moment analysis merges into selected profile like iOS', () async {
    SharedPreferences.setMockInitialValues({});
    final dir = await Directory.systemTemp.createTemp('ai-reply-target-');
    final imageFile = File('${dir.path}/picked-target.jpg');
    final source = img.Image(width: 24, height: 12);
    img.fill(source, color: img.ColorRgb8(80, 160, 120));
    await imageFile.writeAsBytes(img.encodeJpg(source));
    final target = PersonProfile(
      id: 'target',
      displayName: '目标人物',
      aliases: const ['旧别名'],
      relationship: '朋友',
    );
    final app = AppController(api: FakeApi())..profiles = [target];

    try {
      await app.analyzeMoment(imageFile.path, target: target);

      expect(app.profiles, hasLength(1));
      expect(app.profiles.single.displayName, '目标人物');
      expect(app.profiles.single.aliases, containsAll(['旧别名', '小林']));
      expect(app.profiles.single.relationship, '朋友');
      expect(app.currentMomentProfile?.id, 'target');
      expect(app.currentMomentProfile?.displayName, '目标人物');
    } finally {
      if (await dir.exists()) await dir.delete(recursive: true);
    }
  });

  test('moment analysis sends only selected target context', () async {
    SharedPreferences.setMockInitialValues({});
    final dir =
        await Directory.systemTemp.createTemp('ai-reply-moment-context-');
    final imageFile = File('${dir.path}/picked-context.jpg');
    final source = img.Image(width: 24, height: 12);
    img.fill(source, color: img.ColorRgb8(100, 110, 180));
    await imageFile.writeAsBytes(img.encodeJpg(source));
    final api = RecordingMomentContextApi();
    final target = PersonProfile(
      id: 'target',
      displayName: '目标人物',
      relationship: '朋友',
    );
    final recent = PersonProfile(
      id: 'recent',
      displayName: '最近人物',
      relationship: '同事',
    );
    final app = AppController(api: api)..profiles = [recent, target];

    try {
      await app.analyzeMoment(imageFile.path);
      await app.analyzeMoment(imageFile.path, target: target);

      expect(api.personContexts.first, isNull);
      expect(api.personContexts.last, target.summaryForPrompt);
      expect(api.personContexts.last, isNot(contains('最近人物')));
    } finally {
      if (await dir.exists()) await dir.delete(recursive: true);
    }
  });

  test('moment analysis returns updated profile after profile list resort',
      () async {
    SharedPreferences.setMockInitialValues({});
    final dir = await Directory.systemTemp.createTemp('ai-reply-resort-');
    final imageFile = File('${dir.path}/picked-resort.jpg');
    final source = img.Image(width: 24, height: 12);
    img.fill(source, color: img.ColorRgb8(80, 160, 120));
    await imageFile.writeAsBytes(img.encodeJpg(source));
    final other = PersonProfile(
      id: 'other',
      displayName: '阿周',
      updatedAt: DateTime(2026, 1, 4),
    );
    final target = PersonProfile(
      id: 'target',
      displayName: '小林',
      updatedAt: DateTime(2026, 1, 1),
    );
    final app = AppController(api: FakeApi())..profiles = [other, target];

    try {
      await app.analyzeMoment(imageFile.path);

      expect(app.profiles.first.id, 'target');
      expect(app.currentMomentProfile?.id, 'target');
      expect(app.currentMomentProfile?.displayName, '小林');
    } finally {
      if (await dir.exists()) await dir.delete(recursive: true);
    }
  });

  test('moment analysis without visible name still creates fallback profile',
      () async {
    SharedPreferences.setMockInitialValues({});
    final dir = await Directory.systemTemp.createTemp('ai-reply-nameless-');
    final imageFile = File('${dir.path}/picked-nameless.jpg');
    final source = img.Image(width: 24, height: 12);
    img.fill(source, color: img.ColorRgb8(160, 120, 80));
    await imageFile.writeAsBytes(img.encodeJpg(source));
    final app = AppController(api: NamelessMomentApi());

    try {
      await app.analyzeMoment(imageFile.path);

      expect(app.profiles.single.displayName, '朋友圈对象');
      expect(app.currentMomentAnalysis?.sceneSummary, '无昵称动态');
      expect(app.currentMomentProfile?.displayName, '朋友圈对象');
    } finally {
      if (await dir.exists()) await dir.delete(recursive: true);
    }
  });

  test('clearing moment result removes stale analysis and saved profile', () {
    final app = AppController()
      ..currentMomentAnalysis = const MomentProfileAnalysis(
        sceneSummary: '旧动态分析',
        visibleName: '旧人物',
      )
      ..currentMomentProfile = PersonProfile(displayName: '旧人物');

    app.clearMomentResult();

    expect(app.currentMomentAnalysis, isNull);
    expect(app.currentMomentProfile, isNull);
  });

  test('moment analysis clear paths share runtime helper', () {
    final runtimeSource =
        File('lib/core/app_state_runtime_helpers.dart').readAsStringSync();
    final momentSource =
        File('lib/core/app_state_moment_analysis.dart').readAsStringSync();
    final localDataSource =
        File('lib/core/app_state_local_data.dart').readAsStringSync();

    expect(runtimeSource, contains('bool _clearMomentAnalysisReferences()'));
    expect(runtimeSource, contains('int _beginMomentAnalysisOperation()'));
    expect(runtimeSource, contains('_clearMomentAnalysisReferences();'));
    expect(runtimeSource, contains('bool _isCurrentMomentAnalysisOperation({'));
    expect(
        runtimeSource, contains('void _invalidateMomentAnalysisOperation()'));
    expect(momentSource, contains('_beginMomentAnalysisOperation();'));
    expect(momentSource, contains('if (isBusy) return;'));
    expect(momentSource, contains('_isCurrentMomentAnalysisOperation('));
    expect(momentSource, contains('_invalidateMomentAnalysisOperation();'));
    expect(momentSource,
        contains('if (!_clearMomentAnalysisReferences()) return'));
    expect(localDataSource, contains('_clearMomentAnalysisReferences();'));
    expect(momentSource, isNot(contains('currentMomentAnalysis = null')));
    expect(localDataSource, isNot(contains('currentMomentAnalysis = null')));
    expect(momentSource, isNot(contains('++_momentAnalysisRevision')));
    expect(momentSource, isNot(contains('_momentAnalysisRevision += 1')));
  });

  testWidgets('moment profile page starts without stale global analysis',
      (tester) async {
    final controller = AppController(store: FakeStore())
      ..currentMomentAnalysis = const MomentProfileAnalysis(
        sceneSummary: '旧动态分析',
        visibleName: '旧人物',
      )
      ..currentMomentProfile = PersonProfile(displayName: '旧人物');

    await tester.pumpWidget(ProviderScope(
      overrides: [
        app_shell.appProvider.overrideWith((ref) => controller),
      ],
      child: const MaterialApp(home: app_shell.MomentProfileScreen()),
    ));

    expect(controller.currentMomentAnalysis, isNull);
    expect(controller.currentMomentProfile, isNull);
    expect(find.byType(app_shell.MomentAnalysisCard), findsNothing);
  });

  testWidgets('moment analysis card cleans noisy presentation values',
      (tester) async {
    const analysis = MomentProfileAnalysis(
      sceneSummary: ' ',
      sourcePlatform: '未知',
      visibleName: ' ',
      relationshipGuess: '未知',
      personalityTraits: [' 稳 ', '稳', '未知', ' '],
      innerNeeds: ['未知'],
      keyPersonPoints: [' 关键线索 '],
      momentsInsights: [' 常发工作动态 ', '未知'],
      communicationAdvice: ['未知', '少追问', '少追问'],
      boundaries: ['未知'],
      stableFacts: ['喜欢提前确认', '喜欢提前确认', '未知'],
      updateReason: '未知',
    );

    expect(analysis.profileDisplayName(null), '朋友圈对象');
    expect(analysis.displayInfoLines, [
      ('总结', '已从截图提取人物画像。'),
      ('置信度', '40%'),
      ('新增线索', '5 条'),
      ('性格', '稳'),
      ('关键点', '关键线索'),
      ('朋友圈观察', '常发工作动态'),
      ('建议', '少追问'),
      ('事实', '喜欢提前确认'),
    ]);

    await tester.pumpWidget(const ProviderScope(
      child: MaterialApp(
        home: Scaffold(
          body: app_shell.MomentAnalysisCard(analysis: analysis),
        ),
      ),
    ));

    expect(find.text('朋友圈对象'), findsOneWidget);
    expect(find.text('已从截图提取人物画像。'), findsOneWidget);
    expect(find.text('平台'), findsNothing);
    expect(find.text('昵称'), findsNothing);
    expect(find.text('关系'), findsNothing);
    expect(find.text('依据'), findsNothing);
    expect(find.text('未知'), findsNothing);
    expect(find.text('新增线索'), findsOneWidget);
    expect(find.text('5 条'), findsOneWidget);
    expect(find.text('稳'), findsOneWidget);
    expect(find.text('关键线索'), findsOneWidget);
    expect(find.text('朋友圈观察'), findsOneWidget);
    expect(find.text('常发工作动态'), findsOneWidget);
    expect(find.text('少追问'), findsOneWidget);
    expect(find.text('喜欢提前确认'), findsOneWidget);
  });

  testWidgets('moment profile target changes clear stale global feedback',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final controller = AppController(store: FakeStore())
      ..profiles = [
        PersonProfile(id: 'target', displayName: '小林'),
      ];

    await tester.pumpWidget(ProviderScope(
      overrides: [
        app_shell.appProvider.overrideWith((ref) => controller),
      ],
      child: const MaterialApp(home: app_shell.MomentProfileScreen()),
    ));

    controller.setError('旧画像分析错误');
    await tester.pump();
    expect(find.text('旧画像分析错误'), findsOneWidget);

    await tester.ensureVisible(find.text('小林').first);
    await tester.tap(find.text('小林').first);
    await tester.pump();

    expect(controller.errorMessage, isNull);
    expect(find.text('旧画像分析错误'), findsNothing);
  });

  test('moment profile image changes clear stale analysis like iOS', () {
    final source =
        File('lib/screens/moment_profile_screen.dart').readAsStringSync();
    final screenStart = source.indexOf('class MomentProfileScreen');
    final pickStart = source.indexOf('Future<void> _pick() async', screenStart);
    final readStart = source.indexOf(
      'Future<void> _readClipboardImage() async',
      screenStart,
    );
    final screenEnd = source.length;

    expect(screenStart, isNonNegative);
    expect(pickStart, isNonNegative);
    expect(readStart, greaterThan(pickStart));
    expect(screenEnd, greaterThan(readStart));
    expect(
      source.substring(pickStart, readStart),
      contains('clearMomentResult(notify: false)'),
    );
    expect(
      source.substring(readStart, screenEnd),
      contains('clearMomentResult(notify: false)'),
    );
  });

  test('moment profile clears deleted transient preview after success', () {
    final source =
        File('lib/screens/moment_profile_screen.dart').readAsStringSync();
    final screenStart = source.indexOf('class MomentProfileScreen');
    final analyzeStart =
        source.indexOf('await app.analyzeMoment(', screenStart);
    final resultStart =
        source.indexOf('if (app.currentMomentAnalysis != null)', analyzeStart);
    final methodEnd = source.length;

    expect(screenStart, isNonNegative);
    expect(analyzeStart, isNonNegative);
    expect(resultStart, greaterThan(analyzeStart));
    expect(methodEnd, greaterThan(resultStart));
    final analyzeBlock = source.substring(analyzeStart, methodEnd);
    expect(analyzeBlock, contains('isOwnedTransientImagePath(submittedPath)'));
    expect(analyzeBlock, contains('path = null'));
    expect(analyzeBlock, contains('clipboardFeedbackTimer?.cancel()'));
  });

  test(
      'moment profile discards replaced deleted and disposed transient previews',
      () {
    final source =
        File('lib/screens/moment_profile_screen.dart').readAsStringSync();
    final screenStart = source.indexOf('class MomentProfileScreen');
    final disposeStart = source.indexOf('void dispose()', screenStart);
    final pickStart = source.indexOf('Future<void> _pick() async', screenStart);
    final readStart = source.indexOf(
      'Future<void> _readClipboardImage() async',
      screenStart,
    );
    final screenEnd = source.length;

    expect(screenStart, isNonNegative);
    expect(disposeStart, isNonNegative);
    expect(pickStart, greaterThan(disposeStart));
    expect(readStart, greaterThan(pickStart));
    expect(screenEnd, greaterThan(readStart));

    final disposeSource = source.substring(disposeStart, pickStart);
    final pickSource = source.substring(pickStart, readStart);
    final readSource = source.substring(readStart, screenEnd);
    final deleteStart = source.indexOf("label: const Text('删除')", screenStart);
    final deleteSource = source.substring(screenStart, deleteStart);

    expect(disposeSource, contains('final previewPath = path;'));
    expect(disposeSource, contains('discardTransientImagePath(previewPath)'));
    expect(pickSource, contains('final previousPath = path;'));
    expect(pickSource, contains('discardTransientImagePath(previousPath)'));
    expect(readSource, contains('final previousPath = path;'));
    expect(readSource, contains('discardTransientImagePath(previousPath)'));
    expect(deleteSource, contains('final previewPath = path;'));
    expect(deleteSource, contains('discardTransientImagePath(previewPath)'));
  });

  test('clear history keeps other app data intact', () async {
    SharedPreferences.setMockInitialValues({});
    final app = AppController()
      ..history = [
        GenerationRecord(
          inputType: ChatInputType.text,
          selectedStyleName: '自然',
          replies: [
            ReplySuggestion(styleLabel: '自然', text: '收到', reason: '测试'),
          ],
        ),
      ]
      ..profiles = [PersonProfile(displayName: '小林')]
      ..selectedHistoryRecord = GenerationRecord(
        inputType: ChatInputType.text,
        selectedStyleName: '自然',
        replies: [
          ReplySuggestion(styleLabel: '自然', text: '收到', reason: '测试'),
        ],
      );

    await app.clearHistory();

    expect(app.history, isEmpty);
    expect(app.selectedHistoryRecord, isNull);
    expect(app.profiles.single.displayName, '小林');
  });

  test('clear api key keeps api config intact', () async {
    SharedPreferences.setMockInitialValues({});
    final store = FakeStore();
    final config =
        APIConfig.defaults.copyWith(baseURL: 'https://example.com/v1');
    final app = AppController(store: store)
      ..config = config
      ..apiKey = 'sk-test'
      ..availableModels = const [APIModel(id: 'gpt-4o-mini')];

    await app.clearAPIKey();

    expect(app.apiKey, isEmpty);
    expect(app.availableModels, isEmpty);
    expect(store.savedAPIKey, isEmpty);
    expect(app.config.baseURL, 'https://example.com/v1');
    expect(app.statusMessage, contains('已清除'));
  });

  test('api config save normalizes fields and reset clears stale errors',
      () async {
    SharedPreferences.setMockInitialValues({});
    final store = FakeStore();
    final app = AppController(store: store)
      ..errorMessage = '旧错误'
      ..config = APIConfig.defaults.copyWith(baseURL: 'https://old.example/v1')
      ..availableModels = const [APIModel(id: 'old-model')];
    final dirtyConfig = APIConfig.defaults.copyWith(
      baseURL: '  HTTPS://API.EXAMPLE//v1//?foo=bar#top  ',
      visionModelName: ' gpt-4o-mini ',
      textModelName: ' gpt-4o-mini ',
      modelCapabilities: {
        ' gpt-4o-mini ': const ModelCapability(isMultimodal: true),
        ' GPT-4O-MINI ': const ModelCapability(isReasoning: true),
        '   ': const ModelCapability(isReasoning: true),
      },
    );

    await app.saveConfig(dirtyConfig, ' sk-test ');

    expect(app.config.baseURL, 'https://api.example/v1');
    expect(app.config.visionModelName, 'gpt-4o-mini');
    expect(app.config.textModelName, 'gpt-4o-mini');
    expect(app.config.modelCapabilities.keys, ['gpt-4o-mini']);
    expect(app.config.capability('gpt-4o-mini').isMultimodal, isTrue);
    expect(app.config.capability('gpt-4o-mini').isReasoning, isTrue);
    expect(app.availableModels, isEmpty);
    expect(app.apiKey, 'sk-test');
    expect(store.savedConfig!.baseURL, 'https://api.example/v1');
    expect(store.savedAPIKey, 'sk-test');
    expect(app.errorMessage, isNull);
    expect(
      apiConfigSourceFingerprint(dirtyConfig, ' sk-test '),
      'https://api.example/v1|sk-test',
    );
    expect(
      normalizeApiConfig(APIConfig.defaults.copyWith(baseURL: '   ')).baseURL,
      isEmpty,
    );

    final rulesSource =
        File('lib/core/api_config_rules.dart').readAsStringSync();
    expect(rulesSource, contains("import 'text_cleaning.dart';"));
    expect(
      rulesSource,
      contains('String _normalizedApiConfigBaseUrl(String value)'),
    );
    expect(
      rulesSource,
      contains('baseURL: _normalizedApiConfigBaseUrl(config.baseURL),'),
    );
    expect(rulesSource, contains('mergeCapability(capabilities, modelId,'));
    expect(
      rulesSource,
      contains('final base = _normalizedApiConfigBaseUrl(config.baseURL);'),
    );
    expect(rulesSource, isNot(contains('config.baseURL.trim()')));

    app.errorMessage = '测试连接失败';
    app.availableModels = const [APIModel(id: 'old-model')];
    await app.resetConfig();

    expect(app.config, APIConfig.defaults);
    expect(app.apiKey, isEmpty);
    expect(app.availableModels, isEmpty);
    expect(app.errorMessage, isNull);
    expect(app.statusMessage, contains('恢复默认'));
  });

  test('api config save allows text-only mode without a vision model',
      () async {
    SharedPreferences.setMockInitialValues({});
    final store = FakeStore();
    final app = AppController(store: store)
      ..config = APIConfig.defaults
      ..apiKey = 'old-key';
    final textOnlyConfig = APIConfig.defaults.copyWith(
      enableImageInput: false,
      visionModelName: '   ',
      textModelName: ' gpt-text ',
    );

    await app.saveConfig(textOnlyConfig, ' sk-text ');

    expect(app.config.enableImageInput, isFalse);
    expect(app.config.visionModelName, isEmpty);
    expect(app.config.textModelName, 'gpt-text');
    expect(app.apiKey, 'sk-text');
    expect(store.savedConfig!.enableImageInput, isFalse);
    expect(store.savedConfig!.visionModelName, isEmpty);
    expect(store.savedAPIKey, 'sk-text');
    expect(app.statusMessage, '配置已保存');
    expect(app.errorMessage, isNull);
  });

  test('api config save cleans placeholder model names like json', () async {
    SharedPreferences.setMockInitialValues({});
    final store = FakeStore();
    final app = AppController(store: store);
    final dirtyConfig = APIConfig.defaults.copyWith(
      enableImageInput: false,
      visionModelName: '  未知  ',
      textModelName: ' gpt-text ',
      modelCapabilities: {
        ' 未知 ': const ModelCapability(isMultimodal: true),
        ' gpt-text ': const ModelCapability(isReasoning: true),
      },
    );

    await app.saveConfig(dirtyConfig, ' sk-text ');

    expect(app.config.visionModelName, isEmpty);
    expect(app.config.textModelName, 'gpt-text');
    expect(app.config.modelCapabilities.keys, ['gpt-text']);
    expect(app.config.capability('gpt-text').isReasoning, isTrue);
    expect(store.savedConfig!.visionModelName, isEmpty);
    expect(store.savedConfig!.modelCapabilities.keys, ['gpt-text']);
    expect(app.statusMessage, '配置已保存');
    expect(app.errorMessage, isNull);
  });

  test('api config save rejects placeholder text model name', () async {
    SharedPreferences.setMockInitialValues({});
    final store = FakeStore();
    final app = AppController(store: store)
      ..config = APIConfig.defaults.copyWith(textModelName: 'old-text');
    final dirtyConfig = APIConfig.defaults.copyWith(
      textModelName: '  未知  ',
    );

    await app.saveConfig(dirtyConfig, ' sk-text ');

    expect(app.config.textModelName, 'old-text');
    expect(store.savedConfig, APIConfig.defaults);
    expect(store.savedAPIKey, isEmpty);
    expect(app.statusMessage, isNull);
    expect(app.errorMessage, textModelRequiredMessage);
  });

  test('api config save clamps numeric fields to settings ranges', () async {
    SharedPreferences.setMockInitialValues({});
    final store = FakeStore();
    final app = AppController(store: store);
    final dirtyConfig = APIConfig.defaults.copyWith(
      baseURL: 'https://api.example/v1',
      imageMaxWidth: 9999,
      imageCompressionQuality: -1,
      temperature: 9,
      maxTokens: 1,
      timeout: 999,
    );

    await app.saveConfig(dirtyConfig, 'sk-test');

    expect(app.config.imageMaxWidth, APIConfig.imageMaxWidthMax);
    expect(
      app.config.imageCompressionQuality,
      APIConfig.imageCompressionQualityMin,
    );
    expect(app.config.temperature, APIConfig.temperatureMax);
    expect(app.config.maxTokens, APIConfig.maxTokensMin);
    expect(app.config.timeout, APIConfig.timeoutMax);
    expect(store.savedConfig!.imageMaxWidth, APIConfig.imageMaxWidthMax);
    expect(
      store.savedConfig!.imageCompressionQuality,
      APIConfig.imageCompressionQualityMin,
    );
  });

  test('stale api config save cannot persist after clear all', () async {
    SharedPreferences.setMockInitialValues({});
    final store = DeferredPreferenceStore()..delayConfigSave = true;
    final app = AppController(store: store)
      ..config = APIConfig.defaults.copyWith(baseURL: 'https://old.example/v1')
      ..apiKey = 'sk-old';
    final newConfig =
        APIConfig.defaults.copyWith(baseURL: 'https://new.example/v1');

    final pending = app.saveConfig(newConfig, 'sk-new');
    await store.configStarted.future;

    await app.clearAllLocalData();
    store.configRelease.complete();
    await pending;

    expect(app.config, APIConfig.defaults);
    expect(app.apiKey, isEmpty);
    expect(store.savedConfig, isNull);
    expect(store.savedAPIKey, isEmpty);
    expect(store.didClearAll, isTrue);
    expect(app.statusMessage, '本地数据已清空，API 配置已恢复默认。');
  });

  test(
      'stale api config save rewrites latest preference without stale feedback',
      () async {
    SharedPreferences.setMockInitialValues({});
    final store = DeferredPreferenceStore()..delayConfigSave = true;
    final app = AppController(store: store)
      ..config = APIConfig.defaults.copyWith(baseURL: 'https://old.example/v1')
      ..apiKey = 'sk-old';
    final firstConfig =
        APIConfig.defaults.copyWith(baseURL: 'https://first.example/v1');
    final latestConfig =
        APIConfig.defaults.copyWith(baseURL: 'https://latest.example/v1');

    final first = app.saveConfig(firstConfig, 'sk-first');
    await store.configStarted.future;

    await app.saveConfig(latestConfig, 'sk-latest');
    expect(app.config.baseURL, 'https://latest.example/v1');
    expect(app.apiKey, 'sk-latest');
    expect(store.savedConfig!.baseURL, 'https://latest.example/v1');
    expect(store.savedAPIKey, 'sk-latest');
    app.statusMessage = '等待旧请求完成';

    store.configRelease.complete();
    await first;

    expect(app.config.baseURL, 'https://latest.example/v1');
    expect(app.apiKey, 'sk-latest');
    expect(store.savedConfig!.baseURL, 'https://latest.example/v1');
    expect(store.savedAPIKey, 'sk-latest');
    expect(app.statusMessage, '等待旧请求完成');
  });

  test('stale api config reset cannot overwrite newer save feedback', () async {
    SharedPreferences.setMockInitialValues({});
    final store = DeferredPreferenceStore()..delayConfigSave = true;
    final app = AppController(store: store)
      ..config = APIConfig.defaults.copyWith(baseURL: 'https://old.example/v1')
      ..apiKey = 'sk-old';
    final latestConfig =
        APIConfig.defaults.copyWith(baseURL: 'https://latest.example/v1');

    final reset = app.resetConfig();
    await store.configStarted.future;

    await app.saveConfig(latestConfig, 'sk-latest');
    expect(app.config.baseURL, 'https://latest.example/v1');
    expect(app.apiKey, 'sk-latest');
    expect(store.savedConfig!.baseURL, 'https://latest.example/v1');
    expect(store.savedAPIKey, 'sk-latest');
    expect(app.statusMessage, '配置已保存');

    store.configRelease.complete();
    await reset;

    expect(app.config.baseURL, 'https://latest.example/v1');
    expect(app.apiKey, 'sk-latest');
    expect(store.savedConfig!.baseURL, 'https://latest.example/v1');
    expect(store.savedAPIKey, 'sk-latest');
    expect(app.statusMessage, '配置已保存');
  });

  test('stale api config save cannot overwrite newer validation error',
      () async {
    SharedPreferences.setMockInitialValues({});
    final store = DeferredPreferenceStore()..delayConfigSave = true;
    final app = AppController(store: store)
      ..config = APIConfig.defaults.copyWith(baseURL: 'https://old.example/v1')
      ..apiKey = 'sk-old';
    final validConfig =
        APIConfig.defaults.copyWith(baseURL: 'https://valid.example/v1');

    final pending = app.saveConfig(validConfig, 'sk-valid');
    await store.configStarted.future;

    await app.saveConfig(
      APIConfig.defaults.copyWith(baseURL: 'https://'),
      'sk-invalid',
    );
    expect(app.errorMessage, contains('Base URL'));
    expect(app.statusMessage, isNull);

    store.configRelease.complete();
    await pending;

    expect(app.config.baseURL, 'https://valid.example/v1');
    expect(app.apiKey, 'sk-valid');
    expect(store.savedConfig!.baseURL, 'https://valid.example/v1');
    expect(store.savedAPIKey, 'sk-valid');
    expect(app.errorMessage, contains('Base URL'));
    expect(app.statusMessage, isNull);
  });

  test('stale api key clear cannot erase a newer saved key', () async {
    SharedPreferences.setMockInitialValues({});
    final store = DeferredPreferenceStore()..delayAPIKeySave = true;
    final app = AppController(store: store)
      ..config = APIConfig.defaults.copyWith(baseURL: 'https://old.example/v1')
      ..apiKey = 'sk-old';
    final newConfig =
        APIConfig.defaults.copyWith(baseURL: 'https://new.example/v1');

    final pendingClear = app.clearAPIKey();
    await store.apiKeyStarted.future;

    await app.saveConfig(newConfig, 'sk-new');
    store.apiKeyRelease.complete();
    await pendingClear;

    expect(app.config.baseURL, 'https://new.example/v1');
    expect(app.apiKey, 'sk-new');
    expect(store.savedConfig!.baseURL, 'https://new.example/v1');
    expect(store.savedAPIKey, 'sk-new');
    expect(app.statusMessage, '配置已保存');
  });

  test('api config save rejects urls without an http host', () async {
    SharedPreferences.setMockInitialValues({});
    final store = FakeStore();
    final app = AppController(store: store)
      ..config = APIConfig.defaults
      ..apiKey = 'old-key';

    await app.saveConfig(
      APIConfig.defaults.copyWith(baseURL: 'https://'),
      'sk-test',
    );

    expect(app.config, APIConfig.defaults);
    expect(app.apiKey, 'old-key');
    expect(store.savedConfig, APIConfig.defaults);
    expect(store.savedAPIKey, isEmpty);
    expect(app.statusMessage, isNull);
    expect(app.errorMessage, contains('Base URL'));
  });

  test('clear all local data deletes imported custom background file',
      () async {
    final store = FakeStore();
    final tempDir = await Directory.systemTemp.createTemp('ai-reply-test-');
    final background = File('${tempDir.path}/custom-background-owned.jpg');
    final quickImage = File('${tempDir.path}/floating-capture-test.jpg');
    final sharedImage = File('${tempDir.path}/clipboard-image-test.img');
    await background.writeAsBytes([1, 2, 3]);
    await quickImage.writeAsBytes([4, 5, 6]);
    await sharedImage.writeAsBytes([7, 8, 9]);
    final customStyle = ChatStyle(
      id: 'custom-style',
      name: '自定义',
      description: '清空前默认风格',
      rules: const ['短句'],
      isOfficial: false,
    );
    final app = AppController(
      store: store,
      supportDirectoryProvider: () async => tempDir,
      temporaryDirectoryProvider: () async => tempDir,
    )
      ..appearance = AppearanceSettings.defaults
          .copyWith(customBackgroundPath: background.path)
      ..quickImagePath = quickImage.path
      ..sharedImagePath = sharedImage.path
      ..availableModels = const [APIModel(id: 'old-provider-model')]
      ..isBusy = true
      ..isFetchingModels = true
      ..isTestingConnection = true
      ..isTestingVision = true
      ..personalization = ReplyPersonalizationSettings(
        customStyles: [customStyle],
      )
      ..defaultStyle = customStyle
      ..currentResponse = ChatReplyResponse(
        replies: [
          ReplySuggestion(
              styleLabel: customStyle.name, text: '旧回复', reason: '清空前'),
        ],
      )
      ..currentInputType = ChatInputType.image
      ..currentStyle = customStyle
      ..currentGoal = '清空前的目标'
      ..currentTextInput = '清空前的文本'
      ..currentImagePath = quickImage.path
      ..currentSelectedProfileId = '清空前的人物'
      ..simulationScenario = SimulationScenario.conflict;

    await app.clearAllLocalData();

    expect(await background.exists(), isFalse);
    expect(await quickImage.exists(), isFalse);
    expect(await sharedImage.exists(), isFalse);
    expect(app.appearance.customBackgroundPath, isNull);
    expect(app.quickImagePath, isNull);
    expect(app.sharedImagePath, isNull);
    expect(app.availableModels, isEmpty);
    expect(app.isBusy, isFalse);
    expect(app.isFetchingModels, isFalse);
    expect(app.isTestingConnection, isFalse);
    expect(app.isTestingVision, isFalse);
    expect(app.personalization.customStyles, isEmpty);
    expect(app.defaultStyle, ChatStyle.defaultStyle);
    expect(app.currentResponse, isNull);
    expect(app.currentInputType, ChatInputType.text);
    expect(app.currentStyle, ChatStyle.defaultStyle);
    expect(app.currentGoal, isNull);
    expect(app.currentTextInput, isNull);
    expect(app.currentImagePath, isNull);
    expect(app.currentSelectedProfileId, isNull);
    expect(app.simulationScenario, SimulationScenario.dailyChat);
    expect(store.didClearAll, isTrue);

    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('owned file cleanup trims stored background and transient paths',
      () async {
    final store = FakeStore();
    final dir = await Directory.systemTemp.createTemp('ai-reply-clean-paths-');
    final background = File('${dir.path}/custom-background-spaced.jpg');
    final quickImage = File('${dir.path}/floating-capture-spaced.jpg');
    final sharedImage = File('${dir.path}/clipboard-image-spaced.img');
    await background.writeAsBytes([1, 2, 3]);
    await quickImage.writeAsBytes([4, 5, 6]);
    await sharedImage.writeAsBytes([7, 8, 9]);

    try {
      final app = AppController(
        store: store,
        supportDirectoryProvider: () async => dir,
        temporaryDirectoryProvider: () async => dir,
      )
        ..appearance = AppearanceSettings.defaults
            .copyWith(customBackgroundPath: '  ${background.path}  ')
        ..currentInputType = ChatInputType.image
        ..currentImagePath = '  ${quickImage.path}  '
        ..quickImagePath = '  ${quickImage.path}  '
        ..sharedImagePath = '  ${sharedImage.path}  ';

      await app.clearAllLocalData();

      expect(await background.exists(), isFalse);
      expect(await quickImage.exists(), isFalse);
      expect(await sharedImage.exists(), isFalse);
      expect(app.appearance.customBackgroundPath, isNull);
      expect(app.currentImagePath, isNull);
      expect(app.quickImagePath, isNull);
      expect(app.sharedImagePath, isNull);
    } finally {
      if (await dir.exists()) await dir.delete(recursive: true);
    }
  });

  test('stale initial load cannot restore data after clear all', () async {
    final store = DeferredLoadStore()
      ..delayHistoryLoad = true
      ..loadedConfig =
          APIConfig.defaults.copyWith(baseURL: 'https://old.example/v1')
      ..loadedAPIKey = 'sk-old'
      ..loadedHistory = [
        GenerationRecord(
          inputType: ChatInputType.text,
          selectedStyleName: '自然',
          replies: [
            ReplySuggestion(styleLabel: '自然', text: '旧回复', reason: '测试'),
          ],
        ),
      ]
      ..loadedProfiles = [PersonProfile(displayName: '旧人物')]
      ..hasSeenPrivacy = true;
    final app = AppController(store: store);

    final pendingLoad = app.load();
    await store.historyLoadStarted.future;

    await app.clearAllLocalData();

    store.historyLoadRelease.complete();
    await pendingLoad;

    expect(app.config, APIConfig.defaults);
    expect(app.apiKey, isEmpty);
    expect(app.history, isEmpty);
    expect(app.profiles, isEmpty);
    expect(app.showingPrivacyNotice, isTrue);
    expect(app.statusMessage, '本地数据已清空，API 配置已恢复默认。');
    expect(store.didClearAll, isTrue);
  });

  test('stale initial load cannot overwrite saved api settings', () async {
    final store = DeferredLoadStore()
      ..delayHistoryLoad = true
      ..loadedConfig =
          APIConfig.defaults.copyWith(baseURL: 'https://old.example/v1')
      ..loadedAPIKey = 'sk-old'
      ..hasSeenPrivacy = true;
    final app = AppController(store: store);
    final newConfig =
        APIConfig.defaults.copyWith(baseURL: 'https://new.example/v1');

    final pendingLoad = app.load();
    await store.historyLoadStarted.future;

    await app.saveConfig(newConfig, 'sk-new');
    expect(app.shouldDeferExternalHandoffs, isTrue);

    store.historyLoadRelease.complete();
    await pendingLoad;

    expect(app.config.baseURL, 'https://new.example/v1');
    expect(app.apiKey, 'sk-new');
    expect(store.savedConfig!.baseURL, 'https://new.example/v1');
    expect(store.savedAPIKey, 'sk-new');
    expect(app.statusMessage, '配置已保存');
    expect(app.showingPrivacyNotice, isFalse);
    expect(app.shouldDeferExternalHandoffs, isFalse);
  });

  test('initial load revision guard covers persisted app domains', () {
    final source = File('lib/core/app_state.dart').readAsStringSync();
    final runtimeSource =
        File('lib/core/app_state_runtime_helpers.dart').readAsStringSync();
    final guardStart = source.indexOf('String _loadMutationFingerprint() => [');
    final guardEnd =
        source.indexOf('String personalizationPromptContext()', guardStart);
    final loadStart = source.indexOf('Future<void> load() async');

    expect(guardStart, isNonNegative);
    expect(guardEnd, greaterThan(guardStart));
    expect(loadStart, isNonNegative);

    final guardBody = source.substring(guardStart, guardEnd);
    for (final revision in const [
      '_settingsRevision',
      '_contentRevision',
      '_simulationRevision',
      '_historyRevision',
      '_profilesRevision',
      '_backgroundRevision',
      '_preferencesRevision',
      '_appearanceRevision',
    ]) {
      expect(guardBody, contains(revision));
    }

    final loadBody = source.substring(loadStart, guardStart);
    expect(runtimeSource, contains('int _beginInitialLoadOperation()'));
    expect(runtimeSource, contains('bool _isCurrentInitialLoadOperation('));
    expect(runtimeSource, contains('void _applyLoadedPrivacyState('));
    expect(runtimeSource, contains('void _applyLoadedInitialState({'));
    expect(loadBody, contains('_beginInitialLoadOperation();'));
    expect(loadBody, contains('_isCurrentInitialLoadOperation('));
    expect(loadBody, contains('_applyLoadedPrivacyState('));
    expect(loadBody, contains('_applyLoadedInitialState('));
    expect(loadBody, isNot(contains('notifyListeners();')));
  });

  test('clear all local data invalidates pending app domains together', () {
    final source =
        File('lib/core/app_state_local_data.dart').readAsStringSync();
    final clearStart = source.indexOf('Future<void> clearAllLocalData() async');
    final helperStart = source.indexOf('void _invalidateLocalDataOperations()');
    final helperEnd =
        source.indexOf('void setError(String message)', helperStart);

    expect(clearStart, isNonNegative);
    expect(helperStart, greaterThan(clearStart));
    expect(helperEnd, greaterThan(helperStart));
    expect(
      source.substring(clearStart, helperStart),
      contains('_invalidateLocalDataOperations();'),
    );
    expect(
      source.substring(clearStart, helperStart),
      contains('_clearApiOperationState();'),
    );
    expect(
      source.substring(clearStart, helperStart),
      contains('_setPendingGenerationSource('),
    );
    expect(
      source.substring(clearStart, helperStart),
      contains('type: ChatInputType.text'),
    );
    expect(
      source.substring(clearStart, helperStart),
      contains('style: ChatStyle.defaultStyle'),
    );

    final helperBody = source.substring(helperStart, helperEnd);
    for (final revision in const [
      '_settingsRevision',
      '_contentRevision',
      '_simulationRevision',
      '_historyRevision',
      '_profilesRevision',
      '_backgroundRevision',
      '_preferencesRevision',
      '_appearanceRevision',
      '_privacyRevision',
      '_loadRevision',
      '_generationRevision',
      '_momentAnalysisRevision',
      '_modelFetchGeneration',
      '_connectionTestGeneration',
      '_visionTestGeneration',
      '_localDataClearRevision',
    ]) {
      expect(helperBody, contains('$revision += 1'));
    }

    final runtimeSource =
        File('lib/core/app_state_runtime_helpers.dart').readAsStringSync();
    expect(runtimeSource, contains('void _clearApiOperationState()'));
    for (final flag in const [
      'isFetchingModels = false',
      'isTestingConnection = false',
      'isTestingVision = false',
    ]) {
      expect(source.substring(clearStart, helperStart), isNot(contains(flag)));
      expect(runtimeSource, contains(flag));
    }
  });

  test('clear all local data deletes current owned transient image only',
      () async {
    final store = FakeStore();
    final dir =
        await Directory.systemTemp.createTemp('ai-reply-current-image-clear-');
    final owned = File('${dir.path}/accessibility-capture-current.jpg');
    final picked = File('${dir.path}/picked-image.jpg');
    final pickedQuick = File('${dir.path}/picked-quick.jpg');
    final pickedShared = File('${dir.path}/picked-shared.jpg');
    await owned.writeAsBytes([1, 2, 3]);
    await picked.writeAsBytes([4, 5, 6]);
    await pickedQuick.writeAsBytes([7, 8, 9]);
    await pickedShared.writeAsBytes([10, 11, 12]);

    try {
      final app = AppController(
        store: store,
        temporaryDirectoryProvider: () async => dir,
      )..currentImagePath = owned.path;
      await app.clearAllLocalData();

      expect(await owned.exists(), isFalse);
      expect(app.currentImagePath, isNull);

      final pickedApp = AppController(
        store: store,
        temporaryDirectoryProvider: () async => dir,
      )
        ..currentImagePath = picked.path
        ..quickImagePath = pickedQuick.path
        ..sharedImagePath = pickedShared.path;
      await pickedApp.clearAllLocalData();

      expect(await picked.exists(), isTrue);
      expect(await pickedQuick.exists(), isTrue);
      expect(await pickedShared.exists(), isTrue);
      expect(pickedApp.currentImagePath, isNull);
      expect(pickedApp.quickImagePath, isNull);
      expect(pickedApp.sharedImagePath, isNull);
    } finally {
      if (await dir.exists()) await dir.delete(recursive: true);
    }
  });

  test('local data clear and background reset do not delete external files',
      () async {
    final dir = await Directory.systemTemp.createTemp('ai-reply-bg-safe-');
    final supportDir = Directory('${dir.path}/support');
    await supportDir.create();
    final externalBackground = File('${dir.path}/picked-background.jpg');
    final externalResetBackground = File('${dir.path}/picked-reset.jpg');
    await externalBackground.writeAsBytes([1, 2, 3]);
    await externalResetBackground.writeAsBytes([4, 5, 6]);

    try {
      final clearApp = AppController(
        store: FakeStore(),
        supportDirectoryProvider: () async => supportDir,
      )..appearance = AppearanceSettings.defaults
          .copyWith(customBackgroundPath: externalBackground.path);

      await clearApp.clearAllLocalData();

      expect(await externalBackground.exists(), isTrue);
      expect(clearApp.appearance.customBackgroundPath, isNull);

      final resetApp = AppController(
        store: FakeStore(),
        supportDirectoryProvider: () async => supportDir,
      )..appearance = AppearanceSettings.defaults
          .copyWith(customBackgroundPath: externalResetBackground.path);

      await resetApp.resetCustomBackground();

      expect(await externalResetBackground.exists(), isTrue);
      expect(resetApp.appearance.customBackgroundPath, isNull);
    } finally {
      if (await dir.exists()) await dir.delete(recursive: true);
    }
  });

  test('stale appearance save cannot persist after clear all', () async {
    final store = DeferredPreferenceStore()..delayAppearanceSave = true;
    final app = AppController(store: store);
    final customAppearance = AppearanceSettings.defaults.copyWith(
      accentColorName: 'rose',
      textSizeName: 'large',
      backgroundDimOpacity: 0.35,
    );

    final pending = app.saveAppearance(customAppearance);
    await store.appearanceStarted.future;

    await app.clearAllLocalData();
    store.appearanceRelease.complete();
    await pending;

    expect(app.appearance, AppearanceSettings.defaults);
    expect(store.savedAppearance, isNull);
    expect(store.didClearAll, isTrue);
  });

  test('appearance save normalizes runtime and persisted settings', () async {
    final store = FakeStore();
    final app = AppController(store: store);
    const dirtyAppearance = AppearanceSettings(
      isBackgroundBlurEnabled: false,
      backgroundBlurRadius: 999,
      backgroundDimOpacity: -2,
      glassTintStrength: 9,
      glassBorderStrength: -1,
      accentColorName: '未知',
      textSizeName: '  comfortable  ',
      customBackgroundPath: '未知',
    );

    await app.saveAppearance(dirtyAppearance);

    expect(app.appearance.isBackgroundBlurEnabled, isFalse);
    expect(
      app.appearance.backgroundBlurRadius,
      AppearanceSettings.backgroundBlurRadiusMax,
    );
    expect(
      app.appearance.backgroundDimOpacity,
      AppearanceSettings.backgroundDimOpacityMin,
    );
    expect(
      app.appearance.glassTintStrength,
      AppearanceSettings.glassTintStrengthMax,
    );
    expect(
      app.appearance.glassBorderStrength,
      AppearanceSettings.glassBorderStrengthMin,
    );
    expect(
      app.appearance.accentColorName,
      AppearanceSettings.defaults.accentColorName,
    );
    expect(app.appearance.textSizeName, 'comfortable');
    expect(app.appearance.customBackgroundPath, isNull);
    expect(store.savedAppearance, app.appearance);
  });

  test('appearance save path shares revision guard', () {
    final source =
        File('lib/core/app_state_appearance.dart').readAsStringSync();
    final runtimeSource =
        File('lib/core/app_state_runtime_helpers.dart').readAsStringSync();

    expect(source, contains('Future<bool> _persistAppearanceForRevision({'));
    expect(runtimeSource, contains('int _beginAppearanceMutation()'));
    expect(runtimeSource, contains('bool _isCurrentAppearanceRevision('));
    expect(runtimeSource, contains('int _captureLocalDataClearRevision()'));
    expect(runtimeSource, contains('bool _isCurrentLocalDataClearRevision('));
    expect(
      RegExp(r'_persistAppearanceForRevision\(').allMatches(source).length,
      2,
    );
    expect(source, contains('_beginAppearanceMutation();'));
    expect(source, contains('_isCurrentAppearanceRevision('));
    expect(source, contains('_captureLocalDataClearRevision();'));
    expect(source, contains('_isCurrentLocalDataClearRevision('));
    expect(source, contains('await _store.clearAppearance();'));
    expect(
      source,
      isNot(contains('if (requestRevision != _appearanceRevision)')),
    );
    expect(source, isNot(contains('++_appearanceRevision')));
    expect(source, isNot(contains('revision == _appearanceRevision')));
    expect(source, isNot(contains('_localDataClearRevision')));
    expect(runtimeSource, contains('int _beginBackgroundImportOperation()'));
    expect(
        runtimeSource, contains('bool _isCurrentBackgroundImportOperation('));
    expect(
        runtimeSource, contains('int _captureBackgroundOperationRevision()'));
    expect(
        runtimeSource, contains('void _invalidateBackgroundImportOperation()'));
    expect(source, contains('_beginBackgroundImportOperation();'));
    expect(source, contains('_captureBackgroundOperationRevision();'));
    expect(source, contains('_isCurrentBackgroundImportOperation('));
    expect(source, contains('_invalidateBackgroundImportOperation();'));
    expect(source, isNot(contains('++_backgroundRevision')));
    expect(source, isNot(contains('_backgroundRevision += 1')));
    expect(source, isNot(contains('requestRevision != _backgroundRevision')));
  });

  test('stale appearance save rewrites latest preference when not cleared',
      () async {
    final store = DeferredPreferenceStore()..delayAppearanceSave = true;
    final app = AppController(store: store);
    final firstAppearance = AppearanceSettings.defaults.copyWith(
      accentColorName: 'rose',
      textSizeName: 'large',
    );
    final latestAppearance = AppearanceSettings.defaults.copyWith(
      accentColorName: 'teal',
      backgroundDimOpacity: 0.42,
    );

    final first = app.saveAppearance(firstAppearance);
    await store.appearanceStarted.future;

    await app.saveAppearance(latestAppearance);
    expect(app.appearance, latestAppearance);
    expect(store.savedAppearance, latestAppearance);

    store.appearanceRelease.complete();
    await first;

    expect(app.appearance, latestAppearance);
    expect(store.savedAppearance, latestAppearance);
  });

  test('stale personalization save cannot persist after clear all', () async {
    final store = DeferredPreferenceStore()..delayPersonalizationSave = true;
    final customStyle = ChatStyle(
      id: 'custom-style',
      name: '自定义',
      description: '旧偏好',
      rules: const ['旧规则'],
      isOfficial: false,
    );
    final app = AppController(store: store);
    final customPersonalization = ReplyPersonalizationSettings(
      isConversationMemoryEnabled: true,
      memoryNotes: '旧记忆',
      customStyles: [customStyle],
    );

    final pending = app.savePersonalization(customPersonalization);
    await store.personalizationStarted.future;

    await app.clearAllLocalData();
    store.personalizationRelease.complete();
    await pending;

    expect(app.personalization, ReplyPersonalizationSettings.defaults);
    expect(store.savedPersonalization, isNull);
    expect(store.savedDefaultStyleId, isNull);
    expect(store.didClearAll, isTrue);
  });

  test('reset custom background keeps other appearance preferences like iOS',
      () async {
    final store = FakeStore();
    final tempDir = await Directory.systemTemp.createTemp('ai-reply-bg-');
    final background = File('${tempDir.path}/custom-background-owned.jpg');
    await background.writeAsBytes([1, 2, 3]);
    final customAppearance = AppearanceSettings.defaults.copyWith(
      customBackgroundPath: background.path,
      isBackgroundBlurEnabled: false,
      backgroundBlurRadius: 22,
      accentColorName: 'rose',
      textSizeName: 'large',
    );
    final app = AppController(
      store: store,
      supportDirectoryProvider: () async => tempDir,
    )..appearance = customAppearance;

    try {
      await app.resetCustomBackground();

      expect(await background.exists(), isFalse);
      expect(app.appearance.customBackgroundPath, isNull);
      expect(app.appearance.isBackgroundBlurEnabled, isFalse);
      expect(app.appearance.backgroundBlurRadius, 22);
      expect(app.appearance.accentColorName, 'rose');
      expect(app.appearance.textSizeName, 'large');
      expect(app.statusMessage, '已恢复默认背景');
    } finally {
      if (await tempDir.exists()) await tempDir.delete(recursive: true);
    }
  });

  test('reset appearance preferences preserves custom background like iOS',
      () async {
    final tempDir = await Directory.systemTemp.createTemp('ai-reply-bg-');
    final background = File('${tempDir.path}/custom-background.jpg');
    await background.writeAsBytes([1, 2, 3]);
    final customAppearance = AppearanceSettings.defaults.copyWith(
      customBackgroundPath: background.path,
      isBackgroundBlurEnabled: false,
      backgroundBlurRadius: 22,
      backgroundDimOpacity: 0.35,
      glassTintStrength: 1.4,
      glassBorderStrength: 0.7,
      accentColorName: 'rose',
      textSizeName: 'large',
    );
    final app = AppController(store: FakeStore())
      ..appearance = customAppearance;

    try {
      await app.resetAppearance();

      expect(await background.exists(), isTrue);
      expect(app.appearance.customBackgroundPath, background.path);
      expect(app.appearance.isBackgroundBlurEnabled,
          AppearanceSettings.defaults.isBackgroundBlurEnabled);
      expect(app.appearance.backgroundBlurRadius,
          AppearanceSettings.defaults.backgroundBlurRadius);
      expect(app.appearance.backgroundDimOpacity,
          AppearanceSettings.defaults.backgroundDimOpacity);
      expect(app.appearance.glassTintStrength,
          AppearanceSettings.defaults.glassTintStrength);
      expect(app.appearance.glassBorderStrength,
          AppearanceSettings.defaults.glassBorderStrength);
      expect(app.appearance.accentColorName,
          AppearanceSettings.defaults.accentColorName);
      expect(app.appearance.textSizeName,
          AppearanceSettings.defaults.textSizeName);
    } finally {
      if (await tempDir.exists()) await tempDir.delete(recursive: true);
    }
  });

  test('appearance preference changes clear stale background feedback only',
      () async {
    final app = AppController(store: FakeStore())
      ..statusMessage = '背景已导入'
      ..errorMessage = '背景保存失败：旧图片不可用';

    await app.saveAppearance(AppearanceSettings.defaults.copyWith(
      accentColorName: 'rose',
      textSizeName: 'large',
    ));

    expect(app.statusMessage, isNull);
    expect(app.errorMessage, isNull);

    app
      ..statusMessage = '配置已保存'
      ..errorMessage = 'API Base URL 格式不正确';

    await app.saveAppearance(AppearanceSettings.defaults.copyWith(
      accentColorName: 'mint',
      textSizeName: 'comfortable',
    ));

    expect(app.statusMessage, '配置已保存');
    expect(app.errorMessage, 'API Base URL 格式不正确');
  });

  test('custom background import notifies after success status is set',
      () async {
    final tempDir = await Directory.systemTemp.createTemp('ai-reply-bg-');
    final source = File('${tempDir.path}/source.png');
    final image = img.Image(width: 3200, height: 1800);
    img.fill(image, color: img.ColorRgb8(40, 120, 200));
    await source.writeAsBytes(img.encodePng(image));
    final app = AppController(
      store: FakeStore(),
      supportDirectoryProvider: () async => tempDir,
    );
    final statuses = <String?>[];
    app.addListener(() => statuses.add(app.statusMessage));

    try {
      await app.importCustomBackground(source.path);

      expect(app.statusMessage, '背景已导入');
      expect(statuses, contains('背景已导入'));
      final background = File(app.appearance.customBackgroundPath!);
      expect(await background.exists(), isTrue);
      final decoded = img.decodeJpg(await background.readAsBytes());
      expect(decoded, isNotNull);
      expect(decoded!.width, 2560);
      expect(decoded.height, 1440);
      expect(background.path, startsWith(tempDir.path));
    } finally {
      app.dispose();
      if (await tempDir.exists()) await tempDir.delete(recursive: true);
    }
  });

  test('custom background import uses dedicated jpeg export settings',
      () async {
    final tempDir =
        await Directory.systemTemp.createTemp('ai-reply-bg-settings-');
    final source = File('${tempDir.path}/source.png');
    await source.writeAsBytes([1, 2, 3]);
    final imageService = DeferredBackgroundImageService();
    final app = AppController(
      store: FakeStore(),
      imageService: imageService,
      supportDirectoryProvider: () async => tempDir,
    );

    try {
      final pending = app.importCustomBackground(source.path);
      await imageService.started.future;

      expect(imageService.maxWidth, 2560);
      expect(imageService.quality, 0.86);

      imageService.completer.complete();
      await pending;
    } finally {
      app.dispose();
      if (await tempDir.exists()) await tempDir.delete(recursive: true);
    }
  });

  test(
      'stale custom background import cannot restore background after clear all',
      () async {
    final tempDir =
        await Directory.systemTemp.createTemp('ai-reply-bg-stale-clear-');
    final source = File('${tempDir.path}/source.png');
    await source.writeAsBytes([1, 2, 3]);
    final imageService = DeferredBackgroundImageService();
    final app = AppController(
      store: FakeStore(),
      imageService: imageService,
      supportDirectoryProvider: () async => tempDir,
    );

    try {
      final pending = app.importCustomBackground(source.path);
      await imageService.started.future;

      await app.clearAllLocalData();
      imageService.completer.complete();
      await pending;

      expect(app.appearance.customBackgroundPath, isNull);
      expect(app.statusMessage, '本地数据已清空，API 配置已恢复默认。');
      expect(imageService.outputPath, isNotNull);
      expect(await File(imageService.outputPath!).exists(), isFalse);
    } finally {
      app.dispose();
      if (await tempDir.exists()) await tempDir.delete(recursive: true);
    }
  });

  test(
      'stale custom background import cannot override default background reset',
      () async {
    final tempDir =
        await Directory.systemTemp.createTemp('ai-reply-bg-stale-reset-');
    final source = File('${tempDir.path}/source.png');
    final previous = File('${tempDir.path}/custom-background-old.jpg');
    await source.writeAsBytes([1, 2, 3]);
    await previous.writeAsBytes([4, 5, 6]);
    final imageService = DeferredBackgroundImageService();
    final app = AppController(
      store: FakeStore(),
      imageService: imageService,
      supportDirectoryProvider: () async => tempDir,
    )..appearance = AppearanceSettings.defaults
        .copyWith(customBackgroundPath: previous.path);

    try {
      final pending = app.importCustomBackground(source.path);
      await imageService.started.future;

      await app.resetCustomBackground();
      imageService.completer.complete();
      await pending;

      expect(app.appearance.customBackgroundPath, isNull);
      expect(app.statusMessage, '已恢复默认背景');
      expect(await previous.exists(), isFalse);
      expect(imageService.outputPath, isNotNull);
      expect(await File(imageService.outputPath!).exists(), isFalse);
    } finally {
      app.dispose();
      if (await tempDir.exists()) await tempDir.delete(recursive: true);
    }
  });

  test('stale custom background import save cannot overwrite reset feedback',
      () async {
    final tempDir =
        await Directory.systemTemp.createTemp('ai-reply-bg-stale-save-reset-');
    final source = File('${tempDir.path}/source.png');
    final previous = File('${tempDir.path}/custom-background-old.jpg');
    await source.writeAsBytes([1, 2, 3]);
    await previous.writeAsBytes([4, 5, 6]);
    final imageService = DeferredBackgroundImageService();
    final store = DeferredPreferenceStore()..delayAppearanceSave = true;
    final app = AppController(
      store: store,
      imageService: imageService,
      supportDirectoryProvider: () async => tempDir,
    )..appearance = AppearanceSettings.defaults
        .copyWith(customBackgroundPath: previous.path);

    try {
      final pending = app.importCustomBackground(source.path);
      await imageService.started.future;

      imageService.completer.complete();
      await store.appearanceStarted.future;

      final importedPath = imageService.outputPath!;
      expect(app.appearance.customBackgroundPath, importedPath);
      expect(await File(importedPath).exists(), isTrue);

      await app.resetCustomBackground();
      expect(app.appearance.customBackgroundPath, isNull);
      expect(app.statusMessage, '已恢复默认背景');

      store.appearanceRelease.complete();
      await pending;

      expect(app.appearance.customBackgroundPath, isNull);
      expect(app.statusMessage, '已恢复默认背景');
      expect(store.savedAppearance?.customBackgroundPath, isNull);
      expect(await previous.exists(), isFalse);
      expect(await File(importedPath).exists(), isFalse);
    } finally {
      app.dispose();
      if (await tempDir.exists()) await tempDir.delete(recursive: true);
    }
  });

  test('stale custom background reset cannot overwrite import feedback',
      () async {
    final tempDir =
        await Directory.systemTemp.createTemp('ai-reply-bg-stale-reset-save-');
    final source = File('${tempDir.path}/source.png');
    final previous = File('${tempDir.path}/custom-background-old.jpg');
    await source.writeAsBytes([1, 2, 3]);
    await previous.writeAsBytes([4, 5, 6]);
    final imageService = DeferredBackgroundImageService();
    final store = DeferredPreferenceStore()..delayAppearanceSave = true;
    final app = AppController(
      store: store,
      imageService: imageService,
      supportDirectoryProvider: () async => tempDir,
    )..appearance = AppearanceSettings.defaults
        .copyWith(customBackgroundPath: previous.path);

    try {
      final reset = app.resetCustomBackground();
      await store.appearanceStarted.future;
      expect(app.appearance.customBackgroundPath, isNull);

      final import = app.importCustomBackground(source.path);
      await imageService.started.future;
      imageService.completer.complete();
      await import;

      final importedPath = imageService.outputPath!;
      expect(app.appearance.customBackgroundPath, importedPath);
      expect(app.statusMessage, '背景已导入');

      store.appearanceRelease.complete();
      await reset;

      expect(app.appearance.customBackgroundPath, importedPath);
      expect(app.statusMessage, '背景已导入');
      expect(store.savedAppearance?.customBackgroundPath, importedPath);
      expect(await previous.exists(), isFalse);
      expect(await File(importedPath).exists(), isTrue);
    } finally {
      app.dispose();
      if (await tempDir.exists()) await tempDir.delete(recursive: true);
    }
  });

  test('empty custom background import rejects before image service', () async {
    var supportDirectoryCalled = false;
    final imageService = DeferredBackgroundImageService();
    final app = AppController(
      store: FakeStore(),
      imageService: imageService,
      supportDirectoryProvider: () async {
        supportDirectoryCalled = true;
        return Directory.systemTemp;
      },
    )..appearance = AppearanceSettings.defaults.copyWith(
        customBackgroundPath: '/tmp/custom-background-existing.jpg',
      );

    await app.importCustomBackground('   ');

    expect(supportDirectoryCalled, isFalse);
    expect(imageService.started.isCompleted, isFalse);
    expect(imageService.outputPath, isNull);
    expect(app.appearance.customBackgroundPath,
        '/tmp/custom-background-existing.jpg');
    expect(app.statusMessage, isNull);
    expect(app.errorMessage, '背景保存失败：无法读取所选图片，请重新选择。');
  });

  test('custom background import rejects unreadable image bytes', () async {
    final tempDir = await Directory.systemTemp.createTemp('ai-reply-bg-bad-');
    final source = File('${tempDir.path}/source.img');
    await source.writeAsBytes([1, 2, 3]);
    final app = AppController(
      store: FakeStore(),
      supportDirectoryProvider: () async => tempDir,
    );

    try {
      await app.importCustomBackground(source.path);

      expect(app.statusMessage, isNull);
      expect(app.errorMessage, contains('背景保存失败'));
      expect(app.appearance.customBackgroundPath, isNull);
      expect(await File('${tempDir.path}/custom-background.jpg').exists(),
          isFalse);
    } finally {
      app.dispose();
      if (await tempDir.exists()) await tempDir.delete(recursive: true);
    }
  });

  test('person profile filter searches and sorts profiles', () {
    final older = DateTime(2026, 1, 1);
    final newer = DateTime(2026, 1, 2);
    final complete = PersonProfile(
      displayName: '小林',
      aliases: const ['Lin'],
      relationship: '同事',
      personalityTraits: const ['稳'],
      innerNeeds: const ['效率'],
      keyPersonPoints: const ['项目负责人'],
      momentsInsights: const ['爱发工作动态'],
      tonePreferences: const ['直接一点'],
      boundaries: const ['别催促'],
      facts: const ['在北京'],
      updatedAt: older,
    );
    final recent = PersonProfile(
      displayName: '阿周',
      relationship: '朋友',
      tonePreferences: const ['轻松一点'],
      facts: const ['周末常运动'],
      updatedAt: newer,
    );

    expect(
        filterPersonProfiles([complete, recent],
                sortMode: PersonProfileSortMode.recent, query: '')
            .map((profile) => profile.displayName),
        ['阿周', '小林']);
    expect(
        filterPersonProfiles([recent, complete],
                sortMode: PersonProfileSortMode.coverage, query: '')
            .map((profile) => profile.displayName),
        ['小林', '阿周']);
    expect(
        filterPersonProfiles([complete, recent],
                sortMode: PersonProfileSortMode.name, query: '')
            .map((profile) => profile.displayName),
        ['小林', '阿周']);
    expect(
        filterPersonProfiles(
          [
            PersonProfile(displayName: '人物10'),
            PersonProfile(displayName: '人物2'),
            PersonProfile(displayName: '人物1'),
          ],
          sortMode: PersonProfileSortMode.name,
          query: '',
        ).map((profile) => profile.displayName),
        ['人物1', '人物2', '人物10']);
    final sameUpdatedAt = DateTime(2026, 1, 4);
    final spacedAlice = PersonProfile(
      id: 'b',
      displayName: '  Alice  ',
      updatedAt: sameUpdatedAt,
    );
    final cleanAlice = PersonProfile(
      id: 'a',
      displayName: 'Alice',
      updatedAt: sameUpdatedAt,
    );
    final bob = PersonProfile(
      id: 'c',
      displayName: 'Bob',
      updatedAt: sameUpdatedAt,
    );
    expect(
      filterPersonProfiles(
        [bob, spacedAlice, cleanAlice],
        sortMode: PersonProfileSortMode.name,
        query: '',
      ).map((profile) => profile.id),
      ['a', 'b', 'c'],
    );
    expect(
      filterPersonProfiles(
        [bob, spacedAlice, cleanAlice],
        sortMode: PersonProfileSortMode.recent,
        query: '',
      ).map((profile) => profile.id),
      ['a', 'b', 'c'],
    );
    expect(
        filterPersonProfiles([complete, recent],
            sortMode: PersonProfileSortMode.recent, query: '负责人'),
        [complete]);
    expect(
        filterPersonProfiles([complete, recent],
            sortMode: PersonProfileSortMode.recent, query: '项 目-负责人'),
        [complete]);
    expect(
        filterPersonProfiles([complete, recent],
            sortMode: PersonProfileSortMode.recent, query: 'li_n'),
        [complete]);
    expect(complete.searchableIdentityValues, ['小林', 'Lin', '同事']);
    expect(complete.searchableInsightValues,
        containsAll(['稳', '效率', '项目负责人', '别催促', '在北京']));
    expect(complete.previewTags, ['稳', '效率', '项目负责人']);

    final noisy = PersonProfile(
      displayName: '脏画像',
      personalityTraits: const [' ', '未知'],
      innerNeeds: const ['未知'],
      keyPersonPoints: const [' '],
      momentsInsights: const ['未知'],
      tonePreferences: const [' '],
      boundaries: const ['未知'],
      facts: const ['真实信息'],
      updatedAt: DateTime(2026, 1, 3),
    );
    expect(personProfileCoveragePercent(noisy), 14);
    expect(noisy.coveragePercent, 14);
    expect(noisy.searchableIdentityValues, ['脏画像']);
    expect(noisy.searchableInsightValues, ['真实信息']);
    expect(noisy.searchableText, '脏画像 真实信息');
    expect(
      filterPersonProfiles([noisy, recent],
              sortMode: PersonProfileSortMode.coverage, query: '')
          .map((profile) => profile.displayName),
      ['阿周', '脏画像'],
    );
    expect(
      filterPersonProfiles([noisy, recent],
          sortMode: PersonProfileSortMode.recent, query: '未知'),
      isEmpty,
    );

    final source = File('lib/core/person_profile_collection_helpers.dart')
        .readAsStringSync();
    expect(source, contains('String _sortablePersonProfileName('));
    expect(source, contains('cleanPresentationText(profile.displayName)'));
  });

  test('person profile id helpers ignore stale selections', () {
    final profiles = [
      PersonProfile(id: 'target', displayName: '小林'),
      PersonProfile(id: 'other', displayName: '阿周'),
    ];

    expect(normalizedPersonProfileId(' target '), 'target');
    expect(normalizedPersonProfileId('  '), isNull);
    final modelSource = File('lib/core/models.dart').readAsStringSync();
    final profileSource =
        File('lib/core/person_profile_collection_helpers.dart')
            .readAsStringSync();
    final styleSource =
        File('lib/core/chat_style_collection_helpers.dart').readAsStringSync();
    final modelStringSource =
        File('lib/core/model_json_string_helpers.dart').readAsStringSync();
    expect(modelSource, contains('String? cleanIdentifierText(String? value)'));
    expect(profileSource, contains('return cleanIdentifierText(id);'));
    expect(styleSource,
        contains('return cleanIdentifierText(id)?.toLowerCase();'));
    expect(modelStringSource,
        contains('return cleanIdentifierText(value?.toString());'));
    expect(profileSource, isNot(contains('id?.trim()')));
    expect(personProfileIdsMatch(' target ', 'target'), isTrue);
    expect(personProfileById(profiles, 'target')?.displayName, '小林');
    expect(personProfileById(profiles, ' target ')?.displayName, '小林');
    expect(personProfileById(profiles, '  '), isNull);
    expect(personProfileById(profiles, 'missing'), isNull);
    expect(restorablePersonProfileId(profiles, 'target'), 'target');
    expect(restorablePersonProfileId(profiles, ' target '), 'target');
    expect(restorablePersonProfileId(profiles, 'missing'), isNull);
    expect(restorablePersonProfileId(profiles, null), isNull);
  });

  test('screen profile selection helpers share restored profile lookup', () {
    final profiles = [
      PersonProfile(id: 'target', displayName: '小林'),
      PersonProfile(id: 'other', displayName: '阿周'),
    ];
    final app = AppController()
      ..profiles = profiles
      ..currentSelectedProfileId = ' target ';

    expect(restorableScreenProfileId(app), 'target');
    expect(
      selectedScreenProfile(profiles, restorableScreenProfileId(app)),
      same(profiles.first),
    );

    app.currentSelectedProfileId = ' missing ';

    expect(restorableScreenProfileId(app), isNull);
    expect(selectedScreenProfile(profiles, ' missing '), isNull);
  });

  test('person insight upsert matches cleaned profile labels', () {
    final profile = PersonProfile(
      id: 'target',
      displayName: ' 小林 ',
      aliases: const [' Lin ', '未知'],
      relationship: '同事',
    );

    final result = upsertPersonInsight(
      profiles: [profile],
      insight: const PersonInsight(
        displayName: 'lin',
        keyPersonPoints: ['喜欢提前确认时间'],
      ),
      sceneSummary: '  会议安排  ',
    );

    expect(result.profiles, hasLength(1));
    expect(result.savedProfile?.id, 'target');
    expect(result.savedProfile?.displayName, 'lin');
    expect(result.savedProfile?.aliases, ['Lin', '小林']);
    expect(result.savedProfile?.relationship, '同事');
    expect(result.savedProfile?.keyPersonPoints, ['喜欢提前确认时间']);
    expect(result.savedProfile?.lastSceneSummary, '会议安排');

    final separatedLabelResult = upsertPersonInsight(
      profiles: [
        PersonProfile(
          id: 'separated',
          displayName: 'Lin Lin',
          aliases: const ['林同学'],
        ),
      ],
      insight: const PersonInsight(
        displayName: '  ',
        aliases: ['lin_lin'],
        keyPersonPoints: ['会先确认边界'],
      ),
      sceneSummary: '项目推进',
    );

    expect(separatedLabelResult.profiles, hasLength(1));
    expect(separatedLabelResult.savedProfile?.id, 'separated');
    expect(separatedLabelResult.savedProfile?.displayName, 'Lin Lin');
    expect(separatedLabelResult.savedProfile?.aliases, ['林同学', 'lin_lin']);
    expect(
      separatedLabelResult.savedProfile?.keyPersonPoints,
      ['会先确认边界'],
    );

    final source = File('lib/core/person_profile_collection_helpers.dart')
        .readAsStringSync();
    expect(source, contains('.map(normalizedLooseKey)'));

    final upsertSource =
        File('lib/core/profile_insights.dart').readAsStringSync();
    expect(
      upsertSource.indexOf('final index = updatedProfiles.indexWhere'),
      lessThan(upsertSource.indexOf('if (name == null)')),
    );
  });

  test('history record id helpers ignore stale selections', () {
    final records = [
      GenerationRecord(
        id: 'target',
        inputType: ChatInputType.text,
        selectedStyleName: '自然',
        replies: [
          ReplySuggestion(styleLabel: '自然', text: '好呀', reason: '测试'),
        ],
      ),
      GenerationRecord(
        id: ' other ',
        inputType: ChatInputType.text,
        selectedStyleName: '自然',
        replies: [
          ReplySuggestion(styleLabel: '自然', text: '可以', reason: '测试'),
        ],
      ),
    ];
    final stale = GenerationRecord(
      id: ' target ',
      inputType: ChatInputType.text,
      selectedStyleName: '自然',
      replies: [
        ReplySuggestion(styleLabel: '自然', text: '旧', reason: '测试'),
      ],
    );

    expect(normalizedHistoryRecordId(' target '), 'target');
    expect(normalizedHistoryRecordId('  '), isNull);
    final source = File('lib/core/history_record_collection_helpers.dart')
        .readAsStringSync();
    expect(source, contains('return cleanIdentifierText(id);'));
    expect(source, isNot(contains('id?.trim()')));
    expect(historyRecordIdsMatch(' target ', 'target'), isTrue);
    expect(historyRecordIdsMatch('Target', 'target'), isFalse);
    expect(historyRecordById(records, 'target'), same(records.first));
    expect(historyRecordById(records, ' target '), same(records.first));
    expect(historyRecordById(records, 'other'), same(records.last));
    expect(historyRecordById(records, '  '), isNull);
    expect(historyRecordById(records, 'missing'), isNull);
    expect(retainedHistoryRecord(records, stale), same(records.first));
    expect(restorableHistoryRecordId(records, ' target '), 'target');
    expect(restorableHistoryRecordId(records, ' other '), ' other ');
    expect(restorableHistoryRecordId(records, ' missing '), isNull);
  });

  test('presentation helpers keep grapheme clusters intact', () {
    expect(presentationInitial('  👩‍💻 小林'), '👩‍💻');
    expect(presentationInitial('   '), '?');
    expect(
      truncatedPresentationText('👨‍👩‍👧‍👦AB', maxCharacters: 1),
      '👨‍👩‍👧‍👦...',
    );
    expect(truncatedPresentationText('一二三四', maxCharacters: 3), '一二三...');
    expect(truncatedPresentationText(' 一二 ', maxCharacters: 3), '一二');
    expect(truncatedPresentationText('   ', maxCharacters: 3), '');

    final source =
        File('lib/core/presentation_helpers.dart').readAsStringSync();
    expect(source, contains("import 'text_cleaning.dart';"));
    expect(source, contains('final trimmed = cleanNonEmptyText(value);'));
    expect(source, contains("final trimmed = cleanNonEmptyText(value) ?? '';"));
    expect(source, isNot(contains('value.trim()')));
  });

  test('person profile merge follows iOS name and confidence rules', () {
    final profile = PersonProfile(
      displayName: '小林',
      aliases: const ['Lin'],
      relationship: '同事',
      confidence: 0.8,
    );

    final lowerConfidence = profile.merged(
      const PersonInsight(
        displayName: '林同学',
        aliases: ['小林'],
        relationship: '朋友',
        personalityTraits: [
          '稳',
          '未知',
          '细心',
          '稳',
          '慢热',
          '靠谱',
          '直接',
          '谨慎',
          '外向',
          '计划型',
          '重效率',
          '讲边界',
          '会照顾人',
          '喜欢复盘',
        ],
        confidence: 0.3,
      ),
      '新场景',
    );

    expect(lowerConfidence.displayName, '林同学');
    expect(lowerConfidence.aliases, ['Lin', '小林']);
    expect(lowerConfidence.relationship, '朋友');
    expect(lowerConfidence.personalityTraits, [
      '稳',
      '细心',
      '慢热',
      '靠谱',
      '直接',
      '谨慎',
      '外向',
      '计划型',
      '重效率',
      '讲边界',
      '会照顾人',
      '喜欢复盘',
    ]);
    expect(lowerConfidence.confidence, 0.8);

    final higherConfidence = lowerConfidence.merged(
      const PersonInsight(displayName: '林同学', confidence: 0.95),
      null,
    );

    expect(higherConfidence.confidence, 0.95);
  });

  test('person profile merge cleans noisy existing profile fields', () {
    final profile = PersonProfile(
      displayName: '  ',
      aliases: const [' ', '未知', 'Lin'],
      relationship: '未知',
      communicationStyle: '  ',
      personalityTraits: const ['未知', '稳'],
      innerNeeds: const [' '],
      lastSceneSummary: '未知',
      lastUpdateReason: '  ',
    );

    final merged = profile.merged(
      const PersonInsight(
        displayName: '  ',
        aliases: ['小林'],
        relationship: '  ',
        personalityTraits: ['细心'],
      ),
      '未知',
    );

    expect(merged.displayName, '未命名人物');
    expect(merged.aliases, ['Lin', '小林']);
    expect(merged.relationship, isNull);
    expect(merged.communicationStyle, isNull);
    expect(merged.personalityTraits, ['稳', '细心']);
    expect(merged.innerNeeds, isEmpty);
    expect(merged.lastSceneSummary, isNull);
    expect(merged.lastUpdateReason, isNull);
  });

  test('person profile normalized preserves recency while touch refreshes it',
      () {
    final createdAt = DateTime.utc(2026, 1, 1);
    final updatedAt = DateTime.utc(2026, 1, 2);
    final touchedAt = DateTime.utc(2026, 1, 3);
    final profile = PersonProfile(
      id: ' dirty-profile ',
      displayName: '  ',
      aliases: const ['未知', ' Lin ', 'lin', ' '],
      relationship: '未知',
      communicationStyle: '  直接一点  ',
      personalityTraits: const [' 稳 ', '稳', '未知'],
      innerNeeds: const [' '],
      keyPersonPoints: const [' 会提前确认 ', '未知'],
      momentsInsights: const ['未知'],
      tonePreferences: const ['短句回应', '未知'],
      boundaries: const [' '],
      facts: const [' 在上海 '],
      lastSceneSummary: '未知',
      lastUpdateReason: '  ',
      confidence: 1.4,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );

    final normalized = profile.normalized();
    final touched = profile.touch(updatedAt: touchedAt);

    expect(normalized.id, 'dirty-profile');
    expect(normalized.displayName, '未命名人物');
    expect(normalized.aliases, ['Lin']);
    expect(normalized.relationship, isNull);
    expect(normalized.communicationStyle, '直接一点');
    expect(normalized.personalityTraits, ['稳']);
    expect(normalized.innerNeeds, isEmpty);
    expect(normalized.keyPersonPoints, ['会提前确认']);
    expect(normalized.momentsInsights, isEmpty);
    expect(normalized.tonePreferences, ['短句回应']);
    expect(normalized.boundaries, isEmpty);
    expect(normalized.facts, ['在上海']);
    expect(normalized.lastSceneSummary, isNull);
    expect(normalized.lastUpdateReason, isNull);
    expect(normalized.confidence, 1);
    expect(normalized.createdAt, createdAt);
    expect(normalized.updatedAt, updatedAt);
    expect(touched.toJson(), {
      ...normalized.toJson(),
      'updatedAt': touchedAt.toIso8601String(),
    });
  });

  test('person profile merge keeps previous display name as match alias', () {
    final profile = PersonProfile(
      displayName: '小林',
      aliases: const ['Lin'],
      relationship: '同事',
    );

    final renamed = profile.merged(
      const PersonInsight(displayName: '林同学', confidence: 0.7),
      '新场景',
    );

    expect(renamed.displayName, '林同学');
    expect(renamed.aliases, ['Lin', '小林']);
    expect(renamed.summaryForPrompt, contains('称呼：林同学'));
    expect(renamed.summaryForPrompt, isNot(contains('别名：')));
    expect(renamed.summaryForPrompt, isNot(contains('小林')));
  });

  test('saving profile normalizes noisy existing profile fields', () async {
    SharedPreferences.setMockInitialValues({});
    final store = FakeStore();
    final app = AppController(store: store);
    final profile = PersonProfile(
      id: 'dirty-profile',
      displayName: '  ',
      aliases: const [' ', '未知', 'Lin', 'lin'],
      relationship: '未知',
      communicationStyle: '  ',
      personalityTraits: const ['未知', '稳', '稳'],
      innerNeeds: const [' '],
      tonePreferences: const ['短句回应', '未知'],
      facts: const ['在上海'],
      lastSceneSummary: '未知',
      lastUpdateReason: '  ',
      confidence: 1.4,
    );

    await app.saveProfile(profile);

    expect(app.profiles.single.displayName, '未命名人物');
    expect(app.profiles.single.aliases, ['Lin']);
    expect(app.profiles.single.relationship, isNull);
    expect(app.profiles.single.communicationStyle, isNull);
    expect(app.profiles.single.personalityTraits, ['稳']);
    expect(app.profiles.single.innerNeeds, isEmpty);
    expect(app.profiles.single.tonePreferences, ['短句回应']);
    expect(app.profiles.single.facts, ['在上海']);
    expect(app.profiles.single.lastSceneSummary, isNull);
    expect(app.profiles.single.lastUpdateReason, isNull);
    expect(app.profiles.single.confidence, 1);
    expect(store.savedProfiles.single.toJson()['displayName'], '未命名人物');
  });

  test('person profile prompt summary matches iOS field schema', () {
    final profile = PersonProfile(
      displayName: '小林',
      aliases: const ['Lin'],
      relationship: '朋友',
      communicationStyle: '慢热',
      personalityTraits: const ['谨慎', '细腻', '谨慎'],
      innerNeeds: const ['安全感'],
      keyPersonPoints: const ['讨厌催促'],
      momentsInsights: const ['常分享工作日常'],
      tonePreferences: const ['直接一点'],
      boundaries: const ['不要连环追问'],
      facts: const ['在上海'],
      lastUpdateReason: '最近从聊天记录更新',
    );

    expect(profile.promptSummaryLines, [
      '称呼：小林',
      '关系：朋友',
      '沟通风格：慢热',
      '性格倾向：谨慎、细腻',
      '内心需求：安全感',
      '关键人物点：讨厌催促',
      '朋友圈观察：常分享工作日常',
      '偏好：直接一点',
      '避雷：不要连环追问',
      '已知信息：在上海',
      '最近画像依据：最近从聊天记录更新',
    ]);
    expect(profile.summaryForPrompt, contains('称呼：小林'));
    expect(profile.summaryForPrompt, contains('性格倾向：谨慎、细腻'));
    expect(profile.summaryForPrompt, isNot(contains('谨慎、细腻、谨慎')));
    expect(profile.summaryForPrompt, contains('内心需求：安全感'));
    expect(profile.summaryForPrompt, contains('朋友圈观察：常分享工作日常'));
    expect(profile.summaryForPrompt, contains('偏好：直接一点'));
    expect(profile.summaryForPrompt, contains('避雷：不要连环追问'));
    expect(profile.summaryForPrompt, contains('已知信息：在上海'));
    expect(profile.summaryForPrompt, isNot(contains('昵称：')));
    expect(profile.summaryForPrompt, isNot(contains('别名：')));
    expect(profile.summaryForPrompt, isNot(contains('；')));
  });

  test('person profile prompt summary cleans noisy legacy fields', () {
    final profile = PersonProfile(
      displayName: '  ',
      relationship: '未知',
      communicationStyle: '   ',
      personalityTraits: const [' ', '未知', '细腻'],
      innerNeeds: const ['安全感', '未知'],
      keyPersonPoints: const ['  '],
      momentsInsights: const ['未知'],
      tonePreferences: const ['直接一点', ' '],
      boundaries: const ['未知', '不要连环追问'],
      facts: const [' ', '在上海'],
      lastUpdateReason: '未知',
    );

    expect(profile.promptSummaryLines, [
      '称呼：未命名人物',
      '性格倾向：细腻',
      '内心需求：安全感',
      '偏好：直接一点',
      '避雷：不要连环追问',
      '已知信息：在上海',
    ]);
    expect(profile.summaryForPrompt, contains('称呼：未命名人物'));
    expect(profile.summaryForPrompt, contains('性格倾向：细腻'));
    expect(profile.summaryForPrompt, contains('内心需求：安全感'));
    expect(profile.summaryForPrompt, contains('偏好：直接一点'));
    expect(profile.summaryForPrompt, contains('避雷：不要连环追问'));
    expect(profile.summaryForPrompt, contains('已知信息：在上海'));
    expect(profile.summaryForPrompt, isNot(contains('未知')));
    expect(profile.summaryForPrompt, isNot(contains('关系：')));
    expect(profile.summaryForPrompt, isNot(contains('沟通风格：')));
    expect(profile.summaryForPrompt, isNot(contains('最近画像依据：')));
  });

  test('profile detail coverage suggests missing sections like iOS', () {
    final sparse = PersonProfile(
      displayName: '小林',
      personalityTraits: const ['直接坦率'],
      tonePreferences: const ['短句回应'],
    );
    final complete = PersonProfile(
      displayName: '小林',
      personalityTraits: const ['直接坦率'],
      innerNeeds: const ['稳定回应'],
      keyPersonPoints: const ['提前确认时间'],
      momentsInsights: const ['常发运动动态'],
      tonePreferences: const ['短句回应'],
      boundaries: const ['避免催促'],
      facts: const ['喜欢咖啡'],
    );

    expect(
      sparse.coverageSections,
      [
        ('性格', true),
        ('需求', false),
        ('关键点', false),
        ('动态', false),
        ('回复', true),
        ('避雷', false),
        ('事实', false),
      ],
    );
    expect(sparse.coveragePercent, 29);
    expect(
      app_shell.PersonProfilePresentation(sparse).missingCoverageSuggestion,
      '建议优先补：需求、关键点、动态',
    );
    expect(complete.coverageSections.every((section) => section.$2), isTrue);
    expect(complete.coveragePercent, 100);
    expect(
      app_shell.PersonProfilePresentation(complete).missingCoverageSuggestion,
      isNull,
    );

    final noisy = PersonProfile(
      displayName: '小林',
      personalityTraits: const ['未知'],
      tonePreferences: const ['短句回应'],
      boundaries: const [' '],
      facts: const ['喜欢咖啡'],
    );
    expect(
      noisy.coverageSections.where((section) => section.$2).map(
            (section) => section.$1,
          ),
      ['回复', '事实'],
    );
    expect(
      app_shell.PersonProfilePresentation(noisy).missingCoverageSuggestion,
      '建议优先补：性格、需求、关键点',
    );
    expect(noisy.detailRelationshipLabel, '关系待确认');
    expect(noisy.displayCommunicationStyle, isNull);
    expect(noisy.displayLatestWriteSources, isEmpty);
    expect(noisy.listSubtitleLabel, '等待更多聊天样本完善画像');
  });

  test('copying profile summary reports feedback', () async {
    SharedPreferences.setMockInitialValues({});
    final profile = PersonProfile(
      displayName: '小林',
      relationship: '朋友',
      tonePreferences: const ['短句回应'],
    );
    final app = AppController();

    await app.copyProfileSummary(profile);

    expect(app.statusMessage, '已复制画像上下文');
  });

  test('successful profile summary copy clears stale copy errors', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') return null;
      return null;
    });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });
    final profile = PersonProfile(
      displayName: '小林',
      relationship: '朋友',
      tonePreferences: const ['短句回应'],
    );
    final app = AppController()..errorMessage = '复制失败：旧错误';

    await app.copyProfileSummary(profile);

    expect(app.statusMessage, '已复制画像上下文');
    expect(app.errorMessage, isNull);
  });

  test('clipboard copy paths share revision guard helpers', () {
    final runtimeSource =
        File('lib/core/app_state_runtime_helpers.dart').readAsStringSync();
    final clipboardSource =
        File('lib/core/app_state_clipboard_actions.dart').readAsStringSync();

    expect(runtimeSource, contains('int _captureGenerationRevision()'));
    expect(runtimeSource, contains('bool _isCurrentGenerationRevision('));
    expect(runtimeSource, contains('int _captureProfilesRevision()'));
    expect(runtimeSource, contains('bool _isCurrentProfilesRevision('));
    expect(
      RegExp(r'_captureGenerationRevision\(\)')
          .allMatches(clipboardSource)
          .length,
      2,
    );
    expect(
      RegExp(r'_isCurrentGenerationRevision\(')
          .allMatches(clipboardSource)
          .length,
      3,
    );
    expect(clipboardSource,
        contains('retainedHistoryRecord(history, record) != null'));
    expect(clipboardSource, contains('_captureProfilesRevision();'));
    expect(clipboardSource, contains('_isCurrentProfilesRevision('));
    expect(clipboardSource, isNot(contains('== _generationRevision')));
    expect(clipboardSource, isNot(contains('== _profilesRevision')));
  });

  test('feedback paths share runtime status helpers', () {
    final clipboardSource =
        File('lib/core/app_state_clipboard_actions.dart').readAsStringSync();
    final runtimeSource =
        File('lib/core/app_state_runtime_helpers.dart').readAsStringSync();
    final localDataSource =
        File('lib/core/app_state_local_data.dart').readAsStringSync();
    final modelFetchingSource =
        File('lib/core/app_state_model_fetching.dart').readAsStringSync();
    final generationSource =
        File('lib/core/app_state_reply_generation_flow.dart')
            .readAsStringSync();

    expect(runtimeSource, contains('void _setStatusMessage(String message)'));
    expect(runtimeSource, contains('void _setErrorMessage(String message)'));
    expect(runtimeSource, contains('void _clearFeedbackMessages()'));
    expect(runtimeSource, contains('void _applyStatusMessage(String message)'));
    expect(runtimeSource, contains('void _applyErrorMessage(String message)'));
    expect(runtimeSource, contains('errorMessage = null;'));
    expect(runtimeSource, contains('statusMessage = null;'));
    expect(localDataSource, contains('_setStatusMessage(message);'));
    expect(localDataSource, contains('_setErrorMessage(message);'));
    expect(localDataSource, contains('_clearFeedbackMessages();'));
    expect(modelFetchingSource, contains('_beginModelFetchOperation();'));
    expect(modelFetchingSource, isNot(contains('_clearFeedbackMessages();')));
    expect(
        modelFetchingSource, contains('_applyStatusMessage(applyRecommended'));
    expect(generationSource, contains('_clearFeedbackMessages();'));
    expect(generationSource,
        contains('_applyErrorMessage(userMessageFor(error));'));
    expect(
      RegExp(r"_setStatusMessage\('已复制'\)").allMatches(clipboardSource).length,
      2,
    );
    expect(
      clipboardSource,
      contains("_setStatusMessage('已复制画像上下文')"),
    );
    expect(clipboardSource, contains("_setErrorMessage('复制失败："));
    expect(clipboardSource, isNot(contains("statusMessage = '已复制';")));
  });

  test('stale profile summary copy cannot overwrite clear all feedback',
      () async {
    final clipboardStarted = Completer<void>();
    final clipboardRelease = Completer<void>();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        if (!clipboardStarted.isCompleted) clipboardStarted.complete();
        await clipboardRelease.future;
        throw PlatformException(code: 'clipboard', message: '剪贴板不可用');
      }
      return null;
    });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });
    SharedPreferences.setMockInitialValues({});
    final store = FakeStore();
    final profile = PersonProfile(
      displayName: '小林',
      relationship: '朋友',
      tonePreferences: const ['短句回应'],
    );
    final app = AppController(store: store)
      ..profiles = [profile]
      ..selectedProfile = profile;

    final pending = app.copyProfileSummary(profile);
    await clipboardStarted.future;

    await app.clearAllLocalData();
    clipboardRelease.complete();
    final didCopy = await pending;

    expect(didCopy, isFalse);
    expect(app.profiles, isEmpty);
    expect(app.selectedProfile, isNull);
    expect(store.didClearAll, isTrue);
    expect(app.statusMessage, '本地数据已清空，API 配置已恢复默认。');
    expect(app.errorMessage, isNull);
  });

  testWidgets('profile detail copy summary shows iOS-style button feedback',
      (tester) async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') return null;
      return null;
    });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });
    final profile = PersonProfile(
      displayName: '小林',
      relationship: '同事',
      tonePreferences: const ['直接一点'],
    );
    final controller = AppController(store: FakeStore())
      ..profiles = [profile]
      ..selectedProfile = profile;

    await tester.pumpWidget(ProviderScope(
      overrides: [
        app_shell.appProvider.overrideWith((ref) => controller),
      ],
      child: const MaterialApp(home: app_shell.ProfileDetailScreen()),
    ));

    await tester.tap(find.text('复制画像上下文'));
    await tester.pump();

    expect(find.text('已复制画像上下文'), findsOneWidget);
    expect(controller.statusMessage, '已复制画像上下文');

    await tester.pump(const Duration(milliseconds: 1400));
    expect(find.text('复制画像上下文'), findsOneWidget);

    await tester.drag(find.byType(ListView), const Offset(0, -1200));
    await tester.pump();
    expect(find.textContaining('不会根据头像或面部识别真实身份'), findsOneWidget);
  });

  testWidgets('profile detail hides empty latest write source like iOS',
      (tester) async {
    final profile = PersonProfile(
      displayName: '小林',
      relationship: '同事',
      tonePreferences: const ['直接一点'],
    );
    final controller = AppController(store: FakeStore())
      ..profiles = [profile]
      ..selectedProfile = profile;

    await tester.pumpWidget(ProviderScope(
      overrides: [
        app_shell.appProvider.overrideWith((ref) => controller),
      ],
      child: const MaterialApp(home: app_shell.ProfileDetailScreen()),
    ));

    expect(find.text('最近写入依据'), findsNothing);

    final updated = PersonProfile(
      id: profile.id,
      displayName: '小林',
      relationship: '同事',
      tonePreferences: const ['直接一点'],
      lastSceneSummary: '最近在聊项目排期',
      lastUpdateReason: '聊天中多次提到时间安排',
    );
    controller
      ..profiles = [updated]
      ..selectedProfile = updated;
    controller.notifyListeners();
    await tester.pump();

    expect(find.text('最近写入依据'), findsOneWidget);
    expect(find.text('最近在聊项目排期'), findsOneWidget);
    expect(find.text('聊天中多次提到时间安排'), findsOneWidget);
  });

  testWidgets('profile detail cleans blank presentation fields like iOS',
      (tester) async {
    final profile = PersonProfile(
      displayName: '小林',
      relationship: ' 未知 ',
      communicationStyle: '   ',
      lastSceneSummary: '   ',
      lastUpdateReason: '未知',
      facts: const [' ', '未知', '喜欢慢慢聊', '喜欢慢慢聊'],
    );
    final controller = AppController(store: FakeStore())
      ..profiles = [profile]
      ..selectedProfile = profile;

    await tester.pumpWidget(ProviderScope(
      overrides: [
        app_shell.appProvider.overrideWith((ref) => controller),
      ],
      child: const MaterialApp(home: app_shell.ProfileDetailScreen()),
    ));

    expect(find.text('关系待确认'), findsOneWidget);
    expect(find.text('沟通风格'), findsNothing);
    expect(find.text('最近写入依据'), findsNothing);
    expect(find.text('未知'), findsNothing);

    await tester.drag(find.byType(ListView), const Offset(0, -1200));
    await tester.pump();

    expect(find.text('喜欢慢慢聊'), findsOneWidget);
  });

  testWidgets('profile list card cleans relationship and falls back to scene',
      (tester) async {
    final profile = PersonProfile(
      displayName: '小林',
      relationship: ' 未知 ',
      communicationStyle: '   ',
      lastSceneSummary: '最近在聊项目排期',
      keyPersonPoints: const ['记得细节'],
    );

    await tester.pumpWidget(ProviderScope(
      child: MaterialApp(
        home: Scaffold(
          body: app_shell.PersonProfileListCard(
            profile: profile,
            onOpen: () {},
          ),
        ),
      ),
    ));

    expect(find.text('小林'), findsOneWidget);
    expect(find.text('最近在聊项目排期'), findsOneWidget);
    expect(find.text('记得细节'), findsOneWidget);
    expect(find.text('未知'), findsNothing);
  });

  test('profile preview tags clean blank values before taking top tags', () {
    final profile = PersonProfile(
      displayName: '小林',
      personalityTraits: const [' ', '未知', '靠谱', '靠谱'],
      innerNeeds: const ['慢热', '靠谱'],
      keyPersonPoints: const ['记得细节'],
      tonePreferences: const ['直接一点'],
    );

    expect(profile.previewTagValues, ['靠谱', '慢热', '记得细节', '直接一点']);
    expect(profile.previewTags, ['靠谱', '慢热', '记得细节']);
    expect(profile.pickerPreviewTagValues, ['记得细节', '直接一点']);
    expect(profile.pickerSubtitleLabel, '直接一点');

    final profileWithContext = PersonProfile(
      displayName: '小林',
      relationship: ' 同事 ',
      communicationStyle: ' 直接一点 ',
      tonePreferences: const ['慢一点'],
    );
    expect(profileWithContext.pickerSubtitleLabel, '同事 · 直接一点');
  });

  testWidgets('profile picker preview tags clean duplicate noisy values',
      (tester) async {
    final profile = PersonProfile(
      id: 'target',
      displayName: '小林',
      relationship: '同事',
      keyPersonPoints: const [' 记得细节 ', '未知'],
      tonePreferences: const ['直接一点'],
      boundaries: const ['记得细节', '别催促'],
    );
    expect(profile.pickerPreviewTagValues, ['记得细节', '直接一点', '别催促']);

    await tester.pumpWidget(ProviderScope(
      child: MaterialApp(
        home: Scaffold(
          body: PersonProfilePickerCard(
            title: '选择人物',
            profiles: [profile],
            selectedProfileId: ' target ',
            onChanged: (_) {},
            emptyText: '暂无人物',
            autoSummary: '自动判断',
            selectedSummary: (_) => '已选择小林',
          ),
        ),
      ),
    ));

    expect(find.text('记得细节'), findsOneWidget);
    expect(find.text('直接一点'), findsOneWidget);
    expect(find.text('别催促'), findsOneWidget);
    expect(find.text('未知'), findsNothing);
  });

  testWidgets('profile picker uses cleaned display labels for legacy names',
      (tester) async {
    final profile = PersonProfile(
      id: 'target',
      displayName: '未知',
      relationship: '未知',
      communicationStyle: '  ',
      tonePreferences: const ['未知', ' '],
    );

    await tester.pumpWidget(ProviderScope(
      child: MaterialApp(
        home: Scaffold(
          body: PersonProfilePickerCard(
            title: '选择人物',
            profiles: [profile],
            selectedProfileId: 'target',
            onChanged: (_) {},
            emptyText: '暂无人物',
            autoSummary: '自动判断',
            selectedSummary: (profile) => '已选择${profile.displayLabel}',
          ),
        ),
      ),
    ));

    expect(find.text('未命名人物'), findsOneWidget);
    expect(find.text('已选择未命名人物'), findsOneWidget);
    expect(find.text('等待更多聊天样本完善画像'), findsOneWidget);
    expect(find.text('未知'), findsNothing);
  });

  testWidgets('person insight result tags clean duplicate noisy values',
      (tester) async {
    const insight = PersonInsight(
      displayName: '小林',
      tonePreferences: [' 慢热 ', '未知'],
      boundaries: ['慢热', '别催促'],
      personalityTraits: ['靠谱'],
      confidence: 1.2,
      updateReason: ' 聊天截图 ',
    );

    expect(insight.resultTitle(null), '小林');
    expect(insight.resultTags, ['慢热', '别催促', '靠谱']);
    expect(insight.resultFootnoteParts, ['置信度 100%', '聊天截图']);

    await tester.pumpWidget(ProviderScope(
      child: MaterialApp(
        home: Scaffold(
          body: PersonInsightResultCard(
            insight: insight,
            sceneSummary: '聊天截图',
            savedProfile: null,
            onOpenProfile: (_) {},
            onEditDraft: (_) {},
          ),
        ),
      ),
    ));

    expect(find.text('慢热'), findsOneWidget);
    expect(find.text('别催促'), findsOneWidget);
    expect(find.text('靠谱'), findsOneWidget);
    expect(find.text('置信度 100% · 聊天截图'), findsOneWidget);
    expect(find.text('未知'), findsNothing);
  });

  test('profile selection adopts latest retained profile instance', () {
    final stale = PersonProfile(
      id: ' same-profile ',
      displayName: '旧名字',
      keyPersonPoints: const ['旧画像'],
    );
    final latest = PersonProfile(
      id: 'same-profile',
      displayName: '新名字',
      keyPersonPoints: const ['新画像'],
    );
    final app = AppController()..profiles = [latest];

    app.selectProfile(stale);

    expect(app.selectedProfile, same(latest));
    expect(app.selectedProfile?.displayName, '新名字');
    expect(app.selectedProfile?.keyPersonPoints, ['新画像']);
  });

  test('profile selection still allows unsaved drafts', () {
    final draft = PersonProfile(
      id: 'unsaved-draft',
      displayName: '未保存草稿',
      keyPersonPoints: const ['待确认'],
    );
    final app = AppController();

    app.selectProfile(draft);

    expect(app.selectedProfile, same(draft));
    expect(app.profiles, isEmpty);
  });

  testWidgets('profile editor disables save until name is filled like iOS',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final controller = AppController(store: FakeStore());

    await tester.pumpWidget(ProviderScope(
      overrides: [
        app_shell.appProvider.overrideWith((ref) => controller),
      ],
      child: const MaterialApp(home: app_shell.ProfileEditorScreen()),
    ));

    final scrollable = find.byType(Scrollable).first;
    await tester.scrollUntilVisible(
      find.text('保存人物'),
      500,
      scrollable: scrollable,
    );
    await tester.pump();
    final saveButton = find.ancestor(
      of: find.text('保存人物'),
      matching: find.byType(FilledButton),
    );
    expect(tester.widget<FilledButton>(saveButton).onPressed, isNull);

    controller.setError('旧人物表单错误');
    await tester.pump();
    expect(find.text('旧人物表单错误'), findsOneWidget);

    final nameField = find.byWidgetPredicate(
      (widget) => widget is TextField && widget.decoration?.labelText == '人物名称',
    );
    await tester.scrollUntilVisible(nameField, -500, scrollable: scrollable);
    await tester.pump();
    await tester.enterText(nameField, '未知');
    await tester.pump();

    await tester.scrollUntilVisible(
      find.text('保存人物'),
      500,
      scrollable: scrollable,
    );
    await tester.pump();
    expect(tester.widget<FilledButton>(saveButton).onPressed, isNull);

    await tester.scrollUntilVisible(nameField, -500, scrollable: scrollable);
    await tester.pump();
    await tester.enterText(nameField, '小林');
    await tester.pump();

    expect(controller.errorMessage, isNull);
    expect(find.text('旧人物表单错误'), findsNothing);
    await tester.scrollUntilVisible(
      find.text('保存人物'),
      500,
      scrollable: scrollable,
    );
    await tester.pump();
    expect(tester.widget<FilledButton>(saveButton).onPressed, isNotNull);
  });

  testWidgets(
      'profile detail does not show copied feedback on clipboard failure',
      (tester) async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        throw PlatformException(code: 'clipboard', message: '剪贴板不可用');
      }
      return null;
    });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });
    final profile = PersonProfile(
      displayName: '小林',
      relationship: '同事',
      tonePreferences: const ['直接一点'],
    );
    final controller = AppController(store: FakeStore())
      ..profiles = [profile]
      ..selectedProfile = profile;

    await tester.pumpWidget(ProviderScope(
      overrides: [
        app_shell.appProvider.overrideWith((ref) => controller),
      ],
      child: const MaterialApp(home: app_shell.ProfileDetailScreen()),
    ));

    await tester.tap(find.text('复制画像上下文'));
    await tester.pump();

    expect(find.text('复制画像上下文'), findsOneWidget);
    expect(find.text('已复制画像上下文'), findsNothing);
    expect(controller.errorMessage, '复制失败：剪贴板不可用');
    expect(controller.statusMessage, isNull);
  });

  test('saving profile refreshes recency and active references', () async {
    SharedPreferences.setMockInitialValues({});
    final older = DateTime.now().subtract(const Duration(days: 3));
    final newer = DateTime.now().subtract(const Duration(days: 1));
    final target = PersonProfile(
      id: 'target',
      displayName: '小林',
      aliases: const ['Lin'],
      createdAt: older,
      updatedAt: older,
    );
    final other = PersonProfile(
      id: 'other',
      displayName: '阿周',
      updatedAt: newer,
    );
    final app = AppController(api: FakeApi())
      ..profiles = [other, target]
      ..selectedProfile = target
      ..simulationProfile = target
      ..currentMomentProfile = target;

    await app.saveProfile(target);

    expect(app.profiles.first.id, 'target');
    expect(app.profiles.first.updatedAt.isAfter(newer), isTrue);
    expect(app.profiles.first.aliases, ['Lin']);
    expect(app.selectedProfile?.updatedAt, app.profiles.first.updatedAt);
    expect(app.simulationProfile?.updatedAt, app.profiles.first.updatedAt);
    expect(app.currentMomentProfile?.updatedAt, app.profiles.first.updatedAt);
  });

  test('saving profile clamps confidence to iOS editor range', () async {
    SharedPreferences.setMockInitialValues({});
    final app = AppController(api: FakeApi());

    await app.saveProfile(PersonProfile(
      displayName: '小林',
      confidence: 1.4,
    ));

    expect(app.profiles.single.confidence, 1);

    await app.saveProfile(PersonProfile(
      id: app.profiles.single.id,
      displayName: '小林',
      confidence: -0.2,
    ));

    expect(app.profiles.single.confidence, 0);
  });

  test('reply insight upsert refreshes active profile references', () async {
    SharedPreferences.setMockInitialValues({});
    final older = DateTime.now().subtract(const Duration(days: 3));
    final newer = DateTime.now().subtract(const Duration(days: 1));
    final target = PersonProfile(
      id: 'target',
      displayName: '小林',
      createdAt: older,
      updatedAt: older,
      confidence: 0.4,
    );
    final other = PersonProfile(
      id: 'other',
      displayName: '阿周',
      updatedAt: newer,
    );
    final app = AppController(api: InsightReplyApi())
      ..apiKey = 'sk-test'
      ..profiles = [other, target]
      ..selectedProfile = target
      ..simulationProfile = target
      ..currentMomentProfile = target;

    await app.generateText('对方：今天几点开会', ChatStyle.defaultStyle, '');

    expect(app.profiles.first.id, 'target');
    expect(app.profiles.first.aliases, ['Lin']);
    expect(app.profiles.first.keyPersonPoints, ['喜欢提前确认时间']);
    expect(app.profiles.first.confidence, 0.9);
    expect(app.selectedProfile?.keyPersonPoints, ['喜欢提前确认时间']);
    expect(app.simulationProfile?.keyPersonPoints, ['喜欢提前确认时间']);
    expect(app.currentMomentProfile?.keyPersonPoints, ['喜欢提前确认时间']);
  });

  test('chat text helpers count and append clipboard text', () {
    final stats = chatTextStats('  对方：明天见\n\n我：好呀  ');
    final emojiStats = chatTextStats('  👩‍💻：OK\n我：👌  ');

    expect(stats.characters, 10);
    expect(stats.lines, 2);
    expect(emojiStats.characters, 7);
    expect(emojiStats.lines, 2);
    expect(cleanChatTextInput('  对方：明天见  '), '对方：明天见');
    expect(cleanChatTextInput('   \n  '), isNull);
    expect(hasUsableChatText(' 我：好呀 '), isTrue);
    expect(hasUsableChatText('   '), isFalse);
    expect(appendClipboardText('', '  新内容  '), '新内容');
    expect(appendClipboardText('已有内容  ', '  新内容  '), '已有内容\n新内容');
    expect(appendClipboardText('  已有内容  ', '  新内容  '), '已有内容\n新内容');
    expect(appendClipboardText('已有内容', '   '), '已有内容');

    final source = File('lib/core/text_date_helpers.dart').readAsStringSync();
    expect(source, contains('=> cleanNonEmptyText(text);'));
    expect(source, contains('where(_hasChatTextLine)'));
    expect(source, contains('final existing = cleanChatTextInput(current);'));
    expect(source, isNot(contains('final trimmed = text?.trim();')));
    expect(source, isNot(contains('line.trim().isNotEmpty')));
    expect(source, isNot(contains('current.trimRight()')));
  });

  test('sanitized goal trims without truncating like iOS', () {
    final rawGoal = '  ${'自然接住对方的情绪。' * 40}  ';

    final sanitized = sanitizedGoal(rawGoal);

    expect(sanitizedGoal('  未知  '), '');
    expect(optionalSanitizedGoal('  未知  '), isNull);
    expect(optionalSanitizedGoal('  \n  '), isNull);
    expect(optionalSanitizedGoal('  想轻松一点  '), '想轻松一点');
    expect(sanitized.startsWith('自然接住对方的情绪。'), isTrue);
    expect(sanitized.endsWith('自然接住对方的情绪。'), isTrue);
    expect(sanitized.length, greaterThan(200));
    expect(sanitized.length, ('自然接住对方的情绪。' * 40).length);

    final textScreenSource =
        File('lib/screens/text_input_screen.dart').readAsStringSync();
    final imageScreenSource =
        File('lib/screens/image_generation_screens.dart').readAsStringSync();
    expect(
      textScreenSource,
      contains('final restoredGoal = optionalSanitizedGoal(app.currentGoal);'),
    );
    expect(
      imageScreenSource,
      contains('final restoredGoal = optionalSanitizedGoal(app.currentGoal);'),
    );
    expect(textScreenSource, isNot(contains('app.currentGoal?.trim()')));
    expect(imageScreenSource, isNot(contains('app.currentGoal?.trim()')));
  });

  test('profile editor quick fill appends unique suggestion lines', () {
    expect(
      app_shell.profileEditorTextWithSuggestion('需要稳定回应', '需要稳定回应'),
      '需要稳定回应',
    );
    expect(
      app_shell.profileEditorTextWithSuggestion('Lin', 'lin'),
      'Lin',
    );
    expect(
      app_shell.profileEditorTextWithSuggestion('需要稳定回应', '未知'),
      '需要稳定回应',
    );
    expect(
      app_shell.profileEditorTextWithSuggestion('带有幽默感，重视计划感', '适合轻松、口语化地聊'),
      '带有幽默感\n重视计划感\n适合轻松、口语化地聊',
    );
    expect(
      app_shell.profileEditorTextWithSuggestion('', '给对方一点缓冲空间'),
      '给对方一点缓冲空间',
    );
  });

  test('profile editor draft helper cleans fields before saving', () {
    final createdAt = DateTime.utc(2026, 1, 1);
    final original = PersonProfile(
      id: 'existing-profile',
      displayName: '旧名字',
      createdAt: createdAt,
    );

    expect(canSaveProfileEditorDraft('未知'), isFalse);
    expect(canSaveProfileEditorDraft(' 小林 '), isTrue);
    expect(
      personProfileFromEditorDraft(
        original: original,
        displayName: '未知',
        aliases: '',
        relationship: '',
        communicationStyle: '',
        personalityTraits: '',
        innerNeeds: '',
        keyPersonPoints: '',
        momentsInsights: '',
        tonePreferences: '',
        boundaries: '',
        facts: '',
        lastSceneSummary: '',
        lastUpdateReason: '',
        confidence: 0.5,
      ),
      isNull,
    );

    final draft = personProfileFromEditorDraft(
      original: original,
      displayName: ' 小林 ',
      aliases: ' Lin，lin\n小林 ',
      relationship: '未知',
      communicationStyle: ' 直接一点 ',
      personalityTraits: ' 稳，未知；慢热 ',
      innerNeeds: ' 安全感 ',
      keyPersonPoints: '提前确认、未知',
      momentsInsights: ' 常发工作动态 ',
      tonePreferences: ' 短句回应；少绕弯 ',
      boundaries: ' 不催促 ',
      facts: ' 在上海 ',
      lastSceneSummary: '未知',
      lastUpdateReason: ' 聊天里强调提前确认 ',
      confidence: 0.8,
    );

    expect(draft?.id, 'existing-profile');
    expect(draft?.displayName, '小林');
    expect(draft?.aliases, ['Lin', '小林']);
    expect(draft?.relationship, isNull);
    expect(draft?.communicationStyle, '直接一点');
    expect(draft?.personalityTraits, ['稳', '慢热']);
    expect(draft?.innerNeeds, ['安全感']);
    expect(draft?.keyPersonPoints, ['提前确认']);
    expect(draft?.momentsInsights, ['常发工作动态']);
    expect(draft?.tonePreferences, ['短句回应', '少绕弯']);
    expect(draft?.boundaries, ['不催促']);
    expect(draft?.facts, ['在上海']);
    expect(draft?.lastSceneSummary, isNull);
    expect(draft?.lastUpdateReason, '聊天里强调提前确认');
    expect(draft?.confidence, 0.8);
    expect(draft?.createdAt, createdAt);
  });

  test('presentation text helpers clean profile fields consistently', () {
    expect(cleanNonEmptyText(null), isNull);
    expect(cleanNonEmptyText('   '), isNull);
    expect(cleanNonEmptyText('  未知  '), '未知');
    expect(cleanPresentationText(null), isNull);
    expect(cleanPresentationText('  未知  '), isNull);
    expect(cleanPresentationText('  小林  '), '小林');
    expect(
      cleanPresentationList([' 稳定回应 ', '未知', '', '轻松一点']),
      ['稳定回应', '轻松一点'],
    );
    expect(
      uniqueCleanPresentationList([' Lin ', 'lin', null, '未知', '小林']),
      ['Lin', '小林'],
    );
    expect(
      uniqueCleanPresentationList([' A ', 'a', 'B', 'C'], limit: 2),
      ['A', 'B'],
    );
    expect(splitEditorLines('稳定回应，未知\n轻松一点；  '), ['稳定回应', '轻松一点']);
    expect(splitEditorLines('Lin，lin\n未知；小林'), ['Lin', '小林']);
    expect(joinEditorLines([' Lin ', 'lin', '未知', '小林']), 'Lin\n小林');
  });

  test('reply and simulation option cleaners share presentation text dedupe',
      () {
    final replies = cleanUniqueReplySuggestions(
      [
        ReplySuggestion(styleLabel: '  ', text: ' 你好 ', reason: '  开场  '),
        ReplySuggestion(styleLabel: '重复', text: '你好', reason: '重复'),
        ReplySuggestion(styleLabel: '空', text: ' 未知 ', reason: '无效'),
        ReplySuggestion(styleLabel: ' 稳妥 ', text: ' 再见 ', reason: ' 收束 '),
      ],
      limit: 2,
    );
    expect(replies.map((reply) => reply.text), ['你好', '再见']);
    expect(replies.map((reply) => reply.styleLabel), ['建议', '稳妥']);
    expect(replies.map((reply) => reply.reason), ['开场', '收束']);

    final options = cleanUniqueSimulationOptions(
      [
        SimulationOption(text: ' 先接住情绪 ', label: ' ', reason: ' 稳一点 '),
        SimulationOption(text: '先接住情绪', label: '重复', reason: '重复'),
        SimulationOption(text: '未知', label: '空', reason: '无效'),
        SimulationOption(text: ' 问一个具体问题 ', label: '追问', reason: ' 延展 '),
      ],
      limit: 2,
    );
    expect(options.map((option) => option.text), ['先接住情绪', '问一个具体问题']);
    expect(options.map((option) => option.label), ['建议', '追问']);
    expect(options.map((option) => option.reason), ['稳一点', '延展']);
  });

  test('generation record presentation helpers clean noisy display fields', () {
    final record = GenerationRecord(
      id: 'presentation-history-record',
      inputType: ChatInputType.text,
      sceneSummary: '未知',
      platform: '  微信  ',
      relationshipGuess: '未知',
      latestMessage: '  晚上吃啥  ',
      emotion: '  ',
      riskNotice: '未知',
      selectedStyleName: '未知',
      userGoal: '  ',
      copiedReply: '  好呀  ',
      replies: const [],
      createdAt: DateTime(2026, 1, 2),
    );

    expect(record.displaySceneSummary, '未识别场景');
    expect(record.displayPlatform, '微信');
    expect(record.displayRelationshipGuess, isNull);
    expect(record.displayLatestMessage, '晚上吃啥');
    expect(record.displayEmotion, isNull);
    expect(record.displayRiskNotice, isNull);
    expect(record.displayStyleName, '自然');
    expect(record.displayUserGoal, isNull);
    expect(record.displayCopiedReply, '好呀');
  });

  test('chat reply response presentation helpers clean noisy display fields',
      () {
    const response = ChatReplyResponse(
      sceneSummary: '未知',
      platform: '  微信  ',
      relationshipGuess: '未知',
      latestMessage: '  晚上吃啥  ',
      emotion: '  ',
      riskNotice: '未知',
      replies: [],
    );

    expect(response.displaySceneSummary, '未识别');
    expect(response.displayPlatform, '微信');
    expect(response.displayRelationshipGuess, isNull);
    expect(response.displayLatestMessage, '晚上吃啥');
    expect(response.displayEmotion, isNull);
    expect(response.displayRiskNotice, isNull);
    expect(response.resultInfoLines, [
      ('场景', '未识别'),
      ('平台', '微信'),
      ('最后一句', '晚上吃啥'),
    ]);
  });

  test('profile insight cleaning uses shared presentation text helpers', () {
    final presentationSource =
        File('lib/core/presentation_helpers.dart').readAsStringSync();
    final textHelperSource =
        File('lib/core/presentation_text_helpers.dart').readAsStringSync();
    final insightSource =
        File('lib/core/profile_insights.dart').readAsStringSync();
    final modelsSource = File('lib/core/models.dart').readAsStringSync();
    final modelStringsSource =
        File('lib/core/model_json_string_helpers.dart').readAsStringSync();
    final modelCapabilityInferenceSource =
        File('lib/core/api_model_capability_inference.dart').readAsStringSync();
    final modelResponseSource =
        File('lib/core/model_response_helpers.dart').readAsStringSync();
    final simulationModelsSource =
        File('lib/core/simulation_models.dart').readAsStringSync();
    final apiServiceSource =
        File('lib/core/api_service.dart').readAsStringSync();
    final apiParsingSource =
        File('lib/core/api_parsing.dart').readAsStringSync();

    expect(presentationSource,
        contains("export 'presentation_text_helpers.dart';"));
    expect(textHelperSource, contains('String? cleanPresentationText('));
    expect(textHelperSource, contains('List<String> cleanPresentationList('));
    expect(textHelperSource,
        contains('List<String> uniqueCleanPresentationList('));
    expect(textHelperSource, contains('int? limit'));
    expect(textHelperSource,
        contains('List<T> uniqueByCleanPresentationText<T>('));
    expect(insightSource, contains("import 'presentation_text_helpers.dart';"));
    expect(
        insightSource, isNot(contains("import 'presentation_helpers.dart';")));
    expect(insightSource, isNot(contains('String? _clean(')));
    expect(insightSource, isNot(contains('List<String> _cleanList(')));
    expect(insightSource, isNot(contains('List<String> _uniqueClean(')));
    expect(modelsSource, contains("import 'presentation_text_helpers.dart';"));
    expect(modelStringsSource, contains('cleanPresentationText('));
    expect(
        modelStringsSource,
        contains(
            'return uniqueCleanPresentationList([...current, ...incoming], limit: 12);'));
    expect(modelStringsSource, isNot(contains('final seen = <String>{};')));
    expect(modelStringsSource, isNot(contains('String? _clean(')));
    expect(modelResponseSource, contains('uniqueByCleanPresentationText('));
    expect(modelResponseSource, isNot(contains('final seen = <String>{};')));
    expect(simulationModelsSource, contains('uniqueByCleanPresentationText('));
    expect(simulationModelsSource, isNot(contains('final seen = <String>{};')));
    expect(modelCapabilityInferenceSource, contains('cleanPresentationText'));
    expect(modelCapabilityInferenceSource, isNot(contains('.map(_clean)')));
    expect(
        apiServiceSource, contains("import 'presentation_text_helpers.dart';"));
    expect(apiParsingSource,
        contains('return cleanPresentationText(value?.toString());'));
    expect(apiParsingSource, isNot(contains("text == '未知'")));
  });

  test('history date helper mirrors iOS Chinese short date display', () {
    expect(chineseShortDate(DateTime(2026, 1, 2, 13, 45)), '2026年1月2日');
  });

  test('relative date helper mirrors iOS short recency labels', () {
    final now = DateTime(2026, 1, 8, 12);
    expect(
        chineseRelativeShortDate(now.subtract(const Duration(seconds: 20)),
            now: now),
        '刚刚');
    expect(
        chineseRelativeShortDate(now.subtract(const Duration(minutes: 5)),
            now: now),
        '5分钟前');
    expect(
        chineseRelativeShortDate(now.subtract(const Duration(hours: 3)),
            now: now),
        '3小时前');
    expect(chineseRelativeShortDate(DateTime(2026, 1, 7, 23), now: now), '昨天');
    expect(chineseRelativeShortDate(DateTime(2026, 1, 5, 12), now: now), '3天前');
    expect(chineseRelativeShortDate(DateTime(2025, 12, 30, 12), now: now),
        '2025年12月30日');
  });

  test('settings snapshot summarizes setup state and next action', () {
    const missingKey = SettingsSnapshot(
      hasAPIKey: false,
      config: APIConfig.defaults,
      historyCount: 2,
      profileCount: 1,
      personalization: ReplyPersonalizationSettings.defaults,
      defaultStyleName: '自然',
    );
    final ready = SettingsSnapshot(
      hasAPIKey: true,
      config: APIConfig.defaults,
      historyCount: 2,
      profileCount: 1,
      personalization: ReplyPersonalizationSettings(
        userGender: UserGender.female,
        userAgeText: '95 后',
        customStyles: [
          ChatStyle(name: '克制', description: '短句', rules: ['少问'])
        ],
      ),
      defaultStyleName: '自然',
    );

    expect(missingKey.isAPIReady, isFalse);
    expect(missingKey.isOverviewReady, isFalse);
    expect(missingKey.statusTitle, '需要配置 API');
    expect(missingKey.nextActionTitle, contains('接口配置'));
    expect(missingKey.historyMetricValue, '2');
    expect(missingKey.profileMetricValue, '1');
    expect(ready.isAPIReady, isTrue);
    expect(ready.isShortcutReady, isTrue);
    expect(ready.isOverviewReady, isTrue);
    expect(ready.statusTitle, 'API 已就绪');
    expect(ready.visionLine, contains(APIConfig.defaults.visionModelName));
    expect(ready.personalizationLine, contains('我的资料'));
    expect(ready.personalizationLine, contains('自定义风格 1'));
    expect(ready.nextActionTitle, contains('快捷回复'));

    final noisyAge = SettingsSnapshot(
      hasAPIKey: true,
      config: APIConfig.defaults,
      historyCount: 0,
      profileCount: 0,
      personalization: ReplyPersonalizationSettings(
        userAgeText: '未知',
        customStyles: [
          ChatStyle(name: '未知', description: '占位', rules: const ['短句']),
        ],
      ),
      defaultStyleName: '自然',
    );
    expect(noisyAge.personalizationLine, isNot(contains('我的资料')));
    expect(noisyAge.personalizationLine, isNot(contains('自定义风格')));

    const emptyData = SettingsSnapshot(
      hasAPIKey: true,
      config: APIConfig.defaults,
      historyCount: 0,
      profileCount: 0,
      personalization: ReplyPersonalizationSettings.defaults,
      defaultStyleName: '自然',
    );
    expect(emptyData.historyMetricValue, '暂无');
    expect(emptyData.profileMetricValue, '暂无');

    const defensiveEmptyData = SettingsSnapshot(
      hasAPIKey: true,
      config: APIConfig.defaults,
      historyCount: -2,
      profileCount: -1,
      personalization: ReplyPersonalizationSettings.defaults,
      defaultStyleName: '自然',
    );
    expect(defensiveEmptyData.safeHistoryCount, 0);
    expect(defensiveEmptyData.safeProfileCount, 0);
    expect(defensiveEmptyData.historyMetricValue, '暂无');
    expect(defensiveEmptyData.profileMetricValue, '暂无');
  });

  test('settings snapshot sends incomplete screenshot setup back to api', () {
    final snapshot = SettingsSnapshot(
      hasAPIKey: true,
      config: APIConfig.defaults.copyWith(enableImageInput: false),
      historyCount: 0,
      profileCount: 0,
      personalization: ReplyPersonalizationSettings.defaults,
      defaultStyleName: '自然',
    );

    expect(snapshot.isAPIReady, isTrue);
    expect(snapshot.isShortcutReady, isFalse);
    expect(snapshot.isOverviewReady, isFalse);
    expect(snapshot.statusTitle, '截图回复待完善');
    expect(snapshot.statusSubtitle, contains('截图模式'));
    expect(snapshot.visionLine, contains('截图模式'));
    expect(snapshot.nextActionTitle, contains('完善截图回复配置'));
    expect(snapshot.nextActionDescription, contains('截图模式'));

    final unmarkedVisionSnapshot = SettingsSnapshot(
      hasAPIKey: true,
      config: APIConfig.defaults.copyWith(
        visionModelName: 'plain-chat',
        modelCapabilities: const {
          'plain-chat': ModelCapability(),
        },
      ),
      historyCount: 0,
      profileCount: 0,
      personalization: ReplyPersonalizationSettings.defaults,
      defaultStyleName: '自然',
    );

    expect(unmarkedVisionSnapshot.isShortcutReady, isFalse);
    expect(unmarkedVisionSnapshot.visionLine, contains('标记为多模态'));
    expect(unmarkedVisionSnapshot.visionLine, isNot('视觉模型：plain-chat'));
  });

  test('settings snapshot requires text model before reporting api ready', () {
    final snapshot = SettingsSnapshot(
      hasAPIKey: true,
      config: APIConfig.defaults.copyWith(textModelName: ''),
      historyCount: 0,
      profileCount: 0,
      personalization: ReplyPersonalizationSettings.defaults,
      defaultStyleName: '自然',
    );

    expect(snapshot.isAPIReady, isFalse);
    expect(snapshot.statusTitle, 'API 设置待完善');
    expect(snapshot.statusSubtitle, contains('文本模型名称为空'));
    expect(snapshot.textLine, contains('文本模型名称为空'));
    expect(snapshot.nextActionTitle, contains('接口配置'));
    expect(snapshot.nextActionDescription, contains('文本模型名称为空'));
  });

  test('settings snapshot treats placeholder text model as missing', () {
    final snapshot = SettingsSnapshot(
      hasAPIKey: true,
      config: APIConfig.defaults.copyWith(textModelName: '  未知  '),
      historyCount: 0,
      profileCount: 0,
      personalization: ReplyPersonalizationSettings.defaults,
      defaultStyleName: '自然',
    );

    expect(snapshot.isAPIReady, isFalse);
    expect(snapshot.statusTitle, 'API 设置待完善');
    expect(snapshot.statusSubtitle, contains('文本模型名称为空'));
    expect(snapshot.textLine, contains('文本模型名称为空'));
    expect(snapshot.nextActionDescription, contains('文本模型名称为空'));
  });

  test('privacy snapshot describes api clearing scope', () {
    const withData = PrivacySnapshot(
      hasAPIKey: true,
      hasCustomConfig: true,
      historyCount: 3,
      profileCount: 2,
    );
    const empty = PrivacySnapshot(
      hasAPIKey: false,
      hasCustomConfig: false,
      historyCount: 0,
      profileCount: 0,
    );

    expect(withData.apiLine, '会删除 Key 并恢复默认配置');
    expect(withData.historyLine, '3 条生成结果');
    expect(withData.profileLine, '2 个本地画像');
    expect(withData.historyMetricValue, '3');
    expect(withData.profileMetricValue, '2');
    expect(withData.clearButtonLabel, '清空本地数据');
    expect(withData.hasLocalData, isTrue);
    expect(empty.apiLine, '暂无 Key 或自定义配置');
    expect(empty.historyLine, '暂无历史记录');
    expect(empty.profileLine, '暂无人物画像');
    expect(empty.historyMetricValue, '暂无');
    expect(empty.profileMetricValue, '暂无');
    expect(empty.clearButtonLabel, '暂无可清空数据');
    expect(empty.hasLocalData, isFalse);

    const defensiveEmpty = PrivacySnapshot(
      hasAPIKey: false,
      hasCustomConfig: false,
      historyCount: -2,
      profileCount: -1,
    );
    expect(defensiveEmpty.hasLocalData, isFalse);
    expect(defensiveEmpty.historyLine, '暂无历史记录');
    expect(defensiveEmpty.profileLine, '暂无人物画像');
    expect(defensiveEmpty.historyMetricValue, '暂无');
    expect(defensiveEmpty.profileMetricValue, '暂无');
  });

  testWidgets('privacy page ignores unrelated global success messages',
      (tester) async {
    final controller = AppController(store: FakeStore())
      ..statusMessage = '配置已保存';

    await tester.pumpWidget(ProviderScope(
      overrides: [
        app_shell.appProvider.overrideWith((ref) => controller),
      ],
      child: const MaterialApp(home: app_shell.PrivacyScreen()),
    ));

    expect(find.text('配置已保存'), findsNothing);
    expect(find.text('数据只为生成回复服务'), findsOneWidget);
  });

  testWidgets('privacy page describes two step vision text extraction honestly',
      (tester) async {
    await tester.pumpWidget(const ProviderScope(
      child: MaterialApp(home: app_shell.PrivacyScreen()),
    ));

    expect(find.text('不接入本地 OCR'), findsOneWidget);
    expect(find.textContaining('开启两步视觉时'), findsOneWidget);
    expect(find.textContaining('不长期缓存'), findsOneWidget);
    expect(find.textContaining('不会单独提取或缓存截图文字'), findsNothing);
  });

  test('privacy clear banner is scoped to the clear-all result like iOS', () {
    expect(app_shell.privacyClearSuccessMessage, '本地数据已清空，API 配置已恢复默认。');

    final source = File('lib/screens/privacy_screen.dart').readAsStringSync();
    final start = source.indexOf('class PrivacyScreen');
    final end = source.length;
    expect(start, greaterThanOrEqualTo(0));
    expect(end, greaterThan(start));

    final privacyScreenSource = source.substring(start, end);
    expect(privacyScreenSource,
        contains('const SuccessBanner(privacyClearSuccessMessage)'));
    expect(privacyScreenSource,
        isNot(contains('SuccessBanner(app.statusMessage')));
  });

  testWidgets('privacy page uses semantic api config default comparison',
      (tester) async {
    const textOnly = ModelCapability();
    const multimodal = ModelCapability(isMultimodal: true);
    final controller = AppController(store: FakeStore())
      ..config = APIConfig.defaults.copyWith(modelCapabilities: const {
        'text-only': textOnly,
        'gpt-4o-mini': multimodal,
      });

    await tester.pumpWidget(ProviderScope(
      overrides: [
        app_shell.appProvider.overrideWith((ref) => controller),
      ],
      child: const MaterialApp(home: app_shell.PrivacyScreen()),
    ));
    await tester.scrollUntilVisible(
      find.text('清空本地数据'),
      220,
      scrollable: find.byType(Scrollable),
    );

    expect(find.text('会恢复默认配置'), findsOneWidget);
  });

  testWidgets('privacy page disables clear action when local data is empty',
      (tester) async {
    final controller = AppController(store: FakeStore());

    await tester.pumpWidget(ProviderScope(
      overrides: [
        app_shell.appProvider.overrideWith((ref) => controller),
      ],
      child: const MaterialApp(home: app_shell.PrivacyScreen()),
    ));
    await tester.scrollUntilVisible(
      find.text('暂无可清空数据'),
      220,
      scrollable: find.byType(Scrollable),
    );

    expect(find.text('暂无'), findsWidgets);
    final button = tester
        .widget<FilledButton>(find.widgetWithText(FilledButton, '暂无可清空数据'));
    expect(button.onPressed, isNull);
  });

  test('clear profiles resets simulation without clearing history', () async {
    SharedPreferences.setMockInitialValues({});
    final profile = PersonProfile(displayName: '小林');
    final app = AppController()
      ..profiles = [profile]
      ..selectedProfile = profile
      ..currentGeneratedProfile = profile
      ..currentMomentProfile = profile
      ..currentSelectedProfileId = profile.id
      ..simulationProfile = profile
      ..simulationMessages = [
        SimulationMessage(speaker: SimulationSpeaker.user, text: '你好'),
      ]
      ..simulationResponse = const SimulationTurnResponse(
        personaMessage: '你好',
        sceneState: '开场',
        metrics: [],
        options: [],
        coachTip: '继续',
      )
      ..history = [
        GenerationRecord(
          inputType: ChatInputType.text,
          selectedStyleName: '自然',
          replies: [
            ReplySuggestion(styleLabel: '自然', text: '收到', reason: '测试'),
          ],
        ),
      ];

    await app.clearProfiles();

    expect(app.profiles, isEmpty);
    expect(app.selectedProfile, isNull);
    expect(app.currentGeneratedProfile, isNull);
    expect(app.currentMomentProfile, isNull);
    expect(app.currentSelectedProfileId, isNull);
    expect(app.simulationProfile, isNull);
    expect(app.simulationMessages, isEmpty);
    expect(app.simulationResponse, isNull);
    expect(app.history, isNotEmpty);
  });

  test('profile removal paths share runtime clearing helpers', () {
    final runtimeSource =
        File('lib/core/app_state_runtime_helpers.dart').readAsStringSync();
    final recordsSource =
        File('lib/core/app_state_records.dart').readAsStringSync();
    final localDataSource =
        File('lib/core/app_state_local_data.dart').readAsStringSync();

    expect(runtimeSource, contains('void _clearProfileRuntimeReferences()'));
    expect(runtimeSource,
        contains('void _clearProfileRuntimeReferencesFor(String profileId)'));
    expect(runtimeSource, contains('void _clearSimulationSession({'));
    expect(runtimeSource,
        contains('void _clearSimulationSessionForProfile(String profileId)'));
    expect(runtimeSource, contains('void _invalidateContentOperations()'));
    expect(recordsSource, contains('_clearProfileRuntimeReferencesFor('));
    expect(recordsSource, contains('_clearProfileRuntimeReferences();'));
    expect(recordsSource, contains('_clearSimulationSessionForProfile('));
    expect(recordsSource, contains('_clearSimulationSession();'));
    expect(
      RegExp(r'_invalidateContentOperations\(\);')
          .allMatches(recordsSource)
          .length,
      3,
    );
    expect(localDataSource, contains('_clearProfileRuntimeReferences();'));
    expect(localDataSource,
        contains('_clearSimulationSession(invalidatePending: false'));
    expect(recordsSource, isNot(contains('currentGeneratedProfile = null')));
    expect(recordsSource, isNot(contains('currentMomentProfile = null')));
    expect(recordsSource, isNot(contains('simulationMessages = []')));
    expect(recordsSource, isNot(contains('simulationResponse = null')));
    expect(recordsSource, isNot(contains('_contentRevision += 1')));
  });

  testWidgets('simulation header falls back to relationship when style missing',
      (tester) async {
    final profile = PersonProfile.fromJson({
      'displayName': '小林',
      'relationship': '朋友',
    });

    await tester.pumpWidget(ProviderScope(
      child: MaterialApp(
        home: Scaffold(
          body: app_shell.SimulationHeaderCard(
            profile: profile,
            isBusy: false,
            onRestart: () {},
          ),
        ),
      ),
    ));

    expect(find.text('和 小林 练习反应'), findsOneWidget);
    expect(find.text('朋友'), findsOneWidget);
  });

  testWidgets('simulation header cleans legacy placeholder profile labels',
      (tester) async {
    final profile = PersonProfile(
      displayName: '未知',
      relationship: '未知',
      communicationStyle: '  ',
    );

    await tester.pumpWidget(ProviderScope(
      child: MaterialApp(
        home: Scaffold(
          body: app_shell.SimulationHeaderCard(
            profile: profile,
            isBusy: false,
            onRestart: () {},
          ),
        ),
      ),
    ));

    expect(find.text('和 未命名人物 练习反应'), findsOneWidget);
    expect(find.text('根据人物画像模拟对方语气。'), findsOneWidget);
    expect(find.text('未知'), findsNothing);
  });

  test('starting simulation restarts conversation and keeps scenario',
      () async {
    SharedPreferences.setMockInitialValues({});
    final profile = PersonProfile(displayName: '小林');
    final app = AppController(api: FakeApi())
      ..simulationScenario = SimulationScenario.comfort;

    await app.startSimulation(profile);
    expect(app.simulationProfile, profile);
    expect(app.simulationScenario, SimulationScenario.comfort);
    expect(app.simulationMessages.map((message) => message.text), ['开场-安慰情绪']);

    await app.submitSimulationReply('我明白你有点难受');
    expect(app.simulationMessages.map((message) => message.speaker), [
      SimulationSpeaker.persona,
      SimulationSpeaker.user,
      SimulationSpeaker.persona,
    ]);

    await app.startSimulation(profile);
    expect(app.simulationScenario, SimulationScenario.comfort);
    expect(app.simulationMessages.map((message) => message.text), ['开场-安慰情绪']);
    expect(app.simulationResponse?.options.single.text, '建议回复');
  });

  test('starting simulation normalizes dirty profile before API call',
      () async {
    SharedPreferences.setMockInitialValues({});
    final api = DeferredConnectionApi();
    final dirty = PersonProfile(
      id: ' dirty-profile ',
      displayName: '未知',
      aliases: const [' Lin ', 'Lin', '未知'],
      relationship: '  ',
      communicationStyle: '  慢一点  ',
      keyPersonPoints: const ['  记得提前确认  ', '未知'],
      confidence: 1.4,
    );
    final app = AppController(api: api);

    final pending = app.startSimulation(dirty);
    await api.simulationStarted.future;

    expect(app.simulationProfile, isNot(same(dirty)));
    expect(api.simulationRequestProfile, same(app.simulationProfile));
    expect(app.simulationProfile?.id, 'dirty-profile');
    expect(app.simulationProfile?.displayName, '未命名人物');
    expect(app.simulationProfile?.aliases, ['Lin']);
    expect(app.simulationProfile?.relationship, isNull);
    expect(app.simulationProfile?.communicationStyle, '慢一点');
    expect(app.simulationProfile?.keyPersonPoints, ['记得提前确认']);
    expect(app.simulationProfile?.confidence, 1);

    api.simulationCompleter.complete(
      const SimulationTurnResponse(personaMessage: '规范化开场'),
    );
    await pending;

    expect(app.simulationMessages.map((message) => message.text), ['规范化开场']);
  });

  test('busy simulation ignores duplicate reply submissions like iOS',
      () async {
    SharedPreferences.setMockInitialValues({});
    final profile = PersonProfile(displayName: '小林');
    final api = SequencedSimulationApi();
    final app = AppController(api: api)
      ..simulationProfile = profile
      ..simulationMessages = [
        SimulationMessage(speaker: SimulationSpeaker.persona, text: '开场'),
      ];

    final firstReply = app.submitSimulationReply('第一条回复');
    expect(api.simulationCompleters, hasLength(1));
    expect(api.simulationUserReplies, ['第一条回复']);
    expect(app.isBusy, isTrue);

    await app.submitSimulationReply('第二条回复');

    expect(api.simulationCompleters, hasLength(1));
    expect(api.simulationUserReplies, ['第一条回复']);
    expect(
        app.simulationMessages.map((message) => message.text), ['开场', '第一条回复']);

    api.simulationCompleters.single.complete(
      const SimulationTurnResponse(personaMessage: '对方回应'),
    );
    await firstReply;

    expect(app.isBusy, isFalse);
    expect(app.simulationMessages.map((message) => message.text),
        ['开场', '第一条回复', '对方回应']);
  });

  test('simulation reply submit rejects placeholder text before API call',
      () async {
    SharedPreferences.setMockInitialValues({});
    final profile = PersonProfile(displayName: '小林');
    final api = SequencedSimulationApi();
    final app = AppController(api: api)
      ..simulationProfile = profile
      ..simulationMessages = [
        SimulationMessage(speaker: SimulationSpeaker.persona, text: '开场'),
      ];

    expect(cleanSimulationReplyInput('  未知  '), isNull);
    expect(cleanSimulationReplyInput('  我会认真解释  '), '我会认真解释');
    expect(
      canSubmitSimulationReplyInput(' 我会认真解释 ', isBusy: false),
      isTrue,
    );
    expect(
      canSubmitSimulationReplyInput(' 我会认真解释 ', isBusy: true),
      isFalse,
    );
    expect(canSubmitSimulationReplyInput('未知', isBusy: false), isFalse);

    final succeeded = await app.submitSimulationReply('  未知  ');

    expect(succeeded, isFalse);
    expect(api.simulationCompleters, isEmpty);
    expect(app.isBusy, isFalse);
    expect(app.simulationMessages.map((message) => message.text), ['开场']);
  });

  test('successful simulation reply normalizes dirty response values',
      () async {
    SharedPreferences.setMockInitialValues({});
    final profile = PersonProfile(displayName: '小林');
    final api = SequencedSimulationApi();
    final app = AppController(api: api)
      ..simulationProfile = profile
      ..simulationMessages = [
        SimulationMessage(speaker: SimulationSpeaker.persona, text: '  开场  '),
        SimulationMessage(speaker: SimulationSpeaker.user, text: '未知'),
      ];

    final succeeded = app.submitSimulationReply('  我会认真解释  ');
    expect(api.simulationUserReplies, ['我会认真解释']);
    api.simulationCompleters.single.complete(
      SimulationTurnResponse(
        personaMessage: '未知',
        sceneState: '未知',
        options: [
          SimulationOption(text: '未知', label: '占位', reason: '占位'),
        ],
        feedback: '未知',
        betterReply: '未知',
        coachTip: '未知',
      ),
    );
    await succeeded;

    expect(app.simulationMessages.map((message) => message.text), [
      '开场',
      '我会认真解释',
      '嗯，我听到了。你继续说，我想知道你真正的想法。',
    ]);
    expect(app.simulationResponse?.sceneState, '对话正在进行中。');
    expect(app.simulationResponse?.feedback, isNull);
    expect(app.simulationResponse?.betterReply, isNull);
    expect(app.simulationResponse?.coachTip, '下一轮可以更具体地接住对方情绪。');
    expect(app.simulationResponse?.options.map((option) => option.label),
        ['稳妥', '追问', '澄清']);
  });

  test('newly selected simulation profile resets scenario like iOS', () async {
    SharedPreferences.setMockInitialValues({});
    final profile = PersonProfile(displayName: '小林');
    final app = AppController(api: FakeApi())
      ..simulationScenario = SimulationScenario.comfort;

    await app.startSimulation(profile, resetScenario: true);

    expect(app.simulationProfile, profile);
    expect(app.simulationScenario, SimulationScenario.dailyChat);
    expect(app.simulationMessages.map((message) => message.text), ['开场-日常闲聊']);
  });

  test('simulation entry points reset scenario for new profile selection', () {
    final profileSource =
        File('lib/screens/profile_screens.dart').readAsStringSync();
    final simulationSource =
        File('lib/screens/simulation_screens.dart').readAsStringSync();
    final detailStart = profileSource.indexOf('class ProfileDetailScreen');
    final selectStart =
        simulationSource.indexOf('class SimulationProfileSelectScreen');
    final simulationScreenStart =
        simulationSource.indexOf('class SimulationScreen');

    expect(detailStart, isNonNegative);
    expect(selectStart, isNonNegative);
    expect(simulationScreenStart, greaterThan(selectStart));
    expect(
      profileSource.substring(detailStart),
      contains('resetScenario: true'),
    );
    expect(
      simulationSource.substring(selectStart, simulationScreenStart),
      contains('resetScenario: true'),
    );
    expect(
      simulationSource.substring(simulationScreenStart),
      isNot(contains('resetScenario: true')),
    );
  });

  test('simulation turns share lifecycle helpers', () {
    final runtimeSource =
        File('lib/core/app_state_runtime_helpers.dart').readAsStringSync();
    final simulationSource =
        File('lib/core/app_state_simulation.dart').readAsStringSync();

    expect(runtimeSource, contains('int _beginSimulationSession('));
    expect(runtimeSource,
        contains('_SimulationTurnSnapshot _beginSimulationTurn()'));
    expect(runtimeSource, contains('class _SimulationTurnSnapshot'));
    expect(runtimeSource, contains('bool _isCurrentSimulationTurn({'));
    expect(runtimeSource, contains('void _finishSimulationTurn({'));
    expect(simulationSource, contains('_beginSimulationSession('));
    expect(simulationSource, contains('final turn = _beginSimulationTurn();'));
    expect(
      RegExp(r'_isCurrentSimulationTurn\(').allMatches(simulationSource).length,
      2,
    );
    expect(simulationSource, contains('_finishSimulationTurn('));
    expect(simulationSource,
        isNot(contains('final requestRevision = _contentRevision')));
    expect(
        simulationSource,
        isNot(
            contains('final requestSimulationRevision = _simulationRevision')));
    expect(simulationSource, isNot(contains('_beginBusyOperation();')));
    expect(simulationSource, isNot(contains('_simulationRevision += 1')));
    expect(simulationSource, isNot(contains('simulationMessages = []')));
    expect(simulationSource, isNot(contains('simulationResponse = null')));
    expect(
      simulationSource,
      isNot(contains('requestSimulationRevision != _simulationRevision')),
    );
  });

  test('simulation reply submit preserves draft unless turn succeeds', () {
    final source =
        File('lib/screens/simulation_screens.dart').readAsStringSync();
    final screenStart = source.indexOf('class SimulationScreen');
    final submitStart = source.indexOf(
        'Future<void> _submitReply(AppController app', screenStart);
    final buildStart = source.indexOf('@override\n  Widget build', submitStart);
    final submitBlock = source.substring(submitStart, buildStart);

    expect(screenStart, isNonNegative);
    expect(submitStart, greaterThan(screenStart));
    expect(buildStart, greaterThan(submitStart));
    expect(submitBlock,
        contains('final succeeded = await app.submitSimulationReply'));
    expect(submitBlock, contains('cleanSimulationReplyInput'));
    expect(submitBlock, contains('if (!mounted) return;'));
    expect(submitBlock, contains('if (succeeded)'));
    expect(submitBlock, contains('reply.clear();'));
  });

  test('failed simulation reply rolls back pending user message', () async {
    SharedPreferences.setMockInitialValues({});
    final profile = PersonProfile(displayName: '小林');
    final app = AppController(api: FailingSimulationApi())
      ..statusMessage = '已复制';

    await app.startSimulation(profile);
    expect(app.simulationMessages.map((message) => message.text), ['开场-日常闲聊']);

    await app.submitSimulationReply('我想认真解释一下');

    expect(app.errorMessage, '模拟失败');
    expect(app.statusMessage, isNull);
    expect(app.simulationMessages.map((message) => message.text), ['开场-日常闲聊']);
    expect(app.simulationMessages.map((message) => message.speaker),
        [SimulationSpeaker.persona]);
  });

  test('successful simulation reply clears stale failure feedback', () async {
    SharedPreferences.setMockInitialValues({});
    final profile = PersonProfile(displayName: '小林');
    final api = SequencedSimulationApi();
    final app = AppController(api: api)
      ..simulationProfile = profile
      ..simulationMessages = [
        SimulationMessage(speaker: SimulationSpeaker.persona, text: '开场'),
      ];

    final failed = app.submitSimulationReply('第一条');
    api.simulationCompleters.single.completeError(AppException('模拟失败'));
    await failed;

    expect(app.errorMessage, '模拟失败');
    expect(app.simulationMessages.map((message) => message.text), ['开场']);

    final succeeded = app.submitSimulationReply('第二条');
    expect(api.simulationCompleters, hasLength(2));
    api.simulationCompleters.last.complete(
      const SimulationTurnResponse(personaMessage: '对方回应'),
    );
    await succeeded;

    expect(app.errorMessage, isNull);
    expect(app.statusMessage, isNull);
    expect(app.simulationMessages.map((message) => message.text),
        ['开场', '第二条', '对方回应']);
    expect(app.simulationResponse?.personaMessage, '对方回应');
  });

  testWidgets('simulation profile picker is selection-only like iOS',
      (tester) async {
    final profile =
        PersonProfile(displayName: '小林', communicationStyle: '轻松一点');
    final controller = AppController(store: FakeStore(), api: FakeApi())
      ..profiles = [profile];
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) =>
              const app_shell.SimulationProfileSelectScreen(),
        ),
        GoRoute(
          path: AppRoutes.simulation,
          builder: (context, state) => const SizedBox.shrink(),
        ),
      ],
    );

    await tester.pumpWidget(ProviderScope(
      overrides: [
        app_shell.appProvider.overrideWith((ref) => controller),
      ],
      child: MaterialApp.router(routerConfig: router),
    ));

    expect(find.text('小林'), findsOneWidget);
    expect(find.byTooltip('删除人物'), findsNothing);

    await tester.tap(find.text('小林'));
    await tester.pump();

    expect(controller.profiles, [profile]);
    expect(controller.simulationProfile?.displayName, '小林');
    expect(controller.simulationMessages.map((message) => message.text),
        ['开场-日常闲聊']);
  });

  testWidgets('empty people simulation entry opens training empty state',
      (tester) async {
    final controller = AppController(store: FakeStore(), api: FakeApi());
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const app_shell.PeopleScreen(),
        ),
        GoRoute(
          path: AppRoutes.peopleSelectSimulation,
          builder: (context, state) =>
              const app_shell.SimulationProfileSelectScreen(),
        ),
        GoRoute(
          path: AppRoutes.peopleEdit,
          builder: (context, state) => const Text('新增人物页'),
        ),
      ],
    );

    await tester.pumpWidget(ProviderScope(
      overrides: [
        app_shell.appProvider.overrideWith((ref) => controller),
      ],
      child: MaterialApp.router(routerConfig: router),
    ));

    await tester.tap(find.text('模拟对话训练'));
    await tester.pumpAndSettle();

    expect(find.text('还没有可训练的人物'), findsOneWidget);
    expect(find.text('新增人物页'), findsNothing);
  });

  testWidgets('simulation options show reason and predicted score like iOS',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final profile =
        PersonProfile(displayName: '小林', communicationStyle: '轻松一点');
    final option = SimulationOption(
      text: '我先理解你的感受',
      label: '共情',
      reason: '先接住情绪，再推进下一句。',
      predictedScore: 82,
    );
    final controller = AppController(api: FakeApi())
      ..simulationProfile = profile
      ..simulationMessages = [
        SimulationMessage(speaker: SimulationSpeaker.user, text: '未知'),
        SimulationMessage(
            speaker: SimulationSpeaker.persona, text: '  你真的懂我吗？  '),
      ]
      ..simulationResponse = SimulationTurnResponse(
        personaMessage: '你真的懂我吗？',
        sceneState: '对方在观察你的反应',
        options: [
          SimulationOption(text: '未知', label: '占位', reason: '占位'),
          option,
          SimulationOption(text: '我先理解你的感受', label: '重复', reason: '重复'),
        ],
        coachTip: '别急着解释。',
      );

    await tester.pumpWidget(ProviderScope(
      overrides: [
        app_shell.appProvider.overrideWith((ref) => controller),
      ],
      child: const MaterialApp(home: app_shell.SimulationScreen()),
    ));

    expect(find.text('选项回答'), findsOneWidget);
    expect(find.text('共情'), findsOneWidget);
    expect(find.text('预估 82'), findsOneWidget);
    expect(find.text('先接住情绪，再推进下一句。'), findsOneWidget);
    expect(find.text('你真的懂我吗？'), findsOneWidget);
    expect(find.text('未知'), findsNothing);
    expect(find.text('占位'), findsNothing);
    expect(find.text('重复'), findsNothing);
    expect(find.text('当前指标'), findsOneWidget);
    expect(find.text('对话'), findsOneWidget);
    expect(find.text('教练反馈'), findsOneWidget);
    expect(find.text('自己回答'), findsOneWidget);

    await tester.tap(find.text('填入草稿'));
    await tester.pump();

    final replyField = find.byWidgetPredicate(
      (widget) => widget is TextField && widget.decoration?.labelText == '我的回复',
    );
    expect(tester.widget<TextField>(replyField).controller?.text, '我先理解你的感受');

    final adoptButton = find.text('采用并发送');
    await tester.ensureVisible(adoptButton);
    await tester.tap(adoptButton);
    await tester.pumpAndSettle();

    expect(controller.simulationMessages.map((message) => message.text), [
      '你真的懂我吗？',
      '我先理解你的感受',
      '回应-我先理解你的感受',
    ]);
    expect(tester.widget<TextField>(replyField).controller?.text, isEmpty);
  });

  testWidgets('failed simulation reply keeps draft for retry', (tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final profile = PersonProfile(displayName: '小林');
    final controller = AppController(api: FailingSimulationApi())
      ..simulationProfile = profile
      ..simulationMessages = [
        SimulationMessage(speaker: SimulationSpeaker.persona, text: '开场'),
      ]
      ..simulationResponse = const SimulationTurnResponse(
        personaMessage: '开场',
        coachTip: '试着先接住对方。',
      );

    await tester.pumpWidget(ProviderScope(
      overrides: [
        app_shell.appProvider.overrideWith((ref) => controller),
      ],
      child: const MaterialApp(home: app_shell.SimulationScreen()),
    ));

    final replyField = find.byWidgetPredicate(
      (widget) => widget is TextField && widget.decoration?.labelText == '我的回复',
    );
    await tester.ensureVisible(replyField);
    await tester.enterText(replyField, '未知');
    await tester.pump();
    var submitButton = find.widgetWithText(FilledButton, '提交并打分');
    await tester.ensureVisible(submitButton);
    expect(tester.widget<FilledButton>(submitButton).onPressed, isNull);

    await tester.enterText(replyField, '我想认真解释一下');
    await tester.pump();
    submitButton = find.widgetWithText(FilledButton, '提交并打分');
    await tester.ensureVisible(submitButton);
    await tester.tap(submitButton);
    await tester.pumpAndSettle();

    expect(controller.errorMessage, '模拟失败');
    expect(
        controller.simulationMessages.map((message) => message.text), ['开场']);
    expect(tester.widget<TextField>(replyField).controller?.text, '我想认真解释一下');
  });

  test('profile edits and deletes keep simulation state consistent', () async {
    SharedPreferences.setMockInitialValues({});
    final original = PersonProfile(id: 'person-1', displayName: '旧名字');
    final updated = PersonProfile(id: 'person-1', displayName: '新名字');
    final app = AppController(api: FakeApi())
      ..profiles = [original]
      ..selectedProfile = original
      ..currentSelectedProfileId = original.id
      ..simulationProfile = original
      ..currentMomentProfile = original
      ..simulationMessages = [
        SimulationMessage(speaker: SimulationSpeaker.persona, text: '开场'),
      ]
      ..simulationResponse = const SimulationTurnResponse(
        personaMessage: '开场',
        coachTip: '继续',
      );

    await app.saveProfile(updated);

    expect(app.selectedProfile?.displayName, '新名字');
    expect(app.currentSelectedProfileId, original.id);
    expect(app.simulationProfile?.displayName, '新名字');
    expect(app.currentMomentProfile?.displayName, '新名字');

    await app.deleteProfile(updated);

    expect(app.profiles, isEmpty);
    expect(app.selectedProfile, isNull);
    expect(app.currentSelectedProfileId, isNull);
    expect(app.simulationProfile, isNull);
    expect(app.currentMomentProfile, isNull);
    expect(app.simulationMessages, isEmpty);
    expect(app.simulationResponse, isNull);
  });

  test('profile delete clears legacy spaced profile references', () async {
    SharedPreferences.setMockInitialValues({});
    final profile = PersonProfile(id: 'person-1', displayName: '小林');
    final legacyReference = PersonProfile(id: ' person-1 ', displayName: '旧引用');
    final app = AppController(api: FakeApi())
      ..profiles = [profile]
      ..selectedProfile = legacyReference
      ..currentGeneratedProfile = legacyReference
      ..currentMomentProfile = legacyReference
      ..currentSelectedProfileId = ' person-1 '
      ..simulationProfile = legacyReference
      ..simulationMessages = [
        SimulationMessage(speaker: SimulationSpeaker.persona, text: '开场'),
      ]
      ..simulationResponse = const SimulationTurnResponse(
        personaMessage: '开场',
        coachTip: '继续',
      );

    await app.deleteProfile(profile);

    expect(app.profiles, isEmpty);
    expect(app.selectedProfile, isNull);
    expect(app.currentGeneratedProfile, isNull);
    expect(app.currentMomentProfile, isNull);
    expect(app.currentSelectedProfileId, isNull);
    expect(app.simulationProfile, isNull);
    expect(app.simulationMessages, isEmpty);
    expect(app.simulationResponse, isNull);
  });

  test('deleting unrelated profile preserves active profile references',
      () async {
    SharedPreferences.setMockInitialValues({});
    final active = PersonProfile(id: 'active', displayName: '当前人物');
    final removed = PersonProfile(id: 'removed', displayName: '待删除人物');
    final app = AppController(api: FakeApi())
      ..profiles = [active, removed]
      ..selectedProfile = active
      ..currentGeneratedProfile = active
      ..currentMomentProfile = active
      ..currentSelectedProfileId = active.id
      ..simulationProfile = active
      ..simulationMessages = [
        SimulationMessage(speaker: SimulationSpeaker.persona, text: '开场'),
      ]
      ..simulationResponse = const SimulationTurnResponse(
        personaMessage: '开场',
        coachTip: '继续',
      );

    await app.deleteProfile(removed);

    expect(app.profiles.map((profile) => profile.id), ['active']);
    expect(app.selectedProfile?.id, active.id);
    expect(app.currentGeneratedProfile?.id, active.id);
    expect(app.currentMomentProfile?.id, active.id);
    expect(app.currentSelectedProfileId, active.id);
    expect(app.simulationProfile?.id, active.id);
    expect(app.simulationMessages.map((message) => message.text), ['开场']);
    expect(app.simulationResponse?.personaMessage, '开场');
  });

  test('selected person profile context only includes target profile', () {
    final app = AppController()
      ..profiles = [
        PersonProfile(
          id: ' target ',
          displayName: '小林',
          relationship: '同事',
          tonePreferences: const ['直接一点'],
          lastUpdateReason: '最近从项目截图更新',
        ),
        PersonProfile(
          id: 'other',
          displayName: '小陈',
          relationship: '朋友',
          tonePreferences: const ['轻松一点'],
        ),
      ];

    final context = app.makePersonProfileContext(selectedProfileId: 'target');

    expect(context, startsWith('用户本次指定聊天对象：'));
    expect(context, contains('小林'));
    expect(context, contains('直接一点'));
    expect(context, contains('最近画像依据：最近从项目截图更新'));
    expect(context, isNot(contains('小陈')));
    expect(context, isNot(contains('轻松一点')));
  });

  test('selected person profile context trims id before caching', () {
    final app = AppController()
      ..profiles = [
        PersonProfile(
          id: 'target',
          displayName: '小林',
          tonePreferences: const ['直接一点'],
          updatedAt: DateTime(2026, 1, 1),
        ),
        PersonProfile(
          id: 'other',
          displayName: '小陈',
          tonePreferences: const ['轻松一点'],
          updatedAt: DateTime(2026, 1, 2),
        ),
      ];

    final spaced = app.makePersonProfileContext(selectedProfileId: ' target ');
    final clean = app.makePersonProfileContext(selectedProfileId: 'target');

    expect(spaced, startsWith('用户本次指定聊天对象：'));
    expect(spaced, contains('小林'));
    expect(spaced, isNot(contains('用户未指定聊天对象')));
    expect(spaced, isNot(contains('小陈')));
    expect(clean, spaced);
  });

  test('selected person profile prompt uses shared id normalizer', () {
    final source =
        File('lib/core/prompt_context_builder.dart').readAsStringSync();
    final methodStart = source.indexOf('String makePersonProfileContext({');
    final buildStart = source.indexOf('String _buildPersonProfileContext({');
    final fingerprintStart =
        source.indexOf('String _personalizationPromptFingerprint({');

    expect(methodStart, isNonNegative);
    expect(buildStart, greaterThan(methodStart));
    expect(fingerprintStart, greaterThan(buildStart));
    expect(
      source.substring(methodStart, buildStart),
      contains('normalizedPersonProfileId(selectedProfileId)'),
    );
    expect(
      source.substring(buildStart, fingerprintStart),
      contains('normalizedPersonProfileId(selectedProfileId)'),
    );
  });

  test('selected person profile context refreshes noncandidate profile changes',
      () {
    final target = PersonProfile(
      id: 'target',
      displayName: '目标画像',
      tonePreferences: const ['旧语气'],
      updatedAt: DateTime(2026, 1, 1),
    );
    final app = AppController()
      ..profiles = [
        PersonProfile(
          displayName: '最新画像',
          tonePreferences: const ['最新语气'],
          updatedAt: DateTime(2026, 1, 5),
        ),
        PersonProfile(
          displayName: '次新画像',
          tonePreferences: const ['次新语气'],
          updatedAt: DateTime(2026, 1, 4),
        ),
        PersonProfile(
          displayName: '第三画像',
          tonePreferences: const ['第三语气'],
          updatedAt: DateTime(2026, 1, 3),
        ),
        target,
      ];

    expect(app.makePersonProfileContext(selectedProfileId: 'target'),
        contains('旧语气'));

    app.profiles[3] = PersonProfile(
      id: 'target',
      displayName: '目标画像',
      tonePreferences: const ['新语气'],
      updatedAt: target.updatedAt,
    );

    final refreshed = app.makePersonProfileContext(selectedProfileId: 'target');
    expect(refreshed, contains('新语气'));
    expect(refreshed, isNot(contains('旧语气')));
  });

  test('unselected person profile context uses recent cautious candidates', () {
    final app = AppController()
      ..profiles = [
        PersonProfile(
          displayName: '第六画像',
          tonePreferences: const ['第六语气'],
          updatedAt: DateTime(2026, 1, 1),
        ),
        PersonProfile(
          displayName: '最新画像',
          tonePreferences: const ['最新语气'],
          lastUpdateReason: '最近从聊天记录更新',
          updatedAt: DateTime(2026, 1, 4),
        ),
        PersonProfile(
          displayName: '次新画像',
          tonePreferences: const ['次新语气'],
          updatedAt: DateTime(2026, 1, 3),
        ),
        PersonProfile(
          displayName: '第三画像',
          tonePreferences: const ['第三语气'],
          updatedAt: DateTime(2026, 1, 2),
        ),
        PersonProfile(
          displayName: '第四画像',
          tonePreferences: const ['第四语气'],
          updatedAt: DateTime(2026, 1, 1, 18),
        ),
        PersonProfile(
          displayName: '第五画像',
          tonePreferences: const ['第五语气'],
          updatedAt: DateTime(2026, 1, 1, 12),
        ),
        PersonProfile(
          displayName: '最旧画像',
          tonePreferences: const ['最旧语气'],
          updatedAt: DateTime(2025, 12, 31),
        ),
      ];

    final context = app.makePersonProfileContext();

    expect(context, contains('用户未指定聊天对象'));
    expect(context, contains('谨慎匹配'));
    expect('候选画像'.allMatches(context), hasLength(3));
    expect(context.indexOf('最新画像'), lessThan(context.indexOf('次新画像')));
    expect(context.indexOf('次新画像'), lessThan(context.indexOf('第三画像')));
    expect(context, contains('最近画像依据：最近从聊天记录更新'));
    expect(context, isNot(contains('第四画像')));
    expect(context, isNot(contains('第五画像')));
    expect(context, isNot(contains('第六画像')));
    expect(context, isNot(contains('最旧画像')));
  });

  test('unselected person profile context limit matches iOS audit docs', () {
    final promptContextSource =
        File('lib/core/prompt_context_builder.dart').readAsStringSync();
    final readme = File('README.md').readAsStringSync();
    final audit = File('docs/MIGRATION_AUDIT.md').readAsStringSync();

    final methodStart =
        promptContextSource.indexOf('String _buildPersonProfileContext');
    final methodEnd = promptContextSource.indexOf(
      'String _personalizationPromptFingerprint',
      methodStart,
    );

    expect(methodStart, isNonNegative);
    expect(methodEnd, greaterThan(methodStart));
    final methodBody = promptContextSource.substring(methodStart, methodEnd);

    expect(
        promptContextSource, contains('this.profilePromptCandidateLimit = 3'));
    expect(methodBody, contains('.take(profilePromptCandidateLimit)'));
    expect(methodBody, isNot(contains('.take(6)')));
    expect(readme, contains('three most recent profiles'));
    expect(readme, contains('iOS `PersonProfile.promptContext` behavior'));
    expect(audit, contains('original iOS `PersonProfile.promptContext`'));
    expect(audit, contains('the three most recently updated profiles'));
    expect(audit, isNot(contains('the six most recently updated profiles')));
  });

  test('finishing quick reply clears image input and temporary screenshot',
      () async {
    final dir = await Directory.systemTemp.createTemp('ai-reply-quick-');
    final file = File('${dir.path}/floating-capture-test.jpg');
    final picked = File('${dir.path}/picked-image.jpg');
    await file.writeAsBytes([1, 2, 3]);
    await picked.writeAsBytes([4, 5, 6]);
    final app = AppController(temporaryDirectoryProvider: () async => dir)
      ..quickImagePath = file.path
      ..currentImagePath = file.path
      ..isQuickReplySession = true
      ..lastInput = ChatInput(
        type: ChatInputType.image,
        imagePayload: const ImagePayload(
          base64: 'abc',
          mimeType: 'image/jpeg',
          width: 1,
          height: 1,
          sizeInBytes: 3,
        ),
        selectedStyle: ChatStyle.defaultStyle,
      );

    await app.finishQuickReplySession();

    expect(app.quickImagePath, isNull);
    expect(app.currentImagePath, isNull);
    expect(app.lastInput, isNull);
    expect(file.existsSync(), isFalse);

    app
      ..quickImagePath = picked.path
      ..currentImagePath = picked.path;
    await app.finishQuickReplySession();

    expect(app.quickImagePath, isNull);
    expect(app.currentImagePath, isNull);
    expect(await picked.exists(), isTrue);

    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
  });

  test('finishing quick reply clears legacy spaced current image path',
      () async {
    final dir = await Directory.systemTemp.createTemp('ai-reply-quick-spaced-');
    final file = File('${dir.path}/floating-capture-spaced.jpg');
    await file.writeAsBytes([1, 2, 3]);
    final app = AppController(temporaryDirectoryProvider: () async => dir)
      ..quickImagePath = file.path
      ..currentImagePath = '  ${file.path}  '
      ..isQuickReplySession = true;

    try {
      await app.finishQuickReplySession();

      expect(app.quickImagePath, isNull);
      expect(app.currentImagePath, isNull);
      expect(file.existsSync(), isFalse);
    } finally {
      if (await dir.exists()) {
        await dir.delete(recursive: true);
      }
    }
  });

  test('finishing quick reply preserves unrelated shared handoffs', () async {
    final app = AppController()
      ..quickImagePath = '/tmp/quick.jpg'
      ..sharedImagePath = '/tmp/shared.jpg'
      ..sharedText = '待处理分享'
      ..isQuickReplySession = true
      ..shouldReadQuickClipboardOnOpen = true
      ..shouldAutoGenerateQuickReply = true
      ..shouldResetQuickReplyDraft = true;

    await app.finishQuickReplySession();

    expect(app.quickImagePath, isNull);
    expect(app.sharedImagePath, '/tmp/shared.jpg');
    expect(app.sharedText, '待处理分享');
    expect(app.isQuickReplySession, isFalse);
    expect(app.shouldReadQuickClipboardOnOpen, isFalse);
    expect(app.shouldAutoGenerateQuickReply, isFalse);
    expect(app.shouldResetQuickReplyDraft, isFalse);
  });

  test('quick reply clear paths share session state helper', () {
    final externalSource =
        File('lib/core/app_state_external_handoffs.dart').readAsStringSync();
    final clipboardSource =
        File('lib/core/app_state_clipboard_actions.dart').readAsStringSync();
    final localDataSource =
        File('lib/core/app_state_local_data.dart').readAsStringSync();

    expect(externalSource, contains('void _clearQuickReplySessionState()'));
    expect(clipboardSource, contains('_clearQuickReplySessionState();'));
    expect(localDataSource, contains('_clearQuickReplySessionState();'));
    expect(clipboardSource,
        isNot(contains('shouldAutoGenerateQuickReply = false')));
    expect(
        localDataSource, isNot(contains('shouldResetQuickReplyDraft = false')));
  });

  test('image path cleanup paths share matching helper', () {
    final runtimeSource =
        File('lib/core/app_state_runtime_helpers.dart').readAsStringSync();
    final clipboardSource =
        File('lib/core/app_state_clipboard_actions.dart').readAsStringSync();
    final quickSource = File('lib/core/app_state_external_quick_handoffs.dart')
        .readAsStringSync();
    final imageSource =
        File('lib/core/app_state_image_generation.dart').readAsStringSync();
    final imageCleanupStart = imageSource
        .indexOf('deleteOwnedTransientImageFile(submittedImagePath)');
    expect(imageCleanupStart, isNonNegative);
    final imageCleanupSource = imageSource.substring(imageCleanupStart);

    expect(runtimeSource, contains('bool _clearCurrentImagePathIfMatches('));
    expect(runtimeSource, contains('bool _clearQuickImagePathIfMatches('));
    expect(
        runtimeSource,
        contains('final targetPath = '
            '_normalizedGenerationImagePath(path);'));
    expect(runtimeSource,
        contains('_normalizedGenerationImagePath(currentImagePath)'));
    expect(runtimeSource,
        contains('_normalizedGenerationImagePath(quickImagePath)'));
    expect(clipboardSource, contains('_clearCurrentImagePathIfMatches(path)'));
    expect(
        quickSource, contains('_clearCurrentImagePathIfMatches(previousPath)'));
    expect(imageCleanupSource,
        contains('_clearCurrentImagePathIfMatches(submittedImagePath)'));
    expect(imageCleanupSource,
        contains('_clearQuickImagePathIfMatches(submittedImagePath)'));
    expect(clipboardSource, isNot(contains('currentImagePath == path')));
    expect(quickSource, isNot(contains('currentImagePath == previousPath')));
    expect(
        imageCleanupSource, isNot(contains('currentImagePath == imagePath')));
    expect(imageCleanupSource, isNot(contains('quickImagePath == imagePath')));
  });

  test('discarding transient image path only deletes app-owned captures',
      () async {
    final tempRoot =
        await Directory.systemTemp.createTemp('ai-reply-discard-temp-');
    final outsideRoot =
        await Directory.systemTemp.createTemp('ai-reply-discard-picked-');
    final owned = File('${tempRoot.path}/accessibility-capture-discard.jpg');
    final picked = File('${tempRoot.path}/picked-image.jpg');
    final pickedWithTransientName =
        File('${outsideRoot.path}/accessibility-capture-user-picked.jpg');
    await owned.writeAsBytes([1, 2, 3]);
    await picked.writeAsBytes([4, 5, 6]);
    await pickedWithTransientName.writeAsBytes([7, 8, 9]);
    final app = AppController(temporaryDirectoryProvider: () async => tempRoot);

    try {
      await app.discardTransientImagePath(owned.path);
      await app.discardTransientImagePath(picked.path);
      await app.discardTransientImagePath(pickedWithTransientName.path);

      expect(await owned.exists(), isFalse);
      expect(await picked.exists(), isTrue);
      expect(await pickedWithTransientName.exists(), isTrue);
    } finally {
      if (await tempRoot.exists()) await tempRoot.delete(recursive: true);
      if (await outsideRoot.exists()) await outsideRoot.delete(recursive: true);
    }
  });

  test('quick shortcut launch flags drive clipboard import and auto generation',
      () async {
    final dir = await Directory.systemTemp.createTemp('ai-reply-quick-url-');
    final oldQuick = File('${dir.path}/clipboard-image-old-quick.img');
    await oldQuick.writeAsBytes([1, 2, 3]);
    final app = AppController(temporaryDirectoryProvider: () async => dir);

    try {
      app.requestQuickClipboardImport();

      expect(app.shouldReadQuickClipboardOnOpen, isTrue);
      expect(app.shouldAutoGenerateQuickReply, isTrue);
      expect(app.shouldResetQuickReplyDraft, isTrue);
      expect(app.consumeQuickClipboardImportRequest(), isTrue);
      expect(app.shouldReadQuickClipboardOnOpen, isFalse);
      expect(app.consumeQuickDraftResetRequest(), isTrue);
      expect(app.shouldResetQuickReplyDraft, isFalse);

      app.setQuickImagePath(oldQuick.path, autoGenerate: true);
      app.currentImagePath = oldQuick.path;

      expect(app.quickImagePath, oldQuick.path);
      expect(app.shouldReadQuickClipboardOnOpen, isFalse);
      expect(app.shouldAutoGenerateQuickReply, isTrue);
      expect(app.shouldResetQuickReplyDraft, isFalse);
      expect(app.consumeQuickAutoGenerate('/tmp/other.jpg'), isFalse);
      expect(app.shouldAutoGenerateQuickReply, isTrue);
      expect(app.consumeQuickAutoGenerate(oldQuick.path), isTrue);
      expect(app.shouldAutoGenerateQuickReply, isFalse);

      app.requestQuickClipboardImport();
      expect(app.shouldResetQuickReplyDraft, isTrue);
      app.setQuickImagePath(oldQuick.path, autoGenerate: true);
      expect(app.shouldReadQuickClipboardOnOpen, isFalse);
      expect(app.shouldResetQuickReplyDraft, isFalse);

      app.setQuickImagePath(
        oldQuick.path,
        autoGenerate: true,
        resetDraft: true,
      );
      app.currentImagePath = oldQuick.path;

      expect(app.currentImagePath, oldQuick.path);
      expect(app.shouldResetQuickReplyDraft, isTrue);
      expect(app.consumeQuickDraftResetRequest(), isTrue);
      expect(app.shouldResetQuickReplyDraft, isFalse);

      app_shell.prepareQuickShortcutFallback(app);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(app.quickImagePath, isNull);
      expect(app.currentImagePath, isNull);
      expect(app.shouldReadQuickClipboardOnOpen, isTrue);
      expect(app.shouldAutoGenerateQuickReply, isTrue);
      expect(app.consumeQuickAutoGenerate(oldQuick.path), isFalse);
      expect(await oldQuick.exists(), isFalse);
      app.clearPendingQuickAutoGenerate();
      expect(app.shouldAutoGenerateQuickReply, isFalse);
    } finally {
      app.dispose();
      if (await dir.exists()) await dir.delete(recursive: true);
    }
  });

  test('blank quick image path does not leave auto generate pending', () {
    final app = AppController()
      ..shouldAutoGenerateQuickReply = true
      ..quickImagePath = '/tmp/old-quick.jpg';

    app.setQuickImagePath('   ', autoGenerate: true, resetDraft: true);

    expect(app.quickImagePath, isNull);
    expect(app.shouldAutoGenerateQuickReply, isFalse);
    expect(app.shouldResetQuickReplyDraft, isTrue);
    expect(app.consumeQuickAutoGenerate('/tmp/old-quick.jpg'), isFalse);
    expect(app.shouldAutoGenerateQuickReply, isFalse);

    final source = File('lib/core/app_state_external_quick_handoffs.dart')
        .readAsStringSync();
    expect(
      source,
      contains('autoGenerateQuickReply: autoGenerate && nextPath != null'),
    );
  });

  test('dirty pending quick image path clears stale auto generation', () {
    final app = AppController()
      ..shouldAutoGenerateQuickReply = true
      ..quickImagePath = '   ';

    expect(app.consumeQuickAutoGenerate('   '), isFalse);
    expect(app.quickImagePath, isNull);
    expect(app.shouldAutoGenerateQuickReply, isFalse);

    app
      ..shouldAutoGenerateQuickReply = true
      ..quickImagePath = null;

    expect(app.consumeQuickAutoGenerate('/tmp/pending.jpg'), isFalse);
    expect(app.shouldAutoGenerateQuickReply, isTrue);
  });

  test('quick image handoffs clear stale feedback at controller boundary',
      () async {
    final dir =
        await Directory.systemTemp.createTemp('ai-reply-quick-feedback-');
    final first = File('${dir.path}/floating-capture-first.jpg');
    final second = File('${dir.path}/clipboard-image-second.img');
    await first.writeAsBytes([1, 2, 3]);
    await second.writeAsBytes([4, 5, 6]);
    final app = AppController(temporaryDirectoryProvider: () async => dir)
      ..statusMessage = '旧成功'
      ..errorMessage = '旧错误';

    try {
      app.setQuickImagePath(first.path, autoGenerate: true, resetDraft: true);

      expect(app.quickImagePath, first.path);
      expect(app.statusMessage, isNull);
      expect(app.errorMessage, isNull);

      app
        ..statusMessage = '旧成功'
        ..errorMessage = '旧错误'
        ..setQuickImagePath(second.path, autoGenerate: true);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(app.quickImagePath, second.path);
      expect(app.statusMessage, isNull);
      expect(app.errorMessage, isNull);
      expect(await first.exists(), isFalse);

      app
        ..statusMessage = '旧成功'
        ..errorMessage = '旧错误';
      app.requestQuickClipboardImport();
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(app.quickImagePath, isNull);
      expect(app.shouldReadQuickClipboardOnOpen, isTrue);
      expect(app.statusMessage, isNull);
      expect(app.errorMessage, isNull);
      expect(await second.exists(), isFalse);
    } finally {
      app.dispose();
      if (await dir.exists()) await dir.delete(recursive: true);
    }
  });

  test('quick reply screen wires clipboard read feedback into shared shell',
      () {
    final source =
        File('lib/screens/image_generation_screens.dart').readAsStringSync();
    final screenStart = source.indexOf('class _QuickReplyScreenState');
    final classEnd = source.length;

    expect(screenStart, isNot(-1));
    expect(classEnd, isNot(-1));
    expect(
      source.indexOf('bool didReadClipboard = false;', screenStart),
      inExclusiveRange(screenStart, classEnd),
    );
    expect(
      source.indexOf('didReadClipboard: didReadClipboard,', screenStart),
      inExclusiveRange(screenStart, classEnd),
    );
    expect(
      source.indexOf('setState(() => didReadClipboard = true)', screenStart),
      inExclusiveRange(screenStart, classEnd),
    );
    expect(
      source.indexOf('scheduleTransientFeedbackReset(', screenStart),
      inExclusiveRange(screenStart, classEnd),
    );
  });

  test('quick reply screen restores current quick draft controls on open', () {
    final source =
        File('lib/screens/image_generation_screens.dart').readAsStringSync();
    final screenStart = source.indexOf('class _QuickReplyScreenState');
    final initStart = source.indexOf('void initState()', screenStart);
    final disposeStart = source.indexOf('void dispose()', initStart);

    expect(screenStart, isNot(-1));
    expect(initStart, inExclusiveRange(screenStart, disposeStart));
    final initSource = source.substring(initStart, disposeStart);

    expect(initSource, contains('final app = ref.read(appProvider);'));
    expect(initSource, contains('app.clearFeedback(notify: false);'));
    expect(initSource, contains('app.isQuickReplySession &&'));
    expect(initSource, contains('app.currentInputType == ChatInputType.image'));
    expect(initSource, contains('goal.text = restoredGoal;'));
    expect(initSource, contains('style = app.currentStyle;'));
    expect(initSource,
        contains('selectedProfileId = restorableScreenProfileId(app);'));
  });

  test(
      'quick reply external handoff resets mounted quick draft before auto run',
      () {
    final source =
        File('lib/screens/image_generation_screens.dart').readAsStringSync();
    final screenStart = source.indexOf('class _QuickReplyScreenState');
    final scheduleStart =
        source.indexOf('void _schedulePendingQuickWork', screenStart);
    final consumeStart =
        source.indexOf('consumeQuickDraftResetRequest()', scheduleStart);
    final autoStart =
        source.indexOf('app.shouldAutoGenerateQuickReply', scheduleStart);
    final classEnd = source.length;

    expect(screenStart, isNot(-1));
    expect(scheduleStart, inExclusiveRange(screenStart, classEnd));
    expect(consumeStart, inExclusiveRange(scheduleStart, classEnd));
    expect(autoStart, inExclusiveRange(scheduleStart, classEnd));
    expect(consumeStart, lessThan(autoStart));

    final methodSource = source.substring(scheduleStart, classEnd);
    expect(methodSource, contains('goal.clear();'));
    expect(methodSource, contains('style = controller.currentStyle;'));
    expect(methodSource,
        contains('selectedProfileId = restorableScreenProfileId(controller);'));
  });

  test('quick auto generate reports blocked readiness and busy states', () {
    const missingKeyReadiness = GenerateAPIReadiness(
      config: APIConfig.defaults,
      hasAPIKey: false,
      capability: GenerateAPICapability.vision,
      isQuickReply: true,
    );
    const ready = GenerateAPIReadiness(
      config: APIConfig.defaults,
      hasAPIKey: true,
      capability: GenerateAPICapability.vision,
      isQuickReply: true,
    );

    expect(
      app_shell.quickAutoGenerateBlockMessage(
        readiness: missingKeyReadiness,
        isBusy: false,
      ),
      contains('快捷回复不会发送请求'),
    );
    expect(
      app_shell.quickAutoGenerateBlockMessage(readiness: ready, isBusy: true),
      '正在生成中，请稍后再试。',
    );
    expect(
      app_shell.quickAutoGenerateBlockMessage(readiness: ready, isBusy: false),
      isNull,
    );
  });

  test('blocked quick auto generate clears transient session', () async {
    final dir = await Directory.systemTemp.createTemp('ai-reply-quick-block-');
    final file = File('${dir.path}/clipboard-image-blocked.img');
    await file.writeAsBytes([1, 2, 3]);
    final app = AppController(temporaryDirectoryProvider: () async => dir)
      ..setQuickImagePath(file.path, autoGenerate: true);
    final errors = <String>[];
    final overlays = <String>[];

    try {
      await app_shell.finishBlockedQuickReplyAutoGenerate(
        app: app,
        message: '填写 Key 后才能调用视觉模型；配置完成前快捷回复不会发送请求。',
        showErrorOverlay: (message) async => overlays.add(message),
        onError: errors.add,
      );

      expect(errors, isEmpty);
      expect(overlays.single, contains('快捷回复不会发送请求'));
      expect(app.errorMessage, contains('快捷回复不会发送请求'));
      expect(app.quickImagePath, isNull);
      expect(app.shouldAutoGenerateQuickReply, isFalse);
      expect(await file.exists(), isFalse);
    } finally {
      app.dispose();
      if (await dir.exists()) await dir.delete(recursive: true);
    }
  });

  test('quick auto generate native prep failures clear transient session',
      () async {
    final dir =
        await Directory.systemTemp.createTemp('ai-reply-quick-bridge-fail-');
    final file = File('${dir.path}/clipboard-image-bridge-fail.img');
    await file.writeAsBytes([1, 2, 3]);
    final app = AppController(temporaryDirectoryProvider: () async => dir)
      ..setQuickImagePath(file.path, autoGenerate: true);
    final errors = <String>[];
    final overlays = <String>[];
    var collapsed = false;

    try {
      final prepared = await app_shell.prepareQuickReplyAutoGenerateBridge(
        app: app,
        showAnalyzingOverlay: () async {
          throw PlatformException(
            code: 'floating_reply_failed',
            message: '无法显示快捷回复面板。',
          );
        },
        collapseQuickPanel: () async => collapsed = true,
        showErrorOverlay: (message) async => overlays.add(message),
        onError: errors.add,
      );

      expect(prepared, isFalse);
      expect(collapsed, isFalse);
      expect(errors.single, contains('无法显示快捷回复面板'));
      expect(overlays.single, contains('无法显示快捷回复面板'));
      expect(app.quickImagePath, isNull);
      expect(app.shouldAutoGenerateQuickReply, isFalse);
      expect(await file.exists(), isFalse);
    } finally {
      app.dispose();
      if (await dir.exists()) await dir.delete(recursive: true);
    }
  });

  test('quick reply empty goal falls back to iOS shortcut intent', () {
    expect(
      app_shell.effectiveQuickReplyGoal('  \n  '),
      '根据当前界面的聊天内容，生成多条可直接发送的自然回复。',
    );
    expect(app_shell.effectiveQuickReplyGoal('  想轻松一点  '), '想轻松一点');
    expect(
      app_shell.effectiveQuickReplyGoal('  未知  '),
      '根据当前界面的聊天内容，生成多条可直接发送的自然回复。',
    );
    expect(
      app_shell.effectiveImageReplyGoal(isQuickReply: true, goal: '  '),
      '根据当前界面的聊天内容，生成多条可直接发送的自然回复。',
    );
    expect(
      app_shell.effectiveImageReplyGoal(isQuickReply: false, goal: '  '),
      '',
    );
    expect(
      app_shell.effectiveImageReplyGoal(isQuickReply: false, goal: '  未知  '),
      '',
    );
    expect(
      app_shell.effectiveImageReplyGoal(isQuickReply: false, goal: '  想自然一点  '),
      '想自然一点',
    );
  });

  test('quick reply overlay separates copyable replies from messages', () {
    final app = AppController()
      ..currentResponse = ChatReplyResponse(
        replies: [
          ReplySuggestion(styleLabel: '自然', text: '  第一条  ', reason: '测试'),
          ReplySuggestion(styleLabel: '自然', text: '', reason: '空'),
          ReplySuggestion(styleLabel: '自然', text: '未知', reason: '占位'),
          ReplySuggestion(styleLabel: '自然', text: '第一条', reason: '重复'),
          ReplySuggestion(styleLabel: '自然', text: '第二条', reason: '测试'),
          ReplySuggestion(styleLabel: '自然', text: '第三条', reason: '测试'),
          ReplySuggestion(styleLabel: '自然', text: '第四条', reason: '测试'),
          ReplySuggestion(styleLabel: '自然', text: '第五条', reason: '测试'),
          ReplySuggestion(styleLabel: '自然', text: '第六条', reason: '测试'),
        ],
      );

    expect(app_shell.quickReplyCopyableOverlayReplies(app),
        ['第一条', '第二条', '第三条', '第四条', '第五条']);
    expect(app_shell.quickReplyOverlayMessage(app), '没有生成可复制的回复，请稍后重试。');
    expect(app_shell.quickReplyOverlayTitle(app), '没有可复制回复');

    app
      ..currentResponse = null
      ..errorMessage = '  生成失败，请检查 API 配置  ';

    expect(app_shell.quickReplyCopyableOverlayReplies(app), isEmpty);
    expect(app_shell.quickReplyOverlayMessage(app), '生成失败，请检查 API 配置');
    expect(app_shell.quickReplyOverlayTitle(app), '生成失败');

    app.errorMessage = '   ';

    expect(app_shell.quickReplyOverlayMessage(app), '没有生成可复制的回复，请稍后重试。');
    expect(app_shell.quickReplyOverlayTitle(app), '没有可复制回复');

    app.errorMessage = null;

    expect(app_shell.quickReplyCopyableOverlayReplies(app), isEmpty);
    expect(app_shell.quickReplyOverlayMessage(app), '没有生成可复制的回复，请稍后重试。');
    expect(app_shell.quickReplyOverlayTitle(app), '没有可复制回复');

    final source = File('lib/main.dart').readAsStringSync();
    expect(source, isNot(contains('List<String> quickReplyOverlayReplies')));
  });

  test('quick reply maps detected platforms to Android return packages', () {
    expect(
        app_shell.quickReplyReturnPackageForPlatform('微信'), 'com.tencent.mm');
    expect(app_shell.quickReplyReturnPackageForPlatform('WeChat'),
        'com.tencent.mm');
    expect(app_shell.quickReplyReturnPackageForPlatform(' WeChat '),
        'com.tencent.mm');
    expect(app_shell.quickReplyReturnPackageForPlatform('We Chat'),
        'com.tencent.mm');
    expect(app_shell.quickReplyReturnPackageForPlatform('com.tencent.mm'),
        'com.tencent.mm');
    expect(
      app_shell.quickReplyReturnPackageForPlatform(
        'package:com.tencent.mm/.ui.LauncherUI',
      ),
      'com.tencent.mm',
    );
    expect(app_shell.quickReplyReturnPackageForPlatform('QQ 私聊'),
        'com.tencent.mobileqq');
    expect(
        app_shell.quickReplyReturnPackageForPlatform('小红书'), 'com.xingin.xhs');
    expect(app_shell.quickReplyReturnPackageForPlatform('RedNote'),
        'com.xingin.xhs');
    expect(app_shell.quickReplyReturnPackageForPlatform('Little Red Book'),
        'com.xingin.xhs');
    expect(app_shell.quickReplyReturnPackageForPlatform('xhs note'),
        'com.xingin.xhs');
    expect(app_shell.quickReplyReturnPackageForPlatform('Reddit'), isNull);
    expect(
        app_shell.quickReplyReturnPackageForPlatform('微博'), 'com.sina.weibo');
    expect(app_shell.quickReplyReturnPackageForPlatform('douyin'),
        'com.ss.android.ugc.aweme');
    expect(app_shell.quickReplyReturnPackageForPlatform('WhatsApp'),
        'com.whatsapp');
    expect(app_shell.quickReplyReturnPackageForPlatform('com.whatsapp'),
        'com.whatsapp');
    expect(app_shell.quickReplyReturnPackageForPlatform('Telegram 群聊'),
        'org.telegram.messenger');
    expect(
      app_shell.quickReplyReturnPackageForPlatform('org.telegram.messenger'),
      'org.telegram.messenger',
    );
    expect(app_shell.quickReplyReturnPackageForPlatform('LINE'),
        'jp.naver.line.android');
    expect(
      app_shell.quickReplyReturnPackageForPlatform('jp.naver.line.android'),
      'jp.naver.line.android',
    );
    expect(app_shell.quickReplyReturnPackageForPlatform('钉钉'),
        'com.alibaba.android.rimet');
    expect(app_shell.quickReplyReturnPackageForPlatform('Ding-Talk'),
        'com.alibaba.android.rimet');
    expect(
      app_shell.quickReplyReturnPackageForPlatform('com.alibaba.android.rimet'),
      'com.alibaba.android.rimet',
    );
    expect(app_shell.quickReplyReturnPackageForPlatform('飞书'),
        'com.ss.android.lark');
    expect(app_shell.quickReplyReturnPackageForPlatform('com.ss.android.lark'),
        'com.ss.android.lark');
    expect(app_shell.quickReplyReturnPackageForPlatform('短信'), isNull);
    expect(app_shell.quickReplyReturnPackageForPlatform('  '), isNull);

    final flowSource =
        File('lib/core/quick_reply_flow.dart').readAsStringSync();
    final packageSource =
        File('lib/core/quick_reply_return_packages.dart').readAsStringSync();
    expect(flowSource, contains("import 'text_cleaning.dart';"));
    expect(
      packageSource,
      contains(
          'final normalized = cleanNonEmptyText(platform)?.toLowerCase();'),
    );
    expect(packageSource, isNot(contains('platform?.trim()')));
  });

  test('quick auto generate passes detected return package to overlay',
      () async {
    final app = AppController()
      ..currentResponse = ChatReplyResponse(
        platform: '微信',
        replies: [
          ReplySuggestion(styleLabel: '自然', text: '第一条', reason: '测试'),
        ],
      );
    final overlays = <({List<String> replies, String? returnPackage})>[];

    await app_shell.completeQuickReplyAutoGenerateAttempt(
      app: app,
      generate: () async {},
      showOverlay: (replies, returnPackage) async {
        overlays.add((replies: replies, returnPackage: returnPackage));
      },
      showErrorOverlay: (message) async => fail(message),
    );

    expect(overlays.single.replies, ['第一条']);
    expect(overlays.single.returnPackage, 'com.tencent.mm');
  });

  test('quick auto generate reports overlay failures without rethrowing',
      () async {
    final app = AppController();
    final errors = <String>[];

    await app_shell.completeQuickReplyAutoGenerateAttempt(
      app: app,
      generate: () async => throw StateError('模型失败'),
      showOverlay: (replies, returnPackage) async {
        fail('errors must not be shown as copyable replies');
      },
      showErrorOverlay: (message) async {
        throw PlatformException(
          code: 'floating_reply_failed',
          message: '无法显示快捷回复面板。',
        );
      },
      onError: errors.add,
    );

    expect(errors, hasLength(2));
    expect(errors.first, contains('模型失败'));
    expect(errors.last, contains('无法显示快捷回复面板'));
  });

  test('quick auto generate shows failures as non copyable overlay messages',
      () async {
    final app = AppController();
    final errors = <String>[];
    final copyableOverlays =
        <({List<String> replies, String? returnPackage})>[];
    final messageOverlays = <String>[];

    await app_shell.completeQuickReplyAutoGenerateAttempt(
      app: app,
      generate: () async => throw StateError('模型失败'),
      showOverlay: (replies, returnPackage) async {
        copyableOverlays.add((replies: replies, returnPackage: returnPackage));
      },
      showErrorOverlay: (message) async => messageOverlays.add(message),
      onError: errors.add,
    );

    expect(errors.single, contains('模型失败'));
    expect(copyableOverlays, isEmpty);
    expect(messageOverlays.single, contains('模型失败'));

    final source = File('lib/core/quick_reply_flow.dart').readAsStringSync();
    final helperStart =
        source.indexOf('Future<void> completeQuickReplyAutoGenerateAttempt');
    final helperEnd =
        source.indexOf('Future<void> showQuickReplyMessageOverlaySafely');
    expect(helperStart, isNonNegative);
    expect(helperEnd, greaterThan(helperStart));
    final helperBody = source.substring(helperStart, helperEnd);
    expect(
        helperBody, contains('required Future<void> Function(String message)'));
    expect(helperBody, contains('quickReplyCopyableOverlayReplies(app)'));
    expect(helperBody,
        contains('showErrorOverlay(quickReplyOverlayMessage(app))'));
    expect(helperBody, isNot(contains('showOverlaySafely([message], null)')));
  });

  test('quick auto generate attempt clears transient session after errors',
      () async {
    final dir = await Directory.systemTemp.createTemp('ai-reply-quick-fail-');
    final file = File('${dir.path}/clipboard-image-fail.jpg');
    await file.writeAsBytes([1, 2, 3]);
    final app = AppController(temporaryDirectoryProvider: () async => dir)
      ..setQuickImagePath(file.path, autoGenerate: true);
    final overlays = <({List<String> replies, String? returnPackage})>[];
    final messageOverlays = <String>[];

    try {
      await app_shell.completeQuickReplyAutoGenerateAttempt(
        app: app,
        generate: () async => app.setError('模型失败，请稍后重试。'),
        showOverlay: (replies, returnPackage) async {
          overlays.add((replies: replies, returnPackage: returnPackage));
        },
        showErrorOverlay: (message) async => messageOverlays.add(message),
        onError: app.setError,
      );

      expect(overlays, isEmpty);
      expect(messageOverlays.single, '模型失败，请稍后重试。');
      expect(app.quickImagePath, isNull);
      expect(app.shouldAutoGenerateQuickReply, isFalse);
      expect(await file.exists(), isFalse);
    } finally {
      if (await dir.exists()) await dir.delete(recursive: true);
    }
  });

  test('floating capture background replies use safe overlay display', () {
    final source = File('lib/app_shell.dart').readAsStringSync();
    final handlerStart = source.indexOf('Future<void> _handleFloatingCapture');
    final handlerEnd =
        source.indexOf('@override\n  void dispose()', handlerStart);

    expect(handlerStart, isNonNegative);
    expect(handlerEnd, greaterThan(handlerStart));

    final handlerBody = source.substring(handlerStart, handlerEnd);
    expect(handlerBody, contains('showQuickReplyOverlaySafely'));
    expect(handlerBody,
        isNot(contains('FloatingCaptureBridge.showReplyOverlay(')));
    expect(handlerBody, contains('app.setError(message);'));
    expect(handlerBody, contains('!hasUsableAPIKey(app.apiKey)'));
    expect(handlerBody, contains('hasAPIKey: hasUsableAPIKey(app.apiKey)'));
    expect(handlerBody, contains('title: quickReplyOverlayTitle(app)'));
    expect(handlerBody, isNot(contains('app.apiKey.trim()')));
    expect(handlerBody, isNot(contains('app.errorMessage?.trim()')));
    expect(handlerBody,
        contains('if (_floatingGenerationPath != null || app.isBusy)'));
    expect(handlerBody, contains('if (_floatingGenerationPath != imagePath)'));
    expect(handlerBody, contains('discardTransientImagePath(imagePath)'));
    expect(handlerBody, contains('正在生成中，请稍后再试。'));
    expect(handlerBody, contains('quickReplyReturnPackageForPlatform'));
    expect(handlerBody, contains('returnPackage:'));
  });

  test('external handoffs defer until privacy state finishes loading',
      () async {
    final seenStore = FakeStore();
    final seenApp = AppController(store: seenStore);

    expect(seenApp.shouldDeferExternalHandoffs, isTrue);

    await seenApp.load();

    expect(seenApp.showingPrivacyNotice, isFalse);
    expect(seenApp.shouldDeferExternalHandoffs, isFalse);

    final unseenStore = FakeStore()..hasSeenPrivacy = false;
    final unseenApp = AppController(store: unseenStore);

    expect(unseenApp.shouldDeferExternalHandoffs, isTrue);

    await unseenApp.load();

    expect(unseenApp.showingPrivacyNotice, isTrue);
    expect(unseenApp.shouldDeferExternalHandoffs, isTrue);
  });

  test('external handoffs wait while privacy notice is visible', () async {
    final app = AppController(store: FakeStore()..hasSeenPrivacy = false);
    await app.load();

    app.requestQuickClipboardImport();
    app.setSharedText('  对方：晚上见  ');
    app.setSharedImagePath('/tmp/shared.jpg');

    expect(app.shouldDeferExternalHandoffs, isTrue);
    expect(app.shouldReadQuickClipboardOnOpen, isFalse);
    expect(app.shouldAutoGenerateQuickReply, isFalse);
    expect(app.sharedText, isNull);
    expect(app.sharedImagePath, '/tmp/shared.jpg');

    app.showingPrivacyNotice = false;

    expect(app.shouldDeferExternalHandoffs, isFalse);
    expect(app.consumeQuickClipboardImportRequest(), isFalse);
    expect(app.consumeSharedText(), isNull);
    expect(app.consumeSharedImagePath(), '/tmp/shared.jpg');
  });

  test('new external handoff type clears older pending handoffs', () async {
    final dir = await Directory.systemTemp.createTemp('ai-reply-handoff-type-');
    final quick = File('${dir.path}/floating-capture-pending.jpg');
    final shared = File('${dir.path}/clipboard-image-pending.img');
    await quick.writeAsBytes([1, 2, 3]);
    await shared.writeAsBytes([4, 5, 6]);
    final app = AppController(temporaryDirectoryProvider: () async => dir);

    try {
      app.setQuickImagePath(quick.path, autoGenerate: true);
      app.setSharedText('  对方：今晚见  ');
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(app.quickImagePath, isNull);
      expect(app.shouldAutoGenerateQuickReply, isFalse);
      expect(app.shouldReadQuickClipboardOnOpen, isFalse);
      expect(app.sharedText, '对方：今晚见');
      expect(await quick.exists(), isFalse);

      app.setSharedImagePath(shared.path);

      expect(app.sharedText, isNull);
      expect(app.sharedImagePath, shared.path);
      expect(app.quickImagePath, isNull);

      app.requestQuickClipboardImport();
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(app.sharedImagePath, isNull);
      expect(app.sharedText, isNull);
      expect(app.shouldReadQuickClipboardOnOpen, isTrue);
      expect(app.shouldAutoGenerateQuickReply, isTrue);
      expect(await shared.exists(), isFalse);
    } finally {
      app.dispose();
      if (await dir.exists()) await dir.delete(recursive: true);
    }
  });

  test('stale privacy acknowledgement cannot survive clear all', () async {
    final store = DeferredPrivacyStore()..hasSeenPrivacy = false;
    final app = AppController(store: store)
      ..showingPrivacyNotice = true
      ..apiKey = 'sk-old';

    final pendingMark = app.markPrivacySeen();
    await store.markStarted.future;

    await app.clearAllLocalData();

    expect(app.showingPrivacyNotice, isTrue);
    expect(store.hasSeenPrivacy, isFalse);

    store.markRelease.complete();
    await pendingMark;

    expect(app.showingPrivacyNotice, isTrue);
    expect(store.hasSeenPrivacy, isFalse);
    expect(app.apiKey, isEmpty);
    expect(app.statusMessage, '本地数据已清空，API 配置已恢复默认。');
  });

  test('privacy acknowledgement uses lifecycle helpers', () {
    final source =
        File('lib/core/app_state_local_data.dart').readAsStringSync();
    final runtimeSource =
        File('lib/core/app_state_runtime_helpers.dart').readAsStringSync();
    final markStart = source.indexOf('Future<void> markPrivacySeen() async');
    final clearStart = source.indexOf('Future<void> clearAllLocalData() async');

    expect(markStart, isNonNegative);
    expect(clearStart, greaterThan(markStart));
    expect(
        runtimeSource, contains('int _beginPrivacyAcknowledgementOperation()'));
    expect(runtimeSource,
        contains('bool _isCurrentPrivacyAcknowledgementOperation('));
    expect(runtimeSource, contains('void _applyPrivacyAcknowledgement()'));

    final markBody = source.substring(markStart, clearStart);
    expect(markBody, contains('_beginPrivacyAcknowledgementOperation();'));
    expect(markBody, contains('_isCurrentPrivacyAcknowledgementOperation('));
    expect(markBody, contains('_applyPrivacyAcknowledgement();'));
    expect(markBody, isNot(contains('++_privacyRevision')));
    expect(markBody, isNot(contains('_loadRevision += 1')));
    expect(markBody, isNot(contains('requestRevision != _privacyRevision')));
    expect(markBody, isNot(contains('_hasLoadedInitialState = true')));
    expect(markBody, isNot(contains('showingPrivacyNotice = false')));
  });

  test('external handoff routing waits for privacy notice in app shell', () {
    final source = File('lib/app_shell.dart').readAsStringSync();
    final routeHelperStart = source.indexOf('void _routeExternalPath');
    final routeHelperEnd = source.indexOf('void _flushPendingExternalPath');

    expect(source, contains('String? _pendingExternalPath;'));
    expect(source, contains('onError: _handleFloatingEventError'));
    expect(source, contains('void _handleFloatingEvent('));
    expect(source, contains('void _handleFloatingEventError('));
    expect(source, contains('if (!mounted) return;'));
    expect(source, contains('setError(userMessageFor(error))'));
    expect(routeHelperStart, isNot(-1));
    expect(routeHelperEnd, greaterThan(routeHelperStart));
    expect(source.substring(routeHelperStart, routeHelperEnd),
        contains('shouldDeferExternalHandoffs'));
    expect(source.substring(routeHelperStart, routeHelperEnd),
        contains('_pendingExternalPath = path'));
    expect(source.substring(routeHelperStart, routeHelperEnd),
        contains('WidgetsBinding.instance.addPostFrameCallback'));
    expect(source, contains('_flushPendingExternalPath();'));
    expect(source, contains('_routeExternalPath(AppRoutes.image)'));
    expect(source, contains('_routeExternalPath(AppRoutes.text)'));
    expect(source, contains('_routeExternalPath(AppRoutes.quick)'));
    expect(source, contains('} else if (event.text != null) {'));
    expect(source, contains('setSharedText(event.text!)'));
    expect(source, contains('isImageExternalRoute(event.route)'));
    expect(source, contains('prepareExternalImageInput()'));
    expect(source, contains('isTextExternalRoute(event.route)'));
    expect(source, contains('prepareExternalTextInput()'));
    expect(source, contains('_routeExternalPath(path)'));
    expect(source, isNot(contains('_router.go(AppRoutes.image)')));
    expect(source, isNot(contains('_router.go(AppRoutes.text)')));
    expect(source, isNot(contains('_router.go(AppRoutes.quick)')));
  });

  test('shared image handoff is consumed once', () {
    final app = AppController();

    app.setSharedImagePath('/tmp/shared.jpg');

    expect(app.sharedImagePath, '/tmp/shared.jpg');
    expect(app.consumeSharedImagePath(), '/tmp/shared.jpg');
    expect(app.consumeSharedImagePath(), isNull);
  });

  test('external image handoff paths normalize before runtime storage', () {
    final app = AppController();

    app.setSharedImagePath('  /tmp/shared.jpg  ');

    expect(app.sharedImagePath, '/tmp/shared.jpg');
    expect(app.consumeSharedImagePath(), '/tmp/shared.jpg');

    app.setQuickImagePath('  /tmp/quick.jpg  ', autoGenerate: true);

    expect(app.quickImagePath, '/tmp/quick.jpg');
    expect(app.consumeQuickAutoGenerate(' /tmp/quick.jpg '), isTrue);
  });

  test('shared image consume clears legacy dirty pending state', () {
    final app = AppController()..sharedImagePath = '   ';

    expect(app.consumeSharedImagePath(), isNull);
    expect(app.sharedImagePath, isNull);
  });

  test('external share handoffs clear stale feedback at controller boundary',
      () {
    final app = AppController()
      ..statusMessage = '旧成功'
      ..errorMessage = '旧错误';

    app.setSharedImagePath('/tmp/shared.jpg');

    expect(app.sharedImagePath, '/tmp/shared.jpg');
    expect(app.statusMessage, isNull);
    expect(app.errorMessage, isNull);

    app
      ..statusMessage = '旧成功'
      ..errorMessage = '旧错误';
    app.prepareExternalImageInput();

    expect(app.sharedImagePath, isNull);
    expect(app.statusMessage, isNull);
    expect(app.errorMessage, isNull);

    app
      ..statusMessage = '旧成功'
      ..errorMessage = '旧错误';
    app.setSharedText('  对方：晚上见  ');

    expect(app.sharedText, '对方：晚上见');
    expect(app.statusMessage, isNull);
    expect(app.errorMessage, isNull);

    app
      ..statusMessage = '旧成功'
      ..errorMessage = '旧错误';
    app.prepareExternalTextInput();

    expect(app.sharedText, isNull);
    expect(app.statusMessage, isNull);
    expect(app.errorMessage, isNull);
  });

  test('external handoff draft resets share editable draft helper', () {
    final source =
        File('lib/core/app_state_external_handoffs.dart').readAsStringSync();
    final imageStart = source.indexOf('void _resetImageDraftForExternalInput');
    final textStart = source.indexOf('void _resetTextDraftForExternalInput');
    final helperStart = source.indexOf('void _resetEditableDraftState');
    final pendingStart = source.indexOf('void _setPendingExternalHandoff');

    expect(imageStart, isNonNegative);
    expect(textStart, greaterThan(imageStart));
    expect(helperStart, greaterThan(textStart));
    expect(pendingStart, greaterThan(helperStart));
    final imageBlock = source.substring(imageStart, textStart);
    final textBlock = source.substring(textStart, helperStart);
    final helperBlock = source.substring(helperStart, pendingStart);

    expect(imageBlock, contains('_resetEditableDraftState();'));
    expect(textBlock, contains('_resetEditableDraftState();'));
    expect(imageBlock, isNot(contains('currentGoal = null')));
    expect(textBlock, isNot(contains('currentStyle = ChatStyle.defaultStyle')));
    expect(helperBlock, contains('_setPendingGenerationSource('));
    expect(helperBlock, contains('type: currentInputType'));
    expect(helperBlock, contains('style: defaultStyle'));
    expect(helperBlock, isNot(contains('currentTextInput = null')));
    expect(helperBlock, isNot(contains('currentImagePath = null')));
    expect(helperBlock, isNot(contains('lastInput = null')));
  });

  test('external handoff draft reset uses saved default style', () {
    final savedDefaultStyle = ChatStyle.presets[3];
    final staleStyle = ChatStyle.presets[1];
    final app = AppController()
      ..defaultStyle = savedDefaultStyle
      ..currentInputType = ChatInputType.text
      ..currentTextInput = '旧聊天'
      ..currentGoal = '旧目标'
      ..currentStyle = staleStyle
      ..lastInput = ChatInput(
        type: ChatInputType.text,
        text: '旧聊天',
        userGoal: '旧目标',
        selectedStyle: staleStyle,
      );

    app.setSharedText(' 对方：晚上见 ');

    expect(app.currentInputType, ChatInputType.text);
    expect(app.currentStyle, same(savedDefaultStyle));
    expect(app.lastInput, isNull);
    expect(app.sharedText, '对方：晚上见');

    app
      ..currentStyle = staleStyle
      ..lastInput = ChatInput(
        type: ChatInputType.image,
        userGoal: '旧截图目标',
        selectedStyle: staleStyle,
      );

    app.setSharedImagePath('/tmp/shared.jpg');

    expect(app.currentInputType, ChatInputType.image);
    expect(app.currentStyle, same(savedDefaultStyle));
    expect(app.lastInput, isNull);
    expect(app.sharedImagePath, '/tmp/shared.jpg');
  });

  test('shared image handoff starts from a fresh editable image draft',
      () async {
    final dir = await Directory.systemTemp.createTemp('ai-reply-image-draft-');
    final stale = File('${dir.path}/clipboard-image-stale.jpg');
    final incoming = File('${dir.path}/clipboard-image-incoming.jpg');
    await stale.writeAsBytes([1, 2, 3]);
    await incoming.writeAsBytes([4, 5, 6]);
    final staleStyle = ChatStyle.presets[1];
    final app = AppController(temporaryDirectoryProvider: () async => dir)
      ..currentInputType = ChatInputType.image
      ..currentImagePath = stale.path
      ..currentSelectedProfileId = 'target'
      ..currentGoal = '旧目标'
      ..currentStyle = staleStyle
      ..lastInput = ChatInput(
        type: ChatInputType.image,
        userGoal: '旧目标',
        selectedStyle: staleStyle,
      );

    try {
      app.setSharedImagePath(incoming.path);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(app.currentInputType, ChatInputType.image);
      expect(app.currentTextInput, isNull);
      expect(app.currentImagePath, isNull);
      expect(app.currentSelectedProfileId, isNull);
      expect(app.currentGoal, isNull);
      expect(app.currentStyle, ChatStyle.defaultStyle);
      expect(app.lastInput, isNull);
      expect(app.sharedImagePath, incoming.path);
      expect(await stale.exists(), isFalse);
      expect(await incoming.exists(), isTrue);
    } finally {
      app.dispose();
      if (await dir.exists()) await dir.delete(recursive: true);
    }
  });

  test('shared image handoff clears stale text result source state', () async {
    final dir = await Directory.systemTemp.createTemp('ai-reply-image-text-');
    final stale = File('${dir.path}/clipboard-image-stale-text.jpg');
    final incoming = File('${dir.path}/clipboard-image-incoming.jpg');
    await stale.writeAsBytes([9, 8, 7]);
    await incoming.writeAsBytes([1, 2, 3]);
    final staleStyle = ChatStyle.presets[1];
    final app = AppController(temporaryDirectoryProvider: () async => dir)
      ..currentInputType = ChatInputType.text
      ..currentTextInput = '旧文本草稿'
      ..currentImagePath = stale.path
      ..currentSelectedProfileId = 'target'
      ..currentGoal = '旧目标'
      ..currentStyle = staleStyle
      ..lastInput = ChatInput(
        type: ChatInputType.text,
        text: '旧聊天',
        userGoal: '旧目标',
        selectedStyle: staleStyle,
      );

    try {
      app.setSharedImagePath(incoming.path);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(app.currentInputType, ChatInputType.image);
      expect(app.currentTextInput, isNull);
      expect(app.currentGoal, isNull);
      expect(app.currentStyle, ChatStyle.defaultStyle);
      expect(app.lastInput, isNull);
      expect(app.sharedImagePath, incoming.path);
      expect(await stale.exists(), isFalse);
      expect(await incoming.exists(), isTrue);
    } finally {
      app.dispose();
      if (await dir.exists()) await dir.delete(recursive: true);
    }
  });

  test('shared image handoff keeps incoming file if it matches current draft',
      () async {
    final dir =
        await Directory.systemTemp.createTemp('ai-reply-same-image-draft-');
    final incoming = File('${dir.path}/clipboard-image-same.jpg');
    await incoming.writeAsBytes([1, 2, 3]);
    final app = AppController()
      ..currentInputType = ChatInputType.image
      ..currentImagePath = incoming.path
      ..currentGoal = '旧目标'
      ..lastInput = ChatInput(
        type: ChatInputType.image,
        selectedStyle: ChatStyle.defaultStyle,
      );

    try {
      app.setSharedImagePath('  ${incoming.path}  ');
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(app.currentImagePath, isNull);
      expect(app.currentGoal, isNull);
      expect(app.lastInput, isNull);
      expect(app.sharedImagePath, incoming.path);
      expect(await incoming.exists(), isTrue);
    } finally {
      app.dispose();
      if (await dir.exists()) await dir.delete(recursive: true);
    }
  });

  test('blank external image route clears stale draft and pending shared image',
      () async {
    final dir =
        await Directory.systemTemp.createTemp('ai-reply-blank-image-route-');
    final pending = File('${dir.path}/clipboard-image-pending.jpg');
    await pending.writeAsBytes([1, 2, 3]);
    final app = AppController(temporaryDirectoryProvider: () async => dir)
      ..currentInputType = ChatInputType.image
      ..currentImagePath = '/tmp/old.jpg'
      ..currentSelectedProfileId = 'target'
      ..currentGoal = '旧目标'
      ..currentStyle = ChatStyle.presets[2]
      ..sharedImagePath = pending.path
      ..lastInput = ChatInput(
        type: ChatInputType.image,
        userGoal: '旧目标',
        selectedStyle: ChatStyle.presets[2],
      );

    try {
      app.prepareExternalImageInput();
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(app.currentInputType, ChatInputType.image);
      expect(app.currentTextInput, isNull);
      expect(app.currentImagePath, isNull);
      expect(app.currentSelectedProfileId, isNull);
      expect(app.currentGoal, isNull);
      expect(app.currentStyle, ChatStyle.defaultStyle);
      expect(app.sharedImagePath, isNull);
      expect(app.lastInput, isNull);
      expect(await pending.exists(), isFalse);
    } finally {
      app.dispose();
      if (await dir.exists()) await dir.delete(recursive: true);
    }
  });

  test('replacing or superseding transient handoff images deletes stale files',
      () async {
    final dir = await Directory.systemTemp.createTemp('ai-reply-stale-images-');
    final oldShared = File('${dir.path}/clipboard-image-old.img');
    final newShared = File('${dir.path}/clipboard-image-new.img');
    final oldQuick = File('${dir.path}/floating-capture-old.jpg');
    final newQuick = File('${dir.path}/floating-capture-new.jpg');
    await oldShared.writeAsBytes([1]);
    await newShared.writeAsBytes([2]);
    await oldQuick.writeAsBytes([3]);
    await newQuick.writeAsBytes([4]);
    final app = AppController(temporaryDirectoryProvider: () async => dir);

    try {
      app.setSharedImagePath(oldShared.path);
      app.setSharedImagePath(newShared.path);
      app.setQuickImagePath(oldQuick.path, autoGenerate: true);
      app.setQuickImagePath(newQuick.path, autoGenerate: true);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(await oldShared.exists(), isFalse);
      expect(await oldQuick.exists(), isFalse);
      expect(await newShared.exists(), isFalse);
      expect(await newQuick.exists(), isTrue);
      expect(app.sharedImagePath, isNull);
      expect(app.quickImagePath, newQuick.path);
    } finally {
      app.dispose();
      if (await dir.exists()) await dir.delete(recursive: true);
    }
  });

  test('shared text handoff trims and is consumed once', () {
    final app = AppController();

    app.setSharedText('  对方：晚上见  ');

    expect(app.sharedText, '对方：晚上见');
    expect(app.consumeSharedText(), '对方：晚上见');
    expect(app.consumeSharedText(), isNull);

    final source = File('lib/core/app_state_external_text_handoffs.dart')
        .readAsStringSync();
    expect(source, contains('final cleanedText = cleanChatTextInput(text);'));
    expect(source, contains('if (cleanedText == null) {'));
    expect(source, contains('prepareExternalTextInput();'));
    expect(source, contains('_setPendingExternalHandoff(text: cleanedText);'));
    expect(source, contains('return cleanChatTextInput(text);'));
    expect(source, isNot(contains('text.trim()')));
  });

  test('blank shared text handoff clears stale pending text', () {
    final app = AppController()
      ..currentInputType = ChatInputType.text
      ..currentTextInput = '旧聊天'
      ..currentSelectedProfileId = 'target'
      ..currentGoal = '旧目标'
      ..currentStyle = ChatStyle.presets[2]
      ..sharedText = '待消费旧分享'
      ..lastInput = ChatInput(
        type: ChatInputType.text,
        text: '旧聊天',
        userGoal: '旧目标',
        selectedStyle: ChatStyle.presets[2],
      );

    app.setSharedText('   ');

    expect(app.currentInputType, ChatInputType.text);
    expect(app.currentTextInput, isNull);
    expect(app.currentSelectedProfileId, isNull);
    expect(app.currentGoal, isNull);
    expect(app.currentStyle, ChatStyle.defaultStyle);
    expect(app.sharedText, isNull);
    expect(app.consumeSharedText(), isNull);
    expect(app.lastInput, isNull);
  });

  test('shared text consume cleans legacy dirty pending state', () {
    final app = AppController()..sharedText = '  对方：晚上见  ';

    expect(app.consumeSharedText(), '对方：晚上见');
    expect(app.sharedText, isNull);

    app.sharedText = '   ';

    expect(app.consumeSharedText(), isNull);
    expect(app.sharedText, isNull);
  });

  test('shared text handoff starts from a fresh editable text draft', () {
    final staleStyle = ChatStyle.presets[1];
    final app = AppController()
      ..currentInputType = ChatInputType.text
      ..currentTextInput = '旧聊天'
      ..currentImagePath = '/tmp/old.jpg'
      ..currentSelectedProfileId = 'target'
      ..currentGoal = '旧目标'
      ..currentStyle = staleStyle
      ..lastInput = ChatInput(
        type: ChatInputType.text,
        text: '旧聊天',
        userGoal: '旧目标',
        selectedStyle: staleStyle,
      );

    app.setSharedText('  对方：晚上见  ');

    expect(app.currentInputType, ChatInputType.text);
    expect(app.currentTextInput, isNull);
    expect(app.currentImagePath, isNull);
    expect(app.currentSelectedProfileId, isNull);
    expect(app.currentGoal, isNull);
    expect(app.currentStyle, ChatStyle.defaultStyle);
    expect(app.lastInput, isNull);
    expect(app.sharedText, '对方：晚上见');
  });

  test('shared text handoff replaces mounted text field draft controls', () {
    final source =
        File('lib/screens/text_input_screen.dart').readAsStringSync();
    final methodStart = source.indexOf('void _schedulePendingSharedText');
    final methodEnd = source.length;

    expect(methodStart, isNonNegative);
    expect(methodEnd, greaterThan(methodStart));
    final methodSource = source.substring(methodStart, methodEnd);

    expect(methodSource, contains('final controller = ref.read(appProvider);'));
    expect(methodSource, contains('consumeSharedText()'));
    expect(methodSource, contains('cleanChatTextInput(incoming)'));
    expect(methodSource, contains('text.text = sharedText;'));
    expect(methodSource, contains('goal.clear();'));
    expect(methodSource, contains('style = controller.currentStyle;'));
    expect(
      methodSource,
      contains('selectedProfileId = restorableScreenProfileId(controller);'),
    );
    expect(methodSource,
        isNot(contains('appendClipboardText(text.text, incoming)')));
  });

  test('shared text handoff deletes stale owned image draft', () async {
    final dir =
        await Directory.systemTemp.createTemp('ai-reply-text-image-draft-');
    final stale = File('${dir.path}/clipboard-image-stale.jpg');
    await stale.writeAsBytes([1, 2, 3]);
    final app = AppController(temporaryDirectoryProvider: () async => dir)
      ..currentInputType = ChatInputType.image
      ..currentImagePath = stale.path
      ..currentGoal = '旧截图目标'
      ..lastInput = ChatInput(
        type: ChatInputType.image,
        selectedStyle: ChatStyle.defaultStyle,
      );

    try {
      app.setSharedText('  对方：晚上见  ');
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(app.currentInputType, ChatInputType.text);
      expect(app.currentImagePath, isNull);
      expect(app.currentGoal, isNull);
      expect(app.lastInput, isNull);
      expect(app.sharedText, '对方：晚上见');
      expect(await stale.exists(), isFalse);
    } finally {
      app.dispose();
      if (await dir.exists()) await dir.delete(recursive: true);
    }
  });

  test('blank external text route clears stale draft and pending shared text',
      () {
    final app = AppController()
      ..currentInputType = ChatInputType.text
      ..currentTextInput = '旧聊天'
      ..currentSelectedProfileId = 'target'
      ..currentGoal = '旧目标'
      ..currentStyle = ChatStyle.presets[2]
      ..sharedText = '待消费旧分享'
      ..lastInput = ChatInput(
        type: ChatInputType.text,
        text: '旧聊天',
        userGoal: '旧目标',
        selectedStyle: ChatStyle.presets[2],
      );

    app.prepareExternalTextInput();

    expect(app.currentInputType, ChatInputType.text);
    expect(app.currentTextInput, isNull);
    expect(app.currentSelectedProfileId, isNull);
    expect(app.currentGoal, isNull);
    expect(app.currentStyle, ChatStyle.defaultStyle);
    expect(app.sharedText, isNull);
    expect(app.lastInput, isNull);
  });
}
