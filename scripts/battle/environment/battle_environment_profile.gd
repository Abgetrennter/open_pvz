extends Resource
class_name BattleEnvironmentProfile

@export var profile_id: StringName = StringName()
@export var initial_conditions: PackedStringArray = PackedStringArray([&"day", &"sunny"])
@export var natural_sun_enabled := true
@export var natural_sun_interval_seconds := 8.0
@export var natural_sun_value := 25
@export var sun_interval_scale := 1.0
@export var sun_value_scale := 1.0
@export var light_level := 1.0
@export var visibility_range_slots := -1
@export var fog_enabled := false
@export var fog_start_column := -1
@export var fog_max_alpha := 0.85
@export var fog_alpha_step := 0.12
@export var fog_clear_default_radius_slots := 2.0
@export var fog_clear_default_duration := 4.0
@export var visual_environment_id: StringName = StringName()
@export var audio_environment_id: StringName = StringName()
@export var timeline: Array[Dictionary] = []
