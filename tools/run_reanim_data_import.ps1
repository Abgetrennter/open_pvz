param(
	[string]$GodotExe = "",
	[string]$PackRoot = "res://local_extensions/classic_original_assets",
	[string]$Samples = "peashooter,wallnut,threepeater"
)

$ProjectRoot = Split-Path -Parent $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($GodotExe)) {
	if (-not [string]::IsNullOrWhiteSpace($env:GODOT_BIN) -and (Test-Path -LiteralPath $env:GODOT_BIN -PathType Leaf)) {
		$GodotExe = $env:GODOT_BIN
	} else {
		$Candidate = Get-ChildItem $ProjectRoot -Filter "Godot_v*_win64_console.exe" -File | Sort-Object Name -Descending | Select-Object -First 1
		if ($Candidate -ne $null) {
			$GodotExe = $Candidate.FullName
		} else {
			Write-Error "GodotExe not specified and no Godot executable found."
			exit 1
		}
	}
}

$SourceBySample = @{
	"peashooter" = "PeaShooterSingle.reanim"
	"wallnut" = "Wallnut.reanim"
	"threepeater" = "ThreePeater.reanim"
	"sunflower" = "SunFlower.reanim"
	"chomper" = "Chomper.reanim"
	"squash" = "Squash.reanim"
	"repeater" = "PeaShooter.reanim"
	"snowpea" = "SnowPea.reanim"
	"gatlingpea" = "GatlingPea.reanim"
	"splitpea" = "SplitPea.reanim"
	"puffshroom" = "PuffShroom.reanim"
	"scaredyshroom" = "ScaredyShroom.reanim"
	"fumeshroom" = "FumeShroom.reanim"
	"seashroom" = "SeaShroom.reanim"
	"tallnut" = "Tallnut.reanim"
	"pumpkin" = "Pumpkin.reanim"
	"lilypad" = "LilyPad.reanim"
	"flowerpot" = "Pot.reanim"
}

$FailCount = 0
foreach ($Sample in $Samples.Split(",")) {
	$Sample = $Sample.Trim()
	if (-not $SourceBySample.ContainsKey($Sample)) {
		Write-Error ("Unknown sample: {0}" -f $Sample)
		$FailCount += 1
		continue
	}
	$Source = "{0}/sources/reanim/{1}" -f $PackRoot, $SourceBySample[$Sample]
	$DataDir = "{0}/generated/reanim_data/{1}" -f $PackRoot, $Sample
	$GodotArgs = @(
		"--headless",
		"--path", $ProjectRoot,
		"--script", "res://tools/reanim_importer/reanim_import_one.gd",
		"--",
		"--source", $Source,
		"--image-root", ("{0}/sources/reanim" -f $PackRoot),
		"--resources", ("{0}/sources/properties/resources.xml" -f $PackRoot),
		"--out-dir", $DataDir,
		"--emit-reanim-data", $DataDir,
		"--reanim-id", $Sample,
		"--reanim-data-only", "true"
	)
	Write-Host ("[ReanimDataImport] {0} -> {1}" -f $Sample, $DataDir)
	& $GodotExe @GodotArgs
	$ExitCode = $LASTEXITCODE
	Write-Host ("[ReanimDataImport] {0} exit code: {1}" -f $Sample, $ExitCode)
	if ($ExitCode -ne 0) {
		$FailCount += 1
	}
}

if ($FailCount -gt 0) {
	Write-Host ("[ReanimDataImport] FAILED samples: {0}" -f $FailCount)
	exit 1
}
Write-Host "[ReanimDataImport] all samples emitted"
exit 0
