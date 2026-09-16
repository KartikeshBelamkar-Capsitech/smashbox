class_name ImpactEffect
extends Node3D
## Handles collision impact VFX: wooden debris splinters, dust puff, hit sparks,
## dynamic light flash, and self-destruction.

@export var max_light_energy: float = 2.5
@export var light_duration: float = 0.08
@export var auto_destroy_delay: float = 0.55

@onready var light: OmniLight3D = $ImpactLight
@onready var debris_particles: CPUParticles3D = $DebrisParticles
@onready var dust_particles: CPUParticles3D = $DustParticles
@onready var spark_particles: CPUParticles3D = $SparkParticles


func _ready() -> void:
	# Trigger particle bursts
	if debris_particles:
		debris_particles.emitting = true
	if dust_particles:
		dust_particles.emitting = true
	if spark_particles:
		spark_particles.emitting = true
		
	# Quick flash light
	if light:
		light.light_energy = max_light_energy
		var tween: Tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(light, "light_energy", 0.0, light_duration)
		
	# Self cleanup after particles finish
	get_tree().create_timer(auto_destroy_delay).timeout.connect(queue_free)
