extends Resource
class_name ProjectileFlightProfile

@export var profile_id: StringName = &"flat"
@export var move_mode: StringName = &"linear"
@export var height_strategy: StringName = &"flat"
@export var peak_height := 72.0
@export var projection_scale := 1.0
@export var max_hit_height := 24.0
@export var hit_strategy: StringName = StringName()
@export var terminal_hit_strategy: StringName = StringName()
@export var impact_radius := 20.0
@export var collision_padding := 10.0
@export var travel_duration := -1.0
@export var lead_time_scale := 1.0
@export var dynamic_target_adjustment := -1.0
@export var dynamic_target_axis: StringName = &"x"
