extends Resource
class_name EntityTemplate

@export var template_id: StringName = StringName()
@export var entity_kind: StringName = &"plant"
@export var display_name := ""
@export var root_scene: PackedScene
@export var max_health := -1
@export var hitbox_size := Vector2.ZERO
@export var hit_height_band: Resource = null
@export var projectile_flight_profile: Resource = null
@export var default_params: Dictionary = {}
