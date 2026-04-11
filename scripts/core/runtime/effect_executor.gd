extends RefCounted
class_name EffectExecutor

const EffectResultRef = preload("res://scripts/core/runtime/effect_result.gd")

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

	var strategy_result: Variant = strategy.call(context, node.params, node)
	var is_effect_result: bool = strategy_result != null and strategy_result is RefCounted and strategy_result.get_script() == EffectResultRef
	if is_effect_result:
		result = strategy_result
	else:
		result.success = bool(strategy_result)

	DebugService.record_effect_execution(node.effect_id, context, depth, result)

	if result.terminated:
		return result

	var child_keys: Array = node.children.keys()
	child_keys.sort()
	for child_key: Variant in child_keys:
		var child = node.children[child_key]
		if child == null or child.effect_id == &"null":
			continue

		var child_context: Variant = context.duplicate_deep()
		child_context.depth = chain_depth + 1
		child_context.runtime["depth"] = child_context.depth
		var child_result: Variant = execute_node(child, child_context, depth + 1)
		if not child_result.success:
			result.success = false
			for note: String in child_result.notes:
				result.notes.append(note)
		if child_result.terminated:
			return child_result

	return result
