extends "res://scripts/core/registry/registry_base.gd"

const AudioCueDefRef = preload("res://scripts/core/defs/audio_cue_def.gd")


func _make_registry_config():
	return RegistryConfigRef.create(
		&"audio_cues",
		AudioCueDefRef,
		&"audio_cues",
		"data/combat/audio_cues",
		&"data_only",
		StringName(),
		false
	)


func _on_registry_cleared() -> void:
	pass


func _register_builtin_defs() -> void:
	var silent = AudioCueDefRef.new()
	silent.id = &"core.silent"
	silent.stream = null
	silent.volume = -80.0
	register_def(silent, {"kind": &"core", "source": &"core"})
