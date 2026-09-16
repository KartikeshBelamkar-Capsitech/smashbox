class_name LevelUI
extends CanvasLayer
## Manages prototyping UI: shows level title, restart button, and level navigation.

@export var level_title: String = "Level 1"
@export var next_scene_path: String = ""
@export var prev_scene_path: String = ""

@onready var title_label: Label = $Control/TitleLabel
@onready var next_btn: Button = $Control/NextButton
@onready var prev_btn: Button = $Control/PrevButton
@onready var restart_btn: Button = $Control/RestartButton


func _ready() -> void:
	if title_label:
		title_label.text = level_title
		
	if next_btn:
		next_btn.visible = not next_scene_path.is_empty()
		next_btn.pressed.connect(_on_next_pressed)
		
	if prev_btn:
		prev_btn.visible = not prev_scene_path.is_empty()
		prev_btn.pressed.connect(_on_prev_pressed)
		
	if restart_btn:
		restart_btn.pressed.connect(_on_restart_pressed)


func _on_next_pressed() -> void:
	if not next_scene_path.is_empty():
		get_tree().change_scene_to_file(next_scene_path)


func _on_prev_pressed() -> void:
	if not prev_scene_path.is_empty():
		get_tree().change_scene_to_file(prev_scene_path)


func _on_restart_pressed() -> void:
	get_tree().reload_current_scene()
