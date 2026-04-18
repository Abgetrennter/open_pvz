extends Resource
class_name BattlefieldPreset

@export var preset_id: StringName = StringName()
@export var display_name := ""
@export_multiline var description := ""
@export var lane_count := 2
@export var board_slot_count := 5
@export var board_slot_origin_x := 160.0
@export var board_slot_spacing := 96.0
@export var board_slot_configs: Array = []
