# ============================================================
# exactextractr workflow for categorical land-use fractions
# ============================================================
# modified gdalCache

library(terra)
library(sf)
library(exactextractr)
library(future)
library(future.apply)
library(dplyr)
library(tidyr)

# -----------------------------
# User settings
# -----------------------------
raster_file   <- "/mnt/nerf/glc_fcs30d/glc_fcs30d_30m_2022.cog.tif"   # tiled GTiff or COG
point_file    <- "/mnt/nerf/glc_fcs30d/points5k.gpkg"                # can be gpkg / shp / geojson etc.
point_layer   <- NULL                         # set if needed for multi-layer GPKG
id_field      <- NULL                         # set to an existing ID column if you have one
buffer_radii  <- c(30, 100, 500, 2000)       # meters

workers               <- 24L                 # benchmark 12 / 24 / 40
gdal_cache_mb         <- 2048L               # per worker
max_cells_in_memory   <- 1e8                 # for exact_extract
start_supertile_px    <- 8192L               # starting point for raster-aligned chunk size
safety_fraction       <- 0.85                # keep estimated padded chunk below 85% of max_cells_in_memory

# optional outputs
write_wide_csv <- FALSE
write_long_csv <- FALSE

# -----------------------------
# Helper: choose a supertile size
# based on raster resolution and max buffer radius
# -----------------------------
choose_supertile_px <- function(res_xy, max_radius_m,
                                max_cells_in_memory = 1e8,
                                start_px = 8192L,
                                safety = 0.85) {
  rx <- abs(res_xy[1])
  ry <- abs(res_xy[2])

  halo_x <- ceiling(max_radius_m / rx)
  halo_y <- ceiling(max_radius_m / ry)

  px <- as.integer(start_px)

  est_cells <- function(px) {
    (px + 2L * halo_x) * (px + 2L * halo_y)
  }

  while (est_cells(px) > max_cells_in_memory * safety && px > 512L) {
    px <- as.integer(px %/% 2L)
  }

  list(
    supertile_px = px,
    halo_px_x = halo_x,
    halo_px_y = halo_y,
    est_padded_cells = est_cells(px)
  )
}

# -----------------------------
# Helper: assign each point to a raster-aligned chunk
# -----------------------------
assign_chunks <- function(pts_sf, r, supertile_px) {
  xy   <- st_coordinates(pts_sf)
  rr <- rast(r)
  cols <- colFromX(rr, xy[, 1])
  rows <- rowFromY(rr, xy[, 2])

  keep <- !is.na(cols) & !is.na(rows)
  if (!all(keep)) {
    message(sum(!keep), " point(s) fall outside the raster extent and will be dropped.")
  }

  pts_sf <- pts_sf[keep, ]
  cols   <- cols[keep]
  rows   <- rows[keep]

  pts_sf$tile_col <- (cols - 1L) %/% supertile_px
  pts_sf$tile_row <- (rows - 1L) %/% supertile_px
  pts_sf$chunk_id <- sprintf("r%05d_c%05d", pts_sf$tile_row, pts_sf$tile_col)

  pts_sf
}

# -----------------------------
# Helper: run one chunk for one radius
# -----------------------------
process_one_chunk <- function(buf_sf, r, radius_m,
                              gdal_cache_mb = 2048L,
                              max_cells_in_memory = 1e8) {
  # Important for separate worker processes
  terra::gdalCache(gdal_cache_mb)
  r <- terra::rast(r)
  # Run exact extraction in native code
  ee <- exact_extract(
    x = r,
    y = buf_sf,
    fun = "frac",
    progress = FALSE,
    max_cells_in_memory = max_cells_in_memory
  )

  # attach identifying columns
  out <- cbind(
    st_drop_geometry(buf_sf[, c("pt_id", "chunk_id")]),
    buffer_m = radius_m,
    ee
  )

  out
}

