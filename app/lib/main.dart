import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter/material.dart';
import 'package:verger_data/verger_data.dart';

import 'app/verger_app.dart';

void main() {
  final database = VergerDatabase(
    driftDatabase(
      name: 'verger',
      web: DriftWebOptions(
        sqlite3Wasm: Uri.parse('sqlite3.wasm'),
        driftWorker: Uri.parse('drift_worker.js'),
      ),
    ),
  );
  runApp(VergerApp(store: VergerStore(database)));
}
