part of 'platform_routes.dart';

String? _normalizedExternalRoute(String? route) {
  return _normalizedExternalRouteInternal(route, 0);
}

String? _normalizedExternalRouteInternal(String? route, int depth) {
  final raw = _cleanRouteText(route);
  if (raw == null) return null;
  if (depth > 4) return null;

  final uri = Uri.tryParse(raw);
  if (uri != null) {
    if (uri.scheme.isNotEmpty) {
      if (uri.scheme.toLowerCase() != 'aichathelper') return null;
      final queryRoute = _externalRouteQuery(uri);
      final parts = <String>[
        if (_cleanRouteText(uri.host) case final host?) host,
        ...uri.pathSegments.map(_cleanRouteText).whereType<String>(),
      ];
      final pathRoute = normalizedRoutePathToken(parts.join('/'));
      if (queryRoute != null) {
        if (pathRoute == null || _isExternalRouteWrapper(pathRoute)) {
          return _normalizedExternalRouteInternal(queryRoute, depth + 1);
        }
        if (_isExternalRouteContainer(pathRoute)) {
          return _normalizedExternalRouteInternal(
            '$pathRoute/$queryRoute',
            depth + 1,
          );
        }
      }
      return pathRoute ??
          _normalizedExternalRouteInternal(queryRoute, depth + 1);
    }
    if (_cleanRouteText(uri.path) case final path?) {
      return normalizedRoutePathToken(path);
    }
  }

  return normalizedRoutePathToken(raw);
}

String? _externalRouteQuery(Uri uri) {
  for (final entry in uri.queryParameters.entries) {
    if (!_externalRouteQueryAliases.contains(normalizedLooseKey(entry.key))) {
      continue;
    }
    final value = _cleanRouteText(entry.value);
    if (value != null) return value;
  }
  return null;
}

String? _cleanRouteText(String? value) => cleanNonEmptyText(value);

bool _isExternalRouteWrapper(String? route) {
  final normalized = route == null ? null : normalizedRoutePathToken(route);
  return normalized != null && _externalRouteWrappers.contains(normalized);
}

bool _isExternalRouteContainer(String? route) {
  final normalized = route == null ? null : normalizedRoutePathToken(route);
  return normalized != null && _externalRouteContainers.contains(normalized);
}
