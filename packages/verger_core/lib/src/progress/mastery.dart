import 'dart:math' as math;

import '../domain/scheduling_state.dart';

/// Maîtrise d'une connaissance entre 0 et 1, calculée (jamais stockée).
///
/// FSRS ne fournit pas de « pourcentage de maîtrise » : c'est notre propre
/// règle. Elle combine
/// - la probabilité de rappel actuelle R (baisse quand on tarde à réviser) ;
/// - la solidité de la mémoire : stabilité S rapportée à une cible, sur une
///   échelle logarithmique (passer de 1 à 10 jours compte autant que de 10 à
///   100 jours).
///
/// maîtrise = R × min(1, ln(1 + S) / ln(1 + cible))
final class MasteryModel {
  const MasteryModel({this.targetStabilityDays = 90});

  /// Stabilité à partir de laquelle la connaissance est considérée acquise.
  final double targetStabilityDays;

  double of(SchedulingState state, double retrievability) {
    final stability = state.stability;
    if (state.isNew || stability == null) return 0;
    final solidity = math.min(
      1.0,
      math.log(1 + stability) / math.log(1 + targetStabilityDays),
    );
    return (retrievability * solidity).clamp(0.0, 1.0);
  }
}
