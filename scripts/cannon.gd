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
@export var yaw_limits_deg: Vector2 = Vector2(-85.0, 85.0)
## Pitch limits in degrees (Min: Downwards, Max: Upwards).
@export var pitch_limits_deg: Vector2 = Vector2(-55.0, 55.0)

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
var _cannon_fixed_pos: Vector3 = Vector3.ZERO
var _camera_initial_pos: Vector3 = Vector3.ZERO
var _camera_shake_tween: Tween = null


func _ready() -> void:
	current_ammo = max_ammo
	_initial_rotation_y = rotation.y
	_cannon_fixed_pos = position
	
	if not barrel_mesh:
		barrel_mesh = find_child("Barrel", true, false) as Node3D
	if barrel_mesh:
		_barrel_initial_pos = barrel_mesh.position
		
	if not aim_camera:
		aim_camera = get_viewport().get_camera_3d()
	if aim_camera:
		_camera_initial_pos = aim_camera.position
		
	# Fallback: find child Marker3D if muzzle wasn't explicitly assigned
	if not muzzle:
		muzzle = find_child("Muzzle", true, false) as Marker3D
		
	if not muzzle_effect:
		muzzle_effect = find_child("MuzzleEffect", true, false) as MuzzleEffect


func _process(delta: float) -> void:
	# Ensure cannon position is strictly fixed at all times
	position = _cannon_fixed_pos
	
	if _cooldown_timer > 0.0:
		_cooldown_timer -= delta
		
	if enable_mouse_aim and _target_aim_point != Vector3.ZERO:
		_apply_smooth_aim(delta)


func _unhandled_input(event: InputEvent) -> void:
	if not enable_mouse_aim:
		return
		
	# 1. Direct Android Screen Touch:
	# When user taps anywhere on screen, instantly aim at that touch point and shoot!
	if event is InputEventScreenTouch:
		if event.pressed:
			_update_aim_target_from_screen(event.position)
			_snap_aim_to_target()
			shoot()
		return
		
	# 2. Android Screen Drag:
	# Keep tracking aim smoothly while dragging finger across the screen
	if event is InputEventScreenDrag:
		_update_aim_target_from_screen(event.position)
		return
		
	# 3. Desktop Mouse Button Click:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			_update_aim_target_from_screen(event.position)
			_snap_aim_to_target()
			shoot()
		return
		
	# 4. Desktop Mouse Motion:
	if event is InputEventMouseMotion:
		_update_aim_target_from_screen(event.position)
		return
		
	# 5. Keyboard / Gamepad "shoot" action (Spacebar, Gamepad Trigger)
	if InputMap.has_action("shoot") and event.is_action_pressed("shoot"):
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
		
	# Play recoil juice, muzzle blast, and mobile haptic pulse
	_trigger_recoil()
	if muzzle_effect:
		muzzle_effect.play()
	trigger_camera_shake(0.06, 0.12)
	HapticManager.play_shot()
	
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
	HapticManager.play_explosion()
	return true


## Rapidly fires 3 balls one by one in succession, consuming only 1 ammo.
func _shoot_triple_burst() -> void:
	if not infinite_ammo:
		if current_ammo <= 0:
			out_of_ammo.emit()
			if auto_reload:
				reload()
			return
		current_ammo -= 1
		ammo_changed.emit(current_ammo)
		
	_is_burst_firing = true
	_cooldown_timer = fire_cooldown + 0.35
	
	var angles: Array[float] = [-1.5, 0.0, 1.5]
	for i in range(3):
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
		HapticManager.play_burst_shot()
		
		if i < 2:
			await get_tree().create_timer(0.09).timeout
			
	_is_burst_firing = false


## Applies subtle dynamic camera recoil shake via camera offset without shifting position.
func trigger_camera_shake(strength: float = 0.08, duration: float = 0.15) -> void:
	if not aim_camera:
		aim_camera = get_viewport().get_camera_3d()
	if not aim_camera:
		return
		
	# Ensure camera position is permanently anchored to its initial position
	if _camera_initial_pos != Vector3.ZERO:
		aim_camera.position = _camera_initial_pos
		
	if _camera_shake_tween and _camera_shake_tween.is_valid():
		_camera_shake_tween.kill()
		
	_camera_shake_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	var steps: int = 3
	var step_dur: float = duration / float(steps)
	for i in range(steps):
		var h_off: float = randf_range(-strength, strength)
		var v_off: float = randf_range(-strength * 0.7, strength * 0.7)
		_camera_shake_tween.tween_property(aim_camera, "h_offset", h_off, step_dur)
		_camera_shake_tween.tween_property(aim_camera, "v_offset", v_off, step_dur)
	_camera_shake_tween.tween_property(aim_camera, "h_offset", 0.0, 0.04)
	_camera_shake_tween.tween_property(aim_camera, "v_offset", 0.0, 0.04)


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


