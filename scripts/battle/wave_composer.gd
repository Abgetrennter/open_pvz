extends RefCounted
class_name WaveComposer

const BattleSpawnEntryRef = preload("res://scripts/battle/battle_spawn_entry.gd")
const SpawnZoneConfigRef = preload("res://scripts/battle/spawn_zone_config.gd")
const WaveDefRef = preload("res://scripts/battle/wave_def.gd")
const WaveInjectionRuleDefRef = preload("res://scripts/battle/wave_injection_rule_def.gd")
const WavePoolDefRef = preload("res://scripts/battle/wave_pool_def.gd")
const WavePoolEntryDefRef = preload("res://scripts/battle/wave_pool_entry_def.gd")
const WaveRecipeDefRef = preload("res://scripts/battle/wave_recipe_def.gd")
const WaveSpawnEntryRef = preload("res://scripts/battle/wave_spawn_entry.gd")

const SPAWN_MEDIUM_TAGS := [
	&"spawn.medium.ground",
	&"spawn.medium.water",
	&"spawn.medium.roof",
]


func compile(recipe: Resource, battle_seed: int = 0, battlefield_preset: Resource = null) -> Array[Resource]:
	if recipe == null or recipe.get_script() != WaveRecipeDefRef:
		return []
	var waves: Array[Resource] = []
	var spawn_contract := _build_spawn_contract(battlefield_preset)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%s_%d" % [String(recipe.get("recipe_id")), battle_seed])
	for wave_index in range(int(recipe.get("total_waves"))):
		var wave := WaveDefRef.new()
		wave.wave_id = _wave_id(recipe, wave_index)
		wave.start_time = float(recipe.get("start_delay")) + float(wave_index) * float(recipe.get("base_spacing"))
		wave.wave_kind = &"flag" if _is_flag_wave(recipe, wave_index) else &"normal"
		wave.advance_policy = recipe.get("advance_policy")
		wave.spawn_entries = _build_wave_spawn_entries(recipe, wave_index, rng, spawn_contract)
		_apply_special_injections(wave, recipe, wave_index, spawn_contract)
		waves.append(wave)
	return waves


func _build_wave_spawn_entries(recipe: Resource, wave_index: int, rng: RandomNumberGenerator, spawn_contract: Dictionary) -> Array:
	var entries: Array = []
	var budget := _budget_for_wave(recipe, wave_index)
	var flag_entry: Resource = recipe.get("flag_entry")
	if _is_flag_wave(recipe, wave_index) and flag_entry != null and _entry_matches_spawn_contract(flag_entry, spawn_contract):
		entries.append(_make_wave_spawn_entry(flag_entry, 0.0))
		budget -= maxi(1, int(flag_entry.get("power")))
	while budget > 0:
		var candidate := _pick_pool_entry(recipe, wave_index, budget, rng, spawn_contract)
		if candidate == null:
			break
		entries.append(_make_wave_spawn_entry(candidate, float(entries.size()) * 0.25))
		budget -= maxi(1, int(candidate.get("power")))
	return entries


func _budget_for_wave(recipe: Resource, wave_index: int) -> int:
	var budget := int(recipe.get("base_budget")) + int(recipe.get("budget_per_wave")) * wave_index
	if _is_flag_wave(recipe, wave_index):
		budget = int(ceil(float(budget) * float(recipe.get("flag_budget_multiplier"))))
	return maxi(1, budget)


func _is_flag_wave(recipe: Resource, wave_index: int) -> bool:
	var waves_per_flag := int(recipe.get("waves_per_flag"))
	if waves_per_flag <= 0:
		return false
	return (wave_index + 1) % waves_per_flag == 0


func _pick_pool_entry(recipe: Resource, wave_index: int, budget: int, rng: RandomNumberGenerator, spawn_contract: Dictionary) -> Resource:
	var pool: Resource = recipe.get("pool_def")
	if pool == null or pool.get_script() != WavePoolDefRef:
		return null
	var candidates: Array[Resource] = []
	var total_weight := 0
	for entry in Array(pool.get("entries")):
		if entry == null or entry.get_script() != WavePoolEntryDefRef:
			continue
		if int(entry.get("first_allowed_wave")) > wave_index:
			continue
		if int(entry.get("power")) > budget:
			continue
		var weight := int(entry.get("weight"))
		if weight <= 0:
			continue
		if not _entry_matches_spawn_contract(entry, spawn_contract):
			continue
		candidates.append(entry)
		total_weight += weight
	if candidates.is_empty():
		return null
	var roll := rng.randi_range(1, total_weight)
	var cursor := 0
	for entry in candidates:
		cursor += int(entry.get("weight"))
		if roll <= cursor:
			return entry
	return candidates[0]


