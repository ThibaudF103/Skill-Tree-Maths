"""Structure du poly de J. Lamboley (version du 5 février 2023) : chapitres
par page imprimée, lecture des lignes de texte horizontales."""
import re, unicodedata, pymupdf

CHAPTERS = [  # (première page imprimée, chiffre romain, titre)
    (33, 'I', 'Analyse réelle'), (113, 'II', 'Analyse complexe'),
    (173, 'III', 'Topologie'), (231, 'IV', 'Lebesgue'),
    (293, 'V', 'Probabilités'), (343, 'VI', 'Analyse numérique'),
    (363, 'VII', 'Calcul différentiel'), (405, 'VIII', 'Fourier'),
    (455, 'IX', 'Topologie 2'), (501, 'X', 'EDO'), (535, None, 'Biblio'),
]
norm = lambda t: unicodedata.normalize('NFKC', t)

def chapter(page1):
    cur = None
    for start, roman, _ in CHAPTERS:
        if page1 >= start: cur = roman
    return cur

def lines_of(page):
    out = []
    for b in page.get_text('dict')['blocks']:
        for l in b.get('lines', []):
            if l['dir'] != (1.0, 0.0) or not l['spans']: continue
            out.append(l)
    return out
