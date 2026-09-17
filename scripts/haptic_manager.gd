class_name HapticManager
extends RefCounted
## Provides tactile haptic feedback and vibrations specifically tuned for Android devices.
## Integrates directly with Godot's native Input.vibrate_handheld API.

## Snappy, tactile haptic pulse for firing regular cannon balls (30ms).
static func play_shot() -> void:
	vibrate(30, 0.55)


## Heavy, powerful vibration for explosive FireBall blast (85ms).
static func play_explosion() -> void:
	vibrate(85, 1.0)


## Rapid staccato burst vibration for TripleShot (22ms).
static func play_burst_shot() -> void:
	vibrate(22, 0.45)


## Crisp physical impact vibration when cannon balls hit crates or obstacles (35ms).
static func play_impact() -> void:
	vibrate(35, 0.65)


## Micro tactile feedback on UI button tap or power-up selection (16ms).
static func play_button_click() -> void:
	vibrate(16, 0.35)


## Celebratory double-pulse haptic vibration on completing a level.
static func play_win(tree: SceneTree) -> void:
	vibrate(45, 0.75)
	if tree:
		var timer := tree.create_timer(0.12)
		timer.timeout.connect(func() -> void:
			vibrate(80, 0.95)
		)


## Low rumble vibration upon running out of ammunition.
static func play_lose() -> void:
	vibrate(120, 0.7)


## Core vibration dispatcher that safely communicates with the device hardware.
static func vibrate(duration_ms: int, amplitude: float = -1.0) -> void:
	if amplitude >= 0.0:
		Input.vibrate_handheld(duration_ms, amplitude)
	else:
		Input.vibrate_handheld(duration_ms)
