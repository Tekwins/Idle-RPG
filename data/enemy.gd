class_name EnemyResource
extends Resource
## Base enemy stats. AutoCombat scales them by stage at spawn time.

@export var id: String = ""
@export var display_name: String = "Monstre"
## First stage where this enemy can appear.
@export var min_stage: int = 1
@export var max_hp: int = 30
@export var attack: int = 5
@export var defense: int = 0
## Attacks per second.
@export var attack_speed: float = 1.0
@export var xp: int = 5
@export var gold: int = 3
## Item ids, paired with loot_chances (0..1).
@export var loot_ids: PackedStringArray = PackedStringArray()
@export var loot_chances: PackedFloat32Array = PackedFloat32Array()
