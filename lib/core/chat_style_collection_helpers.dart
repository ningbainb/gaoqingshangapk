part of 'models.dart';

String? normalizedChatStyleId(String? id) {
  return cleanIdentifierText(id)?.toLowerCase();
}

String? normalizedChatStyleName(String? name) {
  final cleaned = cleanPresentationText(name);
  return cleaned?.toLowerCase();
}

bool chatStyleIdsMatch(String? left, String? right) {
  final normalizedLeft = normalizedChatStyleId(left);
  final normalizedRight = normalizedChatStyleId(right);
  return normalizedLeft != null &&
      normalizedRight != null &&
      normalizedLeft == normalizedRight;
}

bool chatStyleNamesMatch(String? left, String? right) {
  final normalizedLeft = normalizedChatStyleName(left);
  final normalizedRight = normalizedChatStyleName(right);
  return normalizedLeft != null &&
      normalizedRight != null &&
      normalizedLeft == normalizedRight;
}

ChatStyle? chatStyleById(Iterable<ChatStyle> styles, String? id) {
  final normalizedId = normalizedChatStyleId(id);
  if (normalizedId == null) return null;
  for (final style in styles) {
    if (chatStyleIdsMatch(style.id, normalizedId)) return style;
  }
  return null;
}

ChatStyle? chatStyleByName(
  Iterable<ChatStyle> styles,
  String? name, {
  bool preferOfficial = false,
}) {
  final normalizedName = normalizedChatStyleName(name);
  if (normalizedName == null) return null;
  final matches = styles
      .where((style) => chatStyleNamesMatch(style.name, normalizedName))
      .toList();
  if (matches.length == 1) return matches.single;
  if (!preferOfficial) return null;
  final officialMatches = matches.where((style) => style.isOfficial).toList();
  return officialMatches.length == 1 ? officialMatches.single : null;
}

bool canCreateCustomChatStyleDraft(String? name) =>
    cleanPresentationText(name) != null;

ChatStyle? customChatStyleFromDraft({
  required String? name,
  required String? description,
  required String? rulesText,
}) {
  final cleanName = cleanPresentationText(name);
  if (cleanName == null) return null;
  final cleanDescription = cleanPresentationText(description);
  final rules = cleanPresentationList(
    rulesText?.split(RegExp(r'[\n,，、;；]+')),
  );
  return ChatStyle(
    name: cleanName,
    description: cleanDescription ?? '按我的日常聊天习惯生成',
    rules: rules.isEmpty ? [cleanDescription ?? '贴近我的日常聊天习惯'] : rules,
    isOfficial: false,
  );
}
