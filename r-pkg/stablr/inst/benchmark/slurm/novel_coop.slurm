#!/usr/bin/env bash
# novel_coop.slurm — B5b: SLURM job for the cooperative-fusion rho sweep.
#
# Runs run_novel_coop.R on SSI, OOL-CyPr, OOL-CyPrMe (multi-omic datasets).
# 3 datasets × 8 conditions × 100 outer folds × 300 bootstraps ≈ heavy.
# Use --n-folds 20 for a quick smoke test.
#
# Usage:
#   # Quick test (20 folds):
#   sbatch --export=ALL,N_FOLDS=20 r-pkg/stablr/inst/benchmark/slurm/novel_coop.slurm
#   # Full (all 100 folds):
#   sbatch r-pkg/stablr/inst/benchmark/slurm/novel_coop.slurm

#SBATCH --job-name=stablr_novel_coop
#SBATCH --cpus-per-task=4
#SBATCH --mem=48G
#SBATCH --time=48:00:00
#SBATCH --output=scratch/slurm/novel_coop-%j.out
#SBATCH --error=scratch/slurm/novel_coop-%j.err
#SBATCH --partition=standard

set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel)"
RSCRIPT="/exports/archive/hg-funcgenom-research/mdmanurung/conda/envs/R4_51/bin/Rscript"
RUNNER="${REPO_ROOT}/r-pkg/stablr/inst/benchmark/R/run_novel_coop.R"
DATA_DIR="${REPO_ROOT}/scratch/benchmark/data"
REF_DIR="${REPO_ROOT}/scratch/benchmark/reference"
OUT_DIR="${REPO_ROOT}/papers/application-note/artifacts"

N_FOLDS="${N_FOLDS:-}"  # empty = all folds

echo "============================================================"
echo "Cooperative-fusion rho sweep benchmark"
echo "============================================================"
date
cd "${REPO_ROOT}"

EXTRA_ARGS=""
if [ -n "${N_FOLDS}" ]; then
  EXTRA_ARGS="--n-folds ${N_FOLDS}"
fi

"${RSCRIPT}" "${RUNNER}" \
  --data-dir  "${DATA_DIR}" \
  --ref-dir   "${REF_DIR}" \
  --out-dir   "${OUT_DIR}" \
  --datasets  "SSI,OOL-CyPr,OOL-CyPrMe" \
  ${EXTRA_ARGS}

echo "Done."
date
