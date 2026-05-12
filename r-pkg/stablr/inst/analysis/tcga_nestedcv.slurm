#!/usr/bin/env bash
#SBATCH --job-name=stablr-tcga-nestedcv
#SBATCH --cpus-per-task=6
#SBATCH --mem=128G
#SBATCH --time=2-00:00:00
#SBATCH --output=r-pkg/stablr/inst/analysis/cache/tcga_nestedcv-%j.out
#SBATCH --error=r-pkg/stablr/inst/analysis/cache/tcga_nestedcv-%j.err

set -euo pipefail

cd /exports/para-lipg-hpc/mdmanurung/stablr
mkdir -p r-pkg/stablr/inst/analysis/cache

conda run -n R4_51 Rscript r-pkg/stablr/inst/analysis/run_tcga_nestedcv.R \
  --cache r-pkg/stablr/inst/analysis/cache/tcga_nestedcv_results.rds \
  --cv-workers 1 \
  --stabl-workers "${SLURM_CPUS_PER_TASK:-6}" \
  --diablo-workers "${SLURM_CPUS_PER_TASK:-6}"
