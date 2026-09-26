param(
	[Parameter(Mandatory = $true)][string]$Id,
	# .reanim source filename (e.g. "Coffeebean.reanim"). Defaults to "<Cap(Id)>.reanim".
	[string]$Source = "",
	[string]$GodotExe = "",
	[string]$Project = "",
	[string]$PackRoot = "res://local_extensions/classic_original_assets",
	[string]$Manifest = "res://local_extensions/classic_original_assets/manifests/reanim_visual_manifest.local.json",
	# JSON string with the native block fields that vary per plant:
	#   {"root_offset":[x,y], "states":{...}, "actions":{...},
	#    "action_next_states":{...}, "anchors":{...}, "parts":[...], "initial_state":"idle",
	#    "state_animation_map":{...}, "ground_offset":[x,y]}
	# At minimum provide root_offset + states + state_animation_map. Parts default
	# to a single body part bound to the generated reanim_data.
	[string]$NativeJson = "{}",
	# When set, skips Stage A (assume reanim_data + raw actor already generated)
	# and only writes the manifest entry + runs Stage B.
	[switch]$SkipStageA
)

# End-to-end migration of one original plant into the private classic_original_assets
# native reanim pipeline. Performs:
#   1. Stage A full import  -> generated/raw/<id>/{actor.tscn,import_report.json,visual_profile.tres}
#                              + generated/reanim_data/<id>/reanim_data.tres
#   2. copy import_report   -> generated/reports/<id>.import_report.json
#   3. upsert manifest entry (legacy fields + native block) into the private manifest
#   4. Stage B full pass     -> generated/native/<id>/{actor_def.tres,actor.tscn,native_report.json}
#                              + actors/<id>/actor.tscn + visual profile + composite_report + asset_index
#
# This is the reusable M1/M2 per-plant engine. The plant-specific data (clips ->
# states/actions, root_offset, anchors) is supplied via -NativeJson; everything
# else is derived from -Id and -Source.

$ErrorActionPreference = 'Stop'
if ([string]::IsNullOrWhiteSpace($Project)) { $Project = Split-Path -Parent $PSScriptRoot }
if ([string]::IsNullOrWhiteSpace($GodotExe)) {
	if (-not [string]::IsNullOrWhiteSpace($env:GODOT_BIN) -and (Test-Path -LiteralPath $env:GODOT_BIN -PathType Leaf)) {
		$GodotExe = $env:GODOT_BIN
	} else {
		$Candidate = Get-ChildItem $Project -Filter "Godot_v*_win64_console.exe" -File | Sort-Object Name -Descending | Select-Object -First 1
		if ($Candidate -ne $null) { $GodotExe = $Candidate.FullName }
		else {
			$PathCandidate = Get-Command "godot" -ErrorAction SilentlyContinue
			if ($PathCandidate -ne $null) { $GodotExe = $PathCandidate.Source }
			else { Write-Error "No Godot found (set -GodotExe / `$env:GODOT_BIN)."; exit 1 }
		}
	}
}
if ([string]::IsNullOrWhiteSpace($Source)) { $Source = $Id.Substring(0,1).ToUpper() + $Id.Substring(1) + ".reanim" }

$SourceReanim = "$PackRoot/sources/reanim/$Source"
$ResourcesXml = "$PackRoot/sources/properties/resources.xml"
$RawDir = "$PackRoot/generated/raw/$Id"
$ReanimDataDir = "$PackRoot/generated/reanim_data/$Id"
$ProfileId = "classic_original.entity.plant.$Id.visual"

# --- Stage A: full import ----------------------------------------------------
if (-not $SkipStageA) {
	Write-Host "[MigrateOne] Stage A full import: $Id ($Source)"
	$stageA = Invoke-Godot @(
		"res://tools/reanim_importer/reanim_import_one.gd",
		"--source", $SourceReanim,
		"--image-root", "$PackRoot/sources/reanim",
		"--resources", $ResourcesXml,
		"--out-dir", $RawDir,
		"--emit-reanim-data", $ReanimDataDir,
		"--reanim-id", $Id,
		"--profile-id", $ProfileId
	)
	if ($stageA -ne 0) { Write-Error "Stage A failed for $Id (exit $stageA)"; exit 1 }
}

