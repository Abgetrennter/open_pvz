---
name: openpvz-completion-archive-sweep
description: Audit and optionally perform OpenPVZ post-implementation cleanup after a feature is completed. Use when the user asks to archive a completed draft/plan, verify wiki integration, check validation evidence, or confirm whether the related git work has been committed and pushed.
---

# OpenPVZ Completion Archive Sweep

## Purpose

Use this skill after a feature or workstream appears complete. The default mode is audit-only: report what remains to archive, document, validate, commit, or push. Modify files only when the user explicitly asks to perform cleanup.

## Required Inputs

Identify at least one of:

- feature name or workstream name
- source draft in `plans/draft/`
- formal plan or wiki page
- commit range, branch, or PR
- validation scenario names

If the user only says "this feature", infer from recent changed files and git history, then state the inference.

## Audit Workflow

1. Inspect `git status --short` and separate unrelated user changes.
2. Locate source planning artifacts:
   - `plans/draft/`
   - `plans/README.md`
   - relevant `plans/archive/`
   - linked wiki pages
3. Locate implementation evidence:
   - changed runtime/data/validation/docs files
   - validation scenarios in `tools/validation_scenarios.json`
   - formal coverage in `tools/formal_content_validation_map.json` when applicable
   - artifacts under `artifacts/validation/` if recent validation was run
4. Check wiki integration:
   - feature concepts moved from draft-only text into current wiki when they are now authoritative
   - wiki links and status language match the implemented state
   - outdated draft-only warnings are removed or preserved intentionally
5. Check plan/draft state:
   - completed drafts should be archived or marked superseded
   - `plans/README.md` should reflect current/archived/discussion status
   - root `plans/` should not keep completed one-off drafts as current facts unless intentionally maintained
6. Check git state:
   - uncommitted files relevant to the feature
   - local commits not pushed: `git status -sb`, `git log @{u}..HEAD` when upstream exists
   - remote commits not pulled: `git log HEAD..@{u}` when upstream exists
   - no assumption of commit/push success without evidence
7. Report a punch list ordered by risk.

## Optional Cleanup Mode

Only when the user explicitly asks to perform cleanup:

- update `plans/README.md`
- move completed drafts into `plans/archive/` when appropriate
- adjust wiki status/links to match implemented behavior
- add missing validation/documentation notes

Do not commit, push, stage, or create branches unless the user explicitly asks for those git operations.

## Report Shape

Use Chinese and keep it actionable:

- completion verdict: complete / mostly complete / incomplete
- draft and plan state
- wiki integration state
- validation evidence
- git commit/push state
- required cleanup actions
- optional follow-ups

Include exact file paths and commands used for git or validation evidence.

## Guardrails

- Do not archive active design material just because implementation started.
- Do not move or delete files in audit-only mode.
- Do not treat `plans/draft/` as a failure by itself; drafts can remain as discussion records if `plans/README.md` says so.
- Do not modify `vendor/`.
- Do not hide unrelated dirty worktree changes.
- Commit and push are dangerous operations in this project style: detect and report them, but require explicit user confirmation before executing.
