param(
	# Private classic_original_assets pack root. Defaults to the worktree copy next to
	# this script so it runs out-of-the-box; override for other layouts.
	[string]$Root = (Join-Path $PSScriptRoot '..' 'local_extensions' 'classic_original_assets'),
	# Which roster to scan:
	#   manifest         (default) only entries already in the private reanim manifest (legacy behavior)
	#   original_plants  every archetype_original_*.tres plant, marking each as migrated/pending
	[string]$Roster = 'manifest'
)

# Scans migration-target plants for reanim feature usage to scope T4 (attacher) /
# T5 (override & blend) per the implementation plan, and (with -Roster original_plants)
# to freeze the M0 candidate matrix for the native reanim migration plan.
#
# Missing source files or semantic reports are surfaced explicitly as BLOCKER rows
# (they are never silently skipped), satisfying the M0 acceptance criterion.

$ErrorActionPreference = 'Stop'
$Manifest = Get-Content (Join-Path $Root 'manifests\reanim_visual_manifest.local.json') -Raw | ConvertFrom-Json
$SemanticDir = Join-Path $Root 'generated\reports\semantic'
$SourceDir = Join-Path $Root 'sources\reanim'

# id -> source .reanim filename (without extension). Covers the non-obvious original
# PVZ names; everything else is "capitalize the first letter of the id". Verified
# against sources/reanim/ (146 files) on 2026-08-01.
$SourceNameOverrides = @{
	'peashooter'     = 'PeaShooterSingle'   # repeat-shooter uses the dedicated single source
	'repeater'       = 'PeaShooter'          # repeater reuses the gatling-era PeaShooter.reanim
	'flowerpot'      = 'Pot'                 # original PVZ flower pot is named Pot
	'kernelpult'     = 'Cornpult'            # original PVZ kernel-pult is named Cornpult
	'spikeweed'      = 'Caltrop'             # original PVZ spikeweed is named Caltrop
	'twinsunflower'  = 'TwinSunflower'       # capital S in the middle
}

function Get-SourceName([string]$Id) {
	if ($SourceNameOverrides.ContainsKey($Id)) { return $SourceNameOverrides[$Id] }
	return $Id.Substring(0,1).ToUpper() + $Id.Substring(1)
}

# Build a row describing one plant's reanim feature usage. $Id is the plant id;
# $SourceName is the .reanim filename stem; $Migrated is 'yes'/'pending' for the
# original_plants roster (unused / always 'yes' for the manifest roster).
function New-ReportRow([string]$Id, [string]$SourceName, [string]$Migrated) {
	$SemanticPath = Join-Path $SemanticDir ($SourceName + '.semantic_report.json')
	$SourcePath = Join-Path $SourceDir ($SourceName + '.reanim')
	# Cast counts to [int] (ConvertFrom-Json yields Int64; we want plain ints and
	# predictable comparisons downstream).
	$Row = [ordered]@{
		id                 = $Id
		source             = $SourceName
		migrated           = $Migrated
		attacher           = $null
		blend              = $null
		overlay_binding    = $null
		suspected_overlay  = $null
		angle_warnings     = $null
		unresolved_layers  = $null
		has_text           = $null
		has_font           = $null
		blocker            = $null
	}
	if (-not (Test-Path -LiteralPath $SourcePath)) {
		$Row.source = $SourceName + ' (MISSING SOURCE)'
		$Row.blocker = 'MISSING_SOURCE'
		return [pscustomobject]$Row
	}
	if (Test-Path -LiteralPath $SemanticPath) {
		$Report = Get-Content $SemanticPath -Raw | ConvertFrom-Json
		$Row.attacher = [int]$Report.suspected_attachment_count
		$Row.blend = ($Report.blend_modes_seen -join ',')
		$Row.overlay_binding = [int]$Report.overlay_binding_count
		$Row.suspected_overlay = [int]$Report.suspected_overlay_count
		$Row.angle_warnings = [int]$Report.angle_warning_count
		$Row.unresolved_layers = [int]$Report.unresolved_layer_count
	} else {
		$Row.source = $SourceName + ' (NO SEMANTIC REPORT)'
		$Row.blocker = 'NO_REPORT'
	}
	$Raw = Get-Content -LiteralPath $SourcePath -Raw
	$Row.has_text = [bool]($Raw -match '<text>')
	$Row.has_font = [bool]($Raw -match '<font>')
	# Flag M3 capability-gap blockers. NOTE: suspected_attachment_count and
	# overlay/overlay_binding counts are NOT blockers on their own -- the 18
	# already-migrated plants routinely carry nonzero values that are absorbed by
	# the existing host_track / track_visibility / blink-overlay capabilities
	# (e.g. peashooter attacher=1, chomper attacher=3, sunflower overlay=1).
	# The genuine M3 gaps are: blend modes the runtime can't composite, text/font
	# tracks, and unresolved layers. Missing source/report is also a blocker.
	$Blockers = @()
	if ($Row.blend) { $Blockers += 'blend' }
	if ($Row.has_text -or $Row.has_font) { $Blockers += 'text/font' }
	if ($null -ne $Row.unresolved_layers -and $Row.unresolved_layers -gt 0) { $Blockers += 'unresolved_layer' }
	if ($Blockers.Count -gt 0) { $Row.blocker = ($Blockers -join '+') }
	return [pscustomobject]$Row
}

