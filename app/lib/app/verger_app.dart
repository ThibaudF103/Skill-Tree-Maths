import 'package:flutter/material.dart';
import 'package:verger_data/verger_data.dart';

import 'app_scope.dart';
import 'home_shell.dart';
import 'theme.dart';

class VergerApp extends StatelessWidget {
  const VergerApp({super.key, required this.store});

  final VergerStore store;

  @override
  Widget build(BuildContext context) {
    return AppScope(
      store: store,
      child: MaterialApp(
        title: 'Verger',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(Brightness.light),
        darkTheme: buildTheme(Brightness.dark),
        home: const HomeShell(),
      ),
    );
  }
}
