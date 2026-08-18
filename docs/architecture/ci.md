# CI Pipeline — Headless GUT on Push

> Sprint 1 task 1-21 (Nice-to-have) — established 2026-08-18.

## Trigger and job

`.github/workflows/ci.yml` runs one job, `headless-gut`, on:

- **push** to `main` — the sprint's acceptance criterion ("green on `main`")
- **pull_request** — so test results surface as PR checks before merge

The job runs the project's canonical headless GUT suite:

```
godot --headless --path . --script res://tests/gdunit4_runner.gd
```

(`tests/gdunit4_runner.gd` is a thin subclass of GUT's official CLI entry;
equivalent to the repo's documented invocation
`godot --headless --script tests/gdunit4_runner.gd` — see tests/gdunit4_runner.gd
and Sprint 1 task 1-5).

GUT is configured with `should_exit: true` (`.gutconfig.json`), so a failing
suite exits nonzero and fails the job. The job has `timeout-minutes: 10` as a
hang guard.

## Engine version pin

| Field | Value |
|-------|-------|
| **Pinned version** | `4.6-stable` |
| **Local dev engine** | `4.6.stable.official.89cea1439` (task 1-1 install, `~/.local/bin/godot`) |
| **Pinned reference** | `docs/engine-reference/godot/VERSION.md` (Godot 4.6, project pinned 2026-02-12) |
| **Workflow input** | `appsinacup/setup-godot-action` `version: '4.6-stable'` |

The workflow also verifies the installed engine at job start
(`"$GODOT4" --version`) so a drifting action default cannot silently change
the engine under the suite.

## Engine caching

The setup action (`appsinacup/setup-godot-action`, marketplace "Setup Godot
Engine") is used with `enable_cache: 'true'`:

- it downloads the official Godot release binary
  (`Godot_v4.6-stable_linux.x86_64.zip` from godotengine/godot) into
  `godot-bin/` and exposes it via the `GODOT4` env var plus PATH;
- with caching enabled it wraps the download in `actions/cache@v4` keyed
  `godot-editor-godotengine/godot-4.6-stable-false-Linux` (repo-version-mono-OS),
  so the ~60 MB binary is restored on later runs instead of re-downloaded;
- it also installs Linux runner dependencies (`libwebkit2gtk-4.1-0`,
  `libgtk-3-0`) required by the editor binary.

## Action pin

`appsinacup/setup-godot-action` is referenced by **full commit SHA**
(`8eeed21ba847d6ace719525581d2ac4e398f117b`), which corresponded to `main` as
of 2026-08-18 (verified via `git ls-remote`). The action is a composite action
(no precompiled payload), so the pinned implementation is auditable in-repo.
Update the pin deliberately when validating a new version; do not float `@main`.

## First-run import

`.godot/` is gitignored, so a fresh clone has no imported assets. The workflow
runs `"$GODOT4" --headless --path . --import` once before the suite so tests
run against fully imported resources (portrait/map placeholders, `.tres`
catalogues, etc.).

## WSL / local equivalence

The sprint's primary evidence remains the local WSL headless run (QA plan OQ-B);
CI is a clean-room fallback and the PR-check layer. The exact commands above
were verified locally before this workflow was committed (see task 1-21
verification in `production/session-state/active.md`).

## Known limitation

GitHub Actions cannot be executed from a local WSL checkout. This workflow is
validated by: (1) `actionlint` (v1.7.12) — zero errors zero warnings; (2) a
PyYAML syntax parse; (3) local execution of the exact commands (import, GUT
suite, engine version check). The first real run happens on the next push to
`main`; if the job misbehaves there, fix and re-push — the workflow itself is
not a source of game-state risk.