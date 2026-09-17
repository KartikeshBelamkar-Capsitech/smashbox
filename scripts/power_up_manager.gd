class_name PowerUp
extends RefCounted
## Defines power-up types and utility data for Smashbox.

enum Type {
	NONE = 0,
	FIRE_EXPLODE = 1,
	TRIPLE_SHOT = 2,
}

const NAMES: Dictionary = {
	Type.NONE: "None",
	Type.FIRE_EXPLODE: "Fire Explode",
	Type.TRIPLE_SHOT: "Triple Shot",
}
