import 'package:flutter/material.dart';

import 'models.dart';
import 'presentation_text_helpers.dart';
import 'text_cleaning.dart';
import 'text_truncation.dart';

export 'presentation_text_helpers.dart';

extension PersonProfilePresentation on PersonProfile {
  String get displayLabel => cleanPresentationText(displayName) ?? '未命名人物';

  String get displayInitial => presentationInitial(displayLabel, fallback: '未');

  String? get displayRelationship => cleanPresentationText(relationship);

  String get detailRelationshipLabel => displayRelationship ?? '关系待确认';

  String? get displayCommunicationStyle =>
      cleanPresentationText(communicationStyle);

  List<String> get displayLatestWriteSources => uniqueCleanPresentationList([
        lastSceneSummary,
        lastUpdateReason,
      ]);

  String get subtitleLabel =>
      displayCommunicationStyle ?? displayRelationship ?? '根据人物画像模拟对方语气。';

  String get listSubtitleLabel =>
      displayCommunicationStyle ??
      cleanPresentationText(lastSceneSummary) ??
      '等待更多聊天样本完善画像';

  String get pickerSubtitleLabel {
    final relationship = displayRelationship;
    final style = displayCommunicationStyle;
    if (relationship != null && style != null) return '$relationship · $style';
    if (relationship != null) return relationship;
    if (style != null) return style;
    final tonePreferences = uniqueCleanPresentationList(this.tonePreferences);
    if (tonePreferences.isNotEmpty) return tonePreferences.first;
    return '等待更多聊天样本完善画像';
  }

  List<(String, bool)> get coverageSections =>
      personProfileCoverageSections(this);

  int get coveragePercent => personProfileCoveragePercent(this);

  List<String> get missingCoverageLabels => coverageSections
      .where((section) => !section.$2)
      .map((section) => section.$1)
      .toList();

  String? get missingCoverageSuggestion {
    final missing = missingCoverageLabels;
    if (missing.isEmpty) return null;
    return '建议优先补：${missing.take(3).join('、')}';
  }
}

extension PersonInsightPresentation on PersonInsight {
  String? get displayLabel => cleanPresentationText(displayName);

  String? get displayRelationship => cleanPresentationText(relationship);

  String? get displayCommunicationStyle =>
      cleanPresentationText(communicationStyle);

  String? get displayUpdateReason => cleanPresentationText(updateReason);

  String? get displayConfidencePercent {
    final value = confidence;
    if (value == null) return null;
    return '${(value.clamp(0, 1) * 100).round()}%';
  }

  List<String> get resultTags => uniqueCleanPresentationList([
        ...?tonePreferences,
        ...?boundaries,
        ...?personalityTraits,
      ]).take(6).toList();

  List<String> get resultFootnoteParts => [
        if (displayConfidencePercent != null) '置信度 $displayConfidencePercent',
        if (displayUpdateReason != null) displayUpdateReason!,
      ];

  String resultTitle(PersonProfile? savedProfile) =>
      savedProfile?.displayLabel ?? displayLabel ?? '待命名人物';

  PersonProfile draftProfile(String? sceneSummary) {
    return PersonProfile(
      displayName: displayLabel ?? '',
      aliases: uniqueCleanPresentationList(aliases ?? const []),
      relationship: displayRelationship,
      communicationStyle: displayCommunicationStyle,
      personalityTraits:
          uniqueCleanPresentationList(personalityTraits ?? const []),
      innerNeeds: uniqueCleanPresentationList(innerNeeds ?? const []),
      keyPersonPoints: uniqueCleanPresentationList(keyPersonPoints ?? const []),
      momentsInsights: uniqueCleanPresentationList(momentsInsights ?? const []),
      tonePreferences: uniqueCleanPresentationList(tonePreferences ?? const []),
      boundaries: uniqueCleanPresentationList(boundaries ?? const []),
      facts: uniqueCleanPresentationList(facts ?? const []),
      lastSceneSummary: cleanPresentationText(sceneSummary),
      lastUpdateReason: displayUpdateReason,
      confidence: (confidence ?? 0.4).clamp(0, 1).toDouble(),
    );
  }
}

extension MomentProfileAnalysisPresentation on MomentProfileAnalysis {
  String profileDisplayName(PersonProfile? savedProfile) =>
      savedProfile?.displayLabel ??
      cleanPresentationText(visibleName) ??
      '朋友圈对象';

  String get displaySceneSummary =>
      cleanPresentationText(sceneSummary) ?? '已从截图提取人物画像。';

  String? get displaySourcePlatform => cleanPresentationText(sourcePlatform);

  String? get displayVisibleName => cleanPresentationText(visibleName);

  String? get displayRelationshipGuess =>
      cleanPresentationText(relationshipGuess);

  String? get displayUpdateReason => cleanPresentationText(updateReason);

  String get displayConfidencePercent =>
      '${(confidence.clamp(0, 1) * 100).round()}%';

  List<(String, String)> get displayInfoLines {
    final traits = _joinedPresentationList(personalityTraits);
    final needs = _joinedPresentationList(innerNeeds);
    final keyPoints = _joinedPresentationList(keyPersonPoints);
    final insights = _joinedPresentationList(momentsInsights);
    final advice = _joinedPresentationList(communicationAdvice);
    final boundaryLines = _joinedPresentationList(boundaries);
    final facts = _joinedPresentationList(stableFacts);
    return [
      ('总结', displaySceneSummary),
      if (displaySourcePlatform != null) ('平台', displaySourcePlatform!),
      if (displayVisibleName != null) ('昵称', displayVisibleName!),
      if (displayRelationshipGuess != null) ('关系', displayRelationshipGuess!),
      ('置信度', displayConfidencePercent),
      ('新增线索', '$writableInsightCount 条'),
      if (displayUpdateReason != null) ('依据', displayUpdateReason!),
      if (traits != null) ('性格', traits),
      if (needs != null) ('需求', needs),
      if (keyPoints != null) ('关键点', keyPoints),
      if (insights != null) ('朋友圈观察', insights),
      if (advice != null) ('建议', advice),
      if (boundaryLines != null) ('避雷', boundaryLines),
      if (facts != null) ('事实', facts),
    ];
  }
}

