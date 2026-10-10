import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'secrets.dart';

/// Thrown when the cloud AI cannot answer. [message] is safe to show.
class AiUnavailable implements Exception {
  final String kind; // no_key, bad_key, offline, busy, error
  final String message;
  const AiUnavailable(this.kind, this.message);

  @override
  String toString() => message;
}

class Diagnosis {
  final bool isLeaf;
  final String plant;
  final String condition;
  final String confidence; // low, medium, high
  final String summary;
  final List<String> steps;
  final String callExpert;

  const Diagnosis({
    required this.isLeaf,
    required this.plant,
    required this.condition,
    required this.confidence,
    required this.summary,
    required this.steps,
    required this.callExpert,
  });
}

class AiAdvisor {
  static const String _base =
      'https://generativelanguage.googleapis.com/v1beta';

  static const List<String> _fallbackModels = [
    'gemini-flash-latest',
    'gemini-2.5-flash',
    'gemini-2.5-flash-lite',
  ];

  static List<String>? _models;

  static bool get hasKey =>
      geminiKey.trim().isNotEmpty && !geminiKey.contains('PASTE');

  static Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'x-goog-api-key': geminiKey.trim(),
      };

  static Future<http.Response> _send(
      Future<http.Response> Function() call) async {
    try {
      return await call().timeout(const Duration(seconds: 40));
    } on TimeoutException {
      throw const AiUnavailable('offline', 'Slow or no internet.');
    } on SocketException {
      throw const AiUnavailable('offline', 'No internet.');
    } on http.ClientException {
      throw const AiUnavailable('offline', 'No internet.');
    }
  }

  static int _version(String name) {
    final m = RegExp(r'gemini-(\d+)(?:\.(\d+))?').firstMatch(name);
    final major = int.tryParse(m?.group(1) ?? '') ?? 0;
    final minor = int.tryParse(m?.group(2) ?? '') ?? 0;
    return major * 100 + minor;
  }

  static int _compare(String a, String b) {
    int lite(String n) => n.contains('lite') ? 1 : 0;
    int pre(String n) =>
        (n.contains('preview') || n.contains('exp')) ? 1 : 0;
    final c1 = lite(a).compareTo(lite(b));
    if (c1 != 0) return c1;
    final c2 = pre(a).compareTo(pre(b));
    if (c2 != 0) return c2;
    return _version(b).compareTo(_version(a));
  }

  /// Asks Google which Gemini models this key can use, so we never guess names.
  static Future<List<String>> _loadModels() async {
    final cached = _models;
    if (cached != null && cached.isNotEmpty) return cached;
    if (!hasKey) {
      throw const AiUnavailable(
          'no_key', 'Cloud AI key is missing. Add it in lib/secrets.dart.');
    }

    final res = await _send(
        () => http.get(Uri.parse('$_base/models?pageSize=200'), headers: _headers));

    if (res.statusCode == 400 ||
        res.statusCode == 401 ||
        res.statusCode == 403) {
      debugPrint('GEMINI list ${res.statusCode}: ${res.body}');
      throw const AiUnavailable(
          'bad_key', 'Cloud AI key was rejected. Create a new key.');
    }
    if (res.statusCode != 200) {
      debugPrint('GEMINI list ${res.statusCode}: ${res.body}');
      _models = _fallbackModels;
      return _fallbackModels;
    }

    final data = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    final list = <String>[];
    const skip = [
      'image', 'tts', 'live', 'audio', 'embedding', 'robotics', 'computer',
      'native', 'thinking', 'learnlm', 'gemma'
    ];
    for (final m in (data['models'] as List? ?? [])) {
      final name = (m['name'] ?? '').toString().replaceFirst('models/', '');
      final lower = name.toLowerCase();
      final methods = (m['supportedGenerationMethods'] as List? ?? [])
          .map((e) => e.toString())
          .toList();
      if (!methods.contains('generateContent')) continue;
      if (!lower.startsWith('gemini') || !lower.contains('flash')) continue;
      if (skip.any((w) => lower.contains(w))) continue;
      list.add(name);
    }
    list.sort(_compare);
    if (list.remove('gemini-flash-latest')) {
      list.insert(0, 'gemini-flash-latest');
    }
    debugPrint('GEMINI models: $list');

    _models = list.isEmpty ? _fallbackModels : list;
    return _models!;
  }

  /// Checks the key and internet. Throws [AiUnavailable] when not usable.
  static Future<void> ping() async {
    await _loadModels();
  }

  static Future<String> _generate(List<Map<String, dynamic>> parts) async {
    final models = await _loadModels();
    bool busy = false;

    for (int round = 0; round < 2; round++) {
      for (final model in models.take(6)) {
        final res = await _send(() => http.post(
              Uri.parse('$_base/models/$model:generateContent'),
              headers: _headers,
              body: jsonEncode({
                'contents': [
                  {'parts': parts},
                ],
              }),
            ));
        final code = res.statusCode;

        if (code == 200) {
          final data = jsonDecode(utf8.decode(res.bodyBytes));
          final ps = data['candidates']?[0]?['content']?['parts'] as List?;
          final text =
              ps?.map((p) => p['text'] ?? '').join().trim() ?? '';
          if (text.isNotEmpty) return text;
          continue;
        }

        debugPrint('GEMINI $model -> $code ${res.body}');
        final body = res.body.toLowerCase();
        if ((code == 401 || code == 403 || code == 400) &&
            body.contains('api key')) {
          throw const AiUnavailable(
              'bad_key', 'Cloud AI key was rejected. Create a new key.');
        }
        if (code == 429 || code == 500 || code == 503) busy = true;
      }
      if (!busy) break;
      await Future.delayed(const Duration(seconds: 3));
    }

    if (busy) {
      throw const AiUnavailable('busy', 'Cloud AI is busy right now.');
    }
    throw const AiUnavailable('error', 'Cloud AI could not answer.');
  }

  static Future<Diagnosis> diagnose({
    required Uint8List bytes,
    required String mime,
    required String crop,
    required String symptom,
    required String language,
    String? localPrediction,
  }) async {
    final hint = localPrediction == null
        ? ''
        : 'An offline AI model guessed: $localPrediction.';

    final prompt = '''
You are a plant-disease assistant for small farmers in India.
Look carefully at the photo. The farmer says the crop is $crop and noticed: $symptom. $hint
Reply with JSON only, no other text, in exactly this shape:
{"is_plant_leaf": true or false,
 "plant": "plant name or unknown",
 "condition": "healthy, or the disease name in English, or unknown",
 "confidence": "low, medium or high",
 "summary": "1 or 2 very simple sentences in $language",
 "prevention_steps": ["step 1 in $language", "step 2 in $language", "step 3 in $language"],
 "call_expert_when": "one simple sentence in $language"}
Rules: if the photo is not a plant leaf, set is_plant_leaf to false. If you are unsure, use unknown instead of guessing. Do not give pesticide doses or brand names. This is preliminary advice.
''';

    final text = await _generate([
      {'text': prompt},
      {
        'inline_data': {'mime_type': mime, 'data': base64Encode(bytes)},
      },
    ]);

    final start = text.indexOf('{');
    final end = text.lastIndexOf('}');
    if (start < 0 || end <= start) {
      throw const AiUnavailable('error', 'Cloud AI gave an unreadable answer.');
    }
    try {
      final m = jsonDecode(text.substring(start, end + 1)) as Map<String, dynamic>;
      return Diagnosis(
        isLeaf: m['is_plant_leaf'] == true,
        plant: '${m['plant'] ?? 'unknown'}',
        condition: '${m['condition'] ?? 'unknown'}',
        confidence: '${m['confidence'] ?? 'low'}',
        summary: '${m['summary'] ?? ''}',
        steps: (m['prevention_steps'] as List? ?? [])
            .map((e) => e.toString())
            .toList(),
        callExpert: '${m['call_expert_when'] ?? ''}',
      );
    } on FormatException {
      throw const AiUnavailable('error', 'Cloud AI gave an unreadable answer.');
    }
  }
}
