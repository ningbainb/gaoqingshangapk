part of 'prompts.dart';

String visionReplyPrompt({
  required ChatStyle style,
  String? userGoal,
  String? personProfileContext,
  String? personalizationContext,
}) {
  return _fill(
    '''
请分析这张聊天截图，并生成中文聊天回复建议。

用户选择风格：
{{styleName}}

风格要求：
{{styleRules}}

$_replyStyleExecutionRulesTemplate

$_stylePriorityGuidance

用户目标：
{{userGoal}}

已有人物库摘要：
{{personProfileContext}}

我的个性化回复设置：
{{personalizationContext}}

$_personProfileUsageRulesTemplate

$_replyStrategyGuidance

$_visionReplyTasksTemplate

$_visionReplyRequirementsTemplate

$_replySelfCheck

${_replyJsonSchemaTemplate(
      platform: '微信/QQ/小红书/未知',
      relationshipGuess: '朋友/暧昧对象/同事/同学/未知',
      displayName: '截图中可见的昵称或用户给出的称呼，没有则为空',
    )}
''',
    style: style,
    userGoal: userGoal,
    personProfileContext: personProfileContext,
    personalizationContext: personalizationContext,
  );
}

String visionExtractionPrompt() {
  return '''
请只读取这张聊天截图中的可见文字和明确界面语境，整理成结构化 JSON。

要求：
- 不要生成回复
- 尽量按聊天顺序还原双方消息
- 标出对方最后一句话，如果无法确定就留空
- 只能基于截图可见文字，不要根据头像或面部推断身份
- 必须输出 JSON，不要输出 Markdown

JSON 格式：
{
  "conversationText": "按顺序整理出的聊天文本，用换行分隔；尽量标注我/对方/可见昵称",
  "sceneSummary": "一句话总结可见聊天场景",
  "latestMessage": "对方最后一句话，没有则为空",
  "visibleName": "截图中可见的对方昵称，没有则为空",
  "notes": "任何影响回复判断的边界、上下文或不确定性"
}
''';
}

String textReplyPrompt({
  required String text,
  required ChatStyle style,
  String? userGoal,
  String? personProfileContext,
  String? personalizationContext,
}) {
  return _fill(
    '''
请根据以下聊天内容生成 5 条中文回复。

聊天内容：
{{text}}

用户选择风格：
{{styleName}}

风格要求：
{{styleRules}}

$_replyStyleExecutionRulesTemplate

$_stylePriorityGuidance

用户目标：
{{userGoal}}

已有人物库摘要：
{{personProfileContext}}

我的个性化回复设置：
{{personalizationContext}}

$_personProfileUsageRulesTemplate

$_replyStrategyGuidance

$_textReplyRequirementsTemplate

$_replySelfCheck

${_replyJsonSchemaTemplate(
      platform: '未知',
      relationshipGuess: '关系判断',
      displayName: '聊天中可见的昵称或用户给出的称呼，没有则为空',
    )}
''',
    text: text,
    style: style,
    userGoal: userGoal,
    personProfileContext: personProfileContext,
    personalizationContext: personalizationContext,
  );
}
