param(
	[string]$Scenario = "res://scenes/validation/parabola_long_range_validation.tres",
	[string]$GodotExe = "E:\SDK\Godot\Godot_v4.6.1-stable_win64_console.exe"
)

$ProjectRoot = Split-Path -Parent $PSScriptRoot

& $GodotExe `
	--headless `
	--path $ProjectRoot `
	-- `
	"--validation-scenario=$Scenario" `
	--validation-auto-quit `
	--validation-print-report `
	--validation-no-overlay

exit $LASTEXITCODE
