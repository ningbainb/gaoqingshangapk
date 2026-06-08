import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import 'app_error_messages.dart';
import 'app_feedback.dart';
import 'api_config_rules.dart';
import 'api_service.dart';
import 'generation_goal_helpers.dart';
import 'history_record_collection_helpers.dart';
import 'history_copy_updates.dart';
import 'image_service.dart';
import 'model_recommendations.dart';
import 'models.dart';
import 'owned_file_cleaner.dart';
import 'presentation_text_helpers.dart';
import 'profile_insights.dart';
import 'prompt_context_builder.dart';
import 'record_retention.dart';
import 'storage.dart';

export 'app_error_messages.dart';

part 'app_state_clipboard_actions.dart';
part 'app_state_external_handoffs.dart';
part 'app_state_external_image_handoffs.dart';
part 'app_state_external_quick_handoffs.dart';
part 'app_state_external_text_handoffs.dart';
part 'app_state_records.dart';
part 'app_state_simulation.dart';
part 'app_state_personalization.dart';
part 'app_state_appearance.dart';
part 'app_state_api_settings.dart';
part 'app_state_api_tests.dart';
part 'app_state_editable_drafts.dart';
part 'app_state_generation.dart';
part 'app_state_image_generation.dart';
part 'app_state_local_data.dart';
part 'app_state_moment_analysis.dart';
part 'app_state_model_fetching.dart';
part 'app_state_regeneration.dart';
part 'app_state_reply_generation_flow.dart';
part 'app_state_runtime_helpers.dart';
part 'app_state_text_generation.dart';

class AppController extends ChangeNotifier {
  static const int _maxHistoryCount = 100;
  static const int _maxProfileCount = 50;

  AppController({
    LocalStore? store,
    OpenAICompatibleApi? api,
    ImageService? imageService,
    Future<Directory> Function()? supportDirectoryProvider,
    Future<Directory> Function()? temporaryDirectoryProvider,
  })  : _store = store ?? LocalStore(),
        _api = api ?? OpenAICompatibleApi(),
        _imageService = imageService ?? ImageService(),
        _supportDirectoryProvider =
            supportDirectoryProvider ?? getApplicationSupportDirectory,
        _fileCleaner = OwnedFileCleaner(
          supportDirectoryProvider:
              supportDirectoryProvider ?? getApplicationSupportDirectory,
          temporaryDirectoryProvider:
              temporaryDirectoryProvider ?? getTemporaryDirectory,
        );

  final LocalStore _store;
  final OpenAICompatibleApi _api;
  final ImageService _imageService;
  final Future<Directory> Function() _supportDirectoryProvider;
  final OwnedFileCleaner _fileCleaner;
  final PromptContextBuilder _promptContextBuilder = PromptContextBuilder();

