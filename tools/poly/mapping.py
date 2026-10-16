"""Sections du poly → branches du programme (préfixe le plus long)."""
P = 'agreg2026.'
MAP = {
    # I Analyse à une variable réelle
    'I.1': '6.1', 'I.2.1': '6.1', 'I.2.2': '6.2', 'I.2.3': '6.2',
    'I.3.1': '6.3.a', 'I.3.2': '6.3.a', 'I.3.2.3': '8.1.d',
    'I.3.3': '6.3.b', 'I.3.4': '6.4', 'I.4': '6.6',
    'I.5.1': '6.5.a', 'I.5.1.5': '12.3', 'I.5.2': '6.5.b', 'I.5.3': '6.5',
    'I.6.1': '6.1', 'I.6.2.1': '6.3.a', 'I.6.2.2': '6.7', 'I.6.3': '6.3.b',
    'I.6.4': '6.3.b', 'I.6.5': '6', 'I.6.6': '6', 'I.7': '6',
    # II Analyse à une variable complexe
    'II.1': '7', 'II.2.1': '7.1.a', 'II.2.2': '7.1.a', 'II.2.3': '7.1.a',
    'II.2.4': '7.1.b', 'II.2.5': '7.1.b', 'II.2.6': '7.1.b', 'II.2.7': '7.1',
    'II.3.1': '7.2.a', 'II.3.2': '7.2.a', 'II.3.3': '7.2.a',
    'II.3.4.1': '7.2.b', 'II.3.4.2': '7.2.c', 'II.3.5': '7.2.c',
    'II.3.6': '7.2.a', 'II.3.7': '7.2.e', 'II.3.8': '7.2.d', 'II.3.9': '7.2',
    'II.4': '7', 'II.4.1': '7.1.a', 'II.4.2': '7.1.b', 'II.4.3': '7.2.d',
    'II.4.4': '7.2.a', 'II.4.5': '7.2.c', 'II.4.7': '7.2.c', 'II.4.8': '7.2.c',
    'II.4.8.4': '7.2.d', 'II.4.10': '7.2.d', 'II.4.11': '7.2.d', 'II.5': '7',
    # III Topologie
    'III.1.1': '8.1.a', 'III.1.2': '8.1.b', 'III.1.3': '8.1.b',
    'III.1.4': '8.1.e', 'III.1.5': '8.1.c', 'III.1.6': '8.1.c',
    'III.2.1': '8.2.a', 'III.2.2': '8.2.a', 'III.2.3': '8.1.c',
    'III.2.4.1': '8.2.a', 'III.2.4.2': '8.2.d', 'III.2.4.3': '8.1.c',
    'III.2.5': '8.2.b', 'III.3': '8.2.c', 'III.3.2': '8.2.d', 'III.4': '8',
    # IV Intégration de Lebesgue
    'IV.1': '10.1', 'IV.2': '10.2.a', 'IV.3.1': '10.2.a', 'IV.3.2': '10.2.a',
    'IV.3.3': '10.2.b', 'IV.4': '10.2.d', 'IV.4.1': '10.1', 'IV.4.2': '10.1',
    'IV.5.1': '10.2.c', 'IV.5.2': '10.2.c', 'IV.5.3': '10.2.e',
    'IV.5.4': '10.2.e', 'IV.6': '10.1',
    # V Probabilités
    'V.1': '11.1', 'V.2': '11.2.a', 'V.3': '11.2.a', 'V.3.4': '11.3.a',
    'V.4.1': '11.2.a', 'V.4.2': '11.2.b', 'V.4.3': '11.2.b',
    'V.5.1': '11.3.a', 'V.5.2': '11.3.a', 'V.5.3': '11.3.b',
    'V.5.3.1': '11.4.c', 'V.6': '11.3.a', 'V.6.5': '11.3.b',
    # VI Analyse numérique
    'VI.1': '12.4', 'VI.2': '12.2', 'VI.3': '12.5', 'VI.3.4': '9.2.a',
    # VII Calcul différentiel
    'VII.1.1': '9.1.a', 'VII.1.2': '9.1.a', 'VII.1.3': '9.1.a',
    'VII.1.4': '9.1.b', 'VII.1.5': '9.1.b', 'VII.2': '9.1.c',
    'VII.3': '9.1.f', 'VII.4': '9.3.a', 'VII.5.1': '9.1.e',
    'VII.5.2.1': '9.1.d', 'VII.5.2.2': '9.3.c', 'VII': '9.1',
    # VIII Analyse de Fourier (et distributions, hors programme)
    'VIII.1': '10.3.a', 'VIII.2': '10.3.b', 'VIII.3': '10.3',
    # IX Topologie 2 et analyse fonctionnelle
    'IX.1.1': '8.3.a', 'IX.1.2': '8.3.b', 'IX.1.3': '8.3.c',
    'IX.2': 'option-b.e', 'IX.3': '8',
    # X Équations différentielles
    'X.1': '9.2.a', 'X.2': '9.2.c', 'X.3': '9.2.c', 'X.4': '9.2.b',
}

def node_for(section):
    """Branche du programme pour la section « II.3.4.1 » du poly."""
    parts = section.split('.')
    for n in range(len(parts), 0, -1):
        key = '.'.join(parts[:n])
        if key in MAP:
            return P + MAP[key]
    raise KeyError(section)