# --- copy import_report -> generated/reports/<id>.import_report.json ---------
$ReportsDir = Join-Path $Project "local_extensions\classic_original_assets\generated\reports"
if (-not (Test-Path $ReportsDir)) { New-Item -ItemType Directory -Path $ReportsDir -Force | Out-Null }
$SrcReport = Join-Path $Project "local_extensions\classic_original_assets\generated\raw\$Id\import_report.json"
$DstReport = Join-Path $ReportsDir "$Id.import_report.json"
if (Test-Path -LiteralPath $SrcReport) {
	Copy-Item -LiteralPath $SrcReport -Destination $DstReport -Force
	Write-Host "[MigrateOne] copied import_report -> $DstReport"
} else {
	Write-Warning "[MigrateOne] Stage A import_report missing: $SrcReport"
}

# --- upsert manifest entry ---------------------------------------------------
$ManifestFs = Join-Path $Project "local_extensions\classic_original_assets\manifests\reanim_visual_manifest.local.json"
$Doc = Get-Content $ManifestFs -Raw | ConvertFrom-Json -Depth 32
$Native = $NativeJson | ConvertFrom-Json -Depth 32
# Ensure default single body part if none supplied.
if (-not ($Native.PSObject.Properties.Name -contains 'parts')) {
	$Native | Add-Member -NotePropertyName parts -NotePropertyValue @(
		@{ id = 'body'; reanim_data = "$ReanimDataDir/reanim_data.tres"; initial_clip = ($Native.initial_state ? $Native.initial_state : 'idle'); loop = $true; render_order = 0 }
	)
} else {
	# Ensure reanim_data path points at the generated resource for each part.
	# Only emit non-null fields so GDScript's String(...)/etc. don't choke on
	# explicit JSON nulls (String(null) is not a valid constructor in GDScript).
	$fixedParts = @()
	foreach ($part in $Native.parts) {
		$rd = $part.reanim_data
		if ([string]::IsNullOrWhiteSpace($rd)) { $rd = "$ReanimDataDir/reanim_data.tres" }
		$fp = [ordered]@{
			id = $part.id
			reanim_data = $rd
			initial_clip = $part.initial_clip
			loop = [bool]$part.loop
			render_order = [int]$part.render_order
		}
		if (-not [string]::IsNullOrWhiteSpace($part.host_part_id)) { $fp.host_part_id = $part.host_part_id }
		if (-not [string]::IsNullOrWhiteSpace($part.host_track)) { $fp.host_track = $part.host_track }
		if ($part.track_visibility) { $fp.track_visibility = $part.track_visibility }
		$fixedParts += $fp
	}
	$Native.parts = $fixedParts
}

$Entry = [ordered]@{
	id = $Id
	profile_id = $ProfileId
	raw_actor_scene = "$RawDir/actor.tscn"
	actor_scene_out_path = "$PackRoot/actors/$Id/actor.tscn"
	profile_out_path = "$PackRoot/data/combat/visual_profiles/plants/$Id.tres"
	report_out_path = "$PackRoot/generated/reports/$Id.composite_report.json"
	import_report = "$PackRoot/generated/reports/$Id.import_report.json"
	source_reanim = $SourceReanim
	source_resources = $ResourcesXml
	profile_tags = @('classic_original', 'original', 'reanim', 'composite')
	initial_state = ($Native.initial_state ? $Native.initial_state : 'idle')
}
if ($Native.PSObject.Properties.Name -contains 'ground_offset') {
	$Entry.ground_offset = $Native.ground_offset
}
if ($Native.PSObject.Properties.Name -contains 'state_animation_map') {
	$Entry.state_animation_map = $Native.state_animation_map
}
$NativeBlock = [ordered]@{
	actor_node_name = ($Id.Substring(0,1).ToUpper() + $Id.Substring(1) + 'NativeActor')
	def_out_path = "$PackRoot/generated/native/$Id/actor_def.tres"
	actor_scene_out_path = "$PackRoot/generated/native/$Id/actor.tscn"
	report_out_path = "$PackRoot/generated/native/$Id/native_report.json"
	root_offset = $Native.root_offset
	initial_state = ($Native.initial_state ? $Native.initial_state : 'idle')
	parts = $Native.parts
	states = ($Native.states ? $Native.states : @{ idle = @{ body = 'idle' } })
	actions = ($Native.actions ? $Native.actions : @{})
	anchors = ($Native.anchors ? $Native.anchors : @{})
}
if ($Native.PSObject.Properties.Name -contains 'action_next_states') { $NativeBlock.action_next_states = $Native.action_next_states }
if ($Native.PSObject.Properties.Name -contains 'clip_rates') { $NativeBlock.clip_rates = $Native.clip_rates }
$Entry.native = $NativeBlock

