extends Resource
class_name BattlefieldVisualDef

@export var id: StringName = StringName()
@export var texture_asset_id: StringName = StringName()
@export var source_size: Vector2 = Vector2.ZERO
@export var draw_offset: Vector2 = Vector2.ZERO
@export_enum("original") var fit_mode := "original"
