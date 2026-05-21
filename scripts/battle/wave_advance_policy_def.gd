extends Resource
class_name WaveAdvancePolicyDef

@export var policy_id: StringName = StringName()
@export var policy_kind: StringName = &"absolute_time"
@export var min_wave_duration := 0.0
@export var health_ratio_threshold := 0.5
@export var huge_warning_lead_time := 0.0
