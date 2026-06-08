part of 'api_service.dart';

const _modelListContainerKeys = [
  'data',
  'result',
  'response',
  'payload',
  'models',
  'items',
  'list',
  'rows',
  'records',
  'entries',
  'model_list',
  'modelList',
];

const _indexedModelItemIdKeys = [
  'id',
  'name',
  'model',
  'modelId',
  'modelName',
  'identifier',
  'uid',
  'slug',
  'value',
];

List<dynamic> _modelItems(Object? data) {
  if (data is List) return data;
  if (data is! Map) return const [];
  for (final key in _modelListContainerKeys) {
    final value = _valueForKey(data, key);
    if (value is List && value.isNotEmpty) return value;
    if (value is Map) {
      final nested = _modelItems(value);
      if (nested.isNotEmpty) return nested;
      final mapped = _modelItemsFromMapEntries(value);
      if (mapped.isNotEmpty) return mapped;
    }
  }
  return _modelItemsFromMapEntries(data);
}

List<dynamic> _modelItemsFromMapEntries(Map<dynamic, dynamic> data) {
  final items = <Map<String, dynamic>>[];
  for (final entry in data.entries) {
    final id = cleanIdentifierText(entry.key?.toString());
    if (id == null || entry.value is! Map || !_looksLikeModelMapKey(id)) {
      continue;
    }
    final item = (entry.value as Map)
        .map((key, value) => MapEntry(key.toString(), value));
    _ensureIndexedModelId(item, id);
    items.add(item);
  }
  return items;
}

void _ensureIndexedModelId(Map<String, dynamic> item, String id) {
  for (final key in _indexedModelItemIdKeys) {
    if (cleanIdentifierText(_valueForKey(item, key)?.toString()) != null) {
      return;
    }
  }
  item['id'] = id;
}

bool _looksLikeModelMapKey(String id) {
  final normalized = id.toLowerCase();
  if (normalized.isEmpty) return false;
  if (const {
    'object',
    'meta',
    'metadata',
    'pagination',
    'paging',
    'count',
    'total',
    'limit',
    'offset',
    'page',
    'pages',
    'next',
    'previous',
    'requestid',
    'status',
    'message',
    'error',
  }.contains(normalized.replaceAll(RegExp(r'[^a-z0-9]+'), ''))) {
    return false;
  }
  if (RegExp(r'[0-9]').hasMatch(normalized)) return true;
  if (RegExp(r'[-_./:]').hasMatch(id)) return true;
  return const [
    'gpt',
    'claude',
    'gemini',
    'qwen',
    'llama',
    'mistral',
    'deepseek',
    'glm',
    'moonshot',
    'kimi',
    'doubao',
    'ernie',
    'grok',
  ].any(normalized.contains);
}

APIModel _apiModelFromItem(Object? item) {
  if (item is Map) {
    return APIModel.fromJson(Map<String, dynamic>.from(item));
  }
  return APIModel(id: cleanIdentifierText(item?.toString()) ?? '');
}
