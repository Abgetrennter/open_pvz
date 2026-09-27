# Local setup and actions

Run `pwsh .codex/scripts/setup_openpvz_worktree.ps1` once in a fresh clone or worktree. It resolves Godot, optionally mounts an explicitly requested private pack, and runs headless editor import to build the resource/class cache. `-CheckOnly` checks executable resolution without import or mounts. A separate GUI binary is optional.

Both setup and `run_openpvz_action.ps1` resolve the console executable in this order:

1. `-GodotConsole` / `OPENPVZ_GODOT_CONSOLE`.
2. `PVZ_WS_GODOT_EXE`.
3. `-GodotHome` / `OPENPVZ_GODOT_HOME`.
4. Ancestor workspace `pvz-ws.config.json` (also found through the Git common directory for worktrees outside the workspace).
5. A local `Godot_v*_win64_console.exe`, then `godot` on PATH.

GUI resolution uses the corresponding `GodotGui`, `OPENPVZ_GODOT_GUI`, `PVZ_WS_GODOT_GUI_EXE`, and `godotGuiExe` settings. Invalid configured executable paths fail explicitly.

Standalone clones need no workspace, reference mirrors, or private assets. For example:

```powershell
pwsh .codex/scripts/setup_openpvz_worktree.ps1 -GodotConsole C:/Tools/Godot/godot.exe
pwsh .codex/scripts/run_openpvz_action.ps1 -Action validate_smoke -GodotConsole C:/Tools/Godot/godot.exe
```

Submodule setup defaults to `none`; no retired `vendor/*` paths are requested. Private assets also default to `none`. Private `link` mode requires an explicit source; workspace mount/write policy still applies. Local actions propagate the child process exit code.
