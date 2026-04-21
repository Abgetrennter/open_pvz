extends Resource
class_name BattleSpawnEntry

@export var entity_kind: StringName = &"plant"
@export var archetype: Resource = null
@export var archetype_id: StringName = StringName()
@export var entity_template: Resource = null
@export var entity_template_id: StringName = StringName()
@export var lane_id := 0
@export var x_position := 160.0
@export var spawn_overrides: Dictionary = {}
@export var hit_height_band_override: Resource = null
@export var projectile_flight_profile_override: Resource = null
@export var projectile_template_override: Resource = null
