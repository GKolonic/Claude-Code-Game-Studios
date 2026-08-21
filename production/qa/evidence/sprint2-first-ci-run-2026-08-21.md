# Sprint 2 — First CI Evidence (task 2-11, first real GitHub Actions run)
**Date**: 2026-08-21
**Task**: 2-11 — First CI run on GitHub Actions
**Run**: #15 — status=completed, conclusion=success
**URL**: https://github.com/GKolonic/Claude-Code-Game-Studios/actions/runs/32439957862
**Repo**: GKolonic/Claude-Code-Game-Studios (public)
**Workflow**: .github/workflows/ci.yml
**Event**: push to main
**Head SHA**: 7f50497cb566ab741881bd89728236d346275979
**Verified**: via GitHub **public API** (orchestrator-verified externally; repo is public)
**QA plan**: decision #8 (first CI run at M2); OQ-B — CI evidence mandatory from this sprint. CI is a **clean-room check**; local WSL headless remains PRIMARY evidence (OQ-B).

> **Evidence-limitation note**: the raw run log endpoints return **HTTP 403** on the public API
> (raw/v2 `logs` download requires repo **admin** permissions). The evidence recorded here is
> therefore the **run/job status + per-step conclusions**, which the public API exposes without
> auth. This satisfies OQ-B: the CI run is a clean-room confirmation that the pinned-Godot import +
> headless GUT suite pass on a real GitHub Actions runner; the authoritative full-suite numbers
> (204/204, 22711 asserts, exit 0) live in the local WSL suite log
> (`production/qa/evidence/sprint2-full-suite-2026-08-18.log`).

## Job: "Headless GUT suite (Godot 4.6)" — conclusion=success
| # | Step | Conclusion |
|---|------|------------|
| 1 | Set up job | success |
| 2 | Check out repository | success |
| 3 | Set up Godot 4.6 (cached) | success — `enable_cache: 'true'`, `godot-bin/` cache key active |
| 4 | Verify pinned engine | success — `appsinacup/setup-godot-action@SHA` **4.6-stable** pin; `--version` → `4.6.stable` check passed |
| 5 | First-run asset import | success — `--import` step passed on the runner |
| 6 | Run headless GUT suite | success — `tests/gdunit4_runner.gd` exits **0**; `should_exit=true` gates the job |

All 6 steps green → job conclusion=success → run conclusion=success.

## Continuity — prior green runs (every M2 commit final state green)
| Run | Task | Conclusion |
|-----|------|------------|
| #14 | 2-9 | success |
| #13 | 2-8 | success |
| #12 | (2-7 batch) | success |
| #11 | 2-7 | success |
| #10 | 2-6 | success |
| #9 | 2-5 | success |
| #8 | 2-4 | success |
| #7 | 2-3 | success |
| #4/#5/#6 | 2-1/2-2/2-3 (pushed in a rapid burst) | `cancelled` — **superseded by a newer run on the same branch (concurrency), NOT failures**; the final state of every M2 commit is green |

## Conclusion
First real GitHub Actions run is **GREEN**: pinned Godot 4.6-stable import + headless GUT suite pass
on a real runner against head `7f50497` (the 2-10 status commit). This closes **QA plan OQ-B CI
evidence** requirement ("first real run observed at 2-11"). CI remains supplementary to the local
WSL-suite primary evidence. No code changed; no CI re-run performed (evidence recorded from the
already-completed run).
