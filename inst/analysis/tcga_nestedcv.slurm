#!/usr/bin/env bash
#SBATCH --job-name=costablr-tcga-nestedcv
#SBATCH --cpus-per-task=6
#SBATCH --mem=128G
#SBATCH --time=2-00:00:00
#SBATCH --output=inst/analysis/cache/tcga_nestedcv-%j.out
#SBATCH --error=inst/analysis/cache/tcga_nestedcv-%j.err

set -euo pipefail

cd /exports/para-lipg-hpc/mdmanurung/costablr
mkdir -p inst/analysis/cache

conda run -n R4_51 Rscript inst/analysis/run_tcga_nestedcv.R \
  --cache inst/analysis/cache/tcga_nestedcv_results.rds \
  --cv-workers 1 \
  --stabl-workers "${SLURM_CPUS_PER_TASK:-6}" \
  --diablo-workers "${SLURM_CPUS_PER_TASK:-6}"
