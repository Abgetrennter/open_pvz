extends Resource
class_name SpawnZoneConfig

@export var zone_id: StringName = StringName()
@export var lane_id := 0
@export var x := 0.0
@export var zone_group: StringName = &"default"
@export var zone_tags: PackedStringArray = PackedStringArray()
@export var enabled := true
