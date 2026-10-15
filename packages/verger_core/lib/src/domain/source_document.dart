import 'dart:typed_data';

/// Rôle d'un PDF : cours (énoncés, recto) ou notes manuscrites (verso).
enum DocumentRole { course, notes }

/// PDF importé dans la bibliothèque de l'application (copie).
final class SourceDocument {
  const SourceDocument({
    required this.id,
    required this.title,
    required this.role,
    required this.pageCount,
    required this.contentHash,
    required this.importedAt,
    this.version = 1,
    this.fingerprints = const [],
    this.newPages = const [],
    this.lastPage = 1,
  });

  final String id;
  final String title;
  final DocumentRole role;
  final int pageCount;

  /// Empreinte du fichier (SHA-256) : détecte un import identique.
  final String contentHash;
  final DateTime importedAt;

  /// Incrémentée à chaque mise à jour du fichier.
  final int version;

  /// Empreinte visuelle réduite de chaque page (voir `remapPages`).
  final List<Uint8List> fingerprints;

  /// Pages apparues lors de la dernière mise à jour (numérotées à partir de 1).
  final List<int> newPages;

  /// Dernière page consultée (reprise de lecture).
  final int lastPage;
}
