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
| FSRS | Package `fsrs` (port officiel de py-fsrs, MIT, FSRS-6), derrière une interface `Scheduler` |
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
  scheduling/         interface Scheduler + FsrsScheduler (seul fichier qui importe `fsrs`)
  progress/           maîtrise, stades de croissance, agrégats par nœud
  review_queue/       priorisation des révisions
  interchange/        DTO JSON (export/import, arbres partageables)

app/                  application Flutter
  lib/data/           base drift, dépôts (repositories), mapping vers les types du core
  lib/features/       orchard, tree, review, item, documents, settings
  lib/orchard/        géométrie pure (layout) + rendu CustomPainter
```

- La logique métier ne voit que des types valeur ; drift n'est qu'un détail
  de persistance.
- Gestion d'état : `ChangeNotifier`/`ValueNotifier` + streams drift, sans
  framework supplémentaire tant que ce n'est pas nécessaire.

## Modèle de données

Noms génériques (pas spécifiques à l'agrégation) pour l'app universelle.

```
KnowledgeTree          un domaine (Algèbre, Analyse…) = un arbre du verger
  id, title, sortIndex, createdAt

KnowledgeNode          structure, profondeur libre (liste d'adjacence)
  id, treeId, parentId?, title, sortIndex
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
  état avant/après (stabilité, difficulté, phase, échéance), schedulerId

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
| 0 | Squelette Flutter, package core, CI (tests + exécutable Windows) |
| 1 | Domaine, adaptateur FSRS, maîtrise, file de révision + tests |
| 2 | Persistance drift + dépôts + tests |
| 3 | Vue Arbre (plan) : création d'arbres, nœuds, items |
| 4 | Révisions : file + session |
| 5 | Verger v0 (CustomPainter, descente par niveaux) |
| 6 | Export/import JSON + données d'exemple |
| post-MVP | PDF recto/verso, statistiques, LaTeX, programme officiel, iOS, Android… |
