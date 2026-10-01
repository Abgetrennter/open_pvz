extends "res://scripts/core/registry/registry_base.gd"

const EventDataRef = preload("res://scripts/core/runtime/event_data.gd")
const MovementDefRef = preload("res://scripts/core/defs/movement_def.gd")

const EXTENSION_MOVEMENT_DIR := "data/combat/movements"

var _movement_strategies: Dictionary = {}
var _movement_strategy_owners: Dictionary = {}


func _make_registry_config():
	return RegistryConfigRef.create(
		&"movement",
		MovementDefRef,
		&"movement",
		EXTENSION_MOVEMENT_DIR,
		&"trusted_runtime",
		&"core.walk",
		false
	)


func _on_registry_cleared() -> void:
	_movement_strategies.clear()
	_movement_strategy_owners.clear()


func _register_builtin_defs() -> void:
	var walk_def = MovementDefRef.new()
	walk_def.id = &"core.walk"
	register_def(walk_def, {"kind": &"core", "source": &"core"})

	var leap_def = MovementDefRef.new()
	leap_def.id = &"core.leap_once"
	register_def(leap_def, {"kind": &"core", "source": &"core"})

	var tunnel_def = MovementDefRef.new()
	tunnel_def.id = &"core.tunnel"
	register_def(tunnel_def, {"kind": &"core", "source": &"core"})

	var hop_cycle_def = MovementDefRef.new()
	hop_cycle_def.id = &"core.hop_cycle"
	register_def(hop_cycle_def, {"kind": &"core", "source": &"core"})

	var drive_def = MovementDefRef.new()
	drive_def.id = &"core.drive"
	register_def(drive_def, {"kind": &"core", "source": &"core"})

	var climb_def = MovementDefRef.new()
	climb_def.id = &"core.climb_once"
	register_def(climb_def, {"kind": &"core", "source": &"core"})
	_register_builtin_strategies()


func build_command(movement_id: StringName, owner: Node, spec: Dictionary, delta: float, blackboard: Dictionary = {}) -> Dictionary:
	var strategy: Callable = _movement_strategies.get(movement_id, Callable())
	if not strategy.is_valid():
		return {}
	return Dictionary(strategy.call(owner, spec, delta, blackboard))


