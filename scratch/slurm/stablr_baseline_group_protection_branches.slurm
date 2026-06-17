#!/usr/bin/env bash
#SBATCH --job-name=stablr_base_gp_branch
#SBATCH --output=scratch/slurm/%x-%A_%a.out
#SBATCH --error=scratch/slurm/%x-%A_%a.err
#SBATCH --mem=128G
#SBATCH --cpus-per-task=8
#SBATCH --time=24:00:00
#SBATCH --array=0-51

set -euo pipefail

cd /exports/para-lipg-hpc/mdmanurung/stablr

BRANCHES=(
  "joint:single_view:cytof_celltype"
  "joint:single_view:exvivo_celltype"
  "joint:single_view:exvivo_enzyme"
  "joint:single_view:6h_cyto_LPS"
  "joint:single_view:6h_cyto_ssRNA40"
  "joint:single_view:24h_cyto_iRBC"
  "joint:single_view:24h_cyto_SEB"
  "joint:single_view:24h_enzyme_iRBC"
  "joint:single_view:24h_enzyme_SEB"
  "joint:single_view:3d_cyto"
  "joint:single_view:3d_enzyme"
  "joint:early_fusion"
  "joint:late_fusion"
  "within:EG:single_view:cytof_celltype"
  "within:EG:single_view:exvivo_celltype"
  "within:EG:single_view:exvivo_enzyme"
  "within:EG:single_view:6h_cyto_LPS"
  "within:EG:single_view:6h_cyto_ssRNA40"
  "within:EG:single_view:24h_cyto_iRBC"
  "within:EG:single_view:24h_cyto_SEB"
  "within:EG:single_view:24h_enzyme_iRBC"
  "within:EG:single_view:24h_enzyme_SEB"
  "within:EG:single_view:3d_cyto"
  "within:EG:single_view:3d_enzyme"
  "within:EG:early_fusion"
  "within:EG:late_fusion"
  "within:TU:single_view:cytof_celltype"
  "within:TU:single_view:exvivo_celltype"
  "within:TU:single_view:exvivo_enzyme"
  "within:TU:single_view:6h_cyto_LPS"
  "within:TU:single_view:6h_cyto_ssRNA40"
  "within:TU:single_view:24h_cyto_iRBC"
  "within:TU:single_view:24h_cyto_SEB"
  "within:TU:single_view:24h_enzyme_iRBC"
  "within:TU:single_view:24h_enzyme_SEB"
  "within:TU:single_view:3d_cyto"
  "within:TU:single_view:3d_enzyme"
  "within:TU:early_fusion"
  "within:TU:late_fusion"
  "within:GA:single_view:cytof_celltype"
  "within:GA:single_view:exvivo_celltype"
  "within:GA:single_view:exvivo_enzyme"
  "within:GA:single_view:6h_cyto_LPS"
  "within:GA:single_view:6h_cyto_ssRNA40"
  "within:GA:single_view:24h_cyto_iRBC"
  "within:GA:single_view:24h_cyto_SEB"
  "within:GA:single_view:24h_enzyme_iRBC"
  "within:GA:single_view:24h_enzyme_SEB"
  "within:GA:single_view:3d_cyto"
  "within:GA:single_view:3d_enzyme"
  "within:GA:early_fusion"
  "within:GA:late_fusion"
)

BRANCH="${STABLR_BRANCH:-${BRANCHES[$SLURM_ARRAY_TASK_ID]}}"

export STABLR_N_BOOTSTRAPS="${STABLR_N_BOOTSTRAPS:-500}"
export STABLR_N_LAMBDA="${STABLR_N_LAMBDA:-20}"
export STABLR_N_ITER_LF="${STABLR_N_ITER_LF:-5000}"
export STABLR_SAMPLE_FRACTION="${STABLR_SAMPLE_FRACTION:-0.8}"

conda run -n R4_51 Rscript scratch/scripts/run_stablr_baseline_group_protection_branch.R "${BRANCH}"
