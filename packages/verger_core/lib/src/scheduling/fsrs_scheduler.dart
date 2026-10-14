import 'dart:math' as math;

import '../domain/learning_phase.dart';
import '../domain/rating.dart';
import '../domain/scheduling_state.dart';
import 'scheduler.dart';

// Portage de l'ordonnanceur FSRS-6 de py-fsrs 6.3.2
// (https://github.com/open-spaced-repetition/py-fsrs).
// Copyright (c) 2022 Open Spaced Repetition — licence MIT
// (texte complet : third_party/py-fsrs-LICENSE).
//
// Le package Dart `fsrs` (2.0.1) a été écarté : il diverge de l'implémentation
// officielle actuelle (stabilité à court terme après « Hard », borne de la
// difficulté cible). test/fsrs_reference_test.dart vérifie la concordance avec
// des valeurs calculées par py-fsrs (tool/generate_fsrs_reference.py).

/// Paramètres FSRS-6 par défaut de py-fsrs 6.3.2.
const fsrs6DefaultParameters = <double>[
  0.212, 1.2931, 2.3065, 8.2956, 6.4133, 0.8334, 3.0194, 0.001, 1.8722, //
  0.1666, 0.796, 1.4835, 0.0614, 0.2629, 1.6483, 0.6014, 1.8729, 0.5425,
  0.0912, 0.0658, 0.1542,
];

const _stabilityMin = 0.001;
const _minDifficulty = 1.0;
const _maxDifficulty = 10.0;

/// Ordonnanceur FSRS-6.
final class FsrsScheduler implements Scheduler {
  FsrsScheduler({
    this.desiredRetention = 0.9,
    List<double> parameters = fsrs6DefaultParameters,
    this.learningSteps = const [Duration(minutes: 1), Duration(minutes: 10)],
    this.relearningSteps = const [Duration(minutes: 10)],
    this.maximumInterval = 36500,
    this.enableFuzzing = true,
  }) : w = List.unmodifiable(parameters) {
    if (w.length != 21) {
      throw ArgumentError.value(parameters, 'parameters', '21 attendus');
    }
    if (desiredRetention <= 0 || desiredRetention >= 1) {
      throw ArgumentError.value(desiredRetention, 'desiredRetention');
    }
    _decay = -w[20];
    _factor = math.pow(0.9, 1 / _decay) - 1;
  }

  /// Poids du modèle (w0 … w20).
  final List<double> w;
  final double desiredRetention;
  final List<Duration> learningSteps;
  final List<Duration> relearningSteps;
  final int maximumInterval;

  /// Léger aléa sur les intervalles pour éviter que des connaissances créées
  /// ensemble reviennent toutes le même jour.
  final bool enableFuzzing;

  late final double _decay;
  late final double _factor;

  @override
  String get id => 'fsrs-6/r${desiredRetention.toStringAsFixed(2)}';

  @override
  double retrievability(SchedulingState state, DateTime at) {
    final lastReview = state.lastReview;
    final stability = state.stability;
    if (lastReview == null || stability == null) return 0;
    final elapsedDays = math.max(0, at.toUtc().difference(lastReview).inDays);
    return math.pow(1 + _factor * elapsedDays / stability, _decay).toDouble();
  }

  @override
  SchedulingState review(
    SchedulingState state,
    Rating rating,
    DateTime at, {
    String fuzzKey = '',
  }) {
    final now = at.toUtc();
    final lastReview = state.lastReview;
    final sameDay = lastReview != null && now.difference(lastReview).inDays < 1;

    var phase = state.phase == LearningPhase.newItem
        ? LearningPhase.learning
        : state.phase;
    var step = state.isNew ? 0 : state.step;
    double stability;
    double difficulty;

    // 1. Mise à jour de la stabilité et de la difficulté.
    final s = state.stability;
    final d = state.difficulty;
    if (s == null || d == null) {
      stability = _initialStability(rating);
      difficulty = _clampDifficulty(_initialDifficulty(rating));
    } else if (sameDay) {
      stability = _shortTermStability(s, rating);
      difficulty = _nextDifficulty(d, rating);
    } else {
      stability = _nextStability(d, s, retrievability(state, now), rating);
      difficulty = _nextDifficulty(d, rating);
    }

    // 2. Prochain intervalle.
    Duration interval;
    Duration toReview() {
      phase = LearningPhase.review;
      step = null;
      return Duration(days: _nextInterval(stability));
    }

    switch (phase) {
      case LearningPhase.review:
        if (rating == Rating.again && relearningSteps.isNotEmpty) {
          phase = LearningPhase.relearning;
          step = 0;
          interval = relearningSteps[0];
        } else {
          interval = Duration(days: _nextInterval(stability));
        }
      case LearningPhase.learning || LearningPhase.relearning:
        final steps = phase == LearningPhase.learning
            ? learningSteps
            : relearningSteps;
        final current = step ?? 0;
        if (steps.isEmpty ||
            (current >= steps.length && rating != Rating.again)) {
          interval = toReview();
        } else {
          switch (rating) {
            case Rating.again:
              step = 0;
              interval = steps[0];
            case Rating.hard:
              if (current == 0 && steps.length == 1) {
                interval = steps[0] * 1.5;
              } else if (current == 0) {
                interval = (steps[0] + steps[1]) ~/ 2;
              } else {
                interval = steps[math.min(current, steps.length - 1)];
              }
            case Rating.good:
              if (current + 1 == steps.length) {
                interval = toReview();
              } else {
                step = current + 1;
                interval = steps[current + 1];
              }
            case Rating.easy:
              interval = toReview();
          }
        }
      case LearningPhase.newItem:
        throw StateError('inaccessible');
    }

    if (enableFuzzing && phase == LearningPhase.review) {
      final seed = _stableHash(
        '$fuzzKey|${state.reps}|${rating.index}|'
        '${lastReview?.millisecondsSinceEpoch}',
      );
      interval = _fuzz(interval, math.Random(seed));
    }

    return SchedulingState(
      phase: phase,
      step: step,
      stability: stability,
      difficulty: difficulty,
      due: now.add(interval),
      lastReview: now,
      reps: state.reps + 1,
      lapses:
          state.lapses +
          (state.phase == LearningPhase.review && rating == Rating.again
              ? 1
              : 0),
    );
  }

