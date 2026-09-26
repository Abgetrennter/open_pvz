param(
	[string]$GodotExe = "",
	[string]$Batch = "all",      # all | m1 | m2a | m2b | m2c
	[switch]$SkipStageA
)
# Drives run_reanim_migrate_one.ps1 for the 26 remaining plants. Each entry:
#   id -> @{ source=...; native=<JSON config> }
# SkipStageA forwards to the per-plant wrapper (Stage A already run in batch).

$ErrorActionPreference = 'Stop'
$here = $PSScriptRoot

# Blink/eye overlay glob patterns shared by every body+blink plant. The body part
# excludes these (so it never renders the blink sprites), the blink part includes
# ONLY these. Verified against the track-name survey of all 26 plants.
$BlinkPatterns = @('*blink*', '*eyebrow*', '*eyes*')

function Native-BodyOnly($rootOffset, $states, $actions, $stateAnimMap, $initialState = 'idle', $nextStates = @{}) {
	$p = @{
		root_offset = $rootOffset
		initial_state = $initialState
		states = $states
		actions = $actions
		state_animation_map = $stateAnimMap
	}
	if ($nextStates.Count -gt 0) { $p.action_next_states = $nextStates }
	return $p | ConvertTo-Json -Depth 10 -Compress
}

function Native-BodyBlink($rootOffset, $states, $actions, $stateAnimMap, $hostTrack = 'anim_face', $initialState = 'idle', $nextStates = @{}, $clipRates = @{}) {
	# Two parts: body (excludes blink patterns) + blink (includes blink patterns,
	# hosted on the body's face/idle track). Mirrors sunflower/wallnut.
	$parts = @(
		@{ id = 'body'; initial_clip = $initialState; loop = $true; render_order = 0; track_visibility = @{ mode = 'exclude'; patterns = $BlinkPatterns } }
		@{ id = 'blink'; initial_clip = $initialState; loop = $true; host_part_id = 'body'; host_track = $hostTrack; render_order = 1; track_visibility = @{ mode = 'include'; patterns = $BlinkPatterns } }
	)
	$p = @{
		root_offset = $rootOffset
		initial_state = $initialState
		parts = $parts
		states = $states
		actions = $actions
		state_animation_map = $stateAnimMap
	}
	if ($nextStates.Count -gt 0) { $p.action_next_states = $nextStates }
	if ($clipRates.Count -gt 0) { $p.clip_rates = $clipRates }
	return $p | ConvertTo-Json -Depth 10 -Compress
}

# --- M1 remainder (body-only) ---
$m1 = [ordered]@{
	'blover'    = @{ source = 'Blover.reanim'; native = Native-BodyOnly @(-43,-70) @{ idle = @{ body = 'idle' }; ready = @{ body = 'idle' } } @{ blow = @{ body = 'blow' }; loop = @{ body = 'loop' } } @{ idle = 'idle' } }
	'doomshroom' = @{ source = 'Doomshroom.reanim'; native = Native-BodyOnly @(-44,-90) @{ idle = @{ body = 'idle' }; ready = @{ body = 'idle' }; sleeping = @{ body = 'sleep' } } @{ explode = @{ body = 'explode' } } @{ idle = 'idle'; sleeping = 'sleep' } 'idle' @{ explode = 'idle' } }
}

