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

REF = re.compile(
    r"\b(?:th[ée]or[èe]mes?|propositions?|lemmes?|corollaires?|d[ée]finitions?"
    r"|exercices?|d[ée]finition-propositions?)\s+(\d+\.\d+(?:\s*(?:,|et)\s*\d+\.\d+)*)"
    r"(\s*(?:du|au) [Cc]hapitre\s+([IVX]+)\b)?", re.IGNORECASE)
CHAPTERS = ['I', 'II', 'III', 'IV', 'V', 'VI', 'VII', 'VIII', 'IX', 'X']


def references(statements):
    """Prérequis du poly, toujours vers un énoncé antérieur (ce qui exclut
    les cycles) :
    - renvois explicites de chaque énoncé et de sa démonstration (« d'après
      le théorème 2.8 », « la proposition 4.17 du Chapitre I ») ; les renvois
      en avant sont des « voir plus loin », ignorés ;
    - emploi d'un terme défini plus haut dans le chapitre (term_references) ;
    - pour un exercice, tout ce qui le précède dans sa partie
      (exercise_parts)."""
    rank = {s['number']: n for n, s in enumerate(statements)}
    edges = []
    for n, s in enumerate(statements):
        chapter = s['number'].split('.')[0]
        text = re.sub(r"^\S+ \d+\.\d+\.?", '', s['fullText']) + ' ' + s['versoText']
        for m in REF.finditer(text):
            target_chapter = m.group(3) or chapter
            for number in re.findall(r"\d+\.\d+", m.group(1)):
                target = f"{target_chapter}.{number}"
                if target in rank and rank[target] < n:
                    edges.append((s['number'], target))
    return edges + term_references(statements) + exercise_parts(statements)


# Termes définis : le poly ne les met pas en valeur (ni italique ni gras),
# on les tire des tournures usuelles d'une définition.
_W = r"[a-zàâäçéèêëîïôöùûüÿœ’'\-]+"
_TERM = rf"(?P<t>{_W}(?: {_W}){{0,5}}?)"
_ART = r"(?:un |une |le |la |les |l’|l')?"
_END = r"\s*(?:\d+\s+)?(?:si|s’il|s'il|s’ils|lorsque|quand|lorsqu|\()"
DEFINES = [re.compile(p, re.IGNORECASE) for p in (
    rf"\bon dit qu(?:e|’|')\s?.{{0,80}}?\b(?:est|sont|admet|admettent)\s+{_ART}{_TERM}{_END}",
    rf"\b(?:est|sont) (?:dite?s?|appel[ée]e?s?)\s+{_ART}{_TERM}{_END}",
    rf"\bs(?:’|')appellen?t?\s+{_ART}{_TERM}\s*(?:\(|,|\.|$|\bde\b|\bdu\b|\bd’|\bd')",
    rf"\bon d[ée]finit\s+{_ART}{_TERM}\s+(?:de|du|des|d’|d'|par|pour|sur)\b",
    rf"\bon (?:appelle|nomme)\s+{_TERM}\s*(?:\(|\bune?\b|\bla\b|\ble\b|\bl’|\bl'|\btoute?\b|\bles\b)",
    rf"(?:^|\. )\s*(?:une?|la|le|l’|l')\s*{_TERM}\s*(?:\d+\s+)?(?:est|sur|entre|de|du|d’|d')\b",
    rf"\bon dit qu(?:e|’|')\s?.{{0,60}}?\b(?P<v>converge(?: {_W}){{1,4}}?)\s+(?:vers|si)\b",
)]
_EDGE_WORDS = {'si', 's', 'il', 'lorsque', 'quand', 'de', 'du', 'des', 'd', 'la',
               'le', 'les', 'l', 'un', 'une', 'en', 'et', 'ou', 'sur', 'pour',
               'par', 'a', 'au', 'aux', 'dans', 'alors'}
