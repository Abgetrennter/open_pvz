extends RefCounted
class_name BattleValidationTracker

const BattleValidationRuleRef = preload("res://scripts/battle/battle_validation_rule.gd")

var _battle: Node = null
var _validation_status: StringName = &"pending"
var _validation_started_at := 0.0
var _validation_deadline := 0.0
var _validation_rule_states: Array[Dictionary] = []
var _validation_counts: Dictionary = {}
var _auto_quit_timer := -1.0
var _validation_reported := false


func bind_battle(battle: Node) -> void:
	_battle = battle


func reset_validation() -> void:
	_validation_status = &"pending"
	_validation_started_at = GameState.current_time
	var active_scenario = _battle.call("_resolve_scenario")
	_validation_deadline = GameState.current_time + (0.0 if active_scenario == null else float(active_scenario.validation_time_limit))
	_validation_rule_states.clear()
	_validation_counts.clear()
	_auto_quit_timer = -1.0
	_validation_reported = false
	if active_scenario == null:
		return

	for validation_rule in active_scenario.validation_rules:
		if validation_rule == null or validation_rule.get_script() != BattleValidationRuleRef:
			continue
		var initial_count := 0
		_validation_rule_states.append({
			"rule_id": validation_rule.rule_id,
			"description": validation_rule.description,
			"event_name": validation_rule.event_name,
			"min_count": validation_rule.min_count,
			"max_count": validation_rule.max_count,
			"required_tags": validation_rule.required_tags,
			"required_core_values": validation_rule.required_core_values.duplicate(true),
			"count": initial_count,
			"satisfied": _is_rule_satisfied(initial_count, validation_rule.min_count, validation_rule.max_count),
			"exceeded": _is_rule_exceeded(initial_count, validation_rule.max_count),
		})


func on_validation_event(event_name: StringName, event_data: Variant) -> void:
	if _validation_status != &"pending":
		return
	if _validation_rule_states.is_empty():
		return

	for rule_state in _validation_rule_states:
		if rule_state["event_name"] != event_name:
			continue
		if not _event_matches_rule(event_data, rule_state):
			continue
		rule_state["count"] = int(rule_state.get("count", 0)) + 1
		rule_state["exceeded"] = _is_rule_exceeded(int(rule_state["count"]), int(rule_state.get("max_count", -1)))
		rule_state["satisfied"] = _is_rule_satisfied(
			int(rule_state["count"]),
			int(rule_state.get("min_count", 1)),
			int(rule_state.get("max_count", -1))
		)
		_validation_counts[rule_state["rule_id"]] = rule_state["count"]
		if bool(rule_state.get("exceeded", false)):
			_set_validation_status(&"failed")
			return

	_refresh_validation_status()


func update_validation_state() -> void:
	if _validation_status != &"pending":
		return
	if _validation_deadline <= 0.0:
		return
	if GameState.current_time <= _validation_deadline:
		return
	if _all_validation_rules_satisfied():
		_set_validation_status(&"passed")
		return
	if _validation_status != &"passed":
		_set_validation_status(&"failed")


func process_auto_quit(delta: float) -> void:
	if _auto_quit_timer < 0.0:
		return
	_auto_quit_timer -= delta
	if _auto_quit_timer > 0.0:
		return
	_auto_quit_timer = -1.0
	_battle.get_tree().quit(0 if _validation_status == &"passed" else 1)


func get_validation_status() -> String:
	return String(_validation_status)


