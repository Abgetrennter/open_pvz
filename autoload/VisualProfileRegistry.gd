extends "res://scripts/core/registry/registry_base.gd"

const VisualProfileDefRef = preload("res://scripts/core/defs/visual_profile_def.gd")


func _make_registry_config():
	return RegistryConfigRef.create(
		&"visual_profiles",
		VisualProfileDefRef,
		&"visual_profiles",
		"data/combat/visual_profiles",
		&"data_only",
		StringName(),
		false
	)


func _on_registry_cleared() -> void:
	pass


func _register_builtin_defs() -> void:
	var placeholder_plant = VisualProfileDefRef.new()
	placeholder_plant.id = &"core.placeholder_plant"
	placeholder_plant.actor_scene = null
	placeholder_plant.state_animation_map = {
		&"idle": &"idle",
		&"attacking": &"attack",
		&"dead": &"death",
	}
	placeholder_plant.z_policy = {"layer": &"plant"}
	register_def(placeholder_plant, {"kind": &"core", "source": &"core"})

	var placeholder_zombie = VisualProfileDefRef.new()
	placeholder_zombie.id = &"core.placeholder_zombie"
	placeholder_zombie.actor_scene = null
	placeholder_zombie.state_animation_map = {
		&"idle": &"idle",
		&"moving": &"walk",
		&"attacking": &"attack",
		&"dead": &"death",
	}
	placeholder_zombie.z_policy = {"layer": &"zombie"}
	register_def(placeholder_zombie, {"kind": &"core", "source": &"core"})

	var placeholder_projectile = VisualProfileDefRef.new()
	placeholder_projectile.id = &"core.placeholder_projectile"
	placeholder_projectile.actor_scene = null
	placeholder_projectile.shadow_policy = {"enabled": false}
	placeholder_projectile.z_policy = {"layer": &"projectile"}
	register_def(placeholder_projectile, {"kind": &"core", "source": &"core"})
