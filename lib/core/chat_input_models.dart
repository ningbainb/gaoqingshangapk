part of 'models.dart';

class ImagePayload {
  const ImagePayload({
    required this.base64,
    required this.mimeType,
    required this.width,
    required this.height,
    required this.sizeInBytes,
  });

  final String base64;
  final String mimeType;
  final int width;
  final int height;
  final int sizeInBytes;

  String get dataURL => 'data:$mimeType;base64,$base64';
}

class ChatInput {
  const ChatInput({
    required this.type,
    this.text,
    this.imagePayload,
    this.userGoal,
    required this.selectedStyle,
    this.personProfileContext,
    this.personalizationContext,
  });

  final ChatInputType type;
  final String? text;
  final ImagePayload? imagePayload;
  final String? userGoal;
  final ChatStyle selectedStyle;
  final String? personProfileContext;
  final String? personalizationContext;
}
