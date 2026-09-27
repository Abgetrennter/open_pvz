# Shared by setup and local actions; standalone clones do not require pvz-ws.
function Find-OpenPvzWorkspaceConfig {
    param([string]$ProjectRoot)
    $starts = @($ProjectRoot)
    $common = & git -C $ProjectRoot rev-parse --path-format=absolute --git-common-dir 2>$null
    if ($LASTEXITCODE -eq 0) { $starts += Split-Path ([string]$common) -Parent }
    foreach ($start in $starts) {
        $directory = [IO.DirectoryInfo]::new($start)
        while ($null -ne $directory) {
            $candidate = Join-Path $directory.FullName 'pvz-ws.config.json'
            if (Test-Path -LiteralPath $candidate -PathType Leaf) { return $candidate }
            $directory = $directory.Parent
        }
    }
    return ''
}

function Resolve-OpenPvzExecutable {
    param(
        [string]$ProjectRoot,
        [string]$ExplicitPath,
        [string]$GodotHome,
        [switch]$Gui,
        [switch]$Optional
    )
    $candidate = $ExplicitPath
    $configPath = Find-OpenPvzWorkspaceConfig $ProjectRoot
    if (!$candidate) {
        $candidate = if ($Gui) { $env:PVZ_WS_GODOT_GUI_EXE } else { $env:PVZ_WS_GODOT_EXE }
    }
    $filter = if ($Gui) { 'Godot_v*_win64.exe' } else { 'Godot_v*_win64_console.exe' }
    if (!$candidate -and $GodotHome) {
        if (!(Test-Path -LiteralPath $GodotHome -PathType Container)) { throw "GodotHome not found: $GodotHome" }
        $candidate = (Get-ChildItem -LiteralPath $GodotHome -Filter $filter -File | Sort-Object Name -Descending | Select-Object -First 1).FullName
        if (!$candidate -and !$Optional) { throw "Godot executable not found in $GodotHome" }
    }
    if (!$candidate -and $configPath) {
        $config = Get-Content -LiteralPath $configPath -Raw | ConvertFrom-Json
        $candidate = if ($Gui) { $config.external.godotGuiExe.value } else { $config.external.godotExe.value }
        if ($candidate -and ![IO.Path]::IsPathRooted($candidate)) {
            $candidate = Join-Path (Split-Path $configPath -Parent) $candidate
        }
    }
    if (!$candidate) {
        $candidate = (Get-ChildItem -LiteralPath $ProjectRoot -Filter $filter -File | Sort-Object Name -Descending | Select-Object -First 1).FullName
    }
    if (!$candidate) { $candidate = (Get-Command godot -CommandType Application -ErrorAction SilentlyContinue).Source }
    if (!$candidate) {
        if ($Optional) { return '' }
        throw 'Godot not found. Set -GodotConsole, OPENPVZ_GODOT_CONSOLE, PVZ_WS_GODOT_EXE, OPENPVZ_GODOT_HOME, workspace config, or PATH.'
    }
    if (Test-Path -LiteralPath $candidate -PathType Leaf) { return (Resolve-Path -LiteralPath $candidate).Path }
    $command = Get-Command $candidate -CommandType Application -ErrorAction SilentlyContinue
    if ($command) { return $command.Source }
    throw "Configured Godot executable does not exist: $candidate"
}
