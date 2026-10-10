import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

class PlantPrediction {
  final String crop;
  final String disease;
  final double confidence;
  final bool healthy;
  final List<MapEntry<String, double>> top3;

  PlantPrediction({
    required this.crop,
    required this.disease,
    required this.confidence,
    required this.healthy,
    this.top3 = const [],
  });
}

class PlantClassifier {
  Interpreter? _interpreter;

  // If the offline model gives confident but wrong answers, change this to
  // true. (The cloud AI decides the verdict when internet is available.)
  static const bool minusOneToOne = false;

  // This order must match the order the model was trained with.
  final List<String> labels = [
    'bell_pepper_healthy',
    'bell_pepper_leaf_spot',
    'potato_early_blight',
    'potato_healthy',
    'potato_late_blight',
    'tomato_bacterial_spot',
    'tomato_early_blight',
    'tomato_healthy',
    'tomato_late_blight',
    'tomato_leaf_mold',
    'tomato_mosaic_virus',
    'tomato_septoria_leaf_spot',
    'tomato_yellow_leaf_curl',
  ];

  Future<void> loadModel() async {
    if (_interpreter != null) return;
    _interpreter = await Interpreter.fromAsset(
      'assets/models/best_mobilenet.tflite',
    );
    final inT = _interpreter!.getInputTensor(0);
    final outT = _interpreter!.getOutputTensor(0);
    debugPrint('KM: INPUT shape=${inT.shape} type=${inT.type}');
    debugPrint('KM: OUTPUT shape=${outT.shape} type=${outT.type}');
  }

  Future<PlantPrediction> predict(
    Uint8List imageBytes,
    String selectedCrop,
  ) async {
    await loadModel();

    final outLen = _interpreter!.getOutputTensor(0).shape.last;
    if (outLen != labels.length) {
      throw Exception(
        'Model has $outLen outputs but labels list has ${labels.length}.',
      );
    }

    final decoded = img.decodeImage(imageBytes);
    if (decoded == null) {
      throw Exception('Could not read the leaf image.');
    }
    final image = img.bakeOrientation(decoded);
    final resized = img.copyResize(image, width: 224, height: 224);

    final input = [
      List.generate(
        224,
        (y) => List.generate(224, (x) {
          final p = resized.getPixel(x, y);
          if (minusOneToOne) {
            return [
              (p.r - 127.5) / 127.5,
              (p.g - 127.5) / 127.5,
              (p.b - 127.5) / 127.5,
            ];
          }
          return [p.r / 255.0, p.g / 255.0, p.b / 255.0];
        }),
      ),
    ];

    final output = [List<double>.filled(labels.length, 0.0)];
    _interpreter!.run(input, output);

    final raw = output[0];
    final sum = raw.reduce((a, b) => a + b);
    final alreadyProb =
        raw.every((v) => v >= 0 && v <= 1) && (sum - 1).abs() < 0.01;
    final probabilities = alreadyProb ? raw : _softmax(raw);
    debugPrint('KM: RAW=$raw');

    final cropLower = selectedCrop.toLowerCase().replaceAll(' ', '_');
    final allowed = <int>[];
    for (int i = 0; i < labels.length; i++) {
      if (labels[i].toLowerCase().startsWith('${cropLower}_')) {
        allowed.add(i);
      }
    }
    if (allowed.isEmpty) {
      throw Exception(
        'The offline model supports Tomato, Potato and Bell Pepper.',
      );
    }

    double total = 0.0;
    for (final i in allowed) {
      total += probabilities[i];
    }

    final scored = allowed
        .map((i) => MapEntry(i, total == 0 ? 0.0 : probabilities[i] / total))
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final best = scored.first;

    // The photo is probably not a leaf of the selected crop.
    final rawBest = probabilities[best.key];
    if (total < 0.5 || rawBest < 0.4) {
      return PlantPrediction(
        crop: selectedCrop,
        disease: 'Not Sure - Retake Photo',
        confidence: rawBest,
        healthy: false,
        top3: const [],
      );
    }

    final parsed = _parseLabel(labels[best.key]);

    final top3 = scored
        .take(3)
        .map((e) => MapEntry(_parseLabel(labels[e.key])['disease']!, e.value))
        .toList();

    return PlantPrediction(
      crop: parsed['crop']!,
      disease: parsed['disease']!,
      confidence: best.value,
      healthy: parsed['disease']!.toLowerCase().contains('healthy'),
      top3: top3,
    );
  }

  Map<String, String> _parseLabel(String label) {
    final parts = label.split('_');
    String crop;
    if (label.startsWith('bell_pepper')) {
      crop = 'Bell Pepper';
    } else if (label.startsWith('potato')) {
      crop = 'Potato';
    } else if (label.startsWith('tomato')) {
      crop = 'Tomato';
    } else {
      crop = 'Unknown';
    }

    String disease = label.startsWith('bell_pepper')
        ? parts.skip(2).join(' ')
        : parts.skip(1).join(' ');

    disease = disease
        .split(' ')
        .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
        .join(' ');

    return {'crop': crop, 'disease': disease};
  }

  List<double> _softmax(List<double> values) {
    final maxValue = values.reduce(max);
    final exps = values.map((v) => exp(v - maxValue)).toList();
    final sum = exps.reduce((a, b) => a + b);
    return exps.map((v) => v / sum).toList();
  }

  void dispose() {
    _interpreter?.close();
    _interpreter = null;
  }
}
