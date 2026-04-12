extends Resource
class_name TriggerBinding

@export var binding_id: StringName = StringName()
@export var behavior_key: StringName = StringName()
@export var enabled := true
@export var trigger_id: StringName = StringName()
@export var event_name: StringName = StringName()
@export var condition_values: Dictionary = {}
@export var effect_id: StringName = StringName()
@export var effect_params: Dictionary = {}
@export var on_hit_effect_id: StringName = StringName()
@export var on_hit_effect_params: Dictionary = {}
@export var projectile_template: Resource = null
