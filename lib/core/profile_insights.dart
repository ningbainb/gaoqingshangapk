import 'models.dart';
import 'presentation_text_helpers.dart';

class ProfileUpsertResult {
  const ProfileUpsertResult({
    required this.profiles,
    required this.savedProfile,
  });

  final List<PersonProfile> profiles;
  final PersonProfile? savedProfile;
}

ProfileUpsertResult upsertPersonInsight({
  required List<PersonProfile> profiles,
  required PersonInsight insight,
  required String? sceneSummary,
}) {
  final name = cleanPresentationText(insight.displayName);
  final updatedProfiles = List<PersonProfile>.of(profiles);
  final aliases = cleanPresentationList(insight.aliases);
  final index = updatedProfiles.indexWhere(
    (profile) => personProfileMatchesInsight(profile, insight),
  );

  if (index >= 0) {
    final updated = updatedProfiles[index].merged(insight, sceneSummary);
    updatedProfiles[index] = updated;
    return ProfileUpsertResult(
      profiles: updatedProfiles,
      savedProfile: updated,
    );
  }

  if (name == null) {
    return ProfileUpsertResult(
      profiles: profiles,
      savedProfile: null,
    );
  }

  final profile = PersonProfile(
    displayName: name,
    aliases: aliases,
    relationship: cleanPresentationText(insight.relationship),
    communicationStyle: cleanPresentationText(insight.communicationStyle),
    personalityTraits: cleanPresentationList(insight.personalityTraits),
    innerNeeds: cleanPresentationList(insight.innerNeeds),
    keyPersonPoints: cleanPresentationList(insight.keyPersonPoints),
    momentsInsights: cleanPresentationList(insight.momentsInsights),
    tonePreferences: cleanPresentationList(insight.tonePreferences),
    boundaries: cleanPresentationList(insight.boundaries),
    facts: cleanPresentationList(insight.facts),
    lastSceneSummary: cleanPresentationText(sceneSummary),
    lastUpdateReason: cleanPresentationText(insight.updateReason),
    confidence: (insight.confidence ?? 0.4).clamp(0, 1).toDouble(),
  );
  updatedProfiles.insert(0, profile);
  return ProfileUpsertResult(
    profiles: updatedProfiles,
    savedProfile: profile,
  );
}

PersonInsight momentInsightForTarget(
    MomentProfileAnalysis analysis, PersonProfile? target) {
  final insight = analysis.personInsight;
  if (target == null) {
    return cleanPresentationText(insight.displayName) == null
        ? PersonInsight(
            displayName: '朋友圈对象',
            aliases: insight.aliases,
            relationship: insight.relationship,
            communicationStyle: insight.communicationStyle,
            personalityTraits: insight.personalityTraits,
            innerNeeds: insight.innerNeeds,
            keyPersonPoints: insight.keyPersonPoints,
            momentsInsights: insight.momentsInsights,
            tonePreferences: insight.tonePreferences,
            boundaries: insight.boundaries,
            facts: insight.facts,
            confidence: insight.confidence,
            updateReason: insight.updateReason,
          )
        : insight;
  }

  final visibleName = cleanPresentationText(insight.displayName);
  return PersonInsight(
    displayName: target.displayName,
    aliases: uniqueCleanPresentationList([
      ...?insight.aliases,
      target.displayName,
      ...target.aliases,
      if (visibleName != null && visibleName != target.displayName) visibleName,
    ]),
    relationship:
        cleanPresentationText(insight.relationship) ?? target.relationship,
    communicationStyle: insight.communicationStyle,
    personalityTraits: insight.personalityTraits,
    innerNeeds: insight.innerNeeds,
    keyPersonPoints: insight.keyPersonPoints,
    momentsInsights: insight.momentsInsights,
    tonePreferences: insight.tonePreferences,
    boundaries: insight.boundaries,
    facts: insight.facts,
    confidence: insight.confidence,
    updateReason: insight.updateReason,
  );
}
