extends RefCounted
class_name EffectExecutor

const EffectResultRef = preload("res://scripts/core/runtime/effect_result.gd")
const ProtocolValidatorRef = preload("res://scripts/core/runtime/protocol_validator.gd")

const MAX_DEPTH := 5


static func execute_node(node, context, depth: int = 0) -> Variant:
	var result: Variant = EffectResultRef.new()
	if node == null or node.effect_id == &"null":
		return result

	var chain_depth := int(context.runtime.get("depth", context.depth))
	if chain_depth > MAX_DEPTH or depth > MAX_DEPTH:
		result.success = false
		result.terminated = true
		result.notes.append("Effect chain depth exceeded.")
		return result

	var strategy: Callable = EffectRegistry.get_strategy(node.effect_id)
	if not strategy.is_valid():
		result.success = false
		result.notes.append("Missing strategy for %s." % [String(node.effect_id)])
		DebugService.record_effect_execution(node.effect_id, context, depth, result)
		return result

	var normalized_node: Dictionary = ProtocolValidatorRef.normalize_effect_node(node)
	if not bool(normalized_node.get("valid", false)):
		result.success = false
		for error in PackedStringArray(normalized_node.get("errors", PackedStringArray())):
			result.notes.append(error)
			if DebugService.has_method("record_protocol_issue"):
				DebugService.record_protocol_issue(&"effect_node", error, &"error")
		DebugService.record_effect_execution(node.effect_id, context, depth, result)
		return result

	var strategy_result: Variant = strategy.call(context, Dictionary(normalized_node.get("params", {})), node)
	var is_effect_result: bool = strategy_result != null and strategy_result is RefCounted and strategy_result.get_script() == EffectResultRef
	if is_effect_result:
		result = strategy_result
	else:
		result.success = bool(strategy_result)

	DebugService.record_effect_execution(node.effect_id, context, depth, result)

	if result.terminated:
		return result

	return result
