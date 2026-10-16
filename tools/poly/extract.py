"""Énoncés du poly : type, numéro, nom, section, cadres de l'énoncé (recto)
et de la démonstration (verso), page par page."""
import re
from structure import *

KINDS = {'Définition-Proposition': 'proposition',
         'Proposition-Définition': 'proposition',
         'Théorème-Définition': 'theorem',
         'Définition': 'definition', 'Théorème': 'theorem',
         'Proposition': 'proposition', 'Lemme': 'lemma',
         'Corollaire': 'corollary', 'Exercice': 'exercise'}
ASIDES = {'Remarque', 'Exemple', 'Exemples', 'Remarques',
          'Notation', 'Notations', 'Rappel', 'Rappels'}
STOPWORDS = set(KINDS) | ASIDES
HEADER = re.compile(r"^([A-ZÉ][a-zéèêû]+(?:-[A-ZÉ][a-zéèêû]+)?) (\d+\.\d+)\.?\s*(.*)$")
REFERENCED = re.compile(
    r"^(?:Preuve|Démonstration) (?:de la [a-zéè]+ partie )?d[ue] (?:la )?"
    r"(?:th[ée]r?or[èe]me|proposition|lemme|corollaire) (\d+\.\d+)", re.IGNORECASE)
MAX_GAP = 40  # lignes entre énoncé et démonstration incluses au verso
SECTION = re.compile(r"^\d+(?:\.\d+){0,3}$")
MAX_PAGES = 4  # au-delà, cadre tronqué

def rows_of(page):
    """Lignes visuelles (fragments regroupés par hauteur), de haut en bas."""
    spans = [s for l in lines_of(page) for s in l['spans'] if s['text'].strip()]
    spans.sort(key=lambda s: (s['bbox'][1] + s['bbox'][3]) / 2)
    rows, cur, cy = [], [], None
    for s in spans:
        y = (s['bbox'][1] + s['bbox'][3]) / 2
        if cur and abs(y - cy) > 4.5:
            rows.append(cur); cur = []
        if not cur: cy = y
        cur.append(s)
    if cur: rows.append(cur)
    out = []
    for r in rows:
        r.sort(key=lambda s: s['bbox'][0])
        out.append({
            'spans': r, 'text': norm(' '.join(s['text'] for s in r)).strip(),
            'x0': min(s['bbox'][0] for s in r), 'x1': max(s['bbox'][2] for s in r),
            'y0': min(s['bbox'][1] for s in r), 'y1': max(s['bbox'][3] for s in r),
            'size': max(s['size'] for s in r), 'bold': 'BX' in r[0]['font'],
            'lead': r[0]['font'],
        })
    return out

def qed_marks(page):
    """Ordonnées des carrés de fin de démonstration (marge de droite)."""
    W = page.rect.width
    ys = []
    for d in page.get_drawings():
        r = d['rect']
        if r.width < 0.6 and 5 < r.height < 10 and r.x0 > 0.8 * W:
            ys.append((r.y0 + r.y1) / 2)
    return sorted(set(round(y, 1) for y in ys))

def is_statement(row):
    m = HEADER.match(row['text'])
    return bool(row['bold'] and m and m.group(1) in KINDS)

def is_header_stop(row):
    t = row['text']
    if row['bold']:
        w = t.split(' ')[0]
        if w in STOPWORDS or SECTION.match(w) or is_statement(row):
            return True
    return False

def is_subproof(row):
    """Preuve alternative ou partielle : « Preuve 2 : », « Preuve par… »."""
    return bool(re.match(r"^Preuve (\d|par )", row['text']))

def is_proof_start(row):
    return row['text'].startswith('Démonstration') or row['text'].startswith('Preuve')

def regions(rows, sizes):
    """Un cadre normalisé par page couverte par les lignes."""
    by_page = {}
    for r in rows:
        by_page.setdefault(r['page'], []).append(r)
    out = []
    for p, rs in sorted(by_page.items())[:MAX_PAGES]:
        W, H = sizes[p]
        x0 = min(r['x0'] for r in rs) - 4; x1 = max(r['x1'] for r in rs) + 4
        y0 = min(r['y0'] for r in rs) - 3; y1 = max(r['y1'] for r in rs) + 3
        out.append({'page': p, 'region': [round(max(0, x0 / W), 4), round(max(0, y0 / H), 4),
                                          round(min(1, x1 / W), 4), round(min(1, y1 / H), 4)]})
    return out

