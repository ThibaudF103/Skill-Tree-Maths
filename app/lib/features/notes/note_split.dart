import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Écran partagé pour prendre des notes en gardant le contenu sous les
/// yeux : le contenu (PDF, vidéo, fiche, carte de révision) en haut, la
/// note en bas, séparés par une poignée qu'on fait glisser pour régler la
/// hauteur de la note. Tirée au-delà de la plus grande hauteur, la poignée
/// aimante la note en plein écran ; au-delà de la plus petite, elle la
/// ferme (un voile l'annonce, une vibration marque le seuil).
///
/// Seule la poignée réagit au glissement : un trait du stylet dans la note
/// ne la déplace jamais. La hauteur choisie est mémorisée pendant la
/// session (la même pour tous les écrans). Sur un écran trop bas (téléphone,
/// clavier affiché), la note occupe tout l'écran. Le contenu garde son état
/// (page, zoom, lecture) quand la note s'ouvre, s'agrandit ou se ferme.
class NoteSplit extends StatefulWidget {
  const NoteSplit({
    super.key,
    required this.content,
    this.note,
    this.title,
    this.onClose,
  });

  final Widget content;

  /// La note ; `null` : le contenu seul.
  final Widget? note;

  /// Titre affiché sur la poignée.
  final Widget? title;

  /// Ferme la note (bouton de la poignée).
  final VoidCallback? onClose;

  static const minNoteHeight = 240.0;
  static const minContentHeight = 120.0;
  static const handleHeight = 36.0;

  /// Distance au-delà des bornes de la poignée à partir de laquelle la
  /// note s'aimante au relâcher : plein écran vers le haut, fermeture vers
  /// le bas (si [onClose] est donné).
  static const snapDistance = 60.0;

  /// Poignée (tests).
  static const handleKey = Key('note-split-handle');

  /// Voiles « Relâcher pour… » pendant le glissement (tests).
  static const maximizeHintKey = Key('note-split-maximize-hint');
  static const closeHintKey = Key('note-split-close-hint');

  /// Part de la hauteur donnée à la note, mémorisée pendant la session.
  static double _fraction = 0.45;

  /// Revient à la hauteur par défaut (tests).
  @visibleForTesting
  static void resetSize() => _fraction = 0.45;

  @override
  State<NoteSplit> createState() => _NoteSplitState();
}

class _NoteSplitState extends State<NoteSplit> {
  /// Note en plein écran (contenu masqué, mais conservé).
  var _maximized = false;

  /// Hauteur disponible au dernier affichage.
  var _total = 0.0;

  /// Pendant un glissement de la poignée : hauteur demandée par le doigt,
  /// sans bornes (au-delà, aimantation vers le plein écran ou la
  /// fermeture) ; `null` hors glissement.
  double? _dragHeight;

  /// Aimantation annoncée pendant le glissement (vibration au
  /// franchissement du seuil).
  _Snap _snap = _Snap.none;

  double get _maxNote => math.max(
    NoteSplit.minNoteHeight,
    _total - NoteSplit.handleHeight - NoteSplit.minContentHeight,
  );

  double get _noteHeight =>
      (_total * NoteSplit._fraction).clamp(NoteSplit.minNoteHeight, _maxNote);

  /// Hauteur de la note à l'écran : celle du doigt pendant un glissement,
  /// jusqu'au haut de l'écran (et jusqu'en bas si la note peut se fermer).
  double get _shownHeight => switch (_dragHeight) {
    final h? => h.clamp(
      widget.onClose == null ? NoteSplit.minNoteHeight : 0.0,
      _total - NoteSplit.handleHeight,
    ),
    null => _noteHeight,
  };

  _Snap _snapFor(double height) {
    if (height >= _maxNote + NoteSplit.snapDistance) return _Snap.maximize;
    if (widget.onClose != null &&
        height <= NoteSplit.minNoteHeight - NoteSplit.snapDistance) {
      return _Snap.close;
    }
    return _Snap.none;
  }

  /// Hauteur et plein écran d'avant le glissement : rendus s'il est
  /// annulé, et la hauteur gardée pour rouvrir une note fermée ainsi.
  var _startFraction = NoteSplit._fraction;
  var _startMaximized = false;

