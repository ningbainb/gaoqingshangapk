part of 'api_service.dart';

bool usesResponsesApiEndpoint(Uri base) =>
    _hasPathSuffix(_trimApiPath(base.path), 'responses');

Uri openAIEndpointUrl(Uri base) {
  final path = _trimApiPath(base.path);
  if (_hasPathSuffix(path, 'responses') ||
      _hasPathSuffix(path, 'chat/completions')) {
    return _withApiPath(base, path.isEmpty ? '/' : path);
  }
  return _withJoinedPath(base, 'chat/completions');
}

Uri chatCompletionsUrlFromResponses(Uri base) {
  final path = _removePathSuffix(_trimApiPath(base.path), 'responses');
  return _withApiPath(base, _joinPath(path, 'chat/completions'));
}

Uri openAIModelsUrl(Uri base) {
  var path = _trimApiPath(base.path);
  for (final suffix in const ['chat/completions', 'responses', 'models']) {
    path = _removePathSuffix(path, suffix);
  }
  return _withApiPath(base, _joinPath(path, 'models'));
}

Uri _withJoinedPath(Uri base, String suffix) =>
    _withApiPath(base, _joinPath(_trimApiPath(base.path), suffix));

Uri _withApiPath(Uri base, String path) {
  if (base.hasPort) {
    return Uri(
      scheme: base.scheme,
      userInfo: base.userInfo,
      host: base.host,
      port: base.port,
      path: path,
    );
  }
  return Uri(
    scheme: base.scheme,
    userInfo: base.userInfo,
    host: base.host,
    path: path,
  );
}

String _trimApiPath(String path) =>
    path.replaceAll(RegExp(r'/+'), '/').replaceAll(RegExp(r'/+$'), '');

String _joinPath(String basePath, String suffix) {
  if (basePath.isEmpty || basePath == '/') return '/$suffix';
  return '$basePath/$suffix';
}

bool _hasPathSuffix(String path, String suffix) {
  final normalized = path.startsWith('/') ? path.substring(1) : path;
  return normalized == suffix || normalized.endsWith('/$suffix');
}

String _removePathSuffix(String path, String suffix) {
  if (!_hasPathSuffix(path, suffix)) return path;
  final next = path.substring(0, path.length - suffix.length);
  return next.replaceAll(RegExp(r'/+$'), '');
}
