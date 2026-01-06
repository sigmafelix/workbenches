# spacetime cube data structure
library(sfdep)
library(spacetime)
library(sf)

# load de data
data(package = "spacetime")
data(air)
# air, stations, dates

stn_sf <- st_as_sf(stations)
stn_sf$id <- as.character(rownames(stations@coords))

idchar <- as.character(rownames(stations@coords))
# create a spacetime cube
airdf <- expand.grid(
  id = idchar,
  date = dates
)
airdf$pm10 <- as.vector(air)
airdf$id <- as.character(airdf$id)

# define a spacetime object
# key types should match (i.e., .loc_col in both .geometry and .data)
st <-
  spacetime(
    .data = airdf,
    .geometry = stn_sf,
    .loc_col = "id",
    .time_col = "date"
  )

# check if it is a spacetime cube
is_spacetime_cube(st)


st |>
  dplyr::filter(id == "DEBE032")
st |>
  dplyr::filter(date >= "2009-06-30")


# TODO: colocation...
