import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

class AiChatService {
  static const String _fallbackMessage =
      'Sorry, I am unable to respond right now. Please try again in a moment.';

  static const String _temporaryUnavailableMessage =
      'The AI service is currently busy. Please try again in a moment.';

  static const String _backendBaseUrl = 'http://10.0.2.2:3000';
  static const int _maxRetryAttempts = 3;

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

  Stream<String> sendMessage(
    String userMessage, {
    required String userId,
    File? image,
  }) async* {
    final String trimmedMessage = userMessage.trim();
    final String trimmedUserId = userId.trim();

    if (trimmedMessage.isEmpty && image == null) {
      yield 'Please enter a message or attach an image first.';
      return;
    }

    if (trimmedUserId.isEmpty) {
      yield _fallbackMessage;
      return;
    }

    final Map<String, dynamic> payload = <String, dynamic>{
      'userId': trimmedUserId,
      'message': trimmedMessage,
    };

    if (image != null) {
      try {
        final Map<String, dynamic>? imagePart = await _buildInlineImagePart(
          image,
        );

        if (imagePart == null) {
          yield 'Could not process the selected image. Please try another image.';
          return;
        }

        payload['imagePart'] = imagePart;
      } catch (e) {
        print('AiChatService image conversion error: $e');
        yield 'Could not process the selected image. Please try another image.';
        return;
      }
    }

    final Uri uri = Uri.parse('$_backendBaseUrl/api/chat/message');

    for (int attempt = 1; attempt <= _maxRetryAttempts; attempt++) {
      final http.Client client = http.Client();
      try {
        final http.Response response = await client
            .post(
              uri,
              headers: <String, String>{'Content-Type': 'application/json'},
              body: jsonEncode(payload),
            )
            .timeout(const Duration(seconds: 30));

        if (response.statusCode < 200 || response.statusCode >= 300) {
          print(
            'AiChatService error: HTTP ${response.statusCode}, body=${response.body}',
          );

          if (_isRetriableStatusCode(response.statusCode) &&
              attempt < _maxRetryAttempts) {
            await Future.delayed(_retryDelayForAttempt(attempt));
            continue;
          }

          yield _buildErrorMessage(response.statusCode, response.body);
          return;
        }

        final dynamic decoded = jsonDecode(response.body);
        final String reply = (decoded is Map<String, dynamic>)
            ? (decoded['reply'] ?? '').toString().trim()
            : '';

        if (reply.isEmpty) {
          yield _fallbackMessage;
        } else {
          yield reply;
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
        yield _fallbackMessage;
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

  Future<Map<String, dynamic>> clearChatHistory(String userId) async {
    final String trimmedUserId = userId.trim();
    if (trimmedUserId.isEmpty) {
      return <String, dynamic>{
        'success': false,
        'message': 'Không tìm thấy người dùng để xoá lịch sử.',
      };
    }

    try {
      final Uri uri = Uri.parse(
        '$_backendBaseUrl/api/chat/history?userId=${Uri.encodeComponent(trimmedUserId)}',
      );

      final http.Response response = await http
          .delete(
            uri,
            headers: <String, String>{'Content-Type': 'application/json'},
          )
          .timeout(const Duration(seconds: 15));

      final dynamic decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        return <String, dynamic>{
          'success': response.statusCode >= 200 && response.statusCode < 300,
          'message': (decoded['message'] ?? 'Vui lòng thử lại.').toString(),
        };
      }

      return <String, dynamic>{
        'success': response.statusCode >= 200 && response.statusCode < 300,
        'message': response.statusCode >= 200 && response.statusCode < 300
            ? 'Đã xoá lịch sử trò chuyện.'
            : 'Xoá lịch sử thất bại.',
      };
    } catch (_) {
      return <String, dynamic>{
        'success': false,
        'message': 'Không thể kết nối tới server.',
      };
    }
  }
}
