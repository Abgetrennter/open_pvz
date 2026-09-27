param(
	[string]$GodotHome = $env:OPENPVZ_GODOT_HOME,
	[string]$GodotConsole = $env:OPENPVZ_GODOT_CONSOLE,
	[string]$GodotGui = $env:OPENPVZ_GODOT_GUI,
	[string]$SetupSubmodules = $env:OPENPVZ_SETUP_SUBMODULES,
	[string]$PrivateAssetPackMode = $env:OPENPVZ_PRIVATE_ASSET_PACK_MODE,
	[string]$PrivateAssetPackSource = $env:OPENPVZ_PRIVATE_ASSET_PACK_SOURCE,
	[string]$PrivateAssetPackTarget = $env:OPENPVZ_PRIVATE_ASSET_PACK_TARGET,
	[switch]$CheckOnly
)

$ErrorActionPreference = "Stop"

$ProjectRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..")
 . (Join-Path $PSScriptRoot 'openpvz_environment.ps1')

function Initialize-OpenPvzSubmodules {
    param([string]$Mode)
    if (!$Mode) { $Mode = 'none' }
    if ($Mode -notin @('none', 'reference', 'full')) { throw "Invalid submodule mode: $Mode" }
    if ($Mode -eq 'none' -or !(Test-Path (Join-Path $ProjectRoot '.gitmodules'))) {
        Write-Host '[OpenPVZSetup] No submodule initialization required; references are optional workspace mirrors.'
        return
    }
    if ($Mode -eq 'reference') { throw 'Legacy reference mode is unsupported; use workspace references, or explicitly select full for a clone with submodules.' }
    & git -C $ProjectRoot submodule sync --recursive
    if ($LASTEXITCODE -ne 0) { throw 'Submodule sync failed' }
    & git -C $ProjectRoot submodule update --init --recursive
    if ($LASTEXITCODE -ne 0) { throw 'Submodule initialization failed' }
}

function Initialize-PrivateAssetPack {
	param(
		[string]$Mode,
		[string]$Source,
		[string]$Target
	)

	if ([string]::IsNullOrWhiteSpace($Mode)) {
		$Mode = "none"
	}
	if ([string]::IsNullOrWhiteSpace($Target)) {
		$Target = "local_extensions/classic_original_assets"
	}

	$Mode = $Mode.ToLowerInvariant()
	$TargetPath = Join-Path $ProjectRoot $Target

	if ($Mode -eq "none") {
		Write-Host "[OpenPVZSetup] Private asset pack mode is none."
		return
	}

	if ($Mode -eq "check") {
		if (-not (Test-Path -LiteralPath $TargetPath -PathType Container)) {
			throw "Private asset pack is missing at $TargetPath."
		}
		Write-Host "[OpenPVZSetup] Private asset pack exists at $TargetPath."
		return
	}

	if ($Mode -ne "link") {
		throw "Unsupported OPENPVZ_PRIVATE_ASSET_PACK_MODE value: $Mode. Use none, check, or link."
	}

	if ([string]::IsNullOrWhiteSpace($Source)) {
		throw "OPENPVZ_PRIVATE_ASSET_PACK_SOURCE must be set when OPENPVZ_PRIVATE_ASSET_PACK_MODE=link."
	}
	if (-not (Test-Path -LiteralPath $Source -PathType Container)) {
		throw "Private asset pack source does not exist: $Source."
	}
	if (Test-Path -LiteralPath $TargetPath) {
		Write-Host "[OpenPVZSetup] Private asset pack target already exists: $TargetPath."
		return
	}

	$TargetParent = Split-Path -Parent $TargetPath
	New-Item -ItemType Directory -Path $TargetParent -Force | Out-Null
	New-Item -ItemType Junction -Path $TargetPath -Target $Source | Out-Null
	Write-Host "[OpenPVZSetup] Linked private asset pack: $TargetPath -> $Source"
}

$GodotConsole = Resolve-OpenPvzExecutable -ProjectRoot $ProjectRoot -ExplicitPath $GodotConsole -GodotHome $GodotHome
$GodotGui = Resolve-OpenPvzExecutable -ProjectRoot $ProjectRoot -ExplicitPath $GodotGui -GodotHome $GodotHome -Gui -Optional

Write-Host "[OpenPVZSetup] Godot console: $GodotConsole"
Write-Host "[OpenPVZSetup] Godot GUI: $GodotGui"

if (-not $CheckOnly) {
    Initialize-OpenPvzSubmodules -Mode $SetupSubmodules
	Initialize-PrivateAssetPack `
		-Mode $PrivateAssetPackMode `
		-Source $PrivateAssetPackSource `
		-Target $PrivateAssetPackTarget
    # Fresh worktrees need Godot's generated class/resource cache before running scenarios.
    & $GodotConsole --headless --editor --path $ProjectRoot --import
    if ($LASTEXITCODE -ne 0) { throw "Godot import failed ($LASTEXITCODE)" }
}

Write-Host "[OpenPVZSetup] Environment check completed."