# Termes trop vagues pour signaler un prérequis.
GENERIC = {'fonction', 'suite', 'ensemble', 'application', 'continue', 'serie',
           'espace', 'espaces', 'partie', 'partie non vide', 'famille', 'classe',
           'point', 'nombre', 'valeur', 'elements', 'equation', 'converge',
           'convergente', 'convergent', 'ordre', 'schema', 'integrale',
           'solution', 'globale', 'minimum', 'limite reelle', 'mesure',
           'nulle', 'fini', 'finie', 'positive', 'positif', 'bornee', 'borne'}


def _term(raw):
    words = plain(raw).split()
    while words and (words[-1] in _EDGE_WORDS or len(words[-1]) == 1):
        words.pop()
    while words and words[0] in _EDGE_WORDS:
        words.pop(0)
    return ' '.join(words)


def definition_terms(d):
    """Termes définis par la définition [d] : son titre et les mots qui
    suivent « on dit que … est », « on appelle », « est dit »…"""
    text = re.sub(r"^\S+ \d+\.\d+\.?", '', d['fullText'])
    found = {_term(d['name'] or '')}
    for pattern in DEFINES:
        for m in pattern.finditer(text):
            found.add(_term(m.group('v') if 'v' in pattern.groupindex and m.group('v')
                            else m.group('t') or ''))
    terms = set()
    for t in found:
        terms.update(p.strip() for p in t.split(' ou '))
    return {t for t in terms
            if t and t not in GENERIC and len(t.split()) <= 5
            and (len(t) >= 5 or ' ' in t)}


def _pattern(term):
    """Le terme au singulier ou au pluriel, au masculin ou au féminin."""
    words = [re.escape(w) + r"(?:e?s|e|x)?" for w in term.split()]
    return re.compile(r"\b" + r"\s+".join(words) + r"\b")


def term_references(statements):
    """Un énoncé ultérieur du même chapitre qui emploie un terme défini
    (énoncé ou démonstration) s'appuie sur la définition la plus récente
    de ce terme."""
    edges = []
    latest = {}  # terme -> (définition, motif), dans le chapitre en cours
    chapter = None
    for s in statements:
        if s['number'].split('.')[0] != chapter:
            chapter, latest = s['number'].split('.')[0], {}
        text = plain(re.sub(r"^\S+ \d+\.\d+\.?", '', s['fullText'])
                     + ' ' + s['versoText'])
        for number, pattern in {v for v in latest.values()}:
            if pattern.search(text):
                edges.append((s['number'], number))
        if s['kind'] == 'definition':
            for t in definition_terms(s):
                latest[t] = (s['number'], _pattern(t))
    return edges


def exercise_parts(statements):
    """Les exercices, sans corrigé donc sans renvoi, s'appuient sur tout ce
    qui les précède dans leur partie : une section « Exercices » clôt la
    partie parente (I.2.1.4 Exercices porte sur I.2.1), un exercice au fil
    d'une section porte sur cette section. Les extraits d'annales, qui
    couvrent tout un chapitre, sont laissés libres."""
    edges = []
    for n, s in enumerate(statements):
        if s['kind'] != 'exercise' or 'annales' in s['sectionTitle'].lower():
            continue
        section = s['section']
        if plain(s['sectionTitle']) == 'exercices':
            section = section.rsplit('.', 1)[0]
        prefix = section + '.'
        for t in statements[:n]:
            if t['kind'] != 'exercise' and (t['section'] == section
                                            or t['section'].startswith(prefix)):
                edges.append((s['number'], t['number']))
    return edges


def load_corriges(paths, exercises):
    """Corrigés {numéro: texte} lus dans [paths]. Refuse un numéro qui
    n'est pas celui d'un exercice extrait, un texte qui n'est pas une
    chaîne, ou un même exercice corrigé dans deux fichiers."""
    corriges, errors = {}, []
    for path in paths:
        for number, body in json.load(open(path, encoding='utf-8')).items():
            if number not in exercises:
                errors.append(f"{path} : {number} n'est pas un exercice du poly")
            elif not isinstance(body, str):
                errors.append(f"{path} : le corrigé de {number} n'est pas un texte")
            elif number in corriges:
                errors.append(f"{path} : {number} est déjà corrigé dans un autre fichier")
            else:
                corriges[number] = body
    if errors:
        sys.exit('Corrigés refusés :\n  ' + '\n  '.join(errors))
    return corriges


