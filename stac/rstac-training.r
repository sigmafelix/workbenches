## RSTAC

pkgs <- c("terra", "rstac", "data.table")
invisible(
  sapply(pkgs, library, character.only = TRUE, quietly = TRUE)
)


## from stacspec.org
ashe <- sf::read_sf(system.file("gpkg/nc.gpkg", package = "sf"))[1, ]
ashe_bbox <- ashe |>
  sf::st_transform(4326) |>
  sf::st_bbox()

nc <- sf::read_sf(system.file("gpkg/nc.gpkg", package = "sf")) |>
  sf::st_transform(4326)
ncp <- sf::st_sample(nc, 1000L)
ncp <- sf::st_as_sf(ncp) |>
  dplyr::mutate(id = sprintf("ID-%04d", seq(1, 1000L)))
ncb <- ncp |>
  terra::vect() |>
  terra::project("EPSG:5070") |>
  terra::buffer(width = 5000L)


utoken <- readLines("~/.planettoken")[2]

# test
ncmod13 <-
  query_stac_pcomp(
    collections = "modis-13A1-061",
    asset_names = "500m_16_days_NDVI",
    date_range = "2018-06-01/2018-06-30",
    bbox = sf::st_bbox(nc),
    token = utoken
  )

# unexpected results or as expected?
ncmod13r <- terra::rast(ncmod13[1])
# seems to use network to download the file
# class       : SpatRaster 
# dimensions  : 2400, 2400, 1  (nrow, ncol, nlyr)
# resolution  : 463.3127, 463.3127  (x, y)
# extent      : -7783654, -6671703, 3335852, 4447802  (xmin, xmax, ymin, ymax)
# coord. ref. : +proj=sinu +lon_0=0 +x_0=0 +y_0=0 +R=6371007.181 +units=m +no_defs 
# source      : MOD13A1.A2018177.h11v05.061.2021339232142_500m_16_days_NDVI.tif 
# name        : 500m 16 days NDVI 
# ncmod13r <- terra::vrt(ncmod13)
ncbs <- terra::project(ncb, terra::crs(ncmod13r))

system.time(
  ncmod_bex <-
    exactextractr::exact_extract(
      x = ncmod13r,
      y = sf::st_as_sf(ncbs),
      fun = "mean",
      force_df = TRUE
    )
)
# Network transmission. Including the transmission time.
#    user  system elapsed
#   0.560   0.041   3.925

# terra::writeRaster(ncmod13r, "~/Downloads/MOD13A1_test.tif")
ncmod13d <- terra::rast("~/Downloads/MOD13A1_test.tif")
system.time(
  ncmod_bex <-
    exactextractr::exact_extract(
      x = ncmod13d,
      y = sf::st_as_sf(ncbs),
      fun = "mean",
      force_df = TRUE
    )
)
#    user  system elapsed
#   0.306   0.012   0.318


ncmod13_filtered <- grep("MOD13", ncmod13, value = TRUE)
ncmod13_sprc <- terra::sprc(ncmod13_filtered)
ncmod13_sprc_mos <- terra::mosaic(ncmod13_sprc)


query_stac_gen <-
  function(
    url_root = "https://planetarycomputer.microsoft.com/api/stac/v1",
    collections = NULL,
    asset_names = NULL,
    date_range = NULL,
    bbox = NULL,
    token = NULL
  ) {

    # get full path to the dataset and extents
    full_query <-
      rstac::stac(url_root) |>
      rstac::stac_search(
        collections = collections,
        bbox = bbox,
        datetime = date_range
      ) |>
      rstac::get_request() |>
      rstac::assets_url(asset_names = asset_names)
    return(full_query)

  }


# datatime argument should abide by RFC3339
# URLs listed in stacindex.org should be properly interpreted
# to populate relevant arguments in rstac functions.
# OK
rstac::stac("https://tamn.snapplanet.io") |>
  rstac::stac_search(
    collections = "S2",
    datetime = "2023-01-01T00:00:00Z/2024-01-07T23:59:00Z",
    bbox = st_bbox(nc),
    limit = 5L)|>
  rstac::get_request()

# application/xml error
rstac::stac("https://storage.googleapis.com/earthengine-stac") |>
  rstac::stac_search(
    collections = "COPERNICUS",
    datetime = "2023-01-01/2023-01-02", limit = 5L
  ) |>
  rstac::get_request()# |>
#   rstac::assets_url(asset_names = "COPERNICUS_S2_CLOUD_PROBABILITY")


# get results
rstac::stac("https://landsatlook.usgs.gov/stac-server") |>
  rstac::stac_search(
    collections = "landsat-c2l2alb-ta",
    datetime = "2023-01-01T00:00:00Z/2023-01-07T23:59:00Z", limit = 5L) |>
  rstac::get_request()

# authorization error
rstac::stac("https://services.sentinel-hub.com/api/v1/catalog/1.0.0") |>
  rstac::stac_search(
    collections = "sentinel-2-l1c",
    datetime = "2023-01-01T00:00:00Z/2023-01-07T23:59:00Z",
    bbox = st_bbox(ashe),
    limit = 5L) |>
  rstac::get_request()


rstac::stac("https://earthengine.openeo.org/v1.0") |>
  rstac::stac_search(
    collections = "AU/GA/AUSTRALIA_5M_DEM",
    #datetime = "2023-01-01T00:00:00Z/2023-01-07T23:59:00Z",
    #bbox = st_bbox(ashe),
    limit = 5L)|>
  rstac::get_request()

# gdalcube
# https://r-spatial.org/r/2021/04/23/cloud-based-cubes.html
install.packages("gdalcubes")

usmod13 <-
  query_stac_pcomp(
    collections = "modis-13A1-061",
    asset_names = "500m_16_days_NDVI",
    date_range = "2018-06-01/2018-07-31",
    bbox = c(-128, 22, -60, 52),
    token = utoken,
    return_query = TRUE
  )


col <-
  gdalcubes::stac_image_collection(
    s = usmod13$features,
    asset_names = "500m_16_days_NDVI"
  )

v <- gdalcubes::cube_view(
  srs = "EPSG:5070",
  extent = list(left = 1500000, right = 3000000, top = 3000000, bottom = 1000000,
                t0 = "2018-06-01", t1 = "2018-07-31"),
  dx = 500, dy = 500, dt = "P16D", aggregation = "median", resampling = "bilinear"
)

gdalcubes::gdalcubes_options(threads = 8)
gdalcubes::raster_cube(col, v) |>
  gdalcubes::reduce_time(c("median(500m_16_days_NDVI)")) |>
  plot(zlim = c(-1000000, 10000000))

ndvi_x <-
  gdalcubes::raster_cube(col, v) |>
  gdalcubes::reduce_time(c("median(500m_16_days_NDVI)")) |>
  stars::st_as_stars()
