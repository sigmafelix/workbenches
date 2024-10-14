pkgs <- c("mirai", "terra", "sf", "stars")
invisible(sapply(pkgs, library, character.only = TRUE, quietly = TRUE))
sf_use_s2(FALSE)

rr <- rast(nrow = 2000, ncol = 3000)
values(rr) <- rgamma(6e6, 12, 2)

rp <- spatSample(ext(rr), 100000, as.points = TRUE, lonlat = FALSE)
rp$pid <- sprintf("ID-%04d", seq(1, nrow(rp)))
rb <- buffer(rp, 30)

rrs <- st_as_stars(rr)
rps <- st_as_sf(rp)
rbs <- st_as_sf(rb)

st_crs(rrs) <- st_crs(rps) <- "OGC:CRS84"
st_extract(rrs, at = rps)
st_crs(rbs) <- "OGC:CRS84"

# cl <- mirai::make_cluster(4)
# mirai::stop_cluster()

mirai::daemons(4, dispatcher = "thread")

rrrp_mir <-
mirai({
	stars::st_extract(x, at = y)
}, x = rrs, y = rps)

print(rrrp_mir)
print(rrrp_mir$data)

rrt <- rast(rrs)
rpt <- vect(rps)

system.time(ka <- extract(rrt, rpt))
system.time(kb <- exactextractr::exact_extract(rrt, rbs))

rrrpt_mir <-
mirai({
	library(terra)
	library(sf)
	library(stars)
	library(exactextractr)
	rrc <- terra::rast(xx)
	
	#rpc <- terra::vect(yy)
	xk <- exactextractr::exact_extract(x = rrc, y = yy, fun = "mean")
	return(xk)
}, xx = rrs, yy = rbs)
while (unresolved(rrrpt_mir)) {
  cat("unresolved\n")
  Sys.sleep(0.1)
}

rrrpt_mir$data


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

# cl <- mirai::make_cluster(4)
# mirai::stop_cluster()

mirai::daemons(4, dispatcher = "process")

dispatcher <- mirai::dispatcher(host = "127.0.0.1", n = 1)
test_mm <- mirai::mirai_map(
  .x = rbs[seq_len(3),], .f = \(geometry, rr, ...) {
    library(terra)
    library(sf)
    library(stars)
    library(exactextractr)
	sf::sf_use_s2(FALSE)
	# return(x)
# rr <- rast(nrow = 2000, ncol = 3000)
# values(rr) <- rgamma(6e6, 12, 2)
#     rrc <- terra::rast(rr)
# 	return(terra::ext(rrc))
#	print(geometry)
	# rrx <- terra::rast(rrs)
	# xz <- sf::st_as_sf(x = x, sf_column_name = "geometry")
	rr = terra::rast(rr)
	geox = st_as_sfc(list(geometry))
	#return(class(geox))
    xk <- exactextractr::exact_extract(x = rr, y = geox, fun = "mean")
    return(xk)
  },
  .args = list(rr = ff)
)

test_mm
test_mm[]
test_mm[.flat]
test_mm[.progress]

unclass(rbs$geometry[[1]])
