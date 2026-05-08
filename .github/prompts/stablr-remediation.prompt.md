---
description: >
  Convert a stablr scientific audit (audits/YYYY-MM-DD-*.md) into a strict test-driven
  implementation plan: red-green-refactor work items with failing regression tests written
  first, parity-pinning tests for STABL.md invariants, and explicit acceptance gates.
  Plan-only by default; on confirmation, executes one work item at a time under TDD discipline.
name: "stablr Audit → TDD Remediation Plan"
argument-hint: "Path to the audit file under audits/ (e.g. audits/2026-05-08-full-package.md). Optional: a single finding ID (e.g. H-1) to scope the plan."
agent: "agent"
model: ['Claude Opus 4.7 (copilot)', 'Claude Opus 4.5 (copilot)', 'Claude Opus 4.1 (copilot)', 'Claude Sonnet 4.5 (copilot)']
tools: [codebase, search, searchResults, usages, findTestFiles, problems, testFailure, fetch, githubRepo, runCommands, terminalLastCommand, terminalSelection, editFiles]
---

You are converting a completed **stablr scientific audit** into a **strict test-driven remediation plan** for the R reimplementation of the Python STABL stability-based feature selection method.

## Inputs

- **Audit file** (required): the dated report under `audits/` named in the user's invocation. Read it in full before planning.
- **Authoritative spec**: `STABL.md` (algorithm contract + parity-critical invariants).
- **Workflow policy**: `AGENTS.md` (precedence rules, repo conventions, update discipline).
- **Live state**: `PLAN.md`, `PROGRESS.md`, `HANDOFF.md`.
- **Source under change**: `r-pkg/stablr/R/` and `r-pkg/stablr/tests/testthat/`.

If the user names a single finding ID (e.g. `H-1`, `M-3`, `V-4`), restrict the plan to that finding plus any tightly coupled findings; otherwise plan all High-Risk and Medium-Risk items, plus the Verification Plan items (V-*) the audit recommends adding as tests.

## Goal

Produce a **sequenced, TDD-disciplined remediation plan** in which every behavioural change is:

1. **Specified** by citing the relevant clause in `STABL.md` (or, if the spec is silent, by an explicit decision recorded in the plan with rationale and a `STABL.md` patch proposal).
2. **Pinned** by a new failing `testthat` test written *before* any source edit (red).
3. **Implemented** by the smallest source change that makes the new test pass without breaking existing tests (green).
4. **Locked in** by a regression test that would have caught the original audit finding, even if the implementation is later refactored.
5. **Documented** with a one-line entry in `PROGRESS.md` and, where scope or invariants change, an update to `PLAN.md` and/or `STABL.md`.

## Operating Mode

- **Default: plan only.** Produce the full remediation plan and stop. Do **not** edit source, tests, or docs in this pass.
- **On explicit user confirmation** (e.g. "execute step 1", "go", "implement H-1"), enter execution mode for **one work item at a time**, following the TDD loop below. Re-prompt for confirmation before each subsequent item.
- Honour `AGENTS.md` precedence: `STABL.md` > `PLAN.md` > `PROGRESS.md` > `HANDOFF.md` > `AGENTS.md`. If the audit conflicts with `STABL.md`, the spec wins unless the plan explicitly proposes (and justifies) a spec change.
- Preserve documented Python-R divergences (`round` vs `floor`, `seq` vs `np.arange` endpoint, column-major vs row-major upper-triangle) unless the audit shows they break a parity invariant.
- Keep optional dependencies (`sparsegl`, `knockoff`, `future`, `furrr`, `multiview`) optional. Tests that require them must `skip_if_not_installed()`.

## Triage Rubric

Map every audit item to one of:

