#!/usr/bin/env bash
#SBATCH --job-name=stablr_base_preprocess
#SBATCH --output=scratch/slurm/%x-%j.out
#SBATCH --error=scratch/slurm/%x-%j.err
#SBATCH --mem=128G
#SBATCH --cpus-per-task=8
#SBATCH --time=24:00:00

set -euo pipefail

cd /exports/para-lipg-hpc/mdmanurung/stablr

export STABLR_N_BOOTSTRAPS="${STABLR_N_BOOTSTRAPS:-500}"
export STABLR_N_LAMBDA="${STABLR_N_LAMBDA:-20}"

conda run -n R4_51 Rscript scratch/scripts/run_stablr_baseline_groups_branch.R preprocess
