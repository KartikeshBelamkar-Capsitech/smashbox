class_name PowerUpUnlockModal
extends Control
## Celebratory pop-up shown when a new power-up is unlocked.
## Displays punchy achievement copy, celebratory confetti, cute pop animation,
## and a dismissal button that resumes gameplay.

signal dismissed()

@onready var backdrop: ColorRect = $Backdrop
@onready var card: PanelContainer = $Card
@onready var icon_label: Label = $Card/MarginContainer/VBoxContainer/IconLabel
@onready var title_label: Label = $Card/MarginContainer/VBoxContainer/TitleLabel
@onready var punchline_label: Label = $Card/MarginContainer/VBoxContainer/PunchlineLabel
@onready var action_button: Button = $Card/MarginContainer/VBoxContainer/ActionButton
@onready var confetti_container: Control = $ConfettiContainer

var _dismiss_callback: Callable = Callable()
var _is_closing: bool = false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	if action_button:
		action_button.pressed.connect(_on_action_pressed)


## Configures the modal for either Triple Shot or Explode power-up.
func setup(power_up_type: int, on_dismiss_callback: Callable = Callable()) -> void:
	_dismiss_callback = on_dismiss_callback
	
	# Spawn lightweight celebratory confetti
	_spawn_confetti()
	
	# Configure styling and copy
	if power_up_type == PowerUp.Type.TRIPLE_SHOT:
		_setup_triple_shot()
	else:
		_setup_explode()
		
	# Play cute bouncy entrance animation
	_animate_entrance()


func _setup_triple_shot() -> void:
	if icon_label:
		icon_label.text = "⚡"
	if title_label:
		title_label.text = "Yay!! Triple Shot Unlocked!"
		title_label.add_theme_color_override("font_color", Color(0.3, 0.9, 1.0, 1.0))
	if punchline_label:
		punchline_label.text = "Rapid Burst Ready!\nShoot 3 balls one by one for the cost of only 1!"
	if action_button:
		action_button.text = "LET'S SMASH! ⚡"
		_apply_button_style(action_button, Color(0.05, 0.45, 0.85, 0.95), Color(0.4, 0.95, 1.0, 1.0))
	_apply_card_style(Color(0.05, 0.15, 0.25, 0.96), Color(0.2, 0.75, 1.0, 0.9))


func _setup_explode() -> void:
	if icon_label:
		icon_label.text = "💥"
	if title_label:
		title_label.text = "Yay!! Explode Power-Up Unlocked!"
		title_label.add_theme_color_override("font_color", Color(1.0, 0.65, 0.15, 1.0))
	if punchline_label:
		punchline_label.text = "Total Devastation Unleashed!\nDetonate a fiery blast that flings every box away!"
	if action_button:
		action_button.text = "BLAST THEM! 💥"
		_apply_button_style(action_button, Color(0.85, 0.28, 0.05, 0.95), Color(1.0, 0.8, 0.2, 1.0))
	_apply_card_style(Color(0.22, 0.08, 0.05, 0.96), Color(1.0, 0.45, 0.1, 0.9))


func _apply_card_style(bg: Color, border: Color) -> void:
	if not card:
		return
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(3)
	style.set_corner_radius_all(24)
	style.shadow_color = Color(border.r, border.g, border.b, 0.4)
	style.shadow_size = 18
	card.add_theme_stylebox_override("panel", style)


func _apply_button_style(btn: Button, bg: Color, border: Color) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(2)
	style.set_corner_radius_all(16)
	btn.add_theme_stylebox_override("normal", style)
	btn.add_theme_stylebox_override("hover", style)
	btn.add_theme_stylebox_override("pressed", style)


func _spawn_confetti() -> void:
	if not confetti_container:
		return
	var sparkles := SparkleEffect.new()
	sparkles.name = "Sparkles"
	sparkles.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	confetti_container.add_child(sparkles)


func _animate_entrance() -> void:
	if not card:
		return
		
	card.pivot_offset = card.size / 2.0
	card.scale = Vector2(0.25, 0.25)
	card.modulate.a = 0.0
	
	if backdrop:
		backdrop.modulate.a = 0.0
		var bg_tween := create_tween()
		bg_tween.tween_property(backdrop, "modulate:a", 1.0, 0.2)
		
	var card_tween := create_tween().set_parallel()
	card_tween.tween_property(card, "scale", Vector2.ONE, 0.38).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	card_tween.tween_property(card, "modulate:a", 1.0, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	
	# Subtle icon pulse
	if icon_label:
		icon_label.pivot_offset = icon_label.size / 2.0
		var icon_tween := create_tween().set_loops()
		icon_tween.tween_property(icon_label, "scale", Vector2(1.15, 1.15), 0.4).set_trans(Tween.TRANS_SINE)
		icon_tween.tween_property(icon_label, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_SINE)


func _on_action_pressed() -> void:
	if _is_closing:
		return
	_is_closing = true
	
	# Snappy pop-out animation
	var tween := create_tween().set_parallel()
	tween.tween_property(card, "scale", Vector2(0.1, 0.1), 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.tween_property(self, "modulate:a", 0.0, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(func():
		dismissed.emit()
		if _dismiss_callback.is_valid():
			_dismiss_callback.call()
		queue_free()
	)
