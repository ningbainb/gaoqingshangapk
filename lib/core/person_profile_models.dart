part of 'models.dart';

class PersonProfile {
  PersonProfile({
    String? id,
    required this.displayName,
    this.aliases = const [],
    this.relationship,
    this.communicationStyle,
    this.personalityTraits = const [],
    this.innerNeeds = const [],
    this.keyPersonPoints = const [],
    this.momentsInsights = const [],
    this.tonePreferences = const [],
    this.boundaries = const [],
    this.facts = const [],
    this.lastSceneSummary,
    this.lastUpdateReason,
    this.confidence = 0.4,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : id = id ?? _uuid.v4(),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  final String id;
  final String displayName;
  final List<String> aliases;
  final String? relationship;
  final String? communicationStyle;
  final List<String> personalityTraits;
  final List<String> innerNeeds;
  final List<String> keyPersonPoints;
  final List<String> momentsInsights;
  final List<String> tonePreferences;
  final List<String> boundaries;
  final List<String> facts;
  final String? lastSceneSummary;
  final String? lastUpdateReason;
  final double confidence;
  final DateTime createdAt;
  final DateTime updatedAt;

  String get summaryForPrompt => _personProfileSummaryForPrompt(this);

  PersonProfile merged(PersonInsight insight, String? sceneSummary) =>
      _mergedPersonProfile(this, insight, sceneSummary);

  PersonProfile normalized({DateTime? updatedAt}) =>
      _normalizedPersonProfile(this, updatedAt: updatedAt);

  PersonProfile touch({DateTime? updatedAt}) => _normalizedPersonProfile(
        this,
        updatedAt: updatedAt ?? DateTime.now(),
      );

  factory PersonProfile.fromJson(Map<String, dynamic> json) =>
      _personProfileFromJson(json);

  Map<String, dynamic> toJson() => _personProfileToJson(this);
}
