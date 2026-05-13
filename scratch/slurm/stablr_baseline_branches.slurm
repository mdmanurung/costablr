#!/usr/bin/env bash
#SBATCH --job-name=stablr_base_branch
#SBATCH --output=scratch/slurm/%x-%A_%a.out
#SBATCH --error=scratch/slurm/%x-%A_%a.err
#SBATCH --mem=128G
#SBATCH --cpus-per-task=8
#SBATCH --time=24:00:00
#SBATCH --array=0-17

set -euo pipefail

cd /exports/para-lipg-hpc/mdmanurung/stablr

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
  "cooperative_ovr:EG"
  "cooperative_ovr:GA"
  "cooperative_ovr:TU"
  "nested_cv"
)

BRANCH="${STABLR_BRANCH:-${BRANCHES[$SLURM_ARRAY_TASK_ID]}}"

export STABLR_N_BOOTSTRAPS="${STABLR_N_BOOTSTRAPS:-500}"
export STABLR_N_LAMBDA="${STABLR_N_LAMBDA:-20}"
export STABLR_N_ITER_LF="${STABLR_N_ITER_LF:-5000}"

conda run -n R4_51 Rscript scratch/scripts/run_stablr_baseline_groups_branch.R "${BRANCH}"

# Submit visualization after the branch array completes, for example:
# sbatch --dependency=afterok:<branch_array_job_id> --array=0-0 --export=STABLR_BRANCH=visualize scratch/slurm/stablr_baseline_branches.slurm
