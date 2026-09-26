# Inserts visual_profile_id = &"classic_original.entity.plant.<id>.visual" into every
# archetype_original_*.tres that lacks it, placing it right after display_name (the
# layout the 5 already-bound archetypes use). Idempotent: skips files already bound.
param([string]$Dir = "data/combat/archetypes/plants")

$ErrorActionPreference = 'Stop'
$bound = 0
$added = 0
Get-ChildItem $Dir -Filter 'archetype_original_*.tres' | ForEach-Object {
	$f = $_.FullName
	$id = $_.BaseName -replace '^archetype_original_', ''
	$content = Get-Content -LiteralPath $f -Raw
	if ($content -match 'visual_profile_id') { $bound++; return }
	$vp = "classic_original.entity.plant.$id.visual"
	$line = "visual_profile_id = &`"$vp`""
	# Match display_name = "..." followed by a newline (CRLF or LF).
	if ($content -match "(?ms)^(display_name = `"[^`"]*`")`r?`n") {
		$anchor = $Matches[1]
		$new = $content -replace "(?ms)^(display_name = `"[^`"]*`")`r?`n", "`$1`r`n$line`r`n"
	} else {
		Write-Warning "no display_name anchor in $id; skipping"
		return
	}
	if ($new -eq $content) {
		Write-Warning "substitution failed for $id; skipping"
		return
	}
	Set-Content -LiteralPath $f -Value $new -NoNewline -Encoding UTF8
	$added++
}
Write-Output ("already bound: $bound")
Write-Output ("newly bound:   $added")
Write-Output ("total:         $($bound + $added)")
