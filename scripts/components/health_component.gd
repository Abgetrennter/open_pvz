extends Node
class_name HealthComponent

const EventDataRef = preload("res://scripts/core/runtime/event_data.gd")

signal damaged(amount: int)
signal died()
signal layer_destroyed(layer_id: StringName)

@export var max_health := 100
var current_health := 0
var health_layers: Array[Dictionary] = []

const DEFAULT_LAYER_ORDER := {
	&"attachment": 10,
	&"shield": 20,
	&"helm": 30,
	&"body_extra": 35,
	&"body": 40,
}
const KNOWN_LAYER_KINDS := [
	&"attachment",
	&"shield",
	&"helm",
	&"body_extra",
	&"body",
	&"barrier",
	&"energy_shield",
]


func _ready() -> void:
	current_health = max_health
	_sync_owner_state()


func configure_health_layers(layer_defs: Array) -> void:
	health_layers.clear()
	for layer_def in layer_defs:
		var layer := _normalize_layer_def(layer_def)
		if layer.is_empty():
			continue
		health_layers.append(layer)
	health_layers.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var a_order := int(a.get("route_order", _default_route_order(StringName(a.get("layer_kind", StringName())))))
		var b_order := int(b.get("route_order", _default_route_order(StringName(b.get("layer_kind", StringName())))))
		if a_order != b_order:
			return a_order < b_order
		return String(a.get("layer_id", StringName())) < String(b.get("layer_id", StringName()))
	)
	_sync_owner_state()


func take_damage(
	amount: int,
	source_node: Node = null,
	tags: PackedStringArray = PackedStringArray(),
	runtime_overrides: Dictionary = {}
) -> void:
	if current_health <= 0:
		return
	var owner := get_parent()
	if owner != null and owner.has_method("is_damageable") and not bool(owner.call("is_damageable")):
		return
	var applied_amount := maxi(amount, 0)
	if not health_layers.is_empty():
		applied_amount = _apply_layered_damage(applied_amount, source_node, tags, runtime_overrides)
	else:
		current_health = max(current_health - applied_amount, 0)
	_sync_owner_state()
	damaged.emit(applied_amount)

	var damaged_event = EventDataRef.create(source_node, owner, applied_amount, tags, runtime_overrides)
	damaged_event.core["health"] = current_health
	damaged_event.core["max_health"] = max_health
	damaged_event.core["health_layers"] = get_health_layers_snapshot()
	EventBus.push_event(&"entity.damaged", damaged_event)

	if current_health == 0:
		var death_runtime: Dictionary = runtime_overrides.duplicate(true)
		death_runtime["depth"] = int(damaged_event.runtime.get("depth", 1)) + 1
		var death_tags := PackedStringArray(tags)
		death_tags.append("death")
		var died_event = EventDataRef.create(source_node, owner, 0, death_tags, death_runtime)
		EventBus.push_event(&"entity.died", died_event)
		died.emit()


func heal(amount: int) -> void:
	current_health = min(current_health + amount, max_health)
	_sync_owner_state()


func get_total_health() -> int:
	var total := current_health
	for layer in health_layers:
		total += int(layer.get("current_health", 0))
	return total


func get_total_max_health() -> int:
	var total := max_health
	for layer in health_layers:
		total += int(layer.get("max_health", 0))
	return total


func get_health_layers_snapshot() -> Array:
	var snapshot: Array = []
	for layer in health_layers:
		snapshot.append(layer.duplicate(true))
	return snapshot


func _sync_owner_state() -> void:
	var owner := get_parent()
	if owner != null and owner.has_method("set_health_state"):
		owner.call("set_health_state", get_total_health(), get_total_max_health())
	if owner != null and owner.has_method("set_health_layers_state"):
		owner.call("set_health_layers_state", get_health_layers_snapshot())


