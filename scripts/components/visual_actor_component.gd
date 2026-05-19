extends Node
class_name VisualActorComponent


# ── Fields ──────────────────────────────────────────────────────────

var _owner: Node = null            # owning entity (BaseEntity)
var _profile_def: Resource = null  # VisualProfileDef
var _actor_root: Node2D = null     # instantiated actor scene
var _applied_damage_stages: Dictionary = {}  # stage_index -> true
var _flash_tween: Tween = null     # reserved for tween-based flash (v1 uses timer)
var _shadow_node: Node2D = null    # shadow node for projectile projection
var _is_projectile: bool = false   # cached: owner is projectile with projection

# Event subscription tracking
var _event_callables: Dictionary = {}


# ── Constants ───────────────────────────────────────────────────────

const EVENT_DAMAGED: StringName = &"entity.damaged"
const EVENT_DIED: StringName = &"entity.died"
const EVENT_STATE_ENTERED: StringName = &"entity.state_entered"


# ── Lifecycle ───────────────────────────────────────────────────────

func _exit_tree() -> void:
	_unsubscribe_all()


func shutdown() -> void:
	_unsubscribe_all()
	if _actor_root != null and is_instance_valid(_actor_root):
		_actor_root.queue_free()
	_actor_root = null
	if _shadow_node != null and is_instance_valid(_shadow_node):
		_shadow_node.queue_free()
	_shadow_node = null
	_applied_damage_stages.clear()
	_flash_tween = null
	_owner = null
	_profile_def = null
	_is_projectile = false


# ── Public API ──────────────────────────────────────────────────────

func bind_profile(profile_def: Resource, owner: Node) -> void:
	_unsubscribe_all()
	_owner = owner
	_profile_def = profile_def
	_applied_damage_stages.clear()

	if _profile_def == null:
		return

	# Instantiate actor scene if available
	if _profile_def.actor_scene != null:
		_actor_root = _profile_def.actor_scene.instantiate() as Node2D
		if _actor_root != null:
			_actor_root.name = "ActorRoot"
			add_child(_actor_root)
			_apply_profile_transform()

	# Subscribe to visual-relevant events
	_subscribe_event(EVENT_DAMAGED)
	_subscribe_event(EVENT_DIED)
	_subscribe_event(EVENT_STATE_ENTERED)

	# Detect projectile projection mode
	_is_projectile = _owner != null and StringName(_owner.get("entity_kind")) == &"projectile"
	_setup_shadow_for_projectile()

	play_state(&"idle")


func get_actor_root() -> Node2D:
	return _actor_root


func get_profile_def() -> Resource:
	return _profile_def


func get_profile_source() -> Dictionary:
	if _profile_def == null or not _profile_def.has_meta(&"asset_registry_source"):
		return {}
	var source: Variant = _profile_def.get_meta(&"asset_registry_source")
	if source is Dictionary:
		return Dictionary(source).duplicate(true)
	return {}


func play_animation(animation_name: StringName) -> bool:
	if animation_name == StringName():
		return false
	if _actor_root == null:
		return false

	var actor_result := _call_actor_method(&"play_animation", [animation_name])
	if bool(actor_result.get("handled", false)):
		return true

	var resolved_animation := _resolve_profile_animation_name(animation_name)
	var anim_player: AnimationPlayer = _find_animation_player()
	if anim_player == null:
		return false

	if not anim_player.has_animation(resolved_animation):
		return false

	anim_player.play(resolved_animation)
	return true


func play_state(state_id: StringName) -> bool:
	if state_id == StringName():
		return false

	var actor_result := _call_actor_method(&"play_state", [state_id])
	if bool(actor_result.get("handled", false)):
		return true

	if _profile_def == null:
		return false
	var state_anim_map := _get_profile_dictionary(&"state_animation_map")
	var animation_name := _lookup_string_name(state_anim_map, state_id)
	if animation_name == StringName():
		return false
	return play_animation(animation_name)


func play_action(action_id: StringName) -> bool:
	if action_id == StringName():
		return false

	var actor_result := _call_actor_method(&"play_action", [action_id])
	if bool(actor_result.get("handled", false)):
		return true

	var action_anim_map := _get_profile_dictionary(&"action_animation_map")
	var animation_name := _lookup_string_name(action_anim_map, action_id)
	if animation_name == StringName():
		animation_name = _resolve_profile_animation_name(action_id)
	if animation_name == StringName():
		animation_name = action_id
	return play_animation(animation_name)


func set_visual_speed(speed_scale: float) -> bool:
	if _actor_root == null:
		return false

	var actor_result := _call_actor_method(&"set_visual_speed", [speed_scale])
	if bool(actor_result.get("handled", false)):
		return true

	var anim_player: AnimationPlayer = _find_animation_player()
	if anim_player == null:
		return false
	anim_player.speed_scale = speed_scale
	return true


