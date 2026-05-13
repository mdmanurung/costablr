#!/usr/bin/env bash
#SBATCH --job-name=costablr-vignettes
#SBATCH --cpus-per-task=6
#SBATCH --mem=128G
#SBATCH --time=24:00:00
#SBATCH --array=0-4%5
#SBATCH --output=inst/analysis/cache/vignette-renders/%x-%A_%a.out
#SBATCH --error=inst/analysis/cache/vignette-renders/%x-%A_%a.err

set -euo pipefail

cd /exports/para-lipg-hpc/mdmanurung/costablr
mkdir -p inst/analysis/cache/vignette-renders

export OMP_NUM_THREADS="${SLURM_CPUS_PER_TASK:-6}"
export OPENBLAS_NUM_THREADS="${SLURM_CPUS_PER_TASK:-6}"
export MKL_NUM_THREADS="${SLURM_CPUS_PER_TASK:-6}"

vignettes=(
  "costablr-intro.Rmd"
  "costablr-multiomic.Rmd"
  "costablr-python-parity.Rmd"
  "costablr-tcga.Rmd"
  "costablr-cooperative.Rmd"
)

vignette="${vignettes[$SLURM_ARRAY_TASK_ID]}"

echo "Rendering ${vignette}"
echo "SLURM job: ${SLURM_JOB_ID:-unknown}, array task: ${SLURM_ARRAY_TASK_ID:-unknown}"
echo "Started: $(date)"

conda run -n R4_51 Rscript -e "v <- '${vignette}'; rmarkdown::render(file.path('vignettes', v), output_dir = 'vignettes', quiet = FALSE)"

echo "Finished: $(date)"
