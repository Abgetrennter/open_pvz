param(
	[switch]$IncludeExistingContent
)

$ErrorActionPreference = "Stop"
$ProjectRoot = Split-Path -Parent $PSScriptRoot
$Violations = New-Object System.Collections.Generic.List[string]

function Invoke-Ripgrep {
	param(
		[string]$Pattern,
		[string[]]$Paths
	)
	$Args = @("--line-number", "--color", "never", "--glob", "!vendor/**", "--glob", "!artifacts/**", "--", $Pattern)
	$Args += $Paths
	$Output = & rg @Args 2>$null
	if ($LASTEXITCODE -gt 1) {
		throw "rg failed while scanning pattern: $Pattern"
	}
	return @($Output)
}

function Add-ViolationLines {
	param(
		[string]$Title,
		[string[]]$Lines,
		[string[]]$AllowPathFragments = @(),
		[string[]]$AllowLinePatterns = @()
	)
	foreach ($Line in $Lines) {
		$Allowed = $false
		foreach ($Fragment in $AllowPathFragments) {
			if ($Line -like "*$Fragment*") {
				$Allowed = $true
				break
			}
		}
		if (-not $Allowed) {
			foreach ($Pattern in $AllowLinePatterns) {
				if ($Line -match $Pattern) {
					$Allowed = $true
					break
				}
			}
		}
		if (-not $Allowed) {
			$Violations.Add("${Title}: $Line")
		}
	}
}

Push-Location $ProjectRoot
try {
	$GameplayPaths = @(
		"autoload",
		"scripts/battle",
		"scripts/components",
		"scripts/core/runtime",
		"scripts/entities",
		"scripts/projectile"
	)

	$WallClockLines = Invoke-Ripgrep "Time\.get_ticks_(msec|usec)" $GameplayPaths
	$AllowedWallClockLinePatterns = @(
		"scripts[\\/]+battle[\\/]+battle_manager\.gd:\d+:\s*var tick_started_usec := Time\.get_ticks_usec\(\)",
		"scripts[\\/]+battle[\\/]+battle_manager\.gd:\d+:\s*var elapsed_ms := float\(Time\.get_ticks_usec\(\) - tick_started_usec\) / 1000\.0"
	)
	Add-ViolationLines "Wall-clock API in gameplay code" $WallClockLines @("scripts/core/runtime/event_data.gd", "scripts/core/runtime\event_data.gd") $AllowedWallClockLinePatterns

	$TimerLines = Invoke-Ripgrep "\bTimer\b|SceneTreeTimer|create_timer" $GameplayPaths
	Add-ViolationLines "Timer API in gameplay code" $TimerLines @("scripts/components/visual_actor_component.gd", "scripts/components\visual_actor_component.gd")

	$ChangedTres = @()
	if ($IncludeExistingContent) {
		$ChangedTres = @(rg --files "data/combat" "scenes/validation" "extensions" | Where-Object { $_ -like "*.tres" })
	} else {
		$ChangedTres += @(git diff --name-only --diff-filter=ACMRTUXB -- "*.tres")
		$ChangedTres += @(git ls-files --others --exclude-standard -- "*.tres")
	}
	$ChangedTres = @($ChangedTres | Sort-Object -Unique | Where-Object { $_ -and (Test-Path -LiteralPath $_) })
	$ChangedTres = @($ChangedTres | Where-Object {
		$NormalizedPath = $_.Replace("\", "/")
		$NormalizedPath.StartsWith("data/combat/") -or $NormalizedPath.StartsWith("extensions/")
	})
	if ($ChangedTres.Count -gt 0) {
		$LegacyFieldPattern = '"(scan_range|impact_radius|collision_padding|detection_range|radius|distance|speed|move_speed)"\s*:'
		$LegacyLines = Invoke-Ripgrep $LegacyFieldPattern $ChangedTres
		Add-ViolationLines "Changed .tres uses legacy world-unit gameplay field" $LegacyLines
	}

	if ($Violations.Count -gt 0) {
		Write-Host "[RuntimeMetricsTimeGuardrail] FAILED"
		foreach ($Violation in $Violations) {
			Write-Host $Violation
		}
		exit 1
	}

	Write-Host "[RuntimeMetricsTimeGuardrail] PASSED"
	Write-Host "[RuntimeMetricsTimeGuardrail] Gameplay wall-clock/Timer scan clean; changed .tres legacy field scan clean."
	exit 0
}
finally {
	Pop-Location
}
