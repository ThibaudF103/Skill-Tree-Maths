import 'package:flutter/material.dart';
import 'package:verger_core/verger_core.dart';
import 'package:verger_data/verger_data.dart';

import '../../app/app_scope.dart';
import '../../ui/labels.dart';
import '../../ui/coverage.dart';
import '../../video/video_timeline.dart';
import '../../video/youtube_player.dart';
import '../documents/document_viewer_page.dart'
    show noteColor, rectoColor, versoColor;
import '../documents/pickers.dart';
import '../items/item_detail_page.dart';
import '../items/item_editor.dart';
import '../notes/note_page.dart';

/// Vidéo YouTube : lecture, extraits (début / fin) à transformer en note,
/// en connaissance (recto ou verso) ou à attacher ; extraits et notes déjà
/// liés à la vidéo.
class VideoPage extends StatefulWidget {
  const VideoPage({
    super.key,
    required this.documentId,
    this.startMs,
    this.endMs,
    this.attachToItem,
  });

  final String documentId;

  /// Extrait à jouer à l'ouverture.
  final int? startMs;
  final int? endMs;

  /// Connaissance à laquelle attacher directement l'extrait marqué.
  final KnowledgeItem? attachToItem;

  @override
  State<VideoPage> createState() => _VideoPageState();
}

class _VideoPageState extends State<VideoPage> {
  final _player = YoutubePlayerController();
  Future<SourceDocument?>? _document;
  Stream<List<Anchor>>? _anchors;
  Stream<List<Note>>? _notes;
  Stream<List<KnowledgeItem>>? _items;
  Stream<List<Anchor>>? _timelineAnchors;
  Stream<List<Note>>? _timelineNotes;
  int? _start;
  int? _end;

  /// Une fenêtre couvre le lecteur : il est masqué le temps de l'échange
  /// (dans la version web, une iframe capterait les clics destinés à la
  /// fenêtre).
  var _covered = false;

  Future<T> _covering<T>(Future<T> Function() action) async {
    setState(() => _covered = true);
    try {
      return await action();
    } finally {
      if (mounted) setState(() => _covered = false);
    }
  }

