
# beethoven
# set_args_download(
#   char_period = c("2020-06-01", "2020-06-30"),
#   char_input_dir = ".",
#   nasa_earth_data_token = readLines("~/.edtoken")[1],
#   export = TRUE,
#   path_export = "~/Documents/beethoven_input/download_spec.qs"
# )


# modisfast (opendapr)
library(modisfast)

# Load the packages
library(modisfast)
library(sf)
library(terra)

# ROI and time range of interest
roi <-
  sf::st_as_sf(
    data.frame(
      id = "roi_id",
      geom = "POLYGON ((-126 22, -64 22, -64 52, -126 52, -126 22))"
    ),
    wkt = "geom",
    crs = 4326
  ) # a ROI of interest, format sf polygon
time_range <- as.Date(c("2020-06-01", "2020-06-30"))  # a time range of interest


# MODIS collections and variables (bands) of interest
mf_list_variables("MOD09GA.061")
mf_list_collections()

collection <- "MOD09GA.061"
variables <- c("_500m_16_days_NDVI")
variables <- sprintf("sur_refl_b%02d_1", 1:7)

log <-
  mf_login(
    credentials =
    c(readLines("~/Documents/.earthdata")[1],
      readLines("~/Documents/.earthdata")[2]
    )
  )


## Get the URLs of the data
urls <-
  mf_get_url(
    collection = collection,
    variables = variables,
    roi = roi,
    time_range = time_range
  )

## Download the data. By default the data is downloaded in
## a temporary directory, but you can specify a folder
res_dl <- mf_download_data(urls, parallel = TRUE)


# luna
library(luna)
mod11_d <-
  luna::getNASA(
    product = "MOD11A2",
    start_date = "2020-06-01",
    end_date = "2020-06-30",
    aoi = terra::ext(c(-126, -64, 22, 52)),
    version = "061",
    download = TRUE,
    server = "LPDAAC_ECS",
    username = readLines("~/Documents/.earthdata")[1],
    password = readLines("~/Documents/.earthdata")[2],
    path = "~/Documents/modis/mod06",
    overwrite = TRUE
  )

k <- luna::getProducts()