func get_validation_summary_lines(limit: int = 3) -> PackedStringArray:
	var lines: PackedStringArray = PackedStringArray()
	var status_text := String(_validation_status).to_upper()
	var remaining_time := maxf(_validation_deadline - GameState.current_time, 0.0)
	lines.append("Validation %s" % status_text)
	if _validation_status == &"pending":
		lines.append("Window %.1fs" % remaining_time)

	var shown := 0
	for rule_state in _validation_rule_states:
		if bool(rule_state.get("satisfied", false)):
			continue
		if bool(rule_state.get("exceeded", false)):
			lines.append("Exceeded %s" % String(rule_state.get("description", "")))
		else:
			lines.append("Need %s" % String(rule_state.get("description", "")))
		shown += 1
		if shown >= limit:
			break

	if shown == 0 and _validation_status == &"passed":
		lines.append("All scenario checks satisfied.")
	elif shown == 0 and _validation_status == &"failed":
		lines.append("Window expired before checks completed.")
	return lines


func get_unsatisfied_validation_descriptions() -> PackedStringArray:
	var lines: PackedStringArray = PackedStringArray()
	for rule_state in _validation_rule_states:
		if bool(rule_state.get("satisfied", false)):
			continue
		if bool(rule_state.get("exceeded", false)):
			lines.append("Exceeded %s" % String(rule_state.get("description", "")))
		else:
			lines.append(String(rule_state.get("description", "")))
	return lines


func _set_validation_status(next_status: StringName) -> void:
	if _validation_status == next_status:
		return
	_validation_status = next_status
	if next_status == &"passed" or next_status == &"failed":
		_report_validation_result()
		_battle.call("_emit_validation_completed", next_status)
		var auto_quit_on_validation: bool = _battle.auto_quit_on_validation
		if auto_quit_on_validation:
			var auto_quit_delay: float = _battle.auto_quit_delay
			_auto_quit_timer = maxf(auto_quit_delay, 0.0)


func _report_validation_result() -> void:
	if _validation_reported:
		return
	var print_report: bool = _battle.print_validation_report
	var auto_quit: bool = _battle.auto_quit_on_validation
	var output_dir: String = _battle.validation_output_dir
	if not print_report and not auto_quit and output_dir.is_empty():
		return
	_validation_reported = true
	var reporter: RefCounted = _battle.call("_get_validation_reporter")
	reporter.report_validation_result(
		_validation_status,
		output_dir,
		print_report,
		auto_quit,
		String(_battle.validation_run_label),
		_validation_started_at,
		_validation_rule_states,
		_validation_counts,
		bool(_battle.enable_runtime_snapshot_logging),
		int(_battle.runtime_snapshot_interval_frames)
	)


func _refresh_validation_status() -> void:
	if _validation_rule_states.is_empty():
		_set_validation_status(&"passed")
		return
	for rule_state in _validation_rule_states:
		if bool(rule_state.get("exceeded", false)):
			_set_validation_status(&"failed")
			return
		if not bool(rule_state.get("satisfied", false)):
			return
	if _has_deadline_confirmed_rules():
		return
	_set_validation_status(&"passed")


func _event_matches_rule(event_data: Variant, rule_state: Dictionary) -> bool:
	var event_tags := PackedStringArray(event_data.core.get("tags", PackedStringArray()))
	for required_tag in PackedStringArray(rule_state.get("required_tags", PackedStringArray())):
		if not event_tags.has(required_tag):
			return false

	var required_core_values: Dictionary = rule_state.get("required_core_values", {})
	for key: Variant in required_core_values.keys():
		if event_data.core.get(key, null) != required_core_values[key]:
			return false
	return true


func _all_validation_rules_satisfied() -> bool:
	if _validation_rule_states.is_empty():
		return true
	for rule_state in _validation_rule_states:
		if bool(rule_state.get("exceeded", false)):
			return false
		if not bool(rule_state.get("satisfied", false)):
			return false
	return true


func _has_deadline_confirmed_rules() -> bool:
	for rule_state in _validation_rule_states:
		if int(rule_state.get("max_count", -1)) >= 0:
			return true
	return false


func _is_rule_satisfied(count: int, min_count: int, max_count: int) -> bool:
	if count < min_count:
		return false
	if max_count >= 0 and count > max_count:
		return false
	return true


func _is_rule_exceeded(count: int, max_count: int) -> bool:
	return max_count >= 0 and count > max_count
