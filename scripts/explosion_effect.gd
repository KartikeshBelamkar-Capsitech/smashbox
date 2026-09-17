class_name ExplosionEffect
extends Node3D
## Handles visual and physical detonation juice: fiery flash light,
## shockwave particles, flying fire sparks, smoke cloud, and auto cleanup.

@export var max_light_energy: float = 6.0
@export var light_duration: float = 0.35
@export var auto_destroy_delay: float = 1.6

@onready var light: OmniLight3D = $ExplosionLight
@onready var shockwave_particles: CPUParticles3D = $ShockwaveParticles
@onready var fire_particles: CPUParticles3D = $FireParticles
@onready var spark_particles: CPUParticles3D = $SparkParticles
@onready var smoke_particles: CPUParticles3D = $SmokeParticles


func _ready() -> void:
	if shockwave_particles:
		shockwave_particles.emitting = true
	if fire_particles:
		fire_particles.emitting = true
	if spark_particles:
		spark_particles.emitting = true
	if smoke_particles:
		smoke_particles.emitting = true
		
	if light:
		light.light_energy = max_light_energy
		var tween: Tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(light, "light_energy", 0.0, light_duration)
		
	get_tree().create_timer(auto_destroy_delay).timeout.connect(queue_free)
