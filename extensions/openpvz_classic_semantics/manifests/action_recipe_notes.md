# Classic Reanim Action Recipe Notes

Action Recipe is visual choreography. It does not decide hit, damage, cooldown, target death, or entity movement.

The first supported operation set should stay intentionally small:

- `play_state`
- `play_action`
- `part_action`
- `root_motion`
- `emit_local_cue`
- `spawn_world_fx`
- `return_home`
- `hide_actor`

Part Slot names should describe replaceable visual roles such as `body`, `head`, `upper_head`, `middle_head`, `lower_head`, `blink_overlay`, and `muzzle`, not source reanim track names.

