import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:verger_core/verger_core.dart';
import 'package:verger_data/verger_data.dart';

import '../../app/app_scope.dart';
import '../../ui/dialogs.dart';
import '../../ui/labels.dart';
import '../../ui/latex_input.dart';
import '../../ui/math_text.dart';
import '../documents/pickers.dart';
import '../items/item_detail_page.dart';
import '../items/item_editor.dart';
import 'ink_editor.dart';
import 'ink_view.dart';

/// Panneau de notes d'un PDF : liste des notes (par page) ou édition d'une
/// note, avec aperçu LaTeX et liens vers les connaissances.
class NotesPanel extends StatelessWidget {
  const NotesPanel({
    super.key,
    required this.document,
    required this.notes,
    required this.activeNoteId,
    required this.currentPage,
    required this.onSelect,
    this.onClose,
    required this.onGoTo,
  });

  final SourceDocument document;
  final List<Note> notes;
  final String? activeNoteId;
  final int currentPage;

  /// Ouvre une note (`null` : retour à la liste).
  final ValueChanged<String?> onSelect;

  /// Ferme le panneau ; sans lui, pas de bouton (l'écran partagé a le sien).
  final VoidCallback? onClose;

  /// Affiche la page (et la zone) d'une note dans le PDF.
  final void Function(int page, NormalizedRect? region) onGoTo;

