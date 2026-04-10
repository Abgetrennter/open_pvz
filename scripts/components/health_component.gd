extends Node
class_name HealthComponent

const EventDataRef = preload("res://scripts/core/runtime/event_data.gd")

signal damaged(amount: int)
signal died()

@export var max_health := 100
var current_health := 0


func _ready() -> void:
	current_health = max_health


func take_damage(amount: int, source_node: Node = null, tags: PackedStringArray = PackedStringArray()) -> void:
	current_health = max(current_health - amount, 0)
	damaged.emit(amount)

	var damaged_event = EventDataRef.create(source_node, get_parent(), amount, tags)
	damaged_event.runtime["depth"] = int(damaged_event.runtime.get("depth", 1))
	EventBus.push_event(&"entity.damaged", damaged_event)

	if current_health == 0:
		var died_event = EventDataRef.create(source_node, get_parent(), 0, PackedStringArray(["death"]))
		died_event.runtime["depth"] = int(damaged_event.runtime.get("depth", 1)) + 1
		EventBus.push_event(&"entity.died", died_event)
		died.emit()


func heal(amount: int) -> void:
	current_health = min(current_health + amount, max_health)
