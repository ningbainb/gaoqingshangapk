part of 'models.dart';

class SimulationTurnResponse {
  const SimulationTurnResponse({
    required this.personaMessage,
    this.sceneState = '对话正在进行中。',
    this.favorability = 55,
    this.tension = 40,
    this.trust = 55,
    this.interest = 55,
    this.metrics = const [],
    this.options = const [],
    this.userScore,
    this.feedback,
    this.betterReply,
    this.coachTip = '下一轮可以更具体地接住对方情绪。',
  });

  final String personaMessage;
  final String sceneState;
  final int favorability;
  final int tension;
  final int trust;
  final int interest;
  final List<SimulationMetric> metrics;
  final List<SimulationOption> options;
  final int? userScore;
  final String? feedback;
  final String? betterReply;
  final String coachTip;

  factory SimulationTurnResponse.fromJson(Map<String, dynamic> json) =>
      _simulationTurnResponseFromJson(json);

  SimulationTurnResponse normalized() =>
      SimulationTurnResponse.fromJson(toJson());

  Map<String, dynamic> toJson() => _simulationTurnResponseToJson(this);
}
