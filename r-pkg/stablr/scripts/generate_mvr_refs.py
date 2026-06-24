"""
Generate MVR reference fixtures for stablr test-knockoff-mvr.R.

Run from the repo root with:
    .venv-parity/bin/python r-pkg/stablr/scripts/generate_mvr_refs.py

The generated CSVs are committed to tests/testthat/fixtures/mvr/ so that
the R test suite never needs Python at test time.
"""

import numpy as np
import sys, os

sys.path.insert(0, ".")
from knockpy.mrc import _solve_mvr_ungrouped, mvr_loss
from knockpy import utilities

out = "r-pkg/stablr/tests/testthat/fixtures/mvr"
os.makedirs(out, exist_ok=True)


# ── Fixture 1: AR(1) Sigma, p=10, rho=0.5, seed=42 ──────────────────────────
p, rho = 10, 0.5
ix = np.arange(p)
Sigma = rho ** np.abs(ix[:, None] - ix[None, :])

np.random.seed(42)
S_mat = _solve_mvr_ungrouped(
    Sigma,
    num_iter=200,
    converge_tol=1e-5,   # tight for parity tolerance 1e-4
    smoothing=0,
    choldate_warning=False,
)
S_mat = utilities.shift_until_PSD(S_mat, tol=1e-5)
S_mat, gamma = utilities.scale_until_PSD(Sigma, S_mat, tol=1e-5, num_iter=10)

s_diag = np.diag(S_mat)
loss = mvr_loss(Sigma, S_mat)
print(f"AR(1) p=10 rho=0.5  S_diag = {np.round(s_diag, 8)}")
print(f"  gamma={gamma:.8f}  loss={loss:.6f}")

np.savetxt(f"{out}/ar1_p10_Sigma.csv", Sigma, delimiter=",")
np.savetxt(f"{out}/ar1_p10_S_diag.csv",
           s_diag.reshape(1, -1), delimiter=",", comments="",
           header=",".join(f"s{i+1}" for i in range(p)))


# ── Fixture 2: Identity Sigma, p=5 ──────────────────────────────────────────
Sigma5 = np.eye(5)
np.random.seed(7)
S5 = _solve_mvr_ungrouped(Sigma5, num_iter=50, converge_tol=1e-5,
                            smoothing=0, choldate_warning=False)
S5 = utilities.shift_until_PSD(S5, tol=1e-5)
S5, _ = utilities.scale_until_PSD(Sigma5, S5, tol=1e-5, num_iter=10)
s5_diag = np.diag(S5)
print(f"Identity p=5         S_diag = {np.round(s5_diag, 8)}  (all ~1.0)")
np.savetxt(f"{out}/identity_p5_S_diag.csv",
           s5_diag.reshape(1, -1), delimiter=",", comments="",
           header=",".join(f"s{i+1}" for i in range(5)))


# ── Fixture 3: AR(1) Sigma, p=6, rho=0.7 (for monotonicity checks) ──────────
p3, rho3 = 6, 0.7
Sigma3 = rho3 ** np.abs(np.arange(p3)[:, None] - np.arange(p3)[None, :])
np.savetxt(f"{out}/ar1_p6_Sigma.csv", Sigma3, delimiter=",")

np.random.seed(0)
S3 = _solve_mvr_ungrouped(Sigma3, num_iter=100, converge_tol=1e-5,
                            smoothing=0, choldate_warning=False)
S3 = utilities.shift_until_PSD(S3, tol=1e-5)
S3, _ = utilities.scale_until_PSD(Sigma3, S3, tol=1e-5, num_iter=10)
s3_diag = np.diag(S3)
loss3_init = mvr_loss(Sigma3, utilities.calc_mineig(Sigma3) * np.eye(p3))
loss3_final = mvr_loss(Sigma3, S3)
print(f"AR(1) p=6  rho=0.7  init_loss={loss3_init:.4f}  final_loss={loss3_final:.4f}")
np.savetxt(f"{out}/ar1_p6_S_diag.csv",
           s3_diag.reshape(1, -1), delimiter=",", comments="",
           header=",".join(f"s{i+1}" for i in range(p3)))

print(f"\nFixtures written to {out}/")
