param(
	[string]$GodotExe = "",
	[string]$Project = "",
	[string]$Manifest = "res://local_extensions/classic_original_assets/manifests/reanim_visual_manifest.local.json",
	[string]$Ids = "squash,wallnut,tallnut,pumpkin,lilypad,flowerpot"
)

# Generates native composite actors (ReanimActorDef + actor.tscn + native_report.json)
# for the given manifest ids via reanim_generate_composites.gd --native-only.
#
# Godot binary resolution mirrors run_validation.ps1 / run_reanim_data_import.ps1:
#   -GodotExe  ->  $env:GODOT_BIN  ->  Godot_v*_win64_console.exe in project root  ->  godot on PATH  ->  error.

if ([string]::IsNullOrWhiteSpace($Project)) {
	$Project = Split-Path -Parent $PSScriptRoot
}
if ([string]::IsNullOrWhiteSpace($GodotExe)) {
	if (-not [string]::IsNullOrWhiteSpace($env:GODOT_BIN) -and (Test-Path -LiteralPath $env:GODOT_BIN -PathType Leaf)) {
		$GodotExe = $env:GODOT_BIN
	} else {
		$Candidate = Get-ChildItem $Project -Filter "Godot_v*_win64_console.exe" -File | Sort-Object Name -Descending | Select-Object -First 1
		if ($Candidate -ne $null) {
			$GodotExe = $Candidate.FullName
		} else {
			$PathCandidate = Get-Command "godot" -ErrorAction SilentlyContinue
			if ($PathCandidate -ne $null) {
				$GodotExe = $PathCandidate.Source
			} else {
				Write-Error "GodotExe not specified and no Godot executable found (set -GodotExe, `$env:GODOT_BIN, drop Godot_v*_win64_console.exe in '$Project', or put godot on PATH)."
				exit 1
			}
		}
	}
}

$Fail = 0
foreach ($Id in $Ids.Split(",")) {
	$Id = $Id.Trim()
	if ([string]::IsNullOrWhiteSpace($Id)) { continue }
	& $GodotExe --headless --path $Project --script res://tools/reanim_importer/reanim_generate_composites.gd -- --manifest $Manifest --only $Id --native-only true 2>&1 | Select-String -Pattern "Generated native|error|ERROR|invalid"
	$Report = Join-Path $Project ("local_extensions\classic_original_assets\generated\native\{0}\native_report.json" -f $Id)
	if (Test-Path $Report) {
		$Parsed = Get-Content $Report -Raw | ConvertFrom-Json
		Write-Output ("[NativeGen] {0}: ok={1} parts={2} def_bytes={3}" -f $Id, $Parsed.ok, $Parsed.part_count, $Parsed.def_bytes)
		if (-not $Parsed.ok) { $Fail += 1 }
	} else {
		Write-Output ("[NativeGen] {0}: NO REPORT" -f $Id)
		$Fail += 1
	}
}
Write-Output ("[NativeGen] failures: {0}" -f $Fail)
exit $Fail
