import 'models.dart';
import 'model_id.dart';
import 'model_recommendation_helpers.dart';
import 'presentation_text_helpers.dart';

APIConfig configWithRecommendedModels(APIConfig base, List<APIModel> models) {
  final baseTextModel = cleanPresentationText(base.textModelName) ?? '';
  final baseVisionModel = cleanPresentationText(base.visionModelName) ?? '';
  final modelById = {
    for (final model in models)
      if (cleanModelId(model.id).isNotEmpty) normalizedModelId(model.id): model
  };
  final ids = models
      .map((e) => cleanModelId(e.id))
      .where((id) => id.isNotEmpty)
      .toList();
  if (ids.isEmpty) return base;
  final matchedTextModel = matchingRecommendedModelId(ids, baseTextModel);
  final canKeepTextModel = matchedTextModel != null &&
      !looksVoiceModelId(matchedTextModel) &&
      !looksNonChatModelId(matchedTextModel);
  final textModel =
      canKeepTextModel ? matchedTextModel : preferredTextModel(ids);
  final existingVisionCapability = base.capability(baseVisionModel);
  final matchedVisionModel = matchingRecommendedModelId(ids, baseVisionModel);
  final canKeepVisionModel = matchedVisionModel != null &&
      !looksVoiceModelId(matchedVisionModel) &&
      !looksNonChatModelId(matchedVisionModel) &&
      (existingVisionCapability.isMultimodal ||
          (modelById[normalizedModelId(matchedVisionModel)]
                  ?.isVisionCandidate ??
              false) ||
          looksMultimodalModelId(matchedVisionModel));
  final visionModel =
      canKeepVisionModel ? matchedVisionModel : preferredVisionModel(models);
  final capabilities = <String, ModelCapability>{};
  for (final entry in base.modelCapabilities.entries) {
    final id = cleanPresentationText(entry.key);
    if (id == null) continue;
    replaceCapability(capabilities, id, entry.value);
  }
  for (final model in models) {
    final id = cleanModelId(model.id);
    if (id.isEmpty) continue;
    if (looksVoiceModelId(id) || looksNonChatModelId(id)) {
      final current = APIConfig.lookupCapability(capabilities, id);
      replaceCapability(
        capabilities,
        id,
        ModelCapability(
          isMultimodal: false,
          isReasoning: current.isReasoning || looksReasoningModelId(id),
        ),
      );
      continue;
    }
    final declared = model.capability;
    final declaredMultimodal = model.isVisionCandidate;
    final declaredReasoning = declared?.isReasoning ?? false;
    if (declared != null) {
      final current = APIConfig.lookupCapability(capabilities, id);
      replaceCapability(
        capabilities,
        id,
        ModelCapability(
          isMultimodal: current.isMultimodal || declaredMultimodal,
          isReasoning: current.isReasoning ||
              declaredReasoning ||
              looksReasoningModelId(id),
        ),
      );
      continue;
    }
    if (!capabilities.keys.any((key) => modelIdsEqual(key, id))) {
      replaceCapability(
        capabilities,
        id,
        ModelCapability(
          isMultimodal: isUsableRecommendedVisionModel(id),
          isReasoning: looksReasoningModelId(id),
        ),
      );
    }
  }
  if (visionModel != null &&
      !looksVoiceModelId(visionModel) &&
      !looksNonChatModelId(visionModel) &&
      ((modelById[normalizedModelId(visionModel)]?.isVisionCandidate ??
              false) ||
          looksMultimodalModelId(visionModel) ||
          base.capability(visionModel).isMultimodal)) {
    final current = APIConfig.lookupCapability(capabilities, visionModel);
    replaceCapability(
      capabilities,
      visionModel,
      ModelCapability(
        isMultimodal: true,
        isReasoning: current.isReasoning || looksReasoningModelId(visionModel),
      ),
    );
  }
  return base.copyWith(
    textModelName: textModel ?? baseTextModel,
    visionModelName: visionModel ?? baseVisionModel,
    modelCapabilities: capabilities,
  );
}