extension ChatReplyResponsePresentation on ChatReplyResponse {
  String get displaySceneSummary =>
      cleanPresentationText(sceneSummary) ?? '未识别';

  String? get displayPlatform => cleanPresentationText(platform);

  String? get displayRelationshipGuess =>
      cleanPresentationText(relationshipGuess);

  String? get displayLatestMessage => cleanPresentationText(latestMessage);

  String? get displayEmotion => cleanPresentationText(emotion);

  String? get displayRiskNotice => cleanPresentationText(riskNotice);

  List<(String, String)> get resultInfoLines => [
        ('场景', displaySceneSummary),
        if (displayPlatform != null) ('平台', displayPlatform!),
        if (displayRelationshipGuess != null) ('关系', displayRelationshipGuess!),
        if (displayLatestMessage != null) ('最后一句', displayLatestMessage!),
        if (displayEmotion != null) ('情绪', displayEmotion!),
        if (displayRiskNotice != null) ('风险', displayRiskNotice!),
      ];
}

extension GenerationRecordPresentation on GenerationRecord {
  String get displaySceneSummary =>
      cleanPresentationText(sceneSummary) ?? '未识别场景';

  String get displayStyleName =>
      cleanPresentationText(selectedStyleName) ?? '自然';

  String? get displayPlatform => cleanPresentationText(platform);

  String? get displayRelationshipGuess =>
      cleanPresentationText(relationshipGuess);

  String? get displayLatestMessage => cleanPresentationText(latestMessage);

  String? get displayEmotion => cleanPresentationText(emotion);

  String? get displayRiskNotice => cleanPresentationText(riskNotice);

  String? get displayUserGoal => cleanPresentationText(userGoal);

  String? get displayCopiedReply => cleanPresentationText(copiedReply);
}

extension AppearancePresentation on AppearanceSettings {
  bool get hasCustomBackground =>
      cleanPresentationText(customBackgroundPath) != null;

  String get backgroundSummary => hasCustomBackground ? '自定义背景' : '默认玻璃背景';

  Color get accentColor {
    return switch (accentColorName) {
      'mint' => const Color(0xFF43D9AD),
      'sunset' || 'amber' => const Color(0xFFFF9433),
      'rose' => const Color(0xFFFF5F9E),
      'violet' => const Color(0xFFA78BFA),
      _ => const Color(0xFF2EAFFF),
    };
  }

  double get textScale {
    return switch (textSizeName) {
      'compact' => 0.94,
      'comfortable' => 1.06,
      'large' => 1.12,
      _ => 1.0,
    };
  }
}

String joinEditorLines(List<String> values) =>
    uniqueCleanPresentationList(values).join('\n');

List<String> splitEditorLines(String value) =>
    uniqueCleanPresentationList(value.split(RegExp(r'[\n,，、;；]+')));

bool canSaveProfileEditorDraft(String displayName) =>
    cleanPresentationText(displayName) != null;

PersonProfile? personProfileFromEditorDraft({
  required PersonProfile? original,
  required String displayName,
  required String aliases,
  required String relationship,
  required String communicationStyle,
  required String personalityTraits,
  required String innerNeeds,
  required String keyPersonPoints,
  required String momentsInsights,
  required String tonePreferences,
  required String boundaries,
  required String facts,
  required String lastSceneSummary,
  required String lastUpdateReason,
  required double confidence,
}) {
  final name = cleanPresentationText(displayName);
  if (name == null) return null;
  return PersonProfile(
    id: original?.id,
    displayName: name,
    aliases: splitEditorLines(aliases),
    relationship: cleanPresentationText(relationship),
    communicationStyle: cleanPresentationText(communicationStyle),
    personalityTraits: splitEditorLines(personalityTraits),
    innerNeeds: splitEditorLines(innerNeeds),
    keyPersonPoints: splitEditorLines(keyPersonPoints),
    momentsInsights: splitEditorLines(momentsInsights),
    tonePreferences: splitEditorLines(tonePreferences),
    boundaries: splitEditorLines(boundaries),
    facts: splitEditorLines(facts),
    lastSceneSummary: cleanPresentationText(lastSceneSummary),
    lastUpdateReason: cleanPresentationText(lastUpdateReason),
    confidence: confidence,
    createdAt: original?.createdAt,
  );
}

String profileEditorTextWithSuggestion(String current, String value) {
  final lines = splitEditorLines(current);
  return uniqueCleanPresentationList([...lines, value]).join('\n');
}

String presentationInitial(String value, {String fallback = '?'}) {
  final trimmed = cleanNonEmptyText(value);
  return trimmed == null ? fallback : trimmed.characters.first;
}

String truncatedPresentationText(
  String value, {
  required int maxCharacters,
  String omission = '...',
}) {
  final trimmed = cleanNonEmptyText(value) ?? '';
  return truncateVisibleText(
    trimmed,
    maxCharacters: maxCharacters,
    omission: omission,
  );
}

String? _joinedPresentationList(List<String> values) {
  final visibleValues = uniqueCleanPresentationList(values);
  return visibleValues.isEmpty ? null : visibleValues.join('；');
}
