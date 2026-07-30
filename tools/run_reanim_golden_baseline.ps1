param(
	[string]$GodotExe = "",
	[string]$PackRoot = "res://local_extensions/classic_original_assets",
	[string]$OutDir = "",
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

$GodotArgs = @(
	"--headless",
	"--path", $ProjectRoot,
	"--script", "res://tools/reanim_golden_baseline.gd",
	"--",
	"--pack-root", $PackRoot,
	"--samples", $Samples
)
if (-not [string]::IsNullOrWhiteSpace($OutDir)) {
	$GodotArgs += @("--out-dir", $OutDir)
}

& $GodotExe @GodotArgs
$ExitCode = $LASTEXITCODE
Write-Host ("[ReanimGoldenBaseline] exit code: {0}" -f $ExitCode)
exit $ExitCode
