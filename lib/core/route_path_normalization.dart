import 'text_cleaning.dart';

String? normalizedRoutePathToken(String path) {
  final decoded = _decodeRoutePathToken(path);
  final trimmed = cleanNonEmptyText(decoded)
      ?.replaceAll(
        RegExp(r'^/+|/+$'),
        '',
      )
      .replaceAll(RegExp(r'/+'), '/');
  if (trimmed == null || trimmed.isEmpty) return null;
  final separated = trimmed
      .replaceAllMapped(
        RegExp(r'([a-z0-9])([A-Z])'),
        (match) => '${match.group(1)}-${match.group(2)}',
      )
      .replaceAll(RegExp(r'[_\s]+'), '-');
  final normalized = separated.toLowerCase();
  return normalized.isEmpty ? null : normalized;
}

String _decodeRoutePathToken(String path) {
  try {
    return Uri.decodeComponent(path);
  } catch (_) {
    return path;
  }
}
