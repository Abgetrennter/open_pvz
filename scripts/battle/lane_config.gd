extends Resource
class_name LaneConfig

@export var lane_index := 0
@export var lane_type: StringName = &"grass"
@export var slot_type_override: StringName = StringName()
@export var base_tags_override: PackedStringArray = PackedStringArray()
@export var lane_traits: PackedStringArray = PackedStringArray()
@export var height_offset := 0.0
@export var slope_y_per_slot := 0.0
@export var terrain_profile: Resource = null
@export var visual_theme: StringName = StringName()
