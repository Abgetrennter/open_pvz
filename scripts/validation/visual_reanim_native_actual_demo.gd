extends Node2D
## Windowed demo for the native reanim runtime - full T6 roster.
##
## Loads all 18 migrated original plants as native actors (ReanimActor +
## ReanimActorDef + ReanimData) straight from generated/native, drives
## GameState.current_time locally and loops a combat cycle (idle rest ->
## continuous volleys at the original 1.5s cadence -> idle). Non-shooters
## play their flourish actions on a periodic timer, which exercises the T6
## capabilities live: clip_rates (pea family fps parity), action_next_states
## (chomper bite -> digesting -> swallow -> idle, scaredyshroom cower ->
## cowering) and fixed {position} anchors (pea muzzles, chomper mouth).
## Demo-only; not registered as a validation scenario and never touches
## production profiles.
##
## Run (windowed):
##   & .\Godot_v4.6.2-stable_win64_console.exe --path . res://scenes/validation/visual_reanim_native_actual_demo.tscn
##
## Controls:
##   Space  pause/resume simulation time (phase must freeze)
##   1/2/3  simulation speed 0.5x / 1x / 2x
##   S      trigger an extra volley on all shooters
##   B      trigger every flourish immediately
##   Z      toggle mushrooms between sleeping and idle

const NATIVE_ROOT := "res://local_extensions/classic_original_assets/generated/native"
const IDLE_PHASE_SECONDS := 3.0
const COMBAT_PHASE_SECONDS := 6.0
const FIRE_INTERVAL_SECONDS := 1.5
const FLOURISH_INTERVAL_SECONDS := 2.4
const ANCHOR_MARKER_RADIUS := 4.0
const ROW_YS: Array[float] = [170.0, 350.0, 530.0]
const COL_XS: Array[float] = [90.0, 218.0, 346.0, 474.0, 602.0, 730.0]

## Row-major roster; shoot -> joins volleys, flourish -> cycled one-shots,
## sleeper -> toggles sleeping/idle with Z, anchors -> drawn as markers.
const ROSTER: Array[Dictionary] = [
	{"id": "peashooter", "shoot": true, "anchors": ["muzzle"]},
	{"id": "repeater", "shoot": true, "anchors": ["muzzle"]},
	{"id": "snowpea", "shoot": true, "anchors": ["muzzle"]},
	{"id": "gatlingpea", "shoot": true, "anchors": ["muzzle"]},
	{"id": "splitpea", "shoot": true, "anchors": ["muzzle"]},
	{"id": "threepeater", "shoot": true, "anchors": ["muzzle1", "muzzle2", "muzzle3"]},
	{"id": "puffshroom", "shoot": true, "sleeper": true, "flourish": ["blink"]},
	{"id": "fumeshroom", "shoot": true, "sleeper": true, "flourish": ["blink"]},
	{"id": "seashroom", "shoot": true, "sleeper": true},
	{"id": "scaredyshroom", "shoot": true, "sleeper": true, "flourish": ["cower", "grow"]},
	{"id": "sunflower", "flourish": ["blink"]},
	{"id": "chomper", "flourish": ["bite", "swallow"], "anchors": ["mouth", "bite_target"]},
	{"id": "wallnut", "flourish": ["blink_twice", "blink_twitch", "blink_thrice"]},
	{"id": "tallnut", "flourish": ["blink_twice", "blink_thrice"]},
	{"id": "pumpkin"},
	{"id": "lilypad", "flourish": ["blink"]},
	{"id": "flowerpot"},
	{"id": "squash", "flourish": ["look_left", "look_right", "jump_up", "jump_down"]},
]

var _status_label: Label = null
var _entries: Array[Dictionary] = []
var _time_scale := 1.0
var _paused := false
var _phase: StringName = &"idle"
var _phase_elapsed := 0.0
var _fire_elapsed := 0.0
var _flourish_elapsed := 0.0
var _shoot_count := 0
var _flourish_count := 0
var _mushrooms_sleeping := false
var _missing_ids: Array[String] = []


func _ready() -> void:
	_build_backdrop()
	_build_status_label()
	GameState.reset_simulation_time()
	for index in ROSTER.size():
		var config := ROSTER[index]
		var at := Vector2(COL_XS[index % COL_XS.size()], ROW_YS[floori(float(index) / float(COL_XS.size()))])
		var actor := _spawn_actor(String(config["id"]), at)
		if actor == null:
			_missing_ids.append(String(config["id"]))
			continue
		_entries.append({
			"id": String(config["id"]),
			"actor": actor,
			"shoot": bool(config.get("shoot", false)),
			"sleeper": bool(config.get("sleeper", false)),
			"flourish": config.get("flourish", []),
			"flourish_index": 0,
			"anchors": config.get("anchors", []),
		})
		_build_name_label(String(config["id"]), at)
	_update_status()


func _process(delta: float) -> void:
	if _entries.is_empty():
		return
	if not _paused:
		var step := delta * _time_scale
		GameState.advance_time(step)
		_advance_combat_cycle(step)
		_advance_flourish_cycle(step)
	_update_status()
	queue_redraw()


## Loops idle rest and combat volleys, mirroring in-game pacing: shooters sit
## idle, then fire repeatedly at the original cadence while a target is held.
func _advance_combat_cycle(step: float) -> void:
	_phase_elapsed += step
	if _phase == &"idle":
		if _phase_elapsed >= IDLE_PHASE_SECONDS:
			_enter_phase(&"combat")
			_trigger_shoot()
		return
	_fire_elapsed += step
	if _fire_elapsed >= FIRE_INTERVAL_SECONDS:
		_fire_elapsed = 0.0
		_trigger_shoot()
	if _phase_elapsed >= COMBAT_PHASE_SECONDS:
		_enter_phase(&"idle")