  VergerStore get _store => AppScope.of(context).store;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _document ??= _store.document(widget.documentId);
    _anchors ??= _store.watchAnchors(documentId: widget.documentId);
    _notes ??= _store.watchNotes(documentId: widget.documentId);
    _items ??= _store.watchItems();
    _timelineAnchors ??= _store.watchAnchors(documentId: widget.documentId);
    _timelineNotes ??= _store.watchNotes(documentId: widget.documentId);
  }

  Future<void> _mark({required bool start}) async {
    final now = await _player.currentMs();
    if (now == null || !mounted) return;
    setState(() {
      if (start) {
        _start = now;
        if (_end != null && _end! <= now) _end = null;
      } else {
        _end = now;
        if (_start == null || _start! >= now) _start = 0;
      }
    });
  }

  Future<void> _useExcerpt(SourceDocument document) =>
      _covering(() => _useExcerptCovered(document));

  Future<void> _useExcerptCovered(SourceDocument document) async {
    final start = _start;
    if (start == null) return;
    final end = _end;
    final target = widget.attachToItem;
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: target != null
              ? [
                  ListTile(
                    leading: const Icon(Icons.flip_to_front, color: rectoColor),
                    title: Text('Recto de « ${target.title} »'),
                    onTap: () => Navigator.pop(context, 'source'),
                  ),
                  ListTile(
                    leading: const Icon(Icons.flip_to_back, color: versoColor),
                    title: Text('Verso de « ${target.title} »'),
                    onTap: () => Navigator.pop(context, 'work'),
                  ),
                ]
              : [
                  ListTile(
                    leading: const Icon(Icons.edit_note, color: noteColor),
                    title: const Text('Prendre une note sur cet extrait'),
                    onTap: () => Navigator.pop(context, 'note'),
                  ),
                  ListTile(
                    leading: const Icon(Icons.add_circle_outline),
                    title: const Text('Créer une connaissance (énoncé)'),
                    subtitle: const Text('L\'extrait devient son recto'),
                    onTap: () => Navigator.pop(context, 'create'),
                  ),
                  ListTile(
                    leading: const Icon(Icons.add_circle_outline),
                    title: const Text('Créer une connaissance (démonstration)'),
                    subtitle: const Text('L\'extrait devient son verso'),
                    onTap: () => Navigator.pop(context, 'createWork'),
                  ),
                  ListTile(
                    leading: const Icon(Icons.flip_to_front, color: rectoColor),
                    title: const Text('Attacher comme recto…'),
                    onTap: () => Navigator.pop(context, 'source'),
                  ),
                  ListTile(
                    leading: const Icon(Icons.flip_to_back, color: versoColor),
                    title: const Text('Attacher comme verso…'),
                    onTap: () => Navigator.pop(context, 'work'),
                  ),
                ],
        ),
      ),
    );
    if (action == null || !mounted) return;
    if (action == 'note') {
      final note = await _store.createNote(
        documentId: document.id,
        startMs: start,
        endMs: end,
      );
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => NotePage(noteId: note.id)),
      );
      return;
    }
    final work = action == 'work' || action == 'createWork';
    var item = target;
    if (item == null) {
      if (action.startsWith('create')) {
        item = await showItemEditor(context, family: ItemFamily.statement);
      } else {
        item = await pickItem(
          context,
          title: work
              ? 'Verso de quelle connaissance ?'
              : 'Recto de quelle connaissance ?',
        );
      }
    }
    if (item == null || !mounted) return;
    await _store.addAnchor(
      itemId: item.id,
      documentId: document.id,
      role: work ? AnchorRole.work : AnchorRole.source,
      startMs: start,
      endMs: end,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${work ? 'Verso' : 'Recto'} attaché à « ${item.title} ».',
        ),
      ),
    );
    if (target != null) {
      Navigator.of(context).pop();
    } else {
      setState(() => _start = _end = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<SourceDocument?>(
      future: _document,
      builder: (context, snapshot) {
        final document = snapshot.data;
        if (document == null) {
          return Scaffold(
            appBar: AppBar(),
            body: Center(
              child: snapshot.connectionState == ConnectionState.done
                  ? const Text('Vidéo introuvable')
                  : const CircularProgressIndicator(),
            ),
          );
        }
        return Scaffold(
          appBar: AppBar(title: Text(document.title)),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 960),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Stack(
                        children: [
                          const AspectRatio(
                            aspectRatio: 16 / 9,
                            child: ColoredBox(color: Colors.black),
                          ),
                          Offstage(
                            offstage: _covered,
                            child: YoutubePlayer(
                              videoId: document.contentHash,
                              controller: _player,
                              startMs: widget.startMs ?? 0,
                              endMs: widget.endMs,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      StreamBuilder<List<Anchor>>(
                        stream: _timelineAnchors,
                        builder: (context, anchors) =>
                            StreamBuilder<List<Note>>(
                              stream: _timelineNotes,
                              builder: (context, notes) => VideoTimeline(
                                controller: _player,
                                spans: videoCoverage(
                                  anchors.data ?? const [],
                                  notes.data ?? const [],
                                ),
                                selection: _start == null
                                    ? null
                                    : (_start!, _end),
                                rectoColor: rectoColor,
                                versoColor: versoColor,
                                noteColor: noteColor,
                              ),
                            ),
                      ),
                      const SizedBox(height: 8),
                      _excerptBar(document),
                      const SizedBox(height: 24),
                      _linked(context),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _excerptBar(SourceDocument document) {
    final theme = Theme.of(context);
    final start = _start;
    final end = _end;
    return Card.outlined(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              widget.attachToItem != null
                  ? 'Extrait pour « ${widget.attachToItem!.title} » :'
                  : 'Extrait :',
              style: theme.textTheme.titleSmall,
            ),
            OutlinedButton.icon(
              onPressed: () => _mark(start: true),
              icon: const Icon(Icons.first_page),
              label: Text(
                start == null ? 'Marquer le début' : formatClock(start),
              ),
            ),
            OutlinedButton.icon(
              onPressed: () => _mark(start: false),
              icon: const Icon(Icons.last_page),
              label: Text(end == null ? 'Marquer la fin' : formatClock(end)),
            ),
            if (start != null) ...[
              IconButton(
                tooltip: 'Revoir l\'extrait',
                icon: const Icon(Icons.replay),
                onPressed: () => _player.playSegment(start, end),
              ),
              IconButton(
                tooltip: 'Effacer',
                icon: const Icon(Icons.clear),
                onPressed: () => setState(() => _start = _end = null),
              ),
              FilledButton.icon(
                onPressed: () => _useExcerpt(document),
                icon: const Icon(Icons.check),
                label: const Text('Utiliser l\'extrait…'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _linked(BuildContext context) {
    final theme = Theme.of(context);
    return StreamBuilder<List<KnowledgeItem>>(
      stream: _items,
      builder: (context, items) => StreamBuilder<List<Anchor>>(
        stream: _anchors,
        builder: (context, anchors) => StreamBuilder<List<Note>>(
          stream: _notes,
          builder: (context, notes) {
            final titles = {
              for (final i in items.data ?? const <KnowledgeItem>[])
                i.id: i.title,
            };
            final excerpts = [...?anchors.data]
              ..sort((a, b) => (a.startMs ?? 0).compareTo(b.startMs ?? 0));
            final timed = [...?notes.data]
              ..sort((a, b) => (a.startMs ?? 0).compareTo(b.startMs ?? 0));
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Extraits liés', style: theme.textTheme.titleMedium),
                const Divider(),
                if (excerpts.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: Text(
                      'Marquez le début et la fin d\'un passage pour en faire '
                      'le recto ou le verso d\'une connaissance.',
                      style: TextStyle(color: theme.colorScheme.outline),
                    ),
                  ),
                for (final a in excerpts)
                  ListTile(
                    leading: Icon(
                      a.role == AnchorRole.source
                          ? Icons.flip_to_front
                          : Icons.flip_to_back,
                      color: a.role == AnchorRole.source
                          ? rectoColor
                          : versoColor,
                    ),
                    title: Text(titles[a.itemId] ?? 'Connaissance'),
                    subtitle: Text(
                      '${a.role == AnchorRole.source ? 'Recto' : 'Verso'} · '
                      '${anchorPlace(a)}',
                    ),
                    onTap: () => _player.playSegment(a.startMs ?? 0, a.endMs),
                    trailing: IconButton(
                      tooltip: 'Ouvrir la connaissance',
                      icon: const Icon(Icons.open_in_new),
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => ItemDetailPage(itemId: a.itemId),
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 16),
                Text('Notes', style: theme.textTheme.titleMedium),
                const Divider(),
                if (timed.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: Text(
                      'Aucune note sur cette vidéo.',
                      style: TextStyle(color: theme.colorScheme.outline),
                    ),
                  ),
                for (final n in timed)
                  ListTile(
                    leading: const Icon(Icons.edit_note, color: noteColor),
                    title: Text(
                      n.headline.isEmpty ? 'Note vide' : n.headline,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      n.startMs == null ? '–' : formatClock(n.startMs!),
                    ),
                    onTap: () => n.startMs == null
                        ? null
                        : _player.playSegment(n.startMs!, n.endMs),
                    trailing: IconButton(
                      tooltip: 'Ouvrir la note',
                      icon: const Icon(Icons.open_in_new),
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => NotePage(noteId: n.id),
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}