func _make_wave_spawn_entry(pool_entry: Resource, spawn_time_offset: float) -> Resource:
	var spawn_entry := BattleSpawnEntryRef.new()
	spawn_entry.entity_kind = &"zombie"
	spawn_entry.archetype = pool_entry.get("archetype")
	spawn_entry.archetype_id = StringName(pool_entry.get("archetype_id"))
	spawn_entry.lane_id = int(pool_entry.get("lane_id"))
	spawn_entry.x_position = float(pool_entry.get("x_position"))
	var overrides: Variant = pool_entry.get("spawn_overrides")
	spawn_entry.spawn_overrides = Dictionary(overrides).duplicate(true) if overrides is Dictionary else {}
	var wave_spawn_entry := WaveSpawnEntryRef.new()
	wave_spawn_entry.spawn_time_offset = maxf(spawn_time_offset, 0.0)
	wave_spawn_entry.spawn_entry = spawn_entry
	return wave_spawn_entry


func _wave_id(recipe: Resource, wave_index: int) -> StringName:
	var recipe_id := StringName(recipe.get("recipe_id"))
	if recipe_id == StringName():
		recipe_id = &"wave_recipe"
	return StringName("%s_%d" % [String(recipe_id), wave_index])


func _apply_special_injections(wave: Resource, recipe: Resource, wave_index: int, spawn_contract: Dictionary) -> void:
	var spawn_entries := Array(wave.get("spawn_entries"))
	for rule in Array(recipe.get("special_injection_rules")):
		if rule == null or rule.get_script() != WaveInjectionRuleDefRef:
			continue
		if int(rule.get("wave_index")) != wave_index:
			continue
		var entry: Resource = rule.get("entry")
		if entry == null or entry.get_script() != WavePoolEntryDefRef:
			continue
		if not _entry_matches_spawn_contract(entry, spawn_contract):
			continue
		spawn_entries.append(_make_wave_spawn_entry(entry, float(rule.get("spawn_time_offset"))))
	spawn_entries.sort_custom(func(a: Resource, b: Resource) -> bool:
		return float(a.get("spawn_time_offset")) < float(b.get("spawn_time_offset"))
	)
	wave.set("spawn_entries", spawn_entries)


func _build_spawn_contract(battlefield_preset: Resource) -> Dictionary:
	var lane_tags: Dictionary = {}
	if battlefield_preset == null:
		return lane_tags
	var configured_zones: Variant = battlefield_preset.get("spawn_zones")
	if not (configured_zones is Array):
		return lane_tags
	for zone in Array(configured_zones):
		if zone == null or zone.get_script() != SpawnZoneConfigRef:
			continue
		if not bool(zone.get("enabled")):
			continue
		var lane_id := int(zone.get("lane_id"))
		if not lane_tags.has(lane_id):
			lane_tags[lane_id] = PackedStringArray()
		var tags := PackedStringArray(lane_tags[lane_id])
		for tag in PackedStringArray(zone.get("zone_tags")):
			if not tags.has(tag):
				tags.append(tag)
		lane_tags[lane_id] = tags
	return lane_tags


func _entry_matches_spawn_contract(entry: Resource, spawn_contract: Dictionary) -> bool:
	if spawn_contract.is_empty():
		return true
	var lane_id := int(entry.get("lane_id"))
	if not spawn_contract.has(lane_id):
		return false
	var required_tags := _entry_required_spawn_tags(entry)
	if required_tags.is_empty():
		return false
	var available_tags := PackedStringArray(spawn_contract[lane_id])
	for required_tag in required_tags:
		if available_tags.has(required_tag):
			return true
	return false


func _entry_required_spawn_tags(entry: Resource) -> PackedStringArray:
	var tags := PackedStringArray(entry.get("required_spawn_tags"))
	if not tags.is_empty():
		return _spawn_medium_tags(tags)
	var direct_archetype: Variant = entry.get("archetype")
	if direct_archetype is Resource:
		return _spawn_medium_tags(PackedStringArray(direct_archetype.get("tags")))
	var archetype_id := StringName(entry.get("archetype_id"))
	if archetype_id == StringName() or not SceneRegistry.has_archetype(archetype_id):
		return PackedStringArray()
	var archetype = SceneRegistry.get_archetype(archetype_id)
	if archetype == null:
		return PackedStringArray()
	return _spawn_medium_tags(PackedStringArray(archetype.get("tags")))


func _spawn_medium_tags(raw_tags: PackedStringArray) -> PackedStringArray:
	var result := PackedStringArray()
	for tag in raw_tags:
		var tag_name := StringName(tag)
		if SPAWN_MEDIUM_TAGS.has(tag_name) and not result.has(String(tag_name)):
			result.append(String(tag_name))
	return result
