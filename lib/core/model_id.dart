import 'text_cleaning.dart';

String cleanModelId(String modelId) => cleanNonEmptyText(modelId) ?? '';

String normalizedModelId(String modelId) => cleanModelId(modelId).toLowerCase();

bool modelIdsEqual(String left, String right) {
  final normalizedLeft = normalizedModelId(left);
  return normalizedLeft.isNotEmpty &&
      normalizedLeft == normalizedModelId(right);
}
