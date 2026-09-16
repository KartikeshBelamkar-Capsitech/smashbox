class_name MuzzleEffect
extends Node3D
## Multi-layered particle muzzle blast featuring additive billboard fire core,
## directional flame jet, high-speed embers, soft dissolving smoke, and dynamic lighting.

@export_group("Components")
@export var flash_light: OmniLight3D
@export var fire_core: CPUParticles3D
@export var fire_jet: CPUParticles3D
@export var spark_particles: CPUParticles3D
@export var smoke_particles: CPUParticles3D

@export_group("Settings")
@export var max_light_energy: float = 3.2
@export var light_fade_duration: float = 0.12


func _ready() -> void:
	if not flash_light:
		flash_light = find_child("FlashLight", true, false) as OmniLight3D
	if not fire_core:
		fire_core = find_child("FireCore", true, false) as CPUParticles3D
	if not fire_jet:
		fire_jet = find_child("FireJet", true, false) as CPUParticles3D
	if not spark_particles:
		spark_particles = find_child("SparkParticles", true, false) as CPUParticles3D
	if not smoke_particles:
		smoke_particles = find_child("SmokeParticles", true, false) as CPUParticles3D

	if flash_light:
		flash_light.light_energy = 0.0
		flash_light.visible = false


## Plays the layered muzzle blast particle explosion.
func play() -> void:
	_trigger_light()
	_trigger_particle_emitters()


func _trigger_light() -> void:
	if not flash_light:
		return
		
	flash_light.visible = true
	flash_light.light_energy = max_light_energy
	
	var tween: Tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(flash_light, "light_energy", 0.0, light_fade_duration)
	tween.tween_callback(func() -> void:
		flash_light.visible = false
	)


func _trigger_particle_emitters() -> void:
	if fire_core:
		fire_core.restart()
		fire_core.emitting = true
		
	if fire_jet:
		fire_jet.restart()
		fire_jet.emitting = true
		
	if spark_particles:
		spark_particles.restart()
		spark_particles.emitting = true
		
	if smoke_particles:
		smoke_particles.restart()
		smoke_particles.emitting = true
