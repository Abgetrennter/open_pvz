extends Node
class_name BattleFieldState

# Row-scoped interval field modifiers (original Zamboni ice trail semantics,
# de-pvz Zombie.cpp:3908-3938): per (lane, kind) the modifier is one interval
# [x_min, x_max] with a single row-global timer - the Zamboni extends the
# interval leftward as it drives and every renewal refreshes the whole row,
# matching mIceMinX/mIceTimer exactly. Grid-cell needs stay in GridItem; this
# channel is only for row-interval terrain.

const EventDataRef = preload("res://scripts/core/runtime/event_data.gd")

const EVENT_APPLIED_EMISSION_STEP_PX := 24.0

var battle: Node = null

var _modifiers: Dictionary = {}
var _last_emitted_x_min: Dictionary = {}


func setup(battle_node: Node, _scenario: Resource) -> void:
	battle = battle_node
	_modifiers.clear()
	_last_emitted_x_min.clear()
	EventBus.subscribe(&"game.tick", Callable(self, "_on_game_tick"))


func _exit_tree() -> void:
	EventBus.unsubscribe(&"game.tick", Callable(self, "_on_game_tick"))


func get_debug_name() -> String:
	return "field_state"


func get_debug_snapshot() -> Dictionary:
	var snapshots: Array = []
	for key: Variant in _modifiers.keys():
		var modifier: Dictionary = _modifiers[key]
		snapshots.append({
			"lane_id": int(modifier.get("lane_id", -1)),
			"kind": StringName(modifier.get("kind", StringName())),
			"x_min": float(modifier.get("x_min", 0.0)),
			"x_max": float(modifier.get("x_max", 0.0)),
			"remaining_ticks": int(modifier.get("remaining_ticks", 0)),
		})
	return {
		"entity_id": -1,
		"archetype_id": StringName(),
		"entity_kind": &"field_state",
		"team": &"neutral",
		"lane_id": -1,
		"status": &"active",
		"position": Vector2.ZERO,
		"health": 0,
		"max_health": 0,
		"values": {
			"modifier_count": snapshots.size(),
			"modifiers": snapshots,
		},
	}


func apply_modifier(lane_id: int, kind: StringName, x_min: float, x_max: float, duration_ticks: int, source_entity_id: int = -1) -> void:
	if lane_id < 0 or kind == StringName() or duration_ticks <= 0:
		return
	var key := _modifier_key(lane_id, kind)
	var modifier: Dictionary = _modifiers.get(key, {})
	var is_new: bool = modifier.is_empty()
	var extended: bool = false
	if is_new:
		modifier = {
			"lane_id": lane_id,
			"kind": kind,
			"x_min": minf(x_min, x_max),
			"x_max": maxf(x_min, x_max),
			"remaining_ticks": duration_ticks,
			"source_entity_id": source_entity_id,
		}
	else:
		var merged_x_min := minf(float(modifier.get("x_min")), minf(x_min, x_max))
		var merged_x_max := maxf(float(modifier.get("x_max")), maxf(x_min, x_max))
		extended = merged_x_min < float(modifier.get("x_min")) - 0.001 or merged_x_max > float(modifier.get("x_max")) + 0.001
		modifier["x_min"] = merged_x_min
		modifier["x_max"] = merged_x_max
		# Renewal refreshes the whole row (original mIceTimer = 3000 on every
		# pass); a later shorter renewal never shortens a longer one.
		modifier["remaining_ticks"] = maxi(int(modifier.get("remaining_ticks")), duration_ticks)
	_modifiers[key] = modifier
	if is_new:
		_emit_modifier_event(&"field.modifier_applied", modifier)
	elif extended and absf(float(modifier.get("x_min")) - float(_last_emitted_x_min.get(key, modifier.get("x_min")))) >= EVENT_APPLIED_EMISSION_STEP_PX:
		_last_emitted_x_min[key] = modifier.get("x_min")
		_emit_modifier_event(&"field.modifier_applied", modifier)


func renew_lane_modifier(lane_id: int, kind: StringName, duration_ticks: int) -> void:
	# Timer-only renewal (original UpdateZombieBobsled mIceTimer = max(500, m)):
	# refreshes the duration of an EXISTING lane modifier and never creates
	# one or moves its interval - a sled past the ice's left edge stays off
	# the ice even while it renews the timer.
	var key := _modifier_key(lane_id, kind)
	if not _modifiers.has(key):
		return
	var modifier: Dictionary = _modifiers[key]
	modifier["remaining_ticks"] = maxi(int(modifier.get("remaining_ticks")), duration_ticks)
	_modifiers[key] = modifier


func query(lane_id: int, x: float) -> Array[StringName]:
	var kinds: Array[StringName] = []
	for key: Variant in _modifiers.keys():
		var modifier: Dictionary = _modifiers[key]
		if int(modifier.get("lane_id", -1)) != lane_id:
			continue
		if _modifier_covers(modifier, x):
			kinds.append(StringName(modifier.get("kind")))
	return kinds


func has_modifier(lane_id: int, kind: StringName, x: float) -> bool:
	var key := _modifier_key(lane_id, kind)
	if not _modifiers.has(key):
		return false
	return _modifier_covers(_modifiers[key], x)


func lane_modifier_x_min(lane_id: int, kind: StringName) -> float:
	# Left edge of the lane's interval (original mIceMinX); NaN when absent,
	# which callers treat as "fully off the ice".
	var key := _modifier_key(lane_id, kind)
	if not _modifiers.has(key):
		return NAN
	return float(_modifiers[key].get("x_min"))


func get_ice_trail_speed_scale(lane_id: int, x: float, entity_tags: PackedStringArray) -> float:
	# Ice halves walking speed (original Zombie::GetSpeedModifier ice check);
	# vehicles (Zamboni, Bobsled sled) are exempt, matching the original
	# UpdateZombieWalking branches that never apply terrain scaling to them.
	if entity_tags.has("vehicle"):
		return 1.0
	if has_modifier(lane_id, &"ice_trail", x):
		return 0.5
	return 1.0


func _modifier_covers(modifier: Dictionary, x: float) -> bool:
	return x >= float(modifier.get("x_min")) - 0.001 and x <= float(modifier.get("x_max")) + 0.001


func _modifier_key(lane_id: int, kind: StringName) -> String:
	return "%d|%s" % [lane_id, String(kind)]


func _on_game_tick(event_data: Variant) -> void:
	var expired: Array = []
	for key: Variant in _modifiers.keys():
		var modifier: Dictionary = _modifiers[key]
		var remaining := int(modifier.get("remaining_ticks", 0)) - 1
		if remaining <= 0:
			expired.append(key)
			continue
		modifier["remaining_ticks"] = remaining
		_modifiers[key] = modifier
	for key: Variant in expired:
		var modifier: Dictionary = _modifiers[key]
		_modifiers.erase(key)
		_last_emitted_x_min.erase(key)
		_emit_modifier_event(&"field.modifier_expired", modifier)


func _emit_modifier_event(event_name: StringName, modifier: Dictionary) -> void:
	var event_data: Variant = EventDataRef.create(null, null, 0, PackedStringArray(["field", "modifier", String(event_name.trim_prefix("field."))]))
	event_data.core["lane_id"] = int(modifier.get("lane_id", -1))
	event_data.core["kind"] = StringName(modifier.get("kind", StringName()))
	event_data.core["x_min"] = float(modifier.get("x_min", 0.0))
	event_data.core["x_max"] = float(modifier.get("x_max", 0.0))
	event_data.core["remaining_ticks"] = int(modifier.get("remaining_ticks", 0))
	EventBus.push_event(event_name, event_data)
