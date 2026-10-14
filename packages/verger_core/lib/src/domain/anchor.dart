import 'dart:typed_data';

/// Rôle d'une ancre : énoncé dans le cours (recto) ou rédaction dans les
/// notes (verso).
enum AnchorRole { source, work }

/// Rectangle normalisé dans une page : origine en haut à gauche, coordonnées
/// entre 0 et 1 (indépendant de la résolution d'affichage).
final class NormalizedRect {
  const NormalizedRect(this.left, this.top, this.right, this.bottom)
    : assert(left <= right && top <= bottom);

  /// Rectangle défini par deux coins quelconques, borné à la page.
  factory NormalizedRect.fromCorners(
    double x1,
    double y1,
    double x2,
    double y2,
  ) {
    double c(double v) => v.clamp(0.0, 1.0);
    return NormalizedRect(
      c(x1 < x2 ? x1 : x2),
      c(y1 < y2 ? y1 : y2),
      c(x1 < x2 ? x2 : x1),
      c(y1 < y2 ? y2 : y1),
    );
  }

  final double left;
  final double top;
  final double right;
  final double bottom;

  double get width => right - left;
  double get height => bottom - top;

  @override
  bool operator ==(Object other) =>
      other is NormalizedRect &&
      other.left == left &&
      other.top == top &&
      other.right == right &&
      other.bottom == bottom;

  @override
  int get hashCode => Object.hash(left, top, right, bottom);

  @override
  String toString() => 'NormalizedRect($left, $top, $right, $bottom)';
}

/// Lien entre une connaissance et une zone d'un PDF.
final class Anchor {
  const Anchor({
    required this.id,
    required this.itemId,
    required this.documentId,
    required this.role,
    required this.page,
    required this.createdAt,
    this.region,
    this.textSnippet,
    this.snapshot,
    this.needsReview = false,
  });

  final String id;
  final String itemId;
  final String documentId;
  final AnchorRole role;

  /// Numéro de page (à partir de 1).
  final int page;

  /// Zone encadrée ; `null` : page entière.
  final NormalizedRect? region;

  /// Texte extrait de la zone (PDF de cours), pour relocaliser l'énoncé.
  final String? textSnippet;

  /// Miniature PNG de la zone : reste lisible même si le PDF change.
  final Uint8List? snapshot;

  /// La mise à jour du PDF n'a pas permis de recaler l'ancre avec certitude.
  final bool needsReview;

  final DateTime createdAt;
}
