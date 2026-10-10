import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'ai_advisor.dart';
import 'offline_guide.dart';
import 'theme.dart';

/// Small line on the home screen: is the cloud AI reachable?
class AiStatusChip extends StatefulWidget {
  const AiStatusChip({super.key});

  @override
  State<AiStatusChip> createState() => _AiStatusChipState();
}

class _AiStatusChipState extends State<AiStatusChip> {
  bool checking = true;
  String? problem;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    setState(() {
      checking = true;
      problem = null;
    });
    String? p;
    try {
      await AiAdvisor.ping();
    } on AiUnavailable catch (e) {
      p = e.message;
    } catch (_) {
      p = 'Cloud AI check failed.';
    }
    if (!mounted) return;
    setState(() {
      problem = p;
      checking = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final ok = !checking && problem == null;
    final color = checking ? kMuted : (ok ? kRiskLow : kRiskMid);
    final text = checking
        ? 'Checking cloud AI...'
        : (ok
            ? 'Cloud AI connected'
            : '$problem On-device AI still works. Tap to retry.');
    return GestureDetector(
      onTap: _check,
      child: Row(
        children: [
          Icon(Icons.circle, size: 10, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: TextStyle(color: color, fontSize: 13)),
          ),
        ],
      ),
    );
  }
}

/// One cloud AI call: looks at the photo, names the condition and gives
/// simple steps. Falls back to the offline guidance if it cannot answer.
class AiExpertCard extends StatefulWidget {
  final XFile? leafImage;
  final String crop;
  final String symptom;
  final String localDisease;
  final bool localUsable; // the offline model gave a real answer
  final String fallback; // offline guidance
  final ValueChanged<Diagnosis>? onResult;

  const AiExpertCard({
    super.key,
    required this.leafImage,
    required this.crop,
    required this.symptom,
    required this.localDisease,
    required this.localUsable,
    required this.fallback,
    this.onResult,
  });

  @override
  State<AiExpertCard> createState() => _AiExpertCardState();
}

