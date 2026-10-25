import 'package:flutter/material.dart';
import 'package:verger_core/verger_core.dart';

import '../../app/app_scope.dart';
import '../../ui/labels.dart';
import '../../ui/math_text.dart';
import '../documents/document_viewer_page.dart';
import '../video/video_page.dart';
import 'ink_view.dart';
import 'note_split.dart';
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
                    : document.isVideo
                    ? 'Note · ${document.title} '
                          '${note?.startMs == null ? '' : formatClock(note!.startMs!)}'
                    : 'Note · ${document.title} p. ${note?.page ?? '–'}',
              ),
              actions: [
                if (note != null && document != null && document.isVideo)
                  TextButton.icon(
                    onPressed: () => Navigator.of(context).pushReplacement(
                      MaterialPageRoute<void>(
                        builder: (_) => VideoPage(
                          documentId: document.id,
                          startMs: note.startMs,
                          endMs: note.endMs,
                        ),
                      ),
                    ),
                    icon: const Icon(Icons.smart_display_outlined),
                    label: const Text('Ouvrir la vidéo'),
                  ),
                if (note != null && document != null && document.isPdf)
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

/// Éditeur d'une note désignée par son identifiant, suivie en base : pour
/// l'écran partagé ([NoteSplit]) d'une vidéo ou d'une fiche.
class LiveNoteEditor extends StatefulWidget {
  const LiveNoteEditor({
    super.key,
    required this.noteId,
    required this.onDeleted,
  });

  final String noteId;

  /// Note supprimée par l'utilisateur.
  final VoidCallback onDeleted;

  @override
  State<LiveNoteEditor> createState() => _LiveNoteEditorState();
}

class _LiveNoteEditorState extends State<LiveNoteEditor> {
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
    return Material(
      color: Theme.of(context).colorScheme.surface,
      child: FutureBuilder<SourceDocument?>(
        future: _document,
        builder: (context, docSnapshot) => StreamBuilder<Note?>(
          stream: _note,
          builder: (context, snapshot) {
            final note = snapshot.data;
            if (note == null) {
              return Center(
                child: snapshot.connectionState == ConnectionState.active
                    ? const Text('Note supprimée')
                    : const CircularProgressIndicator(),
              );
            }
            return NoteEditor(
              // Même éditeur tant que c'est la même note : la saisie en
              // cours n'est pas perdue.
              key: ValueKey(note.id),
              note: note,
              document: docSnapshot.data,
              onGoTo: null,
              onDeleted: widget.onDeleted,
            );
          },
        ),
      ),
    );
  }
}

/// Section « Notes » d'une connaissance : ses notes (verso), rendues en LaTeX.
class ItemNotesSection extends StatefulWidget {
  const ItemNotesSection({super.key, required this.item, this.onOpen});

  final KnowledgeItem item;

  /// Ouvre une note (dans l'écran partagé de la fiche) ; sans lui, la note
  /// s'ouvre dans sa propre page.
  final ValueChanged<String>? onOpen;

  @override
  State<ItemNotesSection> createState() => _ItemNotesSectionState();
}

class _ItemNotesSectionState extends State<ItemNotesSection> {
  Stream<List<Note>>? _notes;

  /// Toutes les tentatives (sinon les plus récentes).
  var _allAttempts = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _notes ??= AppScope.of(context).store.watchNotes(itemId: widget.item.id);
  }

  Future<void> _open(String noteId) async {
    if (widget.onOpen case final onOpen?) return onOpen(noteId);
    await Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => NotePage(noteId: noteId)));
  }

  Future<void> _newNote() async {
    final note = await AppScope.of(
      context,
    ).store.createNote(itemId: widget.item.id);
    if (!mounted) return;
    await _open(note.id);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return StreamBuilder<List<Note>>(
      stream: _notes,
      builder: (context, snapshot) {
        final all = snapshot.data ?? const <Note>[];
        final notes = [
          for (final n in all)
            if (!n.isReviewAttempt) n,
        ];
        // Tentatives des révisions : la plus récente d'abord.
        final attempts = [
          for (final n in all)
            if (n.isReviewAttempt) n,
        ]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
        final shown = _allAttempts ? attempts : attempts.take(3).toList();
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
                  onTap: () => _open(note.id),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: note.isBlank
                        ? Text(
                            'Note vide',
                            style: TextStyle(color: theme.colorScheme.outline),
                          )
                        : NoteContent(note: note),
                  ),
                ),
              ),
            OutlinedButton.icon(
              onPressed: _newNote,
              icon: const Icon(Icons.edit_note),
              label: const Text('Nouvelle note'),
            ),
            if (attempts.isNotEmpty) ...[
              const SizedBox(height: 24),
              Text(
                'Tentatives en révision (${attempts.length})',
                style: theme.textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              for (final note in shown)
                _AttemptCard(note: note, onTap: () => _open(note.id)),
              if (attempts.length > shown.length)
                TextButton(
                  onPressed: () => setState(() => _allAttempts = true),
                  child: Text(
                    'Voir les ${attempts.length - shown.length} plus anciennes',
                  ),
                ),
            ],
          ],
        );
      },
    );
  }
}

/// Tentative d'une révision : date et note données, puis ce qui a été
/// rédigé ; liseré de la couleur de la note.
class _AttemptCard extends StatelessWidget {
  const _AttemptCard({required this.note, required this.onTap});

  final Note note;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rating = note.reviewRating!;
    return Card.outlined(
      margin: const EdgeInsets.only(bottom: 12),
      color: theme.colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: rating.color.withValues(alpha: 0.6)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.history_edu, size: 18, color: rating.color),
                  const SizedBox(width: 8),
                  Text(
                    'Révision du ${formatDate(note.createdAt)}',
                    style: theme.textTheme.labelLarge,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    rating.label,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: rating.color,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              note.isBlank
                  ? Text(
                      'Note vide',
                      style: TextStyle(color: theme.colorScheme.outline),
                    )
                  : NoteContent(note: note),
            ],
          ),
        ),
      ),
    );
  }
}

/// Contenu d'une note : texte (LaTeX) puis écriture manuscrite.
class NoteContent extends StatelessWidget {
  const NoteContent({super.key, required this.note});

  final Note note;

  @override
  Widget build(BuildContext context) {
    final ink = note.ink;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (note.body.trim().isNotEmpty) MathText(note.body),
        if (note.body.trim().isNotEmpty && ink != null && !ink.isEmpty)
          const SizedBox(height: 8),
        if (ink != null && !ink.isEmpty) InkView(ink: ink),
      ],
    );
  }
}
