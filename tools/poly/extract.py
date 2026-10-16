"""Énoncés du poly : type, numéro, nom, section, cadres de l'énoncé (recto)
et de la démonstration (verso), page par page."""
import re
from structure import *

KINDS = {'Définition': 'definition', 'Théorème': 'theorem',
         'Proposition': 'proposition', 'Lemme': 'lemma',
         'Corollaire': 'corollary', 'Exercice': 'exercise'}
STOPWORDS = set(KINDS) | {'Remarque', 'Exemple', 'Exemples', 'Remarques',
                          'Notation', 'Notations', 'Rappel', 'Rappels'}
HEADER = re.compile(r"^([A-ZÉ][a-zéèêû]+) (\d+\.\d+)\.?\s*(.*)$")
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

def is_header_stop(row):
    t = row['text']
    if row['bold']:
        w = t.split(' ')[0]
        if w in STOPWORDS or SECTION.match(w):
            return True
    return False

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
        for r in rows_of(page):
            if r['y0'] < 50: continue                         # en-tête courant
            if r['size'] < 9.6 and r['y0'] > 0.55 * H: continue  # notes de bas de page
            r['page'], r['chapter'] = p1, ch
            r['qed'] = any(r['y0'] - 4 <= q <= r['y1'] + 4 for q in qeds)
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
        proof = []
        if j < len(seq) and is_proof_start(seq[j]) and kind != 'definition':
            k = j
            while k < len(seq) and seq[k]['chapter'] == current:
                n = seq[k]
                if k > j and is_header_stop(n): break
                proof.append(n)
                if n['qed']: break
                k += 1
        deepest = max(section, default=None)
        out.append({
            'kind': kind, 'label': f"{m.group(1)} {current}.{m.group(2)}",
            'number': f"{current}.{m.group(2)}", 'name': name,
            'section': f"{current}.{section[deepest][0]}" if deepest is not None else current,
            'sectionTitle': section[deepest][1] if deepest is not None else '',
            'page': r['page'],
            'recto': regions(picked, sizes),
            'verso': regions(proof, sizes) if proof and proof[-1]['qed'] else [],
            'text': ' '.join(p['text'] for p in picked)[:1500],
        })
    return out
