param(
	[string]$Manifest = "",
	[string]$GodotExe = "E:\SDK\Godot\Godot_v4.6.1-stable_win64_console.exe",
	[string]$OutputRoot = "",
	[switch]$EnableRuntimeSnapshots,
	[int]$RuntimeSnapshotInterval = 30
)

$ProjectRoot = Split-Path -Parent $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($Manifest)) {
	$Manifest = Join-Path $PSScriptRoot "validation_scenarios.json"
}
if ([string]::IsNullOrWhiteSpace($OutputRoot)) {
	$OutputRoot = Join-Path $ProjectRoot "artifacts\\validation"
}

$BatchTimestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$BatchDir = Join-Path $OutputRoot ("batch_{0}" -f $BatchTimestamp)
New-Item -ItemType Directory -Path $BatchDir -Force | Out-Null

$ScenarioManifest = Get-Content -LiteralPath $Manifest -Raw | ConvertFrom-Json
$Results = @()

foreach ($Entry in $ScenarioManifest) {
	$RunLabel = if ($Entry.id) { [string]$Entry.id } else { [System.IO.Path]::GetFileNameWithoutExtension([string]$Entry.scenario) }
	$Result = & (Join-Path $PSScriptRoot "run_validation.ps1") `
		-Scenario ([string]$Entry.scenario) `
		-GodotExe $GodotExe `
		-OutputRoot $BatchDir `
		-RunLabel $RunLabel `
		-PassThru `
		-EnableRuntimeSnapshots:$EnableRuntimeSnapshots `
		-RuntimeSnapshotInterval $RuntimeSnapshotInterval
	$Results += $Result
}

$Results = @(
	$Results | Where-Object {
		$_ -is [pscustomobject] -and
		$_.PSObject.Properties.Name -contains "RunLabel" -and
		$_.PSObject.Properties.Name -contains "Status"
	}
)

$PassedCount = ($Results | Where-Object { $_.Status -eq "passed" }).Count
$FailedCount = ($Results | Where-Object { $_.Status -ne "passed" }).Count
$Summary = [pscustomobject]@{
	generated_at = (Get-Date).ToString("s")
	manifest = $Manifest
	batch_dir = $BatchDir
	total = $Results.Count
	passed = $PassedCount
	failed = $FailedCount
	results = $Results
}

$SummaryJsonPath = Join-Path $BatchDir "summary.json"
$SummaryTxtPath = Join-Path $BatchDir "summary.txt"
$Summary | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $SummaryJsonPath -Encoding UTF8

$SummaryLines = @(
	"[ValidationBatch] Total: $($Results.Count)"
	"[ValidationBatch] Passed: $PassedCount"
	"[ValidationBatch] Failed: $FailedCount"
	"[ValidationBatch] BatchDir: $BatchDir"
)
foreach ($Result in $Results) {
	$Status = [string]$Result.Status
	$SummaryLines += "[ValidationBatch] $($Result.RunLabel): $($Status.ToUpperInvariant())"
}
$SummaryLines | Set-Content -LiteralPath $SummaryTxtPath -Encoding UTF8
$SummaryLines | ForEach-Object { Write-Host $_ }

if ($FailedCount -gt 0) {
	exit 1
}

exit 0
