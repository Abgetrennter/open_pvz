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
@export var lane_configs: Array = []
@export var lane_y_positions: Array[float] = []
@export var lane_origin_y := 0.0
@export var lane_spacing := 0.0
@export var spawn_zones: Array = []
