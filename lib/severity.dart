import 'dart:io';
import 'dart:typed_data';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';

import 'theme.dart';

class SeverityResult {
  final double percent; // share of the leaf that looks damaged
  final bool leafFound;
  final Uint8List overlayPng; // photo with damaged areas painted red

  SeverityResult({
    required this.percent,
    required this.leafFound,
    required this.overlayPng,
  });
}

(double, double, double) _hsv(int r8, int g8, int b8) {
  final r = r8 / 255.0;
  final g = g8 / 255.0;
  final b = b8 / 255.0;
  final mx = max(r, max(g, b));
  final mn = min(r, min(g, b));
  final d = mx - mn;
  double h = 0;
  if (d != 0) {
    if (mx == r) {
      h = 60 * (((g - b) / d) % 6);
    } else if (mx == g) {
      h = 60 * (((b - r) / d) + 2);
    } else {
      h = 60 * (((r - g) / d) + 4);
    }
  }
  if (h < 0) h += 360;
  final s = mx == 0 ? 0.0 : d / mx;
  return (h, s, mx);
}

/// Colour-based estimate of how much of the leaf is damaged.
/// Green pixels = healthy leaf. Brown, yellow, orange or very dark pixels
/// = damaged. Grey/white pixels = background and are ignored.
SeverityResult analyzeSeverity(Uint8List bytes) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) {
    throw Exception('Could not read the photo.');
  }
  final base = img.bakeOrientation(decoded);
  final small = img.copyResize(base, width: 320);
  final overlay = img.Image.from(small);

  int green = 0;
  int lesion = 0;

  for (int y = 0; y < small.height; y++) {
    for (int x = 0; x < small.width; x++) {
      final p = small.getPixel(x, y);
      final hsv = _hsv(p.r.toInt(), p.g.toInt(), p.b.toInt());
      final h = hsv.$1;
      final s = hsv.$2;
      final v = hsv.$3;

      final bool isGreen = h >= 65 && h <= 170 && s >= 0.20 && v >= 0.15;
      bool isLesion = false;
      if (!isGreen) {
        if (s >= 0.28 && v >= 0.12 && (h <= 62 || h >= 345)) {
          isLesion = true; // brown, orange, yellow, rust
        } else if (v >= 0.05 && v < 0.22 && s >= 0.15) {
          isLesion = true; // dark dead spots
        }
      }

      if (isGreen) {
        green++;
      } else if (isLesion) {
        lesion++;
        overlay.setPixelRgb(x, y, 230, 30, 60);
      }
    }
  }

  final leafPixels = green + lesion;
  final total = small.width * small.height;
  final leafFound = leafPixels >= total * 0.08;
  final percent = leafPixels == 0 ? 0.0 : lesion / leafPixels * 100.0;

  return SeverityResult(
    percent: percent,
    leafFound: leafFound,
    overlayPng: Uint8List.fromList(img.encodePng(overlay)),
  );
}

class _Level {
  final String name;
  final Color color;
  final String action;
  const _Level(this.name, this.color, this.action);
}

_Level _levelFor(double p) {
  if (p < 3) {
    return const _Level(
        'Trace', kRiskLow, 'Almost no damage. Keep checking the plant every few days.');
  }
  if (p < 15) {
    return const _Level('Mild', kRiskMid,
        'Remove the few damaged leaves and check again in 2 days.');
  }
  if (p < 35) {
    return const _Level('Moderate', Color(0xFFD9822B),
        'Act within 2 to 3 days. Show the plant to your agriculture officer.');
  }
  return const _Level('Severe', kRiskHigh,
      'Act today. Separate the plant and contact your agriculture officer or KVK.');
}

class SeverityCard extends StatefulWidget {
  final XFile leafImage;
  final ValueChanged<double>? onResult;
  const SeverityCard({super.key, required this.leafImage, this.onResult});

  @override
  State<SeverityCard> createState() => _SeverityCardState();
}

class _SeverityCardState extends State<SeverityCard> {
  SeverityResult? result;
  bool loading = true;
  String error = '';

  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    try {
      final bytes = await widget.leafImage.readAsBytes();
      final r = analyzeSeverity(bytes);
      if (!mounted) return;
      setState(() {
        result = r;
        loading = false;
      });
      if (r.leafFound) widget.onResult?.call(r.percent);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        error = e.toString();
        loading = false;
      });
    }
  }

  List<Widget> _content(SeverityResult r) {
    if (!r.leafFound) {
      return const [
        Text(
          'No clear leaf found. Retake the photo with one leaf on a plain, light background.',
          style: TextStyle(color: kMuted),
        ),
      ];
    }
    final lv = _levelFor(r.percent);
    return [
      Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            '${r.percent.toStringAsFixed(0)}%',
            style: TextStyle(
                fontSize: 44, fontWeight: FontWeight.w800, color: lv.color),
          ),
          const SizedBox(width: 10),
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: lv.color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(lv.name,
                  style: TextStyle(
                      color: lv.color, fontWeight: FontWeight.w800)),
            ),
          ),
        ],
      ),
      const SizedBox(height: 8),
      ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: LinearProgressIndicator(
          value: (r.percent / 100).clamp(0.0, 1.0).toDouble(),
          minHeight: 10,
          color: lv.color,
          backgroundColor: kLine,
        ),
      ),
      const SizedBox(height: 14),
      Row(
        children: [
          Expanded(child: _photo('Your photo', Image.file(File(widget.leafImage.path), fit: BoxFit.cover))),
          const SizedBox(width: 10),
          Expanded(child: _photo('Damage found (red)', Image.memory(r.overlayPng, fit: BoxFit.cover))),
        ],
      ),
      const SizedBox(height: 12),
      Text(lv.action,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: kInk)),
      const SizedBox(height: 8),
      const Text(
        'Colour-based estimate. Works best with one leaf on a plain background.',
        style: TextStyle(color: kMuted, fontSize: 12),
      ),
    ];
  }

  Widget _photo(String label, Widget image) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AspectRatio(
          aspectRatio: 1,
          child: ClipRRect(borderRadius: BorderRadius.circular(14), child: image),
        ),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(color: kMuted, fontSize: 12)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final r = result;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: panel(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Severity meter',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: kInk)),
          const SizedBox(height: 2),
          const Text('How much of the leaf looks damaged',
              style: TextStyle(color: kMuted, fontSize: 13)),
          const SizedBox(height: 14),
          if (loading)
            const LinearProgressIndicator(color: kLime)
          else if (error.isNotEmpty)
            Text('Could not measure severity. $error')
          else if (r != null)
            ..._content(r),
        ],
      ),
    );
  }
}
