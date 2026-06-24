#!/usr/bin/env bash
# parity_reference.slurm — B6: Run the Python STABL reference for all 6 datasets.
#
# This job is a prerequisite for parity_array.slurm. It writes
# scratch/benchmark/reference/<dataset>/{predictions,selected,max_scores,folds}.csv.
#
# DREAM is the cost outlier (high-p 16S microbiome): ~8h, 48G.
# OOL-CyPrMe is second-most expensive (3 omics, 100 outer folds, regression): ~6h.
# Adjust --time and --mem as needed.
#
# Usage:
#   sbatch r-pkg/stablr/inst/benchmark/slurm/parity_reference.slurm

#SBATCH --job-name=stabl_reference
#SBATCH --cpus-per-task=8
#SBATCH --mem=48G
#SBATCH --time=24:00:00
#SBATCH --output=scratch/slurm/reference-%j.out
#SBATCH --error=scratch/slurm/reference-%j.err
#SBATCH --partition=standard

set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel)"
PYTHON="${REPO_ROOT}/.venv-parity/bin/python"
RUNNER="${REPO_ROOT}/r-pkg/stablr/inst/benchmark/py/run_reference.py"
DATA_DIR="${REPO_ROOT}/scratch/benchmark/data"
OUT_DIR="${REPO_ROOT}/scratch/benchmark/reference"

echo "============================================================"
echo "Python STABL reference runner — all 6 datasets"
echo "============================================================"
date
echo "Python: ${PYTHON}"

cd "${REPO_ROOT}"

"${PYTHON}" "${RUNNER}" \
  --data-dir "${DATA_DIR}" \
  --out-dir  "${OUT_DIR}"

echo "Done."
date
