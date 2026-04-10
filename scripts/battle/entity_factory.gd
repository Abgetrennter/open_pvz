extends RefCounted
class_name EntityFactory

const PlantRootRef = preload("res://scripts/entities/plant_root.gd")
const ZombieRootRef = preload("res://scripts/entities/zombie_root.gd")
const ProjectileRootRef = preload("res://scripts/entities/projectile_root.gd")
const TriggerComponentRef = preload("res://scripts/components/trigger_component.gd")
const HealthComponentRef = preload("res://scripts/components/health_component.gd")
const MovementComponentRef = preload("res://scripts/components/movement_component.gd")
const HitboxComponentRef = preload("res://scripts/components/hitbox_component.gd")
const DebugViewComponentRef = preload("res://scripts/components/debug_view_component.gd")


func create_plant(position: Vector2):
	var plant: Variant = PlantRootRef.new()
	plant.position = position
	plant.add_child(_make_trigger_component())
	plant.add_child(_make_health_component(100))
	plant.add_child(_make_passive_hitbox(Vector2(42.0, 54.0)))
	plant.add_child(_make_debug_component())
	return plant


func create_zombie(position: Vector2):
	var zombie: Variant = ZombieRootRef.new()
	zombie.position = position
	zombie.add_child(_make_health_component(120))
	zombie.add_child(_make_passive_hitbox(Vector2(44.0, 60.0)))
	return zombie


func create_projectile(position: Vector2):
	var projectile: Variant = ProjectileRootRef.new()
	projectile.position = position
	projectile.add_child(_make_projectile_hitbox(10.0))
	projectile.add_child(_make_movement_component())
	return projectile


func _make_trigger_component():
	var component: Variant = TriggerComponentRef.new()
	component.name = "TriggerComponent"
	return component


func _make_health_component(max_health: int):
	var component: Variant = HealthComponentRef.new()
	component.name = "HealthComponent"
	component.max_health = max_health
	return component


func _make_movement_component():
	var component: Variant = MovementComponentRef.new()
	component.name = "MovementComponent"
	return component


func _make_projectile_hitbox(radius: float):
	var component: Variant = HitboxComponentRef.new()
	component.name = "HitboxComponent"
	component.monitoring = true
	component.monitorable = true
	component.collision_layer = 1
	component.collision_mask = 1
	component.configure_circle(radius)
	return component


func _make_passive_hitbox(size: Vector2):
	var component: Variant = HitboxComponentRef.new()
	component.name = "HitboxComponent"
	component.monitoring = false
	component.monitorable = true
	component.collision_layer = 1
	component.collision_mask = 0
	component.configure_rectangle(size)
	return component


func _make_debug_component():
	var component: Variant = DebugViewComponentRef.new()
	component.name = "DebugViewComponent"
	return component
