import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class AiChatService {
  // ignore: non_constant_identifier_names
  static const String system_prompt =
      'You are Healthy Life AI, a professional health and nutrition assistant. You must ground all your advice in reputable, science-based medical sources (such as WHO, CDC, NIH, or peer-reviewed medical journals). Refuse to diagnose illnesses and always advise users to see a certified doctor for serious conditions. If the user asks about topics unrelated to health, nutrition, or fitness, politely decline to answer and guide them back to health topics. Maintain a polite, empathetic, and professional tone.';

  static const String _fallbackMessage =
      'Sorry, I am unable to respond right now. Please try again in a moment.';

  static const String _temporaryUnavailableMessage =
      'The AI service is currently busy. Please try again in a moment.';

  final String _model;

  const AiChatService({String model = 'gemini-2.5-flash'}) : _model = model;

  String _buildPrompt(String userMessage) {
    return '''
$system_prompt

User message:
$userMessage
''';
  }

  String _buildErrorMessage(int statusCode, String body) {
    if (statusCode == 429 ||
        statusCode == 500 ||
        statusCode == 502 ||
        statusCode == 503 ||
        statusCode == 504) {
      return _temporaryUnavailableMessage;
    }

    if (statusCode == 401 || statusCode == 403) {
      return 'Authentication error. Please check API configuration.';
    }

    if (statusCode == 400) {
      return 'Invalid request sent to AI service.';
    }

    return _fallbackMessage;
  }

  Future<String> sendMessage(String userMessage) async {
    final String trimmedMessage = userMessage.trim();
    if (trimmedMessage.isEmpty) {
      return 'Please enter a message first.';
    }

    try {
      final String? apiKey = dotenv.env['GEMINI_API_KEY'];
      if (apiKey == null || apiKey.isEmpty) {
        return _fallbackMessage;
      }

      final Uri uri = Uri.parse(
        'https://generativelanguage.googleapis.com/v1/models/$_model:generateContent?key=$apiKey',
      );

      final Map<String, dynamic> payload = <String, dynamic>{
        'contents': <Map<String, dynamic>>[
          <String, dynamic>{
            'role': 'user',
            'parts': <Map<String, String>>[
              <String, String>{'text': _buildPrompt(trimmedMessage)},
            ],
          },
        ],
      };

      final http.Response response = await http
          .post(
            uri,
            headers: <String, String>{'Content-Type': 'application/json'},
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 25));

      if (response.statusCode < 200 || response.statusCode >= 300) {
        print(
          'AiChatService error: HTTP ${response.statusCode}, body=${response.body}',
        );
        return _buildErrorMessage(response.statusCode, response.body);
      }

      final Map<String, dynamic> data =
          jsonDecode(response.body) as Map<String, dynamic>;

      final List<dynamic>? candidates = data['candidates'] as List<dynamic>?;
      if (candidates == null || candidates.isEmpty) {
        final String errorBody = response.body;
        if (data['error'] != null) {
          return 'AI API error: ${jsonEncode(data['error'])}';
        }
        return _buildErrorMessage(response.statusCode, errorBody);
      }

      final Map<String, dynamic>? firstCandidate =
          candidates.first as Map<String, dynamic>?;
      final Map<String, dynamic>? content =
          firstCandidate?['content'] as Map<String, dynamic>?;
      final List<dynamic>? parts = content?['parts'] as List<dynamic>?;

      if (parts == null || parts.isEmpty) {
        return _buildErrorMessage(
          response.statusCode,
          'Response did not contain any text parts.',
        );
      }

      final Map<String, dynamic>? firstPart =
          parts.first as Map<String, dynamic>?;
      final String? text = firstPart?['text'] as String?;

      if (text == null || text.trim().isEmpty) {
        return _buildErrorMessage(
          response.statusCode,
          'Response text was empty.',
        );
      }

      return text.trim();
    } catch (e) {
      print('AiChatService exception: $e');
      return 'AI API exception: $e';
    }
  }
}
