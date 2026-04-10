extends RefCounted
class_name EffectExecutor

const EffectResultRef = preload("res://scripts/core/runtime/effect_result.gd")

const MAX_DEPTH := 5


static func execute_node(node, context, depth: int = 0) -> Variant:
	var result: Variant = EffectResultRef.new()
	if node == null or node.effect_id == &"null":
		return result

	if depth > MAX_DEPTH:
		result.success = false
		result.terminated = true
		result.notes.append("Effect chain depth exceeded.")
		return result

	var strategy: Callable = EffectRegistry.get_strategy(node.effect_id)
	if not strategy.is_valid():
		result.success = false
		result.notes.append("Missing strategy for %s." % [String(node.effect_id)])
		return result

	DebugService.record_effect_execution(node.effect_id, context, depth)

	var strategy_result: Variant = strategy.call(context, node.params, node)
	if strategy_result != null and strategy_result.get_script() == EffectResultRef:
		result = strategy_result
	else:
		result.success = bool(strategy_result)

	if result.terminated:
		return result

	for child_key: Variant in node.children.keys():
		var child = node.children[child_key]
		if child == null or child.effect_id == &"null":
			continue

		var child_context: Variant = context.duplicate_deep()
		child_context.runtime["depth"] = int(context.runtime.get("depth", 1)) + 1
		var child_result: Variant = execute_node(child, child_context, depth + 1)
		if child_result.terminated:
			return child_result

	return result
