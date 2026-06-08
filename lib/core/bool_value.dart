import 'text_cleaning.dart';

bool? boolValue(Object? raw) {
  if (raw is bool) return raw;
  if (raw is num) return raw != 0;
  final text = cleanNonEmptyText(raw?.toString())?.toLowerCase();
  if (text == null) return null;
  if (const [
    'true',
    '1',
    'yes',
    'y',
    'on',
    'enabled',
    'enable',
    'supported',
    'support',
    'available',
    'active',
    '是',
    '真'
  ].contains(text)) {
    return true;
  }
  if (const [
    'false',
    '0',
    'no',
    'n',
    'off',
    'disabled',
    'disable',
    'unsupported',
    'unsupport',
    'unavailable',
    'inactive',
    '否',
    '假',
  ].contains(text)) {
    return false;
  }
  return null;
}
