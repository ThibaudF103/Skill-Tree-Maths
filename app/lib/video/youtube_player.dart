import 'package:flutter/material.dart';

import 'player_native.dart'
    if (dart.library.js_interop) 'player_web.dart'
    as platform;

/// État du lecteur, relevé régulièrement par la barre de lecture.
typedef VideoPlayback = ({
  int positionMs,
  int? durationMs,
  bool playing,
  bool muted,
  double rate,
});

/// Pilote du lecteur [YoutubePlayer] : temps courant, saut, extrait.
///
/// Les commandes de YouTube sont masquées : la barre de lecture maison
/// (`VideoControlBar`) passe par ce pilote.
abstract class YoutubePlayerController {
  factory YoutubePlayerController() = platform.PlatformYoutubeController;

  /// Position de lecture, en millisecondes (`null` avant le chargement).
  Future<int?> currentMs();

  /// Durée de la vidéo, en millisecondes (`null` tant qu'elle est inconnue).
  Future<int?> durationMs();

  Future<void> seek(int ms, {bool play = true});

  /// Joue l'extrait [startMs]–[endMs] puis s'arrête ([play] faux : se place
  /// au début sans lancer la lecture, l'arrêt reste programmé).
  Future<void> playSegment(int startMs, int? endMs, {bool play = true});

  Future<void> pause();

  Future<void> play();

  /// État courant (`null` avant le chargement).
  Future<VideoPlayback?> playback();

  Future<void> setMuted(bool muted);

  /// Vitesse de lecture (1 : normale).
  Future<void> setRate(double rate);

  /// Sous-titres (module `captions` du lecteur, piste par défaut).
  Future<void> setCaptions(bool on);
}

/// Paramètres communs du lecteur intégré : commandes de YouTube masquées,
/// annotations désactivées, lecture dans la page.
const playerVars = {
  'controls': '0',
  'iv_load_policy': '3',
  'fs': '0',
  'playsinline': '1',
  'rel': '0',
};

/// Origine déclarée par l'application : YouTube exige un référent (ou une
/// origine) pour les lecteurs intégrés.
const appOrigin = 'https://verger.app';

/// Adresse du lecteur intégré de YouTube.
String embedUrl(String videoId, {int startMs = 0, String? origin}) =>
    Uri.https('www.youtube.com', '/embed/$videoId', {
      'enablejsapi': '1',
      ...playerVars,
      if (startMs > 0) 'start': '${startMs ~/ 1000}',
      'origin': ?origin,
    }).toString();

/// Lecteur YouTube intégré, au format 16:9 : vue web sur ordinateur et
/// tablette, iframe dans la version web.
class YoutubePlayer extends StatelessWidget {
  const YoutubePlayer({
    super.key,
    required this.videoId,
    required this.controller,
    this.startMs = 0,
    this.endMs,
  });

  final String videoId;
  final YoutubePlayerController controller;

  /// Extrait à jouer au chargement (arrêt à [endMs]).
  final int startMs;
  final int? endMs;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: ColoredBox(
        color: Colors.black,
        child: platform.buildPlayer(
          videoId: videoId,
          controller: controller as platform.PlatformYoutubeController,
          startMs: startMs,
          endMs: endMs,
        ),
      ),
    );
  }
}