  APIConfig config = APIConfig.defaults;
  String apiKey = '';
  List<GenerationRecord> history = [];
  List<PersonProfile> profiles = [];
  ReplyPersonalizationSettings personalization =
      ReplyPersonalizationSettings.defaults;
  AppearanceSettings appearance = AppearanceSettings.defaults;
  ChatStyle defaultStyle = ChatStyle.defaultStyle;
  List<APIModel> availableModels = [];
  bool isFetchingModels = false;
  bool isTestingConnection = false;
  bool isTestingVision = false;
  ChatReplyResponse? currentResponse;
  PersonProfile? currentGeneratedProfile;
  MomentProfileAnalysis? currentMomentAnalysis;
  PersonProfile? currentMomentProfile;
  ChatInputType currentInputType = ChatInputType.text;
  ChatStyle currentStyle = ChatStyle.defaultStyle;
  String? currentGoal;
  String? currentTextInput;
  String? currentImagePath;
  String? currentSelectedProfileId;
  String? currentRecordId;
  String? quickImagePath;
  String? sharedImagePath;
  String? sharedText;
  bool isQuickReplySession = false;
  bool shouldReadQuickClipboardOnOpen = false;
  bool shouldAutoGenerateQuickReply = false;
  bool shouldResetQuickReplyDraft = false;
  ChatInput? lastInput;
  PersonProfile? simulationProfile;
  SimulationScenario simulationScenario = SimulationScenario.dailyChat;
  List<SimulationMessage> simulationMessages = [];
  SimulationTurnResponse? simulationResponse;
  bool isBusy = false;
  bool showingPrivacyNotice = false;
  String? statusMessage;
  String? errorMessage;
  GenerationRecord? selectedHistoryRecord;
  PersonProfile? selectedProfile;
  String? _availableModelsFingerprint;
  SimulationScenario? _openingSimulationScenario;
  int _modelFetchGeneration = 0;
  int _settingsRevision = 0;
  int _contentRevision = 0;
  int _simulationRevision = 0;
  int _historyRevision = 0;
  int _profilesRevision = 0;
  int _backgroundRevision = 0;
  int _preferencesRevision = 0;
  int _appearanceRevision = 0;
  int _loadRevision = 0;
  int _privacyRevision = 0;
  int _generationRevision = 0;
  int _localDataClearRevision = 0;
  int _connectionTestGeneration = 0;
  int _visionTestGeneration = 0;
  int _busyRevision = 0;
  int _replyGenerationBusyRevision = 0;
  int _momentAnalysisRevision = 0;
  bool _hasLoadedInitialState = false;
  bool _isReplyGenerationBusy = false;
  bool floatingAutoStart = false;

  bool get shouldDeferExternalHandoffs =>
      !_hasLoadedInitialState || showingPrivacyNotice;

  void _notifyControllerListeners() => notifyListeners();

  Future<void> load() async {
    final requestRevision = _beginInitialLoadOperation();
    final requestMutationFingerprint = _loadMutationFingerprint();
    final loadedConfig = await _store.loadConfig();
    final loadedApiKey = await _store.loadAPIKey();
    final loadedHistory = await _store.loadHistory();
    final loadedProfiles = await _store.loadProfiles();
    final loadedPersonalization =
        (await _store.loadPersonalization()).normalized();
    final defaultStyleId = await _store.loadDefaultStyleId();
    final availableStyles = loadedPersonalization.availableStyles;
    final loadedDefaultStyle = chatStyleById(availableStyles, defaultStyleId) ??
        chatStyleByName(availableStyles, defaultStyleId,
            preferOfficial: true) ??
        ChatStyle.defaultStyle;
    final loadedAppearance = await _store.loadAppearance();
    final loadedShowingPrivacyNotice = !(await _store.hasSeenPrivacyNotice());
    final loadedFloatingAutoStart = await _store.loadFloatingAutoStart();
    if (!_isCurrentInitialLoadOperation(requestRevision)) {
      return;
    }
    if (requestMutationFingerprint != _loadMutationFingerprint()) {
      _applyLoadedPrivacyState(loadedShowingPrivacyNotice);
      return;
    }
    _applyLoadedInitialState(
      loadedConfig: loadedConfig,
      loadedApiKey: loadedApiKey,
      loadedHistory: loadedHistory,
      loadedProfiles: loadedProfiles,
      loadedPersonalization: loadedPersonalization,
      loadedDefaultStyle: loadedDefaultStyle,
      loadedAppearance: loadedAppearance,
      loadedShowingPrivacyNotice: loadedShowingPrivacyNotice,
      loadedFloatingAutoStart: loadedFloatingAutoStart,
    );
  }

  String _loadMutationFingerprint() => [
        _settingsRevision,
        _contentRevision,
        _simulationRevision,
        _historyRevision,
        _profilesRevision,
        _backgroundRevision,
        _preferencesRevision,
        _appearanceRevision,
      ].join('|');

  String personalizationPromptContext() {
    return _promptContextBuilder.personalizationPromptContext(
      personalization: personalization,
      history: history,
      preferencesRevision: _preferencesRevision,
      historyRevision: _historyRevision,
    );
  }

  String makePersonProfileContext({String? selectedProfileId}) {
    return _promptContextBuilder.makePersonProfileContext(
      profiles: profiles,
      profilesRevision: _profilesRevision,
      selectedProfileId: selectedProfileId,
    );
  }
}
