#!/usr/bin/env bash
# parity_aggregate.slurm — B6: Aggregate parity metrics after parity_array completes.
#
# Usage:
#   # Submit with dependency on the array job:
#   sbatch --dependency=afterok:<array_job_id> \
#     r-pkg/stablr/inst/benchmark/slurm/parity_aggregate.slurm

#SBATCH --job-name=stablr_parity_agg
#SBATCH --cpus-per-task=1
#SBATCH --mem=8G
#SBATCH --time=00:30:00
#SBATCH --output=scratch/slurm/parity_agg-%j.out
#SBATCH --error=scratch/slurm/parity_agg-%j.err
#SBATCH --partition=standard

set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel)"
RSCRIPT="/exports/archive/hg-funcgenom-research/mdmanurung/conda/envs/R4_51/bin/Rscript"
AGGREGATOR="${REPO_ROOT}/r-pkg/stablr/inst/benchmark/R/compute_parity.R"
REF_DIR="${REPO_ROOT}/scratch/benchmark/reference"
STABLR_DIR="${REPO_ROOT}/scratch/benchmark/stablr_out"
OUT_DIR="${REPO_ROOT}/papers/application-note/artifacts"

echo "============================================================"
echo "Computing cross-language parity metrics"
echo "============================================================"
date
cd "${REPO_ROOT}"

"${RSCRIPT}" "${AGGREGATOR}" \
  --ref-dir    "${REF_DIR}" \
  --stablr-dir "${STABLR_DIR}" \
  --out-dir    "${OUT_DIR}"

echo "Done."
date
