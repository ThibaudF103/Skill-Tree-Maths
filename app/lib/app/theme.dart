import 'package:flutter/material.dart';

/// Palette calme inspirée d'un verger : vert sauge, fond clair et neutre.
const _seed = Color(0xFF5B7F5E);

ThemeData buildTheme(Brightness brightness) {
  final scheme = ColorScheme.fromSeed(seedColor: _seed, brightness: brightness);
  return ThemeData(
    colorScheme: scheme,
    useMaterial3: true,
    visualDensity: VisualDensity.standard,
  );
}
