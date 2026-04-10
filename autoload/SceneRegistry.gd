extends Node

const MAIN_SCENE := "res://scenes/main/main.tscn"

var _scene_cache: Dictionary = {}


func load_scene(path: String) -> PackedScene:
	if _scene_cache.has(path):
		return _scene_cache[path]

	var scene := load(path) as PackedScene
	if scene != null:
		_scene_cache[path] = scene
	return scene
