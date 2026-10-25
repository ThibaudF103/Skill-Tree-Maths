import 'package:verger_core/verger_core.dart';

/// Ce qui a déjà été tiré d'une page : recto, verso, notes.
typedef PageCoverage = ({int recto, int verso, int notes});

/// Couverture page par page d'un PDF (pages numérotées à partir de 1).
Map<int, PageCoverage> pageCoverage(
  Iterable<Anchor> anchors, [
  Iterable<Note> notes = const [],
]) {
  final result = <int, PageCoverage>{};
  PageCoverage at(int page) => result[page] ?? (recto: 0, verso: 0, notes: 0);
  for (final a in anchors) {
    final page = a.page;
    if (page == null) continue;
    final c = at(page);
    result[page] = a.role == AnchorRole.source
        ? (recto: c.recto + 1, verso: c.verso, notes: c.notes)
        : (recto: c.recto, verso: c.verso + 1, notes: c.notes);
  }
  for (final n in notes) {
    final page = n.page;
    if (page == null) continue;
    final c = at(page);
    result[page] = (recto: c.recto, verso: c.verso, notes: c.notes + 1);
  }
  return result;
}

/// Extrait d'une vidéo, en millisecondes (fin inconnue : point) : [label]
/// est le titre de la connaissance ou de la note, [id] celui de la
/// connaissance (extrait) ou de la note (`role` nul).
typedef TimeSpan = ({
  int start,
  int? end,
  AnchorRole? role,
  String label,
  String id,
});

/// Extraits et notes d'une vidéo, pour la frise de couverture ; [titles]
/// donne le titre des connaissances.
List<TimeSpan> videoCoverage(
  Iterable<Anchor> anchors,
  Iterable<Note> notes, {
  Map<String, String> titles = const {},
}) => [
  for (final a in anchors)
    if (a.startMs != null)
      (
        start: a.startMs!,
        end: a.endMs,
        role: a.role,
        label: titles[a.itemId] ?? 'Connaissance',
        id: a.itemId,
      ),
  for (final n in notes)
    if (n.startMs != null)
      (
        start: n.startMs!,
        end: n.endMs,
        role: null,
        label: n.headline.isNotEmpty ? n.headline : 'Note',
        id: n.id,
      ),
]..sort((a, b) => a.start.compareTo(b.start));

/// Extraits en cours de lecture à [ms] ; un extrait sans fin reste actif
/// trois secondes.
List<TimeSpan> spansAt(Iterable<TimeSpan> spans, int ms) => [
  for (final s in spans)
    if (s.start <= ms && ms < (s.end ?? s.start + 3000)) s,
];
