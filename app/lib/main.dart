import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:verger_data/verger_data.dart';

import 'app/verger_app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await pdfrxFlutterInitialize();
  final store = VergerStore(
    VergerDatabase(
      driftDatabase(
        name: 'verger',
        web: DriftWebOptions(
          sqlite3Wasm: Uri.parse('sqlite3.wasm'),
          driftWorker: Uri.parse('drift_worker.js'),
        ),
      ),
    ),
  );
  final settings = await store.schedulerSettings();
  runApp(VergerApp(store: store, scheduler: settings.build()));
}
