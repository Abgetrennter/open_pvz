extends "res://scripts/core/registry/registry_base.gd"

const VisualCueDefRef = preload("res://scripts/core/defs/visual_cue_def.gd")


func _make_registry_config():
	return RegistryConfigRef.create(
		&"visual_cues",
		VisualCueDefRef,
		&"visual_cues",
		"data/combat/visual_cues",
		&"data_only",
		StringName(),
		false
	)


func _on_registry_cleared() -> void:
	pass


func _register_builtin_defs() -> void:
	var splat_cue = VisualCueDefRef.new()
	splat_cue.id = &"core.projectile_hit_splat"
	splat_cue.listen_event = &"projectile.hit"
	splat_cue.actions = _make_actions({"type": &"spawn_fx", "fx_id": &"core.hit_splat"})
	register_def(splat_cue, {"kind": &"core", "source": &"core"})

	var puff_cue = VisualCueDefRef.new()
	puff_cue.id = &"core.projectile_expired_puff"
	puff_cue.listen_event = &"projectile.expired"
	puff_cue.actions = _make_actions({"type": &"spawn_fx", "fx_id": &"core.expired_puff"})
	register_def(puff_cue, {"kind": &"core", "source": &"core"})

	var flash_cue = VisualCueDefRef.new()
	flash_cue.id = &"core.entity_damaged_flash"
	flash_cue.listen_event = &"entity.damaged"
	flash_cue.actions = _make_actions({"type": &"flash_actor", "color": Color.WHITE, "duration": 0.1})
	register_def(flash_cue, {"kind": &"core", "source": &"core"})

	var fade_cue = VisualCueDefRef.new()
	fade_cue.id = &"core.entity_died_fade"
	fade_cue.listen_event = &"entity.died"
	fade_cue.actions = _make_actions({"type": &"play_actor_animation", "animation": &"dead"})
	register_def(fade_cue, {"kind": &"core", "source": &"core"})

	var pop_cue = VisualCueDefRef.new()
	pop_cue.id = &"core.placement_accepted_pop"
	pop_cue.listen_event = &"placement.accepted"
	pop_cue.actions = _make_actions({"type": &"spawn_fx", "fx_id": &"core.placement_pop"})
	register_def(pop_cue, {"kind": &"core", "source": &"core"})

	var status_clear_cue = VisualCueDefRef.new()
	status_clear_cue.id = &"core.status_removed_clear_overlay"
	status_clear_cue.listen_event = &"entity.status_removed"
	status_clear_cue.actions = _make_actions({"type": &"play_actor_animation", "animation": &"status_clear"})
	register_def(status_clear_cue, {"kind": &"core", "source": &"core"})


func get_cues_for_event(event_name: StringName) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	for entry_key in _entries:
		var entry: Dictionary = _entries[entry_key]
		var cue_def = entry.get("def", null)
		if cue_def == null:
			continue
		if cue_def.listen_event == event_name:
			results.append(entry)
	return results


func _make_actions(action: Dictionary) -> Array[Dictionary]:
	var actions: Array[Dictionary] = []
	actions.append(action)
	return actions
