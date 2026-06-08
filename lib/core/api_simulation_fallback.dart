part of 'api_service.dart';

SimulationTurnResponse _fallbackSimulationTurnResponse(String content) {
  final firstLine = content
      .split(RegExp(r'\n+'))
      .map(_cleanReplyLine)
      .where((line) => !_looksLikeJsonFragment(line))
      .firstWhere((e) => e.isNotEmpty, orElse: () => '嗯，我听到了。你继续说，我想知道你真正的想法。');
  final personaMessage = truncateVisibleText(firstLine, maxCharacters: 90);
  return SimulationTurnResponse(
    personaMessage: personaMessage,
    sceneState: '模型返回格式不标准，已保留可用内容继续训练。',
    favorability: 58,
    tension: 42,
    trust: 55,
    interest: 60,
    feedback: '模型没有返回标准结构，暂时无法给出精确评分。',
    metrics: [
      for (final metric in defaultSimulationMetrics(
        favorability: 58,
        tension: 42,
        trust: 55,
        interest: 60,
      ))
        metric.name == '自然度'
            ? const SimulationMetric(
                name: '自然度', score: 58, insight: '回复可以更像日常聊天。')
            : metric,
      const SimulationMetric(name: '共情感', score: 60, insight: '先接住情绪，再推进话题。'),
      const SimulationMetric(
          name: '推进力', score: 52, insight: '可以多给对方一个容易回应的点。'),
    ],
    options: [
      SimulationOption(
          text: '我懂你的意思，刚刚那一下确实会让人有点不舒服。',
          label: '先共情',
          reason: '先降低对方防御感。',
          predictedScore: 72),
      SimulationOption(
          text: '那你现在更想让我听你说，还是一起想办法？',
          label: '给选择',
          reason: '把节奏交还给对方。',
          predictedScore: 78),
      SimulationOption(
          text: '我刚刚可能接得有点急，我重新听你说。',
          label: '修复感',
          reason: '适合关系有轻微紧张时使用。',
          predictedScore: 75),
    ],
    coachTip: '如果经常出现该提示，可以换一个更稳定支持 JSON 的文本模型。',
  );
}

SimulationTurnResponse _simulationResponseWithDefaults(
  SimulationTurnResponse parsed,
) =>
    SimulationTurnResponse(
      personaMessage: parsed.personaMessage,
      sceneState: parsed.sceneState,
      favorability: parsed.favorability,
      tension: parsed.tension,
      trust: parsed.trust,
      interest: parsed.interest,
      metrics: parsed.metrics.isEmpty
          ? const [
              SimulationMetric(name: '好感度', score: 55, insight: '关系还有继续推进空间。'),
              SimulationMetric(
                  name: '舒适度', score: 58, insight: '保持轻松，不要一次推进太多。'),
              SimulationMetric(name: '回应质量', score: 60, insight: '多接住对方的关键词。'),
            ]
          : parsed.metrics,
      options: parsed.options.isEmpty
          ? [
              SimulationOption(
                  text: '我明白，你刚刚那句话其实挺重要的。',
                  label: '稳妥',
                  reason: '先回应对方表达的重点。',
                  predictedScore: 70),
              SimulationOption(
                  text: '你愿意多说一点吗？我想听真实想法。',
                  label: '追问',
                  reason: '给对方继续表达的空间。',
                  predictedScore: 74),
              SimulationOption(
                  text: '我可能理解得不完全对，你是更在意这件事本身，还是我的态度？',
                  label: '澄清',
                  reason: '适合信息不够时降低误会。',
                  predictedScore: 76),
            ]
          : parsed.options,
      userScore: parsed.userScore,
      feedback: parsed.feedback,
      betterReply: parsed.betterReply,
      coachTip: parsed.coachTip,
    );
