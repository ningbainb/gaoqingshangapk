const apiBaseUrlInvalidMessage = 'API Base URL 格式不正确。';
const apiKeyRequiredMessage = '请先填写 API Key。';
const textModelRequiredMessage = '文本模型名称不能为空。';
const visionModelRequiredMessage = '视觉模型名称不能为空。';
const visionChatModelRequiredMessage = '视觉模型需要选择支持图像输入的聊天模型，不能使用语音、审核或图片生成模型。';
const imageMaxWidthTooSmallMessage = '图片最大宽度不能小于 320。';
const imageCompressionQualityInvalidMessage = '图片压缩质量需要在 0.1 到 1.0 之间。';

const apiRequestTimeoutMessage = '接口请求超时，请稍后重试或调大请求超时。';
const apiConnectionInterruptedMessage = '接口连接被中断，服务器可能已断开连接或没有返回完整响应。';
const apiNetworkConnectionFailedMessage = '网络连接失败，请检查网络或 API Base URL。';
const apiUserAuthInvalidMessage = 'API Key 无效或没有权限，请重新检查配置。';
const apiConnectionServerUnreachableMessage =
    '无法连接到接口服务器，请检查 Base URL、端口和服务状态。';

String apiModelAuthFailureMessage(String detail) {
  return 'API Key 无效或没有权限调用当前模型，请重新检查配置。服务端返回：$detail';
}

String apiFetchModelsAuthFailureMessage(String detail) {
  return 'API Key 无效或没有权限拉取模型列表，请重新生成 Key 后保存。服务端返回：$detail';
}
