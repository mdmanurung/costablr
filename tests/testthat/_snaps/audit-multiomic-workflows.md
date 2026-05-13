# AUDIT INT-003: unnamed features fail selected matrix construction

    Code
      stabl_multiomic_train_validate(x_train_list = list(view = x), y_train = y,
      lambda_grid = data.frame(lambda = 1e-04), artificial_type = NULL,
      hard_threshold = 1e-09, n_bootstraps = 2L, sample_fraction = 1, random_state = 1L)
    Condition
      Error in `[.data.frame`:
      ! undefined columns selected

