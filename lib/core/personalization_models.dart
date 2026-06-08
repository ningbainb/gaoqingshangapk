part of 'models.dart';

enum UserGender { unspecified, female, male, nonBinary }

extension UserGenderText on UserGender {
  String get title => switch (this) {
        UserGender.unspecified => '不填写',
        UserGender.female => '女',
        UserGender.male => '男',
        UserGender.nonBinary => '其他',
      };

  String? get promptText => switch (this) {
        UserGender.unspecified => null,
        UserGender.female => '女',
        UserGender.male => '男',
        UserGender.nonBinary => '用户自定义/非二元',
      };
}

class ReplyPersonalizationSettings {
  const ReplyPersonalizationSettings({
    this.isColloquialExpressionEnabled = true,
    this.userGender = UserGender.unspecified,
    this.userAgeText = '',
    this.customStyles = const [],
    this.isConversationMemoryEnabled = true,
    this.isAdaptiveStyleEnabled = true,
    this.memoryNotes = '',
  });

  final bool isColloquialExpressionEnabled;
  final UserGender userGender;
  final String userAgeText;
  final List<ChatStyle> customStyles;
  final bool isConversationMemoryEnabled;
  final bool isAdaptiveStyleEnabled;
  final String memoryNotes;

  static const defaults = ReplyPersonalizationSettings();

  List<ChatStyle> get availableStyles =>
      [...ChatStyle.presets, ...customStyles];

  String get enabledFeatureSummary {
    return _personalizationFeatureLabels(this).join(' · ');
  }

  ReplyPersonalizationSettings normalized() {
    final usedStyleIds = ChatStyle.presets
        .map((style) => normalizedChatStyleId(style.id))
        .whereType<String>()
        .toSet();
    final normalizedStyles = <ChatStyle>[];
    for (final style in customStyles) {
      final name = cleanPresentationText(style.name);
      if (name == null) continue;
      var id = cleanIdentifierText(style.id) ?? '';
      var normalizedId = normalizedChatStyleId(id);
      if (normalizedId == null || usedStyleIds.contains(normalizedId)) {
        id = _uuid.v4();
        normalizedId = normalizedChatStyleId(id);
      }
      usedStyleIds.add(normalizedId!);
      normalizedStyles.add(ChatStyle(
        id: id,
        name: name,
        description: cleanPresentationText(style.description) ?? '',
        rules: cleanPresentationList(style.rules),
        isOfficial: false,
      ));
    }
    return ReplyPersonalizationSettings(
      isColloquialExpressionEnabled: isColloquialExpressionEnabled,
      userGender: userGender,
      userAgeText: cleanPresentationText(userAgeText) ?? '',
      customStyles: normalizedStyles,
      isConversationMemoryEnabled: isConversationMemoryEnabled,
      isAdaptiveStyleEnabled: isAdaptiveStyleEnabled,
      memoryNotes: cleanPresentationText(memoryNotes) ?? '',
    );
  }

  ReplyPersonalizationSettings copyWith({
    bool? isColloquialExpressionEnabled,
    UserGender? userGender,
    String? userAgeText,
    List<ChatStyle>? customStyles,
    bool? isConversationMemoryEnabled,
    bool? isAdaptiveStyleEnabled,
    String? memoryNotes,
  }) {
    return ReplyPersonalizationSettings(
      isColloquialExpressionEnabled:
          isColloquialExpressionEnabled ?? this.isColloquialExpressionEnabled,
      userGender: userGender ?? this.userGender,
      userAgeText: userAgeText ?? this.userAgeText,
      customStyles: customStyles ?? this.customStyles,
      isConversationMemoryEnabled:
          isConversationMemoryEnabled ?? this.isConversationMemoryEnabled,
      isAdaptiveStyleEnabled:
          isAdaptiveStyleEnabled ?? this.isAdaptiveStyleEnabled,
      memoryNotes: memoryNotes ?? this.memoryNotes,
    );
  }

  factory ReplyPersonalizationSettings.fromJson(Map<String, dynamic> json) =>
      _personalizationSettingsFromJson(json);

  Map<String, dynamic> toJson() {
    final settings = normalized();
    return {
      'isColloquialExpressionEnabled': settings.isColloquialExpressionEnabled,
      'userGender': settings.userGender.name,
      'userAgeText': settings.userAgeText,
      'customStyles': settings.customStyles.map((e) => e.toJson()).toList(),
      'isConversationMemoryEnabled': settings.isConversationMemoryEnabled,
      'isAdaptiveStyleEnabled': settings.isAdaptiveStyleEnabled,
      'memoryNotes': settings.memoryNotes,
    };
  }
}

List<String> _personalizationFeatureLabels(
  ReplyPersonalizationSettings settings,
) {
  final normalized = settings.normalized();
  final features = <String>[];
  features.add(normalized.isColloquialExpressionEnabled ? '口语化' : '稳重表达');
  if (normalized.userGender != UserGender.unspecified ||
      cleanPresentationText(normalized.userAgeText) != null) {
    features.add('我的资料');
  }
  if (normalized.isConversationMemoryEnabled) {
    features.add('记忆');
  }
  if (normalized.isAdaptiveStyleEnabled) {
    features.add('自适应');
  }
  if (normalized.customStyles.isNotEmpty) {
    features.add('自定义风格 ${normalized.customStyles.length}');
  }
  return features;
}
