class_name Cannon
extends Node3D
## Controls the cannon mechanics for aiming, firing projectiles, managing ammo,
## and producing recoil animation for a stack box smasher game.

signal ball_fired(ball: RigidBody3D, launch_velocity: Vector3)
signal ammo_changed(remaining_ammo: int)
signal out_of_ammo()
signal reloaded()
signal power_up_changed(power_up: int)
signal power_up_used(power_up: int)

@export_group("Projectile Settings")
## The projectile scene to instantiate (e.g. cannon_ball.tscn).
@export var ball_scene: PackedScene
## The projectile scene used for fire/explode power-up.
@export var fire_ball_scene: PackedScene = preload("res://scenes/fire_ball.tscn")
## Speed at which balls are propelled outward.
@export_range(10.0, 120.0, 1.0) var launch_speed: float = 50.0
## Optional explicit parent node where spawned balls will be added. If null, uses the active scene root.
@export var projectile_container: Node3D = null

@export_group("Firing Mechanics")
## Minimum delay in seconds between consecutive shots.
@export_range(0.05, 2.0, 0.05) var fire_cooldown: float = 0.25
## When true, ammo is not deducted.
@export var infinite_ammo: bool = true
## Maximum ammo capacity when infinite_ammo is false.
@export var max_ammo: int = 15
## Automatic reload delay after running out of ammo.
@export var auto_reload: bool = false
@export_range(0.5, 5.0, 0.1) var reload_duration: float = 2.0

@export_group("Aiming Controls")
## When enabled, cannon rotates towards the mouse cursor ray in 3D.
@export var enable_mouse_aim: bool = true
## Smooth interpolation rate for rotation tracking.
@export_range(1.0, 40.0, 1.0) var aim_lerp_speed: float = 18.0
## Distance in front of cannon where the virtual targeting plane is positioned (matches box stack distance).
@export var aim_plane_distance: float = 12.0
## Yaw limits in degrees relative to initial rotation (Min: Left, Max: Right).
@export var yaw_limits_deg: Vector2 = Vector2(-70.0, 70.0)
## Pitch limits in degrees (Min: Downwards, Max: Upwards).
@export var pitch_limits_deg: Vector2 = Vector2(-28.0, 35.0)

@export_group("Node References")
## Marker indicating where balls spawn and their initial forward trajectory.
@export var muzzle: Marker3D
## Optional barrel node that receives procedural recoil animation on fire.
@export var barrel_mesh: Node3D
## Optional muzzle effect node (sparks, smoke, flash light).
@export var muzzle_effect: MuzzleEffect
## Reference to the camera used for mouse projection. If null, attempts to find active 3D camera.
@export var aim_camera: Camera3D

var current_ammo: int = 15
var is_reloading: bool = false
var active_power_up: int = PowerUp.Type.NONE
var _is_burst_firing: bool = false
var _cooldown_timer: float = 0.0
var _initial_rotation_y: float = 0.0
var _target_aim_point: Vector3 = Vector3.ZERO
var _barrel_initial_pos: Vector3 = Vector3.ZERO


func _ready() -> void:
	current_ammo = max_ammo
	_initial_rotation_y = rotation.y
	
	if not barrel_mesh:
		barrel_mesh = find_child("Barrel", true, false) as Node3D
	if barrel_mesh:
		_barrel_initial_pos = barrel_mesh.position
		
	if not aim_camera:
		aim_camera = get_viewport().get_camera_3d()
		
	# Fallback: find child Marker3D if muzzle wasn't explicitly assigned
	if not muzzle:
		muzzle = find_child("Muzzle", true, false) as Marker3D
		
	if not muzzle_effect:
		muzzle_effect = find_child("MuzzleEffect", true, false) as MuzzleEffect


func _process(delta: float) -> void:
	if _cooldown_timer > 0.0:
		_cooldown_timer -= delta
		
	if enable_mouse_aim and _target_aim_point != Vector3.ZERO:
		_apply_smooth_aim(delta)