def extract(pdf):
    doc = pymupdf.open(pdf)
    seq, sizes = [], {}
    for page in doc:
        p1 = page.number + 1
        ch = chapter(p1)
        if not ch: continue
        W, H = page.rect.width, page.rect.height
        sizes[p1] = (W, H)
        qeds = qed_marks(page)
        kept = [r for r in rows_of(page)
                if r['y0'] >= 50                                   # en-tête courant
                and not (r['size'] < 9.6 and r['y0'] > 0.55 * H)]  # notes de bas de page
        for n, r in enumerate(kept):
            # Le carré est sur la ligne, ou seul sous la dernière ligne.
            below = kept[n + 1]['y0'] - 1 if n + 1 < len(kept) else H
            r['page'], r['chapter'] = p1, ch
            marks = [q for q in qeds if r['y0'] - 4 <= q < below]
            r['qed'] = bool(marks)
            if marks:  # le cadre englobe le carré de fin de preuve
                r['y1'] = max(r['y1'], max(marks) + 4)
                r['x1'] = max(r['x1'], 0.94 * W)
            seq.append(r)

    out, section, current = [], {}, None
    for i, r in enumerate(seq):
        if r['chapter'] != current:
            current, section = r['chapter'], {}
        first = r['text'].split(' ')[0]
        if r['bold'] and SECTION.match(first) and r['size'] > 10.5:
            level = first.count('.')
            section = {k: v for k, v in section.items() if k < level}
            section[level] = (first, r['text'][len(first):].strip())
            continue
        m = HEADER.match(r['text'])
        if not (r['bold'] and m and m.group(1) in KINDS): continue
        kind = KINDS[m.group(1)]
        rest, name = m.group(3).strip(), None
        if rest[:1] in '[(':
            close, depth = {'[': ']', '(': ')'}[rest[0]], 0
            for pos, c in enumerate(rest):
                depth += c == rest[0]
                depth -= c == close
                if depth == 0:
                    name = re.sub(r"\s*\d+$", '', rest[1:pos].strip())
                    rest = rest[pos + 1:].lstrip('. ')
                    break
        italic = kind not in ('definition', 'exercise')
        picked, j = [r], i + 1
        while j < len(seq):
            n = seq[j]
            if n['chapter'] != current or is_header_stop(n) or is_proof_start(n): break
            if italic and n['lead'].startswith('SFRM') and not n['text'].startswith('—'): break
            picked.append(n); j += 1
        end = j
        deepest = max(section, default=None)
        out.append({
            'kind': kind, 'label': f"{m.group(1)} {current}.{m.group(2)}",
            'number': f"{current}.{m.group(2)}", 'name': name,
            'section': f"{current}.{section[deepest][0]}" if deepest is not None else current,
            'sectionTitle': section[deepest][1] if deepest is not None else '',
            'page': r['page'],
            'recto': regions(picked, sizes),
            'verso': [], 'start': i, 'end': end,
            'text': ' '.join(p['text'] for p in picked)[:1500],
        })
    attach_proofs(out, seq, sizes)
    for st in out:
        del st['start'], st['end']
    return out


def attach_proofs(statements, seq, sizes):
    """Chaque « Démonstration » va à l'énoncé qui la précède (ce qui les
    sépare, remarque ou commentaire, va au verso avec elle) ; une « Preuve du
    théorème X.Y » va à l'énoncé X.Y du chapitre."""
    by_start = sorted(statements, key=lambda st: st['start'])
    covered = set()
    for ps, row in enumerate(seq):
        if not is_proof_start(row) or ps in covered:
            continue
        # Fin : carré de fin de preuve, sauf si d'autres preuves suivent
        # (« Preuve 1 : », « Preuve 2 : »…), qui vont au même verso.
        pe = ps
        while pe + 1 < len(seq):
            nxt = seq[pe + 1]
            if seq[pe]['qed'] and not is_subproof(nxt):
                break
            if nxt['chapter'] != row['chapter'] or is_header_stop(nxt) or \
                    (is_proof_start(nxt) and not is_subproof(nxt)):
                break
            pe += 1
        covered.update(range(ps, pe + 1))
        ref = REFERENCED.match(row['text'])
        if ref:
            owner = next((st for st in statements if st['number'] ==
                          f"{row['chapter']}.{ref.group(1)}"), None)
            if owner and owner['kind'] != 'exercise':
                owner['verso'] += regions(seq[ps:pe + 1], sizes)
            continue
        # Les exercices intercalés n'ont pas de démonstration : on les saute.
        before = [st for st in by_start if st['start'] < ps
                  and seq[st['start']]['chapter'] == row['chapter']]
        exercises = [st for st in before if st['kind'] == 'exercise']
        before = [st for st in before if st['kind'] != 'exercise']
        if not before:
            continue
        owner = before[-1]
        between = range(owner['end'], ps)
        skipped = [st for st in exercises if owner['start'] < st['start'] < ps]
        if owner['verso'] or any(is_statement(seq[k]) for k in between
                                 if not any(st['start'] == k for st in skipped)):
            continue
        first = owner['end'] if len(between) <= MAX_GAP and not skipped else ps
        owner['verso'] = regions(seq[first:pe + 1], sizes)
