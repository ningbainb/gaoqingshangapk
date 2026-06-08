part of 'api_service.dart';

class _ApiJsonRequest {
  const _ApiJsonRequest({
    required this.chatBody,
    required this.responsesBody,
  });

  final Map<String, dynamic> chatBody;
  final Map<String, dynamic> responsesBody;
}

_ApiJsonRequest _textJsonRequest({
  required String model,
  required String systemPrompt,
  required String userPrompt,
  required num temperature,
  required int maxTokens,
}) =>
    _ApiJsonRequest(
      chatBody: {
        'model': model,
        'messages': [
          {'role': 'system', 'content': systemPrompt},
          {'role': 'user', 'content': userPrompt},
        ],
        'temperature': temperature,
        'max_tokens': maxTokens,
        'response_format': {'type': 'json_object'},
      },
      responsesBody: {
        'model': model,
        'input': [
          _responsesTextMessage('system', systemPrompt),
          _responsesTextMessage('user', userPrompt),
        ],
        'text': {
          'format': {'type': 'json_object'},
        },
        'temperature': temperature,
        'max_output_tokens': maxTokens,
        'store': false,
      },
    );

_ApiJsonRequest _imageJsonRequest({
  required String model,
  required String systemPrompt,
  required String userPrompt,
  required String imageDataUrl,
  required num temperature,
  required int maxTokens,
}) =>
    _ApiJsonRequest(
      chatBody: {
        'model': model,
        'messages': [
          {'role': 'system', 'content': systemPrompt},
          {
            'role': 'user',
            'content': [
              {'type': 'text', 'text': userPrompt},
              {
                'type': 'image_url',
                'image_url': {'url': imageDataUrl},
              },
            ],
          },
        ],
        'temperature': temperature,
        'max_tokens': maxTokens,
        'response_format': {'type': 'json_object'},
      },
      responsesBody: {
        'model': model,
        'input': [
          _responsesTextMessage('system', systemPrompt),
          {
            'role': 'user',
            'content': [
              {'type': 'input_text', 'text': userPrompt},
              {'type': 'input_image', 'image_url': imageDataUrl},
            ],
          },
        ],
        'text': {
          'format': {'type': 'json_object'},
        },
        'temperature': temperature,
        'max_output_tokens': maxTokens,
        'store': false,
      },
    );

Map<String, dynamic> _responsesTextMessage(String role, String text) => {
      'role': role,
      'content': [
        {'type': 'input_text', 'text': text},
      ],
    };
