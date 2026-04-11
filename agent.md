# Project Agent Notes

## Godot Paths

- Console: `E:\SDK\Godot\Godot_v4.6.1-stable_win64_console.exe`
- GUI: `E:\SDK\Godot\Godot_v4.6.1-stable_win64.exe`

## Default Read Order

Before doing substantial coding or "vibe coding" in this repo, read these docs first:

1. `wiki/23-当前阶段与实现路线.md`
2. `wiki/26-开发路线图.md`
3. `wiki/27-项目开发方法论.md`
4. `wiki/28-Wiki审查与规范化建议.md`
5. `wiki/29-文档规范与维护约定.md`

`wiki/27-项目开发方法论.md` is the default process guide for this repository. `wiki/28-Wiki审查与规范化建议.md` and `wiki/29-文档规范与维护约定.md` define the expected wiki structure and maintenance rules. If there is any ambiguity about how to proceed, use these as the governing workflow and documentation documents.

## Working Rules

When making engine or runtime changes in this repo:

- Define the problem at the right level first: concept, protocol, implementation, validation, or content.
- Do not patch visible symptoms directly into the backbone if the issue is really a missing abstraction.
- Separate backbone work, content work, and demo work. Do not treat a demo-only fix as backbone completion.
- Prefer explicit Resource-based configuration over long-lived bare dictionaries.
- Add or update a validation scene and an automation entry when changing core behavior.
- Use logs and repeatable validation as the standard for correctness, not visual intuition alone.
- When a new abstraction is introduced, identify what older logic must migrate with it so mixed models do not remain in the codebase.
- If a change affects project assumptions, protocol boundaries, validation rules, or documentation structure, update the relevant wiki docs in the same pass.

## Practical Checklist

Before major changes:

- Clarify goal
- Clarify non-goals
- Clarify acceptance criteria
- Identify migration scope

After major changes:

- Run headless Godot startup
- Run relevant validation scenario(s)
- Check logs if behavior is spatial, event-driven, or timing-sensitive
- Update wiki/resources if protocol or workflow changed

## Validation Commands

- Headless startup:
  - `& 'E:\SDK\Godot\Godot_v4.6.1-stable_win64_console.exe' --headless --path 'E:\Code\open_pvz' --quit-after 3`
- Long-range parabola validation:
  - `& 'E:\Code\open_pvz\tools\run_validation.ps1'`
