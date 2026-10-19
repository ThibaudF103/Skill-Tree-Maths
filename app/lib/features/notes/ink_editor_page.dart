import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:verger_core/verger_core.dart';
import 'package:verger_data/verger_data.dart';

import '../../app/app_scope.dart';
import 'ink_view.dart';

/// Couleurs du stylo.
const inkColors = [
  (name: 'Noir', color: 0xFF1F1F1F),
  (name: 'Bleu', color: 0xFF1E4FA3),
  (name: 'Rouge', color: 0xFFC62828),
  (name: 'Vert', color: 0xFF2E7D32),
];

/// Épaisseurs du stylo, en unités de page.
const inkWidths = [
  (name: 'Fin', width: 2.0),
  (name: 'Moyen', width: 3.5),
  (name: 'Épais', width: 6.0),
];

const _highlighterColor = 0x66FFD54F;
const _highlighterWidth = 24.0;

/// Rayon de la gomme, en unités de page.
const _eraserRadius = 10.0;

enum InkMode { pen, highlighter, eraser }

/// État de l'éditeur : écriture, outil, annuler / rétablir. Séparé de
/// l'affichage pour être testé sans écran.
class InkEditorController extends ChangeNotifier {
  InkEditorController(InkDrawing initial) : _ink = initial;

  InkDrawing _ink;
  InkDrawing get ink => _ink;

  final _undo = <InkDrawing>[];
  final _redo = <InkDrawing>[];
  bool get canUndo => _undo.isNotEmpty;
  bool get canRedo => _redo.isNotEmpty;

  InkMode mode = InkMode.pen;
  int color = inkColors.first.color;
  double width = inkWidths[1].width;

  InkStroke? _current;
  InkStroke? get current => _current;

  /// Points du trait en cours, complétés sur place (pas de copie à chaque
  /// déplacement du stylet).
  final _points = <InkPoint>[];

  /// Effacement en cours : l'état d'avant, pour un seul « annuler ».
  InkDrawing? _beforeErase;

  /// Dernière position de la gomme : on efface tout le long du geste.
  InkPoint? _lastErase;

  void select(InkMode m) {
    mode = m;
    notifyListeners();
  }

  void setColor(int c) {
    color = c;
    mode = InkMode.pen;
    notifyListeners();
  }

  void setWidth(double w) {
    width = w;
    mode = InkMode.pen;
    notifyListeners();
  }

  /// Début d'un trait ; [erasing] : bout gomme du stylet.
  void down(InkPoint p, {bool erasing = false}) {
    if (erasing || mode == InkMode.eraser) {
      _beforeErase = _ink;
      _lastErase = null;
      _eraseAt(p);
      return;
    }
    final highlighter = mode == InkMode.highlighter;
    _points
      ..clear()
      ..add(p);
    _current = InkStroke(
      points: _points,
      color: highlighter ? _highlighterColor : color,
      width: highlighter ? _highlighterWidth : width,
      tool: highlighter ? InkTool.highlighter : InkTool.pen,
    );
    notifyListeners();
  }

  void move(InkPoint p) {
    if (_beforeErase != null) {
      _eraseAt(p);
      return;
    }
    final s = _current;
    if (s == null) return;
    final last = _points.last;
    // Points trop proches : inutiles et coûteux.
    if ((p.x - last.x).abs() + (p.y - last.y).abs() < 0.8) return;
    _points.add(p);
    // Nouvel objet (le dessin se rafraîchit), même liste de points.
    _current = InkStroke(
      points: _points,
      color: s.color,
      width: s.width,
      tool: s.tool,
    );
    notifyListeners();
  }

  /// Fin du trait ; vrai si l'écriture a changé.
  bool up() {
    final before = _beforeErase;
    if (before != null) {
      _beforeErase = null;
      if (identical(before, _ink) ||
          before.strokes.length == _ink.strokes.length) {
        return false;
      }
      _push(before);
      return true;
    }
    final s = _current;
    _current = null;
    if (s == null) return false;
    _push(_ink);
    _ink = _ink.add(
      InkStroke(
        points: List.unmodifiable(_points),
        color: s.color,
        width: s.width,
        tool: s.tool,
      ),
    );
    notifyListeners();
    return true;
  }

  /// Trait abandonné (geste annulé par le système).
  void cancel() {
    _current = null;
    final before = _beforeErase;
    if (before != null) _ink = before;
    _beforeErase = null;
    notifyListeners();
  }

