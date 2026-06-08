part of 'prompts.dart';

String momentProfilePrompt({String? personProfileContext}) {
  final cleanedPersonProfileContext = cleanPresentationText(
    personProfileContext,
  );
  return '''
请分析这张朋友圈/社交动态截图，自动提取可沉淀到人物库的信息。

本次用户指定的可能写入对象：
${cleanedPersonProfileContext ?? '未指定，请根据截图可见昵称和内容自动判断。'}

如果用户指定了写入对象，且截图内容没有明显矛盾，请优先把 visibleName、relationshipGuess 和沟通建议对齐到这个人物库对象；如果截图明显不是这个人，请在 updateReason 里说明不确定。

你要识别：
1. 截图来源平台，如果无法判断则写“未知”
2. 可见昵称或可见称呼，如果没有则为空
3. 内容主题、发帖风格、互动方式
4. 性格倾向：只基于文字和社交内容做“倾向性描述”，不要绝对化
5. 内心需求：例如安全感、被理解、成就感、陪伴、边界感等，只能写“可能更在意...”
6. 关键人物点：和这个人沟通时最应该记住的点
7. 适合怎么回、怎么接近、怎么保持边界
8. 可稳定保存的事实，必须来自截图可见文字或明确语境

安全边界：
- 不要识别人脸或根据头像推断真实身份
- 不要推断年龄、性别、民族、健康、宗教、政治等敏感/生物特征
- 不要把心理推测写成确定事实，使用“可能、倾向、看起来更在意”等表达
- 如果截图不是朋友圈/社交动态，也尽量提取内容画像；完全无法识别时给低 confidence
- 必须输出 JSON，不要输出多余解释

JSON 格式：
{
  "sceneSummary": "一句话总结这张动态截图体现出的内容画像",
  "sourcePlatform": "微信朋友圈/小红书/微博/QQ空间/未知",
  "visibleName": "截图中可见昵称，没有则为空",
  "relationshipGuess": "朋友/同学/同事/暧昧对象/未知",
  "personalityTraits": ["基于文字内容得到的性格倾向"],
  "innerNeeds": ["可能更在意的内心需求"],
  "keyPersonPoints": ["和这个人相处/聊天要记住的关键点"],
  "momentsInsights": ["朋友圈内容暴露出的稳定观察"],
  "communicationAdvice": ["适合怎么回应或开启话题"],
  "boundaries": ["应该避免的沟通方式"],
  "stableFacts": ["截图可见或强语境支持的事实"],
  "confidence": 0.6,
  "updateReason": "为什么这些信息值得加入人物库"
}
''';
}
