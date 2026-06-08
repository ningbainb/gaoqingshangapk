part of 'models.dart';

class APIModel {
  const APIModel({required this.id, this.ownedBy, this.capability});

  final String id;
  final String? ownedBy;
  final ModelCapability? capability;

  bool get isVoiceModel => looksVoiceModelId(id);

  bool get isNonChatModel => looksNonChatModelId(id);

  bool get isVisionCandidate =>
      !isVoiceModel &&
      !isNonChatModel &&
      ((capability?.isMultimodal ?? false) || looksMultimodalModelId(id));

  bool get isTextCandidate => !isVoiceModel && !isNonChatModel;

  String get displayTitle {
    if (isVoiceModel) return '$id · 语音';
    if (isNonChatModel) return '$id · 非聊天';
    return id;
  }

  factory APIModel.fromJson(Map<String, dynamic> json) =>
      _apiModelFromJson(json);
}

bool looksVoiceModelId(String id) {
  final lower = id.toLowerCase();
  return lower.contains('tts') ||
      lower.contains('voice') ||
      lower.contains('audio') ||
      lower.contains('transcribe') ||
      lower.contains('whisper');
}

bool looksNonChatModelId(String id) {
  final lower = id.toLowerCase();
  return lower.contains('embedding') ||
      lower.contains('embed') ||
      lower.contains('moderation') ||
      lower.contains('safety') ||
      lower.contains('classifier') ||
      lower.contains('classification') ||
      lower.contains('rerank') ||
      lower.contains('guard') ||
      lower.contains('gpt-image') ||
      lower.contains('dall-e') ||
      lower.contains('imagen') ||
      lower.contains('image-generation') ||
      lower.contains('image_generation') ||
      lower.contains('imagegen') ||
      lower.contains('stable-diffusion') ||
      lower.contains('sdxl') ||
      lower.contains('flux') ||
      lower.contains('sora') ||
      lower.contains('video') ||
      lower.contains('realtime');
}

bool looksMultimodalModelId(String id) {
  final lower = id.toLowerCase();
  return lower.contains('vision') ||
      lower.contains('omni') ||
      lower.contains('vl') ||
      lower.contains('llava') ||
      lower.contains('minicpm') ||
      lower.contains('internvl') ||
      lower.contains('step-1v') ||
      lower.contains('4v') ||
      lower.contains('4o') ||
      lower.contains('gpt-5') ||
      lower.contains('gemini') ||
      lower.contains('qwen-vl');
}
