# Verger

Application de suivi de progression pour la préparation de l'agrégation externe
de mathématiques : chaque domaine est un arbre, chaque connaissance une feuille,
une fleur ou un fruit qui grandit au rythme de la répétition espacée (FSRS).

- Architecture et décisions : [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md)
- `packages/verger_core/` : logique métier pure (Dart)
- `app/` : application Flutter (Windows, web, iPad/iPhone, Android)

## Installer sur Windows

- Dernière version de `main` :
  [verger-windows.zip](https://github.com/ThibaudF103/Skill-Tree-Maths/releases/latest/download/verger-windows.zip).
- Version d'une PR : lien dans le commentaire « Exécutable Windows » de la PR.

Décompresser puis lancer `verger.exe` (Windows SmartScreen peut demander
« Exécuter quand même » : l'exécutable n'est pas signé).

## Installer sur iPad

Par TestFlight, mis à jour à chaque fusion dans `main` : configuration dans
[`docs/TESTFLIGHT.md`](docs/TESTFLIGHT.md).

## Sauvegarde

Onglet **Arbres** → menu ⋮ : exporter une sauvegarde (fichier JSON), la
restaurer, importer un arbre modèle ou ajouter l'exemple « Algèbre ».
Les données restent sur l'appareil : pensez à exporter régulièrement.

## Développement

```sh
cd packages/verger_core && dart test
cd app && flutter test && flutter run -d chrome
```
