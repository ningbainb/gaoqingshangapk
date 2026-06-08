part of 'models.dart';

ModelCapability? _apiModelCapability(Map<String, dynamic> json) {
  final direct = _firstValue(json, _modelFeatureContainerKeys);
  final directCapability = direct is Map
      ? ModelCapability.fromJson(Map<String, dynamic>.from(direct))
      : null;
  final directModalitiesCapability =
      direct is Map ? null : _capabilityFromModalities(direct);
  final topLevelCapability = _hasAnyNormalizedKey(
    json,
    _modelTopLevelCapabilityKeys,
  )
      ? ModelCapability.fromJson(json)
      : null;
  final modalitiesCapability = _capabilityFromModalities(json);
  final nestedCapability = _capabilityFromNestedModelMetadata(json);
  if (directCapability == null &&
      directModalitiesCapability == null &&
      topLevelCapability == null &&
      modalitiesCapability == null &&
      nestedCapability == null) {
    return null;
  }
  return ModelCapability(
    isMultimodal: (directCapability?.isMultimodal ?? false) ||
        (directModalitiesCapability?.isMultimodal ?? false) ||
        (topLevelCapability?.isMultimodal ?? false) ||
        (modalitiesCapability?.isMultimodal ?? false) ||
        (nestedCapability?.isMultimodal ?? false),
    isReasoning: (directCapability?.isReasoning ?? false) ||
        (directModalitiesCapability?.isReasoning ?? false) ||
        (topLevelCapability?.isReasoning ?? false) ||
        (modalitiesCapability?.isReasoning ?? false) ||
        (nestedCapability?.isReasoning ?? false),
  );
}

ModelCapability? _capabilityFromNestedModelMetadata(Map<String, dynamic> json) {
  final nestedMaps = _modelNestedMetadataKeys
      .map((key) => _valueForKey(json, key))
      .whereType<Map>()
      .map((value) => Map<String, dynamic>.from(value));
  ModelCapability? result;
  for (final nested in nestedMaps) {
    final direct = ModelCapability.fromJson(nested);
    final modalities = _capabilityFromModalities(nested);
    final hasCapability =
        direct.isMultimodal || direct.isReasoning || modalities != null;
    if (!hasCapability) continue;
    result = ModelCapability(
      isMultimodal: (result?.isMultimodal ?? false) ||
          direct.isMultimodal ||
          (modalities?.isMultimodal ?? false),
      isReasoning: (result?.isReasoning ?? false) ||
          direct.isReasoning ||
          (modalities?.isReasoning ?? false),
    );
  }
  return result;
}

ModelCapability? _capabilityFromModalities(Object? raw) {
  final values = _modalityValues(raw).map((e) => e.toLowerCase()).toList();
  if (values.isEmpty) return null;
  final hasVision = values.any((value) =>
      value.contains('image') ||
      value.contains('vision') ||
      value.contains('visual') ||
      value.contains('multimodal'));
  final hasReasoning = values
      .any((value) => value.contains('reason') || value.contains('think'));
  return ModelCapability(isMultimodal: hasVision, isReasoning: hasReasoning);
}

List<String> _modalityValues(Object? raw) {
  if (raw is Map) {
    final json = raw.map((key, value) => MapEntry(key.toString(), value));
    final inputValues = <String>[];
    for (final key in _modelModalityContainerKeys) {
      final value = _valueForKey(json, key);
      if (value == null) continue;
      inputValues.addAll(_modalityValues(value));
    }
    if (inputValues.isNotEmpty) return inputValues;

    final objectValue = _stringListItemText(json);
    if (objectValue != null) return [objectValue];

    return json.entries
        .where((entry) => _boolValue(entry.value) == true)
        .map((entry) => entry.key)
        .map(cleanPresentationText)
        .whereType<String>()
        .toList();
  }
  return _stringList(raw);
}

bool _hasAnyNormalizedKey(Map<String, dynamic> json, List<String> keys) {
  final normalizedKeys = keys.map(normalizedLooseKey).toSet();
  return json.keys
      .map((key) => normalizedLooseKey(key.toString()))
      .any(normalizedKeys.contains);
}
