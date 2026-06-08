import 'package:flutter/foundation.dart';

import 'app_feedback.dart';
import 'app_state.dart';
import 'history_record_collection_helpers.dart';
import 'models.dart';
import 'presentation_text_helpers.dart';

bool canSubmitTextGeneration({
  required GenerateAPIReadiness readiness,
  required bool isBusy,
  required String text,
}) =>
    readiness.isReady && !isBusy && hasUsableChatText(text);

bool canSubmitImageGeneration({
  required GenerateAPIReadiness readiness,
  required bool isBusy,
  required String? imagePath,
  required VoidCallback? onGenerate,
}) =>
    readiness.isReady &&
    !isBusy &&
    hasUsableImagePath(imagePath) &&
    onGenerate != null;

bool canSubmitMomentProfileAnalysis({
  required GenerateAPIReadiness readiness,
  required bool isBusy,
  required String? imagePath,
}) =>
    readiness.isReady && !isBusy && hasUsableImagePath(imagePath);

String? resultCopiedTextFor(
  AppController app,
  ChatReplyResponse? response,
  String? localCopiedText,
) {
  if (response == null) return null;
  final replyTexts = response.replies
      .map((reply) => cleanPresentationText(reply.text))
      .whereType<String>()
      .toSet();
  if (replyTexts.isEmpty) return null;

  final local = cleanPresentationText(localCopiedText);
  if (local != null && replyTexts.contains(local)) return local;

  final recordId = app.currentRecordId;
  if (recordId == null) return null;
  for (final record in app.history) {
    if (!historyRecordIdsMatch(record.id, recordId)) continue;
    final copied = record.cleanCopiedReply;
    if (copied != null && replyTexts.contains(copied)) return copied;
    return null;
  }
  return null;
}