# --- M2-a mushroom blink (body+blink, sleeper) ---
# states: idle/sleeping/attacking (where clip exists); actions: shoot/blink
$m2a = [ordered]@{
	'gloomshroom' = @{ source = 'GloomShroom.reanim'; native = Native-BodyBlink @(-44,-80) @{ idle = @{ body = 'idle'; blink = 'idle' }; ready = @{ body = 'idle'; blink = 'idle' }; sleeping = @{ body = 'sleep'; blink = 'idle' }; attacking = @{ body = 'shooting'; blink = 'idle' } } @{ attack = @{ blink = 'blink' }; fire = @{ blink = 'blink' }; shoot = @{ body = 'shooting' }; blink = @{ blink = 'blink' } } @{ idle = 'idle'; sleeping = 'sleep'; attacking = 'shooting' } }
	'iceshroom'   = @{ source = 'IceShroom.reanim'; native = Native-BodyBlink @(-40,-78) @{ idle = @{ body = 'idle'; blink = 'idle' }; ready = @{ body = 'idle'; blink = 'idle' }; sleeping = @{ body = 'sleep'; blink = 'idle' } } @{ attack = @{ blink = 'blink' }; fire = @{ blink = 'blink' }; blink = @{ blink = 'blink' } } @{ idle = 'idle'; sleeping = 'sleep' } }
	'sunshroom'   = @{ source = 'SunShroom.reanim'; native = Native-BodyBlink @(-40,-78) @{ idle = @{ body = 'idle'; blink = 'idle' }; bigidle = @{ body = 'bigidle'; blink = 'idle' }; ready = @{ body = 'idle'; blink = 'idle' }; sleeping = @{ body = 'sleep'; blink = 'idle' }; bigsleep = @{ body = 'bigsleep'; blink = 'idle' } } @{ grow = @{ body = 'grow' }; blink = @{ blink = 'blink' } } @{ idle = 'idle'; bigidle = 'bigidle'; sleeping = 'sleep'; bigsleep = 'bigsleep' } 'anim_face' 'idle' @{ grow = 'bigidle' } }
	'magnetshroom' = @{ source = 'Magnetshroom.reanim'; native = Native-BodyBlink @(-40,-78) @{ idle = @{ body = 'idle'; blink = 'idle' }; ready = @{ body = 'idle'; blink = 'idle' }; sleeping = @{ body = 'sleep'; blink = 'idle' }; nonactive = @{ body = 'nonactive_idle'; blink = 'idle' }; attacking = @{ body = 'shooting'; blink = 'idle' } } @{ attack = @{ blink = 'blink' }; fire = @{ blink = 'blink' }; shoot = @{ body = 'shooting' }; blink = @{ blink = 'blink' } } @{ idle = 'idle'; sleeping = 'sleep'; nonactive = 'nonactive_idle'; attacking = 'shooting' } }
	'spikeweed'   = @{ source = 'Caltrop.reanim'; native = Native-BodyBlink @(-40,-50) @{ idle = @{ body = 'idle'; blink = 'idle' }; ready = @{ body = 'idle'; blink = 'idle' }; attacking = @{ body = 'attack'; blink = 'idle' } } @{ attack = @{ body = 'attack' }; fire = @{ body = 'attack' }; blink = @{ blink = 'blink' } } @{ idle = 'idle'; attacking = 'attack' } }
	'spikerock'   = @{ source = 'SpikeRock.reanim'; native = Native-BodyBlink @(-40,-50) @{ idle = @{ body = 'idle'; blink = 'idle' }; ready = @{ body = 'idle'; blink = 'idle' }; attacking = @{ body = 'attack'; blink = 'idle' } } @{ attack = @{ body = 'attack' }; fire = @{ body = 'attack' }; blink = @{ blink = 'blink' } } @{ idle = 'idle'; attacking = 'attack' } }
}

# --- M2-b shooter / pult (body+blink, shoot action) ---
$shootStates = @{ idle = @{ body = 'idle'; blink = 'idle' }; ready = @{ body = 'idle'; blink = 'idle' }; attacking = @{ body = 'shooting'; blink = 'idle' } }
$shootStatesNoAttack = @{ idle = @{ body = 'idle'; blink = 'idle' }; ready = @{ body = 'idle'; blink = 'idle' } }
function shootActions($clip = 'shooting') { return @{ attack = @{ body = $clip }; fire = @{ body = $clip }; shoot = @{ body = $clip }; blink = @{ blink = 'blink' } } }
function shootMap() { return @{ idle = 'idle'; attacking = 'shooting' } }

