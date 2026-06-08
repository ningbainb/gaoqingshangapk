part of 'models.dart';

int localizedStandardLikeCompare(String left, String right) {
  final leftParts = _naturalSortParts(cleanModelId(left));
  final rightParts = _naturalSortParts(cleanModelId(right));
  final length = min(leftParts.length, rightParts.length);
  for (var index = 0; index < length; index += 1) {
    final comparison = leftParts[index].compareTo(rightParts[index]);
    if (comparison != 0) return comparison;
  }
  final lengthComparison = leftParts.length.compareTo(rightParts.length);
  if (lengthComparison != 0) return lengthComparison;
  return left.compareTo(right);
}

List<_NaturalSortPart> _naturalSortParts(String value) {
  final matches = RegExp(r'\d+|\D+').allMatches(value);
  return matches.map((match) {
    final text = match.group(0) ?? '';
    final number = int.tryParse(text);
    return number == null
        ? _NaturalSortPart.text(text.toLowerCase())
        : _NaturalSortPart.number(number, text.length);
  }).toList();
}

class _NaturalSortPart {
  const _NaturalSortPart.text(this.text)
      : number = null,
        digitLength = null;

  const _NaturalSortPart.number(this.number, this.digitLength) : text = null;

  final String? text;
  final int? number;
  final int? digitLength;

  int compareTo(_NaturalSortPart other) {
    final leftNumber = number;
    final rightNumber = other.number;
    if (leftNumber != null && rightNumber != null) {
      final numberComparison = leftNumber.compareTo(rightNumber);
      if (numberComparison != 0) return numberComparison;
      return (digitLength ?? 0).compareTo(other.digitLength ?? 0);
    }
    if (leftNumber != null) return -1;
    if (rightNumber != null) return 1;
    return (text ?? '').compareTo(other.text ?? '');
  }
}
