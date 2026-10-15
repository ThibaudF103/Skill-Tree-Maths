import 'dart:typed_data';

/// Nature d'un contenu pédagogique.
enum ResourceKind {
  /// PDF importé (copie conservée sur l'appareil).
  pdf,

  /// Vidéo en ligne (YouTube) : seule l'adresse est conservée.
  video,
}

/// Rattachement d'un contenu à un nœud de l'arbre (un contenu peut servir
/// à plusieurs nœuds, un nœud avoir plusieurs contenus).
typedef ResourceLink = ({String documentId, String nodeId});

/// Contenu pédagogique de la bibliothèque : PDF ou vidéo.
final class SourceDocument {
  const SourceDocument({
    required this.id,
    required this.title,
    required this.pageCount,
    required this.contentHash,
    required this.importedAt,
    this.version = 1,
    this.fingerprints = const [],
    this.newPages = const [],
    this.lastPage = 1,
    this.kind = ResourceKind.pdf,
    this.url,
  });

  final String id;
  final String title;
  final ResourceKind kind;

  /// Adresse d'origine : la vidéo, ou le PDF à télécharger (paquets).
  final String? url;

  /// Nombre de pages (0 pour une vidéo).
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

  bool get isPdf => kind == ResourceKind.pdf;
  bool get isVideo => kind == ResourceKind.video;
}
