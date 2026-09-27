param(
	[ValidateSet("run", "validate_smoke", "validate_reference", "validate_private")]
	[string]$Action = "run",
	[string]$GodotHome = $env:OPENPVZ_GODOT_HOME,
	[string]$GodotConsole = $env:OPENPVZ_GODOT_CONSOLE,
	[int]$MaxParallel = $(if ($env:OPENPVZ_VALIDATION_MAX_PARALLEL) { [int]$env:OPENPVZ_VALIDATION_MAX_PARALLEL } else { 4 })
)

$ErrorActionPreference = "Stop"

$ProjectRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..")
. (Join-Path $PSScriptRoot 'openpvz_environment.ps1')
$GodotConsole = Resolve-OpenPvzExecutable -ProjectRoot $ProjectRoot -ExplicitPath $GodotConsole -GodotHome $GodotHome

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

exit $LASTEXITCODE
