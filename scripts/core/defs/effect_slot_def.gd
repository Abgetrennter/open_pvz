extends Resource
class_name EffectSlotDef

enum SlotType {
	VALUE,
	EFFECT,
}

@export var slot_name: StringName = StringName()
@export var slot_type := SlotType.VALUE
@export var value_type: StringName = &"float"
@export var min_value := 0.0
@export var max_value := 1.0
@export var allowed_effect_ids: PackedStringArray = PackedStringArray()
@export var allowed_effect_tags: PackedStringArray = PackedStringArray()