  void _eraseAt(InkPoint p) {
    // Gomme rapide : on efface aussi entre la position précédente et la
    // nouvelle, par pas d'un demi-rayon.
    final from = _lastErase ?? p;
    _lastErase = p;
    final distance = math.sqrt(
      (p.x - from.x) * (p.x - from.x) + (p.y - from.y) * (p.y - from.y),
    );
    final steps = math.max(1, (distance / (_eraserRadius / 2)).ceil());
    var after = _ink;
    for (var k = 1; k <= steps; k++) {
      final t = k / steps;
      after = after.erase(
        from.x + t * (p.x - from.x),
        from.y + t * (p.y - from.y),
        _eraserRadius,
      );
    }
    if (after.strokes.length != _ink.strokes.length) {
      _ink = after;
      notifyListeners();
    }
  }

  void _push(InkDrawing before) {
    _undo.add(before);
    _redo.clear();
  }

  void undo() {
    if (_undo.isEmpty) return;
    _redo.add(_ink);
    _ink = _undo.removeLast();
    notifyListeners();
  }

  void redo() {
    if (_redo.isEmpty) return;
    _undo.add(_ink);
    _ink = _redo.removeLast();
    notifyListeners();
  }

  void clear() {
    if (_ink.isEmpty) return;
    _push(_ink);
    _ink = InkDrawing.empty;
    notifyListeners();
  }
}

/// Ouvre l'écriture manuscrite de [note] ; au retour, une note restée
/// sans texte, sans écriture ni zone est supprimée.
Future<void> openInkEditor(BuildContext context, Note note) async {
  final store = AppScope.of(context).store;
  await Navigator.of(
    context,
  ).push(MaterialPageRoute<void>(builder: (_) => InkEditorPage(note: note)));
  await store.deleteNoteIfBlank(note.id);
}

/// Écriture manuscrite d'une note, en plein écran : stylet (Apple Pencil),
/// souris ou, sur demande, doigt. Avec un stylet, le doigt fait défiler la
/// page : la paume posée n'écrit pas.
class InkEditorPage extends StatefulWidget {
  const InkEditorPage({super.key, required this.note});

  final Note note;

  @override
  State<InkEditorPage> createState() => _InkEditorPageState();
}

class _InkEditorPageState extends State<InkEditorPage> {
  late final _controller = InkEditorController(
    widget.note.ink ?? InkDrawing.empty,
  );
  final _scroll = ScrollController();
  Timer? _save;
  bool _dirty = false;

  /// Le doigt écrit (sinon il fait défiler la page).
  bool _fingerDraws = false;