  void _dragStart(DragStartDetails _) {
    _startFraction = NoteSplit._fraction;
    _startMaximized = _maximized;
    setState(() {
      // Depuis le plein écran, la poignée part du haut de l'écran.
      final height = _maximized ? _total - NoteSplit.handleHeight : _noteHeight;
      _dragHeight = height;
      _snap = _snapFor(height);
      _maximized = false;
    });
  }

  void _drag(DragUpdateDetails d) {
    final from = _dragHeight;
    if (_total <= 0 || from == null) return;
    final height = from - d.delta.dy;
    final snap = _snapFor(height);
    if (snap != _snap && snap != _Snap.none) {
      unawaited(HapticFeedback.selectionClick());
    }
    // La hauteur n'est retenue qu'au relâcher (_dragEnd).
    setState(() {
      _dragHeight = height;
      _snap = snap;
    });
  }

  void _dragEnd([DragEndDetails? _]) {
    final height = _dragHeight;
    if (height == null) return;
    // Seuils de la mise en page actuelle : la hauteur disponible a pu
    // changer pendant le glissement (rotation, clavier).
    final snap = _snapFor(height);
    setState(() {
      _dragHeight = null;
      _snap = _Snap.none;
      switch (snap) {
        case _Snap.maximize:
          _maximized = true;
          // « Réduire » revient à la plus grande hauteur.
          NoteSplit._fraction = _maxNote / _total;
        case _Snap.close:
          // La note se rouvrira à sa hauteur d'avant le glissement.
          NoteSplit._fraction = _startFraction;
        case _Snap.none:
          NoteSplit._fraction =
              height.clamp(NoteSplit.minNoteHeight, _maxNote) / _total;
      }
    });
    if (snap == _Snap.close) widget.onClose?.call();
  }

  /// Glissement annulé (par le système) : rien n'est aimanté, la note
  /// reprend sa hauteur d'avant.
  void _dragCancel() {
    if (_dragHeight == null) return;
    setState(() {
      _dragHeight = null;
      _snap = _Snap.none;
      _maximized = _startMaximized;
      NoteSplit._fraction = _startFraction;
    });
  }

  @override
  void didUpdateWidget(NoteSplit old) {
    super.didUpdateWidget(old);
    // Une note refermée se rouvre à sa hauteur, pas en plein écran.
    if (widget.note == null) {
      _maximized = false;
      _dragHeight = null;
      _snap = _Snap.none;
    }
  }

