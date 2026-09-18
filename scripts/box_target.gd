class_name BoxTarget
extends RigidBody3D
## Rigid box target in the stack. Automatically cleans up when knocked into the void.

@export var despawn_y: float = -2.0


var _is_destroyed: bool = false


func _ready() -> void:
	add_to_group("level_targets")


func _physics_process(_delta: float) -> void:
	if not _is_destroyed and global_position.y < despawn_y:
		_is_destroyed = true
		if Events:
			Events.target_destroyed.emit(self)
		queue_free()
