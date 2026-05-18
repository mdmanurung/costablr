# AGENTS.md

**Purpose:** Workflow policy and operating discipline for AI agents in this repository.

**This document owns:**
- Precedence rules for conflicting guidance across docs.
- Update discipline and change notification protocol.
- Behavioral execution principles for AI coding agents.
- Repository conventions and guardrails.
- Separation of responsibilities (what lives where).

**This document does NOT own:**
- Algorithm semantics (→ STABL.md)
- Forward work and acceptance gates (→ PLAN.md)
- Completed work and validation evidence (→ PROGRESS.md)
- Operator snapshot and immediate task queue (→ HANDOFF.md)

**Cross-reference pattern:** When in doubt, check the precedence order below.

## Documentation Contract (Read First)

These files are an integrated documentation system for the R reimplementation:

- `STABL.md`: algorithm contract and Python-to-R parity semantics.
- `PLAN.md`: forward-looking roadmap, phase gates, and remaining work.
- `PROGRESS.md`: factual execution log of what is implemented and validated.
- `HANDOFF.md`: fresh-session bootstrap runbook and parity ledger.
- `AGENTS.md` (this file): workflow policy for how agents must operate.

Priority order when documents appear to conflict:

1. `STABL.md` for algorithm semantics and parity-critical behavior.
2. `PLAN.md` for scope, sequencing, and acceptance targets.
3. `PROGRESS.md` for current implementation and validation state.
4. `HANDOFF.md` for immediate execution bootstrap in fresh sessions.
5. `AGENTS.md` for process and operating discipline.

Update discipline:

- If implementation changes behavior/specification, update `STABL.md`.
- If implementation changes scope or priorities, update `PLAN.md`.
- After each implementation step, append outcomes to `PROGRESS.md`.
- Before ending a coding task, ensure `PLAN.md`, `PROGRESS.md`, and `HANDOFF.md` are all updated.

## Important Repository Conventions

- Keep compatibility with scikit-learn estimator patterns (fit/predict/get_support and clone-friendly behavior).
- Preserve pandas index alignment assumptions between feature matrices and outcomes.
- Do not silently change random-state behavior; scripts and modules rely on reproducibility through explicit seeds.
- Prefer adding new functionality inside existing domain modules instead of creating parallel utility layers.
- Maintain tolerance-based Python-to-R parity for core STABL semantics documented in `STABL.md`.
- For cooperative fusion work, use `multiview/` as the only in-repo reference and do not reintroduce standalone `cooperative-learning/` codepaths.

## Workflow Discipline

- After each implementation step, always update both `PLAN.md` and `PROGRESS.md` before ending the task response.
- Before substantial implementation, ask refining questions and include recommended options with brief reasons.
- If user intent is already specific enough to proceed safely, execute directly and document assumptions in `PROGRESS.md`.
- Use `PROGRESS.md` for facts only (what changed, what passed, what is pending), not speculative planning.
- When interacting with users, proceed step-by-step and avoid presenting too many recommendations at once unless explicitly requested.

## Behavioral Execution Principles

These principles bias toward caution over speed. For trivial tasks, use judgment and keep the process lightweight.

### Think Before Coding

- State assumptions explicitly before implementing. If uncertainty changes the outcome, ask first.
- When multiple interpretations exist, present them instead of choosing silently.
- Surface tradeoffs, simpler approaches, and warranted pushback early.
- If the request is unclear, stop, name what is confusing, and ask a focused question.

### Simplicity First

- Write the minimum code that solves the requested problem.
- Do not add speculative features, single-use abstractions, unrequested configurability, or error handling for impossible scenarios.
- If a solution is substantially longer or more complex than necessary, simplify it before finalizing.
- Treat "Would a senior engineer call this overcomplicated?" as a practical review check.

### Surgical Changes

- Touch only files and lines that trace directly to the user's request.
- Do not refactor, reformat, or "improve" adjacent code unless it is required for the task.
- Match existing style and local patterns, even when a different style would be preferable in isolation.
- Clean up imports, variables, functions, and files made unused by the current change.
- Mention unrelated dead code or cleanup opportunities instead of deleting them unless asked.

### Goal-Driven Execution

- Convert each task into verifiable success criteria before or during implementation.
- For bug fixes, prefer a test or check that reproduces the failure before making it pass.
- For validation work, cover invalid inputs and expected edge cases, then verify the checks pass.
- For refactors, preserve behavior and run appropriate checks before and after when feasible.
- For multi-step tasks, state a short plan that pairs each step with its verification check.

## R Reimplementation Guardrails

- Treat `R/stabl_fit.R` and `STABL.md` as the algorithmic source of truth for the R path.
- Keep S3 object contracts and accessor behavior stable unless a documented change is requested.
- Ensure grouped sampling paths prevent leakage and preserve reproducibility controls.
- Keep optional dependencies (`sparsegl`, `knockoff`, `future`, `furrr`) as optional unless scope explicitly changes.

## Separation Of Responsibilities

To minimize drift and duplication, keep content in only one canonical place:

- `STABL.md`: algorithm semantics and parity rules.
- `PLAN.md`: forward-looking work, acceptance criteria, and open milestones.
- `PROGRESS.md`: completed work + validation evidence.
- `HANDOFF.md`: current operator snapshot, immediate next tasks, and execution commands.
- `AGENTS.md`: process policy for how agents must work.

When information changes, update the canonical file first and then only add short pointers in companion docs.

## Agent skills

### Issue tracker

Issues and PRDs for this repo live in GitHub Issues for `mdmanurung/costablr`. See `docs/agents/issue-tracker.md`.

### Triage labels

This repo uses the default five-label triage vocabulary. See `docs/agents/triage-labels.md`.

### Domain docs

This repo uses the canonical documentation set described above. See `docs/agents/domain.md` for how agent skills should consume those docs.

## References

- Usage and environment onboarding: [README.md](README.md)
- Live execution entrypoint for fresh sessions: [HANDOFF.md](HANDOFF.md)
- Planning and execution records: [PLAN.md](PLAN.md), [PROGRESS.md](PROGRESS.md)
