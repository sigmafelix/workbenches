library(targets)
source("./target-tidy/tidymodels_targets.r")

tar_option_set(
  controller = 
  crew::crew_controller_local(
    workers = 24L,
    name = "default",
    garbage_collection = TRUE
  ),
  # crew.cluster::crew_launcher_cluster(
  #   name = "default"
  # ),
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
    preprocess_data(datsf, nsample = 8e3)
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

# gs <- load_data()
# dat <- prep_sf(gs)
# # kk <- sf::st_bbox(c(xmin = -1990000, ymin = 2954000, xmax = -1925000, ymax = 3030000), crs = "EPSG:5070")
# dat <- preprocess_data(dat)
# datrec <- reciping(dat, names(dat)[seq(4, 15)], yc = "price")
# datsplit <- split_data(dat, "zip4")
# dattrain <- train_model(
#   data = datrec,
#   xc = names(dat)[seq(4, 15)],
#   res = datsplit
# )
