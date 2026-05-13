#include <Rcpp.h>
#include <map>

namespace {

int find_root(std::vector<int>& parent, int i) {
  while (parent[i] != i) {
    parent[i] = parent[parent[i]];
    i = parent[i];
  }
  return i;
}

} // namespace

// [[Rcpp::export]]
Rcpp::IntegerVector corr_groups_from_corr_cpp(const Rcpp::NumericMatrix& corr,
                                              double cutoff) {
  const int p = corr.ncol();
  if (corr.nrow() != p) {
    Rcpp::stop("`corr` must be a square matrix.");
  }

  std::vector<int> parent(p);
  for (int i = 0; i < p; ++i) {
    parent[i] = i;
  }

  for (int i = 0; i < p - 1; ++i) {
    for (int j = i + 1; j < p; ++j) {
      if (corr(i, j) > cutoff) {
        const int ri = find_root(parent, i);
        const int rj = find_root(parent, j);
        if (ri != rj) {
          parent[rj] = ri;
        }
      }
    }
  }

  Rcpp::IntegerVector roots(p);
  std::map<int, int> group_map;
  int next_group = 1;
  for (int i = 0; i < p; ++i) {
    const int root = find_root(parent, i);
    if (group_map.find(root) == group_map.end()) {
      group_map[root] = next_group;
      ++next_group;
    }
    roots[i] = group_map[root];
  }

  return roots;
}
