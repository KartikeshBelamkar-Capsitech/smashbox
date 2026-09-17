class_name FireBall
extends CannonBall
## Fireball projectile that explodes on impact and flings all objects on the table.

signal exploded(explosion_center: Vector3)

@export var explosion_scene: PackedScene = preload("res://scenes/effects/explosion_effect.tscn")
@export var blast_radius: float = 20.0
@export var blast_force: float = 3.5

var _has_exploded: bool = false


func _ready() -> void:
	super._ready()
	# Fireballs can trigger on any body contact
	body_entered.connect(_on_fire_contact)


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	# If the fireball reaches the stack depth (Z <= -11.5) without direct collision, detonate!
	if not _has_exploded and global_position.z <= -11.5:
		detonate()


func _on_fire_contact(_body: Node) -> void:
	if _has_exploded:
		return
	detonate()


func despawn() -> void:
	if not _has_exploded:
		detonate()
	else:
		super.despawn()


## Triggers the explosive detonation at current position.
func detonate() -> void:
	if _has_exploded:
		return
	_has_exploded = true
	
	var blast_pos: Vector3 = global_position
	
	# Spawn explosion VFX
	if explosion_scene:
		var exp_effect := explosion_scene.instantiate() as Node3D
		if exp_effect:
			get_tree().root.add_child(exp_effect)
			exp_effect.global_position = blast_pos
			
	# Emit signal so cannon or level can apply extra table-wide clearing logic
	exploded.emit(blast_pos)
	
	# Detonate all rigidbodies in the stack / table area
	_explode_table_objects(blast_pos)
	
	# Despawn the ball immediately
	fade_out_on_despawn = false
	despawn()


## Applies dramatic outward and upward explosive impulses to all target objects.
func _explode_table_objects(blast_pos: Vector3) -> void:
	# Find BoxStack in scene
	var scene_root: Node = get_tree().current_scene
	if not scene_root:
		return
		
	var target_bodies: Array[RigidBody3D] = []
	
	# Search BoxStack specifically
	var box_stack: Node = scene_root.find_child("BoxStack", true, false)
	if box_stack:
		for child in box_stack.get_children():
			if child is RigidBody3D:
				target_bodies.append(child)
				
	# Also search any other RigidBody3D targets that are not the ball itself
	for node in scene_root.find_children("*", "RigidBody3D", true, false):
		if node is RigidBody3D and node != self and not (node is CannonBall) and not (node in target_bodies):
			# If it's a box target or marked in targets
			if node is BoxTarget or node.name.begins_with("Box") or node.name.begins_with("Cylinder") or node.name.begins_with("Triangle"):
				target_bodies.append(node)
				
	# Apply explosive force to all found objects
	for obj in target_bodies:
		if not is_instance_valid(obj):
			continue
			
		var obj_pos: Vector3 = obj.global_position
		var diff: Vector3 = obj_pos - blast_pos
		var horizontal_dir: Vector3 = Vector3(diff.x, 0, diff.z)
		
		if horizontal_dir.length_squared() < 0.01:
			horizontal_dir = Vector3(randf_range(-1.0, 1.0), 0, randf_range(-1.0, 1.0)).normalized()
		else:
			horizontal_dir = horizontal_dir.normalized()
			
		# Add a moderate upward pop so objects lift gently off the table
		var upward_factor: float = randf_range(0.35, 0.65)
		var impulse_dir: Vector3 = (horizontal_dir + Vector3.UP * upward_factor).normalized()
		
		# Ensure body is awake
		obj.sleeping = false
		obj.freeze = false
		
		# Blast impulse scaled with mass
		var actual_force: float = randf_range(blast_force * 0.8, blast_force * 1.2) * maxf(obj.mass, 1.0)
		obj.apply_central_impulse(impulse_dir * actual_force)
		
		# Gentle tumbling
		var torque: Vector3 = Vector3(
			randf_range(-12.0, 12.0),
			randf_range(-12.0, 12.0),
			randf_range(-12.0, 12.0)
		) * maxf(obj.mass, 1.0)
		obj.apply_torque_impulse(torque)
