param(
	[string]$Scenario = "res://scenes/validation/parabola_long_range_validation.tres",
	[string]$GodotExe = "E:\SDK\Godot\Godot_v4.6.1-stable_win64_console.exe",
	[string]$OutputRoot = "",
	[string]$RunLabel = "",
	[switch]$EnableRuntimeSnapshots,
	[int]$RuntimeSnapshotInterval = 30,
	[switch]$PassThru
)

$ProjectRoot = Split-Path -Parent $PSScriptRoot
$ScenarioName = [System.IO.Path]::GetFileNameWithoutExtension($Scenario)
if ([string]::IsNullOrWhiteSpace($RunLabel)) {
	$RunLabel = $ScenarioName
}
if ([string]::IsNullOrWhiteSpace($OutputRoot)) {
	$OutputRoot = Join-Path $ProjectRoot "artifacts\\validation"
}

$Timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$RunDir = Join-Path $OutputRoot ("{0}_{1}" -f $Timestamp, $RunLabel)
New-Item -ItemType Directory -Path $RunDir -Force | Out-Null
$ConsoleLogPath = Join-Path $RunDir "godot.log"
$ReportPath = Join-Path $RunDir "validation_report.json"
$DebugLogPath = Join-Path $RunDir "debug_logs.json"

$ResolvedScenarioPath = $Scenario
if ($Scenario.StartsWith("res://")) {
	$RelativeScenarioPath = $Scenario.Substring("res://".Length).Replace("/", "\")
	$ResolvedScenarioPath = Join-Path $ProjectRoot $RelativeScenarioPath
}

if (-not (Test-Path -LiteralPath $ResolvedScenarioPath)) {
	$Result = [pscustomobject]@{
		Scenario = $Scenario
		RunLabel = $RunLabel
		RunDir = $RunDir
		ConsoleLog = $ConsoleLogPath
		ReportPath = $ReportPath
		DebugLogPath = $DebugLogPath
		Status = "failed"
		ExitCode = 1
	}
	$MissingMessage = "[ValidationRunner] $RunLabel -> FAILED ($RunDir)`nMissing scenario resource: $Scenario"
	$MissingMessage | Set-Content -LiteralPath $ConsoleLogPath -Encoding UTF8
	Write-Host ("[ValidationRunner] {0} -> FAILED ({1})" -f $RunLabel, $RunDir)
	if ($PassThru) {
		$Result
		return
	}
	Write-Host "Missing scenario resource: $Scenario"
	exit 1
}

$GodotArgs = @(
	"--headless",
	"--path", $ProjectRoot,
	"--",
	"--validation-scenario=$Scenario",
	"--validation-auto-quit",
	"--validation-print-report",
	"--validation-no-overlay",
	"--validation-output-dir=$RunDir",
	"--validation-run-label=$RunLabel"
)

if ($EnableRuntimeSnapshots) {
	$GodotArgs += "--runtime-snapshot-log"
	$GodotArgs += "--runtime-snapshot-interval=$RuntimeSnapshotInterval"
}

$Output = & $GodotExe @GodotArgs 2>&1
$ExitCode = $LASTEXITCODE
$Output | Set-Content -LiteralPath $ConsoleLogPath -Encoding UTF8

$Report = $null
if (Test-Path -LiteralPath $ReportPath) {
	$Report = Get-Content -LiteralPath $ReportPath -Raw | ConvertFrom-Json
}

$Status = if ($null -ne $Report) { [string]$Report.status } elseif ($ExitCode -eq 0) { "passed" } else { "failed" }

$Result = [pscustomobject]@{
	Scenario = $Scenario
	RunLabel = $RunLabel
	RunDir = $RunDir
	ConsoleLog = $ConsoleLogPath
	ReportPath = $ReportPath
	DebugLogPath = $DebugLogPath
	Status = $Status
	ExitCode = $ExitCode
}

Write-Host ("[ValidationRunner] {0} -> {1} ({2})" -f $RunLabel, $Status.ToUpperInvariant(), $RunDir)

if (-not $PassThru) {
	$Output | ForEach-Object { Write-Host $_ }
}

if ($PassThru) {
	$Result
	return
}

exit $ExitCode
