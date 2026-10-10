import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'ai_advisor.dart';
import 'ai_expert_card.dart';
import 'plant_classifier.dart';
import 'severity.dart';
import 'theme.dart';

void main() {
  runApp(const KrishiMitraApp());
}

class KrishiMitraApp extends StatelessWidget {
  const KrishiMitraApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'KrishiMitra',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      home: const SplashPage(),
    );
  }
}

// ---------------------------------------------------------------------------
// Splash
// ---------------------------------------------------------------------------

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  bool visible = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 150), () {
      if (mounted) setState(() => visible = true);
    });
    Future.delayed(const Duration(milliseconds: 2800), () {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 600),
          pageBuilder: (_, __, ___) => const HomePage(),
          transitionsBuilder: (_, animation, __, child) =>
              FadeTransition(opacity: animation, child: child),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kPaper,
      body: Center(
        child: AnimatedOpacity(
          opacity: visible ? 1 : 0,
          duration: const Duration(milliseconds: 900),
          child: AnimatedScale(
            scale: visible ? 1 : 0.88,
            duration: const Duration(milliseconds: 900),
            curve: Curves.easeOutBack,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset(
                  'assets/icon/logo_full.png',
                  width: 300,
                  errorBuilder: (_, __, ___) => const Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.eco, size: 90, color: kLeaf),
                      SizedBox(height: 10),
                      Text('KrishiMitra',
                          style: TextStyle(
                              fontSize: 34,
                              fontWeight: FontWeight.w800,
                              color: kLeaf)),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: 120,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: const LinearProgressIndicator(
                      minHeight: 4,
                      color: kLime,
                      backgroundColor: kLine,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Home
// ---------------------------------------------------------------------------

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final ImagePicker _picker = ImagePicker();
  final PlantClassifier _classifier = PlantClassifier();

  List<Map<String, dynamic>> diseaseData = [];

  String selectedCrop = 'Tomato';
  String selectedSymptom = 'Brown/Dark spots';

  XFile? leafImage;

  bool loadingDatabase = true;
  bool analyzing = false;

  static const Set<String> aiCrops = {'Tomato', 'Potato', 'Bell Pepper'};

  static const Map<String, String> crops = {
    'Tomato': '\u{1F345}',
    'Potato': '\u{1F954}',
    'Bell Pepper': '\u{1FAD1}',
    'Rice': '\u{1F33E}',
    'Wheat': '\u{1F33E}',
    'Maize': '\u{1F33D}',
    'Cotton': '\u2601\uFE0F',
    'Sugarcane': '\u{1F38B}',
    'Chickpea': '\u{1F331}',
  };

  static const Map<String, String> symptoms = {
    'Brown/Dark spots': '\u{1F7E4}',
    'Orange/Rust-like marks': '\u{1F7E0}',
    'Yellowing leaves': '\u{1F7E1}',
    'White powder': '\u26AA',
    'Wilting/Drooping': '\u{1F940}',
    'Leaf drying': '\u{1F342}',
  };

  @override
  void initState() {
    super.initState();
    loadDatabase();
  }

  @override
  void dispose() {
    _classifier.dispose();
    super.dispose();
  }

  Future<void> loadDatabase() async {
    try {
      final String jsonString =
          await rootBundle.loadString('assets/crop_diseases.json');
      final List<dynamic> jsonData = jsonDecode(jsonString);
      setState(() {
        diseaseData =
            jsonData.map((item) => Map<String, dynamic>.from(item)).toList();
        loadingDatabase = false;
      });
    } catch (e) {
      setState(() => loadingDatabase = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not load crop database: $e')),
        );
      }
    }
  }

  Future<void> pickLeafImage(ImageSource source) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1024,
        maxHeight: 1024,
      );
      if (image != null) {
        setState(() => leafImage = image);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to select image: $e')),
        );
      }
    }
  }

  void _openResult(Map<String, dynamic> result) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ResultPage(
          crop: selectedCrop,
          symptom: selectedSymptom,
          leafImage: leafImage,
          result: result,
        ),
      ),
    );
  }

  Future<void> analyzeCrop() async {
    if (loadingDatabase) return;

    if (leafImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add a leaf photo first.')),
      );
      return;
    }

    setState(() => analyzing = true);

    try {
      // Offline AI model for Tomato, Potato and Bell Pepper.
      if (aiCrops.contains(selectedCrop)) {
        final bytes = await leafImage!.readAsBytes();
        Map<String, dynamic> result;
        try {
          final PlantPrediction prediction =
              await _classifier.predict(bytes, selectedCrop);
          result = {
            'crop': prediction.crop,
            'disease': prediction.disease,
            'guidance':
                _guidanceForDisease(prediction.disease, prediction.healthy),
            'ai': true,
            'confidence': prediction.confidence,
            'healthy': prediction.healthy,
            'top3': prediction.top3,
          };
        } catch (e) {
          // The offline model failed: still open the result and let the
          // cloud AI answer.
          debugPrint('Offline model error: $e');
          result = {
            'crop': selectedCrop,
            'disease': 'Not Sure - Offline model unavailable',
            'guidance':
                'The offline model could not read this photo. Follow the cloud AI advice below, or retake the photo in daylight.',
            'ai': true,
            'confidence': 0.0,
            'healthy': false,
            'top3': <MapEntry<String, double>>[],
          };
        }

        if (!mounted) return;
        setState(() => analyzing = false);
        _openResult(result);
        return;
      }

      // Knowledge base for the other crops.
      await Future.delayed(const Duration(milliseconds: 400));

      Map<String, dynamic>? bestMatch;
      for (final item in diseaseData) {
        final String crop = item['crop']?.toString() ?? '';
        final List<dynamic> itemSymptoms = item['symptoms'] ?? [];
        if (crop == selectedCrop && itemSymptoms.contains(selectedSymptom)) {
          bestMatch = item;
          break;
        }
      }

      bestMatch ??= {
        'crop': selectedCrop,
        'disease': 'Possible Crop Health Issue',
        'symptoms': [selectedSymptom],
        'guidance':
            'Monitor the affected crop and consult an agriculture expert for confirmation.',
        'ai': false,
      };
      bestMatch['ai'] = false;

      if (!mounted) return;
      setState(() => analyzing = false);
      _openResult(bestMatch);
    } catch (e) {
      if (!mounted) return;
      setState(() => analyzing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('AI analysis failed: $e'),
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  String _guidanceForDisease(String disease, bool healthy) {
    if (healthy) {
      return 'The AI model indicates that the leaf appears healthy. Continue normal crop monitoring and good agricultural practices.';
    }

    final lower = disease.toLowerCase();

    if (lower.contains('not sure')) {
      return 'The on-device AI is not sure about this photo. Retake it in daylight: one leaf, close-up, plain background. See the Cloud AI second opinion below.';
    }
    if (lower.contains('early blight')) {
      return 'Possible early blight detected. Remove severely affected leaves, maintain field hygiene, avoid prolonged leaf wetness and consult an agriculture expert for suitable disease-management advice.';
    }
    if (lower.contains('late blight')) {
      return 'Possible late blight detected. Closely monitor the crop, remove severely affected material where appropriate and seek expert confirmation for disease-management measures.';
    }
    if (lower.contains('bacterial spot')) {
      return 'Possible bacterial spot detected. Avoid unnecessary leaf wetness, maintain field hygiene and consult an agriculture expert for confirmation and suitable management.';
    }
    if (lower.contains('leaf mold')) {
      return 'Possible leaf mold detected. Improve air circulation, avoid excessive leaf moisture and seek expert confirmation.';
    }
    if (lower.contains('mosaic')) {
      return 'Possible mosaic virus symptoms detected. Isolate or monitor affected plants and consult an agriculture expert for confirmation and management advice.';
    }
    if (lower.contains('yellow leaf curl') || lower.contains('yellowleaf')) {
      return 'Possible yellow leaf curl symptoms detected. Monitor affected plants and consult an agriculture expert, especially for vector and disease-management advice.';
    }
    if (lower.contains('septoria')) {
      return 'Possible Septoria leaf spot detected. Maintain field hygiene, remove severely affected material where appropriate and seek expert confirmation.';
    }
    if (lower.contains('leaf spot')) {
      return 'Possible leaf spot detected. Monitor the affected plants, maintain field hygiene and consult an agriculture expert for confirmation.';
    }
    return 'The AI detected a possible crop-health condition. Monitor the affected plant and consult an agriculture expert before making treatment decisions.';
  }

  void openHistory() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const HistoryPage()),
    );
  }

  // ----- UI pieces ---------------------------------------------------------

  Widget _tag(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white38),
      ),
      child: Text(
        text,
        style: const TextStyle(
            color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _hero() {
    final top = MediaQuery.of(context).padding.top;
    return Container(
      width: double.infinity,
      color: kLeaf,
      child: Stack(
        children: [
          // The sun from the logo.
          Positioned(
            right: -34,
            top: -34,
            child: Container(
              width: 150,
              height: 150,
              decoration:
                  const BoxDecoration(color: kSun, shape: BoxShape.circle),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(20, top + 10, 8, 26),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    ClipOval(
                      child: Container(
                        color: kPaper,
                        padding: const EdgeInsets.all(3),
                        child: Image.asset(
                          'assets/icon/icon.png',
                          width: 38,
                          height: 38,
                          errorBuilder: (_, __, ___) =>
                              const Icon(Icons.eco, color: kLeaf, size: 32),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      'KrishiMitra',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w800),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: openHistory,
                      icon: const Icon(Icons.history, color: kLeaf),
                      tooltip: 'Saved reports',
                    ),
                  ],
                ),
                const SizedBox(height: 26),
                const Text('\u0928\u092E\u0938\u094D\u0924\u0947',
                    style: TextStyle(color: Colors.white70, fontSize: 16)),
                const SizedBox(height: 4),
                const Text(
                  'Check your crop\nbefore it spreads.',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 31,
                      height: 1.1,
                      fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _tag('Two-AI check'),
                      _tag('Measures severity'),
                      _tag('Tracks recovery'),
                      _tag('Works offline'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _section(String title, Widget child, {String? hint}) {
    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  fontSize: 18, fontWeight: FontWeight.w800, color: kInk)),
          if (hint != null)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(hint,
                  style: const TextStyle(color: kMuted, fontSize: 13)),
            ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _cropChips() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: crops.entries.map((e) {
        final selected = selectedCrop == e.key;
        final ai = aiCrops.contains(e.key);
        return ChoiceChip(
          label: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(e.value, style: const TextStyle(fontSize: 17)),
              const SizedBox(width: 6),
              Text(e.key),
              if (ai) ...[
                const SizedBox(width: 3),
                Icon(Icons.bolt,
                    size: 15, color: selected ? kSun : kRiskMid),
              ],
            ],
          ),
          selected: selected,
          showCheckmark: false,
          backgroundColor: Colors.white,
          selectedColor: kLeaf,
          side: const BorderSide(color: kLine),
          labelStyle: TextStyle(
            color: selected ? Colors.white : kInk,
            fontWeight: FontWeight.w600,
          ),
          onSelected: (_) => setState(() => selectedCrop = e.key),
        );
      }).toList(),
    );
  }

  Widget _symptomChips() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: symptoms.entries.map((e) {
        final selected = selectedSymptom == e.key;
        return ChoiceChip(
          label: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(e.value, style: const TextStyle(fontSize: 14)),
              const SizedBox(width: 6),
              Text(e.key),
            ],
          ),
          selected: selected,
          showCheckmark: false,
          backgroundColor: Colors.white,
          selectedColor: kLeaf,
          side: const BorderSide(color: kLine),
          labelStyle: TextStyle(
            color: selected ? Colors.white : kInk,
            fontWeight: FontWeight.w600,
          ),
          onSelected: (_) => setState(() => selectedSymptom = e.key),
        );
      }).toList(),
    );
  }

  Widget _viewfinder() {
    final image = leafImage;
    return GestureDetector(
      onTap: () => pickLeafImage(ImageSource.camera),
      child: SizedBox(
        width: double.infinity,
        child: AspectRatio(
          aspectRatio: 4 / 3,
          child: Stack(
            children: [
              Positioned.fill(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(22),
                  child: image == null
                      ? Container(
                          color: const Color(0xFFEAF2E3),
                          child: const Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.eco, size: 54, color: kLime),
                                SizedBox(height: 8),
                                Text('Place one leaf in the frame',
                                    style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        color: kInk)),
                                SizedBox(height: 2),
                                Text('Daylight, close-up, plain background',
                                    style: TextStyle(
                                        color: kMuted, fontSize: 13)),
                              ],
                            ),
                          ),
                        )
                      : Image.file(File(image.path), fit: BoxFit.cover),
                ),
              ),
              Positioned.fill(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: CustomPaint(painter: _BracketPainter(kLime)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _photoButtons() {
    return Row(
      children: [
        Expanded(
          child: FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: kLeaf,
              minimumSize: const Size.fromHeight(50),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
            onPressed: () => pickLeafImage(ImageSource.camera),
            icon: const Icon(Icons.photo_camera_outlined),
            label: const Text('Camera'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: kLeaf,
              side: const BorderSide(color: kLeaf),
              minimumSize: const Size.fromHeight(50),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
            onPressed: () => pickLeafImage(ImageSource.gallery),
            icon: const Icon(Icons.photo_library_outlined),
            label: const Text('Gallery'),
          ),
        ),
      ],
    );
  }

  Widget _scanButton() {
    return SizedBox(
      width: double.infinity,
      height: 58,
      child: FilledButton.icon(
        style: FilledButton.styleFrom(
          backgroundColor: kSun,
          foregroundColor: kInk,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        ),
        onPressed: analyzing ? null : analyzeCrop,
        icon: analyzing
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: kInk),
              )
            : const Icon(Icons.document_scanner_outlined),
        label: Text(
          analyzing ? 'Analysing...' : 'Scan leaf',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kPaper,
      body: loadingDatabase
          ? const Center(child: CircularProgressIndicator(color: kLime))
          : SingleChildScrollView(
              child: Column(
                children: [
                  _hero(),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _section('Which crop?', _cropChips(),
                            hint: 'The bolt marks crops with the offline AI model.'),
                        _section('Leaf photo', Column(
                          children: [
                            _viewfinder(),
                            const SizedBox(height: 12),
                            _photoButtons(),
                          ],
                        )),
                        _section('What do you see?', _symptomChips()),
                        const SizedBox(height: 26),
                        _scanButton(),
                        const SizedBox(height: 12),
                        const AiStatusChip(),
                        const SizedBox(height: 18),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: panel(color: const Color(0xFFF1F6EC)),
                          child: const Text(
                            'Results are preliminary. Confirm with an agriculture officer before treating. Kisan Call Centre (toll free): 1800-180-1551',
                            style: TextStyle(color: kMuted, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

// Four green corner brackets, like the scan frame in the logo.
class _BracketPainter extends CustomPainter {
  final Color color;
  _BracketPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;
    const len = 34.0;
    final w = size.width;
    final h = size.height;
    canvas.drawPath(
        Path()..moveTo(0, len)..lineTo(0, 0)..lineTo(len, 0), p);
    canvas.drawPath(
        Path()..moveTo(w - len, 0)..lineTo(w, 0)..lineTo(w, len), p);
    canvas.drawPath(
        Path()..moveTo(0, h - len)..lineTo(0, h)..lineTo(len, h), p);
    canvas.drawPath(
        Path()..moveTo(w - len, h)..lineTo(w, h)..lineTo(w, h - len), p);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ---------------------------------------------------------------------------
// Result
// ---------------------------------------------------------------------------

class ResultPage extends StatefulWidget {
  final String crop;
  final String symptom;
  final XFile? leafImage;
  final Map<String, dynamic> result;

  const ResultPage({
    super.key,
    required this.crop,
    required this.symptom,
    required this.leafImage,
    required this.result,
  });

  @override
  State<ResultPage> createState() => _ResultPageState();
}

class _ResultPageState extends State<ResultPage> {
  Diagnosis? cloud;
  double? severityPct;
  bool saved = false;

  Map<String, dynamic> get result => widget.result;
  String get localDisease =>
      result['disease']?.toString() ?? 'Possible Crop Health Issue';
  String get guidance =>
      result['guidance']?.toString() ?? 'Consult an agriculture expert.';
  bool get isAI => result['ai'] == true;
  bool get localNotSure => localDisease.toLowerCase().contains('not sure');
  bool get localHealthy => result['healthy'] == true;
  double get conf => result['confidence'] is num
      ? (result['confidence'] as num).toDouble()
      : 0.0;

  // When the cloud AI is available and sure enough, it decides the verdict.
  // Without internet, the offline model decides.
  bool get useCloud {
    final c = cloud;
    return c != null &&
        c.isLeaf &&
        c.condition.toLowerCase() != 'unknown' &&
        (localNotSure || !isAI || c.confidence.toLowerCase() != 'low');
  }

  String _cap(String s) =>
      s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';

  String get title => useCloud ? _cap(cloud!.condition) : localDisease;
  bool get healthy =>
      useCloud ? cloud!.condition.toLowerCase().contains('healthy') : localHealthy;
  bool get notSure => !useCloud && localNotSure;

  Future<void> saveReport() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final List<String> reports = prefs.getStringList('reports') ?? [];

    reports.add(jsonEncode({
      'crop': widget.crop,
      'symptom': widget.symptom,
      'condition': title,
      'confidence': (isAI && !useCloud && !localNotSure) ? conf : null,
      'ai': isAI || useCloud,
      'severity': severityPct,
      'date': DateTime.now().toIso8601String(),
    }));
    await prefs.setStringList('reports', reports);

    if (!mounted) return;
    setState(() => saved = true);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Report saved.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final image = widget.leafImage;
    final List<MapEntry<String, double>> top3 = result['top3'] is List
        ? (result['top3'] as List).whereType<MapEntry<String, double>>().toList()
        : <MapEntry<String, double>>[];

    final bool showGauge =
        !useCloud && isAI && result['confidence'] is num && !localNotSure;

    final Color statusColor = healthy
        ? const Color(0xFF2E7D32)
        : (notSure ? const Color(0xFF5B6B7A) : const Color(0xFFC8501E));
    final String statusText =
        healthy ? 'Looks healthy' : (notSure ? 'Not sure' : 'Possible problem');
    final IconData statusIcon = healthy
        ? Icons.check_circle
        : (notSure ? Icons.help : Icons.warning_amber_rounded);

    final String source = useCloud
        ? (isAI && !localNotSure
            ? 'Cloud AI (Gemini vision). Offline model said: $localDisease'
            : 'Cloud AI (Gemini vision)')
        : (!isAI
            ? 'Knowledge base. Cloud AI checks the photo below.'
            : (localNotSure
                ? 'Offline model is not sure about this photo.'
                : 'Offline AI model (MobileNetV2, runs on this phone)'));

    return Scaffold(
      backgroundColor: kPaper,
      appBar: AppBar(
        title: const Text('Scan result',
            style: TextStyle(fontWeight: FontWeight.w800)),
        backgroundColor: kPaper,
        foregroundColor: kInk,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
        children: [
          // Verdict
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: statusColor,
              borderRadius: BorderRadius.circular(22),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (image != null) ...[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: Image.file(File(image.path),
                            width: 88, height: 88, fit: BoxFit.cover),
                      ),
                      const SizedBox(width: 14),
                    ],
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(statusIcon, color: Colors.white, size: 18),
                              const SizedBox(width: 6),
                              Text(statusText,
                                  style: const TextStyle(
                                      color: Colors.white70,
                                      fontWeight: FontWeight.w700)),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(title,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 22,
                                  height: 1.15,
                                  fontWeight: FontWeight.w800)),
                          const SizedBox(height: 4),
                          Text('${widget.crop}, ${widget.symptom}',
                              style: const TextStyle(
                                  color: Colors.white70, fontSize: 13)),
                        ],
                      ),
                    ),
                    if (showGauge)
                      SizedBox(
                        width: 62,
                        height: 62,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            CircularProgressIndicator(
                              value: conf.clamp(0.0, 1.0).toDouble(),
                              strokeWidth: 6,
                              color: Colors.white,
                              backgroundColor: Colors.white24,
                            ),
                            Text('${(conf * 100).round()}%',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800)),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(source,
                    style: const TextStyle(color: Colors.white70, fontSize: 12.5)),
              ],
            ),
          ),

          if (top3.isNotEmpty && !localNotSure && !useCloud) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: panel(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Other possibilities',
                      style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: kInk)),
                  for (final e in top3)
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Flexible(child: Text(e.key)),
                              Text('${(e.value * 100).toStringAsFixed(0)}%',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w800)),
                            ],
                          ),
                          const SizedBox(height: 4),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: LinearProgressIndicator(
                              value: e.value.clamp(0.0, 1.0).toDouble(),
                              minHeight: 8,
                              color: statusColor,
                              backgroundColor: kLine,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],

          if (image != null) ...[
            const SizedBox(height: 14),
            SeverityCard(
              leafImage: image,
              onResult: (p) {
                if (mounted) setState(() => severityPct = p);
              },
            ),
          ],

          const SizedBox(height: 14),
          AiExpertCard(
            leafImage: widget.leafImage,
            crop: widget.crop,
            symptom: widget.symptom,
            localDisease: localDisease,
            localUsable: isAI && !localNotSure,
            fallback: guidance,
            onResult: (d) {
              if (mounted) setState(() => cloud = d);
            },
          ),

          const SizedBox(height: 18),
          SizedBox(
            height: 54,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: kLeaf,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: saved ? null : saveReport,
              icon: Icon(saved ? Icons.check : Icons.bookmark_add_outlined),
              label: Text(saved ? 'Saved' : 'Save report',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w700)),
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'Preliminary AI guidance. The models can be wrong, especially on field photos that differ from their training data. Confirm with an agriculture expert before any treatment.',
            style: TextStyle(color: kMuted, fontSize: 12.5),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// History and recovery tracker
// ---------------------------------------------------------------------------

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  List<Map<String, dynamic>> reports = [];

  @override
  void initState() {
    super.initState();
    loadReports();
  }

  Future<void> loadReports() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final List<String> saved = prefs.getStringList('reports') ?? [];
    setState(() {
      reports = saved
          .map((item) => Map<String, dynamic>.from(jsonDecode(item)))
          .toList()
          .reversed
          .toList();
    });
  }

  String _fmt(String? iso) {
    final d = DateTime.tryParse(iso ?? '')?.toLocal();
    if (d == null) return '';
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.day)}-${two(d.month)}-${d.year}  ${two(d.hour)}:${two(d.minute)}';
  }

  // Compares this scan with the previous scan of the same crop.
  Widget? _trend(int index) {
    final cur = reports[index]['severity'];
    if (cur is! num) return null;
    for (int j = index + 1; j < reports.length; j++) {
      final prev = reports[j]['severity'];
      if (reports[j]['crop'] == reports[index]['crop'] && prev is num) {
        final diff = cur.toDouble() - prev.toDouble();
        IconData icon;
        Color color;
        String text;
        if (diff <= -3) {
          icon = Icons.trending_down;
          color = kRiskLow;
          text = 'Improving: damage down ${(-diff).round()} points since the last scan';
        } else if (diff >= 3) {
          icon = Icons.trending_up;
          color = kRiskHigh;
          text = 'Getting worse: damage up ${diff.round()} points since the last scan';
        } else {
          icon = Icons.trending_flat;
          color = kMuted;
          text = 'About the same as the last scan';
        }
        return Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Row(
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(text,
                    style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w700,
                        fontSize: 12.5)),
              ),
            ],
          ),
        );
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kPaper,
      appBar: AppBar(
        title: const Text('Saved reports',
            style: TextStyle(fontWeight: FontWeight.w800)),
        backgroundColor: kPaper,
        foregroundColor: kInk,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: reports.isEmpty
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.description_outlined, size: 64, color: kMuted),
                  SizedBox(height: 12),
                  Text('No saved reports yet',
                      style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: kInk)),
                  SizedBox(height: 4),
                  Text('Scan a leaf and tap Save report.',
                      style: TextStyle(color: kMuted)),
                ],
              ),
            )
          : Column(
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Text(
                    'Recovery tracker: scan the same crop again after treatment to see if the damage is shrinking.',
                    style: TextStyle(color: kMuted, fontSize: 13),
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                    itemCount: reports.length,
                    itemBuilder: (context, index) {
                      final report = reports[index];
                      final bool ai = report['ai'] == true;
                      final conf = report['confidence'];
                      final sev = report['severity'];
                      final trend = _trend(index);
                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(14),
                        decoration: panel(),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CircleAvatar(
                              backgroundColor: const Color(0xFFEAF2E3),
                              child: Icon(ai ? Icons.bolt : Icons.eco,
                                  color: kLeaf),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    report['condition']?.toString() ??
                                        'Crop health report',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 16),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                      '${report['crop']}, ${report['symptom']}',
                                      style: const TextStyle(color: kMuted)),
                                  Text(_fmt(report['date']?.toString()),
                                      style: const TextStyle(
                                          color: kMuted, fontSize: 12)),
                                  if (trend != null) trend,
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                if (sev is num)
                                  Text('Damage ${sev.round()}%',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w800,
                                          color: kInk,
                                          fontSize: 13)),
                                if (conf is num)
                                  Text('AI ${(conf * 100).round()}%',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          color: kLeaf,
                                          fontSize: 12)),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }
}
