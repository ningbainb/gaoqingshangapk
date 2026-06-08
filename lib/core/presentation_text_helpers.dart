import 'text_cleaning.dart';

String? cleanPresentationText(String? value) {
  final trimmed = cleanNonEmptyText(value);
  if (trimmed == null || trimmed == '未知') return null;
  return trimmed;
}

List<String> cleanPresentationList(Iterable<String>? values) =>
    values?.map(cleanPresentationText).whereType<String>().toList() ?? const [];

List<String> uniqueCleanPresentationList(
  Iterable<String?> values, {
  int? limit,
}) {
  final result = <String>[];
  final seen = <String>{};
  for (final value in values) {
    final cleaned = cleanPresentationText(value);
    if (cleaned == null) continue;
    if (seen.add(cleaned.toLowerCase())) result.add(cleaned);
    if (limit != null && result.length >= limit) break;
  }
  return result;
}

List<T> uniqueByCleanPresentationText<T>(
  Iterable<T> values, {
  required T Function(T value) normalize,
  required String? Function(T value) text,
  int? limit,
}) {
  final result = <T>[];
  final seen = <String>{};
  for (final value in values) {
    final normalized = normalize(value);
    final cleaned = cleanPresentationText(text(normalized));
    if (cleaned == null || !seen.add(cleaned.toLowerCase())) continue;
    result.add(normalized);
    if (limit != null && result.length >= limit) break;
  }
  return result;
}