func _normalize_layer_def(layer_def) -> Dictionary:
	if layer_def == null:
		return {}
	var layer: Dictionary = {}
	if layer_def is Dictionary:
		layer = Dictionary(layer_def).duplicate(true)
	elif layer_def.has_method("to_runtime_layer"):
		layer = Dictionary(layer_def.call("to_runtime_layer"))
	elif layer_def.has_method("get"):
		layer = {
			"layer_id": StringName(layer_def.get("layer_id")),
			"layer_kind": StringName(layer_def.get("layer_kind")),
			"armor_type": StringName(layer_def.get("armor_type")),
			"max_health": int(layer_def.get("max_health")),
			"current_health": int(layer_def.get("max_health")),
			"route_order": int(layer_def.get("route_order")),
			"material_tags": PackedStringArray(layer_def.get("material_tags")),
			"overflow_policy": StringName(layer_def.get("overflow_policy")),
			"alive": int(layer_def.get("max_health")) > 0,
		}
	else:
		return {}
	var layer_id := StringName(layer.get("layer_id", StringName()))
	var layer_kind := StringName(layer.get("layer_kind", StringName()))
	if layer_id == StringName() or layer_kind == StringName():
		return {}
	if not layer.has("route_order") or int(layer.get("route_order", 0)) == 0:
		layer["route_order"] = _default_route_order(layer_kind)
	layer["layer_id"] = layer_id
	layer["layer_kind"] = layer_kind
	layer["armor_type"] = StringName(layer.get("armor_type", StringName()))
	layer["max_health"] = maxi(0, int(layer.get("max_health", 0)))
	layer["current_health"] = clampi(int(layer.get("current_health", layer.get("max_health", 0))), 0, int(layer["max_health"]))
	layer["material_tags"] = PackedStringArray(layer.get("material_tags", PackedStringArray()))
	layer["overflow_policy"] = StringName(layer.get("overflow_policy", &"spill_to_next"))
	layer["alive"] = int(layer["current_health"]) > 0
	return layer


func _apply_layered_damage(amount: int, source_node: Node, tags: PackedStringArray, runtime_overrides: Dictionary) -> int:
	var remaining := amount
	var applied := 0
	var policy := _normalize_damage_layer_policy(runtime_overrides.get("damage_layer_policy", {}))
	var route := _build_damage_route(policy)
	for layer_index in route:
		if remaining <= 0:
			break
		var layer: Dictionary = health_layers[layer_index]
		var current := int(layer.get("current_health", 0))
		if current <= 0:
			continue
		var absorbed = mini(current, remaining)
		current -= absorbed
		remaining -= absorbed
		applied += absorbed
		layer["current_health"] = current
		layer["alive"] = current > 0
		health_layers[layer_index] = layer
		if current == 0:
			_emit_layer_destroyed(layer, source_node, tags, runtime_overrides)
		if StringName(layer.get("overflow_policy", &"spill_to_next")) == &"absorb_only":
			remaining = 0
	var spillover := bool(policy.get("spillover", true))
	if remaining > 0 and spillover:
		var body_damage := mini(current_health, remaining)
		current_health = max(current_health - body_damage, 0)
		applied += body_damage
	return applied


func _build_damage_route(policy: Dictionary) -> PackedInt32Array:
	var bypass := PackedStringArray(policy.get("bypass_layer_kinds", PackedStringArray()))
	var route := PackedInt32Array()
	for index in range(health_layers.size()):
		var layer: Dictionary = health_layers[index]
		var layer_kind := StringName(layer.get("layer_kind", StringName()))
		if bypass.has(String(layer_kind)):
			continue
		route.append(index)
	return route


func _normalize_damage_layer_policy(raw_policy: Variant) -> Dictionary:
	var policy := {
		"bypass_layer_kinds": PackedStringArray(),
		"spillover": true,
	}
	if raw_policy is Dictionary:
		var raw_bypass: Variant = raw_policy.get("bypass_layer_kinds", PackedStringArray())
		if raw_bypass is PackedStringArray:
			policy["bypass_layer_kinds"] = PackedStringArray(raw_bypass)
		elif raw_bypass is Array:
			policy["bypass_layer_kinds"] = PackedStringArray(raw_bypass)
		if raw_policy.has("spillover"):
			policy["spillover"] = bool(raw_policy.get("spillover", true))
	return policy


func _emit_layer_destroyed(layer: Dictionary, source_node: Node, tags: PackedStringArray, runtime_overrides: Dictionary) -> void:
	var owner := get_parent()
	var destroyed_layer_id := StringName(layer.get("layer_id", StringName()))
	layer_destroyed.emit(destroyed_layer_id)
	var layer_tags := PackedStringArray(tags)
	layer_tags.append("health_layer")
	layer_tags.append("layer_destroyed")
	var event_data = EventDataRef.create(source_node, owner, 0, layer_tags, runtime_overrides)
	event_data.core["layer_id"] = destroyed_layer_id
	event_data.core["layer_kind"] = StringName(layer.get("layer_kind", StringName()))
	event_data.core["armor_type"] = StringName(layer.get("armor_type", StringName()))
	event_data.core["health_layers"] = get_health_layers_snapshot()
	EventBus.push_event(&"health.layer_destroyed", event_data)


func _default_route_order(layer_kind: StringName) -> int:
	return int(DEFAULT_LAYER_ORDER.get(layer_kind, 50))
