/// Genre de page de contenu que l'application sait rouvrir au lancement.
enum OpenPageKind { document, video, item }

/// Page de contenu ouverte (PDF, vidéo, fiche d'une connaissance), à rouvrir
/// telle quelle au prochain lancement : iOS ferme l'application laissée en
/// arrière-plan, et l'on veut reprendre où l'on en était.
final class OpenPage {
  const OpenPage({
    required this.kind,
    required this.id,
    this.page,
    this.positionMs,
    this.endMs,
    this.attachToItemId,
  });

  const OpenPage.document(this.id, {this.page, this.attachToItemId})
    : kind = OpenPageKind.document,
      positionMs = null,
      endMs = null;

  const OpenPage.video(
    this.id, {
    this.positionMs,
    this.endMs,
    this.attachToItemId,
  }) : kind = OpenPageKind.video,
       page = null;

  const OpenPage.item(this.id)
    : kind = OpenPageKind.item,
      page = null,
      positionMs = null,
      endMs = null,
      attachToItemId = null;

  final OpenPageKind kind;

  /// Document (PDF ou vidéo) ou connaissance.
  final String id;

  /// Page affichée d'un PDF (à partir de 1).
  final int? page;

  /// Position de lecture d'une vidéo, en millisecondes.
  final int? positionMs;

  /// Fin de l'extrait vidéo en cours de lecture, en millisecondes.
  final int? endMs;

  /// Connaissance à laquelle la page attache directement la zone ou
  /// l'extrait marqué.
  final String? attachToItemId;

  OpenPage withPage(int page) => OpenPage(
    kind: kind,
    id: id,
    page: page,
    positionMs: positionMs,
    endMs: endMs,
    attachToItemId: attachToItemId,
  );

  OpenPage withPosition(int positionMs) => OpenPage(
    kind: kind,
    id: id,
    page: page,
    positionMs: positionMs,
    endMs: endMs,
    attachToItemId: attachToItemId,
  );

  Map<String, Object?> toJson() => {
    'kind': kind.name,
    'id': id,
    'page': ?page,
    'positionMs': ?positionMs,
    'endMs': ?endMs,
    'attachToItemId': ?attachToItemId,
  };

  /// `null` si [json] est illisible (valeur d'une ancienne version, par
  /// exemple) : la reprise est alors simplement ignorée.
  static OpenPage? fromJson(Object? json) {
    if (json is! Map) return null;
    final kind = OpenPageKind.values
        .where((k) => k.name == json['kind'])
        .firstOrNull;
    final id = json['id'];
    final page = json['page'];
    final position = json['positionMs'];
    final end = json['endMs'];
    final attachTo = json['attachToItemId'];
    if (kind == null || id is! String) return null;
    return OpenPage(
      kind: kind,
      id: id,
      page: page is int && page >= 1 ? page : null,
      positionMs: position is int && position >= 0 ? position : null,
      endMs: end is int && end >= 0 ? end : null,
      attachToItemId: attachTo is String ? attachTo : null,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is OpenPage &&
      other.kind == kind &&
      other.id == id &&
      other.page == page &&
      other.positionMs == positionMs &&
      other.endMs == endMs &&
      other.attachToItemId == attachToItemId;

  @override
  int get hashCode =>
      Object.hash(kind, id, page, positionMs, endMs, attachToItemId);

  @override
  String toString() => 'OpenPage(${toJson()})';
}
