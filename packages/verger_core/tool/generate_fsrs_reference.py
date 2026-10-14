"""Génère les valeurs de référence FSRS à partir de py-fsrs (implémentation officielle).

Usage (dans un environnement où `pip install fsrs==6.3.2` a été fait) :
    python tool/generate_fsrs_reference.py > test/fixtures/fsrs_reference.json

Le test `fsrs_reference_test.dart` rejoue exactement les mêmes révisions avec
notre adaptateur et vérifie que stabilité, difficulté, phase et échéance concordent.
"""

import json
from datetime import datetime, timedelta, timezone

import fsrs
from fsrs import Card, Rating, Scheduler

START = datetime(2026, 1, 5, 9, 0, tzinfo=timezone.utc)

# Chaque étape : (note, moment). Moment = "due" (à l'échéance), "+Nd" (N jours
# après la révision précédente), "+Nm" (N minutes après).
SCENARIOS = {
    "good_toujours_a_l_echeance": [("good", "due")] * 8,
    "easy_premiere_fois": [("easy", "due"), ("good", "due"), ("good", "due")],
    "again_puis_reprise": [
        ("good", "due"), ("good", "due"), ("good", "due"),
        ("again", "due"), ("good", "due"), ("good", "due"), ("good", "due"),
    ],
    "hard_repetes": [("hard", "due")] * 6,
    "revision_en_retard": [
        ("good", "due"), ("good", "due"), ("good", "+30d"), ("good", "+90d"),
    ],
    "revision_en_avance": [
        ("good", "due"), ("good", "due"), ("good", "due"), ("good", "+1d"),
    ],
    "meme_jour_plusieurs_fois": [
        ("again", "due"), ("again", "+1m"), ("good", "+5m"), ("good", "+10m"),
        ("good", "due"),
    ],
    "melange": [
        ("good", "due"), ("hard", "due"), ("good", "due"), ("easy", "due"),
        ("again", "due"), ("hard", "due"), ("good", "+3d"), ("easy", "due"),
    ],
}


def at(previous, card, spec):
    if spec == "due":
        return card.due
    amount, unit = int(spec[1:-1]), spec[-1]
    return previous + (timedelta(days=amount) if unit == "d" else timedelta(minutes=amount))


def main():
    scheduler = Scheduler(enable_fuzzing=False)
    out = {
        "generator": f"py-fsrs {fsrs.__version__ if hasattr(fsrs, '__version__') else '6.3.2'}",
        "parameters": list(scheduler.parameters),
        "desiredRetention": scheduler.desired_retention,
        "scenarios": {},
    }
    for name, steps in SCENARIOS.items():
        card = Card(card_id=1, due=START)
        previous = START
        records = []
        for rating_name, spec in steps:
            when = at(previous, card, spec)
            card, _ = scheduler.review_card(card, Rating[rating_name.capitalize()], review_datetime=when)
            previous = when
            records.append({
                "rating": rating_name,
                "reviewedAt": when.isoformat(),
                "state": card.state.name.lower(),
                "step": card.step,
                "stability": card.stability,
                "difficulty": card.difficulty,
                "due": card.due.isoformat(),
            })
        out["scenarios"][name] = records
    print(json.dumps(out, indent=2))


if __name__ == "__main__":
    main()
