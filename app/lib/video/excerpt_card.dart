import 'package:flutter/material.dart';
import 'package:verger_core/verger_core.dart';

import '../ui/labels.dart';
import '../features/documents/document_viewer_page.dart'
    show noteColor, rectoColor, versoColor;
import 'video_control_bar.dart';
import 'youtube_player.dart';

/// Vignette d'un extrait vidéo (recto ou verso) : image de la vidéo et
/// « Revoir l'extrait », qui joue exactement ce passage.
class VideoExcerptCard extends StatelessWidget {
  const VideoExcerptCard({
    super.key,
    required this.anchor,
    required this.document,
  });

  final Anchor anchor;

  /// Vidéo (`null` tant qu'elle n'est pas chargée, ou supprimée).
  final SourceDocument? document;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final video = document;
    return Row(
      children: [
        if (video != null)
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Image.network(
              'https://i.ytimg.com/vi/${video.contentHash}/mqdefault.jpg',
              width: 128,
              height: 72,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => const SizedBox(
                width: 128,
                height: 72,
                child: Icon(Icons.smart_display_outlined, size: 40),
              ),
            ),
          ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                video?.title ?? 'Vidéo supprimée',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                'Extrait ${anchorPlace(anchor)}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.outline,
                ),
              ),
              const SizedBox(height: 4),
              if (video != null)
                FilledButton.tonalIcon(
                  onPressed: () => showExcerpt(
                    context,
                    video,
                    anchor.startMs ?? 0,
                    anchor.endMs,
                  ),
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Revoir l\'extrait'),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Joue l'extrait [startMs]–[endMs] de [video] dans une fenêtre.
Future<void> showExcerpt(
  BuildContext context,
  SourceDocument video,
  int startMs,
  int? endMs,
) {
  final controller = YoutubePlayerController();
  return showDialog<void>(
    context: context,
    builder: (context) => Dialog(
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            YoutubePlayer(
              videoId: video.contentHash,
              controller: controller,
              startMs: startMs,
              endMs: endMs,
            ),
            // Commandes de YouTube masquées : barre maison, extrait encadré.
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
              child: VideoControlBar(
                controller: controller,
                selection: (startMs, endMs),
                rectoColor: rectoColor,
                versoColor: versoColor,
                noteColor: noteColor,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${video.title} · ${formatClock(startMs)}'
                      '${endMs == null ? '' : ' → ${formatClock(endMs)}'}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Rejouer',
                    icon: const Icon(Icons.replay),
                    onPressed: () => controller.playSegment(startMs, endMs),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Fermer'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
