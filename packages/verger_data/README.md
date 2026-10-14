# verger_data

Persistance locale (SQLite via [drift](https://drift.simonbinder.eu/)).
L'application ne voit que `VergerStore` et les types de `verger_core`.

```sh
dart run build_runner build   # après modification du schéma (database.dart)
dart test
```

Toute modification du schéma : incrémenter `schemaVersion`, écrire la
migration et exporter le schéma (`dart run drift_dev make-migrations`).
