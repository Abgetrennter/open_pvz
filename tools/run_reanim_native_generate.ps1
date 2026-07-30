param([string]$Ids = "squash,wallnut,tallnut,pumpkin,lilypad,flowerpot")
$Godot = 'C:\Users\Administrator\Documents\open-pvz\Godot_v4.6.2-stable_win64_console.exe'
$Project = 'C:\Users\Administrator\Documents\open-pvz'
$Manifest = 'res://local_extensions/classic_original_assets/manifests/reanim_visual_manifest.local.json'
$Fail = 0
foreach ($Id in $Ids.Split(',')) {
	$Id = $Id.Trim()
	& $Godot --headless --path $Project --script res://tools/reanim_importer/reanim_generate_composites.gd -- --manifest $Manifest --only $Id --native-only true 2>&1 | Select-String -Pattern "Generated native|error|ERROR|invalid"
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
