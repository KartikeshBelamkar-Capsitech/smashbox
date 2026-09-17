extends Control

@export var play_scene_path: String = "res://scenes/levels/level_1.tscn"


func _ready() -> void:
	$Panel/Content/PlayButton.grab_focus()


func _on_play_button_pressed() -> void:
	get_tree().change_scene_to_file(play_scene_path)