- **FIX-NOW** — High-risk parity break or silent correctness bug. Always gets a regression test + source fix.
- **FIX-SOON** — Medium-risk divergence or fragility with a clear correct behaviour. Test + fix.
- **DECIDE-THEN-FIX** — Audit flagged as "Unclear Assumption". Plan must surface a small set of options (with a recommended one and reasons) for the user before any test or code is written.
- **TEST-ONLY** — Behaviour is correct but unverified. Add a regression/calibration test; no source change.
- **DOC-ONLY** — Docstring/spec mismatch. Update `STABL.md` and/or roxygen; no behavioural change.
- **DEFER** — Out of current scope. Record in `PLAN.md § Open Milestones` with rationale; do not plan further.

Sequence items by: (a) blockers first (anything other items depend on), (b) FIX-NOW before FIX-SOON before TEST-ONLY before DOC-ONLY, (c) cheapest-credible-first within a tier.

## TDD Loop (per work item, executed only on confirmation)

For each work item, follow this loop strictly:

1. **Restate** the finding, the spec clause it ties to, and the acceptance criterion in one short paragraph.
2. **RED** — Write the new `testthat` test(s) under `r-pkg/stablr/tests/testthat/`. The test must:
   - Fail on the current `HEAD` for the reason stated in the audit (not for an unrelated reason).
   - Assert the *spec-defined* invariant, not an implementation detail (e.g. assert `get_importances()` max-over-lambda parity, not `rowMeans(stabl_scores_)`).
   - Be self-sufficient (testthat 3 style: explicit fixtures, `withr::local_seed()`, `skip_if_not_installed()` for optional deps).
   - Run quickly (< 5 s) where possible; mark slow calibration tests with `skip_on_cran()` and place them in a clearly named file (e.g. `test-fdp-calibration.R`).
   - Run via `devtools::test_active_file()` (or `testthat::test_file`) and confirm failure with the *expected* message.
3. **GREEN** — Make the smallest source edit in `r-pkg/stablr/R/` that makes the new test pass. No drive-by refactors, no tangential cleanup, no new public API unless the spec demands it.
4. **REGRESSION GUARD** — Add (or extend) a second test that would catch a future regression of the original audit finding even if internals are refactored. For numeric parity, prefer `expect_equal(..., tolerance = ...)` with a documented tolerance tied to `STABL.md`.
5. **FULL SUITE** — Run `devtools::test()` on the package. All previously passing tests must still pass. If any pre-existing test now fails, stop and report — do not "fix" it without explicit confirmation; an existing test failure may itself be evidence of a deeper bug or a contract change.
6. **DOCUMENT** — Append a single dated line to `PROGRESS.md` (`YYYY-MM-DD: <finding-id> — <one-line outcome>, tests: <files>`). Update `PLAN.md` if scope/sequencing changed. Update `STABL.md` only if a parity-critical invariant or documented divergence changed; cite the audit finding ID in the diff.
7. **HANDOFF** — Update `HANDOFF.md § Immediate Next Tasks` so a fresh session can resume cleanly.

If the test cannot be written without first deciding an open question, stop the loop at step 1, escalate as a `DECIDE-THEN-FIX` item, and present the user with a short batch of multiple-choice options (recommended option highlighted with reasons) per the user's stated preference. Do not write speculative tests.

## Test Authoring Standards

- Use `testthat` edition 3 idioms; one assertion-cluster per test; one behaviour per file when practical.
- Pin spec invariants symbolically where possible (e.g. strict `>` and `(1/π)` checks on hand-computed tiny matrices, as in audit V-6) before falling back to simulation.
- Calibration-under-null tests (audit V-4) must use a fixed seed, document the expected upper bound on selections, and explain the statistical justification in a comment referencing `STABL.md`.
- Signal-recovery tests (audit V-5) must use a fixed seed and assert exact selected sets where the SNR allows; otherwise assert recall ≥ K with K justified.
- Parallel-determinism tests (audit V-7) must `skip_if_not_installed("furrr")`, set `future::plan(future::sequential)` in teardown via `withr::defer`, and compare full `stabl_scores_` matrices with `expect_equal` (not the weak overlap-of-top-K idiom).
- Group-bootstrap tests (audit V-1) must include both **numeric/integer** and **character** group label types.
- For accessor round-trips (audit V-10), assert `get_feature_names_out(fit)` equals `names(get_support(fit))[get_support(fit)]`.
- Never weaken an existing test to make a new one pass.

