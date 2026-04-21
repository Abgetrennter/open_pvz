extends Resource
class_name CombatMechanic

const FAMILY_TRIGGER := &"Trigger"
const FAMILY_TARGETING := &"Targeting"
const FAMILY_EMISSION := &"Emission"
const FAMILY_TRAJECTORY := &"Trajectory"
const FAMILY_HIT_POLICY := &"HitPolicy"
const FAMILY_PAYLOAD := &"Payload"
const FAMILY_STATE := &"State"
const FAMILY_LIFECYCLE := &"Lifecycle"
const FAMILY_PLACEMENT := &"Placement"
const FAMILY_CONTROLLER := &"Controller"

const ALLOWED_FAMILIES := [
	"Trigger",
	"Targeting",
	"Emission",
	"Trajectory",
	"HitPolicy",
	"Payload",
	"State",
	"Lifecycle",
	"Placement",
	"Controller",
]

@export var mechanic_id: StringName = StringName()
@export var display_name := ""
@export var family: StringName = StringName()
@export var type_id: StringName = StringName()
@export var enabled := true
@export var priority := 100
@export var tags: PackedStringArray = PackedStringArray()
@export var params: Dictionary = {}
