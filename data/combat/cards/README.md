# Combat Card Data

This directory stores formal card-facing combat data.

## Rules

- `cards/` is for reusable card definitions, not validation-only requests.
- Card data should reference `EntityTemplate` ids instead of embedding runtime logic.
- Scenario resources may assemble a card roster from multiple card defs in this tree.

## Current Layout

- `demo/`
  - Demo card defs extracted from `demo_level` as the first formal split example.
