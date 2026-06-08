import 'dart:convert';
import 'dart:math';

import 'package:uuid/uuid.dart';

import 'api_base_url.dart';
import 'api_failure_messages.dart';
import 'bool_value.dart';
import 'loose_key.dart';
import 'model_id.dart';
import 'presentation_text_helpers.dart';
import 'search_match.dart';
import 'text_cleaning.dart';
import 'text_truncation.dart';

part 'api_models.dart';
part 'api_config_json.dart';
part 'api_model_capability_keys.dart';
part 'api_model_capabilities.dart';
part 'api_model_capability_inference.dart';
part 'api_model_json.dart';
part 'api_model_metadata.dart';
part 'api_config_comparison.dart';
part 'api_readiness_models.dart';
part 'api_readiness_status.dart';
part 'appearance_json.dart';
part 'appearance_models.dart';
part 'settings_snapshot_models.dart';
part 'privacy_snapshot_models.dart';
part 'chat_input_models.dart';
part 'chat_reply_json.dart';
part 'chat_reply_models.dart';
part 'chat_style_collection_helpers.dart';
part 'chat_style_json.dart';
part 'chat_style_models.dart';
part 'generation_record_json.dart';
part 'generation_record_models.dart';
part 'model_collections.dart';
part 'model_json_decode_helpers.dart';
part 'model_json_helpers.dart';
part 'model_json_scalar_helpers.dart';
part 'model_json_string_helpers.dart';
part 'model_json_value_helpers.dart';
part 'model_natural_sort.dart';
part 'model_response_helpers.dart';
part 'model_source_helpers.dart';
part 'moment_profile_analysis_models.dart';
part 'person_profile_collection_helpers.dart';
part 'person_profile_field_keys.dart';
part 'person_profile_json_helpers.dart';
part 'person_profile_lifecycle.dart';
part 'person_profile_models.dart';
part 'person_profile_prompt_helpers.dart';
part 'personalization_json.dart';
part 'personalization_models.dart';
part 'reply_model_keys.dart';
part 'reply_models.dart';
part 'simulation_option_metric_json.dart';
part 'simulation_response_json.dart';
part 'simulation_model_keys.dart';
part 'simulation_metric_helpers.dart';
part 'simulation_response_models.dart';
part 'simulation_models.dart';
part 'text_date_helpers.dart';

enum ChatInputType { image, text }

String? cleanIdentifierText(String? value) => cleanNonEmptyText(value);
