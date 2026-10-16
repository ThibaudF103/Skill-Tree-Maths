"""Paquet « Programme 2026 + poly de J. Lamboley » pour le Verger.

    pip install pymupdf
    python3 tools/poly/build_pack.py Poly-Agreg.pdf [-o paquet.verger] [-v]

Chaque définition, théorème, proposition, lemme, corollaire et exercice du
poly devient une connaissance, placée dans la branche du programme
correspondant à sa section (mapping.py), ou rattachée à la connaissance du
programme de même nom. Recto : l'énoncé encadré (un cadre par page) ;
verso : la démonstration quand elle suit l'énoncé et se termine par le
carré de fin de preuve. Le PDF n'est pas inclus : il est désigné par son
adresse et son empreinte (réutilisé s'il est déjà dans la bibliothèque).

Le paquet reproduit des extraits du poly : il est destiné à un usage
personnel, ne le publiez pas.
"""
import argparse, hashlib, json, re, sys, unicodedata, zipfile
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent))
from extract import extract
from mapping import node_for

PROGRAMME = Path(__file__).resolve().parents[2] / 'app/assets/samples/programme_agreg_2026.json'
URL = 'https://webusers.imj-prg.fr/~jimmy.lamboley/fichiers/Poly-Agreg.pdf'
NOW = '2026-10-16T12:00:00.000Z'
DOC = 'poly-lamboley'
PREFIXES = ['theoreme des', 'theoreme de la', 'theoreme du', 'theoreme de',
            'theoreme d', 'lemme des', 'lemme de', 'lemme du', 'lemme d',
            'formule de', 'formules de', 'formule des', 'critere des',
            'critere de', 'inegalite de', 'inegalite des', 'principe des',
            'principe du', 'theoreme', 'lemme', 'formule', 'methode de']

# Rattachements hors de l'arbre de la section (même énoncé, autre chapitre).
CROSS_TREE = {'Corollaire II.3.37',        # d'Alembert-Gauss, prouvé par Liouville
              'Théorème IX.1.23'}          # Lax-Milgram (option B)
NO_MATCH = {'Proposition IV.2.28'}         # comparaison Riemann/Lebesgue ≠ lemme de Fourier
tree_of = lambda key: key.split('.')[1]

def plain(t):
    t = unicodedata.normalize('NFKD', t)
    t = ''.join(c for c in t if not unicodedata.combining(c)).lower()
    return ' '.join(re.sub(r"[^a-z0-9]+", ' ', t).split())

def core(title):
    t = plain(title)
    for p in PREFIXES:
        if t.startswith(p + ' '):
            return t[len(p) + 1:]
    return t

def tidy(text):
    text = text.replace('7→', '↦').replace('7−→', '⟼')
    text = re.sub(r"\s+([,.;:)\]])", r"\1", text)
    text = re.sub(r"([(\[])\s+", r"\1", text)
    return ' '.join(text.split())

def title_of(s):
    if s['name']:
        name = s['name'][0].upper() + s['name'][1:]
        name = name.replace('7→', '↦')
        return f"{tidy(name)} · {s['number']}"
    body = re.sub(r"^\S+ \d+\.\d+\.?\s*", '', s['text'])
    body = tidy(body)
    if len(body) > 72:
        body = body[:72].rsplit(' ', 1)[0] + '…'
    return f"{s['label'].split(' ')[0]} {s['number']} : {body}"

def main():
    args = argparse.ArgumentParser()
    args.add_argument('pdf')
    args.add_argument('-o', '--output', default='programme-agreg-2026-lamboley.verger')
    args.add_argument('-v', '--verbose', action='store_true')
    args = args.parse_args()
    prog = json.load(open(PROGRAMME, encoding='utf-8'))
    statements = extract(args.pdf)
    items = prog['items']
    node_of_item = {i['id']: i['nodeId'] for i in items}
    cores = {i['id']: core(i['title']) for i in items
             if i['kind'] != 'exercise' and len(core(i['title'])) >= 5}
    anchors, new_items, used, matches = [], [], set(), []
    counts = {}
    for n, s in enumerate(statements):
        node = node_for(s['section'])
        target = None
        if s['name'] and s['kind'] != 'exercise' and s['label'] not in NO_MATCH:
            name = plain(s['name'])
            for iid, c in cores.items():
                if iid in used: continue
                if tree_of(node_of_item[iid]) != tree_of(node) and s['label'] not in CROSS_TREE:
                    continue
                if c == name or core(s['name']) == c or \
                   (len(c) >= 8 and re.search(r'\b' + re.escape(c) + r'\b', name)):
                    target = iid; break
        if target:
            used.add(target)
            matches.append((s['label'], s['name'], next(i['title'] for i in items if i['id'] == target)))
        else:
            target = f"lamboley.{s['number']}"
            counts[node] = counts.get(node, 0) + 1
            new_items.append({
                'id': target, 'nodeId': node, 'kind': s['kind'],
                'title': title_of(s), 'sortIndex': 1000 + n,
            })
        for role, frames in (('source', s['recto']), ('work', s['verso'])):
            for k, f in enumerate(frames):
                anchors.append({
                    'id': f"a.{s['number']}.{role}.{k}", 'itemId': target,
                    'documentId': DOC, 'role': role, 'page': f['page'],
                    'region': f['region'],
                    'textSnippet': tidy(s['text'])[:500] if role == 'source' and k == 0 else None,
                    'createdAt': f"2026-10-16T12:{(n // 60) % 60:02d}:{n % 60:02d}.{k:03d}Z",
                })
    data = open(args.pdf, 'rb').read()
    import pymupdf
    pages = pymupdf.open(args.pdf).page_count
    trees = sorted({node_for(s['section']).split('.')[1] for s in statements})
    archive = {
        'format': 'verger', 'version': 2,
        'title': "Programme de l'agrégation 2026 — poly de J. Lamboley",
        'nodes': prog['nodes'],
        'items': items + new_items,
        'documents': [{
            'id': DOC, 'title': "Cours d'analyse pour l'agrégation — J. Lamboley",
            'kind': 'pdf', 'url': URL, 'pageCount': pages,
            'contentHash': hashlib.sha256(data).hexdigest(),
            'importedAt': NOW, 'version': 1, 'fingerprints': [],
            'newPages': [], 'lastPage': 1,
        }],
        'resourceLinks': [{'documentId': DOC, 'nodeId': f'agreg2026.{t}'} for t in trees],
        'anchors': [{k: v for k, v in a.items() if v is not None} for a in anchors],
        'notes': [],
    }
    with zipfile.ZipFile(args.output, 'w', zipfile.ZIP_DEFLATED) as z:
        z.writestr('pack.json', json.dumps(archive, ensure_ascii=False, indent=1))
    print(f"{len(items)} connaissances du programme, {len(new_items)} ajoutées depuis le poly,",
          f"{len(matches)} énoncés rattachés à une connaissance du programme,",
          f"{len(anchors)} cadres ({sum(a['role'] == 'work' for a in anchors)} démonstrations)")
    print('contenu rattaché aux arbres', trees)
    if args.verbose:
        for m in matches: print('  ', m)


if __name__ == '__main__':
    main()
