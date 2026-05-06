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

	# Subscribe to visual-relevant events
	_subscribe_event(EVENT_DAMAGED)
	_subscribe_event(EVENT_DIED)
	_subscribe_event(EVENT_STATE_ENTERED)

	# Detect projectile projection mode
	_is_projectile = _owner != null and StringName(_owner.get("entity_kind")) == &"projectile"
	_setup_shadow_for_projectile()


func get_actor_root() -> Node2D:
	return _actor_root


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

	var state_anim_map: Dictionary = _profile_def.state_animation_map
	if state_anim_map.is_empty():
		return

	var animation_name: StringName = state_anim_map.get(state_id, StringName())
	if animation_name == StringName():
		return

	_play_animation(animation_name)


func _play_animation(animation_name: StringName) -> void:
	if _actor_root == null:
		return

	var anim_player: AnimationPlayer = _find_animation_player()
	if anim_player == null:
		return

	if anim_player.has_animation(StringName(animation_name)):
		anim_player.play(StringName(animation_name))


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
