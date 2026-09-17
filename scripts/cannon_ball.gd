class_name CannonBall
extends RigidBody3D
## Represents a cannon projectile designed for smashing box stacks.
## Uses physics-based RigidBody3D with anti-tunneling (continuous collision detection)
## and automatic cleanup.

signal impacted(target: Node3D, contact_point: Vector3, contact_normal: Vector3)
signal despawned()
signal landed()

@export_group("Ball Settings")
## Lifetime in seconds before the ball automatically frees itself.
@export_range(1.0, 30.0, 0.5) var lifetime: float = 1.5
## Minimum Y coordinate before despawning (falling off the world).
@export var despawn_y_threshold: float = -20.0
## Impact damage or impulse multiplier transferred to hit boxes.
@export_range(1.0, 10.0, 0.5) var impact_force_multiplier: float = 2.5
## Destruction or fade duration upon despawn.
@export var fade_out_on_despawn: bool = true
## Custom gravity scale for satisfying arcade trajectory (lower = flatter, punchier shot).
@export_range(0.1, 1.5, 0.05) var gravity_scale_factor: float = 0.45

@export_group("Impact VFX")
## Visual effect spawned on impact with physics targets.
@export var impact_effect_scene: PackedScene = preload("res://scenes/effects/impact_effect.tscn")
## Minimum velocity required to trigger an impact explosion.
@export var min_impact_speed: float = 6.0

var _life_timer: float = 0.0
var _is_despawning: bool = false
var _last_impact_time: float = -1.0
var _landed: bool = false


func _ready() -> void:
	add_to_group("cannon_balls")
	# Configure physics for high-speed projectile reliability
	continuous_cd = true
	contact_monitor = true
	max_contacts_reported = 4
	gravity_scale = gravity_scale_factor
	
	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	if _is_despawning:
		return
		
	# Virtual floor check must happen even if it bounced off the platform
	if global_position.y <= 0.22:
		global_position.y = 0.22
		if linear_velocity.y < 0:
			linear_velocity.y = -linear_velocity.y * 0.4 # bounce
		linear_damp = 1.5
		angular_damp = 1.5
		if not _landed:
			_landed = true
			landed.emit()
		return
		
	if _landed:
		return
		
	_life_timer += delta
	if _life_timer >= lifetime or global_position.y <= despawn_y_threshold:
		despawn()



## Launches the ball with a direct linear velocity.
func launch(direction: Vector3, speed: float) -> void:
	# Set linear velocity directly for guaranteed, punchy projectile speed
	linear_velocity = direction.normalized() * speed
	angular_velocity = Vector3.ZERO


## Handles clean despawn with optional scale shrink tween.
func despawn() -> void:
	if _is_despawning:
		return
	_is_despawning = false
	despawned.emit()
	
	if fade_out_on_despawn:
		_is_despawning = true
		var tween: Tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tween.tween_property(self, "scale", Vector3.ZERO, 0.2)
		tween.tween_callback(queue_free)
	else:
		queue_free()


## Signal callback triggered when the ball collides with another physics body.
func _on_body_entered(body: Node) -> void:
	if _is_despawning:
		return
		
	if body is StaticBody3D and not _landed:
		_landed = true
		landed.emit()
		
	var current_speed: float = linear_velocity.length()
	var current_time: float = Time.get_ticks_msec() / 1000.0
	var contact_point: Vector3 = global_position
	var contact_normal: Vector3 = -linear_velocity.normalized()
	
	# Trigger impact VFX and mobile haptics on solid hits (throttled to prevent redundant stacking)
	if current_speed >= min_impact_speed and (current_time - _last_impact_time > 0.08):
		_last_impact_time = current_time
		_spawn_impact_vfx(contact_point, contact_normal)
		HapticManager.play_impact()
		
	if body is Node3D:
		impacted.emit(body, contact_point, contact_normal)



## Spawns the impact visual effect oriented along the collision normal.
func _spawn_impact_vfx(pos: Vector3, normal: Vector3) -> void:
	if not impact_effect_scene:
		return
		
	var effect := impact_effect_scene.instantiate() as Node3D
	if not effect:
		return
		
	get_tree().root.add_child(effect)
	effect.global_position = pos
	
	if normal != Vector3.ZERO and not normal.is_equal_approx(Vector3.UP):
		effect.look_at(pos + normal, Vector3.UP)
