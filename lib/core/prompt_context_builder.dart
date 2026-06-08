import 'models.dart';
import 'presentation_text_helpers.dart';

class PromptContextBuilder {
  PromptContextBuilder({
    this.conversationMemoryPromptLimit = 6,
    this.adaptiveStylePromptLimit = 5,
    this.profilePromptCandidateLimit = 3,
  });

  final int conversationMemoryPromptLimit;
  final int adaptiveStylePromptLimit;
  final int profilePromptCandidateLimit;

  final _personalizationCache = _PromptCacheSlot();
  final _personProfileCache = _PersonProfileContextCache();

  String personalizationPromptContext({
    required ReplyPersonalizationSettings personalization,
    required List<GenerationRecord> history,
    required int preferencesRevision,
    required int historyRevision,
  }) {
    final fingerprint = _personalizationPromptFingerprint(
      personalization: personalization,
      history: history,
      preferencesRevision: preferencesRevision,
      historyRevision: historyRevision,
    );
    if (_personalizationCache.fingerprint == fingerprint &&
        _personalizationCache.value != null) {
      return _personalizationCache.value!;
    }
    final context = _buildPersonalizationPromptContext(
      personalization: personalization,
      history: history,
    );
    _personalizationCache
      ..fingerprint = fingerprint
      ..value = context;
    return context;
  }

  String makePersonProfileContext({
    required List<PersonProfile> profiles,
    required int profilesRevision,
    String? selectedProfileId,
  }) {
    final fingerprint = _personProfilePromptFingerprint(
      profiles: profiles,
      profilesRevision: profilesRevision,
    );
    if (_personProfileCache.fingerprint != fingerprint) {
      _personProfileCache
        ..fingerprint = fingerprint
        ..values.clear();
    }
    final normalizedSelectedProfileId =
        normalizedPersonProfileId(selectedProfileId);
    final cacheKey = normalizedSelectedProfileId ?? '__auto__';
    final cached = _personProfileCache.values[cacheKey];
    if (cached != null) return cached;
    final context = _buildPersonProfileContext(
      profiles: profiles,
      selectedProfileId: normalizedSelectedProfileId,
    );
    _personProfileCache.values[cacheKey] = context;
    return context;
  }

  String _buildPersonalizationPromptContext({
    required ReplyPersonalizationSettings personalization,
    required List<GenerationRecord> history,
  }) {
    final settings = personalization.normalized();
    final sections = <String>[];
    final profileLines = <String>[];
    final gender = settings.userGender.promptText;
    if (gender != null) {
      profileLines.add('我的性别：$gender');
    }
    final userAgeText = cleanPresentationText(settings.userAgeText);
    if (userAgeText != null) {
      profileLines.add('我的年龄：$userAgeText');
    }
    if (profileLines.isNotEmpty) {
      profileLines.add('这些资料只用于调整第一人称表达视角；除非聊天语境需要，不要主动提起年龄或性别。');
      sections.add('我的资料：\n${profileLines.join('\n')}');
    }
    sections.add(settings.isColloquialExpressionEnabled
        ? '话术格式：\n- 开启口语化表达，回复要像手机聊天里随手发出的自然表达\n- 少用书面词、总结腔、客服腔和完整作文句\n- 优先短句、轻语气、可直接复制发送\n- 可以有一点停顿感和生活感，但不要堆“哈哈”“呢”“呀”'
        : '话术格式：\n- 口语化表达关闭，回复可以更清晰、稳重、完整\n- 仍然避免 AI 腔、说教感和过度正式');
    sections.add('候选回复质量要求：\n'
        '- 5 条候选必须都服从用户当前选择的风格，并在该风格内部做明显差异\n'
        '- 当前选择风格优先级高于人物库、历史记忆、已采用回复和自定义偏好\n'
        '- 如果历史采用回复或人物库语气与当前风格冲突，只参考事实和避雷点，不模仿冲突语气\n'
        '- 差异可以来自：接住情绪、轻推话题、边界清晰、化解尴尬、低压力收尾\n'
        '- 先选清楚每条候选的策略，再写成一句自然聊天短句\n'
        '- 不要 5 条只是同一句话换词\n'
        '- 不要为了显得高情商而过度解释、过度共情或替对方下结论\n'
        '- 不要暴露“我在分析你/我看了截图/根据人物库”\n'
        '- 每条都必须能直接复制发送，不要加引号、编号或解释\n'
        '- 如果关系不确定，宁可克制一点，不要突然暧昧或过度亲密');
    final memoryNotes = cleanPresentationText(settings.memoryNotes);
    if (memoryNotes != null) {
      sections.add('用户手动记忆：\n$memoryNotes');
    }
    final recentHistory = _historyPromptEntries(history);
    if (settings.isConversationMemoryEnabled) {
      final memory = recentHistory
          .take(conversationMemoryPromptLimit)
          .toList()
          .asMap()
          .entries
          .map((entry) {
        return '${entry.key + 1}. ${entry.value.memoryLine}';
      }).join('\n');
      if (memory.isNotEmpty) sections.add('对话记忆：\n$memory');
    }
    if (settings.isAdaptiveStyleEnabled) {
      final adaptive = recentHistory
          .map((entry) => entry.adaptiveStyleLine)
          .whereType<String>()
          .take(adaptiveStylePromptLimit)
          .join('\n');
      sections.add(adaptive.isEmpty
          ? '自适应我的风格：开启。只能在不偏离当前选择风格的前提下，参考人物库和本次上下文学习用户偏好的语气。'
          : '自适应我的风格：\n用户最近采用过的回复：\n$adaptive\n\n只能在不偏离当前选择风格的前提下，参考这些回复的长度、松弛度、标点密度和亲近感；如果冲突，以当前选择风格为准，不要复读原句。');
    }
    return sections.join('\n\n');
  }