## Output Format (Plan Mode)

Produce the plan in this exact structure. Keep it concise; cite audit IDs and `STABL.md` clauses inline.

### 1. Plan Summary
3–6 bullets: scope, total work items by tier, blockers, expected order of execution, any DECIDE-THEN-FIX items needing user input before TDD can start.

### 2. Decisions Required Before Coding
For each `DECIDE-THEN-FIX` item, present a small batch (≤ 3) of multiple-choice options with a clearly highlighted recommendation and 1–2 strong reasons each, per user preference. Ask only what is needed to unblock the next work item; do not front-load every open question.

### 3. Work Items (Ordered)
Number each item `WI-NN`. For each:

- **Audit ref** — finding IDs from the audit (e.g. `H-1`, `V-1`).
- **Tier** — FIX-NOW / FIX-SOON / DECIDE-THEN-FIX / TEST-ONLY / DOC-ONLY / DEFER.
- **Spec anchor** — the `STABL.md` clause (or "spec silent — see Decision X").
- **Acceptance criterion** — the single observable behaviour that, once true, closes the item.
- **RED test plan** — the new test file/name(s), the assertion(s), and the expected pre-fix failure message.
- **GREEN change plan** — the smallest source edit (file + function + nature of change), with a one-line note on why this is the minimum sufficient change.
- **Regression guard** — the additional test that would catch a future re-introduction.
- **Risk / blast radius** — what else could break; which existing tests are most likely to be sensitive.
- **Doc updates** — `PROGRESS.md`, `PLAN.md`, `STABL.md`, roxygen — only what is actually required.
- **Estimated effort** — XS / S / M / L (no time estimates per repo convention).

### 4. Cross-Cutting Test Infrastructure (if needed)
List shared fixtures, helpers, or skip-guards to add once and reuse (e.g. a Python parity fixture loader keyed on `python_max_score` and `python_support` instead of `python_mean_score`).

### 5. Acceptance Gate for the Whole Plan
The conditions under which the audit can be marked closed:

- All FIX-NOW and FIX-SOON items green; all new regression tests passing.
- `devtools::test()` and `R CMD check` clean (or pre-existing warnings explicitly catalogued and unchanged).
- `STABL.md` parity invariants section reflects any deliberate changes; `PLAN.md` and `PROGRESS.md` updated; `HANDOFF.md` reflects current state.
- A short "audit closure" note appended to the original audit file pointing to the `PROGRESS.md` entries that resolved each finding.

### 6. Out-of-Scope / Deferred
List `DEFER` items with rationale and the `PLAN.md` section they were filed under.

## Anti-Patterns to Reject

- Writing the source fix before the failing test exists.
- Asserting on `rowMeans(stabl_scores_)` or other non-spec statistics for parity (audit H-3).
- Loosening an existing test to accommodate a new behaviour without explicit user sign-off and a `STABL.md` update.
- Bundling multiple audit findings into a single commit-equivalent change.
- Adding speculative tests for `DECIDE-THEN-FIX` items before the decision is recorded.
- Touching files outside the work item's blast radius "while we're here".
- Re-seeding RNG in helpers in ways that mask reproducibility (audit M-5) — any new `set.seed` must be justified in the GREEN change plan.

## Final Notes

- Be brief in chat; the plan lives in this response (or in the audit file as an appended `## Remediation Plan` section if the user prefers — ask once if unclear).
- Do not estimate calendar time. Use XS/S/M/L only.
- When uncertain whether a behaviour is spec or implementation detail, stop and ask — do not guess.
