param(
	[ValidateSet("run", "validate_smoke", "validate_reference", "validate_private")]
	[string]$Action = "run",
	[string]$GodotHome = $env:OPENPVZ_GODOT_HOME,
	[string]$GodotConsole = $env:OPENPVZ_GODOT_CONSOLE,
	[int]$MaxParallel = $(if ($env:OPENPVZ_VALIDATION_MAX_PARALLEL) { [int]$env:OPENPVZ_VALIDATION_MAX_PARALLEL } else { 4 })
)

$ErrorActionPreference = "Stop"

$ProjectRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..")
$DefaultGodotHome = "E:/SDK/Godot"

function Resolve-GodotConsole {
	param(
		[string]$ExplicitPath,
		[string]$HomePath
	)

	if (-not [string]::IsNullOrWhiteSpace($ExplicitPath)) {
		return $ExplicitPath
	}
	if ([string]::IsNullOrWhiteSpace($HomePath)) {
		$HomePath = $DefaultGodotHome
	}

	foreach ($Directory in @($ProjectRoot, $HomePath)) {
		if (-not (Test-Path -LiteralPath $Directory -PathType Container)) {
			continue
		}
		$Candidate = Get-ChildItem -LiteralPath $Directory -Filter "Godot_v*_win64_console.exe" -File |
			Sort-Object Name -Descending |
			Select-Object -First 1
		if ($null -ne $Candidate) {
			return $Candidate.FullName
		}
	}

	throw "Godot console executable was not found. Set OPENPVZ_GODOT_CONSOLE or OPENPVZ_GODOT_HOME."
}

$GodotConsole = Resolve-GodotConsole -ExplicitPath $GodotConsole -HomePath $GodotHome

switch ($Action) {
	"run" {
		& $GodotConsole --path $ProjectRoot
		break
	}
	"validate_smoke" {
		pwsh (Join-Path $ProjectRoot "tools/run_all_validations.ps1") -GodotExe $GodotConsole -Layers smoke -MaxParallel $MaxParallel
		break
	}
	"validate_reference" {
		pwsh (Join-Path $ProjectRoot "tools/run_all_validations.ps1") -GodotExe $GodotConsole -MaxParallel $MaxParallel
		break
	}
	"validate_private" {
		pwsh (Join-Path $ProjectRoot "tools/run_all_validations.ps1") -GodotExe $GodotConsole -Layers local_private -MaxParallel 1
		break
	}
}
