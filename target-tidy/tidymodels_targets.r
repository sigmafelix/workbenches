# Load required libraries
# pkgs <- c("data.table", "dplyr", "terra", "sf", "tidymodels", "xgboost", "fst", "future", "doFuture")
# invisible(sapply(pkgs, library, character.only = TRUE))
options(width = 125)

all_cores <- parallel::detectCores(logical = FALSE)

doFuture::registerDoFuture()
cl <- parallel::makeCluster(all_cores)
future::plan(future::cluster, workers = cl)


# Function to load the Boston housing dataset
load_data <- function(path = file.path("target-tidy", "kinghouse.fst")) {
  indata <- fst::read_fst(path)
  return(indata)
}

prep_sf <- function(data) {
  data <- sf::st_as_sf(data, coords = c("long", "lat"), crs = 4326, remove = FALSE) %>%
    sf::st_transform("EPSG:5070") %>%
    .[sf::st_bbox(c(xmin = -1990000, ymin = 2954000, xmax = -1925000, ymax = 3030000),
                  crs = sf::st_crs(.)) %>% sf::st_as_sfc(), ]
  return(data)
}

# Function to split the data into train-validation-test sets
split_data <- function(data, group) {
  data %>%
    spatialsample::spatial_leave_location_out_cv(group = group)
}

# Function to preprocess the data
preprocess_data <- function(data) {
    data <- data %>%
      mutate(zip4 = substr(zipcode, 1, 4))
#   data <- data %>%
#     dplyr::mutate(
#       dplyr::across(dplyr::where(is.numeric(.x) && names(.x) == "zipcode"), ~as.vector(scale(.x)))
#     )
  # Add preprocessing steps here
  # For example, scaling, imputation, feature engineering, etc.
  return(data)
}


reciping <- function(data, xc, yc) {
  recipes::recipe(
    formula =
      reformulate(
        response = yc,
        termlabels = xc
      ),
    data = data
  )
}

# Function to train a model
train_model <- function(preproc, xc, yc = "price", res = NULL) {
  # Add model training code here
  parsnip::boost_tree(
    mode = "regression",
    engine = "xgboost",
    mtry = 5,
    trees = parsnip::tune(),
    min_n = 2,
    tree_depth = 5,
    learn_rate = parsnip::tune()
  ) %>%
#   parsnip::fit.model_spec(
#     formula =
#     reformulate(
#       response = yc,
#       termlabels = xc
#     ),
#     data = data
#   ) %>%
  tune::tune_bayes(preprocessor = preproc, resamples = res)
  # For example, linear regression, random forest, etc.
  # return(model)
}

# Function to evaluate the model
# evaluate_model <- function(model, data) {
#   # Add model evaluation code here
#   # For example, calculate RMSE, R-squared, etc.
#   parsnip::eval_args()
#   return(metrics)
# }

# Function to generate predictions
generate_predictions <- function(model, res = NULL) {
  # Add prediction code here
  parsnip::predict.model_fit(
    object = model,
    new_data = res
  )
  # For example, predict on new data
  # return(predictions)
}

# Function to save the results
save_results <- function(results, file_path) {
  # Add code to save the results
  # For example, save as CSV or RDS file
  saveRDS(results, file_path)
}

# Function to load the results
load_results <- function(file_path) {
  # Add code to load the results
  # For example, load from CSV or RDS file
  results <- readRDS(file_path)
  return(results)
}
