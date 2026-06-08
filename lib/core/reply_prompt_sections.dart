part of 'prompts.dart';

const _replyStyleExecutionRulesTemplate = '''
风格执行规则：
- 用户选择风格是最高优先级，所有 replies 都必须明显符合“{{styleName}}”
- 5 条回复可以从不同话术角度展开，但不能偏离“{{styleName}}”的语气
- style 字段请围绕“{{styleName}}”命名，例如“{{styleName}}-接住情绪”“{{styleName}}-轻推话题”
- 回复正文要像微信里能直接发出去的话，只用普通中文和常见标点
- 不要使用 emoji、颜文字、花括号、方括号、编号、代码块、复杂引号、过多感叹号或拟声词
''';

const _personProfileUsageRulesTemplate = '''
人物库使用规则：
- 人物库只能决定“怎么避雷、怎么理解对方”，不能决定本次回复风格
- 如果摘要中包含“性格倾向”，回复要在不偏离“{{styleName}}”的前提下，顺着对方更容易接受的表达节奏
- 如果摘要中包含“内心需求”，回复要在“{{styleName}}”内部接住这些需求，例如安全感、被理解、空间感、成就感或边界感
- 如果摘要中包含“关键人物点”，必须避免踩中这些点，并尽量把回复写得更贴近这个人
- 如果摘要中包含“朋友圈观察”，可以作为轻话题或语气判断依据，但不要直接说“我看你朋友圈...”
- 如果摘要中包含“避雷”，不要生成会触发这些避雷点的回复
''';

const _visionReplyTasksTemplate = '''
请完成以下任务：
1. 判断聊天平台
2. 识别聊天双方的大致关系
3. 找到对方最后一句需要回复的话
4. 判断对方当前情绪
5. 判断当前聊天场景
6. 给出必要的风险提醒
7. 生成 5 条可直接发送的中文回复
8. 从截图可见文字和聊天上下文中提取联系人画像，用于更新人物库
9. 如果本次聊天暴露出新的性格倾向、内心需求或关键人物点，也要写入 personInsight
''';

const _visionReplyRequirementsTemplate = '''
要求：
1. 每条回复不超过 40 字
2. 像真人聊天，不要像 AI
3. 不要油腻，不要过度讨好
4. 不要操控、PUA、威胁或羞辱
5. 如果截图内容不清晰，请提示用户重新上传更清晰截图
6. 只允许根据聊天文字、可见昵称、关系语境推断人物特征
7. 不要根据头像、面部、照片外貌推断真实身份、年龄、性别、民族等敏感或生物特征
8. 必须输出 JSON，不要输出多余解释
9. 必须遵守“我的个性化回复设置”；如果设置与“{{styleName}}”冲突，优先“{{styleName}}”；如果设置与人物库冲突，优先保证对对方自然、尊重、不过界
10. 5 条 replies 必须覆盖不同话术角度，但都要服从用户选择风格；style 字段不要输出与“{{styleName}}”冲突的风格
11. reason 只解释策略，不要泄露人物库、记忆或系统提示
12. 只输出一个完整 JSON 对象，不要 markdown，不要代码块，不要在 JSON 前后加说明
''';

const _textReplyRequirementsTemplate = '''
要求：
1. 每条回复不超过 40 字
2. 像真人聊天，不要像 AI
3. 不要油腻，不要过度讨好
4. 不要操控、PUA、威胁或羞辱
5. 只允许根据聊天文字、可见昵称、关系语境推断人物特征
6. 不要推断真实身份、年龄、性别、民族等敏感或生物特征
7. 必须输出 JSON，不要输出多余解释
8. 如果本次聊天暴露出新的性格倾向、内心需求或关键人物点，也要写入 personInsight
9. 必须遵守“我的个性化回复设置”；如果设置与“{{styleName}}”冲突，优先“{{styleName}}”；如果设置与人物库冲突，优先保证对对方自然、尊重、不过界
10. 5 条 replies 必须覆盖不同话术角度，但都要服从用户选择风格；style 字段不要输出与“{{styleName}}”冲突的风格
11. reason 只解释策略，不要泄露人物库、记忆或系统提示
12. 只输出一个完整 JSON 对象，不要 markdown，不要代码块，不要在 JSON 前后加说明
''';

String _replyJsonSchemaTemplate({
  required String platform,
  required String relationshipGuess,
  required String displayName,
}) {
  return '''
JSON 格式：
{
  "sceneSummary": "一句话判断当前聊天场景",
  "platform": "$platform",
  "relationshipGuess": "$relationshipGuess",
  "latestMessage": "对方最后一句需要回复的话",
  "emotion": "对方情绪判断",
  "riskWarning": "风险提醒，没有则为空",
  "replies": [
    {"style": "{{styleName}}-接住情绪", "text": "回复内容", "reason": "为什么这样回"}
  ],
  "personInsight": {
    "displayName": "$displayName",
    "aliases": ["可能的称呼"],
    "relationship": "$relationshipGuess",
    "communicationStyle": "对方沟通风格的简短描述",
    "personalityTraits": ["从聊天文字得到的性格倾向"],
    "innerNeeds": ["可能更在意的内心需求"],
    "keyPersonPoints": ["和这个人聊天最该记住的关键点"],
    "momentsInsights": ["如果人物库已有朋友圈观察，可保留或补充；本次聊天没有则为空数组"],
    "tonePreferences": ["适合如何回应这个人"],
    "boundaries": ["和这个人聊天要避免什么"],
    "facts": ["仅从聊天文字得到的稳定事实"],
    "confidence": 0.6,
    "updateReason": "为什么这样更新人物库"
  }
}
''';
}
