part of 'models.dart';

bool _apiConfigBaseUrlsMatch(String left, String right) {
  final leftCanonical = _apiConfigCanonicalBaseUrl(left);
  final rightCanonical = _apiConfigCanonicalBaseUrl(right);
  if (leftCanonical != null && rightCanonical != null) {
    return leftCanonical == rightCanonical;
  }
  return cleanNonEmptyText(left) == cleanNonEmptyText(right);
}

String? _apiConfigCanonicalBaseUrl(String value) {
  return canonicalApiBaseUrl(value);
}

bool _apiConfigModelIdsMatch(String left, String right) {
  return modelIdsEqual(left, right);
}

bool _apiConfigCapabilitiesMatch(
  Map<String, ModelCapability> left,
  Map<String, ModelCapability> right,
) {
  final normalizedLeft = _normalizedApiConfigCapabilitiesForCompare(left);
  final normalizedRight = _normalizedApiConfigCapabilitiesForCompare(right);
  if (normalizedLeft.length != normalizedRight.length) return false;
  for (final entry in normalizedLeft.entries) {
    final other = normalizedRight[entry.key];
    if (other == null ||
        other.isMultimodal != entry.value.isMultimodal ||
        other.isReasoning != entry.value.isReasoning) {
      return false;
    }
  }
  return true;
}

Map<String, ModelCapability> _normalizedApiConfigCapabilitiesForCompare(
  Map<String, ModelCapability> capabilities,
) {
  final normalized = <String, ModelCapability>{};
  for (final entry in capabilities.entries) {
    final key = normalizedModelId(entry.key);
    if (key.isEmpty) continue;
    normalized[key] = entry.value;
  }
  return normalized;
}
