#!/usr/bin/env bash
#SBATCH --job-name=stablr_base_sp_branch
#SBATCH --output=scratch/slurm/%x-%A_%a.out
#SBATCH --error=scratch/slurm/%x-%A_%a.err
#SBATCH --mem=128G
#SBATCH --cpus-per-task=8
#SBATCH --time=24:00:00
#SBATCH --array=0-26

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
  "ovr_stabl:EG_P"
  "ovr_stabl:EG_NP"
  "ovr_stabl:TU_P"
  "ovr_stabl:TU_NP"
  "ovr_stabl:GA_P"
  "ovr_stabl:GA_NP"
  "cooperative_ovr:EG_P"
  "cooperative_ovr:EG_NP"
  "cooperative_ovr:TU_P"
  "cooperative_ovr:TU_NP"
  "cooperative_ovr:GA_P"
  "cooperative_ovr:GA_NP"
  "nested_cv"
)

BRANCH="${STABLR_BRANCH:-${BRANCHES[$SLURM_ARRAY_TASK_ID]}}"

export STABLR_N_BOOTSTRAPS="${STABLR_N_BOOTSTRAPS:-500}"
export STABLR_N_LAMBDA="${STABLR_N_LAMBDA:-20}"
export STABLR_N_ITER_LF="${STABLR_N_ITER_LF:-5000}"
export STABLR_SAMPLE_FRACTION="${STABLR_SAMPLE_FRACTION:-0.9}"
export STABLR_NESTED_OUTER_V="${STABLR_NESTED_OUTER_V:-3}"
export STABLR_NESTED_INNER_V="${STABLR_NESTED_INNER_V:-2}"
export STABLR_COOPERATIVE_NFOLDS="${STABLR_COOPERATIVE_NFOLDS:-3}"

conda run -n R4_51 Rscript scratch/scripts/run_stablr_baseline_study_protection_branch.R "${BRANCH}"

# Submit visualization after the branch array completes, for example:
# sbatch --dependency=afterok:<branch_array_job_id> --array=0-0 --export=STABLR_BRANCH=visualize scratch/slurm/stablr_baseline_study_protection_branches.slurm