  // --- Formules FSRS-6 ---

  int _grade(Rating rating) => rating.index + 1;

  double _clampStability(double s) => math.max(s, _stabilityMin);

  double _clampDifficulty(double d) => d.clamp(_minDifficulty, _maxDifficulty);

  double _initialStability(Rating rating) =>
      _clampStability(w[_grade(rating) - 1]);

  double _initialDifficulty(Rating rating) =>
      w[4] - math.exp(w[5] * (_grade(rating) - 1)) + 1;

  int _nextInterval(double stability) {
    final raw =
        stability / _factor * (math.pow(desiredRetention, 1 / _decay) - 1);
    return math.min(math.max(_roundHalfEven(raw), 1), maximumInterval);
  }

  double _shortTermStability(double stability, Rating rating) {
    var increase =
        math.exp(w[17] * (_grade(rating) - 3 + w[18])) *
        math.pow(stability, -w[19]);
    if (rating != Rating.again) increase = math.max(increase, 1.0);
    return _clampStability(stability * increase);
  }

  double _nextDifficulty(double difficulty, Rating rating) {
    final delta = -(w[6] * (_grade(rating) - 3));
    final damped = difficulty + (10.0 - difficulty) * delta / 9.0;
    // Retour vers la difficulté initiale « Easy », volontairement non bornée.
    final target = _initialDifficulty(Rating.easy);
    return _clampDifficulty(w[7] * target + (1 - w[7]) * damped);
  }

  double _nextStability(double d, double s, double r, Rating rating) {
    final next = rating == Rating.again
        ? math.min(
            w[11] *
                math.pow(d, -w[12]) *
                (math.pow(s + 1, w[13]) - 1) *
                math.exp((1 - r) * w[14]),
            s / math.exp(w[17] * w[18]),
          )
        : s *
              (1 +
                  math.exp(w[8]) *
                      (11 - d) *
                      math.pow(s, -w[9]) *
                      (math.exp((1 - r) * w[10]) - 1) *
                      (rating == Rating.hard ? w[15] : 1) *
                      (rating == Rating.easy ? w[16] : 1));
    return _clampStability(next.toDouble());
  }

  /// Même dispersion que py-fsrs (±5 à 15 % selon l'intervalle), tirée d'un
  /// générateur initialisé par la connaissance et la révision : l'aperçu des
  /// boutons et la révision réelle donnent la même échéance.
  Duration _fuzz(Duration interval, math.Random random) {
    final days = interval.inDays;
    if (days < 2.5) return interval;
    const ranges = [(2.5, 7.0, 0.15), (7.0, 20.0, 0.1), (20.0, 1e9, 0.05)];
    var delta = 1.0;
    for (final (start, end, factor) in ranges) {
      delta += factor * math.max(math.min(days.toDouble(), end) - start, 0.0);
    }
    final maxDays = math.min(_roundHalfEven(days + delta), maximumInterval);
    final minDays = math.min(
      math.max(2, _roundHalfEven(days - delta)),
      maxDays,
    );
    return Duration(days: minDays + random.nextInt(maxDays - minDays + 1));
  }

  /// Arrondi « au pair le plus proche », comme `round()` en Python.
  static int _roundHalfEven(num x) {
    final floor = x.floor();
    final diff = x - floor;
    if (diff > 0.5) return floor + 1;
    if (diff < 0.5) return floor;
    return floor.isEven ? floor : floor + 1;
  }

  /// FNV-1a 32 bits : stable d'une exécution à l'autre, contrairement à
  /// `String.hashCode`.
  static int _stableHash(String input) {
    var hash = 0x811c9dc5;
    for (final unit in input.codeUnits) {
      hash = ((hash ^ unit) * 0x01000193) & 0xffffffff;
    }
    return hash;
  }
}
