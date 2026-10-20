import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:verger_core/verger_core.dart';
import 'package:verger_data/verger_data.dart';

import '../../app/app_scope.dart';
import 'ink_view.dart';
import 'pencil_gestures.dart';

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

/// Prolongement du trait affiché au-delà du dernier point reçu, pour
/// compenser la latence de l'écran : durée prévue et longueur maximale (en
/// unités de page).
const _predictionHorizonMs = 16.0;
const _predictionMax = 30.0;

/// État de l'éditeur : écriture, outil, annuler / rétablir. Séparé de
/// l'affichage pour être testé sans écran.
///
/// Les auditeurs sont prévenus quand l'écriture ou l'outil changent ; le
/// trait en cours, lui, ne prévient que [live] : suivre le stylet ne
/// reconstruit pas la page.
class InkEditorController extends ChangeNotifier {
  InkEditorController(InkDrawing initial) : _ink = initial;

  final _live = ValueNotifier(0);

  /// Prévient à chaque changement du trait en cours ([current],
  /// [predicted]).
  Listenable get live => _live;
  void _liveChanged() => _live.value++;

  InkDrawing _ink;
  InkDrawing get ink => _ink;

  final _undo = <InkDrawing>[];
  final _redo = <InkDrawing>[];
  bool get canUndo => _undo.isNotEmpty;
  bool get canRedo => _redo.isNotEmpty;

  InkMode mode = InkMode.pen;

  /// Outil d'avant le dernier changement (geste « outil précédent » ou
  /// sortie de la gomme).
  InkMode _previous = InkMode.pen;
  int color = inkColors.first.color;
  double width = inkWidths[1].width;

  InkStroke? _current;
  InkStroke? get current => _current;

  /// Point où le stylet devrait être maintenant, d'après sa vitesse :
  /// affiché au bout du trait en cours, jamais enregistré.
  InkPoint? _predicted;
  InkPoint? get predicted => _predicted;

  /// Dernier point reçu, son instant et la vitesse lissée du stylet (unités
  /// de page par milliseconde).
  ({InkPoint point, Duration time})? _lastSample;
  var _velocity = (x: 0.0, y: 0.0);

  /// Points du trait en cours, complétés sur place (pas de copie à chaque
  /// déplacement du stylet).
  final _points = <InkPoint>[];

  /// Effacement en cours : l'état d'avant, pour un seul « annuler ».
  InkDrawing? _beforeErase;

  /// Dernière position de la gomme : on efface tout le long du geste.
  InkPoint? _lastErase;

  void select(InkMode m) {
    _setMode(m);
    notifyListeners();
  }

  void _setMode(InkMode m) {
    if (m == mode) return;
    _previous = mode;
    mode = m;
  }

  /// Geste « gomme » du stylet : la gomme, ou l'outil d'avant si elle
  /// est déjà choisie.
  void toggleEraser() =>
      select(mode == InkMode.eraser ? _previous : InkMode.eraser);

  /// Geste « outil précédent » du stylet.
  void switchPrevious() => select(_previous);

  void setColor(int c) {
    color = c;
    _setMode(InkMode.pen);
    notifyListeners();
  }

  void setWidth(double w) {
    width = w;
    _setMode(InkMode.pen);
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
    _predicted = null;
    _lastSample = null;
    _velocity = (x: 0.0, y: 0.0);
    _liveChanged();
  }

  /// [time] : instant de l'événement, pour prévoir où va le stylet.
  void move(InkPoint p, {Duration? time}) {
    if (_beforeErase != null) {
      _eraseAt(p);
      return;
    }
    final s = _current;
    if (s == null) return;
    _predict(p, time);
    final last = _points.last;
    // Points trop proches : inutiles et coûteux.
    if ((p.x - last.x).abs() + (p.y - last.y).abs() < 0.8) {
      _liveChanged();
      return;
    }
    _points.add(p);
    // Nouvel objet (le dessin se rafraîchit), même liste de points.
    _current = InkStroke(
      points: _points,
      color: s.color,
      width: s.width,
      tool: s.tool,
    );
    _liveChanged();
  }

