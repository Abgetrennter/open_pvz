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

$LatestSummaryJsonPath = Join-Path $OutputRoot "latest_summary.json"
$LatestSummaryTxtPath = Join-Path $OutputRoot "latest_summary.txt"
$HistoryJsonlPath = Join-Path $OutputRoot "regression_history.jsonl"
$StatusJsonPath = Join-Path $OutputRoot "regression_status.json"
$StatusMarkdownPath = Join-Path $OutputRoot "regression_status.md"

$Summary | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $LatestSummaryJsonPath -Encoding UTF8
$SummaryLines | Set-Content -LiteralPath $LatestSummaryTxtPath -Encoding UTF8

$HistoryEntry = [pscustomobject]@{
	generated_at = $Summary.generated_at
	manifest = $Summary.manifest
	batch_dir = $Summary.batch_dir
	total = $Summary.total
	passed = $Summary.passed
	failed = $Summary.failed
	results = @(
		$Results | ForEach-Object {
			[pscustomobject]@{
				id = [string]$_.RunLabel
				scenario = [string]$_.Scenario
				status = [string]$_.Status
				exit_code = [int]$_.ExitCode
				run_dir = [string]$_.RunDir
			}
		}
	)
}
$HistoryLine = $HistoryEntry | ConvertTo-Json -Depth 8 -Compress
Add-Content -LiteralPath $HistoryJsonlPath -Value $HistoryLine -Encoding UTF8

$PreviousStatus = $null
if (Test-Path -LiteralPath $StatusJsonPath) {
	try {
		$PreviousStatus = Get-Content -LiteralPath $StatusJsonPath -Raw | ConvertFrom-Json
	} catch {
		$PreviousStatus = $null
	}
}

$ScenarioStatusMap = @{}
if ($null -ne $PreviousStatus -and $PreviousStatus.scenarios) {
	foreach ($ScenarioStatus in $PreviousStatus.scenarios) {
		$ScenarioStatusMap[[string]$ScenarioStatus.id] = $ScenarioStatus
	}
}

$RecordedBatchCount = 0
if ($null -ne $PreviousStatus -and $PreviousStatus.batches_recorded) {
	$RecordedBatchCount = [int]$PreviousStatus.batches_recorded
}

$ScenarioStatuses = @()
foreach ($Entry in $ScenarioManifest) {
	$ScenarioId = if ($Entry.id) { [string]$Entry.id } else { [System.IO.Path]::GetFileNameWithoutExtension([string]$Entry.scenario) }
	$ScenarioResult = $Results | Where-Object { $_.RunLabel -eq $ScenarioId } | Select-Object -First 1
	if ($null -eq $ScenarioResult) {
		continue
	}

	$PreviousScenarioStatus = $ScenarioStatusMap[$ScenarioId]
	$PassCount = 0
	$FailCount = 0
	$ConsecutivePasses = 0
	$ConsecutiveFailures = 0
	if ($null -ne $PreviousScenarioStatus) {
		if ($PreviousScenarioStatus.pass_count) {
			$PassCount = [int]$PreviousScenarioStatus.pass_count
		}
		if ($PreviousScenarioStatus.fail_count) {
			$FailCount = [int]$PreviousScenarioStatus.fail_count
		}
		if ($PreviousScenarioStatus.consecutive_passes) {
			$ConsecutivePasses = [int]$PreviousScenarioStatus.consecutive_passes
		}
		if ($PreviousScenarioStatus.consecutive_failures) {
			$ConsecutiveFailures = [int]$PreviousScenarioStatus.consecutive_failures
		}
	}

	$StatusValue = [string]$ScenarioResult.Status
	if ($StatusValue -eq "passed") {
		$PassCount += 1
		$ConsecutivePasses += 1
		$ConsecutiveFailures = 0
	} else {
		$FailCount += 1
		$ConsecutiveFailures += 1
		$ConsecutivePasses = 0
	}

	$ScenarioStatuses += [pscustomobject]@{
		id = $ScenarioId
		scenario = [string]$Entry.scenario
		description = [string]$Entry.description
		last_status = $StatusValue
		last_run_at = $Summary.generated_at
		last_batch_dir = [string]$BatchDir
		last_run_dir = [string]$ScenarioResult.RunDir
		last_exit_code = [int]$ScenarioResult.ExitCode
		pass_count = $PassCount
		fail_count = $FailCount
		consecutive_passes = $ConsecutivePasses
		consecutive_failures = $ConsecutiveFailures
	}
}

$StatusPayload = [pscustomobject]@{
	updated_at = $Summary.generated_at
	manifest = $Manifest
	batch_dir = $BatchDir
	batches_recorded = ($RecordedBatchCount + 1)
	total = $Results.Count
	passed = $PassedCount
	failed = $FailedCount
	scenarios = $ScenarioStatuses
}
$StatusPayload | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $StatusJsonPath -Encoding UTF8

$MarkdownLines = @(
	"# Validation Regression Status",
	"",
	"- Updated: $($Summary.generated_at)",
	"- Manifest: $Manifest",
	"- BatchDir: $BatchDir",
	"- Total: $($Results.Count)",
	"- Passed: $PassedCount",
	"- Failed: $FailedCount",
	"",
	"| Scenario | Status | Pass | Fail | Consecutive Pass | Consecutive Fail | Last Run |",
	"|------|------|------|------|------|------|------|"
)
foreach ($ScenarioStatus in $ScenarioStatuses) {
	$MarkdownLines += "| $($ScenarioStatus.id) | $($ScenarioStatus.last_status) | $($ScenarioStatus.pass_count) | $($ScenarioStatus.fail_count) | $($ScenarioStatus.consecutive_passes) | $($ScenarioStatus.consecutive_failures) | $($ScenarioStatus.last_run_at) |"
}
$MarkdownLines | Set-Content -LiteralPath $StatusMarkdownPath -Encoding UTF8

if ($FailedCount -gt 0) {
	exit 1
}

exit 0
