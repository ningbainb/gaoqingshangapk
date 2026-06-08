import 'loose_key.dart';
import 'text_cleaning.dart';

bool textMatchesSearchQuery(String text, String query) {
  final trimmedQuery = cleanNonEmptyText(query);
  if (trimmedQuery == null) return true;
  final lowerText = text.toLowerCase();
  final lowerQuery = trimmedQuery.toLowerCase();
  if (lowerText.contains(lowerQuery)) return true;
  final looseQuery = normalizedLooseKey(trimmedQuery);
  if (looseQuery.isEmpty) return false;
  return normalizedLooseKey(text).contains(looseQuery);
}
