class_name LevelUI
extends CanvasLayer
## Manages level HUD, limited ammunition, and win or lose panels.

const HOME_SCENE_PATH: String = "res://scenes/home.tscn"

@export var level_title: String = "Level 1"
@export var next_scene_path: String = ""
@export var prev_scene_path: String = ""

@onready var title_label: Label = $Control/TitleLabel
@onready var next_btn: Button = $Control/NextButton
@onready var prev_btn: Button = $Control/PrevButton
@onready var restart_btn: Button = $Control/RestartButton
@onready var cannon: Cannon = get_parent().get_node_or_null("Cannon") as Cannon

var ammo_label: Label
var result_overlay: Control
var level_finished: bool = false
var targets_remaining: int = 0
var ammo_remaining: int = 15
var active_balls: Array[Node] = []
var _is_waiting_lose: bool = false


@export var power_up_buttons_scene: PackedScene = preload("res://scenes/ui/power_up_buttons.tscn")

var power_up_buttons_instance: Control = null


func _ready() -> void:
	if title_label:
		title_label.text = level_title

	if next_btn:
		next_btn.visible = false
	if prev_btn:
		prev_btn.visible = false
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

	_create_ammo_label()
	if cannon:
		cannon.ammo_changed.connect(_on_ammo_changed)
		cannon.ball_fired.connect(_on_ball_fired)
		_on_ammo_changed(cannon.current_ammo)

	call_deferred("_check_level_state")


func _process(_delta: float) -> void:
	if not level_finished:
		_check_level_state()
		_check_lose_condition()


func _check_level_state() -> void:
	targets_remaining = get_tree().get_nodes_in_group("level_targets").size()
	if targets_remaining == 0 and not level_finished:
		_show_win_panel()


func _on_ammo_changed(remaining_ammo: int) -> void:
	ammo_remaining = remaining_ammo
	if ammo_label:
		ammo_label.text = str(remaining_ammo)
	_check_lose_condition()


func _on_ball_fired(ball: RigidBody3D, _launch_velocity: Vector3) -> void:
	active_balls.append(ball)
	ball.tree_exited.connect(_on_ball_exited.bind(ball))


func _on_ball_exited(ball: Node) -> void:
	active_balls.erase(ball)
	_check_lose_condition()


func _check_lose_condition() -> void:
	if ammo_remaining == 0 and active_balls.is_empty() and not level_finished and not _is_waiting_lose:
		_check_level_state()
		if not level_finished:
			_is_waiting_lose = true
			await get_tree().create_timer(2.0).timeout
			if not level_finished:
				_show_lose_panel()
			_is_waiting_lose = false


func _create_ammo_label() -> void:
	ammo_label = Label.new()
	ammo_label.name = "AmmoLabel"
	ammo_label.position = Vector2(24, 82)
	ammo_label.size = Vector2(58, 58)
	ammo_label.add_theme_font_size_override("font_size", 24)
	ammo_label.add_theme_color_override("font_color", Color(0.95, 0.97, 1, 1))
	ammo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ammo_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var badge := StyleBoxFlat.new()
	badge.bg_color = Color(0.08, 0.16, 0.25, 0.96)
	badge.border_color = Color(0.35, 0.7, 0.95, 0.9)
	badge.set_border_width_all(2)
	badge.set_corner_radius_all(29)
	ammo_label.add_theme_stylebox_override("normal", badge)
	$Control.add_child(ammo_label)


func _show_win_panel() -> void:
	level_finished = true
	if cannon:
		cannon.set_process_unhandled_input(false)
	var button_text: String = "QUIT" if next_scene_path.is_empty() else "NEXT LEVEL"
	_show_result_panel("YOU WIN!", button_text, _on_win_action_pressed)


func _show_lose_panel() -> void:
	level_finished = true
	if cannon:
		cannon.set_process_unhandled_input(false)
	_show_result_panel("YOU LOSE!", "PLAY AGAIN", _on_play_again_pressed)


func _show_result_panel(result_text: String, button_text: String, action: Callable) -> void:
	result_overlay = ColorRect.new()
	result_overlay.name = "ResultOverlay"
	result_overlay.color = Color(0.02, 0.03, 0.06, 0.72)
	result_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	$Control.add_child(result_overlay)
	result_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(360, 220)
	result_overlay.add_child(panel)

	if result_text == "YOU WIN!":
		var sparkles := SparkleEffect.new()
		sparkles.name = "Sparkles"
		sparkles.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		result_overlay.add_child(sparkles)
	panel.anchor_left = 0.5
	panel.anchor_top = 0.5
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -180.0
	panel.offset_top = -110.0
	panel.offset_right = 180.0
	panel.offset_bottom = 110.0

	if result_text == "YOU LOSE!":
		panel.pivot_offset = panel.custom_minimum_size / 2.0
		panel.scale = Vector2.ZERO
		var tween := create_tween()
		tween.tween_property(panel, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 28)
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(content)

	var message := Label.new()
	message.text = result_text
	message.add_theme_font_size_override("font_size", 36)
	message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(message)

	var action_button := Button.new()
	action_button.text = button_text
	action_button.custom_minimum_size = Vector2(190, 52)
	action_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	action_button.add_theme_font_size_override("font_size", 20)
	action_button.pressed.connect(action)
	content.add_child(action_button)
	action_button.grab_focus()


func _on_play_again_pressed() -> void:
	get_tree().reload_current_scene()


func _on_win_action_pressed() -> void:
	if next_scene_path.is_empty():
		get_tree().change_scene_to_file(HOME_SCENE_PATH)
	else:
		get_tree().change_scene_to_file(next_scene_path)


func _on_restart_pressed() -> void:
	get_tree().reload_current_scene()
