#!/usr/bin/env bash
#SBATCH --job-name=stablr_base_cmp
#SBATCH --output=scratch/slurm/%x-%A_%a.out
#SBATCH --error=scratch/slurm/%x-%A_%a.err
#SBATCH --mem=128G
#SBATCH --cpus-per-task=8
#SBATCH --time=24:00:00
#SBATCH --array=0-47

set -euo pipefail

cd /exports/para-lipg-hpc/mdmanurung/stablr

CONTRASTS=(
  "EG_vs_GA_TU"
  "GA_vs_EG"
  "TU_vs_EG"
)

BRANCHES=(
  "cytof"
  "single_view:cytof_celltype"
  "single_view:exvivo_celltype"
  "single_view:exvivo_enzyme"
  "single_view:6h_cyto_LPS"
  "single_view:6h_cyto_ssRNA40"
  "single_view:24h_cyto_iRBC"
  "single_view:24h_cyto_SEB"
  "single_view:24h_enzyme_iRBC"
  "single_view:24h_enzyme_SEB"
  "single_view:3d_cyto"
  "single_view:3d_enzyme"
  "early_fusion"
  "late_fusion"
  "cooperative"
  "nested_cv"
)

if [[ -n "${STABLR_CONTRAST:-}" ]]; then
  CONTRAST="${STABLR_CONTRAST}"
  BRANCH_INDEX=$((SLURM_ARRAY_TASK_ID % ${#BRANCHES[@]}))
  BRANCH="${STABLR_BRANCH:-${BRANCHES[$BRANCH_INDEX]}}"
elif [[ -n "${STABLR_BRANCH:-}" ]]; then
  CONTRAST="${CONTRASTS[$SLURM_ARRAY_TASK_ID]}"
  BRANCH="${STABLR_BRANCH}"
else
  CONTRAST_INDEX=$((SLURM_ARRAY_TASK_ID / ${#BRANCHES[@]}))
  BRANCH_INDEX=$((SLURM_ARRAY_TASK_ID % ${#BRANCHES[@]}))
  CONTRAST="${CONTRASTS[$CONTRAST_INDEX]}"
  BRANCH="${STABLR_BRANCH:-${BRANCHES[$BRANCH_INDEX]}}"
fi

export STABLR_N_BOOTSTRAPS="${STABLR_N_BOOTSTRAPS:-500}"
export STABLR_N_LAMBDA="${STABLR_N_LAMBDA:-20}"
export STABLR_N_ITER_LF="${STABLR_N_ITER_LF:-5000}"

conda run -n R4_51 Rscript scratch/scripts/run_stablr_baseline_comparisons_branch.R "${CONTRAST}" "${BRANCH}"

# Submit all heavy branches for all contrasts with:
# sbatch --array=0-47 scratch/slurm/stablr_baseline_comparisons_branches.slurm
#
# Submit visualization after the heavy array completes, for example:
# sbatch --dependency=afterok:<branch_array_job_id> --array=0-2 --export=STABLR_BRANCH=visualize scratch/slurm/stablr_baseline_comparisons_branches.slurm
