import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class GeminiTextResult {
  GeminiTextResult({
    required this.text,
    required this.rawBody,
    required this.statusCode,
    this.finishReason,
    this.finishMessage,
    this.promptBlockReason,
    this.usageMetadata,
  });

  final String text;
  final String rawBody;
  final int statusCode;
  final String? finishReason;
  final String? finishMessage;
  final String? promptBlockReason;
  final Map<String, dynamic>? usageMetadata;

  bool get isComplete => finishReason == 'STOP' && text.trim().isNotEmpty;

  bool get isLikelyIncomplete {
    if (!isComplete) return true;

    final normalized = text.trimRight();
    if (normalized.isEmpty) return true;

    final lastChar = normalized.substring(normalized.length - 1);
    const terminalChars = '.!?)]}"\'…';
    if (terminalChars.contains(lastChar) ||
        !RegExp(r'[A-Za-z0-9]$').hasMatch(lastChar)) {
      return false;
    }

    final lastWord = normalized
        .split(RegExp(r'\s+'))
        .where((token) => token.isNotEmpty)
        .last
        .toLowerCase();

    const danglingWords = {
      'dan',
      'atau',
      'karena',
      'untuk',
      'dengan',
      'yang',
      'but',
      'and',
      'because',
      'with',
      'to',
    };

    return danglingWords.contains(lastWord) ||
        normalized.endsWith(',') ||
        normalized.endsWith(':') ||
        normalized.endsWith('-') ||
        normalized.endsWith('*');
  }
}

class GeminiApiException implements Exception {
  GeminiApiException(
    this.message, {
    this.statusCode,
    this.rawBody,
    this.retryable = false,
  });

  final String message;
  final int? statusCode;
  final String? rawBody;
  final bool retryable;

  @override
  String toString() {
    final code = statusCode == null ? '' : ' [$statusCode]';
    return 'GeminiApiException$code: $message';
  }
}

class GeminiIncompleteResponseException implements Exception {
  GeminiIncompleteResponseException(this.result);

  final GeminiTextResult result;

  @override
  String toString() {
    return 'GeminiIncompleteResponseException: '
        'finishReason=${result.finishReason}, '
        'finishMessage=${result.finishMessage}, '
        'textLength=${result.text.length}';
  }
}

class GeminiService {
  GeminiService({http.Client? client, Duration? timeout, bool? enableDebugLogs})
    : _client = client ?? http.Client(),
      _timeout = timeout ?? const Duration(seconds: 45),
      _enableDebugLogs =
          enableDebugLogs ??
          kDebugMode || dotenv.env['AI_DEBUG_LOGS']?.toLowerCase() == 'true';

  static final GeminiService instance = GeminiService();

  final http.Client _client;
  final Duration _timeout;
  final bool _enableDebugLogs;
  final Random _random = Random();

  String get _model {
    final configured = dotenv.env['GEMINI_MODEL']?.trim();
    if (configured != null && configured.isNotEmpty) {
      return configured;
    }

    return 'gemini-2.5-flash';
  }

  Uri get _uri => Uri.parse(
    'https://generativelanguage.googleapis.com/v1beta/models/$_model:generateContent',
  );

