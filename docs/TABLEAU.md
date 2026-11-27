# Le tableau — conception

Le Verger passe d'une visualisation en « arbres » à un **tableau blanc
géant**, présenté comme une grande carte mentale. Décision validée ; ce
document fixe le modèle et l'ordre de construction pour les étapes
suivantes.

## Modèle

- **Régions = nœuds de la hiérarchie.** Chapitres, sections,
  sous-sections (`KnowledgeNode`) sont des rectangles imbriqués : la région
  d'un nœud contient celles de ses enfants. Un arbre (nœud racine) est une
  grande région de premier niveau.
- **Cartes = connaissances.** Une connaissance (`KnowledgeItem`) est une
  carte posée dans la région de son nœud. La carte montre le titre / recto ;
  le contenu rédigé (verso) se révèle en révision (recto / verso inchangé).
- **Appartenance par la géométrie** (à partir de l'étape 2) : une carte
  appartient à la plus petite région qui la contient ; déplacer une carte la
  déplace dans l'arbre ; une carte hors de toute région va dans
  « Non classées ».
- **Liens entre cartes** (étape 4) : prérequis, « cas de » (vers des cartes
  « modèle » : oscillateur harmonique, équation de d'Alembert, conservation
  du flux, Fourier…), « voir aussi ».
- Plus tard : cartes-références et tableaux de leçon.
- Les fonctions enseignant (feuilles d'exercices, exercices automatiques)
  restent telles quelles.

## Géométrie

Unités du tableau : pixels logiques au zoom 1, en `double`.

| Élément | Champs (base) | Domaine |
|---|---|---|
| Région d'un nœud | `board_x`, `board_y`, `board_width`, `board_height` | `KnowledgeNode.board` (`BoardRect?`) |
| Carte d'une connaissance | `board_x`, `board_y` | `KnowledgeItem.boardPosition` (`BoardPoint?`) |

- `null` : pas encore placé. La taille d'une carte découle de son contenu ;
  fixe pour l'instant (`BoardLayoutConfig.cardWidth` × `cardHeight`).
- Schéma v11. `VergerStore.saveBoardGeometry` écrit régions et cartes en
  une transaction ; la géométrie se lit sur les nœuds et connaissances.
- Changer une connaissance de nœud (ou déplacer un nœud dans « Arbres »)
  efface sa géométrie (celle de toute la branche pour un nœud) : elle est
  replacée automatiquement dans sa nouvelle région. Une connaissance
  rétablie par « Annuler » revient aussi sans place (une autre carte a pu
  prendre la sienne).
- `VergerStore.watchBoard` lit nœuds et connaissances ensemble : la mise en
  page part toujours d'un instantané cohérent.
- **Sauvegarde JSON** : champ facultatif `board` (`[x, y, l, h]` pour un
  nœud, `[x, y]` pour une carte), sans changer la version d'archive (une
  version plus ancienne l'ignore et refait la mise en page). Les **paquets**
  (`.verger`) et modèles n'emportent pas de géométrie : l'arbre importé est
  mis en page à son arrivée.

## Mise en page automatique (`layoutBoard`, verger_core)

Ne complète que ce qui n'a pas de géométrie, sans bouger ce qui est placé :

- **Sous-arbre neuf** : cartes en grille presque carrée sous le bandeau de
  titre, puis sous-régions rangées par étagères (de gauche à droite, à la
  ligne au-delà d'environ 1,4 × √aire) ; marges et bandeau de titre plus
  haut pour un arbre.
- **Dans une région placée** : nouvelle carte ou sous-région dans le premier
  espace libre (les cartes sur la grille des cartes, ligne par ligne ; les
  sous-régions au premier coin libre), sinon sous le contenu ; la région
  grandit alors (bas, droite si besoin) et pousse vers le bas, avec leur
  contenu, les voisines qu'elle recouvrirait (c'est la voisine déjà placée
  qui s'écarte, la région agrandie ne saute pas).
- **Arbres** : rangés par étagères au premier lancement ; un nouvel arbre se
  place à droite des autres.
- Déterministe (ordre des frères, date de création, identifiant).

À l'ouverture du tableau, la géométrie manquante est calculée et
enregistrée ; ensuite, à chaque changement (flux des nœuds et
connaissances), les nouveaux venus sont placés.

## Étapes

| Étape | Contenu |
|---|---|
| 1 | Tableau en lecture seule généré depuis l'arbre (données prêtes pour l'étape 2) ✅ |
| 2 | Déplacer / redimensionner les régions, glisser les cartes (met l'arbre à jour) ✅ |
| 3 | Créer des cartes au stylet sur le tableau, et depuis les notes |
| 4 | Liens, cartes « modèle », mise en évidence |
| 5 | Cartes-références, tableaux de leçon |
| 6 | Performances, zoom sémantique avancé |

## Étape 1 (faite)

- Onglet « Tableau » (après « Verger » ; « Arbres » reste). L'onglet retenu
  est mémorisé par un identifiant stable, indépendant de l'ordre affiché.
- Toile infinie (`GraphViewer` : molette, Ctrl + molette, pavé tactile,
  pincer) ; régions en rectangles arrondis titrés (profondeur = poids
  visuel, couleur tirée de l'arbre), cartes arrondies avec titre (`MathText`)
  et couleur de maîtrise (mêmes règles que l'arbre de compétences).
- **Performances** : seuls les régions et cartes qui touchent la zone
  visible (plus une marge d'un huitième de la vue) sont construites, soit
  environ deux fois la zone visible ; la zone est arrondie à une grille pour
  ne reconstruire qu'en changeant de case ou de palier de zoom. Cartes
  légères (pas de `Material` ni d'ombre).
- **Zoom sémantique** : de loin, titres des régions en grand et cartes en
  simples blocs colorés (un seul peintre) ; à mi-distance, titres des cartes
  en texte simple ; de près, rendu LaTeX.
- Toucher une carte ouvre sa fiche ; toucher un titre de région ouvre le
  nœud ; « Recentrer » cadre tout ; la vue (zoom, décalage) est retenue
  dans les réglages.

## Étape 2 (faite) : éditer la géométrie

Le tableau décide des places, l'arbre de la hiérarchie ; un geste met les
deux à jour ensemble.

- **Mode « Édition »** (puce en haut à droite, désactivée par défaut). Un
  doigt (ou la souris) sur une carte, un bandeau de titre ou une poignée
  déplace l'élément ; sur le vide, il déplace la vue ; deux doigts pincent
  et déplacent toujours la vue (un deuxième doigt annule le geste en
  cours). La vue est figée pendant le geste. Le glissé commence au même
  seuil que le toucher renonce (18 px au doigt ou au stylet) : un toucher
  ouvre la fiche ou le nœud, un glissé déplace sans rien ouvrir. Pas de
  nouveau geste tant que le précédent s'enregistre.
- **Carte** : déposée dans une région, elle rejoint le nœud de la région la
  plus profonde sous le doigt (changement de nœud : historique et état de
  révision intacts), à la position déposée aimantée sur une grille de 8,
  poussée vers la place libre la plus proche. Hors de toute région : dans
  « Non classées ». La région d'arrivée est mise en évidence pendant le
  glissé. De loin (cartes en blocs), les cartes ne se saisissent pas.
- **Région** (par son bandeau de titre) : elle emporte sous-régions et
  cartes ; déposée dans une autre région, elle en devient l'enfant (jamais
  dans elle-même ou sa descendance) ; hors de toute région, elle devient un
  arbre. Les voisines qu'elle recouvre en dessous sont poussées vers le bas
  (règles de la mise en page) ; ce qui est au-dessus y reste : c'est elle
  qui glisse juste en dessous. Elle reste dans la zone utile de son parent ;
  les frères quittés sont renumérotés.
- **Redimensionner** : poignées sur les bords et les coins (36 px à
  l'écran, curseurs de redimensionnement à la souris). Jamais plus petite
  que son contenu plus les marges (une région vide garde la place d'une
  carte), jamais hors de la zone utile de son parent ; un bord tiré vers le
  haut ou la gauche s'arrête aux voisines ; agrandie, elle pousse ses
  voisines et son parent grandit.
- **« Non classées »** : un arbre ordinaire à l'identifiant réservé
  (`KnowledgeNode.unsortedId`), créé à la demande par le premier dépôt hors
  région et retiré quand un geste le vide. Région grise, placée comme un
  nouvel arbre ; elle n'accueille que des cartes (une région n'y entre pas,
  et elle reste un arbre). Règles tenues par le magasin, pas seulement par
  le tableau : aucun nœud créé ni déplacé dessous, jamais déplacée
  elle-même hors des arbres, retirée quand sa dernière carte sort par
  n'importe quel chemin (tableau, « Arbres », fiche, suppression ;
  l'annulation d'une suppression la rétablit). Visible dans « Arbres » (on
  peut y classer les cartes aussi) et dans les révisions comme un arbre :
  ses connaissances restent des connaissances à réviser. Elle ne se partage
  pas : pas de paquet, et un paquet qui l'emporte est refusé (il garde ses
  identifiants et remplacerait les cartes non classées). Aucun changement
  de schéma ni d'archive : une version plus ancienne y voit un arbre
  « Non classées ».
- **Calcul** : `BoardEditor` (verger_core) sur l'instantané du début du
  geste ; **enregistrement** : `VergerStore.applyBoardEdit`, une
  transaction par geste (donc un seul instantané `watchBoard`, sans boucle
  d'écriture) ; tout ce que le geste déplace doit encore exister. Chaque
  geste (ou annulation) incrémente une **génération** portée par les
  instantanés : la sauvegarde automatique, calculée sur un instantané, ne
  s'écrit que si aucun geste n'est passé depuis, et l'aperçu du geste reste
  affiché jusqu'à l'instantané qui le reflète. **Annulation** : « Annuler »
  dans le bandeau qui suit (un seul vivant), `undoBoardEdit` remet parents,
  ordre et géométrie d'avant ; refusée avec un message si ce n'est plus la
  dernière modification, si ce qu'elle a touché a changé depuis, ou si la
  hiérarchie rétablie aurait un cycle.
- Limites : changer une région de profondeur ne réduit pas son bandeau
  (elle s'étend vers le haut si le nouveau bandeau est plus haut) ; une
  région ne rétrécit jamais seule ; le parent ne grandit que vers la droite
  et le bas.