class _AiExpertCardState extends State<AiExpertCard> {
  Diagnosis? diag;
  String note = '';
  bool loading = true;
  String language = 'English';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => run());
  }

  Future<void> run() async {
    final image = widget.leafImage;
    if (image == null) {
      setState(() => loading = false);
      return;
    }
    setState(() {
      loading = true;
      note = '';
    });

    Diagnosis? d;
    String msg = '';
    try {
      final bytes = await image.readAsBytes();
      final isPng = image.path.toLowerCase().endsWith('.png');
      d = await AiAdvisor.diagnose(
        bytes: bytes,
        mime: isPng ? 'image/png' : 'image/jpeg',
        crop: widget.crop,
        symptom: widget.symptom,
        language: language,
        localPrediction: widget.localUsable ? widget.localDisease : null,
      );
    } on AiUnavailable catch (e) {
      msg = e.message;
    } catch (_) {
      msg = 'Cloud AI could not answer.';
    }

    if (!mounted) return;
    setState(() {
      diag = d ?? diag;
      note = msg;
      loading = false;
    });
    if (d != null) widget.onResult?.call(d);
  }

  String _norm(String s) => s.toLowerCase().replaceAll(RegExp(r'[^a-z]'), '');

  bool? get _agree {
    final d = diag;
    if (d == null || !d.isLeaf || !widget.localUsable) return null;
    final a = _norm(widget.localDisease);
    final b = _norm(d.condition);
    if (b.isEmpty || b == 'unknown') return null;
    return a.contains(b) || b.contains(a);
  }

  List<Widget> _stepList(List<String> steps) {
    return [
      for (int i = 0; i < steps.length; i++)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 11,
                backgroundColor: kLime,
                child: Text('${i + 1}',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w800)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(steps[i],
                    style: const TextStyle(fontSize: 15, height: 1.35)),
              ),
            ],
          ),
        ),
    ];
  }

  // Works with no internet.
  List<Widget> _offlineContent() {
    // Structured offline advice is for the offline model's answers.
    // Crops without an offline model use their knowledge-base text.
    final useGuide = widget.localUsable ||
        widget.localDisease.toLowerCase().contains('not sure');
    final g = useGuide ? offlineGuideFor(widget.localDisease, language) : null;
    if (g == null) {
      return [
        Text(widget.fallback,
            style: const TextStyle(fontSize: 15, height: 1.4)),
      ];
    }
    return [
      const Text('Offline guidance (no internet needed)',
          style: TextStyle(fontWeight: FontWeight.w700, color: kLeaf)),
      const SizedBox(height: 8),
      Text(g.summary, style: const TextStyle(fontSize: 15, height: 1.4)),
      ..._stepList(g.steps),
      const SizedBox(height: 10),
      Text(g.callExpert,
          style: const TextStyle(
              fontSize: 14, fontWeight: FontWeight.w600, color: kInk)),
    ];
  }

  List<Widget> _cloudContent(Diagnosis d) {
    if (!d.isLeaf) {
      return [
        const Text(
          'This does not look like a plant leaf. Retake the photo: one leaf, close-up, daylight, plain background.',
          style: TextStyle(fontSize: 15, height: 1.4),
        ),
      ];
    }
    final agree = _agree;
    return [
      Text('Cloud AI sees: ${d.plant}, ${d.condition} (${d.confidence} confidence)',
          style: const TextStyle(fontWeight: FontWeight.w700, color: kLeaf)),
      if (agree != null) ...[
        const SizedBox(height: 6),
        Text(
          agree
              ? 'Both AIs agree.'
              : 'The two AIs disagree. Treat this as uncertain and ask an expert.',
          style: TextStyle(
              fontWeight: FontWeight.w700,
              color: agree ? kRiskLow : kRiskMid),
        ),
      ],
      if (d.summary.isNotEmpty) ...[
        const SizedBox(height: 10),
        Text(d.summary, style: const TextStyle(fontSize: 15, height: 1.4)),
      ],
      ..._stepList(d.steps),
      if (d.callExpert.isNotEmpty) ...[
        const SizedBox(height: 10),
        Text(d.callExpert,
            style: const TextStyle(
                fontSize: 14, fontWeight: FontWeight.w600, color: kInk)),
      ],
    ];
  }

  @override
  Widget build(BuildContext context) {
    final d = diag;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: panel(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text('What to do now',
                    style: TextStyle(
                        fontSize: 17, fontWeight: FontWeight.w800, color: kInk)),
              ),
              DropdownButton<String>(
                value: language,
                underline: const SizedBox.shrink(),
                items: const ['English', 'Hindi']
                    .map((l) => DropdownMenuItem(value: l, child: Text(l)))
                    .toList(),
                onChanged: loading
                    ? null
                    : (v) {
                        if (v == null || v == language) return;
                        setState(() => language = v);
                        run();
                      },
              ),
            ],
          ),
          const SizedBox(height: 6),
          if (loading) ...[
            const LinearProgressIndicator(color: kLime),
            const SizedBox(height: 8),
            const Text('Cloud AI is looking at your photo...',
                style: TextStyle(color: kMuted)),
          ] else if (d != null) ...[
            ..._cloudContent(d),
          ] else ...[
            ..._offlineContent(),
            if (note.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text('$note Showing offline guidance.',
                  style: const TextStyle(color: kMuted, fontSize: 13)),
            ],
            TextButton.icon(
              onPressed: run,
              icon: const Icon(Icons.refresh),
              label: const Text('Try cloud AI again'),
            ),
          ],
          if (!loading && d != null && note.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('$note Showing the earlier answer.',
                style: const TextStyle(color: kMuted, fontSize: 12)),
          ],
          const SizedBox(height: 10),
          const Text(
            'Kisan Call Centre (toll free): 1800-180-1551',
            style: TextStyle(
                color: kLeaf, fontWeight: FontWeight.w700, fontSize: 13.5),
          ),
        ],
      ),
    );
  }
}
