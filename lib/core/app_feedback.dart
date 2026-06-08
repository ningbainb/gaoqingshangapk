import 'text_cleaning.dart';

const apiKeyPasteSuccessMessage = '已从剪贴板填入 API Key，记得保存配置。';
const apiKeyPasteEmptyMessage = '剪贴板里没有可用的 API Key。';
const privacyClearSuccessMessage = '本地数据已清空，API 配置已恢复默认。';
const noClipboardScreenshotMessage = '剪贴板里没有可用截图。请先截屏并复制，或使用相册选择。';
const customBackgroundImportedMessage = '背景已导入';
const customBackgroundResetMessage = '已恢复默认背景';
const customBackgroundFailurePrefix = '背景保存失败';

bool isAPISettingsStatusMessage(String? message) {
  final value = cleanFeedbackMessage(message);
  if (value == null) return false;
  return value == apiKeyPasteSuccessMessage ||
      value == '配置已保存' ||
      value == '配置已恢复默认，API Key 已清除' ||
      value == 'API Key 已清除，其他配置已保留' ||
      value.startsWith('连接测试成功') ||
      value.startsWith('视觉模型测试成功') ||
      value.startsWith('已拉取 ');
}

bool isAPISettingsErrorMessage(String? message) {
  final value = cleanFeedbackMessage(message);
  if (value == null) return false;
  if (isAPISettingsStatusMessage(value)) return false;
  return value == apiKeyPasteEmptyMessage ||
      value.startsWith('视觉模型测试失败') ||
      value.startsWith('读取剪贴板失败') ||
      value.contains('API Key') ||
      value.contains('Base URL') ||
      value.contains('模型') ||
      value.contains('配置') ||
      value.contains('连接') ||
      value.contains('超时') ||
      value.contains('服务端');
}

bool isAppearanceStatusMessage(String? message) {
  final value = cleanFeedbackMessage(message);
  if (value == null) return false;
  return value == customBackgroundImportedMessage ||
      value == customBackgroundResetMessage;
}

bool isAppearanceErrorMessage(String? message) {
  final value = cleanFeedbackMessage(message);
  if (value == null) return false;
  return value.startsWith(customBackgroundFailurePrefix);
}

bool isAppearanceFeedbackMessage(String? message) =>
    isAppearanceStatusMessage(message) || isAppearanceErrorMessage(message);

String? cleanFeedbackMessage(String? message) => cleanNonEmptyText(message);

bool isOwnedTransientImagePath(String? path) {
  final name = imagePathFileName(path);
  if (name == null) return false;
  return name.startsWith('floating-capture-') ||
      name.startsWith('clipboard-image-') ||
      name.startsWith('accessibility-capture-');
}

String? cleanImagePathInput(String? path) => cleanNonEmptyText(path);

String? imagePathFileName(String? path) {
  final cleanedPath = cleanImagePathInput(path);
  if (cleanedPath == null) return null;
  final segments = Uri.file(cleanedPath).pathSegments;
  if (segments.isEmpty) return null;
  return cleanNonEmptyText(segments.last);
}

bool hasUsableImagePath(String? path) => cleanImagePathInput(path) != null;

String? pastedAPIKeyFromClipboardText(String? clipboardText) {
  return cleanAPIKeyInput(clipboardText);
}

String? cleanAPIKeyInput(String? value) => cleanNonEmptyText(value);

bool hasUsableAPIKey(String? value) {
  return cleanAPIKeyInput(value) != null;
}
