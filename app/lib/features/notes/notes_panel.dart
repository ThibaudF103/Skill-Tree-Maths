import 'dart:async';

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
import 'ink_editor_page.dart';
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
    required this.onClose,
    required this.onGoTo,
  });

  final SourceDocument document;
  final List<Note> notes;
  final String? activeNoteId;
  final int currentPage;

  /// Ouvre une note (`null` : retour à la liste).
  final ValueChanged<String?> onSelect;
  final VoidCallback onClose;

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

/// Édition d'une note : texte avec enregistrement automatique, aperçu LaTeX,
/// zone du PDF, lien vers une connaissance.
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

  @override
  State<NoteEditor> createState() => _NoteEditorState();
}

class _NoteEditorState extends State<NoteEditor> {
  late final _text = TextEditingController(text: widget.note.body);

  /// Dernier texte enregistré (la note reçue peut être ancienne).
  late String _saved = widget.note.body;
  Timer? _save;
  late VergerStore _store;

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

  Future<void> _flush() async {
    _save?.cancel();
    _save = null;
    final text = _text.text;
    if (text != _saved) {
      _saved = text;
      await _store.updateNote(widget.note.id, body: text);
    }
  }

  @override
  void dispose() {
    // Une note sans texte, sans écriture ni zone n'a rien à garder : on ne
    // laisse pas de notes vides derrière soi. L'écriture est relue en base
    // (la note reçue peut dater d'avant le passage à l'éditeur manuscrit).
    if (_text.text.trim().isEmpty && widget.note.region == null) {
      _save?.cancel();
      final store = _store, id = widget.note.id;
      store.note(id).then((n) async {
        if (n != null && n.isBlank) await store.deleteNote(id);
      });
    } else if (_save != null) {
      _flush();
    }
    _text.dispose();
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
        const SizedBox(height: 16),
        _Handwriting(note: note, beforeOpen: _flush),
        const SizedBox(height: 16),
        if (note.itemId != null)
          _LinkedItem(itemId: note.itemId!, noteId: note.id)
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

/// Écriture manuscrite de la note : aperçu et accès à l'éditeur.
class _Handwriting extends StatelessWidget {
  const _Handwriting({required this.note, required this.beforeOpen});

  final Note note;
  final Future<void> Function() beforeOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ink = note.ink;
    Future<void> open() async {
      await beforeOpen();
      if (context.mounted) {
        await Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => InkEditorPage(note: note)),
        );
      }
    }

    if (ink == null || ink.isEmpty) {
      return Align(
        alignment: Alignment.centerLeft,
        child: OutlinedButton.icon(
          onPressed: open,
          icon: const Icon(Icons.draw_outlined),
          label: const Text('Écrire à la main'),
        ),
      );
    }
    return InkWell(
      onTap: open,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          border: Border.all(color: theme.colorScheme.outlineVariant),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkView(ink: ink),
            Text(
              'Toucher pour modifier l\'écriture',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LinkedItem extends StatelessWidget {
  const _LinkedItem({required this.itemId, required this.noteId});

  final String itemId;
  final String noteId;

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
            subtitle: const Text('Cette note est son verso'),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => ItemDetailPage(itemId: item.id),
              ),
            ),
            trailing: IconButton(
              tooltip: 'Délier',
              icon: const Icon(Icons.link_off),
              onPressed: () => store.updateNote(noteId, itemId: () => null),
            ),
          ),
        );
      },
    );
  }
}
