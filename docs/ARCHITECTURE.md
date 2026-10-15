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
  id, nodeId, kind, title, body?, level?, sortIndex, createdAt, updatedAt, suspended
  kind                 definition | statement (précision facultative : theorem|proposition|lemma|property|corollary) | exercise
  level                difficulté facultative d'un exercice : easy | medium | hard
  — état d'ordonnancement, aplati pour pouvoir trier/filtrer —
  due, stability?, difficulty?, phase (new|learning|review|relearning),
  step?, lastReview?, reps, lapses

ReviewLog              append-only, source de vérité (permet de rejouer l'historique)
  id, itemId, reviewedAt, rating, durationMs?,
  stateBefore / stateAfter (JSON de SchedulingState), schedulerId

Settings               clé → JSON (réglages de révision : SchedulerSettings)

Document (contenu)     PDF importé (copie dans la bibliothèque) ou vidéo en ligne
  id, title, kind (pdf|video), url?, storedFile (PDF), pageCount, contentHash,
  importedAt, version
  pageFingerprints     empreinte visuelle réduite de chaque page (recalage des ancres)

ResourceLink           contenu ↔ nœud (plusieurs à plusieurs ; un contenu rattaché
                       à un nœud sert aussi à toute sa descendance)

Anchor                 lien item ↔ endroit d'un contenu
  id, itemId, documentId, role (source|work),
  page? + region? (PDF, rectangle normalisé 0–1) ou startMs/endMs (extrait vidéo),
  snapshot (image), textSnippet?, needsReview

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

## Notes de travail et LaTeX (étape 8)

- **Note** : texte avec formules LaTeX (`$…$` dans le texte, `$$…$$`
  centrées, `\$` pour un dollar), éventuellement attachée à une zone d'un
  PDF (page, rectangle, miniature) et à une connaissance, dont elle devient
  le **verso** (affiché en révision). Une note survit à la suppression du
  PDF ou de la connaissance (liens mis à `NULL`). Prévue pour accueillir
  l'encre au stylet plus tard.
- **Visionneuse** : miniatures des pages et sommaire du PDF (panneau
  latéral), recherche dans le texte, reprise à la dernière page lue
  (`documents.last_page`), panneau de notes à droite (écran partagé sur
  grand écran, plein écran sur téléphone) ouvert par le bouton, un balayage
  depuis le bord droit ou un marqueur de note sur la page. Encadrer une
  zone → « Prendre une note sur cette zone ». Liens du PDF actifs (renvois
  internes via `goToDest`, liens web via url_launcher) ; l'appui long
  sélectionne un mot (`wordBounds`, coupure aux écarts visuels pour les PDF
  sans caractères d'espace) ; ouvrir un panneau garde la page ajustée à la
  largeur.
- **Recto / verso en PDF** : quand le PDF est sur l'appareil, une zone
  s'affiche en vectoriel avec texte sélectionnable (`PdfRegionView`, un
  `PdfViewer` figé et cadré sur la zone, document partagé avec la
  visionneuse) ; la miniature PNG sert pendant le chargement et en secours.
- **Depuis une note** : « Créer une connaissance » ou « Lier à une
  connaissance » ; la note devient le verso et, pour un cours, la zone
  devient le recto.
- **Fiche** : section Notes (rendu LaTeX, nouvelle note libre).
- Rendu LaTeX : `MathText` (flutter_math_fork, Apache 2.0), aussi pour le
  contenu des connaissances et l'aperçu dans l'éditeur.
- Schéma v4, migrations version par version (`stepByStep`). v4 : difficulté des exercices et ordre manuel des connaissances (`sortIndex`, l'ordre de création départage).

## Échange JSON (`VergerArchive`)

Un seul format (`{"format": "verger", "version": 1, …}`) pour deux usages :

- **Sauvegarde** : nœuds, connaissances (avec état FSRS), historique complet,
  réglages. « Restaurer » remplace toutes les données en conservant les
  identifiants.
- **Modèle d'arbre** (partage, programme officiel, exemple « Algèbre ») :
  nœuds et connaissances seulement ; à l'import, nouveaux identifiants et
  aucune progression. Champs facultatifs : `curriculumKey`, `body`, dates.

Validation à la lecture : format, version, références, cycles.
`packages/verger_core/tool/generate_demo_backup.dart` produit une sauvegarde
de démonstration (deux mois de révisions simulées).

## Paquets d'arbres (`.verger`, étape 10)

- Archive ZIP : `pack.json` (une `VergerArchive` : nœuds, connaissances sans
  état de révision, contenus, rattachements, ancres avec miniatures, notes)
  et `files/<id>.pdf` pour les PDF inclus.
- **Export** (menu d'un nœud, « Partager ») : la descendance du nœud, qui
  devient un arbre ; les contenus rattachés aux ancêtres sont rattachés à sa
  racine. PDF inclus, ou « par adresse » : un PDF muni d'une adresse de
  téléchargement (Bibliothèque) n'est pas embarqué, seuls son adresse et son
  empreinte voyagent (poly public, sans redistribuer le fichier).
- **Import** (menu Données, ou écran d'accueil vide) : nouveaux identifiants,
  aucune progression ; un contenu déjà présent (même SHA-256) est réutilisé ;
  un PDF absent est téléchargé puis analysé. S'il diffère de la version du
  paquet, ses ancres sont recalées par empreintes de pages (`updateDocument`).
  Un PDF introuvable n'empêche pas l'import (miniatures conservées).

## Contenus et recto / verso

- **Recto** : ancre `source` (énoncé encadré) ; **verso** : ancre `work`
  (rédaction). Tout PDF peut fournir l'un ou l'autre : la distinction
  cours / notes a disparu à l'étape 9 avec la prise de notes intégrée.
- **Contenus d'un nœud** (onglet Arbres) : PDF et vidéos rattachés au nœud,
  puis ceux hérités de ses ancêtres (« via … ») ; importer un PDF directement
  rattaché, rattacher un contenu existant, détacher.
- **Onglet Bibliothèque** : tous les contenus, filtrables par arbre (ou « non
  rattachés ») ; import (titre, branche de rattachement), rattachement, mise à
  jour (nouvelle version), renommage, suppression. Les PDF sont copiés dans la
  base (`document_files`, contenu séparé des métadonnées). Migration v5 : les
  PDF existants sont rattachés aux arbres des connaissances qui les utilisent.
- **Visionneuse** (pdfrx / PDFium, y compris sur le web en WebAssembly) :
  mode « Encadrer » → créer une connaissance depuis un énoncé (titre et
  contenu pré-remplis par le texte du PDF) ou attacher la zone comme recto /
  verso. Les ancres existantes sont dessinées sur les pages (bleu : recto,
  orange : verso) et ouvrent la connaissance.
- **Fiche d'une connaissance** : section Recto / verso (miniatures, ouvrir au
  bon endroit du PDF, retirer), « Attacher une zone d'un PDF » (on choisit
  recto ou verso en encadrant).
- **Révision** : le recto s'affiche sous le titre ; « Révéler » montre le verso
  (rédaction) et le contenu texte.
- **Miniatures** (PNG) stockées avec l'ancre : le verso reste lisible même si
  le PDF change ou est absent de l'appareil.
- **Mise à jour d'un carnet** : empreintes de pages 32×32 ; `remapPages`
  apparie les pages au rendu identique (plus longue sous-suite commune), puis
  les pages complétées (inclusion de l'encre). Ancres recalées ; page
  introuvable → « à vérifier ». Les nouvelles pages sont signalées dans la
  visionneuse pour y attacher les nouveaux versos. Testé sur de vrais PDF.
- **Sauvegarde JSON** : documents (sans contenu) et ancres (avec miniatures) ;
  une restauration conserve les PDF déjà présents sur l'appareil.
- Limite connue : contenu des PDF dans SQLite ; à surveiller si le carnet
  dépasse quelques centaines de Mo (migration possible vers des fichiers
  derrière la même API `VergerStore`).

## Plan

| Étape | Contenu |
|---|---|
| 0 | Squelette Flutter, package core, CI (tests + exécutable Windows) ✅ |
| 1 | Domaine, adaptateur FSRS, maîtrise, file de révision + tests ✅ |
| 2 | Persistance drift + dépôts + tests ✅ |
| 3 | Vue Arbres (plan) : création d'arbres, nœuds, items ✅ |
| 4 | Révisions : file + session ✅ |
| 5 | Verger v0 (CustomPainter, descente par niveaux) ✅ |
| 6 | Export/import JSON + données d'exemple ✅ |
| 7 | PDF recto/verso ✅ |
| 8 | Visionneuse améliorée, notes liées au PDF, LaTeX ✅ |
| 9 | Contenus (PDF, vidéos) rattachés aux nœuds, ancres généralisées, Bibliothèque ✅ |
| 10 | Paquets d'arbres : contenus, ancres et notes ; PDF inclus ou par référence ✅ |
| 11 | Vidéos YouTube : lecteur intégré, extraits recto/verso |
| ensuite | Déplacement par l'interface, LaTeX, statistiques, programme officiel, verger, iPad… |
