extends Resource
class_name WaveRecipeDef

@export var recipe_id: StringName = StringName()
@export var total_waves := 1
@export var waves_per_flag := 10
@export var start_delay := 0.0
@export var base_spacing := 8.0
@export var base_budget := 1
@export var budget_per_wave := 1
@export var flag_budget_multiplier := 2.5
@export var pool_def: Resource = null
@export var flag_entry: Resource = null
@export var advance_policy: Resource = null
@export var special_injection_rules: Array = []
