# Verger

Application de suivi de progression pour la préparation de l'agrégation externe
de mathématiques : chaque domaine est un arbre, chaque connaissance une feuille,
une fleur ou un fruit qui grandit au rythme de la répétition espacée (FSRS).

- Architecture et décisions : [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md)
- `packages/verger_core/` : logique métier pure (Dart)
- `app/` : application Flutter (Windows, web, iPad/iPhone, Android)

## Tester sur Windows

1. Onglet **Actions** du dépôt GitHub → dernier run **CI** réussi.
2. Télécharger l'artefact **verger-windows** (zip), le décompresser.
3. Lancer `verger.exe` (Windows SmartScreen peut demander « Exécuter quand même » :
   l'exécutable n'est pas signé).

## Développement

```sh
cd packages/verger_core && dart test
cd app && flutter test && flutter run -d chrome
```
