extends Resource
class_name BattleScenario

@export var scenario_id: StringName = &"minimal_validation"
@export var display_name := "Minimal Battle Validation"
@export_multiline var description := ""
@export var goals: PackedStringArray = PackedStringArray()
@export var validation_time_limit := 8.0
@export var initial_sun := 0
@export var sun_auto_collect_delay := -1.0
@export var sun_drop_entries: Array = []
@export var resource_spend_requests: Array = []
@export var board_slot_count := 5
@export var board_slot_origin_x := 160.0
@export var board_slot_spacing := 96.0
@export var board_slot_configs: Array = []
@export var lane_count := 2
@export var card_defs: Array = []
@export var card_play_requests: Array = []
@export var status_application_requests: Array = []
@export var field_object_configs: Array = []
@export var wave_defs: Array = []
@export var defeat_line_x := 80.0
@export var validation_rules: Array = []
@export var spawns: Array = []
