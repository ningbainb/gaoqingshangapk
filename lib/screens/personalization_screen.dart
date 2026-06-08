import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/app_provider.dart';
import '../core/app_state.dart';
import '../core/models.dart';
import '../core/transient_feedback_timer.dart';
import '../widgets/glass_scaffold.dart';
import '../widgets/personalization_widgets.dart';

class PersonalizationScreen extends ConsumerStatefulWidget {
  const PersonalizationScreen({super.key});

  @override
  ConsumerState<PersonalizationScreen> createState() =>
      _PersonalizationScreenState();
}

class _PersonalizationScreenState extends ConsumerState<PersonalizationScreen> {
  late final AppController _app;
  late bool colloquial;
  late bool memory;
  late bool adaptive;
  late UserGender gender;
  late final TextEditingController age;
  late final TextEditingController notes;
  late List<ChatStyle> customStyles;
  final styleName = TextEditingController();
  final styleDescription = TextEditingController();
  final styleRules = TextEditingController();
  Timer? saveTimer;
  Timer? messageTimer;
  String? saveMessage;

  @override
  void initState() {
    super.initState();
    _app = ref.read(appProvider);
    final settings = _app.personalization;
    colloquial = settings.isColloquialExpressionEnabled;
    memory = settings.isConversationMemoryEnabled;
    adaptive = settings.isAdaptiveStyleEnabled;
    gender = settings.userGender;
    age = TextEditingController(text: settings.userAgeText);
    notes = TextEditingController(text: settings.memoryNotes);
    customStyles = List.of(settings.customStyles);
  }

  @override
  void dispose() {
    final hasPendingSave = saveTimer?.isActive ?? false;
    saveTimer?.cancel();
    messageTimer?.cancel();
    if (hasPendingSave) {
      unawaited(_app.savePersonalization(draftSettings, notify: false));
    }
    age.dispose();
    notes.dispose();
    styleName.dispose();
    styleDescription.dispose();
    styleRules.dispose();
    super.dispose();
  }

  ReplyPersonalizationSettings get draftSettings =>
      ReplyPersonalizationSettings(
        isColloquialExpressionEnabled: colloquial,
        userGender: gender,
        userAgeText: age.text,
        customStyles: customStyles,
        isConversationMemoryEnabled: memory,
        isAdaptiveStyleEnabled: adaptive,
        memoryNotes: notes.text,
      ).normalized();

  void scheduleSave({bool immediate = false}) {
    saveTimer?.cancel();
    if (immediate) {
      unawaited(persistDraft());
    } else {
      saveTimer = Timer(const Duration(milliseconds: 450), () {
        unawaited(persistDraft());
      });
    }
  }

  Future<void> persistDraft() async {
    await _app.savePersonalization(draftSettings);
    if (!mounted) return;
    setState(() => saveMessage = '已保存并接入生成');
    messageTimer = scheduleTransientFeedbackReset(
      previousTimer: messageTimer,
      isMounted: () => mounted,
      reset: () => setState(() => saveMessage = null),
    );
  }

  bool get canAddCustomStyle => canCreateCustomChatStyleDraft(styleName.text);

  @override
  Widget build(BuildContext context) {
    return GlassScaffold(
      title: '个性化回复',
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 76, 20, 96),
        children: [
          PersonalizationSummaryCard(
            draft: draftSettings,
            colloquial: colloquial,
            memory: memory,
            adaptive: adaptive,
            saveMessage: saveMessage,
          ),
          const SizedBox(height: 14),
          PersonalizationProfileCard(
            gender: gender,
            age: age,
            onGenderChanged: (item) {
              setState(() => gender = item);
              scheduleSave(immediate: true);
            },
            onAgeChanged: (_) => scheduleSave(),
          ),
          const SizedBox(height: 14),
          PersonalizationSwitchesCard(
            colloquial: colloquial,
            memory: memory,
            adaptive: adaptive,
            onColloquialChanged: (v) {
              setState(() => colloquial = v);
              scheduleSave(immediate: true);
            },
            onMemoryChanged: (v) {
              setState(() => memory = v);
              scheduleSave(immediate: true);
            },
            onAdaptiveChanged: (v) {
              setState(() => adaptive = v);
              scheduleSave(immediate: true);
            },
          ),
          const SizedBox(height: 14),
          PersonalizationMemoryCard(
            notes: notes,
            onNotesChanged: (_) => scheduleSave(),
          ),
          const SizedBox(height: 14),
          PersonalizationCustomStylesCard(
            customStyles: customStyles,
            styleName: styleName,
            styleDescription: styleDescription,
            styleRules: styleRules,
            canAddCustomStyle: canAddCustomStyle,
            onStyleNameChanged: (_) => setState(() {}),
            onRemoveStyle: (style) {
              setState(() => customStyles
                  .removeWhere((item) => chatStyleIdsMatch(item.id, style.id)));
              scheduleSave(immediate: true);
            },
            onAddCustomStyle: addCustomStyle,
          ),
        ],
      ),
    );
  }

  void addCustomStyle() {
    final style = customChatStyleFromDraft(
      name: styleName.text,
      description: styleDescription.text,
      rulesText: styleRules.text,
    );
    if (style == null) return;
    setState(() {
      customStyles = [...customStyles, style];
      styleName.clear();
      styleDescription.clear();
      styleRules.clear();
    });
    scheduleSave(immediate: true);
  }
}
