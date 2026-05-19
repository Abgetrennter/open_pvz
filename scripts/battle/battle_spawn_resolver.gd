extends RefCounted
class_name BattleSpawnResolver

const SpawnZoneConfigRef = preload("res://scripts/battle/spawn_zone_config.gd")
const CombatArchetypeRef = preload("res://scripts/core/defs/combat_archetype.gd")

const SPAWN_MEDIUM_GROUND := &"spawn.medium.ground"
const SPAWN_MEDIUM_WATER := &"spawn.medium.water"
const SPAWN_MEDIUM_ROOF := &"spawn.medium.roof"

var _battle: Node = null
var _zones: Array[Resource] = []
var _strict_requirements := false


func setup(battle: Node, battlefield_preset) -> void:
	_battle = battle
	_zones.clear()
	_strict_requirements = _preset_uses_explicit_spawn_contract(battlefield_preset)
	if battlefield_preset != null:
		var configured_zones: Variant = battlefield_preset.get("spawn_zones")
		if configured_zones is Array:
			for zone in configured_zones:
				if zone != null and zone.get_script() == SpawnZoneConfigRef:
					_zones.append(zone)
	if _zones.is_empty():
		_build_default_zones()


func resolve_spawn(spawn_entry: Resource, archetype: Resource) -> Dictionary:
	if spawn_entry == null:
		return _failure(&"spawn_entry_missing")
	if archetype == null or not (archetype is CombatArchetypeRef):
		return _failure(&"archetype_missing")
	var required_tags := _required_spawn_tags(archetype)
	if required_tags.is_empty():
		if not _strict_requirements:
			return _legacy_spawn(spawn_entry)
		return _failure(&"missing_required_spawn_tags")
	var lane_id := int(spawn_entry.get("lane_id"))
	var candidates := _candidate_zones(lane_id)
	if candidates.is_empty():
		return _failure(&"spawn_zone_missing", lane_id)
	for zone in candidates:
		if not bool(zone.get("enabled")):
			continue
		var zone_tags := PackedStringArray(zone.get("zone_tags"))
		if _tags_match(zone_tags, required_tags):
			return {
				"ok": true,
				"lane_id": int(zone.get("lane_id")),
				"x": float(zone.get("x")),
				"zone_id": StringName(zone.get("zone_id")),
				"reason": StringName(),
			}
	return _failure(&"spawn_tags_mismatch", lane_id)


func get_zones() -> Array[Resource]:
	return _zones.duplicate()


func _build_default_zones() -> void:
	if _battle == null or not is_instance_valid(_battle) or not _battle.has_method("get_board_state"):
		return
	var board_state: Node = _battle.call("get_board_state")
	if board_state == null or not is_instance_valid(board_state):
		return
	if not _battle.has_method("get_lane_ids"):
		return
	var default_x := 900.0
	var playfield_size: Variant = _battle.get("playfield_size")
	if playfield_size is Vector2:
		default_x = maxf(float(playfield_size.x) - 80.0, 0.0)
	for raw_lane_id in _battle.call("get_lane_ids"):
		var lane_id := int(raw_lane_id)
		var traits := PackedStringArray()
		if board_state.has_method("get_lane_traits"):
			traits = PackedStringArray(board_state.call("get_lane_traits", lane_id))
		var zone_tags := _default_zone_tags_for_traits(traits)
		if zone_tags.is_empty():
			continue
		var zone = SpawnZoneConfigRef.new()
		zone.zone_id = StringName("default_lane_%d" % lane_id)
		zone.lane_id = lane_id
		zone.x = default_x
		zone.zone_group = &"default"
		zone.zone_tags = zone_tags
		zone.enabled = true
		_zones.append(zone)


func _default_zone_tags_for_traits(traits: PackedStringArray) -> PackedStringArray:
	if traits.has("placement.blocked"):
		return PackedStringArray()
	if traits.has("surface.water"):
		return PackedStringArray([SPAWN_MEDIUM_WATER])
	if traits.has("surface.roof"):
		return PackedStringArray([SPAWN_MEDIUM_ROOF, SPAWN_MEDIUM_GROUND])
	if traits.has("surface.ground"):
		return PackedStringArray([SPAWN_MEDIUM_GROUND])
	return PackedStringArray([SPAWN_MEDIUM_GROUND])


func _required_spawn_tags(archetype: Resource) -> PackedStringArray:
	var result := PackedStringArray()
	for tag in PackedStringArray(archetype.get("tags")):
		var tag_name := StringName(tag)
		if tag_name == SPAWN_MEDIUM_GROUND or tag_name == SPAWN_MEDIUM_WATER or tag_name == SPAWN_MEDIUM_ROOF:
			result.append(String(tag_name))
	return result


func _candidate_zones(lane_id: int) -> Array[Resource]:
	var result: Array[Resource] = []
	for zone in _zones:
		if zone == null or zone.get_script() != SpawnZoneConfigRef:
			continue
		if int(zone.get("lane_id")) != lane_id:
			continue
		result.append(zone)
	return result


func _tags_match(zone_tags: PackedStringArray, required_tags: PackedStringArray) -> bool:
	for required_tag in required_tags:
		if zone_tags.has(required_tag):
			return true
	return false


func _failure(reason: StringName, lane_id: int = -1) -> Dictionary:
	return {
		"ok": false,
		"lane_id": lane_id,
		"x": 0.0,
		"zone_id": StringName(),
		"reason": reason,
	}


func _legacy_spawn(spawn_entry: Resource) -> Dictionary:
	return {
		"ok": true,
		"lane_id": int(spawn_entry.get("lane_id")),
		"x": float(spawn_entry.get("x_position")),
		"zone_id": StringName(),
		"reason": &"legacy_wave_entry",
	}


func _preset_uses_explicit_spawn_contract(preset) -> bool:
	if preset == null:
		return false
	var spawn_zones: Variant = preset.get("spawn_zones")
	if spawn_zones is Array and not Array(spawn_zones).is_empty():
		return true
	return false
