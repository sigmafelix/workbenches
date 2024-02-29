## lessons learned
## No custom states are required
## _targets/meta controls the up-to-dateness and staleness of a node by hash
## File should be read at the surface level, not inside a function

library(targets)
source("./target-tidy/tidymodels_targets.r")

tar_option_set(
  controller = 
  crew::crew_controller_local(
    workers = 8,
    name = "default"
  ),
  packages = c("data.table", "dplyr", "terra", "sf", "tidymodels", "parallel", "xgboost", "fst", "future", "doFuture", "crew", "crew.cluster"),
)

## target pipeline
list(
  tar_target(
    data,
    fst::read_fst(file.path("target-tidy", "kinghouse.fst"))
  )
  ,
  tar_target(
    datsf,
    prep_sf(data)
  )
  ,
  tar_target(
    datsfpp,
    preprocess_data(datsf, nsample = 2e3)
  )
  ,
  tar_target(
    tarsplit,
    split_data(datsfpp, "zip4")
  )
  ,
  tar_target(
    recipe_set,
    reciping(datsfpp, names(datsfpp)[seq(4, 15)], "price")
  )
  ,
  tar_target(
    train0,
    train_model(
      preproc = recipe_set,
      xc = names(datsfpp)[seq(4, 15)],
      res = tarsplit
    )
  )
  ,
  tar_target(
    pred,
    generate_predictions(train0, split = tarsplit)
  )
)