$m2b = [ordered]@{
	'cabbagepult' = @{ source = 'Cabbagepult.reanim'; native = Native-BodyBlink @(-44,-90) $shootStates (shootActions) (shootMap) }
	'kernelpult'  = @{ source = 'Cornpult.reanim'; native = Native-BodyBlink @(-44,-90) $shootStates (shootActions) (shootMap) }
	'melonpult'   = @{ source = 'Melonpult.reanim'; native = Native-BodyBlink @(-44,-90) $shootStates (shootActions) (shootMap) }
	'wintermelon' = @{ source = 'WinterMelon.reanim'; native = Native-BodyBlink @(-44,-90) $shootStates (shootActions) (shootMap) }
	'starfruit'   = @{ source = 'Starfruit.reanim'; native = Native-BodyBlink @(-40,-78) @{ idle = @{ body = 'idle'; blink = 'idle' }; ready = @{ body = 'idle'; blink = 'idle' }; attacking = @{ body = 'shoot'; blink = 'idle' } } @{ attack = @{ body = 'shoot' }; fire = @{ body = 'shoot' }; shoot = @{ body = 'shoot' }; blink = @{ blink = 'blink' } } @{ idle = 'idle'; attacking = 'shoot' } }
	'cattail'     = @{ source = 'Cattail.reanim'; native = Native-BodyBlink @(-40,-80) $shootStates (shootActions) (shootMap) }
	'cobcannon'   = @{ source = 'CobCannon.reanim'; native = Native-BodyBlink @(-44,-90) @{ idle = @{ body = 'idle'; blink = 'idle' }; ready = @{ body = 'idle'; blink = 'idle' }; unarmed = @{ body = 'unarmed_idle'; blink = 'idle' }; attacking = @{ body = 'shooting'; blink = 'idle' } } @{ attack = @{ body = 'shooting' }; fire = @{ body = 'shooting' }; shoot = @{ body = 'shooting' }; charge = @{ body = 'charge' }; blink = @{ blink = 'blink' } } @{ idle = 'idle'; unarmed = 'unarmed_idle'; attacking = 'shooting' } }
	'cactus'      = @{ source = 'Cactus.reanim'; native = Native-BodyBlink @(-40,-80) @{ idle = @{ body = 'idle'; blink = 'idle' }; ready = @{ body = 'idle'; blink = 'idle' }; idlehigh = @{ body = 'idlehigh'; blink = 'idle' }; attacking = @{ body = 'shooting'; blink = 'idle' }; attackinghigh = @{ body = 'shootinghigh'; blink = 'idle' } } @{ attack = @{ body = 'shooting' }; fire = @{ body = 'shooting' }; shoot = @{ body = 'shooting' }; rise = @{ body = 'rise' }; lower = @{ body = 'lower' }; blink = @{ blink = 'blink' } } @{ idle = 'idle'; idlehigh = 'idlehigh'; attacking = 'shooting'; attackinghigh = 'shootinghigh' } }
	'goldmagnet'  = @{ source = 'GoldMagnet.reanim'; native = Native-BodyBlink @(-40,-78) $shootStatesNoAttack @{ attract = @{ body = 'attract' }; blink = @{ blink = 'blink' } } @{ idle = 'idle' } }
}

