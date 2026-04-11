extends Resource
class_name BattleSpawnEntry

@export var entity_kind: StringName = &"plant"
@export var entity_template: Resource = null
@export var lane_id := 0
@export var x_position := 160.0
@export var hit_height_band: Resource = null
@export var projectile_flight_profile: Resource = null
@export var params: Dictionary = {}
