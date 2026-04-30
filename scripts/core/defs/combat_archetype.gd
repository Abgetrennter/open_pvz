extends Resource
class_name CombatArchetype

@export var archetype_id: StringName = StringName()
@export var entity_kind: StringName = &"plant"
@export var display_name := ""
@export var tags: PackedStringArray = PackedStringArray()
@export var root_scene: PackedScene
@export var visual_scene: PackedScene
@export var required_components: PackedStringArray = PackedStringArray()
@export var optional_components: PackedStringArray = PackedStringArray()
@export var placement_role: StringName = &"primary"
@export var allowed_slot_types: PackedStringArray = PackedStringArray()
@export var required_placement_tags: PackedStringArray = PackedStringArray(["supports_primary"])
@export var granted_placement_tags: PackedStringArray = PackedStringArray()
@export var required_present_roles: PackedStringArray = PackedStringArray()
@export var required_present_archetypes: PackedStringArray = PackedStringArray()
@export var required_empty_roles: PackedStringArray = PackedStringArray(["blocker"])
@export var max_health := -1
@export var hitbox_size := Vector2.ZERO
@export var hit_height_band: Resource = null
@export var projectile_flight_profile: Resource = null
@export var projectile_template: Resource = null
@export var default_params: Dictionary = {}
@export var compiler_hints: Dictionary = {}
@export var mechanics: Array[Resource] = []
