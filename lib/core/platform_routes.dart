import 'app_routes.dart';
import 'loose_key.dart';
import 'route_path_normalization.dart';
import 'text_cleaning.dart';

part 'platform_route_aliases.dart';
part 'platform_route_normalization.dart';

const quickShortcutUrl = 'aichathelper://quick-image';

String? appPathForExternalRoute(String? route) {
  final normalized = _normalizedExternalRoute(route);
  if (normalized == null) return null;
  return _externalRoutePathByAlias[normalized];
}

bool isQuickExternalRoute(String? route) =>
    appPathForExternalRoute(route) == AppRoutes.quick;

bool isImageExternalRoute(String? route) =>
    appPathForExternalRoute(route) == AppRoutes.image;

bool isTextExternalRoute(String? route) =>
    appPathForExternalRoute(route) == AppRoutes.text;

bool isNewProfileExternalRoute(String? route) =>
    appPathForExternalRoute(route) == AppRoutes.peopleEdit;
