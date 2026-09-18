extends Node
## Global Event Bus for decoupled communication across systems in Smashbox.
## Registered as an Autoload singleton named "Events".

# Combat & Projectiles
signal ball_fired(ball: RigidBody3D, launch_velocity: Vector3)
signal ammo_changed(remaining_ammo: int, max_ammo: int)
signal out_of_ammo()
signal reloaded()

# Targets & Objectives
signal target_destroyed(target: Node3D)

# Power-Ups
signal power_up_selected(power_up_type: int)
signal power_up_used(power_up_type: int)
signal power_up_changed(power_up_type: int)
signal power_up_unlocked(power_up_type: int)

# Level Flow & Management
signal level_started(level_data: LevelData)
signal level_won(level_data: LevelData)
signal level_lost(level_data: LevelData)
signal level_restart_requested()
signal next_level_requested()
signal home_requested()

# Juice & Feedback
signal camera_shake_requested(strength: float, duration: float)
