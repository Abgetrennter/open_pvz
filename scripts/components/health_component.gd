extends Node
class_name HealthComponent

const EventDataRef = preload("res://scripts/core/runtime/event_data.gd")

signal damaged(amount: int)
signal died()

@export var max_health := 100
var current_health := 0


func _ready() -> void:
	current_health = max_health
	_sync_owner_state()


func take_damage(
	amount: int,
	source_node: Node = null,
	tags: PackedStringArray = PackedStringArray(),
	runtime_overrides: Dictionary = {}
) -> void:
	if current_health <= 0:
		return
	current_health = max(current_health - amount, 0)
	_sync_owner_state()
	damaged.emit(amount)

	var damaged_event = EventDataRef.create(source_node, get_parent(), amount, tags, runtime_overrides)
	EventBus.push_event(&"entity.damaged", damaged_event)

	if current_health == 0:
		var death_runtime: Dictionary = runtime_overrides.duplicate(true)
		death_runtime["depth"] = int(damaged_event.runtime.get("depth", 1)) + 1
		var death_tags := PackedStringArray(tags)
		death_tags.append("death")
		var died_event = EventDataRef.create(source_node, get_parent(), 0, death_tags, death_runtime)
		EventBus.push_event(&"entity.died", died_event)
		died.emit()


func heal(amount: int) -> void:
	current_health = min(current_health + amount, max_health)
	_sync_owner_state()


func _sync_owner_state() -> void:
	var owner := get_parent()
	if owner != null and owner.has_method("set_health_state"):
		owner.call("set_health_state", current_health, max_health)