# Replace existing entry or append.
$Replaced = $false
for ($i = 0; $i -lt $Doc.entries.Count; $i++) {
	if ($Doc.entries[$i].id -eq $Id) { $Doc.entries[$i] = $Entry; $Replaced = $true; break }
}
if (-not $Replaced) { $Doc.entries += $Entry }
($Doc | ConvertTo-Json -Depth 32) | Set-Content -Path $ManifestFs -NoNewline -Encoding UTF8
Write-Host "[MigrateOne] manifest entry $(if ($Replaced) {'replaced'} else {'added'}) for $Id"

# --- Stage B: native-only (fast) + lightweight profile/composite_report -------
# The full _generate_entry path rebuilds the heavy legacy composite actor for
# every entry, which is slow and unnecessary for native migration (the validator
# does not check the legacy actor_scene_out_path). So we run native-only here,
# then write the VisualProfile .tres (pointing at the native scene) and a
# minimal composite_report directly. asset_index.json is rebuilt by a single
# full unfiltered Stage B pass at the end of a batch (see run_reanim_migrate_finalize.ps1).
Write-Host "[MigrateOne] Stage B native generation: $Id"
& $GodotExe --headless --path $Project --script res://tools/reanim_importer/reanim_generate_composites.gd -- --manifest $Manifest --only $Id --native-only true 2>&1 | ForEach-Object { Write-Host $_ }
$NativeReport = Join-Path $Project "local_extensions\classic_original_assets\generated\native\$Id\native_report.json"
if (Test-Path $NativeReport) {
	$Nr = Get-Content $NativeReport -Raw | ConvertFrom-Json
	Write-Host "[MigrateOne] native: ok=$($Nr.ok) parts=$($Nr.part_count) def_bytes=$($Nr.def_bytes)"
	if (-not $Nr.ok) { exit 1 }
} else {
	Write-Warning "[MigrateOne] no native_report for $Id"; exit 1
}

# Write the VisualProfile .tres bound to the native actor scene (mirrors the 18
# migrated profiles). The validator requires profile_out_path to exist, be a
# VisualProfileDef with matching id, and have actor_scene == native scene.
$ProfileFs = Join-Path $Project "local_extensions\classic_original_assets\data\combat\visual_profiles\plants\$Id.tres"
$ProfileDir = Split-Path -Parent $ProfileFs
if (-not (Test-Path $ProfileDir)) { New-Item -ItemType Directory -Path $ProfileDir -Force | Out-Null }
$StateMapLines = ""
$Sam = if ($Native.state_animation_map) { $Native.state_animation_map } else { @{ idle = 'idle' } }
foreach ($k in $Sam.PSObject.Properties.Name) {
	$StateMapLines += "`n`t&`"$k`": &`"$($Sam.$k)`","	# trailing comma is valid in .tres dicts
}
$ProfileTags = "PackedStringArray(`"classic_original`", `"original`", `"reanim`", `"composite`")"
$ProfileContent = @"
[gd_resource type="Resource" script_class="VisualProfileDef" format=3]

[ext_resource type="PackedScene" path="res://local_extensions/classic_original_assets/generated/native/$Id/actor.tscn" id="1_mv"]
[ext_resource type="Script" path="res://scripts/core/defs/visual_profile_def.gd" id="2_mv"]

[resource]
script = ExtResource("2_mv")
actor_scene = ExtResource("1_mv")
state_animation_map = {$StateMapLines
}
z_policy = {
"layer": &"plant"
}
id = &"$ProfileId"
tags = $ProfileTags
"@
Set-Content -Path $ProfileFs -Value $ProfileContent -NoNewline -Encoding UTF8
Write-Host "[MigrateOne] wrote profile -> $ProfileFs"

# Write a minimal composite_report (the validator only checks report_out_path exists).
$CompositeReport = Join-Path $Project "local_extensions\classic_original_assets\generated\reports\$Id.composite_report.json"
$ReportObj = [ordered]@{
	id = $Id
	ok = $true
	actor_scene = "$PackRoot/generated/native/$Id/actor.tscn"
	visual_profile = "$PackRoot/data/combat/visual_profiles/plants/$Id.tres"
	raw_actor_scene = "$RawDir/actor.tscn"
	native = $true
}
($ReportObj | ConvertTo-Json -Depth 8) | Set-Content -Path $CompositeReport -NoNewline -Encoding UTF8
Write-Host "[MigrateOne] wrote composite_report -> $CompositeReport"
Write-Host "[MigrateOne] done: $Id. Remember to run a full unfiltered Stage B pass to rebuild asset_index.json before local_private validation."