func _unhandled_input(event: InputEvent) -> void:
	if not enable_mouse_aim:
		return
		
	# Native support for mouse motion, touch taps, and touch drags on mobile
	var pointer_pos: Vector2 = Vector2.ZERO
	var has_pointer_pos: bool = false
	
	if event is InputEventMouse:
		pointer_pos = event.position
		has_pointer_pos = true
	elif event is InputEventScreenTouch or event is InputEventScreenDrag:
		pointer_pos = event.position
		has_pointer_pos = true
		
	if has_pointer_pos:
		_update_aim_target_from_mouse(pointer_pos)
		
	# Fire trigger: Left click, mobile screen tap, or custom "shoot" action
	var is_shoot_action: bool = InputMap.has_action("shoot") and event.is_action_pressed("shoot")
	var is_mouse_click: bool = event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed
	var is_touch_press: bool = event is InputEventScreenTouch and event.pressed
	
	if is_shoot_action or is_mouse_click or is_touch_press:
		if has_pointer_pos:
			_update_aim_target_from_mouse(pointer_pos)
			_snap_aim_to_target()
		shoot()


## Sets the current active power-up.
func set_power_up(p_type: int) -> void:
	active_power_up = p_type
	power_up_changed.emit(active_power_up)


## Gets the current active power-up.
func get_power_up() -> int:
	return active_power_up


## Primary function to fire a projectile.
## Returns true if a ball was successfully fired.
func shoot() -> bool:
	if _cooldown_timer > 0.0 or is_reloading or _is_burst_firing:
		return false
		
	# Check for special power-up shots
	if active_power_up == PowerUp.Type.FIRE_EXPLODE:
		var power_fired: int = active_power_up
		active_power_up = PowerUp.Type.NONE
		power_up_used.emit(power_fired)
		power_up_changed.emit(active_power_up)
		return _shoot_fire_explode()
	elif active_power_up == PowerUp.Type.TRIPLE_SHOT:
		var power_fired: int = active_power_up
		active_power_up = PowerUp.Type.NONE
		power_up_used.emit(power_fired)
		power_up_changed.emit(active_power_up)
		_shoot_triple_burst()
		return true
		
	if not infinite_ammo:
		if current_ammo <= 0:
			out_of_ammo.emit()
			if auto_reload:
				reload()
			return false
			
		current_ammo -= 1
		ammo_changed.emit(current_ammo)
		
	# Reset cooldown
	_cooldown_timer = fire_cooldown
	
	# Instantiate and launch ball
	var ball: RigidBody3D = _spawn_ball()
	if ball:
		var shoot_dir: Vector3 = _get_shooting_direction()
		if ball is CannonBall:
			ball.launch(shoot_dir, launch_speed)
		else:
			ball.linear_velocity = shoot_dir * launch_speed
			
		ball_fired.emit(ball, shoot_dir * launch_speed)
		
	# Play recoil juice and muzzle blast
	_trigger_recoil()
	if muzzle_effect:
		muzzle_effect.play()
	trigger_camera_shake(0.06, 0.12)
	
	return true


## Fires a fire/explode shot that detonates with fiery blast flinging all objects.
func _shoot_fire_explode() -> bool:
	if not infinite_ammo:
		if current_ammo <= 0:
			out_of_ammo.emit()
			if auto_reload:
				reload()
			return false
		current_ammo -= 1
		ammo_changed.emit(current_ammo)
		
	_cooldown_timer = fire_cooldown
	
	var spawn_pos: Vector3 = muzzle.global_position if muzzle else global_position
	var scene_to_use: PackedScene = fire_ball_scene if fire_ball_scene else ball_scene
	var ball_node: Node = scene_to_use.instantiate() if scene_to_use else _create_fallback_ball()
	
	if ball_node is RigidBody3D:
		var parent: Node = projectile_container if projectile_container else get_tree().current_scene
		if not parent:
			parent = get_tree().root
		parent.add_child(ball_node)
		ball_node.global_position = spawn_pos
		
		var shoot_dir: Vector3 = _get_shooting_direction()
		if ball_node is CannonBall:
			ball_node.launch(shoot_dir, launch_speed * 1.05)
		else:
			ball_node.linear_velocity = shoot_dir * launch_speed * 1.05
			
		ball_fired.emit(ball_node, shoot_dir * launch_speed * 1.05)
		
	_trigger_recoil()
	if muzzle_effect:
		muzzle_effect.play()
	trigger_camera_shake(0.2, 0.25)
	return true


