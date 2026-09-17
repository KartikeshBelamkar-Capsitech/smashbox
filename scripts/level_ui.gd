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


@export var power_up_buttons_scene: PackedScene = preload("res://scenes/ui/power_up_buttons.tscn")

var power_up_buttons_instance: Control = null


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
		
	_spawn_power_up_buttons()


func _spawn_power_up_buttons() -> void:
	if not power_up_buttons_scene:
		return
	var ctrl: Node = find_child("Control", true, false)
	if not ctrl:
		ctrl = self
	power_up_buttons_instance = power_up_buttons_scene.instantiate() as Control
	if power_up_buttons_instance:
		ctrl.add_child(power_up_buttons_instance)
		var cannon: Node = get_parent().find_child("Cannon", true, false)
		if cannon and power_up_buttons_instance.has_method("set_cannon"):
			power_up_buttons_instance.call("set_cannon", cannon)


func _on_next_pressed() -> void:
	if not next_scene_path.is_empty():
		get_tree().change_scene_to_file(next_scene_path)


func _on_prev_pressed() -> void:
	if not prev_scene_path.is_empty():
		get_tree().change_scene_to_file(prev_scene_path)


func _on_restart_pressed() -> void:
	get_tree().reload_current_scene()
