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
$DefaultGodotHome = "E:/SDK/Godot"
$ReferenceSubmodules = @(
	"vendor/de-pvz",
	"vendor/PVZ-Godot-Dream"
)

function Resolve-FirstMatchingFile {
	param(
		[string[]]$Directories,
		[string]$Filter
	)

	foreach ($Directory in $Directories) {
		if ([string]::IsNullOrWhiteSpace($Directory)) {
			continue
		}
		if (-not (Test-Path -LiteralPath $Directory -PathType Container)) {
			continue
		}
		$Candidate = Get-ChildItem -LiteralPath $Directory -Filter $Filter -File |
			Sort-Object Name -Descending |
			Select-Object -First 1
		if ($null -ne $Candidate) {
			return $Candidate.FullName
		}
	}

	return ""
}

function Resolve-OpenPvzPath {
	param(
		[string]$ExplicitPath,
		[string[]]$FallbackDirectories,
		[string]$Filter
	)

	if (-not [string]::IsNullOrWhiteSpace($ExplicitPath)) {
		return $ExplicitPath
	}

	return Resolve-FirstMatchingFile -Directories $FallbackDirectories -Filter $Filter
}

function Assert-ExecutableExists {
	param(
		[string]$Path,
		[string]$Name
	)

	if ([string]::IsNullOrWhiteSpace($Path) -or -not (Test-Path -LiteralPath $Path -PathType Leaf)) {
		throw "$Name was not found. Set the matching OPENPVZ_GODOT_* environment variable or install Godot under E:/SDK/Godot."
	}
}

function Initialize-OpenPvzSubmodules {
	param(
		[string]$Mode
	)

	if ([string]::IsNullOrWhiteSpace($Mode)) {
		$Mode = "reference"
	}
	$Mode = $Mode.ToLowerInvariant()

	if ($Mode -eq "none") {
		Write-Host "[OpenPVZSetup] Skipping submodule setup."
		return
	}

	git -C $ProjectRoot submodule sync --recursive

	if ($Mode -eq "full") {
		Write-Host "[OpenPVZSetup] Initializing all submodules."
		git -C $ProjectRoot submodule update --init --recursive
		return
	}

	if ($Mode -ne "reference") {
		throw "Unsupported OPENPVZ_SETUP_SUBMODULES value: $Mode. Use none, reference, or full."
	}

	Write-Host "[OpenPVZSetup] Initializing reference submodules."
	git -C $ProjectRoot submodule update --init -- $ReferenceSubmodules
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

if ([string]::IsNullOrWhiteSpace($GodotHome)) {
	$GodotHome = $DefaultGodotHome
}

$GodotConsole = Resolve-OpenPvzPath `
	-ExplicitPath $GodotConsole `
	-FallbackDirectories @($ProjectRoot, $GodotHome) `
	-Filter "Godot_v*_win64_console.exe"
$GodotGui = Resolve-OpenPvzPath `
	-ExplicitPath $GodotGui `
	-FallbackDirectories @($ProjectRoot, $GodotHome) `
	-Filter "Godot_v*_win64.exe"

Assert-ExecutableExists -Path $GodotConsole -Name "Godot console executable"
Assert-ExecutableExists -Path $GodotGui -Name "Godot GUI executable"

Write-Host "[OpenPVZSetup] Godot console: $GodotConsole"
Write-Host "[OpenPVZSetup] Godot GUI: $GodotGui"

if (-not $CheckOnly) {
	Initialize-OpenPvzSubmodules -Mode $SetupSubmodules
	Initialize-PrivateAssetPack `
		-Mode $PrivateAssetPackMode `
		-Source $PrivateAssetPackSource `
		-Target $PrivateAssetPackTarget
}

Write-Host "[OpenPVZSetup] Environment check completed."