# --- M2-c support (body+blink, mostly non-shooter) ---
$m2c = [ordered]@{
	'garlic'       = @{ source = 'Garlic.reanim'; native = Native-BodyBlink @(-40,-78) @{ idle = @{ body = 'idle'; blink = 'idle' }; ready = @{ body = 'idle'; blink = 'idle' } } @{ blink = @{ blink = 'blink' } } @{ idle = 'idle' } }
	'plantern'     = @{ source = 'Plantern.reanim'; native = Native-BodyBlink @(-40,-78) @{ idle = @{ body = 'idle'; blink = 'idle' }; ready = @{ body = 'idle'; blink = 'idle' } } @{ blink = @{ blink = 'blink' } } @{ idle = 'idle' } }
	'torchwood'    = @{ source = 'Torchwood.reanim'; native = Native-BodyBlink @(-40,-78) @{ idle = @{ body = 'idle'; blink = 'idle' }; ready = @{ body = 'idle'; blink = 'idle' } } @{ blink = @{ blink = 'blink' } } @{ idle = 'idle' } }
	'marigold'     = @{ source = 'Marigold.reanim'; native = Native-BodyBlink @(-40,-78) @{ idle = @{ body = 'idle'; blink = 'idle' }; ready = @{ body = 'idle'; blink = 'idle' } } @{ blink = @{ blink = 'blink' } } @{ idle = 'idle' } }
	'twinsunflower' = @{ source = 'TwinSunflower.reanim'; native = Native-BodyBlink @(-42,-96) @{ idle = @{ body = 'idle'; blink = 'idle' }; ready = @{ body = 'idle'; blink = 'idle' } } @{ blink = @{ blink = 'blink' }; blink2 = @{ blink = 'blink2' } } @{ idle = 'idle' } }
	'jalapeno'     = @{ source = 'Jalapeno.reanim'; native = Native-BodyOnly @(-44,-80) @{ idle = @{ body = 'idle' }; ready = @{ body = 'idle' } } @{ explode = @{ body = 'explode' } } @{ idle = 'idle' } 'idle' @{ explode = 'idle' } }
	'umbrellaleaf' = @{ source = 'Umbrellaleaf.reanim'; native = Native-BodyBlink @(-40,-78) @{ idle = @{ body = 'idle'; blink = 'idle' }; ready = @{ body = 'idle'; blink = 'idle' } } @{ block = @{ body = 'block' }; blink = @{ blink = 'blink' } } @{ idle = 'idle' } }
	'tanglekelp'   = @{ source = 'Tanglekelp.reanim'; native = Native-BodyBlink @(-40,-78) @{ idle = @{ body = 'idle'; blink = 'idle' }; ready = @{ body = 'idle'; blink = 'idle' } } @{ grab = @{ body = 'grab' }; blink = @{ blink = 'blink' } } @{ idle = 'idle' } 'anim_face' 'idle' @{ grab = 'idle' } }
	'potatomine'   = @{ source = 'Potatomine.reanim'; native = Native-BodyBlink @(-40,-50) @{ idle = @{ body = 'idle'; blink = 'idle' }; ready = @{ body = 'idle'; blink = 'idle' }; armed = @{ body = 'armed'; blink = 'idle' } } @{ rise = @{ body = 'rise' }; mashed = @{ body = 'mashed' }; blink = @{ blink = 'blink' } } @{ idle = 'idle'; armed = 'armed' } 'anim_face' 'idle' @{ rise = 'idle' } }
}

$select = switch ($Batch) {
	'm1'  { $m1.Keys }
	'm2a' { $m2a.Keys }
	'm2b' { $m2b.Keys }
	'm2c' { $m2c.Keys }
	default { @($m1.Keys) + @($m2a.Keys) + @($m2b.Keys) + @($m2c.Keys) }
}

$all = @{}
foreach ($k in $m1.Keys) { $all[$k] = $m1[$k] }
foreach ($k in $m2a.Keys) { $all[$k] = $m2a[$k] }
foreach ($k in $m2b.Keys) { $all[$k] = $m2b[$k] }
foreach ($k in $m2c.Keys) { $all[$k] = $m2c[$k] }

$fail = 0
foreach ($id in $select) {
	$cfg = $all[$id]
	# Reconstruct the native JSON string with robust quoting for the child script.
	$nj = $cfg.native
	$srcFile = $cfg.source
	if ($SkipStageA) {
		& pwsh -NoProfile -File (Join-Path $here 'run_reanim_migrate_one.ps1') -Id $id -Source $srcFile -NativeJson $nj -GodotExe $GodotExe -SkipStageA
	} else {
		& pwsh -NoProfile -File (Join-Path $here 'run_reanim_migrate_one.ps1') -Id $id -Source $srcFile -NativeJson $nj -GodotExe $GodotExe
	}
	if ($LASTEXITCODE -ne 0) { Write-Warning "[MigrateBatch] $id FAILED (exit $LASTEXITCODE)"; $fail += 1 }
}
Write-Host "`n[MigrateBatch] batch=$Batch plants=$($select.Count) failures=$fail"
exit $fail
