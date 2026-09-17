class_name HapticManager
extends RefCounted
## Provides tactile haptic feedback and vibrations specifically tuned for Android devices.
## Integrates directly with Godot's native Input.vibrate_handheld API.

## Snappy, tactile haptic pulse for firing regular cannon balls (50ms).
static func play_shot() -> void:
	vibrate(50)


## Heavy, powerful vibration for explosive FireBall blast (120ms).
static func play_explosion() -> void:
	vibrate(120)


## Rapid staccato burst vibration for TripleShot (35ms).
static func play_burst_shot() -> void:
	vibrate(35)


## Crisp physical impact vibration when cannon balls hit crates or obstacles (60ms).
static func play_impact() -> void:
	vibrate(60)


## Micro tactile feedback on UI button tap or power-up selection (40ms).
static func play_button_click() -> void:
	vibrate(40)


## Celebratory double-pulse haptic vibration on completing a level.
static func play_win(tree: SceneTree) -> void:
	vibrate(60)
	if tree:
		var timer := tree.create_timer(0.14)
		timer.timeout.connect(func() -> void:
			vibrate(100)
		)


## Low rumble vibration upon running out of ammunition.
static func play_lose() -> void:
	vibrate(150)


## Core vibration dispatcher that safely communicates with the device hardware.
## Passing amplitude -1.0 uses VibrationEffect.DEFAULT_AMPLITUDE for full compatibility.
static func vibrate(duration_ms: int, amplitude: float = -1.0) -> void:
	Input.vibrate_handheld(duration_ms, amplitude)
