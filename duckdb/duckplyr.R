library(dbplyr)
library(DBI)
library(duckdb)
# takes a long time
library(duckplyr)
library(terra)
library(collapse)
library(data.table)
library(qs)
library(nanoparquet)


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



##
df_duck <-
  duckplyr::read_parquet_duckdb(
    "duckdb/df_feat_calc_daily_full.parquet",
    prudence = "lavish"
  )

haversine <- function(lat1, lon1, lat2, lon2) {
  R <- 6371 # Earth radius in kilometers
  dlat <- (lat2 - lat1) * pi / 180
  dlon <- (lon2 - lon1) * pi / 180
  a <- sin(dlat / 2)^2 + cos(lat1 * pi / 180) * cos(lat2 * pi / 180) * sin(dlon / 2)^2
  c <- 2 * atan2(sqrt(a), sqrt(1 - a))
  R * c
}


df_seoul_haversine <-
  df_duck |>
  filter(grepl("^11", TMSID)) |>
  mutate(
    d_hav = haversine(lat2, lon2, lag(lat2), lag(lon2)),
    .by = TMSID
  ) |>
  ungroup()

#
df_duck_summary <-
  df_duck |>
  mutate(yearmonth = strftime(date, "%Y%m")) |>
  # group_by(TMSID, yearmonth) |>
  summarize(
    PM10 = mean(PM10, na.rm = TRUE),
    PM2.5 = mean(PM25, na.rm = TRUE),
    t2m = mean(t2m, na.rm = TRUE),
    u10 = mean(u10, na.rm = TRUE),
    v10 = mean(v10, na.rm = TRUE),
    sp = mean(sp, na.rm = TRUE),
    ssr = mean(ssr, na.rm = TRUE),
    tp = mean(tp, na.rm = TRUE),
    aod = mean(aod, na.rm = TRUE),
    blh = mean(blh, na.rm = TRUE),
    d_road = mean(d_road, na.rm = TRUE),
    PM10_med = median(PM10, na.rm = TRUE),
    PM2.5_med = median(PM2.5, na.rm = TRUE),
    t2m_med = median(t2m, na.rm = TRUE),
    u10_med = median(u10, na.rm = TRUE),
    v10_med = median(v10, na.rm = TRUE),
    sp_med = median(sp, na.rm = TRUE),
    ssr_med = median(ssr, na.rm = TRUE),
    tp_med = median(tp, na.rm = TRUE),
    aod_med = median(aod, na.rm = TRUE),
    blh_med = median(blh, na.rm = TRUE),
    d_road_med = median(d_road, na.rm = TRUE),
    # across(matches("PM|t2m|u10|v10|sp|ssr|tp|aod|blh|d_road"), mean),
    .by = c(TMSID, yearmonth)
  ) |>
  ungroup()
# duckplyr does not support group_by + summarize; .by inside apply functions
# across() does not work; need to specify each column separately

duckplyr::compute_parquet(
  df_duck_summary,
  "duckdb/df_feat_calc_monthly_full.parquet",
  prudence = "stingy",
  options = list(compression = "ZSTD", compression_level = 22)
)
duckplyr::compute_parquet(
  df_seoul_haversine,
  "duckdb/df_feat_11_haversine.parquet",
  prudence = "stingy",
  options = list(compression = "ZSTD", compression_level = 22)
)
summary(df_seoul_haversine$d_hav)
