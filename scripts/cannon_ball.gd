class_name CannonBall
extends RigidBody3D
## Represents a cannon projectile designed for smashing box stacks.
## Uses physics-based RigidBody3D with anti-tunneling (continuous collision detection)
## and automatic cleanup.

signal impacted(target: Node3D, contact_point: Vector3, contact_normal: Vector3)
signal despawned()

@export_group("Ball Settings")
## Lifetime in seconds before the ball automatically frees itself.
@export_range(1.0, 30.0, 0.5) var lifetime: float = 6.0
## Minimum Y coordinate before despawning (falling off the world).
@export var despawn_y_threshold: float = -20.0
## Impact damage or impulse multiplier transferred to hit boxes.
@export_range(1.0, 10.0, 0.5) var impact_force_multiplier: float = 2.5
## Destruction or fade duration upon despawn.
@export var fade_out_on_despawn: bool = true
## Custom gravity scale for satisfying arcade trajectory (lower = flatter, punchier shot).
@export_range(0.1, 1.5, 0.05) var gravity_scale_factor: float = 0.45

var _life_timer: float = 0.0
var _is_despawning: bool = false


func _ready() -> void:
	# Configure physics for high-speed projectile reliability
	continuous_cd = true
	contact_monitor = true
	max_contacts_reported = 4
	gravity_scale = gravity_scale_factor
	
	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	if _is_despawning:
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
		
	var contact_point: Vector3 = global_position
	var contact_normal: Vector3 = -linear_velocity.normalized()
	
	if body is Node3D:
		impacted.emit(body, contact_point, contact_normal)