# -----------------------------
# Helper: run all chunks for one radius
# -----------------------------
process_one_radius <- function(pts_chunked, r, radius_m,
                               gdal_cache_mb = 2048L,
                               max_cells_in_memory = 1e8) {

  # Build buffers once for this radius
  buf <- st_buffer(pts_chunked[, c("pt_id", "chunk_id")], dist = radius_m)

  idx_by_chunk <- split(seq_len(nrow(buf)), buf$chunk_id)

  res_list <- future_lapply(
    idx_by_chunk,
    FUN = function(idx) {
      process_one_chunk(
        buf_sf = buf[idx, ],
        r = r,
        radius_m = radius_m,
        gdal_cache_mb = gdal_cache_mb,
        max_cells_in_memory = max_cells_in_memory
      )
    },
    future.seed = TRUE
  )

  # bind rows with fill for missing class columns
  out <- bind_rows(res_list)

  # replace missing fractions with 0
  frac_cols <- setdiff(names(out), c("pt_id", "chunk_id", "buffer_m"))
  out[frac_cols] <- lapply(out[frac_cols], function(x) {
    x[is.na(x)] <- 0
    x
  })

  out
}

# ============================================================
# Main
# ============================================================

# Avoid nested over-threading when using many R workers
Sys.setenv(
  OMP_NUM_THREADS = "1",
  OPENBLAS_NUM_THREADS = "1",
  MKL_NUM_THREADS = "1"
)

# Read raster
r <- raster_file

# Basic checks
# if (is.lonlat(r)) {
#   stop("Raster is lon/lat. Reproject it to a projected CRS with meter units before buffering.")
# }

# Read points
pts <- if (is.null(point_layer)) {
  st_read(point_file, quiet = TRUE)
} else {
  st_read(point_file, layer = point_layer, quiet = TRUE)
}

if (nrow(pts) == 0) stop("Point dataset is empty.")
if (is.na(st_crs(pts))) stop("Point dataset has no CRS defined.")

# Reproject points to raster CRS
pts <- st_transform(pts, crs(rast(r)))

# Add a point ID if not supplied
if (is.null(id_field)) {
  pts$pt_id <- seq_len(nrow(pts))
} else {
  if (!id_field %in% names(pts)) stop("id_field not found in point data.")
  pts$pt_id <- pts[[id_field]]
}

# Choose raster-aligned chunk size based on your largest buffer
chunk_info <- choose_supertile_px(
  res_xy = res(rast(r)),
  max_radius_m = max(buffer_radii),
  max_cells_in_memory = max_cells_in_memory,
  start_px = start_supertile_px,
  safety = safety_fraction
)

message("Chosen supertile size: ", chunk_info$supertile_px, " pixels")
message("Estimated padded chunk cells: ", format(chunk_info$est_padded_cells, big.mark = ","))
message("Halo in pixels (x, y): ", chunk_info$halo_px_x, ", ", chunk_info$halo_px_y)

# Assign points to raster-aligned chunks
pts_chunked <- assign_chunks(
  pts_sf = pts,
  r = r,
  supertile_px = chunk_info$supertile_px
)

message("Number of points kept: ", nrow(pts_chunked))
message("Number of chunks: ", dplyr::n_distinct(pts_chunked$chunk_id))

# Parallel plan
library(mirai)
library(future.mirai)
# On Linux, multicore is usually fine; multisession is safer cross-platform.
future::plan(mirai_multisession, workers = workers)

# Apply gdalCache in the main process too
terra::gdalCache(gdal_cache_mb)

# Run extraction radius by radius
all_results <- lapply(
  buffer_radii,
  function(rad) {
    message("Processing radius = ", rad, " m")
    process_one_radius(
      pts_chunked = pts_chunked,
      r = r,
      radius_m = rad,
      gdal_cache_mb = gdal_cache_mb,
      max_cells_in_memory = max_cells_in_memory
    )
  }
)

# Combine wide output
frac_wide <- bind_rows(all_results)

# Convert to long output if preferred
frac_long <- frac_wide %>%
  pivot_longer(
    cols = -c(pt_id, chunk_id, buffer_m),
    names_to = "landuse_code",
    values_to = "frac"
  ) %>%
  filter(frac > 0)

# Optional write-out
if (write_wide_csv) {
  write.csv(frac_wide, "landuse_frac_wide.csv", row.names = FALSE)
}
if (write_long_csv) {
  write.csv(frac_long, "landuse_frac_long.csv", row.names = FALSE)
}

# Final objects in memory:
#   frac_wide : one row per point-buffer, columns = land-use classes
#   frac_long : long format, one row per point-buffer-class
message("Done.")
