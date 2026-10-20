import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:verger_core/verger_core.dart';

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

/// État de l'éditeur : écriture, outil, annuler / rétablir. Séparé de
/// l'affichage pour être testé sans écran.
///
/// Les auditeurs sont prévenus quand l'écriture ou l'outil changent ; le
/// trait en cours, lui, ne prévient que [live] : suivre le stylet ne
/// reconstruit pas la page.
class InkEditorController extends ChangeNotifier {
  InkEditorController(InkDrawing initial) : _ink = initial;

  final _live = ValueNotifier(0);

  /// Prévient à chaque changement du trait en cours ([current]).
  Listenable get live => _live;
  void _liveChanged() => _live.value++;

  InkDrawing _ink;
  InkDrawing get ink => _ink;

  final _undo = <InkDrawing>[];
  final _redo = <InkDrawing>[];
  bool get canUndo => _undo.isNotEmpty;
  bool get canRedo => _redo.isNotEmpty;

  InkMode mode = InkMode.pen;

  /// Le doigt écrit (sinon il fait défiler la page).
  bool fingerDraws = false;

  /// Position dans la page : gardée, comme [fingerDraws], quand l'éditeur
  /// est retiré puis remis (passage au clavier et retour).
  final scroll = ScrollController();

  void toggleFingerDraws() {
    fingerDraws = !fingerDraws;
    notifyListeners();
  }

  /// Outil d'avant le dernier changement (geste « outil précédent » ou
  /// sortie de la gomme).
  InkMode _previous = InkMode.pen;
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
    _liveChanged();
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
    _liveChanged();
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
    scroll.dispose();
    super.dispose();
  }
}

/// Écriture manuscrite : barre d'outils et page. Stylet (Apple Pencil),
/// souris ou, sur demande, doigt ; avec un stylet, le doigt fait défiler
/// la page et la paume posée n'écrit pas. Les gestes de l'Apple Pencil
/// (toucher deux fois, presser) prennent la gomme ou ouvrent la palette.
///
/// L'écriture vit dans [controller] ; chaque modification est signalée par
/// [onChanged], l'enregistrement revient à l'appelant.
class InkEditor extends StatefulWidget {
  const InkEditor({
    super.key,
    required this.controller,
    required this.onChanged,
  });

  final InkEditorController controller;
  final VoidCallback onChanged;

  @override
  State<InkEditor> createState() => _InkEditorState();
}

class _InkEditorState extends State<InkEditor> {
  /// Appareil du trait en cours.
  int? _pointer;

  /// Palette ouverte par un geste du stylet, à cette position (dans
  /// [_body]) ; `null` : fermée.
  Offset? _palette;
  final _body = GlobalKey();

  InkEditorController get _controller => widget.controller;

  @override
  void initState() {
    super.initState();
    PencilGestures.addListener(_pencil);
  }

  void _pencil(PencilGesture gesture) {
    switch (gesture.action) {
      case PencilAction.eraser:
        _closePalette();
        _controller.toggleEraser();
      case PencilAction.previous:
        _closePalette();
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
    super.dispose();
  }

  void _changed() => widget.onChanged();

  bool _draws(PointerDeviceKind kind) => switch (kind) {
    PointerDeviceKind.stylus || PointerDeviceKind.invertedStylus => true,
    PointerDeviceKind.mouse => true,
    PointerDeviceKind.touch => _controller.fingerDraws,
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
      builder: (context, _) => LayoutBuilder(
        key: _body,
        builder: (context, body) => Stack(
          children: [
            Positioned.fill(child: _page(_controller, scheme)),
            if (_palette case final at?)
              _Palette(
                at: at,
                area: body.biggest,
                controller: _controller,
                onPicked: _closePalette,
              ),
          ],
        ),
      ),
    );
  }

  /// Annuler, rétablir, écrire au doigt, tout effacer.
  List<Widget> _actions(InkEditorController c) => [
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
          c.toggleFingerDraws();
        }
      },
      itemBuilder: (context) => [
        CheckedPopupMenuItem(
          value: 'finger',
          checked: c.fingerDraws,
          child: const Text('Écrire au doigt'),
        ),
        const PopupMenuItem(value: 'clear', child: Text('Tout effacer')),
      ],
    ),
  ];

  Widget _page(InkEditorController c, ColorScheme scheme) => Column(
    children: [
      _Toolbar(controller: c, actions: _actions(c)),
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
                dragDevices: c.fingerDraws
                    ? const {}
                    : const {
                        PointerDeviceKind.touch,
                        PointerDeviceKind.trackpad,
                      },
              ),
              child: Scrollbar(
                controller: c.scroll,
                thumbVisibility: c.fingerDraws,
                child: SingleChildScrollView(
                  controller: c.scroll,
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
                        if (e.pointer == _pointer) c.move(_point(e, scale));
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
                            // Même ordre que l'écriture enregistrée :
                            // surligneur sous le stylo.
                            RepaintBoundary(
                              child: CustomPaint(
                                painter: InkPainter(
                                  ink: InkDrawing.empty,
                                  scale: scale,
                                  lines: scheme.outlineVariant.withValues(
                                    alpha: 0.5,
                                  ),
                                ),
                              ),
                            ),
                            RepaintBoundary(
                              child: CustomPaint(
                                painter: _LivePainter(
                                  c,
                                  scale,
                                  InkTool.highlighter,
                                ),
                              ),
                            ),
                            RepaintBoundary(
                              child: CustomPaint(
                                painter: InkPainter(ink: c.ink, scale: scale),
                              ),
                            ),
                            RepaintBoundary(
                              child: CustomPaint(
                                painter: _LivePainter(c, scale, InkTool.pen),
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

/// Trait en cours de l'outil [tool], redessiné à chaque point sans
/// toucher au reste de la page.
class _LivePainter extends CustomPainter {
  _LivePainter(this.controller, this.scale, this.tool)
    : super(repaint: controller.live);

  final InkEditorController controller;
  final double scale;
  final InkTool tool;

  @override
  void paint(Canvas canvas, Size size) {
    final s = controller.current;
    if (s == null || s.tool != tool) return;
    InkPainter(
      ink: InkDrawing.empty,
      scale: scale,
      current: s,
    ).paint(canvas, size);
  }

  @override
  bool shouldRepaint(_LivePainter old) =>
      old.controller != controller || old.scale != scale || old.tool != tool;
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
    // Fenêtre étroite (écran partagé) : la palette rétrécit, ses outils
    // passent à la ligne.
    final width = math.min(_width, area.width - 16);
    return Positioned(
      left: clamp(at.dx - width / 2, area.width - width - 8),
      top: clamp(at.dy + 24, area.height - _height - 8),
      width: width,
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
  const _Toolbar({
    required this.controller,
    this.onPicked,
    this.actions = const [],
  });

  final InkEditorController controller;

  /// Boutons ajoutés en fin de barre (barre principale, pas la palette).
  final List<Widget> actions;

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
          if (actions.isNotEmpty) const SizedBox(width: 12),
          ...actions,
        ],
      ),
    );
  }
}
