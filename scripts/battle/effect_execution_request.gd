extends Resource
class_name EffectExecutionRequest

@export var at_time := 0.0
@export var effect_id: StringName = StringName()
@export var params: Dictionary = {}
@export var owner_archetype_id: StringName = StringName()
@export var owner_lane_id := -1
@export var source_archetype_id: StringName = StringName()
@export var source_lane_id := -1
@export var target_archetype_id: StringName = StringName()
@export var target_lane_id := -1
@export var position := Vector2.ZERO
