extends Resource
class_name LaneTerrainProfile

@export var profile_id: StringName = StringName()
@export var elevation_mode: StringName = &"flat"
@export var base_elevation := 0.0
@export var elevation_per_slot := 0.0
@export var slot_elevations: PackedFloat32Array = PackedFloat32Array()
@export var sample_points: PackedVector2Array = PackedVector2Array()
@export var interpolation: StringName = &"step"
@export var projection_y_scale := 1.0
