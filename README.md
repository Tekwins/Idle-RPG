# Idle Quest

Idle RPG pour Godot 4.7 (GDScript). Le héros se bat tout seul, ramasse du butin
et monte en niveau, même quand le jeu est fermé.

## Lancer

1. Ouvrir Godot 4.7, « Importer », choisir `project.godot`.
2. Appuyer sur F5.

## Jeu

- **Combat auto** : le héros et l'ennemi frappent selon leur vitesse. 10 % de
  coups critiques. Dégâts = ATQ² / (ATQ + DÉF).
- **Étapes** : 10 ennemis par étape, le 10e est un boss (×3 PV, ×3 gains).
  Un K.O. renvoie à l'étape d'avant ; retour au combat après 3 s.
- **Potions auto** : sous 40 % de PV, le héros boit la potion la plus adaptée.
- **Inventaire** (24 cases, piles) : clic = équiper / boire, clic droit = vendre 1,
  Maj + clic droit = vendre la pile, « Trier », « Vendre matériaux ».
  Sac plein : le butin est vendu tout seul.
- **Options** : équiper le meilleur butin, vendre les matériaux, forge auto.
- **Forge** : améliorations permanentes (ATQ, DÉF, PV) payées en or ; achat de potions.
- **Hors ligne** : à la relance, le combat est rejoué en accéléré (8 h max) et
  un résumé s'affiche. Sauvegarde auto toutes les 15 s dans `user://`.
- **Vitesse** : ×1, ×2, ×5.

## Code

| Fichier | Rôle |
|---|---|
| `data/item.gd`, `data/items/*.tres` | Objets (armes, armures, potions, matériaux) |
| `data/enemy.gd`, `data/enemies/*.tres` | Ennemis, étape d'apparition, butin |
| `core/game_db.gd` | Registre des données |
| `core/inventory.gd` | Sac : piles, tri, potions, sauvegarde |
| `core/player_state.gd` | Héros : stats, équipement, forge, sauvegarde |
| `core/auto_combat.gd` | Boucle de combat (sans nœuds, testable) |
| `core/game.gd` | Autoload `Game` : tick, sauvegarde, gains hors ligne |
| `ui/main.gd` | Écran construit en code (héros, combat, inventaire) |

Ajouter un objet ou un ennemi : créer le `.tres`, puis ajouter son chemin dans
`core/game_db.gd`.

## Tests

```bash
godot --headless --path . --import
godot --headless --path . --script res://tests/test_core.gd
```

Code de sortie 0 = tout passe.