  Future<GeminiTextResult> generateText({
    required String prompt,
    required int maxOutputTokens,
    String? requestTag,
    List<Map<String, dynamic>>? safetySettings,
    Map<String, dynamic>? generationConfig,
    bool requireComplete = true,
  }) async {
    final apiKey = dotenv.env['GEMINI_API_KEY'] ?? '';
    if (apiKey.isEmpty) {
      throw GeminiApiException('Missing GEMINI_API_KEY.');
    }

    final body = <String, dynamic>{
      'contents': [
        {
          'role': 'user',
          'parts': [
            {'text': prompt},
          ],
        },
      ],
      'generationConfig': {
        'maxOutputTokens': maxOutputTokens,
        ...?generationConfig,
      },
      if (safetySettings != null) 'safetySettings': safetySettings,
    };

    GeminiApiException? lastApiError;
    Object? lastUnexpectedError;

    for (var attempt = 1; attempt <= 4; attempt++) {
      try {
        _log(
          '[Gemini${_formatTag(requestTag)}] attempt=$attempt promptLength=${prompt.length} maxOutputTokens=$maxOutputTokens',
        );

        final request = http.Request('POST', _uri)
          ..headers.addAll({
            'Content-Type': 'application/json',
            'x-goog-api-key': apiKey,
          })
          ..body = jsonEncode(body);

        final streamedResponse = await _client.send(request).timeout(_timeout);
        final response = await http.Response.fromStream(streamedResponse);

        _logChunked(
          '[Gemini${_formatTag(requestTag)}] raw status=${response.statusCode}',
          response.body,
        );

        if (response.statusCode != 200) {
          final error = GeminiApiException(
            _extractApiErrorMessage(response.body),
            statusCode: response.statusCode,
            rawBody: response.body,
            retryable: _isRetryableStatus(response.statusCode),
          );

          if (error.retryable && attempt < 4) {
            await Future.delayed(
              _retryDelay(
                attempt: attempt,
                rawBody: response.body,
                retryAfterHeader: response.headers['retry-after'],
              ),
            );
            lastApiError = error;
            continue;
          }

          throw error;
        }

        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final promptFeedback = data['promptFeedback'] as Map<String, dynamic>?;

        if ((data['candidates'] as List?)?.isEmpty ?? true) {
          throw GeminiApiException(
            'Gemini returned no candidates.',
            statusCode: response.statusCode,
            rawBody: response.body,
          );
        }

        final candidate =
            (data['candidates'] as List).first as Map<String, dynamic>;
        final content = candidate['content'] as Map<String, dynamic>?;
        final parts = (content?['parts'] as List? ?? const []);
        final text = parts
            .whereType<Map>()
            .map((part) => part['text'])
            .whereType<String>()
            .join()
            .trim();

        final result = GeminiTextResult(
          text: text,
          rawBody: response.body,
          statusCode: response.statusCode,
          finishReason: candidate['finishReason'] as String?,
          finishMessage: candidate['finishMessage'] as String?,
          promptBlockReason: promptFeedback?['blockReason'] as String?,
          usageMetadata: data['usageMetadata'] as Map<String, dynamic>?,
        );

        if (requireComplete && !result.isComplete) {
          throw GeminiIncompleteResponseException(result);
        }

        return result;
      } on GeminiApiException catch (error) {
        lastApiError = error;
        rethrow;
      } on GeminiIncompleteResponseException {
        rethrow;
      } on TimeoutException catch (error) {
        lastUnexpectedError = error;
        if (attempt == 4) break;
        await Future.delayed(_retryDelay(attempt: attempt));
      } catch (error) {
        lastUnexpectedError = error;
        if (attempt == 4) break;
        await Future.delayed(_retryDelay(attempt: attempt));
      }
    }

    if (lastApiError != null) {
      throw lastApiError;
    }

    throw GeminiApiException(
      'Gemini request failed after retries: ${lastUnexpectedError ?? 'unknown error'}',
    );
  }

  bool _isRetryableStatus(int statusCode) {
    return statusCode == 429 ||
        statusCode == 500 ||
        statusCode == 503 ||
        statusCode == 504;
  }

  Duration _retryDelay({
    required int attempt,
    String? rawBody,
    String? retryAfterHeader,
  }) {
    final retryAfterSeconds = int.tryParse(retryAfterHeader ?? '');
    if (retryAfterSeconds != null && retryAfterSeconds > 0) {
      return Duration(seconds: retryAfterSeconds);
    }

    final retryDelayFromBody = _extractRetryDelay(rawBody);
    if (retryDelayFromBody != null) {
      return retryDelayFromBody;
    }

    final cappedSeconds = min(8, 1 << (attempt - 1));
    final jitterMillis = _random.nextInt(400);
    return Duration(seconds: cappedSeconds, milliseconds: jitterMillis);
  }

  Duration? _extractRetryDelay(String? rawBody) {
    if (rawBody == null || rawBody.isEmpty) return null;

    try {
      final parsed = jsonDecode(rawBody);
      if (parsed is! Map<String, dynamic>) return null;

      final details =
          ((parsed['error'] as Map<String, dynamic>?)?['details'] as List?) ??
          const [];

      for (final detail in details.whereType<Map>()) {
        final retryDelay = detail['retryDelay'];
        if (retryDelay is String && retryDelay.endsWith('s')) {
          final seconds = double.tryParse(retryDelay.replaceAll('s', ''));
          if (seconds != null) {
            return Duration(milliseconds: (seconds * 1000).round());
          }
        }
      }
    } catch (_) {
      return null;
    }

    return null;
  }

  String _extractApiErrorMessage(String rawBody) {
    try {
      final parsed = jsonDecode(rawBody) as Map<String, dynamic>;
      final error = parsed['error'] as Map<String, dynamic>?;
      final message = error?['message'];
      if (message is String && message.isNotEmpty) {
        return message;
      }
    } catch (_) {
      // Fallback to raw body below.
    }

    return rawBody.isEmpty ? 'Unknown Gemini API error.' : rawBody;
  }

  String _formatTag(String? requestTag) {
    if (requestTag == null || requestTag.trim().isEmpty) return '';
    return ' $requestTag';
  }

  void _log(String message) {
    if (!_enableDebugLogs) return;
    debugPrint(message);
  }

  void _logChunked(String prefix, String message) {
    if (!_enableDebugLogs) return;

    const chunkSize = 800;
    if (message.isEmpty) {
      debugPrint(prefix);
      return;
    }

    for (var index = 0; index < message.length; index += chunkSize) {
      final end = min(index + chunkSize, message.length);
      final chunk = message.substring(index, end);
      debugPrint('$prefix ${index ~/ chunkSize + 1}: $chunk');
    }
  }
}
