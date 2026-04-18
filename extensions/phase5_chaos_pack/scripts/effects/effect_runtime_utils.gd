extends RefCounted


static func resolve_target(context, target_mode: StringName) -> Node:
	match target_mode:
		&"source":
			return context.source_node
		&"owner":
			return context.owner_entity
		&"context_target":
			return context.target_node
		&"event_source":
			return context.core.get("source_node", context.source_node)
		&"event_target":
			return context.core.get("target_node", context.target_node)
		_:
			return context.target_node


static func node_ground_position(node: Node) -> Vector2:
	if node == null or not (node is Node2D):
		return Vector2.ZERO
	if node.has_method("get_ground_position"):
		return Vector2(node.call("get_ground_position"))
	return (node as Node2D).global_position


static func extract_team(node: Node) -> StringName:
	if node == null:
		return StringName()
	var value: Variant = node.get("team")
	return StringName(value) if value is String or value is StringName else StringName()


static func extract_entity_id(node: Node) -> int:
	if node == null or not node.has_method("get_entity_id"):
		return -1
	return int(node.call("get_entity_id"))


static func append_unique_tag(tags: PackedStringArray, tag: String) -> PackedStringArray:
	if not tags.has(tag):
		tags.append(tag)
	return tags
