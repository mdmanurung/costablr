// Minimum variance-based reconstructability (MVR) Gaussian knockoffs.
//
// This file implements the ungrouped knockpy coordinate-descent S-matrix
// solver in native code. The public R path keeps the existing sampler and
// fallback behavior; only the expensive S-matrix optimization is moved here.

#include <RcppArmadillo.h>

// [[Rcpp::depends(RcppArmadillo)]]

namespace {

arma::mat symmetrize(const arma::mat& x) {
  return 0.5 * (x + x.t());
}

double calc_mineig_cpp(const arma::mat& x) {
  arma::vec eigval;
  if (!arma::eig_sym(eigval, symmetrize(x))) {
    Rcpp::stop("Eigenvalue decomposition failed in MVR solver.");
  }
  return eigval.min();
}

double mvr_loss_cpp(const arma::mat& sigma, const arma::mat& s,
                    double smoothing) {
  arma::vec eig_diff;
  if (!arma::eig_sym(eig_diff, symmetrize(2.0 * sigma - s))) {
    Rcpp::stop("Eigenvalue decomposition failed in MVR loss.");
  }

  arma::vec s_diag = s.diag();
  if (s_diag.min() < 0.0 || eig_diff.min() < 0.0) {
    return R_PosInf;
  }

  return arma::sum(1.0 / (eig_diff + smoothing)) +
    arma::sum(1.0 / (s_diag + smoothing));
}

double solve_mvr_quadratic_cpp(double cn, double cd, double sj,
                               double smoothing) {
  const double coef2 = -cn - cd * cd;
  const double coef1 = 2.0 * (-cn * (sj + smoothing) + cd);
  const double coef0 = -cn * std::pow(sj + smoothing, 2.0) - 1.0;
  const double lower = -sj;
  const double upper = 1.0 / cd;
  const double eps = 1e-12;

  std::vector<double> feasible;
  auto add_if_feasible = [&](double root) {
    if (std::isfinite(root) && root > lower && root < upper) {
      feasible.push_back(root);
    }
  };

  if (std::abs(coef2) < eps) {
    if (std::abs(coef1) >= eps) {
      add_if_feasible(-coef0 / coef1);
    }
  } else {
    const double disc = coef1 * coef1 - 4.0 * coef2 * coef0;
    if (disc >= -eps) {
      const double sqrt_disc = std::sqrt(std::max(0.0, disc));
      add_if_feasible((-coef1 + sqrt_disc) / (2.0 * coef2));
      add_if_feasible((-coef1 - sqrt_disc) / (2.0 * coef2));
    }
  }

  if (feasible.empty()) {
    return 0.0;
  }
  if (feasible.size() == 1) {
    return feasible[0];
  }

  double best_delta = feasible[0];
  double best_loss = R_PosInf;
  for (double delta : feasible) {
    const double loss = 1.0 / (sj + delta) -
      (delta * cn) / (1.0 - delta * cd);
    if (loss < best_loss) {
      best_loss = loss;
      best_delta = delta;
    }
  }
  return best_delta;
}

Rcpp::IntegerVector get_update_order(
    int iter,
    int p,
    const Rcpp::Nullable<Rcpp::IntegerMatrix>& update_order,
    const Rcpp::Function& sample_int) {
  if (update_order.isNotNull()) {
    Rcpp::IntegerMatrix order(update_order);
    if (order.nrow() <= iter || order.ncol() != p) {
      Rcpp::stop(
        "`update_order` must have at least `num_iter` rows and p columns."
      );
    }
    Rcpp::IntegerVector out(p);
    Rcpp::LogicalVector seen(p);
    for (int j = 0; j < p; ++j) {
      const int value = order(iter, j);
      if (value < 1 || value > p) {
        Rcpp::stop("`update_order` entries must be 1-based column indices.");
      }
      if (seen[value - 1]) {
        Rcpp::stop("Each `update_order` row must be a permutation of 1:p.");
      }
      seen[value - 1] = true;
      out[j] = value;
    }
    return out;
  }

  return sample_int(p, Rcpp::Named("size") = p, Rcpp::Named("replace") = false);
}

} // namespace

// [[Rcpp::export]]
arma::mat mvr_solve_ungrouped_cpp(const arma::mat& Sigma,
                                  int num_iter = 50,
                                  double smoothing = 0.0,
                                  double converge_tol = 1e-3,
                                  bool verbose = false,
                                  Rcpp::Nullable<Rcpp::IntegerMatrix> update_order = R_NilValue) {
  if (Sigma.n_rows != Sigma.n_cols) {
    Rcpp::stop("`Sigma` must be a square matrix.");
  }
  if (num_iter < 1) {
    Rcpp::stop("`num_iter` must be positive.");
  }

  const int p = Sigma.n_rows;
  const arma::mat sigma = symmetrize(Sigma);
  const arma::mat eye = arma::eye<arma::mat>(p, p);
  const double min_eig = calc_mineig_cpp(sigma);

  arma::mat s = min_eig * eye;
  double loss = R_PosInf;
  double decayed_improvement = 10.0;
  Rcpp::Environment base = Rcpp::Environment::base_env();
  Rcpp::Function sample_int = base["sample.int"];

  for (int iter = 0; iter < num_iter; ++iter) {
    Rcpp::IntegerVector order = get_update_order(
      iter, p, update_order, sample_int
    );

    for (int pos = 0; pos < p; ++pos) {
      const int j = order[pos] - 1;
      arma::mat upper;
      const arma::mat v = 2.0 * sigma - s + smoothing * eye;
      if (!arma::chol(upper, symmetrize(v))) {
        Rcpp::stop("Cholesky decomposition failed in MVR coordinate update.");
      }

      arma::vec ej(p, arma::fill::zeros);
      ej[j] = 1.0;

      arma::vec vd = arma::solve(arma::trimatl(upper.t()), ej);
      const double cd = arma::dot(vd, vd);
      arma::vec vn = arma::solve(arma::trimatu(upper), vd);
      const double cn = -arma::dot(vn, vn);

      const double delta = solve_mvr_quadratic_cpp(cn, cd, s(j, j), smoothing);
      s(j, j) += delta;
    }

    const double prev_loss = loss;
    loss = mvr_loss_cpp(sigma, s, smoothing);
    if (iter > 0) {
      decayed_improvement = decayed_improvement / 10.0 +
        9.0 * (prev_loss - loss) / 10.0;
    }
    if (verbose) {
      Rcpp::Rcout << "MVR iteration " << (iter + 1)
                  << " loss=" << loss << std::endl;
    }
    if (iter > 0 && decayed_improvement >= 0.0 &&
        decayed_improvement < converge_tol) {
      break;
    }
  }

  return s;
}
