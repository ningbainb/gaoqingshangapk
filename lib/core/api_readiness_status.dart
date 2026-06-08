part of 'models.dart';

String _generateAPIReadinessStatusText(GenerateAPIReadiness readiness) {
  if (!readiness.hasAPIKey) {
    if (readiness.capability == GenerateAPICapability.vision) {
      return readiness.isQuickReply
          ? '填写 Key 后才能调用视觉模型；配置完成前快捷回复不会发送请求。'
          : '填写 Key 后才能调用视觉模型；配置完成前不会发送截图。';
    }
    return '填写 Key 后才能调用模型；配置完成前不会发送请求。';
  }
  if (!readiness.hasValidBaseURL) {
    return 'API Base URL 格式不正确，请返回设置页修正。';
  }
  if (!readiness.hasTextModel) {
    return readiness.capability == GenerateAPICapability.vision
        ? '文本模型名称为空，无法把识别结果整理成候选回复。'
        : '文本模型名称为空，文本生成暂不可用。';
  }

  if (readiness.capability == GenerateAPICapability.text) {
    return '文本：${readiness.textModelName}';
  }
  if (!readiness.config.enableImageInput) {
    return readiness.isQuickReply
        ? '快捷回复需要截图模式开启，才能读取当前界面并生成回复。'
        : '截图模式已关闭，请在 API 设置中开启。';
  }
  if (!readiness.hasVisionModel) {
    return '视觉模型名称为空，截图生成暂不可用。';
  }
  if (!readiness.hasUsableVisionModel) {
    return visionChatModelRequiredMessage;
  }
  if (!readiness.hasMultimodalVisionModel) {
    return '请先在 API 设置里把视觉模型标记为多模态。';
  }
  return '视觉：${readiness.visionModelName} · 文本：${readiness.textModelName}';
}
