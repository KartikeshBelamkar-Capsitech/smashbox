class_name BoxTarget
extends RigidBody3D
## Rigid box target in the stack. Automatically cleans up when knocked into the void.

@export var despawn_y: float = -20.0


func _physics_process(_delta: float) -> void:
	if global_position.y < despawn_y:
		queue_free()
