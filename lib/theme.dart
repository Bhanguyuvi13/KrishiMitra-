import 'package:flutter/material.dart';

// Colours taken from the KrishiMitra logo.
const Color kLeaf = Color(0xFF1B5E20); // deep leaf green
const Color kLime = Color(0xFF5FA52A); // fresh green
const Color kSun = Color(0xFFF5A623); // sun amber
const Color kPaper = Color(0xFFFAFBF6); // logo background
const Color kInk = Color(0xFF1E2B1F); // main text
const Color kMuted = Color(0xFF6B7868); // secondary text
const Color kLine = Color(0xFFE1E8DA); // thin borders

const Color kRiskLow = Color(0xFF2E7D32);
const Color kRiskMid = Color(0xFFE09A12);
const Color kRiskHigh = Color(0xFFC8402E);

// A quiet bordered box used for every section.
BoxDecoration panel({Color color = Colors.white, double radius = 18}) {
  return BoxDecoration(
    color: color,
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: kLine),
  );
}

ThemeData buildTheme() {
  return ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(seedColor: kLeaf),
    scaffoldBackgroundColor: kPaper,
  );
}
