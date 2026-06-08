part of 'models.dart';

class ChatStyle {
  ChatStyle({
    String? id,
    required this.name,
    required this.description,
    required this.rules,
    this.isOfficial = true,
  }) : id = cleanIdentifierText(id) ?? _uuid.v4();

  final String id;
  final String name;
  final String description;
  final List<String> rules;
  final bool isOfficial;

  static final presets = <ChatStyle>[
    ChatStyle(
        id: 'official-natural',
        name: '自然',
        description: '像真人日常聊天，不刻意、不油腻',
        rules: ['语气自然', '不要太正式', '不要过度讨好', '每条回复不超过40字']),
    ChatStyle(
        id: 'official-relaxed',
        name: '松弛',
        description: '轻一点接住话题，给对方舒服空间',
        rules: ['语气放松', '避免压迫感', '不要连环追问', '保留一点余地']),
    ChatStyle(
        id: 'official-flirty',
        name: '暧昧',
        description: '有一点心动感，但不过界',
        rules: ['轻微暧昧', '不低俗', '不强行推进关系', '保持分寸']),
    ChatStyle(
        id: 'official-humor',
        name: '幽默',
        description: '用轻松玩笑缓和氛围',
        rules: ['自然幽默', '不要阴阳怪气', '不冒犯对方', '优先让对方好接']),
    ChatStyle(
        id: 'official-gentle',
        name: '温柔',
        description: '柔和、体贴、稳定地回应',
        rules: ['语气温柔', '表达理解', '不说教', '不过度煽情']),
    ChatStyle(
        id: 'official-comfort',
        name: '安慰',
        description: '先接住情绪，再给一点陪伴',
        rules: ['先共情', '避免空洞鸡汤', '不要否定对方感受', '表达陪伴']),
    ChatStyle(
        id: 'official-apology',
        name: '道歉',
        description: '解释但不卑微，承担该承担的部分',
        rules: ['真诚道歉', '不甩锅', '解释克制', '给出改进态度']),
    ChatStyle(
        id: 'official-workplace',
        name: '职场',
        description: '清晰、有边界、礼貌专业',
        rules: ['表达清楚', '语气礼貌', '不情绪化', '保留边界']),
  ];

  static ChatStyle get defaultStyle => presets.first;

  factory ChatStyle.fromJson(Map<String, dynamic> json) =>
      _chatStyleFromJson(json);

  Map<String, dynamic> toJson() => {
        'id': cleanIdentifierText(id) ?? _uuid.v4(),
        'name': cleanPresentationText(name) ?? '',
        'description': cleanPresentationText(description) ?? '',
        'rules': cleanPresentationList(rules),
        'isOfficial': isOfficial,
      };
}
