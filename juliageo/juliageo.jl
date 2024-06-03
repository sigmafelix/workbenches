
using GeoInterface
using GeoDataFrames
using Rasters, ArchGDAL, RasterDataSources
using CairoMakie, Makie
using Plots

rr = Rasters.RasterStack("/home/felix/Downloads/agg_terraclimate_ppt_1958_CurrentYear_GLOBE.nc")
rr

plot(rr[:,:,:,1];)

fig = Figure();
plot(fig[1, 1], rr[:,:,1])
Rasters.rplot(rr[:,:,1:10]; Axis = (aspect = DataAspect(),),)



filecheck = ArchGDAL.read("/home/felix/Documents/nhgis0047_shape/US_cbsa_2010.shp")
filecheck1 = ArchGDAL.getlayer(filecheck, 0)
ArchGDAL.getspatialref(filecheck1)
poppl = ArchGDAL.read("/home/felix/Documents/US_Census_Populated_Places.gpkg")

poppl1 = ArchGDAL.getlayer(poppl, 0)
ArchGDAL.getspatialref(poppl1)

poppl1re = ArchGDAL.reproject(poppl1, ArchGDAL.getspatialref(poppl1), ArchGDAL.getspatialref(filecheck1))

# Define a point buffer
buffer_radius = 100.0  # Specify the buffer radius in meters
point = Point(0.0, 0.0)  # Specify the center point coordinates

# Define the coordinate reference system (CRS)
crs = CRS("EPSG:4326")  # Example: EPSG:4326 is the WGS84 CRS

ArchGDAL.CoordTransform()
buffer = Buffer(point, buffer_radius, crs)



#
# Create a GeoDataFrame from the reprojected layer
poppl1re_gdf = GeoDataFrames.read("/home/felix/Documents/US_Census_Populated_Places.gpkg")

# Modify the geometry of the GeoDataFrame
poppl1re_gdf.geometry = GeoInterface.translate(poppl1re_gdf.geometry, 1.0, 1.0)

# Perform unary operations on the geometry
poppl1re_gdf.geometry = GeoDataFrames.buffer(poppl1re_gdf.geom, 0.0)

# Perform binary operations on the geometry
intersection = GeoInterface.intersection(poppl1re_gdf.geometry, buffer)

# Perform spatial projection transformation
poppl1re_gdf.geometry = GeoDataFrames.reproject(poppl1re_gdf.geometry, GeoFormatTypes.EPSG(2163), GeoFormatTypes.EPSG(5070))

epsg2163 = GeoFormatTypes.EPSG(2163)
GeoFormatTypes.ESRIWellKnownText(epsg2163)
GeoFormatTypes.ESRIWellKnownText("ESRI:102003")