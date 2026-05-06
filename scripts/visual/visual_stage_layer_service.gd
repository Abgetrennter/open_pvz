extends Node
class_name VisualStageLayerService

const VisualLayerPolicyRef = preload("res://scripts/visual/visual_layer_policy.gd")

# ── Layer host mapping ──────────────────────────────────────────────

var _layer_hosts: Dictionary = {}  # layer_name (StringName) -> Node2D host
var _root: Node2D = null           # BattleVisualRoot


# ── Layer name to host node name mapping ────────────────────────────
# Some policy layers share a host node (e.g. plant + zombie → EntityLayer)

const _LAYER_TO_HOST := {
	&"ground": &"GroundLayer",
	&"shadow": &"ShadowLayer",
	&"field_object": &"FieldObjectLayer",
	&"plant": &"EntityLayer",
	&"zombie": &"EntityLayer",
	&"projectile": &"ProjectileLayer",
	&"world_fx": &"WorldFxLayer",
	&"fog_weather": &"FogWeatherLayer",
	&"preview": &"PreviewLayer",
	&"screen_fx": &"ScreenFxLayer",
	&"ui": &"UiLayer",
}

const _HOST_ORDER: PackedStringArray = [
	&"GroundLayer",
	&"ShadowLayer",
	&"FieldObjectLayer",
	&"EntityLayer",
	&"ProjectileLayer",
	&"WorldFxLayer",
	&"FogWeatherLayer",
	&"PreviewLayer",
	&"ScreenFxLayer",
	&"UiLayer",
]


# ── Public API ──────────────────────────────────────────────────────

func initialize(parent: Node2D) -> void:
	_root = Node2D.new()
	_root.name = "BattleVisualRoot"
	parent.add_child(_root)

	for host_name: StringName in _HOST_ORDER:
		var host: Node2D = Node2D.new()
		host.name = host_name
		_root.add_child(host)
		_layer_hosts[host_name] = host


func get_layer_host(layer_name: StringName) -> Node2D:
	var host_name: StringName = _LAYER_TO_HOST.get(layer_name, &"EntityLayer")
	var host: Node2D = _layer_hosts.get(host_name, null)
	return host


func apply_z_index(node: Node2D, entity_kind: StringName, lane_id: int, local_offset: int = 0) -> void:
	node.z_index = VisualLayerPolicyRef.resolve_z_index(entity_kind, lane_id, VisualLayerPolicyRef.get_layer_for_entity_kind(entity_kind), local_offset)


func apply_visual_preset(preset: Resource) -> void:
	if preset == null:
		return
	# v1: read and record preset fields, no full background system
	if DebugService.has_method("record_visual_event"):
		DebugService.record_visual_event({
			"cue_id": &"visual_preset_applied",
			"action_type": &"apply_visual_preset",
			"result": "recorded",
			"preset_class": preset.get_class(),
		})


func cleanup() -> void:
	for host: Variant in _layer_hosts.values():
		if host != null and is_instance_valid(host):
			host.queue_free()
	_layer_hosts.clear()
	if _root != null and is_instance_valid(_root):
		_root.queue_free()
	_root = null
