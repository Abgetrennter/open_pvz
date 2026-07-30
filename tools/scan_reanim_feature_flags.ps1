param(
	[string]$Root = 'C:\Users\Administrator\Documents\open-pvz\local_extensions\classic_original_assets'
)
# Scans migration-target plants (manifest entries) for reanim feature usage to
# scope T4 (attacher) / T5 (override & blend) per the implementation plan.
$Manifest = Get-Content (Join-Path $Root 'manifests\reanim_visual_manifest.local.json') -Raw | ConvertFrom-Json
$SemanticDir = Join-Path $Root 'generated\reports\semantic'
$Rows = @()
foreach ($Entry in $Manifest.entries) {
	$SourceName = [IO.Path]::GetFileNameWithoutExtension($Entry.source_reanim)
	$SemanticPath = Join-Path $SemanticDir ($SourceName + '.semantic_report.json')
	$SourcePath = Join-Path $Root ($Entry.source_reanim -replace '^res://local_extensions/classic_original_assets/', '' -replace '/', '\')
	$Row = [ordered]@{
		id = $Entry.id
		source = $SourceName
		attacher_tracks = $null
		blend_modes = $null
		overlay_bindings = $null
		suspected_overlays = $null
		angle_warnings = $null
		unresolved_layers = $null
		has_text = $null
		has_font = $null
	}
	if (Test-Path $SemanticPath) {
		$Report = Get-Content $SemanticPath -Raw | ConvertFrom-Json
		$Row.attacher_tracks = $Report.suspected_attachment_count
		$Row.blend_modes = ($Report.blend_modes_seen -join ',')
		$Row.overlay_bindings = $Report.overlay_binding_count
		$Row.suspected_overlays = $Report.suspected_overlay_count
		$Row.angle_warnings = $Report.angle_warning_count
		$Row.unresolved_layers = $Report.unresolved_layer_count
	} else {
		$Row.source = $SourceName + ' (NO SEMANTIC REPORT)'
	}
	if (Test-Path $SourcePath) {
		$Raw = Get-Content $SourcePath -Raw
		$Row.has_text = $Raw -match '<text>'
		$Row.has_font = $Raw -match '<font>'
	}
	$Rows += [pscustomobject]$Row
}
$Rows | Format-Table -AutoSize | Out-String -Width 220 | Write-Output
$NeedsT4 = @($Rows | Where-Object { $_.attacher_tracks -gt 0 })
$NeedsBlend = @($Rows | Where-Object { $_.blend_modes -and $_.blend_modes -ne '' })
$NeedsOverlay = @($Rows | Where-Object { $_.overlay_bindings -gt 0 -or $_.suspected_overlays -gt 0 })
$NeedsTextFont = @($Rows | Where-Object { $_.has_text -or $_.has_font })
Write-Output ("plants total: {0}" -f $Rows.Count)
Write-Output ("needs T4 attacher: {0} -> {1}" -f $NeedsT4.Count, (($NeedsT4 | ForEach-Object { $_.id }) -join ', '))
Write-Output ("needs blend: {0} -> {1}" -f $NeedsBlend.Count, (($NeedsBlend | ForEach-Object { $_.id }) -join ', '))
Write-Output ("needs overlay/track-override: {0} -> {1}" -f $NeedsOverlay.Count, (($NeedsOverlay | ForEach-Object { $_.id }) -join ', '))
Write-Output ("uses text/font: {0} -> {1}" -f $NeedsTextFont.Count, (($NeedsTextFont | ForEach-Object { $_.id }) -join ', '))