## Rapidly fires 3 balls one by one in succession.
func _shoot_triple_burst() -> void:
	_is_burst_firing = true
	_cooldown_timer = fire_cooldown + 0.35
	
	var angles: Array[float] = [-1.5, 0.0, 1.5]
	for i in range(3):
		if not infinite_ammo:
			if current_ammo <= 0:
				out_of_ammo.emit()
				break
			current_ammo -= 1
			ammo_changed.emit(current_ammo)
			
		var ball: RigidBody3D = _spawn_ball()
		if ball:
			var base_dir: Vector3 = _get_shooting_direction()
			var spread_dir: Vector3 = base_dir.rotated(Vector3.UP, deg_to_rad(angles[i]))
			if ball is CannonBall:
				ball.launch(spread_dir, launch_speed)
			else:
				ball.linear_velocity = spread_dir * launch_speed
			ball_fired.emit(ball, spread_dir * launch_speed)
			
		_trigger_recoil()
		if muzzle_effect:
			muzzle_effect.play()
		trigger_camera_shake(0.08, 0.1)
		
		if i < 2:
			await get_tree().create_timer(0.09).timeout
			
	_is_burst_firing = false


## Applies subtle dynamic camera recoil juice.
func trigger_camera_shake(strength: float = 0.12, duration: float = 0.2) -> void:
	if not aim_camera:
		aim_camera = get_viewport().get_camera_3d()
	if not aim_camera:
		return
		
	var orig_pos: Vector3 = aim_camera.position
	var tween: Tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	var steps: int = 4
	var step_dur: float = duration / float(steps)
	for i in range(steps):
		var offset: Vector3 = Vector3(
			randf_range(-strength, strength),
			randf_range(-strength, strength),
			randf_range(-strength * 0.5, strength * 0.5)
		)
		tween.tween_property(aim_camera, "position", orig_pos + offset, step_dur)
	tween.tween_property(aim_camera, "position", orig_pos, 0.05)


## Reloads ammo count back to max.
func reload() -> void:
	if is_reloading:
		return
	is_reloading = true
	
	var tween: Tween = create_tween()
	tween.tween_interval(reload_duration)
	tween.tween_callback(func() -> void:
		current_ammo = max_ammo
		is_reloading = false
		ammo_changed.emit(current_ammo)
		reloaded.emit()
	)


## Calculates the normalized forward vector pointing directly toward the target aim point.
func _get_shooting_direction() -> Vector3:
	var origin: Vector3 = muzzle.global_position if muzzle else global_position
	if _target_aim_point != Vector3.ZERO:
		return (_target_aim_point - origin).normalized()
	if muzzle:
		return -muzzle.global_transform.basis.z.normalized()
	return -global_transform.basis.z.normalized()


## Spawns the projectile into the scene hierarchy.
func _spawn_ball() -> RigidBody3D:
	var spawn_pos: Vector3 = muzzle.global_position if muzzle else global_position
	var instance: Node = null
	
	if ball_scene:
		instance = ball_scene.instantiate()
	else:
		# Dynamic fallback: build a basic CannonBall if no scene is hooked up yet
		instance = _create_fallback_ball()
		
	if not (instance is RigidBody3D):
		push_error("Cannon: ball_scene must inherit from RigidBody3D (CannonBall)!")
		if instance:
			instance.queue_free()
		return null
		
	var ball := instance as RigidBody3D
	
	# Add to designated container or scene root
	var parent: Node = projectile_container if projectile_container else get_tree().current_scene
	if not parent:
		parent = get_tree().root
	parent.add_child(ball)
	
	ball.global_position = spawn_pos
	return ball


## Procedural fallback ball in case user hasn't baked a .tscn yet.
func _create_fallback_ball() -> RigidBody3D:
	var ball := CannonBall.new()
	ball.mass = 2.0
	
	var col_shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.35
	col_shape.shape = sphere
	ball.add_child(col_shape)
	
	var mesh_inst := MeshInstance3D.new()
	var sphere_mesh := SphereMesh.new()
	sphere_mesh.radius = 0.35
	sphere_mesh.height = 0.7
	mesh_inst.mesh = sphere_mesh
	ball.add_child(mesh_inst)
	
	return ball