def common_branch(nodes, parent_of):
    """Branche la plus profonde qui contient toutes [nodes] (None si elles
    sont dans des arbres différents)."""
    def path(n):
        out = []
        while n is not None:
            out.insert(0, n)
            n = parent_of.get(n)
        return out
    paths = [path(n) for n in nodes]
    common = paths[0]
    for p in paths[1:]:
        k = 0
        while k < min(len(common), len(p)) and common[k] == p[k]:
            k += 1
        common = common[:k]
    return common[-1] if common else None


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
    args.add_argument('--corriges', action='append', default=[],
                      help="JSON {numéro: texte} : corrigés ajoutés en note au verso "
                           "des exercices (option répétable)")
    args = args.parse_args()
    prog = json.load(open(PROGRAMME, encoding='utf-8'))
    statements = extract(args.pdf)
    items = prog['items']
    node_of_item = {i['id']: i['nodeId'] for i in items}
    parent_of = {n['id']: n['parentId'] for n in prog['nodes']}
    cores = {i['id']: core(i['title']) for i in items
             if i['kind'] != 'exercise' and len(core(i['title'])) >= 5}
    anchors, new_items, used, matches = [], [], set(), []
    statement_items = []  # connaissance de chaque énoncé, dans l'ordre
    counts = {}
    for n, s in enumerate(statements):
        node = node_for(s['section'])
        # Une section « Exercices » n'a pas de branche au programme : ses
        # exercices rejoignent celle de la partie qu'elle clôt.
        if s['kind'] == 'exercise' and plain(s['sectionTitle']) == 'exercices':
            prefix = s['section'].rsplit('.', 1)[0] + '.'
            part = {node_for(t['section']) for t in statements[:n]
                    if t['kind'] != 'exercise' and t['section'].startswith(prefix)}
            if part:
                node = common_branch(part, parent_of) or node
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
            statement_items.append(target)
            matches.append((s['label'], s['name'], next(i['title'] for i in items if i['id'] == target)))
        else:
            target = f"lamboley.{s['number']}"
            statement_items.append(target)
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
    item_of = {s['number']: i for s, i in zip(statements, statement_items)}
    prerequisites = sorted({
        (item_of[a], item_of[b]) for a, b in references(statements)
        if item_of[a] != item_of[b]
    })
    corriges = load_corriges(args.corriges, {
        s['number'] for s in statements if s['kind'] == 'exercise'})
    data = open(args.pdf, 'rb').read()
    import pymupdf
    pages = pymupdf.open(args.pdf).page_count
    trees = sorted({node_for(s['section']).split('.')[1] for s in statements})
    archive = {
        'format': 'verger', 'version': 3,
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
        'notes': [
            {'id': f'corrige.{number}', 'itemId': item_of[number], 'body': body,
             'createdAt': NOW, 'updatedAt': NOW}
            for number, body in corriges.items()
        ],
        'prerequisites': [
            {'itemId': a, 'requiresId': b} for a, b in prerequisites
        ],
    }
    with zipfile.ZipFile(args.output, 'w', zipfile.ZIP_DEFLATED) as z:
        z.writestr('pack.json', json.dumps(archive, ensure_ascii=False, indent=1))
    print(f"{len(items)} connaissances du programme, {len(new_items)} ajoutées depuis le poly,",
          f"{len(matches)} énoncés rattachés à une connaissance du programme,",
          f"{len(anchors)} cadres ({sum(a['role'] == 'work' for a in anchors)} démonstrations),",
          f"{len(prerequisites)} prérequis, {len(corriges)} corrigés")
    print('contenu rattaché aux arbres', trees)
    if args.verbose:
        for m in matches: print('  ', m)


if __name__ == '__main__':
    main()