## Non-shoot plants cycle their one-shot flourishes; finished one-shots route
## back through the def (action_next_states or the current state).
func _advance_flourish_cycle(step: float) -> void:
	_flourish_elapsed += step
	if _flourish_elapsed >= FLOURISH_INTERVAL_SECONDS:
		_flourish_elapsed = 0.0
		_trigger_flourish()


func _enter_phase(phase: StringName) -> void:
	_phase = phase
	_phase_elapsed = 0.0
	_fire_elapsed = 0.0


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	match key.keycode:
		KEY_SPACE:
			_paused = not _paused
		KEY_1:
			_time_scale = 0.5
		KEY_2:
			_time_scale = 1.0
		KEY_3:
			_time_scale = 2.0
		KEY_S:
			_trigger_shoot()
		KEY_B:
			_trigger_flourish()
		KEY_Z:
			_toggle_mushroom_sleep()


func _draw() -> void:
	for row_y in ROW_YS:
		draw_line(Vector2(30.0, row_y), Vector2(770.0, row_y), Color(0.35, 0.5, 0.35), 2.0)
	for entry in _entries:
		var actor := entry["actor"] as Node2D
		if actor == null or not actor.has_method("get_anchor"):
			continue
		for anchor_name in entry["anchors"]:
			var anchor := actor.call("get_anchor", StringName(anchor_name)) as Node2D
			if anchor == null:
				continue
			var local := to_local(anchor.global_position)
			draw_circle(local, ANCHOR_MARKER_RADIUS, Color(1.0, 0.35, 0.2, 0.9))
			draw_line(local - Vector2(ANCHOR_MARKER_RADIUS, 0.0), local + Vector2(ANCHOR_MARKER_RADIUS, 0.0), Color.WHITE, 1.0)
			draw_line(local - Vector2(0.0, ANCHOR_MARKER_RADIUS), local + Vector2(0.0, ANCHOR_MARKER_RADIUS), Color.WHITE, 1.0)


func _spawn_actor(plant_id: String, at: Vector2) -> Node2D:
	var scene_path := "%s/%s/actor.tscn" % [NATIVE_ROOT, plant_id]
	if not ResourceLoader.exists(scene_path):
		return null
	var packed := load(scene_path) as PackedScene
	if packed == null:
		return null
	var actor := packed.instantiate() as Node2D
	if actor == null:
		return null
	actor.position = at
	add_child(actor)
	if actor.has_method("get_part_count") and int(actor.call("get_part_count")) <= 0:
		actor.queue_free()
		return null
	return actor


func _trigger_shoot() -> void:
	_shoot_count += 1
	for entry in _entries:
		if not entry["shoot"]:
			continue
		if entry["sleeper"] and _mushrooms_sleeping:
			continue
		var actor := entry["actor"] as Node2D
		if actor.has_method("play_action"):
			actor.call("play_action", &"shoot")


func _trigger_flourish() -> void:
	for entry in _entries:
		var flourish: Array = entry["flourish"]
		if flourish.is_empty():
			continue
		var actor := entry["actor"] as Node2D
		if not actor.has_method("play_action"):
			continue
		var action := StringName(flourish[int(entry["flourish_index"]) % flourish.size()])
		if actor.call("play_action", action):
			entry["flourish_index"] = int(entry["flourish_index"]) + 1
			_flourish_count += 1


## Z toggles the four mushrooms between their sleeping and idle states to
## show per-state clip forwarding on the same body part.
func _toggle_mushroom_sleep() -> void:
	_mushrooms_sleeping = not _mushrooms_sleeping
	var target: StringName = &"sleeping" if _mushrooms_sleeping else &"idle"
	for entry in _entries:
		if not entry["sleeper"]:
			continue
		var actor := entry["actor"] as Node2D
		if actor.has_method("play_state"):
			actor.call("play_state", target)


func _build_backdrop() -> void:
	var background := ColorRect.new()
	background.color = Color(0.12, 0.14, 0.16)
	background.size = Vector2(800.0, 600.0)
	background.z_index = -10
	add_child(background)


func _build_name_label(plant_id: String, at: Vector2) -> void:
	var label := Label.new()
	label.text = plant_id
	label.position = at + Vector2(-40.0, 6.0)
	label.size = Vector2(80.0, 14.0)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 10)
	label.add_theme_color_override("font_color", Color(0.7, 0.8, 0.7))
	add_child(label)


func _build_status_label() -> void:
	_status_label = Label.new()
	_status_label.position = Vector2(16.0, 8.0)
	_status_label.add_theme_font_size_override("font_size", 12)
	_status_label.add_theme_color_override("font_color", Color(0.9, 0.95, 0.9))
	_status_label.z_index = 10
	add_child(_status_label)


func _update_status() -> void:
	var text := "Native reanim runtime - T6 full roster (%d/18 plants, ReanimActor + ReanimActorDef + ReanimData)\n" % _entries.size() \
		+ "sim_time=%.2f  speed=%.1fx  %s  phase=%s  volleys=%d  flourishes=%d  mushrooms=%s\n" % [
			GameState.current_time,
			_time_scale,
			"PAUSED" if _paused else "running",
			String(_phase),
			_shoot_count,
			_flourish_count,
			"sleeping" if _mushrooms_sleeping else "idle",
		] \
		+ "[Space] pause  [1/2/3] speed  [S] volley  [B] flourish  [Z] mushroom sleep   markers = get_anchor()"
	if not _missing_ids.is_empty():
		text += "\nMISSING native actors: %s (regenerate via reanim_generate_composites.gd --native-only true)" % ", ".join(_missing_ids)
	_status_label.text = text
