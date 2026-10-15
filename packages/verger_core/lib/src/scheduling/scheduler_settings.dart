import 'fsrs_scheduler.dart';
import 'scheduler.dart';

/// Réglages de révision choisis par l'utilisateur, persistés tels quels.
///
/// Diffèrent volontairement des valeurs de py-fsrs (1 min / 10 min) : pour des
/// définitions et des démonstrations, une nouvelle connaissance revient
/// 6 heures puis 1 jour après la première révision ; idem après un oubli.
final class SchedulerSettings {
  const SchedulerSettings({
    this.desiredRetention = 0.9,
    this.learningSteps = const [Duration(hours: 6), Duration(days: 1)],
    this.relearningSteps = const [Duration(hours: 6), Duration(days: 1)],
    this.maximumInterval = 36500,
  });

  factory SchedulerSettings.fromJson(Map<String, Object?> json) {
    List<Duration> steps(Object? value) => [
      for (final minutes in (value as List).cast<int>())
        Duration(minutes: minutes),
    ];
    final settings = SchedulerSettings(
      desiredRetention: (json['desiredRetention'] as num).toDouble(),
      learningSteps: steps(json['learningStepsMinutes']),
      relearningSteps: steps(json['relearningStepsMinutes']),
      maximumInterval: json['maximumInterval'] as int,
    );
    if (!settings.isValid) {
      throw FormatException('Réglages de révision invalides : $json');
    }
    return settings;
  }

  /// Valeurs acceptées par l'ordonnanceur.
  bool get isValid =>
      desiredRetention > 0 &&
      desiredRetention < 1 &&
      maximumInterval >= 1 &&
      learningSteps.every((d) => d > Duration.zero) &&
      relearningSteps.every((d) => d > Duration.zero);

  final double desiredRetention;
  final List<Duration> learningSteps;
  final List<Duration> relearningSteps;
  final int maximumInterval;

  Scheduler build() => FsrsScheduler(
    desiredRetention: desiredRetention,
    learningSteps: learningSteps,
    relearningSteps: relearningSteps,
    maximumInterval: maximumInterval,
  );

  Map<String, Object?> toJson() => {
    'desiredRetention': desiredRetention,
    'learningStepsMinutes': [for (final d in learningSteps) d.inMinutes],
    'relearningStepsMinutes': [for (final d in relearningSteps) d.inMinutes],
    'maximumInterval': maximumInterval,
  };
}
