extends RefCounted
class_name BoardSlotCatalog

const SLOT_TYPE_DEFAULT_TAGS := {
	&"ground": ["ground", "supports_primary"],
	&"water": ["water"],
	&"roof": ["roof"],
	&"air_only": ["air_only", "supports_air"],
}


static func is_known_slot_type(slot_type: StringName) -> bool:
	return SLOT_TYPE_DEFAULT_TAGS.has(slot_type)


static func default_tags_for(slot_type: StringName) -> PackedStringArray:
	if not SLOT_TYPE_DEFAULT_TAGS.has(slot_type):
		return PackedStringArray()
	return PackedStringArray(Array(SLOT_TYPE_DEFAULT_TAGS[slot_type]))


static func list_slot_types() -> PackedStringArray:
	var slot_types := PackedStringArray()
	for slot_type in SLOT_TYPE_DEFAULT_TAGS.keys():
		slot_types.append(String(slot_type))
	slot_types.sort()
	return slot_types