  @override
  Widget build(BuildContext context) {
    final hint = Theme.of(
      context,
    ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.85);
    return LayoutBuilder(
      builder: (context, constraints) {
        _total = constraints.maxHeight;
        final note = widget.note;
        final compact =
            _total <
            NoteSplit.minNoteHeight +
                NoteSplit.handleHeight +
                NoteSplit.minContentHeight;
        final full = note != null && (compact || _maximized);
        final dragging = note != null && !full && _dragHeight != null;
        final noteHeight = note == null ? 0.0 : _shownHeight;
        // Le contenu garde au moins sa hauteur minimale : au-delà, la
        // poignée et la note passent par-dessus.
        final contentHeight = note == null
            ? _total
            : math.max(
                NoteSplit.minContentHeight,
                _total - noteHeight - NoteSplit.handleHeight,
              );
        final handleTop = full
            ? 0.0
            : _total - noteHeight - NoteSplit.handleHeight;
        return Stack(
          children: [
            // Toujours en premier : le contenu garde son état.
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              height: contentHeight,
              child: Offstage(offstage: full, child: widget.content),
            ),
            if (dragging)
              // Retour visuel : le contenu s'efface quand la note va
              // passer en plein écran. Clés : la poignée et la note gardent
              // leur état (glissement, éditeur) quand le voile apparaît.
              Positioned(
                key: const ValueKey('note-split-hint'),
                left: 0,
                right: 0,
                top: 0,
                height: contentHeight,
                child: _SnapHint(
                  key: NoteSplit.maximizeHintKey,
                  visible: _snap == _Snap.maximize,
                  icon: Icons.open_in_full,
                  label: 'Relâcher pour le plein écran',
                  color: hint,
                ),
              ),
            if (note != null) ...[
              Positioned(
                key: const ValueKey('note-split-handle-area'),
                left: 0,
                right: 0,
                top: handleTop,
                height: NoteSplit.handleHeight,
                child: _handle(context, compact: compact),
              ),
              Positioned(
                key: const ValueKey('note-split-note'),
                left: 0,
                right: 0,
                top: handleTop + NoteSplit.handleHeight,
                // Sous sa hauteur minimale, la note glisse vers le bas
                // au lieu de rétrécir.
                height: full
                    ? _total - NoteSplit.handleHeight
                    : math.max(noteHeight, NoteSplit.minNoteHeight),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    note,
                    if (dragging)
                      _SnapHint(
                        key: NoteSplit.closeHintKey,
                        visible: _snap == _Snap.close,
                        icon: Icons.close,
                        label: 'Relâcher pour fermer la note',
                        color: hint,
                        alignment: Alignment.topCenter,
                      ),
                  ],
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _handle(BuildContext context, {required bool compact}) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surfaceContainer,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border.symmetric(
            horizontal: BorderSide(color: theme.colorScheme.outlineVariant),
          ),
        ),
        child: MouseRegion(
          cursor: compact ? MouseCursor.defer : SystemMouseCursors.resizeRow,
          // Toucher annulé par le système : un glissement déjà commencé
          // se termine pour le détecteur par « fin », pas « annulé » ;
          // le Listener, prévenu avant lui, abandonne le glissement.
          child: Listener(
            onPointerCancel: compact ? null : (_) => _dragCancel(),
            child: GestureDetector(
              key: NoteSplit.handleKey,
              behavior: HitTestBehavior.opaque,
              // La poignée suit le doigt dès le premier pixel.
              dragStartBehavior: DragStartBehavior.down,
              onVerticalDragStart: compact ? null : _dragStart,
              onVerticalDragUpdate: compact ? null : _drag,
              onVerticalDragEnd: compact ? null : _dragEnd,
              onVerticalDragCancel: compact ? null : _dragCancel,
              child: Stack(
                children: [
                  if (!compact)
                    Center(
                      child: Container(
                        width: 48,
                        height: 5,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.outline,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                  Row(
                    children: [
                      const SizedBox(width: 16),
                      Expanded(
                        child: DefaultTextStyle(
                          style: theme.textTheme.labelLarge!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          child: Align(
                            alignment: Alignment.centerLeft,
                            // La moitié gauche : le titre ne passe pas sous
                            // la languette.
                            child: FractionallySizedBox(
                              widthFactor: 0.45,
                              alignment: Alignment.centerLeft,
                              child: widget.title ?? const SizedBox.shrink(),
                            ),
                          ),
                        ),
                      ),
                      if (!compact)
                        IconButton(
                          tooltip: _maximized
                              ? 'Réduire la note'
                              : 'Agrandir la note',
                          visualDensity: VisualDensity.compact,
                          iconSize: 20,
                          icon: Icon(
                            _maximized
                                ? Icons.close_fullscreen
                                : Icons.open_in_full,
                          ),
                          onPressed: () =>
                              setState(() => _maximized = !_maximized),
                        ),
                      if (widget.onClose != null)
                        IconButton(
                          tooltip: 'Fermer la note',
                          visualDensity: VisualDensity.compact,
                          iconSize: 20,
                          icon: const Icon(Icons.close),
                          onPressed: widget.onClose,
                        ),
                      const SizedBox(width: 4),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

enum _Snap { none, maximize, close }

/// Voile et consigne affichés quand relâcher la poignée aimante la note ;
/// laisse passer les touchers.
class _SnapHint extends StatelessWidget {
  const _SnapHint({
    super.key,
    required this.visible,
    required this.icon,
    required this.label,
    required this.color,
    this.alignment = Alignment.center,
  });

  final bool visible;
  final IconData icon;
  final String label;
  final Color color;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ink = theme.colorScheme.onSurfaceVariant;
    return IgnorePointer(
      child: AnimatedOpacity(
        opacity: visible ? 1 : 0,
        duration: const Duration(milliseconds: 150),
        child: ColoredBox(
          color: color,
          child: Align(
            alignment: alignment,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, color: ink),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(color: ink),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
