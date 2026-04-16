extends Resource
class_name StatusApplicationRequest

@export var at_time := 0.0
@export var target_template_id: StringName = StringName()
@export var lane_id := -1
@export var status_id: StringName = &"status"
@export var duration := 1.0
@export var movement_scale := 1.0
@export var blocks_attack := false
