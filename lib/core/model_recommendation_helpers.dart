import 'models.dart';
import 'model_id.dart';

String? preferredTextModel(List<String> ids) {
  final candidates = ids.where(isRecommendedTextCandidate).toList()
    ..sort((a, b) => textModelRecommendationScore(b)
        .compareTo(textModelRecommendationScore(a)));
  return candidates.isEmpty ? null : cleanModelId(candidates.first);
}

String? preferredVisionModel(List<APIModel> models) {
  final candidates = models
      .where((model) => model.isVisionCandidate)
      .map((model) => cleanModelId(model.id))
      .where((id) => id.isNotEmpty)
      .toList()
    ..sort((a, b) => visionModelRecommendationScore(b)
        .compareTo(visionModelRecommendationScore(a)));
  return candidates.isEmpty ? null : candidates.first;
}

String? matchingRecommendedModelId(List<String> ids, String modelId) {
  final normalized = normalizedModelId(modelId);
  if (normalized.isEmpty) return null;
  for (final id in ids) {
    if (normalizedModelId(id) == normalized) return cleanModelId(id);
  }
  return null;
}

bool isRecommendedTextCandidate(String id) =>
    !looksVoiceModelId(id) && !looksNonChatModelId(id);

bool isUsableRecommendedVisionModel(String id) =>
    isRecommendedTextCandidate(id) && looksMultimodalModelId(id);

bool looksReasoningModelId(String id) {
  final lower = id.toLowerCase();
  return RegExp(r'(^|[/:\-_])o\d').hasMatch(lower) ||
      lower.contains('reason') ||
      lower.contains('think') ||
      lower.contains('r1');
}

int textModelRecommendationScore(String id) {
  final lower = id.toLowerCase();
  var score = 0;
  if (lower.contains('mini') || lower.contains('flash')) score += 25;
  if (lower.contains('gpt-4o')) score += 45;
  if (lower.contains('gpt-5')) score += 40;
  if (lower.contains('gemini')) score += 35;
  if (lower.contains('claude')) score += 30;
  if (lower.contains('qwen')) score += 25;
  if (looksReasoningModelId(id)) score -= 18;
  if (looksMultimodalModelId(id)) score -= 4;
  return score;
}

int visionModelRecommendationScore(String id) {
  final lower = id.toLowerCase();
  var score = textModelRecommendationScore(id);
  if (looksMultimodalModelId(id)) score += 80;
  if (lower.contains('vision') || lower.contains('omni')) score += 12;
  if (lower.contains('4o') || lower.contains('gpt-5')) score += 10;
  if (lower.contains('vl')) score += 8;
  return score;
}
