import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_shell.dart';

export 'app_shell.dart';
export 'core/app_feedback.dart';
export 'core/app_provider.dart';
export 'core/app_routes.dart';
export 'core/generation_flow.dart';
export 'core/generation_goal_helpers.dart';
export 'core/presentation_helpers.dart';
export 'core/quick_reply_flow.dart';
export 'screens/api_settings_screen.dart';
export 'screens/history_detail_screen.dart';
export 'screens/history_people_screens.dart';
export 'screens/floating_guide_screen.dart';
export 'screens/home_screen.dart';
export 'screens/image_generation_screens.dart';
export 'screens/moment_profile_screen.dart';
export 'screens/personalization_screen.dart';
export 'screens/privacy_screen.dart';
export 'screens/profile_screens.dart';
export 'screens/result_screen.dart';
export 'screens/settings_screen.dart';
export 'screens/simulation_screens.dart';
export 'screens/text_input_screen.dart';
export 'widgets/glass_scaffold.dart';
export 'widgets/glass_widgets.dart';
export 'widgets/generate_image_shell.dart';
export 'widgets/history_people_widgets.dart';
export 'widgets/image_input_widgets.dart';
export 'widgets/profile_widgets.dart';
export 'widgets/privacy_widgets.dart';
export 'widgets/result_widgets.dart';
export 'widgets/settings_cards.dart';
export 'widgets/simulation_widgets.dart';
export 'widgets/text_input_widgets.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: AIReplyApp()));
}
