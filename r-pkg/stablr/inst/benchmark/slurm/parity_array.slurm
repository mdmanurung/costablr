#!/usr/bin/env bash
# parity_array.slurm — B6: SLURM array for the cross-language parity benchmark.
#
# One task per (dataset, learner) combination — 6 datasets × 3 learners = 18 tasks
# (array 0..17). Each task runs the full outer-fold loop for one (dataset, learner)
# pair sequentially; folds are embarrassingly parallel within the task but kept
# serial here to avoid scheduler overhead on smaller clusters.
#
# Array index mapping (0-indexed):
#   0  COVID-19  lasso      9  OOL-CyPr   lasso
#   1  COVID-19  alasso    10  OOL-CyPr   alasso
#   2  COVID-19  en        11  OOL-CyPr   en
#   3  CFRNA     lasso     12  OOL-CyPrMe lasso
#   4  CFRNA     alasso    13  OOL-CyPrMe alasso
#   5  CFRNA     en        14  OOL-CyPrMe en
#   6  SSI       lasso     15  DREAM      lasso
#   7  SSI       alasso    16  DREAM      alasso
#   8  SSI       en        17  DREAM      en
#
# Usage:
#   # 1. Stage data (once)
#   Rscript r-pkg/stablr/inst/benchmark/R/stage_datasets.R
#   # 2. Run Python reference (once per dataset — or submit separately)
#   .venv-parity/bin/python r-pkg/stablr/inst/benchmark/py/run_reference.py
#   # 3. Submit this array
#   sbatch r-pkg/stablr/inst/benchmark/slurm/parity_array.slurm
#   # 4. After array completes, aggregate
#   sbatch r-pkg/stablr/inst/benchmark/slurm/parity_aggregate.slurm

#SBATCH --job-name=stablr_parity
#SBATCH --array=0-17
#SBATCH --cpus-per-task=4
#SBATCH --mem=24G
#SBATCH --time=12:00:00
#SBATCH --output=scratch/slurm/parity-%A_%a.out
#SBATCH --error=scratch/slurm/parity-%A_%a.err
#SBATCH --partition=standard

set -euo pipefail

# ── Environment ───────────────────────────────────────────────────────────────
REPO_ROOT="$(git rev-parse --show-toplevel)"
RSCRIPT="/exports/archive/hg-funcgenom-research/mdmanurung/conda/envs/R4_51/bin/Rscript"
RUNNER="${REPO_ROOT}/r-pkg/stablr/inst/benchmark/R/run_stablr_pipeline.R"
DATA_DIR="${REPO_ROOT}/scratch/benchmark/data"
REF_DIR="${REPO_ROOT}/scratch/benchmark/reference"
OUT_DIR="${REPO_ROOT}/scratch/benchmark/stablr_out"

# ── Task index → (dataset, learner) ──────────────────────────────────────────
DATASETS=("COVID-19" "COVID-19" "COVID-19"
          "CFRNA"    "CFRNA"    "CFRNA"
          "SSI"      "SSI"      "SSI"
          "OOL-CyPr" "OOL-CyPr" "OOL-CyPr"
          "OOL-CyPrMe" "OOL-CyPrMe" "OOL-CyPrMe"
          "DREAM"    "DREAM"    "DREAM")
LEARNERS=("lasso" "alasso" "en"
          "lasso" "alasso" "en"
          "lasso" "alasso" "en"
          "lasso" "alasso" "en"
          "lasso" "alasso" "en"
          "lasso" "alasso" "en")

TASK_IDX=${SLURM_ARRAY_TASK_ID}
DS="${DATASETS[$TASK_IDX]}"
LEARNER="${LEARNERS[$TASK_IDX]}"

echo "============================================================"
echo "Task ${TASK_IDX}: dataset=${DS}  learner=${LEARNER}"
echo "============================================================"
date

cd "${REPO_ROOT}"

# ── DREAM needs more memory — override if needed ──────────────────────────────
# (Submit DREAM tasks with --mem=48G if required: sbatch --mem=48G ...)

"${RSCRIPT}" "${RUNNER}" \
  --data-dir   "${DATA_DIR}" \
  --ref-dir    "${REF_DIR}" \
  --out-dir    "${OUT_DIR}" \
  --datasets   "${DS}" \
  --learners   "${LEARNER}" \
  --n-workers  "${SLURM_CPUS_PER_TASK}"

echo "Done: ${DS} / ${LEARNER}"
date
