class_name SparkleEffect
extends Control

var elapsed: float = 0.0
var launch_velocities: Array[Vector2] = []
var rotations: Array[float] = []
var rotation_speeds: Array[float] = []
var sway_phases: Array[float] = []
var piece_sizes: Array[Vector2] = []
var sprinkle_colors: Array[Color] = [
	Color(1.0, 0.3, 0.35),
	Color(0.25, 0.8, 1.0),
	Color(1.0, 0.82, 0.2),
	Color(0.45, 1.0, 0.48),
	Color(0.85, 0.4, 1.0),
	Color(1.0, 0.5, 0.2),
	Color(0.3, 1.0, 0.85),
	Color(1.0, 0.4, 0.75)
]


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var random := RandomNumberGenerator.new()
	random.seed = 48271
	for index in 48:
		var spread := random.randf_range(-270.0, 270.0)
		launch_velocities.append(Vector2(spread, random.randf_range(-560.0, -280.0)))
		rotations.append(random.randf_range(-PI, PI))
		rotation_speeds.append(random.randf_range(-10.0, 10.0))
		sway_phases.append(random.randf_range(0.0, TAU))
		piece_sizes.append(Vector2(random.randf_range(5.0, 10.0), random.randf_range(12.0, 23.0)))
	queue_redraw()


func _process(delta: float) -> void:
	elapsed += delta
	queue_redraw()


func _draw() -> void:
	var center := size * 0.5
	center.y -= 70.0
	var cycle_time := fmod(elapsed, 3.8)
	var gravity := 780.0
	for index in launch_velocities.size():
		var velocity := launch_velocities[index]
		var point := center + velocity * cycle_time
		point.y += 0.5 * gravity * cycle_time * cycle_time
		point.x += sin(cycle_time * 5.0 + sway_phases[index]) * 18.0
		var life := clampf(cycle_time / 2.4, 0.0, 1.0)
		var fade := 1.0 - clampf((cycle_time - 2.6) / 1.2, 0.0, 1.0)
		var color: Color = sprinkle_colors[index % sprinkle_colors.size()]
		color.a = fade * (0.92 - life * 0.12)
		draw_set_transform(point, rotations[index] + rotation_speeds[index] * cycle_time, Vector2.ONE)
		draw_rect(Rect2(-piece_sizes[index].x * 0.5, -piece_sizes[index].y * 0.5, piece_sizes[index].x, piece_sizes[index].y), color)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