  String _buildPersonProfileContext({
    required List<PersonProfile> profiles,
    String? selectedProfileId,
  }) {
    final normalizedProfiles =
        profiles.map((profile) => profile.normalized()).toList();
    final normalizedSelectedProfileId =
        normalizedPersonProfileId(selectedProfileId);
    if (normalizedSelectedProfileId != null) {
      final index = normalizedProfiles.indexWhere((profile) =>
          personProfileIdsMatch(profile.id, normalizedSelectedProfileId));
      if (index >= 0) {
        return '用户本次指定聊天对象：\n${normalizedProfiles[index].summaryForPrompt}';
      }
    }
    if (normalizedProfiles.isEmpty) {
      return '暂无人物库记录。请只根据本次聊天内容提取非生物特征，不要根据头像或面部推断真实身份。';
    }
    final recentProfiles = normalizedProfiles
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    final summaries = recentProfiles
        .take(profilePromptCandidateLimit)
        .map((profile) => '候选画像：\n${profile.summaryForPrompt}')
        .join('\n\n');
    return '''
用户未指定聊天对象。请根据截图或文本中的称呼、关系、语气和上下文，从下面最近人物画像中谨慎匹配；如果匹配不确定，只作为弱参考，不要编造身份。

$summaries
''';
  }

  String _personalizationPromptFingerprint({
    required ReplyPersonalizationSettings personalization,
    required List<GenerationRecord> history,
    required int preferencesRevision,
    required int historyRevision,
  }) {
    final recentHistory = _historyPromptEntries(history);
    return [
      preferencesRevision,
      historyRevision,
      identityHashCode(personalization),
      identityHashCode(history),
      history.length,
      recentHistory
          .take(conversationMemoryPromptLimit)
          .map((entry) => entry.marker)
          .join('~'),
      recentHistory
          .where((entry) => entry.copiedReply != null)
          .take(adaptiveStylePromptLimit)
          .map((entry) => entry.marker)
          .join('~'),
    ].join('|');
  }

  String _personProfilePromptFingerprint({
    required List<PersonProfile> profiles,
    required int profilesRevision,
  }) {
    final recentProfiles = profiles
        .map((profile) => profile.normalized())
        .toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return [
      profilesRevision,
      identityHashCode(profiles),
      profiles.length,
      recentProfiles.map(_profilePromptMarker).join('~'),
    ].join('|');
  }

  List<_HistoryPromptEntry> _historyPromptEntries(
    List<GenerationRecord> history,
  ) =>
      history.map(_HistoryPromptEntry.from).toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  String _profilePromptMarker(PersonProfile profile) {
    return [
      profile.id,
      profile.updatedAt.microsecondsSinceEpoch,
      profile.promptSummaryLines.join('/'),
    ].join(':');
  }
}

class _HistoryPromptEntry {
  const _HistoryPromptEntry({
    required this.id,
    required this.createdAt,
    required this.latestMessage,
    required this.sceneSummary,
    required this.copiedReply,
    required this.styleName,
    required this.replySamples,
  });

  factory _HistoryPromptEntry.from(GenerationRecord record) {
    final normalized = record.normalized();
    return _HistoryPromptEntry(
      id: normalized.id,
      createdAt: normalized.createdAt,
      latestMessage: cleanPresentationText(normalized.latestMessage),
      sceneSummary: cleanPresentationText(normalized.sceneSummary),
      copiedReply: cleanPresentationText(normalized.copiedReply),
      styleName: cleanPresentationText(normalized.selectedStyleName) ?? '自然',
      replySamples: cleanUniqueReplyTexts(normalized.replies, limit: 2),
    );
  }

  final String id;
  final DateTime createdAt;
  final String? latestMessage;
  final String? sceneSummary;
  final String? copiedReply;
  final String styleName;
  final List<String> replySamples;

  String get memoryLine {
    final parts = <String>[
      if (latestMessage != null) '对方最后一句：$latestMessage',
      if (sceneSummary != null) '场景：$sceneSummary',
      if (copiedReply != null) '用户采用过：$copiedReply',
      if (replySamples.isNotEmpty) '当时候选示例：${replySamples.join(' / ')}',
      '当时风格：$styleName',
    ];
    return parts.join('；');
  }

  String? get adaptiveStyleLine {
    final copied = copiedReply;
    if (copied == null) return null;
    return '“$copied”（$styleName）';
  }

  String get marker => [
        id,
        createdAt.microsecondsSinceEpoch,
        latestMessage ?? '',
        sceneSummary ?? '',
        copiedReply ?? '',
        styleName,
        replySamples.length,
        replySamples.join('/'),
      ].join(':');
}

class _PromptCacheSlot {
  String? fingerprint;
  String? value;
}

class _PersonProfileContextCache {
  String? fingerprint;
  final values = <String, String>{};
}
