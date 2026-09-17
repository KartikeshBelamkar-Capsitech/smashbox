extends SceneTree

func _init() -> void:
	_run()

func _run() -> void:
	print("[TEST] Starting Power-Ups automated verification test...")
	
	# Load level 1 scene
	var level_scene: PackedScene = load("res://scenes/levels/level_1.tscn")
	assert(level_scene != null, "Failed to load level_1.tscn")
	
	var root_node: Node = level_scene.instantiate()
	root.add_child(root_node)
	current_scene = root_node
	
	# Wait for nodes to enter tree and call _ready()
	await process_frame
	await process_frame
	
	print("[TEST] Level 1 instantiated and ready.")
	
	# Verify Cannon
	var cannon: Cannon = root_node.find_child("Cannon", true, false) as Cannon
	assert(cannon != null, "Cannon not found in Level 1")
	print("[TEST] Found Cannon.")
	
	# Verify BoxStack
	var box_stack: Node = root_node.find_child("BoxStack", true, false)
	assert(box_stack != null, "BoxStack not found")
	var initial_box_count: int = box_stack.get_child_count()
	print("[TEST] Found BoxStack with %d target boxes." % initial_box_count)
	assert(initial_box_count > 0, "No boxes in stack!")
	
	# Verify LevelUI & PowerUpButtons
	var level_ui: LevelUI = root_node.find_child("LevelUI", true, false) as LevelUI
	assert(level_ui != null, "LevelUI not found")
	var power_up_ui: Node = level_ui.find_child("PowerUpButtons", true, false)
	assert(power_up_ui != null, "PowerUpButtons not found in LevelUI")
	print("[TEST] Found PowerUpButtons in LevelUI.")
	
	var left_btn: Button = power_up_ui.find_child("LeftButton", true, false) as Button
	var right_btn: Button = power_up_ui.find_child("RightButton", true, false) as Button
	assert(left_btn != null, "LeftButton not found")
	assert(right_btn != null, "RightButton not found")
	print("[TEST] Found LeftButton and RightButton.")
	
	# Test 1: Toggle Explode Power-Up
	print("[TEST 1] Testing Explode Power-Up toggle...")
	assert(cannon.get_power_up() == PowerUp.Type.NONE, "Default should be NONE")
	left_btn.emit_signal("pressed")
	assert(cannon.get_power_up() == PowerUp.Type.FIRE_EXPLODE, "Power-up should be FIRE_EXPLODE after left press")
	print("[TEST 1] Explode armed successfully.")
	
	# Test 2: Fire Explode Shot
	print("[TEST 2] Testing Fire Explode Shot...")
	var shot_success: bool = cannon.shoot()
	assert(shot_success, "Shoot should succeed")
	assert(cannon.get_power_up() == PowerUp.Type.NONE, "Power-up should be consumed back to NONE")
	print("[TEST 2] Fire Explode shot fired and consumed.")
	
	# Find the spawned FireBall
	var found_fireball: FireBall = null
	for child in root_node.get_children():
		if child is FireBall:
			found_fireball = child
			break
	if not found_fireball:
		for child in root.get_children():
			if child is FireBall:
				found_fireball = child
				break
				
	assert(found_fireball != null, "FireBall projectile was not spawned!")
	print("[TEST 2] Spawned FireBall verified.")
	
	# Trigger detonation on the FireBall
	found_fireball.detonate()
	print("[TEST 2] FireBall detonation executed.")
	
	# Wait for physics step to integrate the impulse
	await physics_frame
	await physics_frame
	
	# Verify that boxes received explosive impulse
	var moving_count: int = 0
	for child in box_stack.get_children():
		if child is RigidBody3D:
			if child.linear_velocity.length_squared() > 0.01 or child.angular_velocity.length_squared() > 0.01:
				moving_count += 1
	print("[TEST 2] %d / %d boxes are moving with explosion impulse." % [moving_count, initial_box_count])
	assert(moving_count > 0, "No boxes were affected by explosion!")
	
	# Test 3: Toggle Triple Shot Power-Up
	print("[TEST 3] Testing Triple Shot Power-Up toggle...")
	right_btn.emit_signal("pressed")
	assert(cannon.get_power_up() == PowerUp.Type.TRIPLE_SHOT, "Power-up should be TRIPLE_SHOT after right press")
	print("[TEST 3] Triple Shot armed successfully.")
	
	# Test 4: Fire Triple Shot (wait for cooldown first)
	await create_timer(0.3).timeout
	print("[TEST 4] Testing Triple Shot firing...")
	var counter: Array[int] = [0]
	cannon.ball_fired.connect(func(_ball, _vel): counter[0] += 1)
	
	cannon.shoot()
	assert(cannon.get_power_up() == PowerUp.Type.NONE, "Power-up should be consumed back to NONE")
	
	# Wait for coroutine to finish the 3 burst shots
	await create_timer(0.45).timeout
	print("[TEST 4] Total burst balls fired: %d" % counter[0])
	assert(counter[0] == 3, "Expected exactly 3 balls fired for triple shot burst, got %d" % counter[0])
	print("[TEST SUCCESS] All power-up tests passed successfully!")
	quit(0)
