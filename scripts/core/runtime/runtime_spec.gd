extends RefCounted
class_name RuntimeSpec

var compiler_version: StringName = StringName()
var source_archetype_id: StringName = StringName()
var entity_kind: StringName = StringName()
var display_name := ""
var tags: PackedStringArray = PackedStringArray()
var backend_entity_template: Resource = null
var params: Dictionary = {}
var hit_height_band: Resource = null
var projectile_template: Resource = null
var projectile_flight_profile: Resource = null
var compiled_trigger_bindings: Array = []
var runtime_state_values: Dictionary = {}
var mechanic_ids: PackedStringArray = PackedStringArray()
var notes: PackedStringArray = PackedStringArray()


func has_backend_entity_template() -> bool:
	return backend_entity_template != null

