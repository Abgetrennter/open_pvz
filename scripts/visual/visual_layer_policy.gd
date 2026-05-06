extends RefCounted
class_name VisualLayerPolicy


# ── Layer name constants ────────────────────────────────────────────

const LAYER_GROUND: StringName = &"ground"
const LAYER_SHADOW: StringName = &"shadow"
const LAYER_FIELD_OBJECT: StringName = &"field_object"
const LAYER_PLANT: StringName = &"plant"
const LAYER_ZOMBIE: StringName = &"zombie"
const LAYER_PROJECTILE: StringName = &"projectile"
const LAYER_WORLD_FX: StringName = &"world_fx"
const LAYER_FOG_WEATHER: StringName = &"fog_weather"
const LAYER_PREVIEW: StringName = &"preview"
const LAYER_SCREEN_FX: StringName = &"screen_fx"
const LAYER_UI: StringName = &"ui"


# ── z_index base values ─────────────────────────────────────────────

const LAYER_BASE := {
	&"ground": 0,
	&"shadow": 1000,
	&"field_object": 2000,
	&"plant": 3000,
	&"zombie": 4000,
	&"projectile": 5000,
	&"world_fx": 6000,
	&"fog_weather": 7000,
	&"preview": 8000,
	&"screen_fx": 9000,
	&"ui": 10000,
}

const ROW_STRIDE := 100


# ── Static helpers ──────────────────────────────────────────────────

static func resolve_z_index(entity_kind: StringName, lane_id: int, visual_layer: StringName, local_offset: int = 0) -> int:
	var base: int = LAYER_BASE.get(visual_layer, 0)
	var lane_offset: int = lane_id * ROW_STRIDE if lane_id >= 0 else 0
	return base + lane_offset + local_offset


static func get_layer_for_entity_kind(entity_kind: StringName) -> StringName:
	match entity_kind:
		&"plant":
			return LAYER_PLANT
		&"zombie":
			return LAYER_ZOMBIE
		&"projectile":
			return LAYER_PROJECTILE
		&"field_object":
			return LAYER_FIELD_OBJECT
		_:
			return LAYER_PLANT
