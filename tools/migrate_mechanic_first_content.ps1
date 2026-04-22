$ErrorActionPreference = "Stop"

$Utf8NoBom = New-Object System.Text.UTF8Encoding($false)

function Write-Utf8NoBom {
	param(
		[string]$Path,
		[string]$Content
	)
	[System.IO.File]::WriteAllText($Path, $Content, $Utf8NoBom)
}

function Convert-TemplateIdToArchetypeId {
	param(
		[string]$TemplateId
	)
	if ([string]::IsNullOrWhiteSpace($TemplateId)) {
		return ""
	}
	if ($TemplateId.StartsWith("plant_")) {
		return "archetype_" + $TemplateId.Substring(6)
	}
	if ($TemplateId.StartsWith("zombie_")) {
		return "archetype_" + $TemplateId.Substring(7)
	}
	if ($TemplateId.StartsWith("field_object_")) {
		return "archetype_" + $TemplateId.Substring(13)
	}
	return "archetype_" + $TemplateId
}

function Get-EntityTemplateMetadata {
	param(
		[string]$Path
	)
	$content = Get-Content -Raw $Path
	$templateId = ([regex]'template_id = &"([^"]+)"').Match($content).Groups[1].Value
	$entityKind = ([regex]'entity_kind = &"([^"]+)"').Match($content).Groups[1].Value
	$displayName = ([regex]'display_name = "([^"]+)"').Match($content).Groups[1].Value
	$tagsMatch = ([regex]'tags = PackedStringArray\(([^)]*)\)').Match($content)
	$tags = @()
	if ($tagsMatch.Success) {
		$tags = [regex]::Matches($tagsMatch.Groups[1].Value, '"([^"]+)"') | ForEach-Object { $_.Groups[1].Value }
	}
	return @{
		TemplateId = $templateId
		EntityKind = $entityKind
		DisplayName = $displayName
		Tags = $tags
	}
}

function Ensure-ArchetypeWrapper {
	param(
		[string]$TemplatePath,
		[string]$RepoRoot
	)
	$metadata = Get-EntityTemplateMetadata -Path $TemplatePath
	if ([string]::IsNullOrWhiteSpace($metadata.TemplateId) -or [string]::IsNullOrWhiteSpace($metadata.EntityKind)) {
		return
	}
	$archetypeId = Convert-TemplateIdToArchetypeId -TemplateId $metadata.TemplateId
	$entityKind = $metadata.EntityKind
	$scriptClass = "CombatArchetype"
	$scriptPath = "res://scripts/core/defs/combat_archetype.gd"
	switch ($entityKind) {
		"plant" {
			$scriptClass = "PlantArchetype"
			$scriptPath = "res://scripts/core/defs/plant_archetype.gd"
		}
		"zombie" {
			$scriptClass = "ZombieArchetype"
			$scriptPath = "res://scripts/core/defs/zombie_archetype.gd"
		}
	}
	$templateResPath = "res://" + ((Resolve-Path $TemplatePath).Path.Substring($RepoRoot.Length + 1) -replace "\\","/")
	$dataCombatRoot = Split-Path (Split-Path (Split-Path $TemplatePath -Parent) -Parent) -Parent
	$archetypeDir = Join-Path $dataCombatRoot ("archetypes/" + ($entityKind + "s"))
	if ($entityKind -eq "field_object") {
		$archetypeDir = Join-Path $dataCombatRoot "archetypes/field_objects"
	}
	New-Item -ItemType Directory -Force -Path $archetypeDir | Out-Null
	$archetypeFile = Join-Path $archetypeDir ($archetypeId + ".tres")
	if (Test-Path $archetypeFile) {
		return
	}
	$entityKindLine = ""
	if ($entityKind -eq "field_object") {
		$entityKindLine = "entity_kind = &`"field_object`"`r`n"
	}
	$tags = @("archetype", $entityKind, "migrated")
	if ($metadata.Tags.Count -gt 0) {
		$tags += $metadata.Tags
	}
	$tags = $tags | Select-Object -Unique
	$tagExpr = ($tags | ForEach-Object { '"' + $_ + '"' }) -join ", "
	$body = @"
[gd_resource type="Resource" script_class="$scriptClass" load_steps=3 format=3]

[ext_resource type="Script" path="$scriptPath" id="1_archetype"]
[ext_resource type="Resource" path="$templateResPath" id="2_backend"]

[resource]
script = ExtResource("1_archetype")
archetype_id = &"$archetypeId"
$entityKindLine display_name = "$($metadata.DisplayName)"
tags = PackedStringArray($tagExpr)
compiler_hints = {
"migrated_wrapper": true
}
backend_entity_template = ExtResource("2_backend")
backend_entity_template_id = &"$($metadata.TemplateId)"
"@
	$body = $body -replace "`r`n ", "`r`n"
	Write-Utf8NoBom -Path $archetypeFile -Content $body
}

function Add-ArchetypeIdSiblingLine {
	param(
		[string]$Path,
		[string]$LegacyProperty
	)
	$content = Get-Content -Raw $Path
	$pattern = "^(?<indent>\s*)" + [regex]::Escape($LegacyProperty) + " = &`"(?<template>[^`"]+)`"$"
	$updated = [regex]::Replace($content, $pattern, {
		param($match)
		$indent = $match.Groups["indent"].Value
		$templateId = $match.Groups["template"].Value
		$archetypeId = Convert-TemplateIdToArchetypeId -TemplateId $templateId
		$legacyLine = $match.Value
		$archetypeLine = $indent + "archetype_id = &`"" + $archetypeId + "`""
		return $archetypeLine + [Environment]::NewLine + $legacyLine
	}, [System.Text.RegularExpressions.RegexOptions]::Multiline)
	if ($updated -ne $content) {
		Write-Utf8NoBom -Path $Path -Content $updated
	}
}

