part of 'app_state.dart';

extension AppControllerGenerationHelpers on AppController {
  ChatInput _inputForRegeneration(ChatInput input) {
    final promptContext =
        _promptContextSnapshot(selectedProfileId: currentSelectedProfileId);
    return ChatInput(
      type: input.type,
      text: input.text,
      imagePayload: input.imagePayload,
      userGoal: input.userGoal,
      selectedStyle: input.selectedStyle,
      personProfileContext: promptContext.personProfileContext,
      personalizationContext: promptContext.personalizationContext,
    );
  }
}
