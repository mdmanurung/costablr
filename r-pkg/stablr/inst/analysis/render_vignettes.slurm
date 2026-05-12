#!/usr/bin/env bash
#SBATCH --job-name=stablr-vignettes
#SBATCH --cpus-per-task=6
#SBATCH --mem=128G
#SBATCH --time=24:00:00
#SBATCH --array=0-4%5
#SBATCH --output=r-pkg/stablr/inst/analysis/cache/vignette-renders/%x-%A_%a.out
#SBATCH --error=r-pkg/stablr/inst/analysis/cache/vignette-renders/%x-%A_%a.err

set -euo pipefail

cd /exports/para-lipg-hpc/mdmanurung/stablr
mkdir -p r-pkg/stablr/inst/analysis/cache/vignette-renders

export OMP_NUM_THREADS="${SLURM_CPUS_PER_TASK:-6}"
export OPENBLAS_NUM_THREADS="${SLURM_CPUS_PER_TASK:-6}"
export MKL_NUM_THREADS="${SLURM_CPUS_PER_TASK:-6}"

vignettes=(
  "stablr-intro.Rmd"
  "stablr-multiomic.Rmd"
  "stablr-python-parity.Rmd"
  "stablr-tcga.Rmd"
  "stablr-cooperative.Rmd"
)

vignette="${vignettes[$SLURM_ARRAY_TASK_ID]}"

echo "Rendering ${vignette}"
echo "SLURM job: ${SLURM_JOB_ID:-unknown}, array task: ${SLURM_ARRAY_TASK_ID:-unknown}"
echo "Started: $(date)"

conda run -n R4_51 Rscript -e "v <- '${vignette}'; rmarkdown::render(file.path('r-pkg/stablr/vignettes', v), output_dir = 'r-pkg/stablr/vignettes', quiet = FALSE)"

echo "Finished: $(date)"
