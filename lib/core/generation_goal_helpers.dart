import 'presentation_text_helpers.dart';

String sanitizedGoal(String value) {
  return cleanPresentationText(value) ?? '';
}

String? optionalSanitizedGoal(String? value) {
  if (value == null) return null;
  final goal = sanitizedGoal(value);
  return goal.isEmpty ? null : goal;
}
