# Test Infrastructure — The Faithful / Divine Dominion

**Engine**: Godot 4.6 (4.6.stable.official.89cea1439) / GDScript
**Test Framework**: GUT (Godot Unit Test, bitwes/Gut) **v9.6.1** — vendored at `addons/gut/`
**Runner**: `tests/gdunit4_runner.gd` (thin subclass of GUT's official CLI entry)
**Config**: `.gutconfig.json` at project root
**Setup date**: 2026-08-11 (Sprint 1 task 1-5)

## Framework choice (recorded per task 1-5)

- `technical-preferences.md` pins **GUT** (bitwes/Gut). Two candidates were
  verified empirically on `4.6.stable.official.89cea1439` (the pinned engine
  reference does not cover third-party addons, so a headless run is the check):
  - **v9.7.1** (latest, 2026-07-10): REJECTED — `stub_params.gd` fails to parse
    on 4.6: the typed `return_val` getter returns `null` for a property whose
    type is inferred from `GutConstants.NOT_SET` (a `StringName`), and Godot
    4.4+ made `StringName` non-nullable. The doublers/stubbers subsystem would
    be unavailable to any test using `double()`/`stub()`.
  - **v9.6.1** (2026-07-09): ACCEPTED — `stub_params.gd` is clean
    (`var return_val = null`); full suite runs green headless with zero parse
    errors, and the release is the base of 9.7.1 (9.7.1 = 9.6.1 + bug fixes,
    so no functional gap). Chosen as the Godot 4.6-compatible version.
  Re-check for a fixed release before any suite relies on `double()`/`stub()`.
- Note on naming: the runner file is `tests/gdunit4_runner.gd` because the
  repo's CI rules and QA plan reference that exact path (it originates from the
  `/test-setup` skill template, which targets GdUnit4). The framework actually
  installed here is **GUT**, per technical-preferences.md and the Sprint 1 plan.
  If GdUnit4 is ever adopted, only the runner internals change; the command
  below stays the same.

## Directory Layout

```
tests/
  unit/                    # Isolated unit tests (formulas, state machines, logic)
    core/                  # Shared classes (GameEnums)
    <system>/              # One dir per system (game_config, trait_database, ...)
  integration/             # Cross-system and boot tests
  gdunit4_runner.gd        # Headless runner (this file)
```

## Running Tests

From the project root (WSL, local headless — primary Sprint 1 evidence):

```bash
godot --headless --script tests/gdunit4_runner.gd
```

- Reads `res://.gutconfig.json`: scans `tests/unit` + `tests/integration`
  (recursively) for `*_test.gd` scripts.
- Headless mode: GUT always exits after the run. Exit 0 = suite green;
  nonzero = at least one failure (gateable in CI, story 1-21).
- Overrides: `-- -gdir=... -glog=2 -gselect=...` (command line wins over config).

## Test Naming

- **Files**: `[system]_[feature]_test.gd` (e.g. `game_enums_test.gd`, `m0_boot_test.gd`)
- **Functions**: `test_[scenario]_[expected]` (e.g. `test_enum_4_persuaded_present`)
- GUT discovery: `suffix = "_test.gd"`, `prefix = ""` (set in `.gutconfig.json`)

## Story Type -> Test Evidence (coding-standards.md)

| Story Type | Required Evidence | Location | Gate |
|---|---|---|---|
| Logic | Automated unit test — must pass | `tests/unit/[system]/` | BLOCKING |
| Integration | Integration test OR documented playtest | `tests/integration/[system]/` | BLOCKING |
| Visual/Feel | Screenshot + lead sign-off | `production/qa/evidence/` | ADVISORY |
| UI | Manual walkthrough OR interaction test | `production/qa/evidence/` | ADVISORY |
| Config/Data | Smoke check pass | `production/qa/smoke-*.md` | ADVISORY |

## CI

Story 1-21 (Nice-to-Have) adds a GitHub Actions job running the same headless
command on push to `main`. CI evidence becomes mandatory from Sprint 2 (QA plan
OQ-B); local WSL headless is the primary evidence for Sprint 1.
