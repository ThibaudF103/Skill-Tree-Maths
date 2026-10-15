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

/// Extrait d'une vidéo, en millisecondes (fin inconnue : point).
typedef TimeSpan = ({int start, int? end, AnchorRole? role});

/// Extraits et notes d'une vidéo, pour la frise de couverture.
List<TimeSpan> videoCoverage(Iterable<Anchor> anchors, Iterable<Note> notes) =>
    [
      for (final a in anchors)
        if (a.startMs != null) (start: a.startMs!, end: a.endMs, role: a.role),
      for (final n in notes)
        if (n.startMs != null) (start: n.startMs!, end: n.endMs, role: null),
    ]..sort((a, b) => a.start.compareTo(b.start));