  /// Vitesse lissée du stylet, prolongée sur [_predictionHorizonMs].
  void _predict(InkPoint p, Duration? time) {
    final last = _lastSample;
    if (time == null) {
      _predicted = null;
      return;
    }
    _lastSample = (point: p, time: time);
    if (last == null) return;
    final dt = (time - last.time).inMicroseconds / 1000;
    if (dt <= 0 || dt > 50) {
      // Pause ou événements groupés : pas de vitesse fiable.
      _velocity = (x: 0.0, y: 0.0);
      _predicted = null;
      return;
    }
    _velocity = (
      x: 0.5 * _velocity.x + 0.5 * (p.x - last.point.x) / dt,
      y: 0.5 * _velocity.y + 0.5 * (p.y - last.point.y) / dt,
    );
    var dx = _velocity.x * _predictionHorizonMs;
    var dy = _velocity.y * _predictionHorizonMs;
    final length = math.sqrt(dx * dx + dy * dy);
    if (length < 0.5) {
      _predicted = null;
      return;
    }
    if (length > _predictionMax) {
      dx *= _predictionMax / length;
      dy *= _predictionMax / length;
    }
    _predicted = (x: p.x + dx, y: p.y + dy, pressure: p.pressure);
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
    _predicted = null;
    if (s == null) return false;
    _liveChanged();
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
    _predicted = null;
    _liveChanged();
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

  @override
  void dispose() {
    _live.dispose();
    super.dispose();
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
/// page : la paume posée n'écrit pas. Les gestes de l'Apple Pencil
/// (toucher deux fois, presser) prennent la gomme ou ouvrent la palette.
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

  /// Palette ouverte par un geste du stylet, à cette position (dans
  /// [_body]) ; `null` : fermée.
  Offset? _palette;
  final _body = GlobalKey();

  @override
  void initState() {
    super.initState();
    PencilGestures.addListener(_pencil);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _store = AppScope.of(context).store;
  }

  void _pencil(PencilGesture gesture) {
    switch (gesture.action) {
      case PencilAction.eraser:
        _controller.toggleEraser();
      case PencilAction.previous:
        _controller.switchPrevious();
      case PencilAction.palette:
        final box = _body.currentContext?.findRenderObject() as RenderBox?;
        final at = gesture.at;
        setState(() {
          _palette = _palette != null || box == null
              ? null
              : at == null
              ? Offset(box.size.width, 0)
              : box.globalToLocal(at);
        });
    }
  }

  void _closePalette() {
    if (_palette != null) setState(() => _palette = null);
  }

  @override
  void dispose() {
    PencilGestures.removeListener(_pencil);
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
            body: LayoutBuilder(
              key: _body,
              builder: (context, body) => Stack(
                children: [
                  Positioned.fill(child: _page(c, scheme)),
                  if (_palette case final at?)
                    _Palette(
                      at: at,
                      area: body.biggest,
                      controller: c,
                      onPicked: _closePalette,
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _page(InkEditorController c, ColorScheme scheme) => Column(
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
                        _closePalette();
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
                          erasing: e.kind == PointerDeviceKind.invertedStylus,
                        );
                      },
                      onPointerMove: (e) {
                        if (e.pointer == _pointer) {
                          c.move(_point(e, scale), time: e.timeStamp);
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
                        // Deux calques : l'écriture enregistrée
                        // ne se redessine pas à chaque point du
                        // trait en cours.
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            RepaintBoundary(
                              child: CustomPaint(
                                painter: InkPainter(
                                  ink: c.ink,
                                  scale: scale,
                                  lines: scheme.outlineVariant.withValues(
                                    alpha: 0.5,
                                  ),
                                ),
                              ),
                            ),
                            RepaintBoundary(
                              child: CustomPaint(
                                painter: _LivePainter(c, scale),
                              ),
                            ),
                          ],
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
  );
}

/// Trait en cours et son prolongement prévu, redessinés à chaque point
/// sans toucher au reste de la page.
class _LivePainter extends CustomPainter {
  _LivePainter(this.controller, this.scale) : super(repaint: controller.live);

  final InkEditorController controller;
  final double scale;

  @override
  void paint(Canvas canvas, Size size) {
    final s = controller.current;
    if (s == null) return;
    final predicted = controller.predicted;
    InkPainter(
      ink: InkDrawing.empty,
      scale: scale,
      current: predicted == null
          ? s
          : InkStroke(
              points: [...s.points, predicted],
              color: s.color,
              width: s.width,
              tool: s.tool,
            ),
    ).paint(canvas, size);
  }

  @override
  bool shouldRepaint(_LivePainter old) =>
      old.controller != controller || old.scale != scale;
}

/// Palette d'outils flottante, ouverte par un geste du stylet près de la
/// pointe ; se referme au choix d'un outil.
class _Palette extends StatelessWidget {
  const _Palette({
    required this.at,
    required this.area,
    required this.controller,
    required this.onPicked,
  });

  final Offset at;
  final Size area;
  final InkEditorController controller;
  final VoidCallback onPicked;

  static const _width = 340.0;
  static const _height = 150.0;

  @override
  Widget build(BuildContext context) {
    double clamp(double v, double max) => v.clamp(8.0, math.max(8.0, max));
    return Positioned(
      left: clamp(at.dx - _width / 2, area.width - _width - 8),
      top: clamp(at.dy + 24, area.height - _height - 8),
      width: _width,
      child: Material(
        elevation: 6,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: ListenableBuilder(
            listenable: controller,
            builder: (context, _) =>
                _Toolbar(controller: controller, onPicked: onPicked),
          ),
        ),
      ),
    );
  }
}

class _Toolbar extends StatelessWidget {
  const _Toolbar({required this.controller, this.onPicked});

  final InkEditorController controller;

  /// Appelé après chaque choix (palette flottante : elle se referme).
  final VoidCallback? onPicked;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final scheme = Theme.of(context).colorScheme;
    Widget tool(InkMode mode, IconData icon, String label) => IconButton(
      tooltip: label,
      isSelected: c.mode == mode,
      onPressed: () {
        c.select(mode);
        onPicked?.call();
      },
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
                onTap: () {
                  c.setColor(color);
                  onPicked?.call();
                },
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
              onSelected: (_) {
                c.setWidth(width);
                onPicked?.call();
              },
            ),
        ],
      ),
    );
  }
}
