# Verger — architecture et décisions

Application de suivi de progression (préparation de l'agrégation externe de
mathématiques), pensée pour devenir une application d'apprentissage universelle.

## Principe directeur

```
Arbre de connaissances (programme)
        ↓
connaissances personnelles (items)
        ↓
historique de révision (append-only)
        ↓
ordonnanceur (FSRS, remplaçable)
        ↓
progression (calculée, jamais stockée)
        ↓
visualisation (verger, remplaçable)
```

Chaque flèche est une frontière de code. La visualisation et l'ordonnanceur
peuvent être remplacés sans toucher au stockage.

## Décisions validées

| Sujet | Décision |
|---|---|
| Plateforme | **Flutter** (Dart). Cibles : Windows (dès maintenant), web, iPad/iPhone, Android |
| Plateforme principale | iPad (UI pensée grand écran d'abord) |
| Build sans Mac | GitHub Actions : exécutable Windows téléchargeable. iOS plus tard (Apple Developer + Codemagic/TestFlight) |
| Développement | Dans l'environnement cloud de Claude Code ; le PC sert uniquement à tester les builds |
| Persistance | SQLite local via `drift`, 100 % hors ligne. Export/import JSON |
| FSRS | **Portage FSRS-6 de py-fsrs 6.3.2** (MIT) derrière l'interface `Scheduler`, validé contre des valeurs de référence. Le package Dart `fsrs` 2.0.1 a été écarté : il diverge de l'implémentation officielle (voir « FSRS » ci-dessous) |
| Stratégie de révision | Paramètres FSRS par défaut (rétention 0,90). `LearningPlan` (date cible, rétention) prévu mais non utilisé |
| Rattachement des items | À n'importe quel nœud de l'arbre |
| Maîtrise initiale | Évaluation initiale facultative = première révision FSRS (pas de curseur manuel) |
| Métaphore | définition → feuille · énoncé (théorème, proposition, lemme…) → fleur · exercice → fruit |
| Notes | Pas d'intégration CollaNote. Les notes sont importées sous forme de PDF exportés |
| Langue | Interface en français, code en anglais |

## Couches

```
packages/core/        Dart pur, aucune dépendance Flutter
  domain/             types valeur : ItemKind, Rating, SchedulingState, ReviewRecord…
  scheduling/         interface Scheduler + FsrsScheduler (portage FSRS-6)
  progress/           maîtrise, stades de croissance, agrégats par nœud
  review_queue/       priorisation des révisions
  interchange/        DTO JSON (export/import, arbres partageables)

packages/verger_data/ persistance : schéma drift (SQLite), VergerStore (seule API vue par l'app)

app/                  application Flutter
  lib/features/       orchard, tree, review, item, documents, settings
  lib/orchard/        géométrie pure (layout) + rendu CustomPainter
```

- La logique métier ne voit que des types valeur ; drift n'est qu'un détail
  de persistance, testé en Dart pur (`dart test`, base en mémoire et fichier).
- Base ouverte via `drift_flutter` : fichier SQLite natif (Windows, iOS,
  Android), SQLite WebAssembly sur le web (`web/sqlite3.wasm`,
  `web/drift_worker.js`, versions alignées sur les packages `sqlite3` et `drift`).
- Gestion d'état : `ChangeNotifier`/`ValueNotifier` + streams drift, sans
  framework supplémentaire tant que ce n'est pas nécessaire.

## Modèle de données

Noms génériques (pas spécifiques à l'agrégation) pour l'app universelle.

```
KnowledgeNode          structure, profondeur libre (liste d'adjacence)
                       un nœud sans parent = un arbre du verger (Algèbre, Analyse…)
  id, parentId?, title, sortIndex, createdAt
  curriculumKey?       clé stable pour ré-importer un programme sans rien perdre
  origin               official | user

KnowledgeItem          ce que j'ai décidé d'apprendre
  id, nodeId, kind, title, body?, createdAt, updatedAt, suspended
  kind                 definition | statement(theorem|proposition|lemma|property|corollary) | exercise
  — état d'ordonnancement, aplati pour pouvoir trier/filtrer —
  due, stability?, difficulty?, phase (new|learning|review|relearning),
  step?, lastReview?, reps, lapses

ReviewLog              append-only, source de vérité (permet de rejouer l'historique)
  id, itemId, reviewedAt, rating, durationMs?,
  stateBefore / stateAfter (JSON de SchedulingState), schedulerId

Settings               clé → JSON (réglages de révision : SchedulerSettings)

Document               PDF importé (copie dans la bibliothèque de l'app)
  id, title, role (course|notes), storedFile, pageCount, contentHash, importedAt, version
  pageFingerprints     empreinte visuelle réduite de chaque page (recalage des ancres)

Anchor                 lien item ↔ zone d'un PDF
  id, itemId, documentId, role (source|work), page,
  region? (rectangle normalisé 0–1), snapshot (image), textSnippet?, needsReview

LearningPlan           (prévu, non utilisé dans le MVP) par arbre : date cible, rétention visée
```

La maîtrise n'est **pas** stockée : elle est calculée à partir de l'état FSRS
(rétention actuelle R(t) et stabilité). Changer la règle de croissance ne
nécessite aucune migration.

## FSRS

- `FsrsScheduler` est un portage fidèle de l'ordonnanceur de py-fsrs 6.3.2
  (mêmes valeurs par défaut que py-fsrs, utilisées par le test de référence).
- Réglages de l'application (`SchedulerSettings`, persistés) : rétention 0,90,
  étapes d'apprentissage **6 h, 1 j** et de réapprentissage **6 h, 1 j**.
  Première révision d'une connaissance nouvelle : Again → 6 h, Hard → 15 h,
  Good → 1 j, Easy → directement en révision espacée.
- Les poids FSRS par défaut conviennent tant que l'historique est court ; après
  quelques centaines de révisions, ils pourront être ré-optimisés sur
  l'historique personnel (optimiseur de py-fsrs, hors application).
- `test/fsrs_reference_test.dart` rejoue 8 scénarios calculés par py-fsrs
  (`tool/generate_fsrs_reference.py`) : stabilité, difficulté, phase et
  échéance concordent exactement. À relancer à chaque montée de version.
- Le package Dart `fsrs` 2.0.1 a été écarté après comparaison : il laisse
  « Hard » faire baisser la stabilité en apprentissage et borne la difficulté
  cible, contrairement à py-fsrs actuel ; ses paramètres par défaut sont aussi
  plus anciens.
- Aléa des intervalles (« fuzz ») déterministe, initialisé par l'identifiant de
  la connaissance : l'intervalle affiché sur chaque bouton est exactement celui
  appliqué, et des connaissances créées ensemble sont dispersées.
- Chaque révision est enregistrée avec l'état avant/après et l'identifiant de
  l'ordonnanceur (`fsrs-6/r0.90`) ; `replay` recalcule l'état depuis l'historique.

## Maîtrise

```
maîtrise = R(t) × min(1, ln(1 + S) / ln(1 + 90 j))
```

R(t) : probabilité de rappel actuelle (baisse si on tarde à réviser) ;
S : stabilité, sur une échelle logarithmique, avec une cible de 90 jours
(réglable). Une connaissance nouvelle a une maîtrise nulle.

## File de révision

1. Étapes d'apprentissage / réapprentissage arrivées à échéance.
2. Révisions dues avant la fin de la journée, probabilité de rappel la plus
   faible d'abord.
3. Nouvelles connaissances, les plus anciennes d'abord (limite facultative).

Liste des révisions : En retard / Aujourd'hui / Demain / Plus tard / Nouvelles,
selon la journée locale.

## Stades de croissance (première version, ajustable)

| Stade | Condition |
|---|---|
| hiver (nœud vide) | aucun item |
| bourgeon | item jamais révisé |
| pousse | en apprentissage / réapprentissage |
| jeune | en révision, stabilité < 7 j |
| développé | stabilité 7–30 j |
| mûr | stabilité ≥ 30 j |

Indicateur séparé « à arroser » : échéance dépassée.

## Persistance

- `VergerStore` : nœuds (création, renommage, déplacement avec contrôle des
  cycles, suppression refusée si non vide sauf en récursif), connaissances,
  révisions (trace + nouvel état dans une même transaction, refus d'une
  révision calculée sur un état périmé), réglages.
- Schéma versionné (`schemaVersion`) ; schémas exportés dans
  `packages/verger_data/drift_schemas/` pour tester les migrations futures.

## PDF et notes manuscrites : recto / verso

- **Recto** : ancre `source` sur le PDF de cours (énoncé).
- **Verso** : ancre `work` sur le PDF des notes (rédaction manuscrite exportée de CollaNote).
- En révision : on affiche le recto, l'utilisateur tente de reproduire, « Révéler » affiche le verso, puis note.
- Flux : encadrer une zone dans la visionneuse → « Créer une connaissance » (recto) ou « Attacher comme rédaction » (verso).
- Notes en un seul carnet : à chaque fin de session, export PDF → « Mettre à jour le document ».
  L'app compare les empreintes de pages, recale les ancres si des pages ont été insérées,
  et liste les **nouvelles pages** pour attacher rapidement les versos.
- Chaque ancre garde une miniature : le verso reste visible même si une ancre est cassée.

## Plan

| Étape | Contenu |
|---|---|
| 0 | Squelette Flutter, package core, CI (tests + exécutable Windows) ✅ |
| 1 | Domaine, adaptateur FSRS, maîtrise, file de révision + tests ✅ |
| 2 | Persistance drift + dépôts + tests ✅ |
| 3 | Vue Arbres (plan) : création d'arbres, nœuds, items ✅ |
| 4 | Révisions : file + session ✅ |
| 5 | Verger v0 (CustomPainter, descente par niveaux) |
| 6 | Export/import JSON + données d'exemple |
| post-MVP | PDF recto/verso, statistiques, LaTeX, programme officiel, iOS, Android… |
