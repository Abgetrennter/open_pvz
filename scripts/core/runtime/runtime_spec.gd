extends RefCounted
class_name RuntimeSpec

var compiler_version: StringName = StringName()
var source_archetype_id: StringName = StringName()
var entity_kind: StringName = StringName()
var display_name := ""
var tags: PackedStringArray = PackedStringArray()
var required_components: PackedStringArray = PackedStringArray()
var optional_components: PackedStringArray = PackedStringArray()
var params: Dictionary = {}
var hit_height_band: Resource = null
var projectile_template: Resource = null
var projectile_flight_profile: Resource = null
var trigger_specs: Array = []
var controller_specs: Array = []
var state_specs: Array = []
var runtime_state_values: Dictionary = {}
var mechanic_ids: PackedStringArray = PackedStringArray()
var mechanic_runtime_states: Dictionary = {}
var root_scene: PackedScene = null
var max_health: int = -1
var hitbox_size: Vector2 = Vector2.ZERO
var notes: PackedStringArray = PackedStringArray()
var placement_spec: Dictionary = {}
