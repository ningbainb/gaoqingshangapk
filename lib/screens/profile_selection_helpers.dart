import '../core/app_state.dart';
import '../core/models.dart';

PersonProfile? selectedScreenProfile(
  List<PersonProfile> profiles,
  String? selectedProfileId,
) {
  return personProfileById(profiles, selectedProfileId);
}

String? restorableScreenProfileId(AppController app) {
  return restorablePersonProfileId(
    app.profiles,
    app.currentSelectedProfileId,
  );
}
