class_name PowerUpButtons
extends Control
## Controls the left (Fire/Explode) and right (Triple Shot) power-up buttons.
## Provides visual feedback, arming/toggling state, and integrates directly with Cannon.

@export var cannon: Cannon = null

@onready var left_btn: Button = $LeftButton
@onready var right_btn: Button = $RightButton
@onready var left_badge: Label = $LeftButton/BadgeLabel
@onready var right_badge: Label = $RightButton/BadgeLabel

# Visual style constants
var _style_left_idle: StyleBoxFlat
var _style_left_active: StyleBoxFlat
var _style_right_idle: StyleBoxFlat
var _style_right_active: StyleBoxFlat

var _left_pulse_tween: Tween
var _right_pulse_tween: Tween


func _ready() -> void:
	_init_styles()
	
	if left_btn:
		left_btn.mouse_filter = Control.MOUSE_FILTER_STOP
		left_btn.pressed.connect(_on_left_button_pressed)
	if right_btn:
		right_btn.mouse_filter = Control.MOUSE_FILTER_STOP
		right_btn.pressed.connect(_on_right_button_pressed)
		
	if not cannon:
		_find_cannon()
		
	if cannon:
		_connect_cannon()
		
	_update_ui_state(PowerUp.Type.NONE)
	_auto_configure_for_level()


## Configures power-up visibility according to level progression:
## - Levels 1 to 3: None
## - Levels 4 to 6: Triple Shot only
## - Levels 7+: Explode and Triple Shot
func configure_for_level(level_number: int) -> void:
	var triple_unlocked: bool = level_number > 3
	var explode_unlocked: bool = level_number > 6
	
	if right_btn:
		right_btn.visible = triple_unlocked
	if left_btn:
		left_btn.visible = explode_unlocked


func _auto_configure_for_level() -> void:
	var path: String = ""
	if get_tree() and get_tree().current_scene:
		path = get_tree().current_scene.scene_file_path
		
	var regex := RegEx.create_from_string("level_(\\d+)")
	var match_res := regex.search(path)
	if match_res:
		configure_for_level(match_res.get_string(1).to_int())
		return
		
	# Check parent LevelUI title if available
	var parent_ui := get_parent()
	while parent_ui:
		if "level_title" in parent_ui:
			var title_regex := RegEx.create_from_string("Level\\s*(\\d+)")
			var title_match := title_regex.search(parent_ui.level_title)
			if title_match:
				configure_for_level(title_match.get_string(1).to_int())
				return
		parent_ui = parent_ui.get_parent()


func set_cannon(new_cannon: Cannon) -> void:
	if cannon and cannon.power_up_changed.is_connected(_on_cannon_power_up_changed):
		cannon.power_up_changed.disconnect(_on_cannon_power_up_changed)
	cannon = new_cannon
	if cannon:
		_connect_cannon()
		_update_ui_state(cannon.get_power_up())


func _find_cannon() -> void:
	var tree_root: Node = get_tree().current_scene
	if tree_root:
		var found: Node = tree_root.find_child("Cannon", true, false)
		if found is Cannon:
			cannon = found as Cannon


func _connect_cannon() -> void:
	if not cannon.power_up_changed.is_connected(_on_cannon_power_up_changed):
		cannon.power_up_changed.connect(_on_cannon_power_up_changed)


func _init_styles() -> void:
	# Left Button: Fire / Explode (Fiery Orange / Red)
	_style_left_idle = StyleBoxFlat.new()
	_style_left_idle.bg_color = Color(0.18, 0.08, 0.06, 0.85)
	_style_left_idle.border_color = Color(0.95, 0.45, 0.1, 0.7)
	_style_left_idle.set_border_width_all(2)
	_style_left_idle.set_corner_radius_all(16)
	_style_left_idle.shadow_color = Color(0.9, 0.3, 0.05, 0.25)
	_style_left_idle.shadow_size = 4
	
	_style_left_active = StyleBoxFlat.new()
	_style_left_active.bg_color = Color(0.85, 0.25, 0.05, 0.95)
	_style_left_active.border_color = Color(1.0, 0.85, 0.3, 1.0)
	_style_left_active.set_border_width_all(4)
	_style_left_active.set_corner_radius_all(16)
	_style_left_active.shadow_color = Color(1.0, 0.4, 0.1, 0.8)
	_style_left_active.shadow_size = 14
	
	# Right Button: Triple Shot (Electric Cyan / Gold)
	_style_right_idle = StyleBoxFlat.new()
	_style_right_idle.bg_color = Color(0.06, 0.14, 0.22, 0.85)
	_style_right_idle.border_color = Color(0.15, 0.7, 0.95, 0.7)
	_style_right_idle.set_border_width_all(2)
	_style_right_idle.set_corner_radius_all(16)
	_style_right_idle.shadow_color = Color(0.1, 0.6, 0.9, 0.25)
	_style_right_idle.shadow_size = 4
	
	_style_right_active = StyleBoxFlat.new()
	_style_right_active.bg_color = Color(0.05, 0.5, 0.85, 0.95)
	_style_right_active.border_color = Color(0.5, 1.0, 1.0, 1.0)
	_style_right_active.set_border_width_all(4)
	_style_right_active.set_corner_radius_all(16)
	_style_right_active.shadow_color = Color(0.2, 0.8, 1.0, 0.8)
	_style_right_active.shadow_size = 14


