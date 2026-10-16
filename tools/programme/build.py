"""Programme de l'agrégation (agreg2026.txt) → modèle d'arbres du Verger.

    python3 tools/programme/build.py

Écrit app/assets/samples/programme_agreg_2026.json (format « verger »,
importable par « Importer un arbre modèle »).
"""

import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "tools/programme/agreg2026.txt"
TARGET = ROOT / "app/assets/samples/programme_agreg_2026.json"
KINDS = {
    "d": "definition",
    "t": "theorem",
    "p": "proposition",
    "l": "lemma",
    "c": "corollary",
    "s": "statement",
    "x": "exercise",
}


def slug(title: str) -> str:
    """Clé de programme d'un titre : « 1.2 … » → « 1.2 », « (a) … » → « a »."""
    m = re.match(r"(\d+(?:\.\d+)*)\s", title) or re.match(r"\((\w)\)", title)
    if m:
        return m.group(1).split(".")[-1]
    return re.sub(r"\W+", "-", title.split("—")[0].strip().lower()).strip("-")


def build(lines):
    nodes, items = [], []
    stack = []  # (niveau, id du nœud)
    counts = {}
    for number, raw in enumerate(lines, 1):
        line = raw.rstrip()
        if not line or line.startswith("%"):
            continue  # ligne vide ou commentaire
        m = re.match(r"(#+) (.+)", line)
        if m:
            level, title = len(m.group(1)), m.group(2).strip()
            while stack and stack[-1][0] >= level:
                stack.pop()
            parent = stack[-1][1] if stack else None
            key = (parent + "." if parent else "agreg2026.") + slug(title)
            if level == 1:
                num = re.match(r"(\d+) (.+)", title)
                title = f"{num.group(1)}. {num.group(2)}" if num else title
            if any(n["id"] == key for n in nodes):
                sys.exit(f"ligne {number} : clé en double {key}")
            siblings = counts.setdefault(parent, 0)
            counts[parent] = siblings + 1
            nodes.append({
                "id": key,
                "parentId": parent,
                "title": title,
                "sortIndex": siblings,
                "curriculumKey": key,
                "origin": "official",
            })
            stack.append((level, key))
            continue
        m = re.match(r"([a-z]) (.+)", line)
        if not m or m.group(1) not in KINDS:
            sys.exit(f"ligne {number} illisible : {line!r}")
        if not stack:
            sys.exit(f"ligne {number} : connaissance hors d'un arbre")
        node = stack[-1][1]
        index = sum(1 for i in items if i["nodeId"] == node)
        items.append({
            "id": f"{node}#{index + 1}",
            "nodeId": node,
            "kind": KINDS[m.group(1)],
            "title": m.group(2).strip(),
            "sortIndex": index,
        })
    return nodes, items


def main():
    nodes, items = build(SOURCE.read_text(encoding="utf-8").splitlines())
    archive = {
        "format": "verger",
        "version": 2,
        "title": "Programme de l'agrégation externe 2026",
        "nodes": nodes,
        "items": items,
    }
    TARGET.write_text(
        json.dumps(archive, ensure_ascii=False, indent=1) + "\n", encoding="utf-8"
    )
    trees = [n for n in nodes if n["parentId"] is None]
    print(f"{len(trees)} arbres, {len(nodes) - len(trees)} branches, {len(items)} connaissances → {TARGET.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