  Future<void> _newPageNote(BuildContext context) async {
    final note = await AppScope.of(
      context,
    ).store.createNote(documentId: document.id, page: currentPage);
    onSelect(note.id);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final active = notes.where((n) => n.id == activeNoteId).firstOrNull;
    return Material(
      color: theme.colorScheme.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
            child: Row(
              children: [
                if (active != null)
                  IconButton(
                    tooltip: 'Toutes les notes',
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () => onSelect(null),
                  )
                else
                  const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    active == null
                        ? 'Notes'
                        : 'Note · p. ${active.page ?? '–'}',
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                if (active == null)
                  TextButton.icon(
                    onPressed: () => _newPageNote(context),
                    icon: const Icon(Icons.add),
                    label: Text('Note p. $currentPage'),
                  ),
                if (onClose != null)
                  IconButton(
                    tooltip: 'Fermer les notes',
                    icon: const Icon(Icons.close),
                    onPressed: onClose,
                  ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: active != null
                ? NoteEditor(
                    key: ValueKey(active.id),
                    note: active,
                    document: document,
                    onGoTo: onGoTo,
                    onDeleted: () => onSelect(null),
                  )
                : _NoteList(
                    notes: notes,
                    currentPage: currentPage,
                    onSelect: (note) {
                      onSelect(note.id);
                      if (note.page != null) onGoTo(note.page!, note.region);
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _NoteList extends StatelessWidget {
  const _NoteList({
    required this.notes,
    required this.currentPage,
    required this.onSelect,
  });

  final List<Note> notes;
  final int currentPage;
  final ValueChanged<Note> onSelect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (notes.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          'Aucune note sur ce PDF.\n\n'
          'Ajoutez une note sur la page en cours, ou encadrez un élément du '
          'PDF puis choisissez « Prendre une note sur cette zone ».',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.outline,
          ),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: notes.length,
      separatorBuilder: (_, _) => const Divider(height: 1, indent: 16),
      itemBuilder: (context, i) {
        final note = notes[i];
        final onPage = note.page == currentPage;
        final headline = note.headline.isEmpty && !(note.ink?.isEmpty ?? true)
            ? 'Note manuscrite'
            : note.headline;
        return ListTile(
          selected: onPage,
          leading: CircleAvatar(
            radius: 16,
            backgroundColor: onPage
                ? theme.colorScheme.primaryContainer
                : theme.colorScheme.surfaceContainerHighest,
            child: Text(
              '${note.page ?? '–'}',
              style: theme.textTheme.labelMedium,
            ),
          ),
          title: Text(
            headline.isEmpty ? 'Note vide' : headline,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: headline.isEmpty
                ? TextStyle(color: theme.colorScheme.outline)
                : null,
          ),
          subtitle: note.itemId != null
              ? const Text('Liée à une connaissance')
              : null,
          trailing: note.snapshot != null
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: Image.memory(
                    note.snapshot!,
                    width: 56,
                    height: 40,
                    fit: BoxFit.cover,
                  ),
                )
              : null,
          onTap: () => onSelect(note),
        );
      },
    );
  }
}

/// Dernier mode de saisie choisi (stylet ou clavier), commun à tous les
/// éditeurs de note.
bool? _lastHandwriting;

/// Mode de saisie à l'ouverture : celui du contenu s'il n'y en a qu'un,
/// sinon le dernier choisi (d'abord le stylet sur iPad, pas sur iPhone).
bool _initialMode(
  BuildContext context, {
  required bool hasText,
  required bool hasInk,
}) {
  if (hasInk != hasText) return hasInk;
  return _lastHandwriting ??
      (defaultTargetPlatform == TargetPlatform.iOS &&
          MediaQuery.sizeOf(context).shortestSide >= 600);
}

/// Bascule Clavier / Stylet des éditeurs de note.
class _ModeToggle extends StatelessWidget {
  const _ModeToggle({required this.handwriting, required this.onChanged});

  final bool handwriting;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => SegmentedButton<bool>(
    segments: const [
      ButtonSegment(
        value: false,
        icon: Icon(Icons.keyboard_outlined),
        label: Text('Clavier'),
      ),
      ButtonSegment(
        value: true,
        icon: Icon(Icons.draw_outlined),
        label: Text('Stylet'),
      ),
    ],
    selected: {handwriting},
    onSelectionChanged: (v) => onChanged(v.single),
  );
}

/// Brouillon de note, pas encore enregistré (tentative pendant une
/// révision) : texte et écriture restent dans [text] et [ink], que
/// l'appelant enregistre quand il le décide.
class NoteDraftEditor extends StatefulWidget {
  const NoteDraftEditor({
    super.key,
    required this.text,
    required this.ink,
    this.hint = r'Formules : $x^2$ ou $$\sum_k a_k$$',
  });

  final TextEditingController text;
  final InkEditorController ink;
  final String hint;

  @override
  State<NoteDraftEditor> createState() => _NoteDraftEditorState();
}

class _NoteDraftEditorState extends State<NoteDraftEditor> {
  late bool _handwriting = _initialMode(
    context,
    hasText: widget.text.text.trim().isNotEmpty,
    hasInk: !widget.ink.ink.isEmpty,
  );

  void _setMode(bool handwriting) {
    if (handwriting == _handwriting) return;
    if (handwriting) FocusScope.of(context).unfocus();
    _lastHandwriting = handwriting;
    setState(() => _handwriting = handwriting);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: _ModeToggle(
                handwriting: _handwriting,
                onChanged: _setMode,
              ),
            ),
          ),
          Expanded(
            child: _handwriting
                ? InkEditor(controller: widget.ink, onChanged: () {})
                : ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      TextField(
                        controller: widget.text,
                        inputFormatters: const [LatexAutoCloseFormatter()],
                        minLines: 4,
                        maxLines: null,
                        keyboardType: TextInputType.multiline,
                        decoration: InputDecoration(
                          hintText: widget.hint,
                          border: const OutlineInputBorder(),
                        ),
                      ),
                      ListenableBuilder(
                        listenable: widget.text,
                        builder: (context, _) => widget.text.text.contains(r'$')
                            ? Container(
                                margin: const EdgeInsets.only(top: 12),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.surfaceContainerLow,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: MathText(widget.text.text),
                              )
                            : const SizedBox.shrink(),
                      ),
                      // L'écriture du brouillon : la toucher passe au stylet.
                      ListenableBuilder(
                        listenable: widget.ink,
                        builder: (context, _) => widget.ink.ink.isEmpty
                            ? const SizedBox.shrink()
                            : Padding(
                                padding: const EdgeInsets.only(top: 16),
                                child: InkWell(
                                  onTap: () => _setMode(true),
                                  child: InkView(ink: widget.ink.ink),
                                ),
                              ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

/// Édition d'une note, au clavier (texte et LaTeX, avec aperçu) ou au
/// stylet (écriture manuscrite) : une même note peut mêler les deux.
/// Enregistrement automatique, zone du PDF, lien vers une connaissance.
class NoteEditor extends StatefulWidget {
  const NoteEditor({
    super.key,
    required this.note,
    required this.document,
    required this.onGoTo,
    required this.onDeleted,
  });

  final Note note;
  final SourceDocument? document;
  final void Function(int page, NormalizedRect? region)? onGoTo;
  final VoidCallback onDeleted;

  /// Oublie le dernier mode de saisie choisi (tests).
  @visibleForTesting
  static void forgetMode() => _lastHandwriting = null;

  @override
  State<NoteEditor> createState() => _NoteEditorState();
}

class _NoteEditorState extends State<NoteEditor> {
  late final _text = TextEditingController(text: widget.note.body);
  late final _ink = InkEditorController(widget.note.ink ?? InkDrawing.empty);

  /// Dernier texte et dernière écriture enregistrés (la note reçue peut
  /// être ancienne).
  late String _saved = widget.note.body;
  late InkDrawing _savedInk = _ink.ink;
  Timer? _save;
  late VergerStore _store;

  /// Saisie au stylet (sinon au clavier). Une note qui n'a que de
  /// l'écriture s'ouvre au stylet, une note qui n'a que du texte au
  /// clavier ; sinon, le dernier mode choisi (d'abord le stylet sur iPad,
  /// pas sur iPhone).
  late bool _handwriting = _initialMode(
    context,
    hasText: widget.note.body.trim().isNotEmpty,
    hasInk: !_ink.ink.isEmpty,
  );

  void _setMode(bool handwriting) {
    if (handwriting == _handwriting) return;
    if (handwriting) FocusScope.of(context).unfocus();
    _lastHandwriting = handwriting;
    setState(() => _handwriting = handwriting);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _store = AppScope.of(context).store;
  }

  @override
  void initState() {
    super.initState();
    _text.addListener(_scheduleSave);
  }

  void _scheduleSave() {
    _save?.cancel();
    _save = Timer(const Duration(milliseconds: 600), _flush);
  }

  /// Enregistre ce qui a changé (texte, écriture) ; les valeurs sont lues
  /// tout de suite, avant toute attente.
  Future<void> _flush() async {
    _save?.cancel();
    _save = null;
    final text = _text.text;
    final ink = _ink.ink;
    final body = text != _saved ? text : null;
    final changedInk = identical(ink, _savedInk) ? null : ink;
    if (body == null && changedInk == null) return;
    try {
      await _store.updateNote(widget.note.id, body: body, ink: changedInk);
    } catch (e) {
      // Rien n'est marqué enregistré : le prochain enregistrement réessaie.
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Note non enregistrée : $e')));
      }
      return;
    }
    _saved = text;
    _savedInk = ink;
  }

  @override
  void dispose() {
    // Ce qui reste est enregistré ; puis une note sans texte, sans écriture
    // ni zone est supprimée (on ne laisse pas de notes vides derrière soi) :
    // en une requête qui relit la note en base, sans risque d'effacer une
    // modification faite entre-temps.
    final store = _store, id = widget.note.id;
    final blank =
        _text.text.trim().isEmpty &&
        _ink.ink.isEmpty &&
        widget.note.region == null;
    final saved = _flush();
    if (blank) saved.then((_) => store.deleteNoteIfBlank(id));
    _text.dispose();
    _ink.dispose();
    super.dispose();
  }

  Future<void> _createItem() async {
    await _flush();
    if (!mounted) return;
    final item = await showItemEditor(
      context,
      family: ItemFamily.statement,
      initialTitle: shortenTitle(noteHeadline(_text.text)),
    );
    if (item == null) return;
    await _linkTo(item);
  }

  Future<void> _linkExisting() async {
    final item = await pickItem(
      context,
      title: 'Verso de quelle connaissance ?',
    );
    if (item != null) await _linkTo(item);
  }

  /// La note devient le verso de [item] ; la zone d'un cours devient son
  /// recto.
  Future<void> _linkTo(KnowledgeItem item) async {
    await _flush();
    final note = widget.note;
    await _store.updateNote(note.id, itemId: () => item.id);
    final document = widget.document;
    if (document != null &&
        document.isPdf &&
        note.page != null &&
        note.region != null) {
      final existing = await _store.anchorsOf(item.id);
      final already = existing.any(
        (a) =>
            a.documentId == document.id &&
            a.page == note.page &&
            a.region == note.region,
      );
      if (!already) {
        await _store.addAnchor(
          itemId: item.id,
          documentId: document.id,
          role: AnchorRole.source,
          page: note.page!,
          region: note.region,
          snapshot: note.snapshot,
        );
      }
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Note liée à « ${item.title} » (verso).')),
      );
    }
  }

  Future<void> _delete() async {
    final ok = await confirmDestructive(
      context,
      title: 'Supprimer la note ?',
      message: 'Son texte sera définitivement supprimé.',
    );
    if (!ok) return;
    _save?.cancel();
    _save = null;
    await _store.deleteNote(widget.note.id);
    widget.onDeleted();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Align(
            alignment: Alignment.centerLeft,
            child: _ModeToggle(handwriting: _handwriting, onChanged: _setMode),
          ),
        ),
        Expanded(
          child: _handwriting
              ? InkEditor(controller: _ink, onChanged: _scheduleSave)
              : _keyboard(context),
        ),
      ],
    );
  }

  Widget _keyboard(BuildContext context) {
    final theme = Theme.of(context);
    final note = widget.note;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (note.snapshot != null)
          InkWell(
            onTap: note.page == null || widget.onGoTo == null
                ? null
                : () => widget.onGoTo!(note.page!, note.region),
            child: Container(
              constraints: const BoxConstraints(maxHeight: 180),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: theme.colorScheme.outlineVariant),
                borderRadius: BorderRadius.circular(8),
              ),
              clipBehavior: Clip.antiAlias,
              child: Image.memory(note.snapshot!, fit: BoxFit.contain),
            ),
          ),
        if (note.snapshot != null) const SizedBox(height: 12),
        TextField(
          controller: _text,
          inputFormatters: const [LatexAutoCloseFormatter()],
          autofocus: note.isBlank,
          minLines: 6,
          maxLines: null,
          keyboardType: TextInputType.multiline,
          decoration: const InputDecoration(
            hintText:
                r'Rédaction, démonstration… Formules : $x^2$ ou $$\sum_k a_k$$',
            border: OutlineInputBorder(),
          ),
        ),
        ListenableBuilder(
          listenable: _text,
          builder: (context, _) => _text.text.contains(r'$')
              ? Container(
                  margin: const EdgeInsets.only(top: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: MathText(_text.text),
                )
              : const SizedBox.shrink(),
        ),
        // L'écriture manuscrite de la note : la toucher passe au stylet.
        ListenableBuilder(
          listenable: _ink,
          builder: (context, _) => _ink.ink.isEmpty
              ? const SizedBox.shrink()
              : Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: InkWell(
                    onTap: () => _setMode(true),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: theme.colorScheme.outlineVariant,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: InkView(ink: _ink.ink),
                    ),
                  ),
                ),
        ),
        const SizedBox(height: 16),
        if (note.itemId != null)
          _LinkedItem(
            itemId: note.itemId!,
            noteId: note.id,
            attempt: note.reviewRating,
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.tonalIcon(
                onPressed: _createItem,
                icon: const Icon(Icons.add_circle_outline),
                label: const Text('Créer une connaissance'),
              ),
              OutlinedButton.icon(
                onPressed: _linkExisting,
                icon: const Icon(Icons.link),
                label: const Text('Lier à une connaissance'),
              ),
            ],
          ),
        const SizedBox(height: 16),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: _delete,
            icon: const Icon(Icons.delete_outline),
            label: const Text('Supprimer la note'),
          ),
        ),
      ],
    );
  }
}

class _LinkedItem extends StatelessWidget {
  const _LinkedItem({required this.itemId, required this.noteId, this.attempt});

  final String itemId;
  final String noteId;

  /// Note donnée si c'est une tentative de révision (pas un verso).
  final Rating? attempt;

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context).store;
    return FutureBuilder<KnowledgeItem?>(
      future: store.item(itemId),
      builder: (context, snapshot) {
        final item = snapshot.data;
        if (item == null) return const SizedBox.shrink();
        return Card.outlined(
          child: ListTile(
            leading: const Icon(Icons.flip_to_back),
            title: Text(item.title),
            subtitle: Text(
              attempt == null
                  ? 'Cette note est son verso'
                  : 'Tentative de révision · ${attempt!.label}',
            ),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => ItemDetailPage(itemId: item.id),
              ),
            ),
            // Une tentative reste attachée à sa connaissance (son historique).
            trailing: attempt != null
                ? null
                : IconButton(
                    tooltip: 'Délier',
                    icon: const Icon(Icons.link_off),
                    onPressed: () =>
                        store.updateNote(noteId, itemId: () => null),
                  ),
          ),
        );
      },
    );
  }
}
