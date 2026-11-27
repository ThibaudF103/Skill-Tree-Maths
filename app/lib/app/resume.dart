import 'dart:async';

import 'package:flutter/material.dart';
import 'package:verger_core/verger_core.dart';
import 'package:verger_data/verger_data.dart';

import '../features/documents/document_viewer_page.dart';
import '../features/items/item_detail_page.dart';
import '../features/video/video_page.dart';

/// Relève, juste avant un enregistrement, l'état courant d'une page (la
/// position d'une vidéo, lue de façon asynchrone) ; `null` : inchangé.
typedef OpenPageRefresh = Future<OpenPage?> Function();

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
  final _refreshers = <Object, OpenPageRefresh>{};
  Timer? _save;

  /// Dernière liste enregistrée avec succès.
  List<OpenPage>? _saved;

  /// Faux tant que la reprise du lancement n'est pas faite : rien n'est
  /// enregistré avant, pour ne pas effacer la page à rouvrir.
  var _ready = false;

  /// Délai de regroupement des enregistrements.
  static const delay = Duration(seconds: 2);

  /// Attente maximale des relevés avant l'enregistrement d'arrière-plan.
  static const refreshTimeout = Duration(milliseconds: 500);

  /// Déclare une page ouverte ; renvoie le jeton à passer à [update] et
  /// [close]. [refresh] est attendu avant l'enregistrement du passage en
  /// arrière-plan.
  Object open(OpenPage page, {OpenPageRefresh? refresh}) {
    final token = Object();
    _pages[token] = page;
    if (refresh != null) _refreshers[token] = refresh;
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
    _refreshers.remove(token);
    if (_pages.remove(token) != null) unawaited(flush());
  }

  /// Enregistre tout de suite ; [refresh] : relève d'abord l'état courant
  /// des pages (passage en arrière-plan).
  Future<void> flush({bool refresh = false}) async {
    _save?.cancel();
    _save = null;
    if (!_ready) return;
    if (refresh && _refreshers.isNotEmpty) {
      await Future.wait([
        for (final MapEntry(key: token, value: read) in _refreshers.entries)
          read()
              .then((page) {
                if (page != null && _pages.containsKey(token)) {
                  _pages[token] = page;
                }
              })
              .timeout(refreshTimeout, onTimeout: () {})
              .catchError((_) {}),
      ]);
    }
    final pages = _pages.values.toList();
    if (_saved != null && _listEquals(_saved!, pages)) return;
    await _store.setOpenPages(pages);
    // Seulement après succès : un échec sera retenté au prochain appel.
    _saved = pages;
  }

  void dispose() => _save?.cancel();

  /// Rouvre, au-dessus de l'accueil, les pages enregistrées encore valables ;
  /// oublie les autres (document supprimé, PDF absent de l'appareil…).
  Future<void> restore(NavigatorState navigator) async {
    final routes = <Route<void>>[];
    try {
      for (final page in await _store.openPages()) {
        final widget = await _resolve(page);
        if (widget != null) {
          routes.add(MaterialPageRoute<void>(builder: (_) => widget));
        }
      }
    } finally {
      _ready = true;
    }
    if (routes.isNotEmpty && navigator.mounted) {
      // Les pages poussées se déclarent elles-mêmes, ce qui enregistre la
      // liste complète (y compris celles ouvertes pendant la reprise).
      for (final route in routes) {
        unawaited(navigator.push(route));
      }
    } else {
      // Rien à rouvrir : enregistre l'état réel (pages ouvertes entre-temps,
      // ou aucune, ce qui oublie les pages disparues).
      await flush();
    }
  }

  /// Page à rouvrir pour [page], ou `null` si son contenu a disparu.
  Future<Widget?> _resolve(OpenPage page) async {
    final attachId = page.attachToItemId;
    final attachTo = attachId == null ? null : await _store.item(attachId);
    switch (page.kind) {
      case OpenPageKind.item:
        if (await _store.item(page.id) == null) return null;
      case OpenPageKind.document:
        final document = await _store.document(page.id);
        if (document?.kind != ResourceKind.pdf ||
            !await _store.hasDocumentFile(page.id)) {
          return null;
        }
      case OpenPageKind.video:
        final document = await _store.document(page.id);
        if (document?.kind != ResourceKind.video) return null;
    }
    return (debugPageBuilder ?? build)(page, attachTo: attachTo);
  }

  /// Remplace [build] dans les tests (pas de lecteur PDF ni vidéo).
  @visibleForTesting
  static Widget Function(OpenPage page, {KnowledgeItem? attachTo})?
  debugPageBuilder;

  /// Page à rouvrir pour [page] ; [attachTo] : connaissance de
  /// [OpenPage.attachToItemId], si elle existe encore.
  static Widget build(OpenPage page, {KnowledgeItem? attachTo}) =>
      switch (page.kind) {
        OpenPageKind.document => DocumentViewerPage(
          documentId: page.id,
          initialPage: page.page,
          attachToItem: attachTo,
        ),
        OpenPageKind.video => VideoPage(
          documentId: page.id,
          startMs: page.positionMs,
          // Extrait dépassé (lecture libre ensuite) : plus d'arrêt.
          endMs: (page.endMs ?? 0) > (page.positionMs ?? 0) ? page.endMs : null,
          attachToItem: attachTo,
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