# --- Roster resolution -------------------------------------------------------

$Rows = @()
if ($Roster -eq 'original_plants') {
	$ArchetypeDir = Join-Path $PSScriptRoot '..' 'data\combat\archetypes\plants'
	$ArchetypeFiles = Get-ChildItem -LiteralPath $ArchetypeDir -Filter 'archetype_original_*.tres' -File |
		Sort-Object Name
	$MigratedIds = @{}
	foreach ($Entry in $Manifest.entries) { $MigratedIds[$Entry.id] = $true }
	foreach ($File in $ArchetypeFiles) {
		$Id = $File.BaseName -replace '^archetype_original_', ''
		$Migrated = if ($MigratedIds.ContainsKey($Id)) { 'yes' } else { 'pending' }
		$Rows += New-ReportRow -Id $Id -SourceName (Get-SourceName $Id) -Migrated $Migrated
	}
} elseif ($Roster -eq 'manifest') {
	foreach ($Entry in $Manifest.entries) {
		$SourceName = [IO.Path]::GetFileNameWithoutExtension($Entry.source_reanim)
		$Rows += New-ReportRow -Id $Entry.id -SourceName $SourceName -Migrated 'yes'
	}
} else {
	Write-Error "Unknown -Roster '$Roster'. Use 'manifest' or 'original_plants'."
	exit 1
}

# --- Output ------------------------------------------------------------------

$Rows | Format-Table -AutoSize | Out-String -Width 240 | Write-Output

$NeedsT4 = @($Rows | Where-Object { $null -ne $_.attacher -and $_.attacher -gt 0 })
$NeedsBlend = @($Rows | Where-Object { $_.blend -and $_.blend -ne '' })
$NeedsOverlay = @($Rows | Where-Object { ($null -ne $_.overlay_binding -and $_.overlay_binding -gt 0) -or ($null -ne $_.suspected_overlay -and $_.suspected_overlay -gt 0) })
$NeedsTextFont = @($Rows | Where-Object { $_.has_text -or $_.has_font })
$Blockers = @($Rows | Where-Object { $_.blocker })
$Pending = @($Rows | Where-Object { $_.migrated -eq 'pending' })

Write-Output ("roster: {0}" -f $Roster)
Write-Output ("plants total: {0}" -f $Rows.Count)
if ($Roster -eq 'original_plants') {
	Write-Output ("migrated: {0}  pending: {1}" -f ($Rows.Count - $Pending.Count), $Pending.Count)
}
Write-Output ("needs T4 attacher: {0} -> {1}" -f $NeedsT4.Count, (($NeedsT4 | ForEach-Object { $_.id }) -join ', '))
Write-Output ("needs blend: {0} -> {1}" -f $NeedsBlend.Count, (($NeedsBlend | ForEach-Object { $_.id }) -join ', '))
Write-Output ("needs overlay/track-override: {0} -> {1}" -f $NeedsOverlay.Count, (($NeedsOverlay | ForEach-Object { $_.id }) -join ', '))
Write-Output ("uses text/font: {0} -> {1}" -f $NeedsTextFont.Count, (($NeedsTextFont | ForEach-Object { $_.id }) -join ', '))
Write-Output ("BLOCKERS (M3 capability gap or missing data): {0} -> {1}" -f $Blockers.Count, (($Blockers | ForEach-Object { ('{0}({1})' -f $_.id, $_.blocker) }) -join ', '))
