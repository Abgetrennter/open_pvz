extends Node
class_name EffectDelayRunner

var _remaining_time := 0.0
var _callback: Callable = Callable()


func setup(delay: float, callback: Callable) -> void:
	_remaining_time = maxf(delay, 0.0)
	_callback = callback
	process_mode = Node.PROCESS_MODE_PAUSABLE
	set_process(true)


func _process(delta: float) -> void:
	_remaining_time -= delta
	if _remaining_time > 0.0:
		return
	set_process(false)
	if _callback.is_valid():
		_callback.call()
	queue_free()
