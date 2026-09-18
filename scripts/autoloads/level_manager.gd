extends Node
## Central manager and loader for level progression, level configurations, and scene transitions.
## Registered as an Autoload singleton named "LevelManager".

const HOME_SCENE_PATH: String = "res://scenes/home.tscn"

var levels: Array[LevelData] = []
var current_level_index: int = 0


func _ready() -> void:
	_init_level_database()
	
	# Connect global event bus requests
	if Events:
		Events.level_restart_requested.connect(restart_current_level)
		Events.next_level_requested.connect(load_next_level)
		Events.home_requested.connect(go_to_home)


func _init_level_database() -> void:
	levels.clear()
	
	var titles: Array[String] = [
		"Level 1 (Regular Crates)",
		"Level 2 (Medium Girders Arch)",
		"Level 3 (Mixed Fortress)",
		"Level 4",
		"Level 5",
		"Level 6",
		"Level 7",
		"Level 8",
		"Level 9"
	]
	
	for i in range(1, 10):
		var data := LevelData.new()
		data.level_id = i
		data.title = titles[i - 1]
		data.scene_path = "res://scenes/levels/level_%d.tscn" % i
		data.max_ammo = 15
		
		# Set available power-ups based on progression rules
		if i < 4:
			data.available_power_ups = []
		elif i < 7:
			data.available_power_ups = [PowerUp.Type.TRIPLE_SHOT]
		else:
			data.available_power_ups = [PowerUp.Type.FIRE_EXPLODE, PowerUp.Type.TRIPLE_SHOT]
			
		# Milestone celebrations
		if i == 4:
			data.milestone_unlock = PowerUp.Type.TRIPLE_SHOT
		elif i == 7:
			data.milestone_unlock = PowerUp.Type.FIRE_EXPLODE
		else:
			data.milestone_unlock = PowerUp.Type.NONE
			
		levels.append(data)


## Returns the LevelData for the currently active level.
func get_current_level_data() -> LevelData:
	_sync_with_current_scene()
	if current_level_index >= 0 and current_level_index < levels.size():
		return levels[current_level_index]
		
	# Fallback if outside registry
	var fallback := LevelData.new()
	fallback.level_id = 1
	fallback.title = "Level 1"
	return fallback


## Loads a level by its 1-based level number (1 to N).
func load_level(level_number: int) -> void:
	var idx: int = level_number - 1
	if idx >= 0 and idx < levels.size():
		current_level_index = idx
		var data := levels[idx]
		get_tree().change_scene_to_file(data.scene_path)
		call_deferred("_emit_level_started", data)
	else:
		push_warning("LevelManager: Level %d not found, returning to Home." % level_number)
		go_to_home()


## Checks if a next level is available in the progression.
func has_next_level() -> bool:
	_sync_with_current_scene()
	return current_level_index + 1 < levels.size()


## Loads the next level, or goes to home screen if the final level is completed.
func load_next_level() -> void:
	_sync_with_current_scene()
	if has_next_level():
		load_level(current_level_index + 2) # current_level_index is 0-based, so +2 gives next 1-based level
	else:
		go_to_home()


## Reloads the current scene / level.
func restart_current_level() -> void:
	get_tree().reload_current_scene()
	var data := get_current_level_data()
	call_deferred("_emit_level_started", data)


## Transitions to the home menu.
func go_to_home() -> void:
	get_tree().change_scene_to_file(HOME_SCENE_PATH)


func _emit_level_started(data: LevelData) -> void:
	if Events:
		Events.level_started.emit(data)


## Synchronizes current_level_index if a scene was launched directly from editor (F6).
func _sync_with_current_scene() -> void:
	var cur_scene := get_tree().current_scene
	if not cur_scene:
		return
	var scene_path := cur_scene.scene_file_path
	for i in range(levels.size()):
		if levels[i].scene_path == scene_path:
			current_level_index = i
			return