## Calculates the ballistic drop compensation so the ball arrives exactly at the touch point.
func _get_compensated_target(target_pt: Vector3) -> Vector3:
	var origin: Vector3 = muzzle.global_position if muzzle else global_position
	var to_target: Vector3 = target_pt - origin
	var dist: float = to_target.length()
	var flight_time: float = dist / maxf(launch_speed, 1.0)
	# Gravity scale factor is 0.45, default gravity is 9.8 m/s^2
	var gravity_mag: float = 9.8 * 0.45
	var vertical_drop: float = 0.5 * gravity_mag * flight_time * flight_time
	return target_pt + Vector3(0.0, vertical_drop, 0.0)


## Calculates the normalized forward vector pointing directly toward the target aim point with ballistic compensation.
func _get_shooting_direction() -> Vector3:
	var origin: Vector3 = muzzle.global_position if muzzle else global_position
	if _target_aim_point != Vector3.ZERO:
		var compensated: Vector3 = _get_compensated_target(_target_aim_point)
		return (compensated - origin).normalized()
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


## Casts ray from 3D camera to world space to calculate the exact 3D touch target point.
func _update_aim_target_from_screen(screen_pos: Vector2) -> void:
	if not aim_camera:
		aim_camera = get_viewport().get_camera_3d()
	if not aim_camera:
		return
		
	var ray_origin: Vector3 = aim_camera.project_ray_origin(screen_pos)
	var ray_dir: Vector3 = aim_camera.project_ray_normal(screen_pos)
	
	# Exclude in-flight cannon balls from blocking the touch ray
	var space_state: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(ray_origin, ray_origin + ray_dir * 120.0)
	var ball_nodes: Array[Node] = get_tree().get_nodes_in_group("cannon_balls")
	var exclude_rids: Array[RID] = []
	for b in ball_nodes:
		if b is CollisionObject3D:
			exclude_rids.append(b.get_rid())
	query.exclude = exclude_rids
	
	var result: Dictionary = space_state.intersect_ray(query)
	
	# Priority 1: Check if ray directly intersects a target, crate, or platform at gameplay depth
	if result.has("position") and result["position"].z <= global_position.z - 4.0:
		_target_aim_point = result["position"]
		return
		
	# Priority 2: Project touch ray onto the vertical aiming plane at the box stack distance (z = -12.0)
	var target_z: float = global_position.z - aim_plane_distance
	if absf(ray_dir.z) > 0.0001:
		var t: float = (target_z - ray_origin.z) / ray_dir.z
		if t > 0.0:
			_target_aim_point = ray_origin + ray_dir * t
			return
			
	_target_aim_point = ray_origin + ray_dir * aim_plane_distance


## Backward-compatible alias for mouse aim targeting.
func _update_aim_target_from_mouse(mouse_pos: Vector2) -> void:
	_update_aim_target_from_screen(mouse_pos)


## Computes the target yaw and pitch angles towards a 3D point without transform distortion.
func _get_target_angles(target_pt: Vector3) -> Vector2:
	var aim_pt: Vector3 = _get_compensated_target(target_pt)
	var diff: Vector3 = aim_pt - global_position
	if diff.length_squared() < 0.001:
		return Vector2(_initial_rotation_y, 0.0)
		
	var rel: Vector3 = diff.rotated(Vector3.UP, -_initial_rotation_y)
	var target_yaw: float = -atan2(rel.x, -rel.z)
	var horizontal_dist: float = Vector2(rel.x, rel.z).length()
	var target_pitch: float = atan2(rel.y, horizontal_dist)
	
	var min_yaw_rad: float = deg_to_rad(yaw_limits_deg.x)
	var max_yaw_rad: float = deg_to_rad(yaw_limits_deg.y)
	target_yaw = clampf(target_yaw, min_yaw_rad, max_yaw_rad)
	
	var min_pitch_rad: float = deg_to_rad(pitch_limits_deg.x)
	var max_pitch_rad: float = deg_to_rad(pitch_limits_deg.y)
	target_pitch = clampf(target_pitch, min_pitch_rad, max_pitch_rad)
	
	return Vector2(_initial_rotation_y + target_yaw, target_pitch)


## Instantly aligns the cannon orientation to current target (for responsive mobile tap shooting).
func _snap_aim_to_target() -> void:
	if _target_aim_point == Vector3.ZERO:
		return
	var angles: Vector2 = _get_target_angles(_target_aim_point)
	rotation.y = angles.x
	rotation.x = angles.y


## Smoothly rotates the cannon towards the target point with angle limits.
func _apply_smooth_aim(delta: float) -> void:
	if _target_aim_point == Vector3.ZERO:
		return
	var angles: Vector2 = _get_target_angles(_target_aim_point)
	rotation.y = lerp_angle(rotation.y, angles.x, aim_lerp_speed * delta)
	rotation.x = lerp_angle(rotation.x, angles.y, aim_lerp_speed * delta)


## Applies a punchy squash & stretch and backward kick recoil to the barrel.
func _trigger_recoil() -> void:
	if not barrel_mesh:
		return
		
	var tween: Tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var kickback_pos: Vector3 = _barrel_initial_pos + Vector3(0, 0, 0.25)
	
	# Kick back quickly and return smoothly
	tween.tween_property(barrel_mesh, "position", kickback_pos, 0.05)
	tween.tween_property(barrel_mesh, "position", _barrel_initial_pos, 0.2)
