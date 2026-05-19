param(
	[string]$ExtensionRoot = "extensions"
)

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$extensionRootPath = Join-Path $repoRoot $ExtensionRoot
$issues = New-Object System.Collections.Generic.List[string]

function Add-Issue([string]$Message) {
	$issues.Add($Message) | Out-Null
}

function Test-JsonManifest([string]$ManifestPath) {
	try {
		return Get-Content -LiteralPath $ManifestPath -Raw | ConvertFrom-Json
	}
	catch {
		Add-Issue "Invalid extension manifest JSON: $ManifestPath"
		return $null
	}
}

function Test-PrivateReference([object]$Value, [string]$Path) {
	if ($null -eq $Value) {
		return
	}
	if ($Value -is [string]) {
		$normalized = $Value.Replace('\', '/')
		if ($normalized.Contains('vendor/out_files') -or $normalized.Contains('local_extensions')) {
			Add-Issue "Public extension manifest references private path at ${Path}: $Value"
		}
		return
	}
	if ($Value -is [System.Array]) {
		for ($i = 0; $i -lt $Value.Count; $i++) {
			Test-PrivateReference $Value[$i] "$Path[$i]"
		}
		return
	}
	if ($Value -is [pscustomobject]) {
		foreach ($property in $Value.PSObject.Properties) {
			Test-PrivateReference $property.Value "$Path.$($property.Name)"
		}
	}
}

if (-not (Test-Path -LiteralPath $extensionRootPath)) {
	Write-Host "[PublicExtensionGuardrail] No extension root found: $extensionRootPath"
	exit 0
}

$manifestFiles = Get-ChildItem -LiteralPath $extensionRootPath -Filter "extension.json" -Recurse
foreach ($manifestFile in $manifestFiles) {
	$manifest = Test-JsonManifest $manifestFile.FullName
	if ($null -eq $manifest) {
		continue
	}

	$packId = if ($manifest.pack_id) { [string]$manifest.pack_id } else { $manifestFile.Directory.Name }
	$publishPolicy = if ($manifest.publish_policy) { [string]$manifest.publish_policy } else { "public" }
	if ($publishPolicy -ne "public") {
		continue
	}

	if ($manifest.contains_original_assets -eq $true) {
		Add-Issue "Public extension $packId must not set contains_original_assets=true."
	}
	if ($manifest.generated_from_private_source -eq $true) {
		Add-Issue "Public extension $packId must not set generated_from_private_source=true."
	}

	Test-PrivateReference $manifest $manifestFile.FullName

	$privateSourceFiles = Get-ChildItem -LiteralPath $manifestFile.Directory.FullName -Recurse -File |
		Where-Object { $_.Extension.ToLowerInvariant() -eq ".reanim" }
	foreach ($privateSourceFile in $privateSourceFiles) {
		Add-Issue "Public extension $packId must not contain private source file: $($privateSourceFile.FullName)"
	}
}

if ($issues.Count -gt 0) {
	Write-Host "[PublicExtensionGuardrail] FAILED"
	foreach ($issue in $issues) {
		Write-Host " - $issue"
	}
	exit 1
}

Write-Host "[PublicExtensionGuardrail] OK"
exit 0
