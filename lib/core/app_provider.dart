import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_state.dart';

final appProvider = ChangeNotifierProvider<AppController>((ref) {
  final controller = AppController();
  controller.load();
  return controller;
});