func _on_left_button_pressed() -> void:
	if not cannon:
		_find_cannon()
	if not cannon:
		return
		
	# Toggle left power-up
	if cannon.get_power_up() == PowerUp.Type.FIRE_EXPLODE:
		cannon.set_power_up(PowerUp.Type.NONE)
	else:
		cannon.set_power_up(PowerUp.Type.FIRE_EXPLODE)


func _on_right_button_pressed() -> void:
	if not cannon:
		_find_cannon()
	if not cannon:
		return
		
	# Toggle right power-up
	if cannon.get_power_up() == PowerUp.Type.TRIPLE_SHOT:
		cannon.set_power_up(PowerUp.Type.NONE)
	else:
		cannon.set_power_up(PowerUp.Type.TRIPLE_SHOT)


func _on_cannon_power_up_changed(new_power_up: int) -> void:
	_update_ui_state(new_power_up)


func _update_ui_state(active_type: int) -> void:
	# Update Left (Fire/Explode)
	var is_left_active: bool = (active_type == PowerUp.Type.FIRE_EXPLODE)
	if left_btn:
		left_btn.add_theme_stylebox_override("normal", _style_left_active if is_left_active else _style_left_idle)
		left_btn.add_theme_stylebox_override("hover", _style_left_active if is_left_active else _style_left_idle)
		left_btn.add_theme_stylebox_override("pressed", _style_left_active if is_left_active else _style_left_idle)
		
	if left_badge:
		left_badge.visible = is_left_active
		if is_left_active:
			left_badge.text = "ARMED!"
			_start_pulse(left_btn, true)
		else:
			_stop_pulse(left_btn, true)
			
	# Update Right (Triple Shot)
	var is_right_active: bool = (active_type == PowerUp.Type.TRIPLE_SHOT)
	if right_btn:
		right_btn.add_theme_stylebox_override("normal", _style_right_active if is_right_active else _style_right_idle)
		right_btn.add_theme_stylebox_override("hover", _style_right_active if is_right_active else _style_right_idle)
		right_btn.add_theme_stylebox_override("pressed", _style_right_active if is_right_active else _style_right_idle)
		
	if right_badge:
		right_badge.visible = is_right_active
		if is_right_active:
			right_badge.text = "ARMED!"
			_start_pulse(right_btn, false)
		else:
			_stop_pulse(right_btn, false)


func _start_pulse(btn: Button, is_left: bool) -> void:
	if is_left:
		if _left_pulse_tween:
			_left_pulse_tween.kill()
		_left_pulse_tween = create_tween().set_loops()
		_left_pulse_tween.tween_property(btn, "scale", Vector2(1.08, 1.08), 0.3).set_trans(Tween.TRANS_SINE)
		_left_pulse_tween.tween_property(btn, "scale", Vector2(1.0, 1.0), 0.3).set_trans(Tween.TRANS_SINE)
	else:
		if _right_pulse_tween:
			_right_pulse_tween.kill()
		_right_pulse_tween = create_tween().set_loops()
		_right_pulse_tween.tween_property(btn, "scale", Vector2(1.08, 1.08), 0.3).set_trans(Tween.TRANS_SINE)
		_right_pulse_tween.tween_property(btn, "scale", Vector2(1.0, 1.0), 0.3).set_trans(Tween.TRANS_SINE)


func _stop_pulse(btn: Button, is_left: bool) -> void:
	if is_left:
		if _left_pulse_tween:
			_left_pulse_tween.kill()
			_left_pulse_tween = null
		btn.scale = Vector2.ONE
	else:
		if _right_pulse_tween:
			_right_pulse_tween.kill()
			_right_pulse_tween = null
		btn.scale = Vector2.ONE