## Casts ray from 3D camera to world space to calculate target aim point.
func _update_aim_target_from_mouse(mouse_pos: Vector2) -> void:
	if not aim_camera:
		aim_camera = get_viewport().get_camera_3d()
	if not aim_camera:
		return
		
	var ray_origin: Vector3 = aim_camera.project_ray_origin(mouse_pos)
	var ray_dir: Vector3 = aim_camera.project_ray_normal(mouse_pos)
	
	# Priority 1: Check if ray directly intersects a target RigidBody3D (like a box in the stack)
	var space_state: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(ray_origin, ray_origin + ray_dir * 100.0)
	var result: Dictionary = space_state.intersect_ray(query)
	
	if result.has("collider") and (result["collider"] is RigidBody3D):
		_target_aim_point = result["position"]
		return
		
	# Priority 2: Project mouse ray onto the vertical aiming plane at the box stack distance
	# This prevents the cannon from aiming down into the floor near the player
	var target_z: float = global_position.z - aim_plane_distance
	if absf(ray_dir.z) > 0.0001:
		var t: float = (target_z - ray_origin.z) / ray_dir.z
		if t > 0.0:
			var point: Vector3 = ray_origin + ray_dir * t
			point.y = maxf(point.y, -0.5)
			_target_aim_point = point
			return
			
	_target_aim_point = ray_origin + ray_dir * aim_plane_distance


## Instantly aligns the cannon orientation to current target (for responsive mobile tap shooting).
func _snap_aim_to_target() -> void:
	var look_target: Vector3 = _target_aim_point
	var local_target: Vector3 = to_local(look_target)
	
	if local_target.length_squared() < 0.001:
		return
		
	var target_yaw: float = -atan2(local_target.x, -local_target.z)
	var horizontal_dist: float = Vector2(local_target.x, local_target.z).length()
	var target_pitch: float = atan2(local_target.y, horizontal_dist)
	
	var min_yaw_rad: float = deg_to_rad(yaw_limits_deg.x)
	var max_yaw_rad: float = deg_to_rad(yaw_limits_deg.y)
	target_yaw = clampf(target_yaw, min_yaw_rad, max_yaw_rad)
	
	var min_pitch_rad: float = deg_to_rad(pitch_limits_deg.x)
	var max_pitch_rad: float = deg_to_rad(pitch_limits_deg.y)
	target_pitch = clampf(target_pitch, min_pitch_rad, max_pitch_rad)
	
	rotation.y = _initial_rotation_y + target_yaw
	rotation.x = target_pitch


## Smoothly rotates the cannon towards the target point with angle limits.
func _apply_smooth_aim(delta: float) -> void:
	var look_target: Vector3 = _target_aim_point
	var local_target: Vector3 = to_local(look_target)
	
	if local_target.length_squared() < 0.001:
		return
		
	# Calculate target yaw and pitch
	var target_yaw: float = -atan2(local_target.x, -local_target.z)
	var horizontal_dist: float = Vector2(local_target.x, local_target.z).length()
	var target_pitch: float = atan2(local_target.y, horizontal_dist)
	
	# Clamp angles to configured limits
	var min_yaw_rad: float = deg_to_rad(yaw_limits_deg.x)
	var max_yaw_rad: float = deg_to_rad(yaw_limits_deg.y)
	target_yaw = clampf(target_yaw, min_yaw_rad, max_yaw_rad)
	
	var min_pitch_rad: float = deg_to_rad(pitch_limits_deg.x)
	var max_pitch_rad: float = deg_to_rad(pitch_limits_deg.y)
	target_pitch = clampf(target_pitch, min_pitch_rad, max_pitch_rad)
	
	# Smoothly rotate
	rotation.y = lerp_angle(rotation.y, _initial_rotation_y + target_yaw, aim_lerp_speed * delta)
	rotation.x = lerp_angle(rotation.x, target_pitch, aim_lerp_speed * delta)


## Applies a punchy squash & stretch and backward kick recoil to the barrel.
func _trigger_recoil() -> void:
	if not barrel_mesh:
		return
		
	var tween: Tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var kickback_pos: Vector3 = _barrel_initial_pos + Vector3(0, 0, 0.25)
	
	# Kick back quickly and return smoothly
	tween.tween_property(barrel_mesh, "position", kickback_pos, 0.05)
	tween.tween_property(barrel_mesh, "position", _barrel_initial_pos, 0.2)
