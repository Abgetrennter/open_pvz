extends Node2D
## Windowed demo for the native reanim runtime (T0-T3 spike output).
##
## Loads the generated native actors (ReanimActor + ReanimActorDef + ReanimData)
## for ThreePeater (composite: body + 3 hosted heads), Peashooter (body +
## hosted head) and Sunflower (body + blink overlay part), drives
## GameState.current_time locally, loops a combat cycle (idle rest ->
## continuous volleys at the original 1.5s cadence -> idle) plus a periodic
## blink, and draws anchor markers. Demo-only; not registered as a validation
## scenario and never touches production profiles.
##
## Run (windowed):
##   & .\Godot_v4.6.2-stable_win64_console.exe --path . res://scenes/validation/visual_reanim_native_actual_demo.tscn
##
## Controls:
##   Space  pause/resume simulation time (phase must freeze)
##   1/2/3  simulation speed 0.5x / 1x / 2x
##   S      trigger an extra shoot action on both actors
##   B      trigger an extra blink on the sunflower

const THREEPEATER_ACTOR_PATH := "res://local_extensions/classic_original_assets/generated/native/threepeater/actor.tscn"
const PEASHOOTER_ACTOR_PATH := "res://local_extensions/classic_original_assets/generated/native/peashooter/actor.tscn"
const SUNFLOWER_ACTOR_PATH := "res://local_extensions/classic_original_assets/generated/native/sunflower/actor.tscn"
const GROUND_Y := 360.0
const THREEPEATER_POSITION := Vector2(200.0, GROUND_Y)
const PEASHOOTER_POSITION := Vector2(440.0, GROUND_Y)
const SUNFLOWER_POSITION := Vector2(640.0, GROUND_Y)
const IDLE_PHASE_SECONDS := 3.0
const COMBAT_PHASE_SECONDS := 6.0
const FIRE_INTERVAL_SECONDS := 1.5
const BLINK_INTERVAL_SECONDS := 2.4
const THREEPEATER_ANCHORS: Array[StringName] = [&"muzzle1", &"muzzle2", &"muzzle3"]
const PEASHOOTER_ANCHORS: Array[StringName] = [&"muzzle"]
const ANCHOR_MARKER_RADIUS := 5.0

var _status_label: Label = null
var _actors: Array[Node2D] = []
var _anchor_sets: Array = []
var _time_scale := 1.0
var _paused := false
var _phase: StringName = &"idle"
var _phase_elapsed := 0.0
var _fire_elapsed := 0.0
var _shoot_count := 0
var _sunflower: Node2D = null
var _blink_elapsed := 0.0
var _blink_count := 0


func _ready() -> void:
	_build_backdrop()
	_build_status_label()
	GameState.reset_simulation_time()
	var threepeater := _spawn_actor(THREEPEATER_ACTOR_PATH, THREEPEATER_POSITION, THREEPEATER_ANCHORS)
	var peashooter := _spawn_actor(PEASHOOTER_ACTOR_PATH, PEASHOOTER_POSITION, PEASHOOTER_ANCHORS)
	_sunflower = _spawn_actor(SUNFLOWER_ACTOR_PATH, SUNFLOWER_POSITION, [])
	if threepeater == null or peashooter == null or _sunflower == null:
		_status_label.text = "Native actors missing. Regenerate them first:\n" \
			+ "reanim_generate_composites.gd --manifest .../reanim_visual_manifest.local.json --native-only true"
		return
	_update_status()


func _process(delta: float) -> void:
	if _actors.is_empty():
		return
	if not _paused:
		var step := delta * _time_scale
		GameState.advance_time(step)
		_advance_combat_cycle(step)
		_advance_blink_cycle(step)
	_update_status()
	queue_redraw()


## Sunflowers blink periodically regardless of combat, mirroring the legacy
## overlay demo cadence; the blink action is a one-shot clip on the blink part.
func _advance_blink_cycle(step: float) -> void:
	_blink_elapsed += step
	if _blink_elapsed >= BLINK_INTERVAL_SECONDS:
		_blink_elapsed = 0.0
		_trigger_blink()


## Loops idle rest and combat volleys, mirroring in-game pacing: plants sit
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
			_trigger_blink()


func _draw() -> void:
	draw_line(Vector2(40.0, GROUND_Y), Vector2(760.0, GROUND_Y), Color(0.35, 0.5, 0.35), 2.0)
	for anchor_set in _anchor_sets:
		for anchor_name in anchor_set["names"]:
			var actor := anchor_set["actor"] as Node2D
			if actor == null or not actor.has_method("get_anchor"):
				continue
			var anchor := actor.call("get_anchor", anchor_name) as Node2D
			if anchor == null:
				continue
			var local := to_local(anchor.global_position)
			draw_circle(local, ANCHOR_MARKER_RADIUS, Color(1.0, 0.35, 0.2, 0.9))
			draw_line(local - Vector2(ANCHOR_MARKER_RADIUS, 0.0), local + Vector2(ANCHOR_MARKER_RADIUS, 0.0), Color.WHITE, 1.0)
			draw_line(local - Vector2(0.0, ANCHOR_MARKER_RADIUS), local + Vector2(0.0, ANCHOR_MARKER_RADIUS), Color.WHITE, 1.0)


func _spawn_actor(scene_path: String, at: Vector2, anchor_names: Array[StringName]) -> Node2D:
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
	_actors.append(actor)
	_anchor_sets.append({"actor": actor, "names": anchor_names})
	return actor


func _trigger_shoot() -> void:
	_shoot_count += 1
	for actor in _actors:
		if actor.has_method("play_action") and actor != _sunflower:
			actor.call("play_action", &"shoot")


func _trigger_blink() -> void:
	if _sunflower != null and _sunflower.has_method("play_action") and _sunflower.call("play_action", &"blink"):
		_blink_count += 1


func _build_backdrop() -> void:
	var background := ColorRect.new()
	background.color = Color(0.12, 0.14, 0.16)
	background.size = Vector2(800.0, 600.0)
	background.z_index = -10
	add_child(background)


func _build_status_label() -> void:
	_status_label = Label.new()
	_status_label.position = Vector2(16.0, 12.0)
	_status_label.add_theme_color_override("font_color", Color(0.9, 0.95, 0.9))
	add_child(_status_label)


func _update_status() -> void:
	_status_label.text = "Native reanim runtime demo (ReanimActor + ReanimActorDef + ReanimData)\n" \
		+ "sim_time=%.2f  speed=%.1fx  %s  phase=%s  shots=%d  blinks=%d\n" % [
			GameState.current_time,
			_time_scale,
			"PAUSED (phase frozen)" if _paused else "running",
			String(_phase),
			_shoot_count,
			_blink_count,
		] \
		+ "cycle: idle %.0fs -> volleys every %.1fs for %.0fs -> repeat   blink every %.1fs\n" % [
			IDLE_PHASE_SECONDS,
			FIRE_INTERVAL_SECONDS,
			COMBAT_PHASE_SECONDS,
			BLINK_INTERVAL_SECONDS,
		] \
		+ "left: threepeater (body + 3 hosted heads)   mid: peashooter (body + hosted head)   right: sunflower (body + blink part)\n" \
		+ "[Space] pause  [1/2/3] speed 0.5/1/2x  [S] shoot  [B] blink   markers = get_anchor() muzzles"
