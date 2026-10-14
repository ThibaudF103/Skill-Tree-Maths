import 'package:test/test.dart';
import 'package:verger_core/verger_core.dart';

void main() {
  test('SchedulingState : aller-retour JSON', () {
    final state = SchedulingState(
      phase: LearningPhase.relearning,
      step: 0,
      stability: 3.25,
      difficulty: 6.5,
      due: DateTime.utc(2026, 3, 4, 15, 30, 12, 345),
      lastReview: DateTime.utc(2026, 3, 4, 9),
      reps: 7,
      lapses: 2,
    );
    expect(SchedulingState.fromJson(state.toJson()), state);
    expect(
      SchedulingState.fromJson(SchedulingState.initial.toJson()),
      SchedulingState.initial,
    );
  });
}
