# stablr Benchmark Harness

End-to-end benchmark for the stablr R package, supporting:

1. **Cross-language parity** against the published Python STABL on all 6 benchmark datasets.
2. **Novel-feature characterisation** of MVR knockoffs and cooperative-learning fusion.

---

## Directory structure

```
inst/benchmark/
  R/
    bench_common.R          # Shared utilities (find_repo_root, preprocess_fit, ...)
    stage_datasets.R        # B1: Extract data.zip → scratch/benchmark/data/
    run_stablr_pipeline.R   # B3: Replay Python folds with stablr (knockoff_equi)
    compute_parity.R        # B4: Parity metrics → papers/application-note/artifacts/
    run_novel_mvr.R         # B5a: MVR FDR/power semi-synthetic benchmark
    run_novel_coop.R        # B5b: Cooperative-fusion rho sweep
  py/
    run_reference.py        # B2: Python STABL reference runner (all 6 datasets)
    knockoff_parity_reference.py  # A4: Python knockpy reference S-matrices
  config/
    datasets.yaml           # Per-dataset CV parameters (outer CV, n_bootstraps, lambda grids)
  slurm/
    parity_reference.slurm  # Submit B2 Python reference job
    parity_array.slurm      # Submit B3 R stablr array (18 tasks: 6 datasets × 3 learners)
    parity_aggregate.slurm  # Submit B4 after array completes
    novel_mvr.slurm         # Submit B5a MVR benchmark
    novel_coop.slurm        # Submit B5b cooperative rho sweep
```

---

## Quick start

### Prerequisites

```bash
# 1. R package loaded (dev install)
Rscript -e 'pkgload::load_all("r-pkg/stablr")'

# 2. Python environment with stabl + knockpy
#    Already at .venv-parity/ (see top-level README)
.venv-parity/bin/python -c "import stabl, knockpy; print('OK')"
```

### Step-by-step

```bash
# B1: Stage data (idempotent; run once after cloning or if zip changes)
Rscript r-pkg/stablr/inst/benchmark/R/stage_datasets.R
# → scratch/benchmark/data/{COVID-19,CFRNA,Biobank SSI,Dream,Onset of Labor}/

# B2: Python STABL reference (all 6 datasets — takes hours on full protocol)
.venv-parity/bin/python r-pkg/stablr/inst/benchmark/py/run_reference.py \
  --datasets COVID-19   # single dataset for smoke test
# → scratch/benchmark/reference/<dataset>/{predictions,selected,max_scores,folds}.csv

# B3: Matched stablr run (replays Python folds with knockoff_equi)
Rscript r-pkg/stablr/inst/benchmark/R/run_stablr_pipeline.R \
  --datasets COVID-19 --learners lasso --dry-run   # smoke test
# → scratch/benchmark/stablr_out/<dataset>/fold<N>_<learner>.rds

# B4: Parity metrics
Rscript r-pkg/stablr/inst/benchmark/R/compute_parity.R
# → papers/application-note/artifacts/parity_summary.csv
# → papers/application-note/artifacts/max_score_concordance.csv

# B5a: MVR FDR/power benchmark
Rscript r-pkg/stablr/inst/benchmark/R/run_novel_mvr.R --n-reps 5   # smoke
# → papers/application-note/artifacts/mvr_fdr_power.csv

# B5b: Cooperative-fusion rho sweep
Rscript r-pkg/stablr/inst/benchmark/R/run_novel_coop.R \
  --datasets SSI --n-folds 5   # smoke
# → papers/application-note/artifacts/coop_rho_sweep.csv
# → papers/application-note/artifacts/coop_rho_sweep_summary.csv
```

### On SLURM (full benchmark)

```bash
# 1. Stage data
Rscript r-pkg/stablr/inst/benchmark/R/stage_datasets.R

# 2. Python reference (single job, ~24h)
REF_JOB=$(sbatch --parsable r-pkg/stablr/inst/benchmark/slurm/parity_reference.slurm)

# 3. R stablr array (18 tasks, ~12h each)
ARRAY_JOB=$(sbatch --parsable \
  --dependency=afterok:${REF_JOB} \
  r-pkg/stablr/inst/benchmark/slurm/parity_array.slurm)

# 4. Aggregate metrics
sbatch --dependency=afterok:${ARRAY_JOB} \
  r-pkg/stablr/inst/benchmark/slurm/parity_aggregate.slurm

# 5. Novel feature benchmarks (independent of parity jobs)
sbatch r-pkg/stablr/inst/benchmark/slurm/novel_mvr.slurm
sbatch r-pkg/stablr/inst/benchmark/slurm/novel_coop.slurm
```

---

## Parity tiers

| Tier | Description | When to use |
|------|-------------|-------------|
| A (strict) | Python folds.csv is honored; R uses identical train/test splits | Primary parity claim |
| B (seed 42) | Both sides regenerate folds from `random_state=42` | Sanity check / fallback |

---

## Pass criteria (from BENCHMARK_PLAN Phase 1)

| Metric | Threshold |
|--------|-----------|
| Max-score Spearman (per learner × omic) | ≥ 0.90 |
| Selected-set Jaccard (per fold × learner) | ≥ 0.80 |
| Held-out AUC or R² fold-wise delta 95% CI | overlaps 0 |

---

## Outputs tracked in git

Only the curated manuscript artifact CSVs are committed (via `.gitignore` negation rules):

```
papers/application-note/artifacts/
  knockoff_parity.csv          # A4: MVR/equi S-matrix concordance vs knockpy
  parity_summary.csv           # B4: Cross-language parity performance deltas
  max_score_concordance.csv    # B4: Max-score Spearman × Jaccard per dataset × learner
  mvr_fdr_power.csv            # B5a: MVR vs equi vs RP FDR/power (committed after run)
  coop_rho_sweep_summary.csv   # B5b: Cooperative rho sweep summary (committed after run)
```

Large intermediate files (per-fold RDS, reference CSVs) live in `scratch/benchmark/`
and are **not** committed.
