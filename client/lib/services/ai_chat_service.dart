import 'dart:async';
import 'dart:convert';
import 'dart:io';

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

  static const String _backendBaseUrl = 'http://10.0.2.2:3000';
  static const int _maxRetryAttempts = 3;

  final String _model;

  const AiChatService({String model = 'gemini-2.5-flash'}) : _model = model;

  List<Map<String, dynamic>> _buildGeminiContents(
    String currentMessage,
    List<Map<String, dynamic>> chatHistory,
    Map<String, dynamic>? imagePart,
  ) {
    final List<Map<String, dynamic>> contents = <Map<String, dynamic>>[];
    final int startIndex = chatHistory.length > 10
        ? chatHistory.length - 10
        : 0;

    for (final Map<String, dynamic> message in chatHistory.skip(startIndex)) {
      final String role = (message['role'] ?? '').toString();
      final String text = (message['text'] ?? '').toString().trim();

      if ((role == 'user' || role == 'model') && text.isNotEmpty) {
        contents.add(<String, dynamic>{
          'role': role,
          'parts': <Map<String, String>>[
            <String, String>{'text': text},
          ],
        });
      }
    }

    final List<Map<String, dynamic>> currentParts = <Map<String, dynamic>>[
      <String, String>{
        'text': _buildPrompt(currentMessage, hasImage: imagePart != null),
      },
    ];

    if (imagePart != null) {
      currentParts.add(imagePart);
    }

    contents.add(<String, dynamic>{'role': 'user', 'parts': currentParts});

    return contents;
  }

  String _buildPrompt(String userMessage, {required bool hasImage}) {
    final String normalizedMessage = userMessage.trim();
    final String messageForPrompt = normalizedMessage.isEmpty && hasImage
        ? 'Please analyze the attached image and provide health or nutrition insights.'
        : normalizedMessage;

    return '''
$system_prompt

User message:
$messageForPrompt
''';
  }

  String _detectImageMimeType(String path) {
    final String lowerPath = path.toLowerCase();
    if (lowerPath.endsWith('.png')) {
      return 'image/png';
    }
    if (lowerPath.endsWith('.webp')) {
      return 'image/webp';
    }
    if (lowerPath.endsWith('.gif')) {
      return 'image/gif';
    }
    if (lowerPath.endsWith('.bmp')) {
      return 'image/bmp';
    }
    if (lowerPath.endsWith('.heic')) {
      return 'image/heic';
    }
    if (lowerPath.endsWith('.heif')) {
      return 'image/heif';
    }
    return 'image/jpeg';
  }

  Future<Map<String, dynamic>?> _buildInlineImagePart(File image) async {
    final bool exists = await image.exists();
    if (!exists) {
      return null;
    }

    final List<int> imageBytes = await image.readAsBytes();
    if (imageBytes.isEmpty) {
      return null;
    }

    final String mimeType = _detectImageMimeType(image.path);
    final String encodedImage = base64Encode(imageBytes);

    return <String, dynamic>{
      'inlineData': <String, String>{
        'mimeType': mimeType,
        'data': encodedImage,
      },
    };
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

  bool _isRetriableStatusCode(int statusCode) {
    return statusCode == 429 ||
        statusCode == 500 ||
        statusCode == 502 ||
        statusCode == 503 ||
        statusCode == 504;
  }

  Duration _retryDelayForAttempt(int attempt) {
    if (attempt <= 1) {
      return const Duration(seconds: 1);
    }
    if (attempt == 2) {
      return const Duration(seconds: 2);
    }
    return const Duration(seconds: 4);
  }

  Map<String, dynamic> _parseSseDataEvent(String rawData) {
    final String trimmed = rawData.trim();
    if (trimmed.isEmpty || trimmed == '[DONE]') {
      return <String, dynamic>{'done': true};
    }

    try {
      final dynamic decoded = jsonDecode(trimmed);
      if (decoded is! Map<String, dynamic>) {
        return <String, dynamic>{'text': ''};
      }

      final dynamic errorRaw = decoded['error'];
      if (errorRaw is Map<String, dynamic>) {
        final int errorCode = (errorRaw['code'] is int)
            ? errorRaw['code'] as int
            : 500;
        return <String, dynamic>{
          'errorCode': errorCode,
          'errorBody': jsonEncode(errorRaw),
        };
      }

      final List<dynamic>? candidates = decoded['candidates'] as List<dynamic>?;
      if (candidates == null || candidates.isEmpty) {
        return <String, dynamic>{'text': ''};
      }

      final Map<String, dynamic>? firstCandidate =
          candidates.first as Map<String, dynamic>?;
      final Map<String, dynamic>? content =
          firstCandidate?['content'] as Map<String, dynamic>?;
      final List<dynamic>? parts = content?['parts'] as List<dynamic>?;
      if (parts == null || parts.isEmpty) {
        return <String, dynamic>{'text': ''};
      }

      final String text = parts
          .whereType<Map<String, dynamic>>()
          .map((Map<String, dynamic> part) => (part['text'] ?? '').toString())
          .where((String value) => value.isNotEmpty)
          .join();

      return <String, dynamic>{'text': text};
    } catch (_) {
      return <String, dynamic>{'text': ''};
    }
  }

  Stream<String> _streamSseText(http.StreamedResponse response) async* {
    String eventBuffer = '';

    await for (final String line
        in response.stream
            .transform(utf8.decoder)
            .transform(const LineSplitter())) {
      if (line.isEmpty) {
        if (eventBuffer.isNotEmpty) {
          final Map<String, dynamic> event = _parseSseDataEvent(eventBuffer);
          final int? errorCode = event['errorCode'] as int?;
          if (errorCode != null) {
            yield _buildErrorMessage(
              errorCode,
              (event['errorBody'] ?? '').toString(),
            );
            return;
          }

          final String chunkText = (event['text'] ?? '').toString();
          if (chunkText.isNotEmpty) {
            yield chunkText;
          }
        }

        eventBuffer = '';
        continue;
      }

      if (line.startsWith('data:')) {
        final String dataLine = line.substring(5).trimLeft();
        eventBuffer = eventBuffer.isEmpty
            ? dataLine
            : '$eventBuffer\n$dataLine';
      }
    }

    if (eventBuffer.isNotEmpty) {
      final Map<String, dynamic> event = _parseSseDataEvent(eventBuffer);
      final int? errorCode = event['errorCode'] as int?;
      if (errorCode != null) {
        yield _buildErrorMessage(
          errorCode,
          (event['errorBody'] ?? '').toString(),
        );
        return;
      }

      final String chunkText = (event['text'] ?? '').toString();
      if (chunkText.isNotEmpty) {
        yield chunkText;
      }
    }
  }

  Stream<String> sendMessage(
    String userMessage, {
    List<Map<String, dynamic>> chatHistory = const <Map<String, dynamic>>[],
    File? image,
  }) async* {
    final String trimmedMessage = userMessage.trim();
    if (trimmedMessage.isEmpty && image == null) {
      yield 'Please enter a message or attach an image first.';
      return;
    }

    final String? apiKey = dotenv.env['GEMINI_API_KEY'];
    if (apiKey == null || apiKey.isEmpty) {
      yield _fallbackMessage;
      return;
    }

    Map<String, dynamic>? imagePart;
    if (image != null) {
      try {
        imagePart = await _buildInlineImagePart(image);
      } catch (e) {
        print('AiChatService image conversion error: $e');
        yield 'Could not process the selected image. Please try another image.';
        return;
      }

      if (imagePart == null) {
        yield 'Could not process the selected image. Please try another image.';
        return;
      }
    }

    final Uri uri = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/$_model:streamGenerateContent?alt=sse&key=$apiKey',
    );

    final Map<String, dynamic> payload = <String, dynamic>{
      'contents': _buildGeminiContents(trimmedMessage, chatHistory, imagePart),
    };

    for (int attempt = 1; attempt <= _maxRetryAttempts; attempt++) {
      final http.Client client = http.Client();
      try {
        final http.Request request = http.Request('POST', uri)
          ..headers['Content-Type'] = 'application/json'
          ..body = jsonEncode(payload);

        final http.StreamedResponse response = await client
            .send(request)
            .timeout(const Duration(seconds: 25));

        if (response.statusCode < 200 || response.statusCode >= 300) {
          final String body = await response.stream.bytesToString();
          print('AiChatService error: HTTP ${response.statusCode}, body=$body');

          if (_isRetriableStatusCode(response.statusCode) &&
              attempt < _maxRetryAttempts) {
            await Future.delayed(_retryDelayForAttempt(attempt));
            continue;
          }

          yield _buildErrorMessage(response.statusCode, body);
          return;
        }

        bool hasStreamedAnyChunk = false;
        await for (final String chunkText in _streamSseText(response)) {
          if (chunkText.isEmpty) {
            continue;
          }
          hasStreamedAnyChunk = true;
          yield chunkText;
        }

        if (!hasStreamedAnyChunk) {
          yield _fallbackMessage;
        }
        return;
      } on TimeoutException catch (e) {
        print('AiChatService timeout (attempt $attempt): $e');
        if (attempt < _maxRetryAttempts) {
          await Future.delayed(_retryDelayForAttempt(attempt));
          continue;
        }
        yield _temporaryUnavailableMessage;
        return;
      } on SocketException catch (e) {
        print('AiChatService socket exception (attempt $attempt): $e');
        if (attempt < _maxRetryAttempts) {
          await Future.delayed(_retryDelayForAttempt(attempt));
          continue;
        }
        yield _fallbackMessage;
        return;
      } catch (e) {
        print('AiChatService exception: $e');
        yield 'AI API exception: $e';
        return;
      } finally {
        client.close();
      }
    }

    yield _temporaryUnavailableMessage;
  }

  Future<List<Map<String, dynamic>>> fetchChatHistory(String userId) async {
    final String trimmedUserId = userId.trim();
    if (trimmedUserId.isEmpty) {
      return <Map<String, dynamic>>[];
    }

    try {
      final Uri uri = Uri.parse(
        '$_backendBaseUrl/api/chat/${Uri.encodeComponent(trimmedUserId)}',
      );

      final http.Response response = await http
          .get(
            uri,
            headers: <String, String>{'Content-Type': 'application/json'},
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode < 200 || response.statusCode >= 300) {
        print(
          'fetchChatHistory error: HTTP ${response.statusCode}, body=${response.body}',
        );
        return <Map<String, dynamic>>[];
      }

      final Map<String, dynamic> data =
          jsonDecode(response.body) as Map<String, dynamic>;

      final dynamic messagesRaw = data['messages'];
      if (messagesRaw is! List<dynamic>) {
        return <Map<String, dynamic>>[];
      }

      return messagesRaw
          .whereType<Map<String, dynamic>>()
          .map(
            (Map<String, dynamic> message) => <String, dynamic>{
              'role': (message['role'] ?? '').toString(),
              'text': (message['text'] ?? '').toString(),
              'timestamp': message['timestamp'],
            },
          )
          .toList();
    } catch (e) {
      print('fetchChatHistory exception: $e');
      return <Map<String, dynamic>>[];
    }
  }

  Future<void> saveMessageToDb(String userId, String role, String text) async {
    final String trimmedUserId = userId.trim();
    final String trimmedRole = role.trim();
    final String trimmedText = text.trim();

    if (trimmedUserId.isEmpty || trimmedText.isEmpty) {
      return;
    }

    if (trimmedRole != 'user' && trimmedRole != 'model') {
      return;
    }

    try {
      final Uri uri = Uri.parse('$_backendBaseUrl/api/chat/save');

      final http.Response response = await http
          .post(
            uri,
            headers: <String, String>{'Content-Type': 'application/json'},
            body: jsonEncode(<String, String>{
              'userId': trimmedUserId,
              'role': trimmedRole,
              'text': trimmedText,
            }),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode < 200 || response.statusCode >= 300) {
        print(
          'saveMessageToDb error: HTTP ${response.statusCode}, body=${response.body}',
        );
      }
    } catch (e) {
      print('saveMessageToDb exception: $e');
    }
  }
}
