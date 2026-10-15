import 'dart:typed_data';

import 'anchor.dart';

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
    this.region,
    this.snapshot,
    this.itemId,
  });

  final String id;

  /// Contenu ; prévu pour accueillir plus tard l'encre (traits au stylet).
  final String body;

  final String? documentId;

  /// Page du PDF (à partir de 1).
  final int? page;

  /// Zone du PDF à laquelle la note se rapporte ; `null` : page entière.
  final NormalizedRect? region;

  /// Miniature PNG de la zone.
  final Uint8List? snapshot;

  /// Connaissance dont la note est le verso.
  final String? itemId;

  final DateTime createdAt;
  final DateTime updatedAt;

  /// Première ligne non vide, sans LaTeX : titre lisible.
  String get headline {
    for (final line in body.split('\n')) {
      final text = line
          .replaceAll(r'$', '')
          .replaceFirst(RegExp(r'^\s*([#>]+|[-*]\s)\s*'), '')
          .trim();
      if (text.isNotEmpty) return text;
    }
    return '';
  }
}
