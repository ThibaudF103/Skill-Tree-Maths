import 'package:flutter/material.dart';
import 'package:verger_core/verger_core.dart';
import 'package:verger_data/verger_data.dart';

import 'app_scope.dart';
import 'home_shell.dart';
import 'resume.dart';
import 'theme.dart';

class VergerApp extends StatefulWidget {
  const VergerApp({super.key, required this.store, required this.scheduler});

  final VergerStore store;
  final Scheduler scheduler;

  @override
  State<VergerApp> createState() => _VergerAppState();
}

class _VergerAppState extends State<VergerApp> {
  late Scheduler _scheduler = widget.scheduler;
  late final _resume = ResumeTracker(widget.store);

  /// Enregistre la page ouverte dès que l'application passe en
  /// arrière-plan : iOS peut la fermer ensuite sans prévenir.
  late final _lifecycle = AppLifecycleListener(
    onInactive: _resume.flush,
    onHide: _resume.flush,
    onPause: _resume.flush,
  );

  @override
  void initState() {
    super.initState();
    _lifecycle;
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    _resume.dispose();
    super.dispose();
  }

  Future<void> _reloadSettings() async {
    final settings = await widget.store.schedulerSettings();
    if (mounted) setState(() => _scheduler = settings.build());
  }

  @override
  Widget build(BuildContext context) {
    return AppScope(
      store: widget.store,
      scheduler: _scheduler,
      reloadSettings: _reloadSettings,
      resume: _resume,
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
