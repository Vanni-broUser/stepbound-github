import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

/// How a batch went.
enum SendOutcome {
  /// The server has it.
  delivered,

  /// The server will never take it (malformed, too large, wrong key):
  /// sending it again would fail again, so it is dropped.
  rejected,

  /// No network, a timeout, the server busy or down: tried again later.
  failed,
}

/// Where the outbox goes: POSTs a body as JSON to a path of the server.
typedef TelemetryTransport =
    Future<SendOutcome> Function(String path, Map<String, Object?> body);

/// The `stepbound-be` server at [baseUrl], over HTTP(S), with the app's
/// [key]; its [send] is the [TelemetryTransport].
final class HttpTelemetryTransport {
  HttpTelemetryTransport({
    required this.baseUrl,
    required this.key,
    http.Client? client,
    this.timeout = const Duration(seconds: 20),
  }) : _client = client ?? http.Client();

  final String baseUrl;
  final String key;
  final Duration timeout;
  final http.Client _client;

  Future<SendOutcome> send(String path, Map<String, Object?> body) async {
    final base = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;
    try {
      final response = await _client
          .post(
            Uri.parse('$base$path'),
            headers: <String, String>{
              'Content-Type': 'application/json',
              'X-Stepbound-Key': key,
            },
            body: jsonEncode(body),
          )
          .timeout(timeout);
      return outcomeOf(response.statusCode);
    } on Object {
      // Offline, DNS, TLS, timeout: all of them mean "later".
      return SendOutcome.failed;
    }
  }

  /// What an answer with [status] means for the batch.
  static SendOutcome outcomeOf(int status) {
    if (status >= 200 && status < 300) {
      return SendOutcome.delivered;
    }
    // Busy, rate limited, or the server broken for now.
    if (status == 408 || status == 429 || status >= 500) {
      return SendOutcome.failed;
    }
    return SendOutcome.rejected;
  }
}
