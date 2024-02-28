library(targets)
source("./target-tidy/tidymodels_targets.r")

## target pipeline
list(
  tar_target(
    data,
    load_data()
  )
  ,
  tar_target(
    datsf,
    prep_sf(data)
  )
  ,
  tar_target(
    datsfpp,
    preprocess_data(datsf)
  )
  ,
  tar_target(
    tarsplit,
    split_data(datsfpp)
  )
  ,
  tar_target(
    train0,
    train_model(
      data = datsfpp,
      xc = names(datsfpp)[seq(4, 15)],
      res = tarsplit)
  )
  ,
  tar_target(
    pred,
    generate_predictions(train0, res = tarsplit)
  )
)
