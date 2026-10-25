import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// Écran partagé pour prendre des notes en gardant le contenu sous les
/// yeux : le contenu (PDF, vidéo, fiche, carte de révision) en haut, la
/// note en bas, séparés par une poignée qu'on fait glisser pour régler la
/// hauteur de la note.
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

  /// Poignée (tests).
  static const handleKey = Key('note-split-handle');

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

  double get _maxNote => math.max(
    NoteSplit.minNoteHeight,
    _total - NoteSplit.handleHeight - NoteSplit.minContentHeight,
  );

  double get _noteHeight =>
      (_total * NoteSplit._fraction).clamp(NoteSplit.minNoteHeight, _maxNote);

  void _dragStart(DragStartDetails _) {
    if (!_maximized) return;
    // Glisser depuis le plein écran : on repart de la plus grande hauteur.
    setState(() {
      _maximized = false;
      NoteSplit._fraction = _maxNote / _total;
    });
  }

  void _drag(DragUpdateDetails d) {
    if (_total <= 0) return;
    final height = (_noteHeight - d.delta.dy).clamp(
      NoteSplit.minNoteHeight,
      _maxNote,
    );
    setState(() => NoteSplit._fraction = height / _total);
  }

  @override
  void didUpdateWidget(NoteSplit old) {
    super.didUpdateWidget(old);
    // Une note refermée se rouvre à sa hauteur, pas en plein écran.
    if (widget.note == null) _maximized = false;
  }

  @override
  Widget build(BuildContext context) {
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
        final noteHeight = note == null ? 0.0 : _noteHeight;
        final contentHeight = note == null
            ? _total
            : math.max(
                NoteSplit.minContentHeight,
                _total - noteHeight - NoteSplit.handleHeight,
              );
        final handleTop = full ? 0.0 : contentHeight;
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
            if (note != null) ...[
              Positioned(
                left: 0,
                right: 0,
                top: handleTop,
                height: NoteSplit.handleHeight,
                child: _handle(context, compact: compact),
              ),
              Positioned(
                left: 0,
                right: 0,
                top: handleTop + NoteSplit.handleHeight,
                bottom: 0,
                child: note,
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
          child: GestureDetector(
            key: NoteSplit.handleKey,
            behavior: HitTestBehavior.opaque,
            // La poignée suit le doigt dès le premier pixel.
            dragStartBehavior: DragStartBehavior.down,
            onVerticalDragStart: compact ? null : _dragStart,
            onVerticalDragUpdate: compact ? null : _drag,
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
    );
  }
}
