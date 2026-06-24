"""
knockoff_parity_reference.py — Python side of the A4 model-X knockoff parity arm.

For each Sigma configuration, computes:
  1. Equicorrelated S (knockpy GaussianSampler, method='equicorrelated')
  2. MVR S (knockpy solve_mvr)

Saves per-config CSV files to scratch/benchmark/knockoff_parity/ so the R
comparison script can compare against R's knockoff_equi and knockoff_mvr.

Run from repo root:
  .venv-parity/bin/python r-pkg/stablr/inst/benchmark/py/knockoff_parity_reference.py
"""

import os, sys
import numpy as np
import pandas as pd

sys.path.insert(0, ".")
from knockpy.knockoffs import GaussianSampler
from knockpy import mrc, utilities

OUT = "scratch/benchmark/knockoff_parity"
os.makedirs(OUT, exist_ok=True)

# Reproducibility
np.random.seed(42)

# ── Sigma configurations ───────────────────────────────────────────────────────
def ar1_sigma(p, rho):
    ix = np.arange(p)
    return rho ** np.abs(ix[:, None] - ix[None, :])

def block_sigma(p, block_size, within_rho, between_rho=0.0):
    """Block-diagonal covariance: within-block rho, between-block ~0."""
    S = np.full((p, p), between_rho)
    np.fill_diagonal(S, 1.0)
    for i in range(0, p, block_size):
        j = min(i + block_size, p)
        S[i:j, i:j] = within_rho
        np.fill_diagonal(S[i:j, i:j], 1.0)
    return S

CONFIGS = [
    {"name": "ar1_p20_rho05",  "Sigma": ar1_sigma(20, 0.5)},
    {"name": "ar1_p20_rho07",  "Sigma": ar1_sigma(20, 0.7)},
    {"name": "ar1_p50_rho03",  "Sigma": ar1_sigma(50, 0.3)},
    {"name": "block_p40_rho08", "Sigma": block_sigma(40, 5, within_rho=0.8)},
]

# n large enough that n >= p for all configs (no rank-deficiency at Sigma level)
N_SAMPLES = 500

def compute_equi_s(Sigma):
    """Equicorrelated S via knockpy (closed-form, same as create.gaussian equi)."""
    p = Sigma.shape[0]
    X = np.random.multivariate_normal(np.zeros(p), Sigma, size=N_SAMPLES)
    mu = np.zeros(p)
    sampler = GaussianSampler(X, method='equicorrelated', mu=mu, Sigma=Sigma)
    sampler.sample_knockoffs()
    # Extract diag(S) from the sampler's stored S
    if hasattr(sampler, 'S'):
        return np.diag(sampler.S)
    # Fallback: recompute equi S = 2 * min(eig(Sigma)) * ones, clipped to <=1
    min_eig = np.linalg.eigvalsh(Sigma).min()
    s_val = min(2 * min_eig, 1.0)
    return np.full(p, s_val)

def compute_mvr_s(Sigma):
    """MVR S via knockpy."""
    np.random.seed(0)
    S_mat = mrc._solve_mvr_ungrouped(
        Sigma, num_iter=200, converge_tol=1e-5, smoothing=0,
        choldate_warning=False
    )
    S_mat = utilities.shift_until_PSD(S_mat, tol=1e-5)
    S_mat, _ = utilities.scale_until_PSD(Sigma, S_mat, tol=1e-5, num_iter=10)
    return np.diag(S_mat)

records = []
for cfg in CONFIGS:
    name  = cfg["name"]
    Sigma = cfg["Sigma"]
    p     = Sigma.shape[0]
    print(f"\n── {name} (p={p}) ──")

    s_equi = compute_equi_s(Sigma)
    s_mvr  = compute_mvr_s(Sigma)

    print(f"  equi S: min={s_equi.min():.4f} max={s_equi.max():.4f}")
    print(f"  mvr  S: min={s_mvr.min():.4f}  max={s_mvr.max():.4f}")

    # Save Sigma and S vectors as CSVs
    sigma_cols = [f"c{i+1}" for i in range(p)]
    pd.DataFrame(Sigma, columns=sigma_cols).to_csv(
        f"{OUT}/{name}_Sigma.csv", index=False
    )
    s_cols = [f"s{i+1}" for i in range(p)]
    pd.DataFrame([s_equi], columns=s_cols).to_csv(
        f"{OUT}/{name}_S_equi_py.csv", index=False
    )
    pd.DataFrame([s_mvr], columns=s_cols).to_csv(
        f"{OUT}/{name}_S_mvr_py.csv", index=False
    )

    records.append({"config": name, "p": p,
                    "s_equi_min": s_equi.min(), "s_equi_max": s_equi.max(),
                    "s_mvr_min": s_mvr.min(),   "s_mvr_max": s_mvr.max()})

pd.DataFrame(records).to_csv(f"{OUT}/python_summary.csv", index=False)
print(f"\nAll Python reference CSVs written to {OUT}/")
