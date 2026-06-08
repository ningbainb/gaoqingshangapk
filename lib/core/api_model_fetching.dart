part of 'api_service.dart';

extension _OpenAICompatibleApiModelFetching on OpenAICompatibleApi {
  Future<List<APIModel>> _fetchModels(
    APIConfig config,
    String apiKey,
  ) async {
    final base = _base(config);
    _requireKey(apiKey);
    final url = _modelsUrl(base);
    final response = await _fetchModelsResponse(config, apiKey, url);
    final list = _modelItems(response.data);
    return list.map(_apiModelFromItem).where((e) => e.id.isNotEmpty).toList()
      ..sort((a, b) => localizedStandardLikeCompare(a.id, b.id));
  }
}