  /// Appareil du trait en cours.
  int? _pointer;
  late VergerStore _store;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _store = AppScope.of(context).store;
  }

  @override
  void dispose() {
    _save?.cancel();
    if (_dirty) _flush().ignore();
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _changed() {
    _setDirty(true);
    _save?.cancel();
    _save = Timer(const Duration(milliseconds: 800), _flush);
  }

  /// Enregistrement en cours (on attend sa fin avant de quitter).
  Future<void>? _saving;

  /// Enregistre l'écriture ; la page reste « modifiée » tant que
  /// l'enregistrement n'a pas réussi.
  Future<void> _flush() async {
    _save?.cancel();
    final previous = _saving;
    if (previous != null) await previous;
    final ink = _controller.ink;
    final saving = _store.updateNote(widget.note.id, ink: ink);
    _saving = saving;
    try {
      await saving;
      // Rien de nouveau entre-temps : tout est enregistré.
      if (identical(ink, _controller.ink)) _setDirty(false);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Écriture non enregistrée : $e')),
        );
      }
      rethrow;
    } finally {
      if (identical(_saving, saving)) _saving = null;
    }
  }

  void _setDirty(bool dirty) {
    if (_dirty == dirty) return;
    if (mounted) {
      setState(() => _dirty = dirty);
    } else {
      _dirty = dirty;
    }
  }

  bool _draws(PointerDeviceKind kind) => switch (kind) {
    PointerDeviceKind.stylus || PointerDeviceKind.invertedStylus => true,
    PointerDeviceKind.mouse => true,
    PointerDeviceKind.touch => _fingerDraws,
    _ => false,
  };

  InkPoint _point(PointerEvent e, double scale) {
    final pressure = e.pressureMax > e.pressureMin
        ? ((e.pressure - e.pressureMin) / (e.pressureMax - e.pressureMin))
              .clamp(0.0, 1.0)
        : 0.5;
    return (
      x: e.localPosition.dx / scale,
      y: e.localPosition.dy / scale,
      pressure: pressure,
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        final c = _controller;
        // On enregistre avant de quitter : l'appelant relit la note aussitôt.
        return PopScope(
          canPop: !_dirty && _saving == null,
          onPopInvokedWithResult: (didPop, _) async {
            if (didPop) return;
            try {
              await _flush();
            } catch (_) {
              return; // Échec signalé : on reste sur la page.
            }
            if (context.mounted) Navigator.of(context).pop();
          },
          child: Scaffold(
            appBar: AppBar(
              title: const Text('Écriture manuscrite'),
              actions: [
                IconButton(
                  tooltip: 'Annuler',
                  onPressed: c.canUndo
                      ? () {
                          c.undo();
                          _changed();
                        }
                      : null,
                  icon: const Icon(Icons.undo),
                ),
                IconButton(
                  tooltip: 'Rétablir',
                  onPressed: c.canRedo
                      ? () {
                          c.redo();
                          _changed();
                        }
                      : null,
                  icon: const Icon(Icons.redo),
                ),
                PopupMenuButton<String>(
                  tooltip: 'Plus',
                  onSelected: (v) {
                    if (v == 'clear') {
                      c.clear();
                      _changed();
                    } else if (v == 'finger') {
                      setState(() => _fingerDraws = !_fingerDraws);
                    }
                  },
                  itemBuilder: (context) => [
                    CheckedPopupMenuItem(
                      value: 'finger',
                      checked: _fingerDraws,
                      child: const Text('Écrire au doigt'),
                    ),
                    const PopupMenuItem(
                      value: 'clear',
                      child: Text('Tout effacer'),
                    ),
                  ],
                ),
              ],
            ),
            body: Column(
              children: [
                _Toolbar(controller: c),
                const Divider(height: 1),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final width = math.min(constraints.maxWidth, 1000.0);
                      final scale = width / InkDrawing.pageWidth;
                      // Toujours une page de marge sous l'écriture.
                      final height = math.max(
                        constraints.maxHeight,
                        (c.ink.bottom + 800) * scale,
                      );
                      return ScrollConfiguration(
                        // Le stylet et la souris écrivent, le doigt défile.
                        behavior: ScrollConfiguration.of(context).copyWith(
                          dragDevices: _fingerDraws
                              ? const {}
                              : const {
                                  PointerDeviceKind.touch,
                                  PointerDeviceKind.trackpad,
                                },
                        ),
                        child: Scrollbar(
                          controller: _scroll,
                          thumbVisibility: _fingerDraws,
                          child: SingleChildScrollView(
                            controller: _scroll,
                            child: Center(
                              child: Listener(
                                onPointerDown: (e) {
                                  if (_pointer != null || !_draws(e.kind)) {
                                    return;
                                  }
                                  if (e.kind == PointerDeviceKind.mouse &&
                                      e.buttons != kPrimaryMouseButton) {
                                    return;
                                  }
                                  _pointer = e.pointer;
                                  c.down(
                                    _point(e, scale),
                                    erasing:
                                        e.kind ==
                                        PointerDeviceKind.invertedStylus,
                                  );
                                },
                                onPointerMove: (e) {
                                  if (e.pointer == _pointer) {
                                    c.move(_point(e, scale));
                                  }
                                },
                                onPointerUp: (e) {
                                  if (e.pointer != _pointer) return;
                                  _pointer = null;
                                  if (c.up()) _changed();
                                },
                                onPointerCancel: (e) {
                                  if (e.pointer != _pointer) return;
                                  _pointer = null;
                                  c.cancel();
                                },
                                child: Container(
                                  width: width,
                                  height: height,
                                  color: scheme.surface,
                                  child: CustomPaint(
                                    painter: InkPainter(
                                      ink: c.ink,
                                      current: c.current,
                                      scale: scale,
                                      lines: scheme.outlineVariant.withValues(
                                        alpha: 0.5,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Toolbar extends StatelessWidget {
  const _Toolbar({required this.controller});

  final InkEditorController controller;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final scheme = Theme.of(context).colorScheme;
    Widget tool(InkMode mode, IconData icon, String label) => IconButton(
      tooltip: label,
      isSelected: c.mode == mode,
      onPressed: () => c.select(mode),
      icon: Icon(icon),
      style: IconButton.styleFrom(
        backgroundColor: c.mode == mode ? scheme.secondaryContainer : null,
      ),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Wrap(
        spacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          tool(InkMode.pen, Icons.edit, 'Stylo'),
          tool(InkMode.highlighter, Icons.border_color, 'Surligneur'),
          tool(InkMode.eraser, Icons.auto_fix_normal, 'Gomme'),
          const SizedBox(width: 12),
          for (final (:name, :color) in inkColors)
            Tooltip(
              message: name,
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: () => c.setColor(color),
                child: Container(
                  width: 28,
                  height: 28,
                  margin: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Color(color),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: c.mode == InkMode.pen && c.color == color
                          ? scheme.primary
                          : Colors.transparent,
                      width: 3,
                    ),
                  ),
                ),
              ),
            ),
          const SizedBox(width: 12),
          for (final (:name, :width) in inkWidths)
            ChoiceChip(
              label: Text(name),
              selected: c.mode == InkMode.pen && c.width == width,
              onSelected: (_) => c.setWidth(width),
            ),
        ],
      ),
    );
  }
}
