import 'dart:convert';
import 'dart:math';

import 'package:dio/dio.dart';

import 'models.dart';
import 'presentation_text_helpers.dart';
import 'prompts.dart';
import 'app_feedback.dart';
import 'api_failure_messages.dart';
import 'connection_interruption.dart';
import 'error_response_message.dart';
import 'loose_key.dart';
import 'text_cleaning.dart';
import 'text_truncation.dart';

part 'api_parsing.dart';
part 'api_endpoints.dart';
part 'api_errors.dart';
part 'api_chat_content_parsing.dart';
part 'api_connection_tests.dart';
part 'api_content_text_helpers.dart';
part 'api_model_items.dart';
part 'api_model_fetching.dart';
part 'api_profile_analysis.dart';
part 'api_reply_array_fallback.dart';
part 'api_reply_fallback.dart';
part 'api_reply_text_fallback.dart';
part 'api_reply_generation.dart';
part 'api_request_bodies.dart';
part 'api_responses_content_parsing.dart';
part 'api_send.dart';
part 'api_simulation_turn.dart';
part 'api_simulation_fallback.dart';
part 'api_transport.dart';
part 'api_vision_extraction.dart';
part 'api_vision_extraction_text.dart';

class AppException implements Exception {
  AppException(this.message);
  final String message;
  @override
  String toString() => message;
}

class OpenAICompatibleApi {
  OpenAICompatibleApi({Dio Function(APIConfig config)? dioFactory})
      : _dioFactory = dioFactory;

  final Dio Function(APIConfig config)? _dioFactory;

  Future<List<APIModel>> fetchModels(APIConfig config, String apiKey) =>
      _fetchModels(config, apiKey);

  Future<ChatReplyResponse> generateReply(
          ChatInput input, APIConfig config, String apiKey) =>
      _generateReply(input, config, apiKey);

  Future<ChatReplyResponse> generateReplyFromImage(
          ImagePayload image,
          ChatStyle style,
          String? goal,
          String? personContext,
          String? personalization,
          APIConfig config,
          String apiKey) =>
      _generateReplyFromImage(
        image,
        style,
        goal,
        personContext,
        personalization,
        config,
        apiKey,
      );

  Future<ChatReplyResponse> generateReplyFromText(
          String text,
          ChatStyle style,
          String? goal,
          String? personContext,
          String? personalization,
          APIConfig config,
          String apiKey) =>
      _generateReplyFromText(
        text,
        style,
        goal,
        personContext,
        personalization,
        config,
        apiKey,
      );

  Future<void> testConnection(APIConfig config, String apiKey) =>
      _testConnection(config, apiKey);

  Future<void> testVisionConnection(APIConfig config, String apiKey) =>
      _testVisionConnection(config, apiKey);

  Future<MomentProfileAnalysis> analyzeMomentScreenshot(ImagePayload image,
          String? personContext, APIConfig config, String apiKey) =>
      _analyzeMomentScreenshot(image, personContext, config, apiKey);

  Future<SimulationTurnResponse> runSimulationTurn({
    required PersonProfile profile,
    required SimulationScenario scenario,
    required List<SimulationMessage> history,
    required String? userReply,
    required String personalizationContext,
    required APIConfig config,
    required String apiKey,
  }) =>
      _runSimulationTurn(
        profile: profile,
        scenario: scenario,
        history: history,
        userReply: userReply,
        personalizationContext: personalizationContext,
        config: config,
        apiKey: apiKey,
      );
}

int _replyOutputTokenLimit(APIConfig config) =>
    config.maxTokens < 1800 ? 1800 : config.maxTokens;
