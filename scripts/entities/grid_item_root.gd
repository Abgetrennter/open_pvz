extends "res://scripts/entities/field_object_root.gd"
class_name GridItemRoot

var grid_lane_id := -1
var grid_slot_index := -1
var occupies_blocker_role := false
var _grid_item_state: Node = null


func _ready() -> void:
	super()
	set_state_value(&"grid_lane_id", grid_lane_id)
	set_state_value(&"grid_slot_index", grid_slot_index)
	set_state_value(&"occupies_blocker_role", occupies_blocker_role)
	if not is_damageable():
		set_health_state(0, 0)


func bind_grid_item_state(state: Node) -> void:
	_grid_item_state = state


func bind_grid_slot(lane_id_value: int, slot_index_value: int, blocker_role: bool) -> void:
	grid_lane_id = lane_id_value
	grid_slot_index = slot_index_value
	occupies_blocker_role = blocker_role
	set_state_value(&"grid_lane_id", grid_lane_id)
	set_state_value(&"grid_slot_index", grid_slot_index)
	set_state_value(&"slot_index", grid_slot_index)
	set_state_value(&"placement_role", &"grid_item")
	set_state_value(&"occupies_blocker_role", occupies_blocker_role)


func release_from_grid(reason: StringName = &"grid_item_removed") -> void:
	if _grid_item_state != null and is_instance_valid(_grid_item_state) and _grid_item_state.has_method("remove_grid_item_for_entity"):
		_grid_item_state.call("remove_grid_item_for_entity", self, reason)


func take_damage(
	amount: int,
	source_node: Node = null,
	tags: PackedStringArray = PackedStringArray(),
	runtime_overrides: Dictionary = {}
) -> void:
	if not is_damageable():
		return
	var health_component: Node = get_node_or_null("HealthComponent")
	if health_component == null or not health_component.has_method("take_damage"):
		return
	health_component.call("take_damage", amount, source_node, tags, runtime_overrides)
