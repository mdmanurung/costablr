#!/usr/bin/env bash
#SBATCH --job-name=stablr_base_cmp_pre
#SBATCH --output=scratch/slurm/%x-%A_%a.out
#SBATCH --error=scratch/slurm/%x-%A_%a.err
#SBATCH --mem=64G
#SBATCH --cpus-per-task=8
#SBATCH --time=08:00:00
#SBATCH --array=0-2

set -euo pipefail

cd /exports/para-lipg-hpc/mdmanurung/stablr

CONTRASTS=(
  "EG_vs_GA_TU"
  "GA_vs_EG"
  "TU_vs_EG"
)

CONTRAST="${STABLR_CONTRAST:-${CONTRASTS[$SLURM_ARRAY_TASK_ID]}}"

export STABLR_N_BOOTSTRAPS="${STABLR_N_BOOTSTRAPS:-500}"
export STABLR_N_LAMBDA="${STABLR_N_LAMBDA:-20}"

conda run -n R4_51 Rscript scratch/scripts/run_stablr_baseline_comparisons_branch.R "${CONTRAST}" preprocess
