import 'dart:typed_data';

import 'anchor.dart';
import 'ink.dart';
import 'rating.dart';

/// Note de travail : rédaction (texte, LaTeX entre `$…$` ou `$$…$$`)
/// éventuellement attachée à une zone d'un PDF et à une connaissance.
///
/// Une note liée à une connaissance lui sert de verso en révision. Elle
/// survit à la suppression du PDF ou de la connaissance (les liens sont
/// simplement retirés) : c'est l'écriture de l'utilisateur.
final class Note {
  const Note({
    required this.id,
    required this.body,
    required this.createdAt,
    required this.updatedAt,
    this.documentId,
    this.page,
    this.startMs,
    this.endMs,
    this.region,
    this.snapshot,
    this.itemId,
    this.ink,
    this.reviewRating,
  });

  final String id;

  /// Texte (LaTeX entre `$…$`) ; l'écriture manuscrite est dans [ink].
  final String body;

  final String? documentId;

  /// Page du PDF (à partir de 1).
  final int? page;

  /// Moment ou extrait d'une vidéo, en millisecondes.
  final int? startMs;
  final int? endMs;

  /// Zone du PDF à laquelle la note se rapporte ; `null` : page entière.
  final NormalizedRect? region;

  /// Miniature PNG de la zone.
  final Uint8List? snapshot;

  /// Connaissance dont la note est le verso.
  final String? itemId;

  /// Écriture manuscrite (traits au stylet), en plus du texte.
  final InkDrawing? ink;

  /// Tentative de révision : note prise pendant la révision de la
  /// connaissance [itemId], avant de révéler le verso, avec la note donnée
  /// (date : [createdAt]). Elle ne fait pas partie du verso.
  final Rating? reviewRating;

  bool get isReviewAttempt => reviewRating != null;

  /// Ni texte ni écriture.
  bool get isBlank => body.trim().isEmpty && (ink?.isEmpty ?? true);

  final DateTime createdAt;
  final DateTime updatedAt;

  /// Première ligne non vide, sans `$` ni puce : titre lisible.
  String get headline => noteHeadline(body);
}

/// Première ligne non vide d'un texte, sans `$` ni marque de liste ou de
/// titre Markdown.
String noteHeadline(String body) {
  for (final line in body.split('\n')) {
    final text = line
        .replaceAll(r'$', '')
        .replaceFirst(RegExp(r'^\s*([#>]+|[-*]\s)\s*'), '')
        .trim();
    if (text.isNotEmpty) return text;
  }
  return '';
}
