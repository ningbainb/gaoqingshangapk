part of 'models.dart';

class ModelCapability {
  const ModelCapability({this.isMultimodal = false, this.isReasoning = false});

  final bool isMultimodal;
  final bool isReasoning;

  factory ModelCapability.fromJson(Map<String, dynamic> json) =>
      ModelCapability(
        isMultimodal: _boolValue(
              _firstValue(json, _modelMultimodalCapabilityKeys),
            ) ??
            false,
        isReasoning: _boolValue(
              _firstValue(json, _modelReasoningCapabilityKeys),
            ) ??
            false,
      );

  Map<String, dynamic> toJson() => {
        'isMultimodal': isMultimodal,
        'isReasoning': isReasoning,
      };
}

void _mergeModelCapabilities(
  Map<String, ModelCapability> capabilities,
  Object? raw,
) {
  final importedModelIds = <String>{};
  if (raw is Map) {
    raw.forEach((key, value) {
      _putImportedCapability(
        capabilities,
        cleanPresentationText(key?.toString()),
        value,
        importedModelIds,
      );
    });
    return;
  }
  if (raw is! List) return;
  for (final item in raw) {
    if (item is! Map) continue;
    try {
      final json = Map<String, dynamic>.from(item);
      final modelId = _firstClean(json, const [
        'id',
        'modelId',
        'modelName',
        'model',
        'name',
      ]);
      final capability = _apiModelCapability(json);
      if (modelId == null || capability == null) continue;
      _putImportedCapability(
        capabilities,
        modelId,
        capability,
        importedModelIds,
      );
    } catch (_) {
      // Skip malformed list entries but keep the rest of the config.
    }
  }
}

void _putImportedCapability(
  Map<String, ModelCapability> capabilities,
  String? modelId,
  Object? raw,
  Set<String> importedModelIds,
) {
  if (modelId == null) return;
  try {
    final capability = _capabilityFromImportedValue(raw);
    if (capability == null) return;
    final normalized = normalizedModelId(modelId);
    if (normalized.isEmpty) return;
    if (importedModelIds.add(normalized)) {
      capabilities
          .removeWhere((key, _) => normalizedModelId(key) == normalized);
    }
    mergeCapability(capabilities, modelId, capability);
  } catch (_) {
    // Skip malformed capability entries but keep the rest of the config.
  }
}

ModelCapability? _capabilityFromImportedValue(Object? raw) {
  if (raw is ModelCapability) return raw;
  if (raw is Map) {
    final json = Map<String, dynamic>.from(raw);
    final direct = ModelCapability.fromJson(json);
    final modalities = _capabilityFromModalities(json);
    final nested = _capabilityFromNestedModelMetadata(json);
    final container = _capabilityFromImportedValue(
      _firstValue(json, _modelCapabilityContainerKeys),
    );
    final hasCapability = direct.isMultimodal ||
        direct.isReasoning ||
        modalities != null ||
        nested != null ||
        container != null;
    if (!hasCapability) return null;
    return ModelCapability(
      isMultimodal: direct.isMultimodal ||
          (modalities?.isMultimodal ?? false) ||
          (nested?.isMultimodal ?? false) ||
          (container?.isMultimodal ?? false),
      isReasoning: direct.isReasoning ||
          (modalities?.isReasoning ?? false) ||
          (nested?.isReasoning ?? false) ||
          (container?.isReasoning ?? false),
    );
  }
  return _capabilityFromModalities(raw);
}

void putCapability(
  Map<String, ModelCapability> capabilities,
  String modelId,
  ModelCapability capability,
) {
  final normalized = normalizedModelId(modelId);
  if (normalized.isEmpty) return;
  final canonical = capabilities.keys.firstWhere(
    (key) => normalizedModelId(key) == normalized,
    orElse: () => cleanModelId(modelId),
  );
  capabilities.removeWhere((key, _) => normalizedModelId(key) == normalized);
  capabilities[cleanModelId(canonical)] = capability;
}

void mergeCapability(
  Map<String, ModelCapability> capabilities,
  String modelId,
  ModelCapability capability,
) {
  final trimmed = cleanModelId(modelId);
  final normalized = normalizedModelId(trimmed);
  if (normalized.isEmpty) return;
  MapEntry<String, ModelCapability>? existingEntry;
  for (final entry in capabilities.entries) {
    if (normalizedModelId(entry.key) == normalized) {
      existingEntry = entry;
      break;
    }
  }
  final canonical = cleanModelId(existingEntry?.key ?? trimmed);
  final existing = existingEntry?.value;
  capabilities.removeWhere((key, _) => normalizedModelId(key) == normalized);
  capabilities[canonical] = ModelCapability(
    isMultimodal: (existing?.isMultimodal ?? false) || capability.isMultimodal,
    isReasoning: (existing?.isReasoning ?? false) || capability.isReasoning,
  );
}

void replaceCapability(
  Map<String, ModelCapability> capabilities,
  String modelId,
  ModelCapability capability,
) {
  final trimmed = cleanModelId(modelId);
  final normalized = normalizedModelId(trimmed);
  if (normalized.isEmpty) return;
  capabilities.removeWhere((key, _) => normalizedModelId(key) == normalized);
  capabilities[trimmed] = capability;
}
