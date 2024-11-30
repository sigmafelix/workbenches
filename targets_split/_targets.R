# Created by use_targets().
# Follow the comments below to fill in this target script.
# Then follow the manual to check and run the pipeline:
#   https://books.ropensci.org/targets/walkthrough.html#inspect-the-pipeline

# Load packages required to define the pipeline:
library(targets)
library(chopin)
library(geotargets)
library(sf)
options(sf_use_s2 = FALSE)
# library(tarchetypes) # Load other packages as needed.

# Set target options:
tar_option_set(
  packages = c("tibble", "terra", "chopin", "geotargets","sf") # Packages that your targets need for their tasks.
  # format = "qs", # Optionally set the default storage format. qs is fast.
  #
  # Pipelines that take a long time to run may benefit from
  # optional distributed computing. To use this capability
  # in tar_make(), supply a {crew} controller
  # as discussed at https://books.ropensci.org/targets/crew.html.
  # Choose a controller that suits your needs. For example, the following
  # sets a controller that scales up to a maximum of two workers
  # which run as local R processes. Each worker launches when there is work
  # to do and exits if 60 seconds pass with no tasks to run.
  #
  #   controller = crew::crew_controller_local(workers = 2, seconds_idle = 60)
  #
  # Alternatively, if you want workers to run on a high-performance computing
  # cluster, select a controller from the {crew.cluster} package.
  # For the cloud, see plugin packages like {crew.aws.batch}.
  # The following example is a controller for Sun Grid Engine (SGE).
  # 
  #   controller = crew.cluster::crew_controller_sge(
  #     # Number of workers that the pipeline can scale up to:
  #     workers = 10,
  #     # It is recommended to set an idle time so workers can shut themselves
  #     # down if they are not running tasks.
  #     seconds_idle = 120,
  #     # Many clusters install R as an environment module, and you can load it
  #     # with the script_lines argument. To select a specific verison of R,
  #     # you may need to include a version string, e.g. "module load R/4.3.2".
  #     # Check with your system administrator if you are unsure.
  #     script_lines = "module load R"
  #   )
  #
  # Set other options as needed.
)

# Run the R scripts in the R/ folder with your custom functions:
# tar_source()
# tar_source("other_functions.R") # Source other scripts as needed.

# Replace the target list below with your own:
list(
  tar_target(
    name = filepath_vec,
    command = system.file("gpkg/nc.gpkg", package= "sf")
    # format = "qs" # Efficient storage for general data objects.
  ),
  tar_target(
    name = filepath_ras,
    command = system.file("extdata/nc_srtm15_otm.tif", package = "chopin")
    ),
  tar_terra_rast(
    name = ras_nc,
    command = terra::rast(filepath_ras)
    ),
  tar_terra_vect(
    name = vec_nc,
    command = terra::project(terra::vect(filepath_vec), terra::crs(ras_nc))
  ),
  tar_target(
    name = tiled,
    command = chopin::par_pad_grid(sf::st_as_sf(vec_nc), mode = "grid", nx = 2L, ny = 2L, padding=3000)[[2]]
  ),
  tar_target(
    name = ras_tiled,
    command = terra::extract(ras_nc, terra::buffer(vec_nc[terra::ext(tiled)+1000,], 1000), ID=TRUE,fun="mean"),
    iteration = "vector",
    pattern = map(tiled)
    )
)