func get_anchor(anchor_name: StringName) -> Node2D:
	if anchor_name == StringName() or _actor_root == null:
		return null

	var actor_result := _call_actor_method(&"get_anchor", [anchor_name])
	if bool(actor_result.get("handled", false)):
		var result: Variant = actor_result.get("result", null)
		if result is Node2D:
			return result

	var direct := _actor_root.get_node_or_null(NodePath(String(anchor_name))) as Node2D
	if direct != null:
		return direct
	return _find_node2d_by_name(_actor_root, String(anchor_name))


# ── Event subscription ──────────────────────────────────────────────

func _subscribe_event(event_name: StringName) -> void:
	if _event_callables.has(event_name):
		return
	var callback := Callable(self, "_on_visual_event").bind(event_name)
	_event_callables[event_name] = callback
	EventBus.subscribe(event_name, callback)


func _unsubscribe_all() -> void:
	for event_name: Variant in _event_callables.keys():
		EventBus.unsubscribe(event_name, _event_callables[event_name])
	_event_callables.clear()


# ── Event handler ───────────────────────────────────────────────────

func _on_visual_event(event_data: Variant, event_name: StringName) -> void:
	if event_data == null:
		return
	if _owner == null or not is_instance_valid(_owner):
		return
	if not _event_targets_owner(event_data, event_name):
		return

	match event_name:
		EVENT_DAMAGED:
			_on_entity_damaged(event_data)
		EVENT_DIED:
			_on_entity_died(event_data)
		EVENT_STATE_ENTERED:
			_on_state_changed(event_data)


# ── Event filtering ─────────────────────────────────────────────────

func _event_targets_owner(event_data: Variant, event_name: StringName) -> bool:
	var core: Dictionary = event_data.core
	var owner_id: int = int(_owner.call("get_entity_id"))

	if event_name == EVENT_DAMAGED or event_name == EVENT_DIED:
		# These events target the damaged/dying entity
		var target_id: int = core.get("target_id", -1)
		return target_id == owner_id

	if event_name == EVENT_STATE_ENTERED:
		# State events: source is the entity entering the state
		var source_id: int = core.get("source_id", -1)
		return source_id == owner_id

	return false


# ── Damage handler ──────────────────────────────────────────────────

func _on_entity_damaged(event_data: Variant) -> void:
	if _owner == null or _profile_def == null:
		return

	var health_ratio: float = _get_owner_health_ratio()
	if health_ratio <= 0.0:
		return

	# Apply damage stages
	_apply_damage_stage(health_ratio)

	# Flash effect (simple modulate toggle)
	_flash_actor_damage()


func _get_owner_health_ratio() -> float:
	if _owner == null:
		return 1.0
	var health_component: Node = _owner.get_node_or_null("HealthComponent")
	if health_component == null:
		return 1.0
	var current: int = health_component.get("current_health")
	var maximum: int = health_component.get("max_health")
	if maximum <= 0:
		return 0.0
	return float(current) / float(maximum)


func _apply_damage_stage(health_ratio: float) -> void:
	if _profile_def == null:
		return

	var stages: Array[Dictionary] = _profile_def.damage_stage_defs
	if stages.is_empty():
		return

	# Sort by threshold_ratio descending (highest first = least damaged first)
	var sorted_stages: Array[Dictionary] = stages.duplicate(true)
	sorted_stages.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a.get("threshold_ratio", 0.0)) > float(b.get("threshold_ratio", 0.0))
	)

	for i: int in range(sorted_stages.size()):
		if _applied_damage_stages.has(i):
			continue
		var stage: Dictionary = sorted_stages[i]
		var threshold: float = float(stage.get("threshold_ratio", 0.0))
		if health_ratio > threshold:
			continue

		# Apply this stage
		_applied_damage_stages[i] = true
		_apply_single_damage_stage(stage)


func _apply_single_damage_stage(stage: Dictionary) -> void:
	if _actor_root == null:
		return

	# Modulate change
	if stage.has("modulate"):
		_actor_root.modulate = stage["modulate"]

	# Show/hide child nodes
	var show_nodes: Variant = stage.get("show_child_nodes", [])
	if show_nodes is Array:
		for child_name: String in show_nodes:
			var child: Node = _actor_root.get_node_or_null(NodePath(child_name))
			if child != null and (child is Node2D or child is Control):
				child.set("visible", true)

	var hide_nodes: Variant = stage.get("hide_child_nodes", [])
	if hide_nodes is Array:
		for child_name: String in hide_nodes:
			var child: Node = _actor_root.get_node_or_null(NodePath(child_name))
			if child != null and (child is Node2D or child is Control):
				child.set("visible", false)

	# FX spawn request — v1 log only
	if stage.has("fx_id"):
		if DebugService.has_method("record_visual_event"):
			DebugService.record_visual_event({
				"cue_id": &"damage_stage",
				"event_name": EVENT_DAMAGED,
				"action_type": &"spawn_fx",
				"target_id": _owner.get_entity_id(),
				"result": "no_op",
				"skip_reason": "damage stage FX spawn not yet implemented",
		})


