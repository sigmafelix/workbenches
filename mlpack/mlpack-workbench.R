library(mlpack)
library(palmerpenguins)
library(missRanger)
library(mice)

# load data
data(penguins)

# basic workflow: init model -> train with the init obj


# test simple models
str(penguins)
penguins_fill <- mice::mice(penguins, method = "rf")
pxx <- complete(penguins_fill)[, c(3:6, 8)] |> as.matrix()
pxx_nmf <- mlpack::nmf(pxx, 4)


image(pxx)
image(pxx_nmf$h)
image(pxx_nmf$w)


#
## Not run:
island_df <- data.frame(island = as.integer(penguins$island))

# Split the dataset using mlpack.
prepdata <- preprocess_split(
  input = pxx,
  input_labels = island_df,
  test_ratio = 0.3,
  verbose = TRUE
)


output <-
  bayesian_linear_regression(
    input = prepdata$training,
    responses = prepdata$training_labels,
    center = 1,
    scale = 0
  )

blr_model <- output$output_model

# blr
output_bl <- bayesian_linear_regression(
  input_model = blr_model,
  test = prepdata$test,
  verbose = TRUE
)

output_bl
output_bl$stds
output_bl$predictions
prepdata$test_labels

# Train a random forest.
rf_base <- random_forest(
  training = prepdata$training,
  labels = prepdata$training_labels,
  print_training_accuracy = TRUE,
  num_trees = 500,
  minimum_leaf_size = 3,
  verbose = TRUE
)
rf_base_model <- rf_base$output_model

# rf
rf_base_pred <- random_forest(
  input_model = rf_base_model,
  test = prepdata$test,
  verbose = TRUE
)

rf_base_pred
rf_base_pred$output_model
rf_base_pred$predictions


cc <-
  mlpack::lars(
    input = data.frame(prepdata$training),
    lambda1 = 0.4, lambda2 = 0.0,
    responses = data.frame(prepdata$training_labels),
    no_intercept = FALSE,
    no_normalize = FALSE,
    verbose = TRUE
  )
ccm <- cc$output_model
ccf <-
  mlpack::lars(
    input_model = ccm,
    test = data.frame(prepdata$test),
    verbose = TRUE
  )

ccf
ccf$output_model
ccf$output_predictions
?mlpack


library(mlpack)
d <- lars(
  input = matrix(numeric(), 0, 0), input_model = NA, lambda1 = 0,
  lambda2 = 0, no_intercept = FALSE, no_normalize = FALSE,
  responses = matrix(numeric(), 0, 0), test = matrix(numeric(), 0, 0),
  use_cholesky = FALSE, verbose = getOption("mlpack.verbose", FALSE)
)
output_model <- d$output_model
output_predictions <- d$output_predictions

output <- lars(input = data, responses = responses, lambda1 = 0.4, lambda2 = 0)
lasso_model <- output$output_model

output <- lars(input_model = lasso_model, test = test)
test_predictions <- output$output_predictions
