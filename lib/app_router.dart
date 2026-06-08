import 'package:go_router/go_router.dart';

import 'core/app_routes.dart';
import 'screens/api_settings_screen.dart';
import 'screens/floating_guide_screen.dart';
import 'screens/history_detail_screen.dart';
import 'screens/history_people_screens.dart';
import 'screens/home_screen.dart';
import 'screens/image_generation_screens.dart';
import 'screens/moment_profile_screen.dart';
import 'screens/personalization_screen.dart';
import 'screens/privacy_screen.dart';
import 'screens/profile_screens.dart';
import 'screens/result_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/simulation_screens.dart';
import 'screens/text_input_screen.dart';

GoRouter buildAIReplyRouter() {
  return GoRouter(
    routes: [
      GoRoute(
          path: AppRoutes.home,
          builder: (context, state) => const HomeScreen()),
      GoRoute(
          path: AppRoutes.image,
          builder: (context, state) => const ImageInputScreen()),
      GoRoute(
          path: AppRoutes.screenshot,
          builder: (context, state) => const ImageInputScreen()),
      GoRoute(
          path: AppRoutes.quick,
          builder: (context, state) => const QuickReplyScreen()),
      GoRoute(
          path: AppRoutes.quickImage,
          builder: (context, state) => const QuickReplyScreen()),
      GoRoute(
          path: AppRoutes.text,
          builder: (context, state) => const TextInputScreen()),
      GoRoute(
          path: AppRoutes.result,
          builder: (context, state) => const ResultScreen()),
      GoRoute(
          path: AppRoutes.history,
          builder: (context, state) => const HistoryScreen()),
      GoRoute(
          path: AppRoutes.historyDetail,
          builder: (context, state) => const HistoryDetailScreen()),
      GoRoute(
          path: AppRoutes.people,
          builder: (context, state) => const PeopleScreen()),
      GoRoute(
          path: AppRoutes.personLibrary,
          builder: (context, state) => const PeopleScreen()),
      GoRoute(
          path: AppRoutes.peopleDetail,
          builder: (context, state) => const ProfileDetailScreen()),
      GoRoute(
          path: AppRoutes.peopleEdit,
          builder: (context, state) => const ProfileEditorScreen()),
      GoRoute(
          path: AppRoutes.peopleSelectSimulation,
          builder: (context, state) => const SimulationProfileSelectScreen()),
      GoRoute(
          path: AppRoutes.simulation,
          builder: (context, state) => const SimulationScreen()),
      GoRoute(
          path: AppRoutes.moments,
          builder: (context, state) => const MomentProfileScreen()),
      GoRoute(
          path: AppRoutes.settings,
          builder: (context, state) => const SettingsScreen()),
      GoRoute(
          path: AppRoutes.floatingGuide,
          builder: (context, state) => const FloatingGuideScreen()),
      GoRoute(
          path: AppRoutes.api,
          builder: (context, state) => const ApiSettingsScreen()),
      GoRoute(
          path: AppRoutes.apiSettings,
          builder: (context, state) => const ApiSettingsScreen()),
      GoRoute(
          path: AppRoutes.personalization,
          builder: (context, state) => const PersonalizationScreen()),
      GoRoute(
          path: AppRoutes.privacy,
          builder: (context, state) => const PrivacyScreen()),
    ],
  );
}
