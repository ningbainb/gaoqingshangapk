import 'package:characters/characters.dart';

int visibleTextLength(String value) => value.characters.length;

String truncateVisibleText(
  String value, {
  required int maxCharacters,
  String omission = '',
}) {
  if (maxCharacters <= 0) return '';
  final characters = value.characters;
  if (characters.length <= maxCharacters) return value;
  return '${characters.take(maxCharacters)}$omission';
}
