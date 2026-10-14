import 'package:flutter/material.dart';

import 'home_shell.dart';
import 'theme.dart';

class VergerApp extends StatelessWidget {
  const VergerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Verger',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      home: const HomeShell(),
    );
  }
}
