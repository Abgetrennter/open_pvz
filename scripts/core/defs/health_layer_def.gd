extends Resource
class_name HealthLayerDef

@export var layer_id: StringName = StringName()
@export var layer_kind: StringName = StringName()
@export var armor_type: StringName = StringName()
@export var max_health := 0
@export var route_order := 0
@export var material_tags: PackedStringArray = PackedStringArray()
@export var overflow_policy: StringName = &"spill_to_next"


func to_runtime_layer() -> Dictionary:
	return {
		"layer_id": layer_id,
		"layer_kind": layer_kind,
		"armor_type": armor_type,
		"max_health": max_health,
		"current_health": max_health,
		"route_order": route_order,
		"material_tags": PackedStringArray(material_tags),
		"overflow_policy": overflow_policy,
		"alive": max_health > 0,
	}
