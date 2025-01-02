library(dbplyr)
library(DBI)
library(duckdb)
# takes a long time
library(duckplyr)
library(terra)
library(collapse)
library(data.table)

duckplyr::as_duckplyr_df()

con <- duckdb::duckdb("~/spatial_workbench.duckdb")
con <- duckdb::dbConnect(con)

dbListTables(con)
duckdb::dbListTables(con)

# does not work
check <- vect(con, layer = "tract10")

# work but geometry is not read properly
check <- sf::st_read(con, layer = "tract10")

# data
storage <- "/mnt/s/Projects/beethoven_input/aqs"
csvs_aqs <- list.files(storage, "*.csv", recursive = TRUE, full.names = TRUE)
dfs_aqs <- Map(fread, csvs_aqs)
dt_aqs <- rowbind(dfs_aqs, fill = TRUE)

# dbplyr
duckdb::dbListTables(con)

dplyr::copy_to(con, dt_aqs)
ddt_aqs <- dplyr::tbl(con, "dt_aqs")

unique_sites <-
  ddt_aqs |>
  dplyr::select(1:9, 11, 13, `Arithmetic Mean`, `Date of Last Change`) |>
  dplyr::transmute(
    site_id = printf("%02d%03d%04d%05d%01d",
    `State Code`, `County Code`, `Site Num`, `Parameter Code`, POC),
    Latitude = Latitude,
    Longitude = Longitude
  ) |>
  dplyr::group_by(site_id) |>
#   dplyr::summarize(dplyr::across(Latitude:Datum, ~distinct(.))) |>
  dplyr::distinct() |>
  dplyr::ungroup()

unique_sites |> dplyr::show_query()

unique_sites |> dplyr::collect()
