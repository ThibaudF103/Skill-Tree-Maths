import 'dart:async';

import 'package:flutter/material.dart';
import 'package:verger_core/verger_core.dart';
import 'package:verger_data/verger_data.dart';

import '../features/documents/document_viewer_page.dart';
import '../features/items/item_detail_page.dart';
import '../features/video/video_page.dart';

/// Reprise au lancement : mémorise les pages de contenu ouvertes (PDF,
/// vidéo, fiche d'une connaissance) pour les rouvrir au prochain lancement.
///
/// iOS ferme l'application laissée longtemps en arrière-plan : on enregistre
/// donc à l'ouverture de chaque page, à chaque changement de page ou de
/// position (regroupés), et dès que l'application passe en arrière-plan.
/// Quitter une page normalement (retour) l'oublie.
class ResumeTracker {
  ResumeTracker(this._store);

  final VergerStore _store;

  /// Pages ouvertes, dans l'ordre de la pile de navigation.
  final _pages = <Object, OpenPage>{};
  Timer? _save;
  List<OpenPage>? _saved;

  /// Faux tant que la reprise du lancement n'est pas faite : rien n'est
  /// enregistré avant, pour ne pas effacer la page à rouvrir.
  var _ready = false;

  /// Délai de regroupement des enregistrements.
  static const delay = Duration(seconds: 2);

  /// Déclare une page ouverte ; renvoie le jeton à passer à [update] et
  /// [close].
  Object open(OpenPage page) {
    final token = Object();
    _pages[token] = page;
    unawaited(flush());
    return token;
  }

  /// Nouvelle page du PDF, nouvelle position de la vidéo…
  void update(Object token, OpenPage page) {
    if (!_pages.containsKey(token) || _pages[token] == page) return;
    _pages[token] = page;
    _save?.cancel();
    _save = Timer(delay, flush);
  }

  /// La page est quittée normalement.
  void close(Object token) {
    if (_pages.remove(token) != null) unawaited(flush());
  }

  /// Enregistre tout de suite (passage en arrière-plan).
  Future<void> flush() async {
    _save?.cancel();
    _save = null;
    if (!_ready) return;
    final pages = _pages.values.toList();
    if (_saved != null && _listEquals(_saved!, pages)) return;
    _saved = pages;
    await _store.setOpenPages(pages);
  }

  void dispose() => _save?.cancel();

  /// Rouvre, au-dessus de l'accueil, les pages enregistrées encore valables ;
  /// oublie les autres (document supprimé, PDF absent de l'appareil…).
  Future<void> restore(NavigatorState navigator) async {
    try {
      final saved = await _store.openPages();
      final valid = <OpenPage>[];
      for (final page in saved) {
        if (await _exists(page)) valid.add(page);
      }
      // Les pages poussées ci-dessous se déclarent elles-mêmes.
      _saved = const [];
      _ready = true;
      if (valid.isEmpty) {
        if (saved.isNotEmpty) await _store.setOpenPages(const []);
        return;
      }
      if (!navigator.mounted) return;
      for (final page in valid) {
        unawaited(
          navigator.push(
            MaterialPageRoute<void>(
              builder: (_) => (debugPageBuilder ?? build)(page),
            ),
          ),
        );
      }
    } finally {
      _ready = true;
    }
  }

  Future<bool> _exists(OpenPage page) async {
    switch (page.kind) {
      case OpenPageKind.item:
        return await _store.item(page.id) != null;
      case OpenPageKind.document:
        final document = await _store.document(page.id);
        return document?.kind == ResourceKind.pdf &&
            await _store.hasDocumentFile(page.id);
      case OpenPageKind.video:
        final document = await _store.document(page.id);
        return document?.kind == ResourceKind.video;
    }
  }

  /// Remplace [build] dans les tests (pas de lecteur PDF ni vidéo).
  @visibleForTesting
  static Widget Function(OpenPage page)? debugPageBuilder;

  /// Page à rouvrir pour [page].
  static Widget build(OpenPage page) => switch (page.kind) {
    OpenPageKind.document => DocumentViewerPage(
      documentId: page.id,
      initialPage: page.page,
    ),
    OpenPageKind.video => VideoPage(
      documentId: page.id,
      startMs: page.positionMs,
    ),
    OpenPageKind.item => ItemDetailPage(itemId: page.id),
  };

  static bool _listEquals(List<OpenPage> a, List<OpenPage> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
