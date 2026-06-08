part of 'models.dart';

bool? _boolValue(Object? raw) {
  return boolValue(raw);
}

double? _doubleValue(Object? raw) {
  if (raw is num) return raw.toDouble();
  final text = _scalarTextValue(raw);
  return text == null ? null : double.tryParse(text);
}

double _boundedDouble(Object? raw,
    {required double fallback, required double min, required double max}) {
  final value = _doubleValue(raw);
  if (value == null || !value.isFinite) return fallback;
  return value.clamp(min, max).toDouble();
}

int _boundedInt(Object? raw,
    {required int fallback, required int min, required int max}) {
  final value = _intValue(raw);
  if (value == null) return fallback;
  return value.clamp(min, max);
}

DateTime? _dateTimeValue(Object? raw) {
  if (raw == null) return null;
  if (raw is DateTime) return raw;
  if (raw is num) return _dateTimeFromNumber(raw.toDouble());

  final text = _scalarTextValue(raw);
  if (text == null) return null;
  final parsed = DateTime.tryParse(text);
  if (parsed != null) return parsed;
  final numeric = double.tryParse(text);
  return numeric == null ? null : _dateTimeFromNumber(numeric);
}

DateTime? _dateTimeFromNumber(double value) {
  if (!value.isFinite) return null;
  if (value.abs() > 100000000000) {
    return DateTime.fromMillisecondsSinceEpoch(value.round());
  }
  if (value.abs() >= 1000000000) {
    return DateTime.fromMillisecondsSinceEpoch((value * 1000).round());
  }
  const appleReferenceUnixOffsetSeconds = 978307200;
  final unixSeconds = value + appleReferenceUnixOffsetSeconds;
  return DateTime.fromMillisecondsSinceEpoch((unixSeconds * 1000).round());
}

int? _intValue(Object? raw) {
  if (raw is num) return raw.toInt();
  final text = _scalarTextValue(raw);
  return text == null ? null : int.tryParse(text);
}

String? _scalarTextValue(Object? raw) => cleanNonEmptyText(raw?.toString());

double _doubleInRange(Object? raw, {required double fallback}) {
  final text = _scalarTextValue(raw);
  final value = raw is num
      ? raw.toDouble()
      : text == null
          ? null
          : double.tryParse(text);
  return (value ?? fallback).clamp(0, 1).toDouble();
}

int _firstScore(Map<String, dynamic> json, List<String> keys,
        {required int fallback, Map<String, dynamic>? secondary}) =>
    _firstOptionalScore(json, keys, secondary: secondary) ?? fallback;

int? _firstOptionalScore(Map<String, dynamic> json, List<String> keys,
    {Map<String, dynamic>? secondary}) {
  for (final source in [json, if (secondary != null) secondary]) {
    for (final key in keys) {
      final value = _optionalScore(_valueForKey(source, key));
      if (value != null) return value;
    }
  }
  return null;
}

int? _optionalScore(Object? raw) {
  final text = _scalarTextValue(raw);
  final value = raw is num
      ? raw.toInt()
      : text == null
          ? null
          : int.tryParse(text);
  return value?.clamp(0, 100);
}
