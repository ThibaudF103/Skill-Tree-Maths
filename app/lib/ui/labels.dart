import 'package:flutter/widgets.dart' show Color, StringCharacters;
import 'package:verger_core/verger_core.dart';

/// Libellés français de l'interface.
extension ItemKindLabel on ItemKind {
  String get label => switch (this) {
    ItemKind.definition => 'Définition',
    ItemKind.statement => 'Énoncé',
    ItemKind.theorem => 'Théorème',
    ItemKind.proposition => 'Proposition',
    ItemKind.lemma => 'Lemme',
    ItemKind.property => 'Propriété',
    ItemKind.corollary => 'Corollaire',
    ItemKind.exercise => 'Exercice',
  };
}

/// Durée d'une vidéo en « 1:02:03 » ou « 12:05 ».
String formatClock(int milliseconds) {
  final total = milliseconds ~/ 1000;
  String two(int n) => n.toString().padLeft(2, '0');
  final h = total ~/ 3600;
  final m = total ~/ 60 % 60;
  final s = total % 60;
  return h > 0 ? '$h:${two(m)}:${two(s)}' : '$m:${two(s)}';
}

/// Endroit d'une ancre : « p. 12 » ou « 12:30 → 14:05 ».
String anchorPlace(Anchor anchor) {
  final page = anchor.page;
  if (page != null) return 'p. $page';
  final start = formatClock(anchor.startMs ?? 0);
  final end = anchor.endMs;
  return end == null ? start : '$start → ${formatClock(end)}';
}

extension ExerciseLevelLabel on ExerciseLevel {
  String get label => switch (this) {
    ExerciseLevel.easy => 'Facile',
    ExerciseLevel.medium => 'Moyen',
    ExerciseLevel.hard => 'Difficile',
  };
}

extension ItemTypeLabel on KnowledgeItem {
  /// Type affiché, avec la difficulté d'un exercice : « Exercice · difficile ».
  String get typeLabel {
    final level = this.level;
    return level == null
        ? kind.label
        : '${kind.label} · ${level.label.toLowerCase()}';
  }
}

extension ItemFamilyLabel on ItemFamily {
  String get label => switch (this) {
    ItemFamily.definition => 'Définition',
    ItemFamily.statement => 'Énoncé',
    ItemFamily.exercise => 'Exercice',
  };
}

extension GrowthStageLabel on GrowthStage {
  String get label => switch (this) {
    GrowthStage.bud => 'Bourgeon',
    GrowthStage.sprout => 'Pousse',
    GrowthStage.young => 'Jeune',
    GrowthStage.developed => 'Développé',
    GrowthStage.mature => 'Mûr',
  };
}

extension RatingLabel on Rating {
  String get label => switch (this) {
    Rating.again => 'À revoir',
    Rating.hard => 'Difficile',
    Rating.good => 'Correct',
    Rating.easy => 'Facile',
  };

  /// Couleur des boutons de note et des tentatives de révision.
  Color get color => switch (this) {
    Rating.again => const Color(0xFFC8553D),
    Rating.hard => const Color(0xFFE09A3E),
    Rating.good => const Color(0xFF5B7F5E),
    Rating.easy => const Color(0xFF3F7CAC),
  };
}

extension LearningPhaseLabel on LearningPhase {
  String get label => switch (this) {
    LearningPhase.newItem => 'Nouvelle',
    LearningPhase.learning => 'En apprentissage',
    LearningPhase.review => 'En révision espacée',
    LearningPhase.relearning => 'En réapprentissage',
  };
}

const _months = [
  'janv.', 'févr.', 'mars', 'avr.', 'mai', 'juin', //
  'juil.', 'août', 'sept.', 'oct.', 'nov.', 'déc.',
];

/// « 18 oct. » ou « 18 oct. 2027 » si l'année diffère.
String formatDate(DateTime date, {DateTime? now}) {
  final local = date.toLocal();
  final ref = (now ?? DateTime.now()).toLocal();
  final base = '${local.day} ${_months[local.month - 1]}';
  return local.year == ref.year ? base : '$base ${local.year}';
}

/// Nombre de jours de calendrier de [from] à [to] (indépendant des
/// changements d'heure).
int _calendarDays(DateTime from, DateTime to) => DateTime.utc(
  to.year,
  to.month,
  to.day,
).difference(DateTime.utc(from.year, from.month, from.day)).inDays;

/// Échéance relative : « en retard de 2 j », « aujourd'hui », « dans 5 h »,
/// « demain », « dans 12 j »…
String formatDue(DateTime due, DateTime now) {
  final window = DayWindow.around(now);
  final local = due.toLocal();
  if (local.isBefore(window.startOfToday)) {
    final days = _calendarDays(local, window.startOfToday);
    return 'en retard de ${days < 1 ? 1 : days} j';
  }
  if (local.isBefore(window.startOfTomorrow)) {
    if (!local.isAfter(now)) return 'maintenant';
    final hours = local.difference(now).inHours;
    return hours >= 1 ? 'dans $hours h' : "aujourd'hui";
  }
  if (local.isBefore(window.startOfDayAfter)) return 'demain';
  final days =
      DateTime(
        local.year,
        local.month,
        local.day,
      ).difference(window.startOfToday).inHours ~/
      24;
  return days < 60 ? 'dans $days j' : 'le ${formatDate(due, now: now)}';
}

/// Intervalle court et lisible : « 10 min », « 6 h », « 4 j », « 3 mois ».
String formatInterval(Duration d) {
  if (d.inMinutes < 60) return '${d.inMinutes} min';
  if (d.inHours < 24) return '${d.inHours} h';
  final days = (d.inHours / 24).round();
  if (days < 31) return '$days j';
  if (days < 365) return '${(days / 30.4).round()} mois';
  final years = days / 365;
  return years < 10
      ? '${years.toStringAsFixed(1).replaceAll('.', ',')} an${years >= 2 ? 's' : ''}'
      : '${years.round()} ans';
}

/// Durée de session : « 45 s », « 12 min », « 1 h 05 ».
String formatElapsed(Duration d) {
  if (d.inSeconds < 60) return '${d.inSeconds} s';
  if (d.inMinutes < 60) return '${d.inMinutes} min';
  return '${d.inHours} h ${(d.inMinutes % 60).toString().padLeft(2, '0')}';
}

/// Raccourcit un titre à [max] caractères (points de suspension).
String shortenTitle(String text, {int max = 80}) {
  final chars = text.trim().characters;
  return chars.length <= max ? chars.toString() : '${chars.take(max - 1)}…';
}

/// Première phrase d'un texte extrait d'un PDF, raccourcie : bon titre par
/// défaut pour une connaissance.
String? suggestTitle(String? text) {
  if (text == null) return null;
  final sentence = text
      .split(RegExp(r'(?<=[.:])\s'))
      .first
      .trim()
      .replaceFirst(RegExp(r'[.:]$'), '');
  return shortenTitle(sentence);
}