function Replace-DictionaryTemplateKeys {
	param(
		[string]$Path
	)
	$content = Get-Content -Raw $Path
	$updated = [regex]::Replace($content, '"entity_template_id": &"([^"]+)"', {
		param($match)
		$templateId = $match.Groups[1].Value
		$archetypeId = Convert-TemplateIdToArchetypeId -TemplateId $templateId
		'"archetype_id": &"' + $archetypeId + '"'
	})
	if ($updated -ne $content) {
		Write-Utf8NoBom -Path $Path -Content $updated
	}
}

function Remove-DuplicateArchetypeLines {
	param(
		[string]$Path
	)
	$content = Get-Content -Raw $Path
	$updated = [regex]::Replace(
		$content,
		'^(?<indent>\s*)archetype_id = &[^\r\n]+\r?\n(?:(?<indent2>\s*)archetype_id = &[^\r\n]+\r?\n)+',
		{
			param($match)
			$lines = $match.Value -split "\r?\n" | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
			if ($lines.Count -eq 0) {
				return $match.Value
			}
			return $lines[0] + [Environment]::NewLine
		},
		[System.Text.RegularExpressions.RegexOptions]::Multiline
	)
	if ($updated -ne $content) {
		Write-Utf8NoBom -Path $Path -Content $updated
	}
}

function Normalize-TresEncoding {
	param(
		[string]$Path
	)
	$content = Get-Content -Raw $Path
	Write-Utf8NoBom -Path $Path -Content $content
}

function Migrate-ContentReferences {
	param(
		[string]$RepoRoot
	)
	$paths = @(
		(Join-Path $RepoRoot "data/combat/cards"),
		(Join-Path $RepoRoot "data/combat/waves"),
		(Join-Path $RepoRoot "data/combat/levels"),
		(Join-Path $RepoRoot "scenes/validation"),
		(Join-Path $RepoRoot "scenes/demo"),
		(Join-Path $RepoRoot "extensions")
	)
	foreach ($path in $paths) {
		if (-not (Test-Path $path)) {
			continue
		}
		Get-ChildItem -Recurse -File $path -Filter *.tres | ForEach-Object {
			$file = $_.FullName
			Add-ArchetypeIdSiblingLine -Path $file -LegacyProperty "entity_template_id"
			Add-ArchetypeIdSiblingLine -Path $file -LegacyProperty "object_template_id"
			Replace-DictionaryTemplateKeys -Path $file
			Remove-DuplicateArchetypeLines -Path $file
			Normalize-TresEncoding -Path $file
		}
	}
}

function Repair-ArchetypeDirectories {
	param(
		[string]$RepoRoot
	)
	$wrongRoots = @(
		(Join-Path $RepoRoot "data/combat/entity_templates/archetypes"),
		(Join-Path $RepoRoot "extensions/minimal_chaos_pack/data/combat/entity_templates/archetypes"),
		(Join-Path $RepoRoot "extensions/phase5_chaos_pack/data/combat/entity_templates/archetypes")
	)
	foreach ($wrongRoot in $wrongRoots) {
		if (-not (Test-Path $wrongRoot)) {
			continue
		}
		Get-ChildItem -Recurse -File $wrongRoot -Filter *.tres | ForEach-Object {
			$source = $_.FullName
			$segments = $source -split '\\\\'
			$kind = if ($segments -contains 'plants') { 'plants' } elseif ($segments -contains 'zombies') { 'zombies' } else { 'field_objects' }
			$targetRoot = $source.Split('\\entity_templates\\')[0]
			$targetDir = Join-Path $targetRoot ("archetypes/" + $kind)
			New-Item -ItemType Directory -Force -Path $targetDir | Out-Null
			$target = Join-Path $targetDir $_.Name
			if (-not (Test-Path $target)) {
				Move-Item $source $target
			}
		}
		Remove-Item -Recurse -Force $wrongRoot
	}
}

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path

Get-ChildItem -Recurse -File (Join-Path $repoRoot "data/combat/entity_templates") -Filter *.tres | ForEach-Object {
	Ensure-ArchetypeWrapper -TemplatePath $_.FullName -RepoRoot $repoRoot
}

Get-ChildItem -Recurse -File (Join-Path $repoRoot "extensions") -Filter *.tres | Where-Object { $_.FullName -like '*entity_templates*' } | ForEach-Object {
	Ensure-ArchetypeWrapper -TemplatePath $_.FullName -RepoRoot $repoRoot
}

Repair-ArchetypeDirectories -RepoRoot $repoRoot
Migrate-ContentReferences -RepoRoot $repoRoot

Write-Host "Mechanic-first content migration pass completed."
