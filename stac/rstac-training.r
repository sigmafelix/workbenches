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

#' Query STAC from Planetary Computer with parameters
#' @param url_root character(1). https address string
#' @param collections character. Collections.
#' @param asset_names character. IDs.
#' @param date_range character(1). Date range of the search.
#' Should be formed YYYY-MM-DD/YYYY-MM-DD. The former should
#' predate the latter.
#' @param bbox numeric(4). [sf::st_bbox] output.
#' @param token character(1). Planetary Computer access token.
#' @returns vsicurl data path.
#' @author Insang Song
#' @references [STAC specification][https://www.stacspec.org]
#' @importFrom rstac stac_search
#' @importFrom rstac get_request
#' @importFrom rstac stac
#' @importFrom rstac assets_url
#' @importFrom rstac items_sign
#' @importFrom rstac sign_planetary_computer
#' @export
query_stac_pcomp <-
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
      rstac::items_sign(
        sign_fn =
        rstac::sign_planetary_computer(
          headers = c("Ocp-Apim-Subscription-Key" = token)
        )
      ) |>
      rstac::assets_url(asset_names = asset_names)
    return(full_query)
    # vsicurl base
    # vsi_template <-
    #   paste0(
    #     "/vsicurl",
    #     "?pc_url_signing=yes",
    #     "&pc_collection=%s",
    #     "&url=%s"
    #   )

    # vsi_full <-
    #   sprintf(
    #     vsi_template,
    #     collections,
    #     full_query
    #   )
    # return(vsi_full)
  }

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