# ── Projectile projection tracking ──────────────────────────────────

func _process(_delta: float) -> void:
	if not _is_projectile or _owner == null or not is_instance_valid(_owner):
		return
	if _shadow_node == null:
		return
	# Shadow follows ground_position
	var ground_pos: Vector2 = _owner.call("get_ground_position")
	_shadow_node.global_position = ground_pos


func _setup_shadow_for_projectile() -> void:
	if not _is_projectile:
		return
	if _profile_def == null:
		return
	# Check shadow_policy
	var shadow_policy: Dictionary = _profile_def.shadow_policy
	var shadow_enabled: bool = shadow_policy.get("enabled", true) if shadow_policy is Dictionary else true
	if not shadow_enabled:
		return
	# Create shadow placeholder node (v1: simple ellipse)
	_shadow_node = Node2D.new()
	_shadow_node.name = "ShadowAnchor"
	add_child(_shadow_node)
	# Shadow draws a simple ellipse via _draw on a separate control is overkill;
	# v1: shadow is just a position tracker, visual TBD when actor scenes exist


func _flash_actor_damage() -> void:
	if _actor_root == null:
		return

	var flash_color := Color.WHITE
	var flash_duration := 0.08

	var original_modulate: Color = _actor_root.modulate
	_actor_root.modulate = flash_color

	var tree := _actor_root.get_tree()
	if tree != null:
		tree.create_timer(flash_duration).timeout.connect(
			_restore_modulate.bind(_actor_root, original_modulate),
			CONNECT_ONE_SHOT
		)


func _restore_modulate(target: Node2D, original_modulate: Color) -> void:
	if is_instance_valid(target):
		target.modulate = original_modulate


# ── Death handler ───────────────────────────────────────────────────

func _on_entity_died(_event_data: Variant) -> void:
	if _actor_root == null:
		return

	# v1: simple fade — reduce modulate alpha
	var tween := create_tween()
	if tween != null:
		tween.tween_property(_actor_root, "modulate:a", 0.0, 0.5)


# ── State handler ───────────────────────────────────────────────────

func _on_state_changed(event_data: Variant) -> void:
	if _profile_def == null:
		return

	var state_id: StringName = event_data.core.get("state_id", StringName())
	if state_id == StringName():
		return

	play_state(state_id)


func _apply_profile_transform() -> void:
	if _actor_root == null or _profile_def == null:
		return

	var default_scale_value: Variant = _profile_def.get("default_scale")
	if default_scale_value is Vector2:
		_actor_root.scale *= default_scale_value

	var ground_offset_value: Variant = _profile_def.get("ground_offset")
	if ground_offset_value is Vector2:
		_actor_root.position += ground_offset_value


func _call_actor_method(method_name: StringName, args: Array) -> Dictionary:
	if _actor_root == null:
		return {"handled": false, "result": null}
	if not _actor_root.has_method(method_name):
		return {"handled": false, "result": null}

	var result: Variant = _actor_root.callv(method_name, args)
	if result is bool:
		return {"handled": bool(result), "result": result}
	return {"handled": true, "result": result}


func _resolve_profile_animation_name(animation_name: StringName) -> StringName:
	if animation_name == StringName():
		return StringName()
	var animation_map := _get_profile_dictionary(&"animation_map")
	return _lookup_string_name(animation_map, animation_name, animation_name)


func _lookup_string_name(values: Dictionary, key: StringName, fallback: StringName = StringName()) -> StringName:
	if values.is_empty():
		return fallback
	if values.has(key):
		return _variant_to_string_name(values[key])
	var string_key := String(key)
	if values.has(string_key):
		return _variant_to_string_name(values[string_key])
	return fallback


func _variant_to_string_name(value: Variant) -> StringName:
	if value == null:
		return StringName()
	if value is StringName:
		return value
	return StringName(str(value))


func _get_profile_dictionary(property_name: StringName) -> Dictionary:
	if _profile_def == null:
		return {}
	var value: Variant = _profile_def.get(property_name)
	if value is Dictionary:
		return value
	return {}


func _find_animation_player() -> AnimationPlayer:
	if _actor_root == null:
		return null

	# Direct child first
	var direct: Node = _actor_root.get_node_or_null("AnimationPlayer")
	if direct != null and direct is AnimationPlayer:
		return direct

	# Recursive search (shallow)
	for child: Node in _actor_root.get_children():
		if child is AnimationPlayer:
			return child

	return null


func _find_node2d_by_name(root: Node, node_name: String) -> Node2D:
	if root == null:
		return null
	for child: Node in root.get_children():
		if child is Node2D and child.name == node_name:
			return child
		var found := _find_node2d_by_name(child, node_name)
		if found != null:
			return found
	return null
