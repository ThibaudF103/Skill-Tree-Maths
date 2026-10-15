import 'package:flutter/material.dart';
import 'package:verger_core/verger_core.dart';

import '../../app/app_scope.dart';
import '../../ui/math_text.dart';
import '../documents/document_viewer_page.dart';
import 'notes_panel.dart';

/// Page d'édition d'une note (hors visionneuse).
class NotePage extends StatefulWidget {
  const NotePage({super.key, required this.noteId});

  final String noteId;

  @override
  State<NotePage> createState() => _NotePageState();
}

class _NotePageState extends State<NotePage> {
  Stream<Note?>? _note;
  Future<SourceDocument?>? _document;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final store = AppScope.of(context).store;
    _note ??= store.watchNote(widget.noteId);
    _document ??= store
        .note(widget.noteId)
        .then(
          (n) => n?.documentId == null ? null : store.document(n!.documentId!),
        );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<SourceDocument?>(
      future: _document,
      builder: (context, docSnapshot) => StreamBuilder<Note?>(
        stream: _note,
        builder: (context, snapshot) {
          final note = snapshot.data;
          final document = docSnapshot.data;
          final loading =
              !snapshot.hasData &&
              snapshot.connectionState != ConnectionState.active;
          return Scaffold(
            appBar: AppBar(
              title: Text(
                document == null
                    ? 'Note'
                    : 'Note · ${document.title} p. ${note?.page ?? '–'}',
              ),
              actions: [
                if (note != null && document != null)
                  TextButton.icon(
                    onPressed: () => Navigator.of(context).pushReplacement(
                      MaterialPageRoute<void>(
                        builder: (_) => DocumentViewerPage(
                          documentId: document.id,
                          initialPage: note.page,
                          highlight: note.region,
                          openNoteId: note.id,
                        ),
                      ),
                    ),
                    icon: const Icon(Icons.picture_as_pdf_outlined),
                    label: const Text('Ouvrir avec le PDF'),
                  ),
              ],
            ),
            body: loading
                ? const Center(child: CircularProgressIndicator())
                : note == null
                ? const Center(child: Text('Note supprimée'))
                : Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 760),
                      child: NoteEditor(
                        // Même éditeur tant que c'est la même note : la
                        // saisie en cours n'est pas perdue.
                        key: ValueKey(note.id),
                        note: note,
                        document: document,
                        onGoTo: null,
                        onDeleted: () => Navigator.of(context).pop(),
                      ),
                    ),
                  ),
          );
        },
      ),
    );
  }
}

/// Section « Notes » d'une connaissance : ses notes (verso), rendues en LaTeX.
class ItemNotesSection extends StatefulWidget {
  const ItemNotesSection({super.key, required this.item});

  final KnowledgeItem item;

  @override
  State<ItemNotesSection> createState() => _ItemNotesSectionState();
}

class _ItemNotesSectionState extends State<ItemNotesSection> {
  Stream<List<Note>>? _notes;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _notes ??= AppScope.of(context).store.watchNotes(itemId: widget.item.id);
  }

  Future<void> _newNote() async {
    final note = await AppScope.of(
      context,
    ).store.createNote(itemId: widget.item.id);
    if (!mounted) return;
    await Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => NotePage(noteId: note.id)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return StreamBuilder<List<Note>>(
      stream: _notes,
      builder: (context, snapshot) {
        final notes = snapshot.data ?? const <Note>[];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (notes.isEmpty)
              Text(
                'Aucune note : rédigez la démonstration ou la solution ici, '
                'ou depuis le panneau de notes d\'un PDF.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.outline,
                ),
              ),
            for (final note in notes)
              Card.outlined(
                margin: const EdgeInsets.only(bottom: 12),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => NotePage(noteId: note.id),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: note.body.trim().isEmpty
                        ? Text(
                            'Note vide',
                            style: TextStyle(color: theme.colorScheme.outline),
                          )
                        : MathText(note.body),
                  ),
                ),
              ),
            OutlinedButton.icon(
              onPressed: _newNote,
              icon: const Icon(Icons.edit_note),
              label: const Text('Nouvelle note'),
            ),
          ],
        );
      },
    );
  }
}
