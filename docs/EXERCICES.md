# Exercices corrigés automatiquement

Un exercice peut porter un **modèle** : Verger en tire un énoncé aux valeurs
différentes à chaque révision, vérifie les réponses et propose la note
(tout juste : « Correct », en partie : « Difficile », rien de juste :
« À revoir »). Le modèle se saisit dans la fiche de l'exercice, rubrique
« Corrigé automatiquement », avec un aperçu du tirage ; un modèle invalide
ne peut pas être enregistré.

Une même graine redonne toujours le même énoncé : c'est ce qui permettra
d'imprimer une fiche par élève puis de la corriger.

## Format

```json
{
  "v": 1,
  "params": {
    "a": {"int": [2, 9]},
    "b": {"int": [-9, 9], "not": [0]},
    "c": {"int": [-9, 9]}
  },
  "let": {"x": "(c - b) / a"},
  "when": ["x != 0"],
  "statement": "Résoudre l'équation $[[a]]x [[b|+]] = [[c]]$.",
  "questions": [
    {"prompt": "$x =$", "answer": "x"},
    {"prompt": "Signe de la solution :",
     "choices": ["positive", "négative"],
     "correct": "si(x > 0, 1, 2)"}
  ]
}
```

| Clé | Rôle |
| --- | --- |
| `params` | Valeurs tirées : `{"int": [min, max]}` (bornes comprises, `"not"` : valeurs exclues) ou `{"pick": [2, 3, 5]}`. |
| `let` | Valeurs calculées, dans l'ordre ; chacune peut utiliser les précédentes. |
| `when` | Conditions : un tirage qui ne les remplit pas est refait. |
| `statement` | Énoncé (LaTeX entre `$…$`). |
| `questions` | Une ou plusieurs questions (voir ci-dessous). |

**Expressions** : nombres, `+ - * / ^`, parenthèses, `abs`, `sqrt`, `min`,
`max`, `si(condition, alors, sinon)`, comparaisons (`== != < <= > >=`),
`&&`, `||`. Le calcul est exact sur les fractions ; une racine non entière
devient une valeur approchée. La multiplication peut être sous-entendue
(`2x`, `3(a+1)`) et passe alors avant `*` et `/` : `3/2sqrt(2)` vaut
3/(2√2).

**Valeurs dans un texte** : `[[expression]]`, ou `[[expression|options]]` :

| Option | Effet | Exemple (valeur -3) |
| --- | --- | --- |
| `+` | signe toujours écrit | `- 3` (pour `2x [[b\|+]]`) |
| `coef` | 1 et -1 s'écrivent « » et « - » | `[[a\|coef]]x` |
| `tex` | fraction en `\frac{}{}` | `-\frac{3}{4}` |
| un nombre | arrondi à ce nombre de décimales | `[[v\|2]]` → `1,41` |

**Questions** :

- Réponse numérique : `"answer"` (expression). L'élève peut écrire `-3/4`,
  `-0,75`, `sqrt(2)/2`… La réponse exacte est due ; `"tolerance": 0.01`
  accepte un écart. Sans tolérance, une valeur approchée (racine non
  entière) est acceptée à 4 décimales.
- QCM : `"choices"`, mélangés à l'affichage. La bonne réponse est la
  première, ou celle de rang `"correct"` (1 = le premier choix écrit) ; ce
  rang doit être un entier, sinon le modèle est refusé.

## Exemples

Calcul de fractions :

```json
{"v": 1,
 "params": {"a": {"int": [1, 9]}, "b": {"int": [2, 9]},
            "c": {"int": [1, 9]}, "d": {"int": [2, 9]}},
 "when": ["b != d"],
 "statement": "Calculer $\\frac{[[a]]}{[[b]]} + \\frac{[[c]]}{[[d]]}$ (forme irréductible).",
 "questions": [{"answer": "a/b + c/d"}]}
```

Pythagore, valeur approchée :

```json
{"v": 1,
 "params": {"a": {"int": [2, 9]}, "b": {"int": [2, 9]}},
 "statement": "Un triangle rectangle a des côtés de l'angle droit de $[[a]]$ cm et $[[b]]$ cm.",
 "questions": [{"prompt": "Hypoténuse (cm, au centième) :",
                "answer": "sqrt(a^2 + b^2)", "tolerance": 0.01}]}
```

## Fiches par élève

Dans le menu d'une branche ou d'un arbre, « Fiches d'exercices par élève
(PDF) » crée une fiche par élève (un nom par ligne) avec les exercices
corrigés automatiquement de la branche :

- chaque élève a ses propres valeurs et, si l'on demande moins d'exercices
  qu'il n'y en a, son propre tirage parmi eux (toujours dans l'ordre de la
  branche) ;
- une case par réponse numérique, une case à cocher par choix de QCM (A, B,
  C…) ;
- un QR code porte le nom de l'élève, la graine de la fiche, les exercices
  et une empreinte de leurs modèles : il suffit à retrouver chaque énoncé
  et sa réponse, pour la correction par lecture des copies à venir (un
  modèle modifié depuis l'impression se repère à l'empreinte) ;
- le corrigé (réponses de chaque élève) peut être ajouté en fin de document.

Limite connue : une formule centrée (`$$…$$`) plus large que la page est
coupée sur la fiche.
