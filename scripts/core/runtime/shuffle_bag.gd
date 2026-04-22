extends RefCounted
class_name ShuffleBag

var _items: Array = []
var _bag: Array = []
var _index: int = 0
var _rng: RandomNumberGenerator


func _init(items: Array = [], seed_value: int = 0) -> void:
	_items = items.duplicate()
	_rng = RandomNumberGenerator.new()
	_rng.seed = seed_value
	_refill()


func next() -> Variant:
	if _items.is_empty():
		return null
	if _index >= _bag.size():
		_refill()
	var item: Variant = _bag[_index]
	_index += 1
	return item


func get_items() -> Array:
	return _items.duplicate()


func get_remaining() -> int:
	return maxi(0, _bag.size() - _index)


func get_cycle_count() -> int:
	if _items.is_empty():
		return 0
	return _index / _items.size()


func _refill() -> void:
	_bag = _items.duplicate()
	_index = 0
	for i in range(_bag.size() - 1, 0, -1):
		var j := _rng.randi_range(0, i)
		var temp: Variant = _bag[i]
		_bag[i] = _bag[j]
		_bag[j] = temp
