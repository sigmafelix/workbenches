if (!require(targets)) {
  pak::pak("targets")
  library(targets)
}

source("inst/extdata/req_pakcages.R")
source("inst/extdata/ext_functions.R")

# targets options
tar_option_set(
  packages = c("NRTAPmodel", "scomps", "data.table", "sf", "terra", "exactextractr"),
  repository = "local",
  error = "null",
  memory = "persistent",
  storage = "worker",
  seed = 202401L)

list(
  # tar_target for base directories and files
  targets::tar_target(sites, format = "file")
  # tar_target for download and checking presence
  targets::tar_target(modis, download_data("./input/modis/...")
  # ...
  # covariate file existence check then calculate covariates
  targets::tar_target(covar_modis, calculate_covariates("modis", ...))
  # ...
  # combine each covariate set into one data.frame (data.table; if any)
  targets::tar_target(covar_all, concatenate_covariates(...))
  # tar_target for initial model fitting and tuning
  targets::tar_target(fitted_ranger, base_learner("randomforest"))
  targets::tar_target(fitted_xgb, base_learner("xgboost"))
  # CNN, if any
  
  # meta learner
  targets::tar_target(fitted_meta, meta_learner(list(fitted_ranger, fitted_xgb, fitted_cnn, ...)))

  # tar_target for initial model update if pre-fitted
  # model exists; is it possible to nest pipelines?
  targets::tar_target(data_updated, foo_above_all(...))
  targets::tar_target(fitted_2025_ranger, base_learner("randomforest", data_updated, ...))
  targets::tar_target(fitted_2025_xgb, base_learner("xgboost", data_updated, ...))
  # if any
  # tar_target for 8+M point covariate calculation
  targets::tar_target(covar_modis_pred, calculate_covariates("modis", usmain_p8m))
  targets::tar_target(covar_ncep_pred, calculate_covariates("ncep", usmain_p8m, ...))
  # others
  targets::tar_target(covar_all_pred, concateneate_covariates(...))
  # tar_target for prediction using pre-fitted models
  targets::tar_target(pred_p8m, predict_meta(fitted_meta, covar_all_pred))
  # documents and summary statistics
  targets::tar_target(summary_urban_rural, summary_prediction(pred_p8m, level = "point", contrast = "urbanrural"))
  targets::tar_target(summary_state, summary_prediction(pred_p8m, level = "point", contrast = "state"))
)


# END OF FILE
