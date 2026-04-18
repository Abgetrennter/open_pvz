extends RefCounted
class_name BattleValidationReporter

var _battle: Node = null


func bind_battle(battle: Node) -> void:
	_battle = battle


func report_validation_result(
	validation_status: StringName,
	validation_output_dir: String,
	print_validation_report: bool,
	auto_quit_on_validation: bool,
	validation_run_label: String,
	validation_started_at: float,
	validation_rule_states: Array[Dictionary],
	validation_counts: Dictionary,
	enable_runtime_snapshot_logging: bool,
	runtime_snapshot_interval_frames: int
) -> void:
	if not print_validation_report and not auto_quit_on_validation and validation_output_dir.is_empty():
		return

	var status_label := "PASSED" if validation_status == &"passed" else "FAILED"
	var active_scenario = _battle.resolve_scenario()
	var scenario_label := "unknown"
	if active_scenario != null:
		scenario_label = "%s (%s)" % [active_scenario.display_name, String(active_scenario.scenario_id)]

	if print_validation_report or auto_quit_on_validation:
		print("[Validation] %s %s" % [status_label, scenario_label])
		for line in _battle.get_validation_summary_lines(12):
			print("[Validation] %s" % line)

	_export_validation_artifacts(
		validation_status,
		validation_output_dir,
		validation_run_label,
		validation_started_at,
		validation_rule_states,
		validation_counts,
		enable_runtime_snapshot_logging,
		runtime_snapshot_interval_frames
	)


func _export_validation_artifacts(
	validation_status: StringName,
	validation_output_dir: String,
	validation_run_label: String,
	validation_started_at: float,
	validation_rule_states: Array[Dictionary],
	validation_counts: Dictionary,
	enable_runtime_snapshot_logging: bool,
	runtime_snapshot_interval_frames: int
) -> void:
	if validation_output_dir.is_empty():
		return
	var output_dir_path := _resolved_output_dir_path(validation_output_dir)
	if output_dir_path.is_empty():
		return

	var mkdir_error := DirAccess.make_dir_recursive_absolute(output_dir_path)
	if mkdir_error != OK:
		push_warning("Failed to create validation output directory: %s (error %d)" % [output_dir_path, mkdir_error])
		return

	var report_path := output_dir_path.path_join("validation_report.json")
	var summary_path := output_dir_path.path_join("validation_summary.txt")
	var debug_log_path := output_dir_path.path_join("debug_logs.json")

	var report: Dictionary = _build_validation_report(
		validation_status,
		validation_run_label,
		validation_started_at,
		validation_rule_states,
		validation_counts,
		enable_runtime_snapshot_logging,
		runtime_snapshot_interval_frames
	)
	var summary_text := "\n".join(_battle.get_validation_summary_lines(12)) + "\n"
	var debug_payload: Dictionary = {}
	if DebugService.has_method("build_export_payload"):
		debug_payload = DebugService.build_export_payload()

	_write_json_file(report_path, report)
	_write_text_file(summary_path, summary_text)
	_write_json_file(debug_log_path, debug_payload)
	print("[Validation] Artifacts exported to %s" % output_dir_path)


func _build_validation_report(
	validation_status: StringName,
	validation_run_label: String,
	validation_started_at: float,
	validation_rule_states: Array[Dictionary],
	validation_counts: Dictionary,
	enable_runtime_snapshot_logging: bool,
	runtime_snapshot_interval_frames: int
) -> Dictionary:
	var active_scenario = _battle.resolve_scenario()
	var validation_rules: Array[Dictionary] = []
	for rule_state in validation_rule_states:
		validation_rules.append({
			"rule_id": String(rule_state.get("rule_id", "")),
			"description": String(rule_state.get("description", "")),
			"event_name": String(rule_state.get("event_name", "")),
			"min_count": int(rule_state.get("min_count", 0)),
			"max_count": int(rule_state.get("max_count", -1)),
			"count": int(rule_state.get("count", 0)),
			"satisfied": bool(rule_state.get("satisfied", false)),
			"exceeded": bool(rule_state.get("exceeded", false)),
			"required_tags": Array(PackedStringArray(rule_state.get("required_tags", PackedStringArray()))),
			"required_core_values": rule_state.get("required_core_values", {}).duplicate(true),
		})

	return {
		"scenario_id": "" if active_scenario == null else String(active_scenario.scenario_id),
		"display_name": "" if active_scenario == null else String(active_scenario.display_name),
		"description": "" if active_scenario == null else String(active_scenario.description),
		"goals": [] if active_scenario == null else Array(active_scenario.goals),
		"status": String(validation_status),
		"summary_lines": Array(_battle.get_validation_summary_lines(12)),
		"unsatisfied_rules": Array(_battle.get_unsatisfied_validation_descriptions()),
		"validation_time_limit": 0.0 if active_scenario == null else float(active_scenario.validation_time_limit),
		"started_at": validation_started_at,
		"finished_at": GameState.current_time,
		"counts": validation_counts.duplicate(true),
		"run_label": validation_run_label,
		"runtime_snapshot_enabled": enable_runtime_snapshot_logging,
		"runtime_snapshot_interval_frames": runtime_snapshot_interval_frames,
		"rules": validation_rules,
	}


func _resolved_output_dir_path(validation_output_dir: String) -> String:
	if validation_output_dir.is_empty():
		return ""
	if validation_output_dir.begins_with("res://") or validation_output_dir.begins_with("user://"):
		return ProjectSettings.globalize_path(validation_output_dir)
	return validation_output_dir


func _write_json_file(path: String, payload: Variant) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_warning("Failed to open validation artifact for writing: %s" % path)
		return
	file.store_string(JSON.stringify(payload, "\t"))
	file.close()


func _write_text_file(path: String, contents: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_warning("Failed to open validation summary for writing: %s" % path)
		return
	file.store_string(contents)
	file.close()
