
library(chopin)
library(sf)
library(mirai)
library(terra)
options(sf_use_s2 = FALSE)

## mirai_map (1.3.0)

rr <- rast(nrow = 2000, ncol = 3000)
values(rr) <- rgamma(6e6, 12, 2)
ff <- file.path(tempdir(), "test.tif")
terra::writeRaster(rr, ff)

rp <- spatSample(ext(rr), 100000, as.points = TRUE, lonlat = FALSE)
rp$pid <- sprintf("ID-%04d", seq(1, nrow(rp)))
rb <- buffer(rp, 30)

rrs <- st_as_stars(rr)
rps <- st_as_sf(rp)
rbs <- st_as_sf(rb)

st_crs(rrs) <- st_crs(rps) <- "OGC:CRS84"
st_extract(rrs, at = rps)
st_crs(rbs) <- "OGC:CRS84"

mirai::daemons(4, dispatcher = "process")

# case 1. chunking, local load
chunk_size <- 1000L
orig_vec <- seq_len(nrow(rbs))
chunked <- ceiling(orig_vec / chunk_size)

chunked_l <- split(orig_vec, chunked)
test_mm <- mirai::mirai_map(
  .x = chunked_l,
  .f = function(rowindex, vec, ras, ...) {
    # todo: confirm whether package loading is required
    library(terra)
    library(sf)
    library(stars)
    library(exactextractr)
	sf::sf_use_s2(FALSE)

	ras <- terra::rast(ras)
	geox <- vec[rowindex, ]

    xk <-
      exactextractr::exact_extract(
        x = ras,
        y = geox,
        fun = "mean",
        force_df = TRUE,
        progress = FALSE,
        max_cells_in_memory = 1e7
      )
    return(xk)
  },
  .args = list(vec = rbs, ras = ff)
)

system.time(
  single <- exactextractr::exact_extract(
    x = rr,
    y = rbs,
    fun = "mean",
    force_df = TRUE,
    progress = FALSE,
    max_cells_in_memory = 1e7
  )
)


pryr::object_size(rbs)

# case 2. filepath reference
vfile <- file.path(tempdir(), "vecexport.gpkg")
sf::st_write(rbs, vfile, append = FALSE)

test_mm2 <- mirai::mirai_map(
  .x = chunked_l,
  .f = function(rowindex, vec, ras, ...) {
    # todo: confirm whether package loading is required
    library(terra)
    library(sf)
    library(stars)
    library(exactextractr)
	sf::sf_use_s2(FALSE)

	ras <- terra::rast(ras)
    vec <- terra::vect(vec)
    vec <- vec[rowindex, ]
	geox <- sf::st_as_sf(vec)

    xk <-
      exactextractr::exact_extract(
        x = ras,
        y = geox,
        fun = "mean",
        force_df = TRUE,
        progress = FALSE,
        max_cells_in_memory = 1e7
      )
    return(xk)
  },
  .args = list(vec = vfile, ras = ff)
)

test_mm2[.progress]