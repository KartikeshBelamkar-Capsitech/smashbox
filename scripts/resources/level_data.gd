class_name LevelData
extends Resource
## Defines metadata and rules for an individual level in Smashbox.

@export var level_id: int = 1
@export var title: String = "Level 1"
@export var scene_path: String = ""
@export var max_ammo: int = 15
@export var available_power_ups: Array[int] = []
@export var milestone_unlock: int = PowerUp.Type.NONE
