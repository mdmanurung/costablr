#!/usr/bin/env bash
# novel_mvr.slurm — B5a: SLURM job for the MVR FDR/power benchmark.
#
# Runs run_novel_mvr.R on OOL Proteomics + SSI CyTOF donor matrices.
# 50 replicates × 4 artificial types × 2 donors ≈ 400 STABL fits (n_boot=1000 each).
# Expect ~4-6h with 4 CPUs at n_bootstraps=1000.
#
# Usage:
#   sbatch r-pkg/stablr/inst/benchmark/slurm/novel_mvr.slurm

#SBATCH --job-name=stablr_novel_mvr
#SBATCH --cpus-per-task=4
#SBATCH --mem=32G
#SBATCH --time=08:00:00
#SBATCH --output=scratch/slurm/novel_mvr-%j.out
#SBATCH --error=scratch/slurm/novel_mvr-%j.err
#SBATCH --partition=standard

set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel)"
RSCRIPT="/exports/archive/hg-funcgenom-research/mdmanurung/conda/envs/R4_51/bin/Rscript"
RUNNER="${REPO_ROOT}/r-pkg/stablr/inst/benchmark/R/run_novel_mvr.R"
DATA_DIR="${REPO_ROOT}/scratch/benchmark/data"
OUT_DIR="${REPO_ROOT}/papers/application-note/artifacts"

echo "============================================================"
echo "Novel MVR FDR/power benchmark"
echo "============================================================"
date
cd "${REPO_ROOT}"

"${RSCRIPT}" "${RUNNER}" \
  --data-dir "${DATA_DIR}" \
  --out-dir  "${OUT_DIR}" \
  --n-reps   50 \
  --n-true   15 \
  --seed     42

echo "Done."
date
