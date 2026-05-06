extends "res://scripts/core/registry/registry_base.gd"

const VisualFxDefRef = preload("res://scripts/core/defs/visual_fx_def.gd")


func _make_registry_config():
	return RegistryConfigRef.create(
		&"visual_fx",
		VisualFxDefRef,
		&"visual_fx",
		"data/combat/visual_fx",
		&"data_only",
		StringName(),
		false
	)


func _on_registry_cleared() -> void:
	pass


func _register_builtin_defs() -> void:
	var hit_splat = VisualFxDefRef.new()
	hit_splat.id = &"core.hit_splat"
	hit_splat.fx_scene = null
	hit_splat.default_lifetime = 0.5
	hit_splat.default_layer = &"world_fx"
	register_def(hit_splat, {"kind": &"core", "source": &"core"})

	var expired_puff = VisualFxDefRef.new()
	expired_puff.id = &"core.expired_puff"
	expired_puff.fx_scene = null
	expired_puff.default_lifetime = 0.3
	expired_puff.default_layer = &"world_fx"
	register_def(expired_puff, {"kind": &"core", "source": &"core"})

	var placement_pop = VisualFxDefRef.new()
	placement_pop.id = &"core.placement_pop"
	placement_pop.fx_scene = null
	placement_pop.default_lifetime = 0.5
	placement_pop.default_layer = &"world_fx"
	register_def(placement_pop, {"kind": &"core", "source": &"core"})
