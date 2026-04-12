extends Resource
class_name ProjectileTemplate

@export var template_id: StringName = StringName()
@export var display_name := ""
@export var tags: PackedStringArray = PackedStringArray()
@export var root_scene: PackedScene
@export var visual_scene: PackedScene
@export var flight_profile: Resource = null
@export var lifetime := -1.0
@export var hitbox_radius := 10.0
@export var default_params: Dictionary = {}
