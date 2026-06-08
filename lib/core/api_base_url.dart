import 'text_cleaning.dart';

Uri? normalizedApiBaseUri(String value) {
  final trimmed = cleanNonEmptyText(value);
  if (trimmed == null) return null;
  final uri = Uri.tryParse(trimmed);
  if (uri == null) return null;
  final path = _normalizedApiBasePath(uri.path);
  if (uri.hasPort) {
    return Uri(
      scheme: uri.scheme,
      userInfo: uri.userInfo,
      host: uri.host,
      port: uri.port,
      path: path,
    );
  }
  return Uri(
    scheme: uri.scheme,
    userInfo: uri.userInfo,
    host: uri.host,
    path: path,
  );
}

String? canonicalApiBaseUrl(String value) {
  final uri = normalizedApiBaseUri(value);
  if (uri == null ||
      cleanNonEmptyText(uri.scheme) == null ||
      cleanNonEmptyText(uri.host) == null) {
    return null;
  }
  return uri
      .replace(
        scheme: uri.scheme.toLowerCase(),
        host: uri.host.toLowerCase(),
      )
      .toString();
}

String _normalizedApiBasePath(String path) =>
    path.replaceAll(RegExp(r'/+'), '/').replaceAll(RegExp(r'/+$'), '');
