

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

# works in mirai>=1.3.0
mirai::daemons(8, dispatcher = "process")

bench_target <- function(chunk_size = 1000L, max_cells = 1e7) {

  orig_vec <- seq_len(nrow(rbs))
  chunked <- ceiling(orig_vec / chunk_size)
  chunked_l <- split(orig_vec, chunked)

  # case 2. filepath reference
  vfile <- file.path(tempdir(), "vecexport.gpkg")
  sf::st_write(rbs, vfile, append = FALSE)

  test_mm2 <- mirai::mirai_map(
    .x = chunked_l,
    .f = function(rowindex, vec, ras, ...) {
      library(terra)
      library(sf)
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
          max_cells_in_memory = max_cells
        )
      return(xk)
    },
    .args = list(vec = vfile, ras = ff, max_cells = max_cells)
  )
  message <- sprintf("Chunksize=%d", chunk_size)
  tictoc::tic(message)
  test_mm2[.progress]
  tictoc::toc()
}


bench_target(chunk_size = 100L)
# 216.487 sec
bench_target(chunk_size = 500L)
# 170.158 sec
bench_target(chunk_size = 2000L)
# 170.8 sec
bench_target(chunk_size = 5000L)
# 182.158 sec
bench_target(chunk_size = 10000L)
# 225.674 sec


## max cells
bench_target(chunk_size = 1e3L, max_cells = 5e+06)
# 179.415 sec
bench_target(chunk_size = 1e3L, max_cells = 3e+07)
# 171.517 sec
bench_target(chunk_size = 1e3L, max_cells = 5e+07)
# 174.636 sec

