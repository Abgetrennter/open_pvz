extends CanvasLayer
class_name DebugOverlay

const REFRESH_INTERVAL := 0.15
const MAX_EVENT_LINES := 6
const MAX_TRIGGER_LINES := 4
const MAX_EFFECT_LINES := 4

var battle_root: Node = null
var _refresh_accumulator := 0.0
var _panel: PanelContainer = null
var _summary_label: Label = null
var _events_label: RichTextLabel = null
var _triggers_label: RichTextLabel = null
var _effects_label: RichTextLabel = null


func _ready() -> void:
	layer = 10
	_build_ui()
	_refresh_text()


func _process(delta: float) -> void:
	_refresh_accumulator += delta
	if _refresh_accumulator < REFRESH_INTERVAL:
		return

	_refresh_accumulator = 0.0
	_refresh_text()


func bind_battle_root(node: Node) -> void:
	battle_root = node
	_refresh_text()


func _build_ui() -> void:
	_panel = PanelContainer.new()
	_panel.size = Vector2(340.0, 300.0)
	_panel.position = _panel_position()
	add_child(_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 8)
	_panel.add_child(margin)

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 6)
	margin.add_child(layout)

	_summary_label = Label.new()
	_summary_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	layout.add_child(_summary_label)

	_events_label = RichTextLabel.new()
	_events_label.fit_content = true
	_events_label.scroll_active = false
	_events_label.bbcode_enabled = false
	layout.add_child(_events_label)

	_triggers_label = RichTextLabel.new()
	_triggers_label.fit_content = true
	_triggers_label.scroll_active = false
	_triggers_label.bbcode_enabled = false
	layout.add_child(_triggers_label)

	_effects_label = RichTextLabel.new()
	_effects_label.fit_content = true
	_effects_label.scroll_active = false
	_effects_label.bbcode_enabled = false
	layout.add_child(_effects_label)


func _refresh_text() -> void:
	if _summary_label == null:
		return

	_panel.position = _panel_position()
	_summary_label.text = _build_summary_text()
	_events_label.text = _build_events_text()
	_triggers_label.text = _build_triggers_text()
	_effects_label.text = _build_effects_text()


func _build_summary_text() -> String:
	var lines: PackedStringArray = PackedStringArray()
	if battle_root != null and battle_root.has_method("get_scenario_name"):
		lines.append("Scenario %s" % String(battle_root.call("get_scenario_name")))
	lines.append("Time %.1f" % GameState.current_time)
	if battle_root != null and battle_root.has_method("get_validation_summary_lines"):
		var validation_lines: PackedStringArray = battle_root.call("get_validation_summary_lines", 2)
		for validation_line in validation_lines:
			lines.append(validation_line)
	if battle_root != null and battle_root.has_method("get_scenario_goals"):
		var goals: PackedStringArray = battle_root.call("get_scenario_goals")
		for goal_index in range(mini(goals.size(), 2)):
			lines.append("Goal %s" % goals[goal_index])
	lines.append("Reset R")
	lines.append("Entities")

	if battle_root == null:
		lines.append("  <no battle>")
		return "\n".join(lines)

	var entities: Array = battle_root.get_children()
	if battle_root.has_method("get_runtime_entities"):
		entities = battle_root.call("get_runtime_entities")
	for child in entities:
		if not child.has_method("get_debug_name"):
			continue
		lines.append("  %s" % _entity_line(child))

	return "\n".join(lines)


func _entity_line(entity: Node) -> String:
	var position_text := ""
	if entity is Node2D:
		var entity_node := entity as Node2D
		position_text = "@(%.0f, %.0f)" % [entity_node.global_position.x, entity_node.global_position.y]
	var status_text := ""
	if entity.has_method("get_debug_snapshot"):
		var snapshot: Dictionary = entity.call("get_debug_snapshot")
		status_text = " status=%s" % String(snapshot.get("status", ""))

	var health_component := entity.get_node_or_null("HealthComponent")
	if health_component != null:
		return "%s lane=%d hp=%d/%d%s %s" % [
			entity.call("get_debug_name"),
			int(entity.get("lane_id")),
			int(health_component.current_health),
			int(health_component.max_health),
			status_text,
			position_text,
		]

	return "%s lane=%d%s %s" % [entity.call("get_debug_name"), int(entity.get("lane_id")), status_text, position_text]


func _build_events_text() -> String:
	var lines: PackedStringArray = PackedStringArray()
	lines.append("Recent Events")
	var count := mini(DebugService.event_log.size(), MAX_EVENT_LINES)
	for index in range(count):
		var entry: Dictionary = DebugService.event_log[index]
		lines.append("  %s d=%d s=%s t=%s" % [
			String(entry.get("event_name", "")),
			int(entry.get("depth", 0)),
			str(entry.get("source", "")),
			str(entry.get("target", "")),
		])
	return "\n".join(lines)


func _build_effects_text() -> String:
	var lines: PackedStringArray = PackedStringArray()
	lines.append("Recent Effects")
	var count := mini(DebugService.effect_log.size(), MAX_EFFECT_LINES)
	for index in range(count):
		var entry: Dictionary = DebugService.effect_log[index]
		lines.append("  %s via %s" % [
			String(entry.get("effect_id", "")),
			String(entry.get("event_name", "")),
		])
	return "\n".join(lines)


func _build_triggers_text() -> String:
	var lines: PackedStringArray = PackedStringArray()
	lines.append("Recent Triggers")
	var count := mini(DebugService.trigger_log.size(), MAX_TRIGGER_LINES)
	for index in range(count):
		var entry: Dictionary = DebugService.trigger_log[index]
		lines.append("  %s %s" % [
			"fire" if bool(entry.get("fired", false)) else "skip",
			String(entry.get("trigger_id", "")),
		])
	return "\n".join(lines)


func _panel_position() -> Vector2:
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	return Vector2(maxf(12.0, viewport_size.x - _panel.size.x - 16.0), 12.0)
