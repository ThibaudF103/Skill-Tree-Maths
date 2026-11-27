import '../board/board_geometry.dart';

/// Provenance d'un nœud : programme importé ou créé par l'utilisateur.
enum NodeOrigin { official, user }

/// Nœud de la structure des connaissances (profondeur libre). Un nœud sans
/// parent est un arbre du verger (un domaine : Algèbre, Analyse…).
final class KnowledgeNode {
  const KnowledgeNode({
    required this.id,
    required this.title,
    required this.sortIndex,
    required this.createdAt,
    this.parentId,
    this.curriculumKey,
    this.origin = NodeOrigin.user,
    this.board,
  });

  final String id;
  final String? parentId;
  final String title;

  /// Rang parmi les frères.
  final int sortIndex;

  /// Clé stable dans un programme importé : permet de ré-importer le
  /// programme sans perdre les connaissances personnelles.
  final String? curriculumKey;
  final NodeOrigin origin;
  final DateTime createdAt;

  /// Région du nœud sur le tableau ; `null` tant qu'elle n'est pas placée
  /// (la mise en page automatique s'en charge).
  final BoardRect? board;

  bool get isTree => parentId == null;

  /// Identifiant réservé du nœud « Non classées » : un arbre créé à la
  /// demande pour les cartes déposées hors de toute région du tableau.
  static const unsortedId = 'verger-non-classees';

  /// Titre du nœud « Non classées » à sa création.
  static const unsortedTitle = 'Non classées';

  bool get isUnsorted => id == unsortedId;
}