func _validate_def_specific(movement_def: Resource, source: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	if bool(source.get("extension", false)):
		if movement_def.strategy_script == null or not (movement_def.strategy_script is Script):
			errors.append("MovementDef %s strategy_script must be a Script." % String(movement_def.id))
		else:
			var strategy_owner = movement_def.strategy_script.new()
			if strategy_owner == null or not strategy_owner.has_method("build_command"):
				errors.append("MovementDef %s strategy_script must expose build_command(owner, spec, delta, blackboard)." % String(movement_def.id))
	return errors


func _on_def_registered(entry: Dictionary) -> void:
	var source: Dictionary = Dictionary(entry.get("source", {}))
	if not bool(source.get("extension", false)):
		return
	var movement_def = entry.get("def", null)
	if movement_def == null or movement_def.strategy_script == null:
		return
	var strategy_owner = movement_def.strategy_script.new()
	if strategy_owner == null or not strategy_owner.has_method("build_command"):
		return
	_movement_strategy_owners[movement_def.id] = strategy_owner
	_movement_strategies[movement_def.id] = Callable(strategy_owner, "build_command")


func _register_builtin_strategies() -> void:
	_movement_strategies[&"core.walk"] = func(owner: Node, spec: Dictionary, _delta: float, _blackboard: Dictionary) -> Dictionary:
		var params: Dictionary = Dictionary(spec.get("params", {}))
		var fallback_speed := float(params.get("move_speed", 55.0))
		var move_speed := _resolve_slots_speed(owner, params, "move_speed_slots_per_sec", fallback_speed)
		var direction := Vector2(params.get("direction", Vector2.LEFT))
		if direction.length_squared() <= 0.0001:
			direction = Vector2.LEFT
		var exposure_state := StringName(params.get("exposure_state", &"ground"))
		var pause_reason := StringName()
		# Position hold (original Catapult semantics): stop advancing once
		# the owner reaches stop_x (de-pvz mPosX <= 650 firing line).
		# Expressed as movement params instead of a controller special case.
		if params.has("stop_x") and owner != null and owner is Node2D:
			var stop_x := float(params.get("stop_x"))
			var reached_stop: bool = (direction.x < 0.0 and owner.position.x <= stop_x) or (direction.x > 0.0 and owner.position.x >= stop_x)
			if reached_stop:
				move_speed = 0.0
				pause_reason = &"position_hold"
		# Ice trail halves walking speed (original GetSpeedModifier); vehicles
		# are exempt and the field state owns the lane-interval query.
		move_speed *= _field_speed_scale(owner)
		var ground_contact := bool(params.get("ground_contact", exposure_state != &"flying" and exposure_state != &"airborne"))
		return {
			"source_id": &"movement:core.walk",
			"command_kind": &"base",
			"ground_velocity": direction.normalized() * move_speed,
			"ground_contact": ground_contact,
			"exposure_state": exposure_state,
			"interruptible": true,
			"pause_reason": pause_reason,
		}

	_movement_strategies[&"core.leap_once"] = func(owner: Node, spec: Dictionary, _delta: float, blackboard: Dictionary) -> Dictionary:
		var params: Dictionary = Dictionary(spec.get("params", {}))
		var fallback_speed := float(params.get("move_speed", 80.0))
		var move_speed := _resolve_slots_speed(owner, params, "leap_speed_slots_per_sec", _resolve_slots_speed(owner, params, "move_speed_slots_per_sec", fallback_speed))
		var direction := Vector2(params.get("direction", Vector2.LEFT))
		if direction.length_squared() <= 0.0001:
			direction = Vector2.LEFT
		var height := 0.0
		var ground_contact := true
		if owner != null and owner.has_method("get_height"):
			height = float(owner.call("get_height"))
		if owner != null and owner.has_method("is_ground_contact"):
			ground_contact = bool(owner.call("is_ground_contact"))
		# Vault speed from the landing formula (original Pole Vaulter, de-pvz
		# Zombie.cpp:1671-1686: mVelX = (mX - plantX - 80) / animDuration, then
		# :1711-1715 shifts the landing -150 once the jump animation completes,
		# netting a landing fixed distance past the vaulted plant).
		var vault_speed := float(blackboard.get("vault_speed_px", 0.0))
		if vault_speed > 0.0:
			move_speed = vault_speed
		if bool(blackboard.get("landed", false)):
			return {
				"source_id": &"movement:core.leap_once",
				"command_kind": &"base",
				"ground_velocity": direction.normalized() * move_speed,
				"ground_contact": true,
				"exposure_state": &"ground",
				"interruptible": true,
				"pause_reason": StringName(),
			}
		if bool(blackboard.get("started", false)):
			# Vault blocking (original Tall-nut semantics): while mid-leap, a
			# blocker whose tags intersect vault_block_tags interrupts the leap
			# and the vaulter lands in front of it (de-pvz PHASE_POLEVAULTER_IN_VAULT
			# Tall-nut bonk, DOLPHIN_IN_JUMP and POGO FORWARD_BOUNCE variants).
			var blocker := _find_vault_blocker(owner, params, direction)
			if blocker != null:
				blackboard["landed"] = true
				if params.get("blocked_landing_movement", null) is Dictionary and owner != null and owner.has_method("set_movement_spec"):
					owner.call("set_movement_spec", Dictionary(params.get("blocked_landing_movement")).duplicate(true))
				return {
					"source_id": &"movement:core.leap_once",
					"command_kind": &"base",
					"ground_velocity": Vector2.ZERO,
					"ground_contact": false,
					"exposure_state": &"airborne",
					"gravity": float(params.get("gravity", -520.0)),
					"interruptible": true,
					"pause_reason": &"vault_blocked",
				}
			if ground_contact and height <= 0.001:
				blackboard["landed"] = true
				if params.get("post_landing_movement", null) is Dictionary and owner != null and owner.has_method("set_movement_spec"):
					owner.call("set_movement_spec", Dictionary(params.get("post_landing_movement")).duplicate(true))
				return {
					"source_id": &"movement:core.leap_once",
					"command_kind": &"base",
					"ground_velocity": direction.normalized() * move_speed,
					"ground_contact": true,
					"exposure_state": &"ground",
					"interruptible": true,
					"pause_reason": StringName(),
				}
		# Pre-vault approach run (original PHASE_POLEVAULTER_PRE_VAULT): walk at
		# normal speed until the first vaultable target enters scan range, then
		# start the leap with a horizontal speed that lands the arc a fixed
		# distance past that target. Specs without vault_trigger_tags keep the
		# legacy spawn-time leap (dolphin). vault_trigger_after_x gates the
		# scan behind a position line (original dolphin enters the pool near
		# mX 700-720 before hunting plants, de-pvz Zombie.cpp:1762-1813), with
		# an optional slower ride speed once past the line.
		var trigger_tags := PackedStringArray(params.get("vault_trigger_tags", PackedStringArray()))
		if not bool(blackboard.get("started", false)) and not trigger_tags.is_empty():
			var scanning := true
			if params.has("vault_trigger_after_x") and owner is Node2D:
				var trigger_x := float(params.get("vault_trigger_after_x"))
				scanning = (owner.position.x <= trigger_x) if direction.x < 0.0 else (owner.position.x >= trigger_x)
			var approach_speed := _resolve_slots_speed(owner, params, "move_speed_slots_per_sec", fallback_speed)
			if params.has("pre_leap_ride_speed_slots_per_sec") and not scanning:
				approach_speed = _resolve_slots_speed(owner, params, "pre_leap_ride_speed_slots_per_sec", 0.3 * 96.0)
			var vault_target: Node = _find_vault_target(owner, params, direction) if scanning else null
			if vault_target == null:
				# Approach run at the walking range (original PRE_VAULT runs at
				# 0.66-0.68), never at the vaulting leap speed.
				return {
					"source_id": &"movement:core.leap_once",
					"command_kind": &"base",
					"ground_velocity": direction.normalized() * approach_speed,
					"ground_contact": true,
					"exposure_state": &"ground",
					"interruptible": true,
					"pause_reason": StringName(),
				}
			var jump_velocity := float(params.get("jump_velocity", 220.0))
			var gravity := absf(float(params.get("gravity", -520.0)))
			var air_time := 2.0 * jump_velocity / maxf(gravity, 1.0)
			var landing_beyond := float(params.get("vault_landing_beyond_px", 70.0))
			var landing_x := (vault_target as Node2D).position.x + direction.x * landing_beyond
			# Ground to cover from takeoff to the landing point, positive in
			# the movement direction (owner starts up-range of the landing).
			var travel := (landing_x - (owner as Node2D).position.x) * direction.x
			blackboard["vault_speed_px"] = maxf(travel, 1.0) / maxf(air_time, 0.01)
			move_speed = float(blackboard["vault_speed_px"])
			# Fall through to the airborne command; the tail below owns the
			# started flag so the takeoff frame still injects height_velocity.
		var command := {
			"source_id": &"movement:core.leap_once",
			"command_kind": &"base",
			"ground_velocity": direction.normalized() * move_speed,
			"ground_contact": false,
			"exposure_state": &"airborne",
			"gravity": float(params.get("gravity", -520.0)),
			"interruptible": false,
			"pause_reason": StringName(),
		}
		if not bool(blackboard.get("started", false)):
			blackboard["started"] = true
			command["height_velocity"] = float(params.get("jump_velocity", 220.0))
		return command

	_movement_strategies[&"core.climb_once"] = func(owner: Node, spec: Dictionary, _delta: float, blackboard: Dictionary) -> Dictionary:
		# Ladder climb-over (original UpdateClimbingLadder semantics): constant
		# ascent at climb_speed with slight forward drift while below the wall
		# top, then gravity takes over past climb_height (HEIGHT_FALLING) until
		# ground contact, where post_climb_movement resumes normal walking.
		var params: Dictionary = Dictionary(spec.get("params", {}))
		var drift_speed := _resolve_slots_speed(owner, params, "climb_drift_slots_per_sec", 50.0)
		var climb_speed := _resolve_slots_speed(owner, params, "climb_speed_slots_per_sec", 80.0)
		var climb_height := _resolve_slots_distance(params, "climb_height_slots", 90.0)
		var direction := Vector2(params.get("direction", Vector2.LEFT))
		if direction.length_squared() <= 0.0001:
			direction = Vector2.LEFT
		var height := 0.0
		var ground_contact := true
		if owner != null and owner.has_method("get_height"):
			height = float(owner.call("get_height"))
		if owner != null and owner.has_method("is_ground_contact"):
			ground_contact = bool(owner.call("is_ground_contact"))
		if bool(blackboard.get("landed", false)):
			if params.get("post_climb_movement", null) is Dictionary and owner != null and owner.has_method("set_movement_spec"):
				owner.call("set_movement_spec", Dictionary(params.get("post_climb_movement")).duplicate(true))
			return {
				"source_id": &"movement:core.climb_once",
				"command_kind": &"base",
				"ground_velocity": direction.normalized() * _resolve_slots_speed(owner, params, "move_speed_slots_per_sec", drift_speed),
				"ground_contact": true,
				"exposure_state": &"ground",
				"interruptible": true,
				"pause_reason": StringName(),
			}
		if ground_contact and height <= 0.001 and bool(blackboard.get("started", false)):
			blackboard["landed"] = true
			return {
				"source_id": &"movement:core.climb_once",
				"command_kind": &"base",
				"ground_velocity": direction.normalized() * drift_speed,
				"ground_contact": true,
				"exposure_state": &"ground",
				"interruptible": true,
				"pause_reason": StringName(),
			}
		blackboard["started"] = true
		var command := {
			"source_id": &"movement:core.climb_once",
			"command_kind": &"base",
			"ground_velocity": direction.normalized() * drift_speed,
			"ground_contact": false,
			"exposure_state": &"airborne",
			"interruptible": false,
			"pause_reason": StringName(),
		}
		if height >= climb_height:
			# Wall top reached: stop thrusting and let gravity finish the arc.
			command["gravity"] = float(params.get("gravity", -520.0))
		else:
			command["height_velocity"] = climb_speed
			command["gravity"] = 0.0
		return command

	_movement_strategies[&"core.tunnel"] = func(_owner: Node, spec: Dictionary, _delta: float, _blackboard: Dictionary) -> Dictionary:
		var params: Dictionary = Dictionary(spec.get("params", {}))
		var fallback_speed := float(params.get("move_speed", 80.0))
		var move_speed := _resolve_slots_speed(owner, params, "move_speed_slots_per_sec", fallback_speed)
		var direction := Vector2(params.get("direction", Vector2.LEFT))
		if direction.length_squared() <= 0.0001:
			direction = Vector2.LEFT
		return {
			"source_id": &"movement:core.tunnel",
			"command_kind": &"base",
			"ground_velocity": direction.normalized() * move_speed,
			"ground_contact": true,
			"exposure_state": StringName(params.get("exposure_state", &"underground")),
			"interruptible": true,
			"pause_reason": StringName(),
		}

	_movement_strategies[&"core.hop_cycle"] = func(owner: Node, spec: Dictionary, delta: float, blackboard: Dictionary) -> Dictionary:
		var params: Dictionary = Dictionary(spec.get("params", {}))
		var fallback_speed := float(params.get("move_speed", 70.0))
		var move_speed := _resolve_slots_speed(owner, params, "move_speed_slots_per_sec", fallback_speed)
		var direction := Vector2(params.get("direction", Vector2.LEFT))
		if direction.length_squared() <= 0.0001:
			direction = Vector2.LEFT
		var height := 0.0
		var ground_contact := true
		if owner != null and owner.has_method("get_height"):
			height = float(owner.call("get_height"))
		if owner != null and owner.has_method("is_ground_contact"):
			ground_contact = bool(owner.call("is_ground_contact"))
		var cooldown := maxf(float(blackboard.get("hop_cooldown", 0.0)) - delta, 0.0)
		blackboard["hop_cooldown"] = cooldown
		var command := {
			"source_id": &"movement:core.hop_cycle",
			"command_kind": &"base",
			"ground_velocity": direction.normalized() * move_speed,
			"ground_contact": ground_contact,
			"exposure_state": &"airborne" if not ground_contact or height > 0.001 else &"ground",
			"gravity": float(params.get("gravity", -520.0)),
			"interruptible": true,
			"pause_reason": StringName(),
		}
		if ground_contact and height <= 0.001 and cooldown <= 0.0:
			command["ground_contact"] = false
			command["exposure_state"] = &"airborne"
			command["height_velocity"] = float(params.get("jump_velocity", 160.0))
			blackboard["hop_cooldown"] = maxf(float(params.get("hop_interval", 0.7)), 0.05)
		return command

	_movement_strategies[&"core.drive"] = func(owner: Node, spec: Dictionary, _delta: float, _blackboard: Dictionary) -> Dictionary:
		var params: Dictionary = Dictionary(spec.get("params", {}))
		var fallback_speed := float(params.get("move_speed", 45.0))
		var move_speed := _resolve_slots_speed(owner, params, "move_speed_slots_per_sec", fallback_speed)
		var direction := Vector2(params.get("direction", Vector2.LEFT))
		if direction.length_squared() <= 0.0001:
			direction = Vector2.LEFT
		# Progressive deceleration (original Zamboni semantics): speed scales
		# linearly toward decel_min_slots_per_sec while approaching the far
		# side (de-pvz UpdateZamboni: 0.25 -> 0.05 between x 700 -> 300).
		if params.has("decel_start_x") and owner != null and owner is Node2D:
			var decel_start_x := float(params.get("decel_start_x"))
			var decel_end_x := float(params.get("decel_end_x", 300.0))
			var min_speed := _resolve_slots_speed(owner, params, "decel_min_slots_per_sec", 0.05 * 96.0)
			if direction.x < 0.0 and owner.position.x <= decel_start_x:
				var span := maxf(decel_start_x - decel_end_x, 1.0)
				var t := clampf((decel_start_x - owner.position.x) / span, 0.0, 1.0)
				move_speed = lerpf(move_speed, min_speed, t)
		# Field-terrain vehicle interactions (original Zamboni/Bobsled):
		# lay_ice_trail extends the lane interval under the vehicle as it
		# drives (de-pvz UpdateZamboni mIceMinX advance, 3000-tick renewal);
		# ice_renewal_ticks only refreshes an EXISTING trail's timer (de-pvz
		# UpdateZombieBobsled mIceTimer = max(500, m)); a sled past the ice's
		# left edge takes off_ice_damage_per_tick per step until the sled
		# layer breaks (de-pvz TakeDamage(6, ...) once mPosX+10 < mIceMinX).
		if owner != null and owner is Node2D:
			var field := _get_field_state()
			if field != null:
				var lane_value: Variant = owner.get("lane_id")
				var lane_id := int(lane_value) if lane_value is int else -1
				if lane_id >= 0:
					if bool(params.get("lay_ice_trail", false)):
						var pad := maxf(move_speed * maxf(_delta, 0.0), 2.0) + 2.0
						var entity_id := int(owner.get("entity_id")) if owner.get("entity_id") is int else -1
						field.call("apply_modifier", lane_id, &"ice_trail", owner.position.x - pad, owner.position.x + pad, int(params.get("ice_trail_duration_ticks", 3000)), entity_id)
					if params.has("ice_renewal_ticks"):
						field.call("renew_lane_modifier", lane_id, &"ice_trail", int(params.get("ice_renewal_ticks", 500)))
					if params.has("off_ice_damage_per_tick"):
						var ice_x_min := float(field.call("lane_modifier_x_min", lane_id, &"ice_trail"))
						var check_offset := float(params.get("off_ice_check_offset_px", 10.0))
						var off_ice: bool = (not is_finite(ice_x_min)) or owner.position.x + check_offset < ice_x_min
						if off_ice and owner.has_method("take_damage"):
							owner.call("take_damage", int(params.get("off_ice_damage_per_tick", 6)), owner, PackedStringArray(["ice_grind", "vehicle"]))
		return {
			"source_id": &"movement:core.drive",
			"command_kind": &"base",
			"ground_velocity": direction.normalized() * move_speed,
			"ground_contact": true,
			"exposure_state": &"ground",
			"interruptible": false,
			"pause_reason": StringName(),
		}


func _resolve_slots_speed(owner: Node, params: Dictionary, slots_key: String, default_world_per_sec: float) -> float:
	# Range keys (original PickRandomSpeed) resolve to one deterministic
	# per-entity sample before unit conversion; see GameState.resolve_ranged_value.
	var sampled: Variant = GameState.resolve_ranged_value(owner, params, slots_key)
	if sampled != null:
		params = {slots_key: float(sampled)}
	var metrics := _get_battlefield_metrics()
	if metrics != null and metrics.has_method("resolve_slots_speed"):
		return float(metrics.call("resolve_slots_speed", params, slots_key, default_world_per_sec))
	if params.has(slots_key):
		return float(params.get(slots_key)) * 96.0
	return default_world_per_sec


func _resolve_slots_distance(params: Dictionary, slots_key: String, default_world: float) -> float:
	var metrics := _get_battlefield_metrics()
	if metrics != null and metrics.has_method("resolve_slots_distance"):
		return float(metrics.call("resolve_slots_distance", params, slots_key, default_world))
	if params.has(slots_key):
		return float(params.get(slots_key)) * 96.0
	return default_world


func _get_battlefield_metrics() -> RefCounted:
	if GameState.current_battle == null:
		return null
	if not GameState.current_battle.has_method("get_battlefield_metrics"):
		return null
	var metrics: Variant = GameState.current_battle.call("get_battlefield_metrics")
	return metrics if metrics is RefCounted else null


func _get_field_state() -> Node:
	if GameState.current_battle == null:
		return null
	if not GameState.current_battle.has_method("get_field_state"):
		return null
	var field: Variant = GameState.current_battle.call("get_field_state")
	return field if field is Node else null


func _field_speed_scale(owner: Node) -> float:
	# Terrain speed factor from the row-interval field state (ice halves
	# walkers, vehicles exempt); 1.0 whenever no battle/field state exists.
	if owner == null or not (owner is Node2D):
		return 1.0
	var field := _get_field_state()
	if field == null or not field.has_method("get_ice_trail_speed_scale"):
		return 1.0
	var lane_value: Variant = owner.get("lane_id")
	if not (lane_value is int) or int(lane_value) < 0:
		return 1.0
	var tags_value: Variant = owner.get("tags")
	var tags := PackedStringArray(tags_value) if tags_value is PackedStringArray or tags_value is Array else PackedStringArray()
	return float(field.call("get_ice_trail_speed_scale", int(lane_value), owner.position.x, tags))


func _find_vault_blocker(owner: Node, params: Dictionary, direction: Vector2) -> Node:
	# Tag-driven vault blocking (no entity-specific branches): returns the
	# nearest candidate ahead of the owner whose tags intersect
	# vault_block_tags, or null when nothing blocks the leap.
	var block_tags := PackedStringArray(params.get("vault_block_tags", PackedStringArray()))
	if block_tags.is_empty() or owner == null or not (owner is Node2D):
		return null
	if GameState.current_battle == null or not GameState.current_battle.has_method("spatial_query"):
		return null
	var scan_range := float(params.get("vault_scan_range", 60.0))
	var owner_position: Vector2 = owner.position
	var query := {
		"team_exclude": StringName(owner.get("team")),
		"center": owner_position,
		"radius": scan_range,
		"filter": func(candidate):
			if candidate == owner or not (candidate is Node2D):
				return false
			if not candidate.has_method("is_targetable") or not bool(candidate.call("is_targetable")):
				return false
			var candidate_tags: Variant = candidate.get("tags")
			if not (candidate_tags is PackedStringArray or candidate_tags is Array):
				return false
			var tag_set := PackedStringArray(candidate_tags)
			for block_tag: String in block_tags:
				if tag_set.has(block_tag):
					return true
			return false,
		"sort_by_distance": true,
		"max_results": 1,
	}
	if direction.x < 0.0:
		query["x_max"] = owner_position.x + 8.0
	else:
		query["x_min"] = owner_position.x - 8.0
	var results: Array = GameState.current_battle.call("spatial_query", query)
	return null if results.is_empty() else results[0]


func _find_vault_target(owner: Node, params: Dictionary, direction: Vector2) -> Node:
	# Pre-vault scan (original FindPlantTarget(ATTACKTYPE_VAULT)): the nearest
	# living target ahead whose tags intersect vault_trigger_tags; spiky ground
	# plants are not vaultable, and a slot carrying a ladder defers to the climb
	# path instead of vaulting (de-pvz UpdateZombiePolevaulter GetLadderAt).
	var trigger_tags := PackedStringArray(params.get("vault_trigger_tags", PackedStringArray()))
	if trigger_tags.is_empty() or owner == null or not (owner is Node2D):
		return null
	if GameState.current_battle == null or not GameState.current_battle.has_method("spatial_query"):
		return null
	var exclude_tags := PackedStringArray(params.get("vault_trigger_exclude_tags", PackedStringArray()))
	var scan_range := float(params.get("vault_trigger_scan_range", 96.0))
	var owner_position: Vector2 = owner.position
	var owner_lane := int(owner.get("lane_id")) if owner.get("lane_id") is int else -1
	var query := {
		"team_exclude": StringName(owner.get("team")),
		"center": owner_position,
		"radius": scan_range,
		"filter": func(candidate):
			if candidate == owner or not (candidate is Node2D):
				return false
			if not candidate.has_method("is_targetable") or not bool(candidate.call("is_targetable")):
				return false
			if owner_lane >= 0 and int(candidate.get("lane_id")) != owner_lane:
				return false
			# Fading corpses still answer spatial queries; vault only over
			# living targets (original FindPlantTarget skips dead plants).
			if candidate.has_node("HealthComponent"):
				var candidate_health: Variant = candidate.get_node("HealthComponent").get("current_health")
				if candidate_health is int and int(candidate_health) <= 0:
					return false
			var candidate_tags: Variant = candidate.get("tags")
			if not (candidate_tags is PackedStringArray or candidate_tags is Array):
				return false
			var tag_set := PackedStringArray(candidate_tags)
			var matches := false
			for trigger_tag: String in trigger_tags:
				if tag_set.has(trigger_tag):
					matches = true
					break
			if not matches:
				return false
			for exclude_tag: String in exclude_tags:
				if tag_set.has(exclude_tag):
					return false
			return true,
		"sort_by_distance": true,
		"max_results": 1,
	}
	if direction.x < 0.0:
		query["x_max"] = owner_position.x + 8.0
	else:
		query["x_min"] = owner_position.x - 8.0
	var results: Array = GameState.current_battle.call("spatial_query", query)
	if results.is_empty():
		return null
	var target: Node = results[0]
	if _slot_has_ladder(target):
		return null
	return target


func _slot_has_ladder(target: Node) -> bool:
	var battle = GameState.current_battle
	if battle == null:
		return false
	if not battle.has_method("get_battlefield_metrics") or not battle.has_method("get_grid_item_state"):
		return false
	var metrics: Variant = battle.call("get_battlefield_metrics")
	var grid_item_state: Variant = battle.call("get_grid_item_state")
	if metrics == null or not metrics.has_method("world_to_slot_index"):
		return false
	if grid_item_state == null or not grid_item_state.has_method("get_grid_item_at"):
		return false
	var lane_id := int(target.get("lane_id")) if target.get("lane_id") is int else -1
	if lane_id < 0:
		return false
	var slot_index := int(metrics.call("world_to_slot_index", (target as Node2D).position.x))
	var item: Node = grid_item_state.call("get_grid_item_at", lane_id, slot_index)
	if item == null or not is_instance_valid(item):
		return false
	return PackedStringArray(item.get("tags")).has("ladder_grid_item")
