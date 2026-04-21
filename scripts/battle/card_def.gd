extends Resource
class_name CardDef

@export var card_id: StringName = &"card"
@export var display_name := "Card"
@export var archetype_id: StringName = StringName()
@export var entity_template_id: StringName = StringName()
@export var sun_cost := 25
@export var cooldown_seconds := 1.0
@export var placement_tags: PackedStringArray = PackedStringArray()
