"""
Demonstration of raster-vector overlay using xarray/rioxarray and dask-geopandas.

This script reads a raster dataset and a vector dataset from online sources,
performs spatial operations using xarray/rioxarray and dask-geopandas, and
demonstrates how to overlay vector data on raster data.

Dependencies:
- numpy
- pandas
- xarray
- rioxarray
- dask
- dask-geopandas
- geopandas
- rasterio
- matplotlib

Make sure to install the required packages before running the script:
pip install numpy pandas xarray rioxarray dask dask-geopandas geopandas rasterio matplotlib
"""

import numpy as np
import pandas as pd
import xarray as xr
import rioxarray
import dask_geopandas as dgpd
import geopandas as gpd
import matplotlib.pyplot as plt
from shapely.geometry import mapping

# Suppress warnings for cleaner output
import warnings
warnings.filterwarnings('ignore')

# Define URLs for raster and vector data
# Raster data: Global Land Cover dataset (MODIS Land Cover Type Yearly L3 Global 500m SIN Grid)
# Vector data: Countries shapefile from Natural Earth

# For demonstration, we'll use a small raster dataset and a vector dataset

# Raster data: Elevation data from AWS Open Data
# raster_url = 'https://s3.amazonaws.com/elevation-tiles-prod/skadi/N40/N40E000.hgt.gz'
filepath = "./raster-vector/SRTM_N40E000.tif"

# Vector data: Natural Earth countries (small scale)
vector_url = 'https://naturalearth.s3.amazonaws.com/110m_cultural/ne_110m_admin_0_countries.zip'

# Load the raster data using xarray and rioxarray
# Since the raster data is in HGT format (SRTM data), we'll need to handle it appropriately

import rasterio
from rasterio.io import MemoryFile
import requests

# Download the raster data
# response = requests.get(raster_url)

# with MemoryFile(filepath) as memfile:
#     with memfile.open() as dataset:
#         # Read the dataset into an xarray DataArray
elevation = rioxarray.open_rasterio(filepath)

# Print raster metadata
print("Raster CRS:", elevation.rio.crs)
print("Raster shape:", elevation.shape)
print("Raster bounds:", elevation.rio.bounds())

# Load the vector data using dask-geopandas
# Since dask-geopandas works with partitioned data,
# we'll read the vector data into a Dask GeoDataFrame

# Download and extract the vector data
import tempfile
import zipfile

# Create a temporary directory to store the downloaded data
with tempfile.TemporaryDirectory() as tmpdir:
    # Download the vector data
    vector_response = requests.get(vector_url)
    zip_path = f"{tmpdir}/ne_110m_admin_0_countries.zip"
    with open(zip_path, 'wb') as f:
        f.write(vector_response.content)
    # Extract the zip file
    with zipfile.ZipFile(zip_path, 'r') as zip_ref:
        zip_ref.extractall(tmpdir)
    # Find the shapefile path
    import glob
    shapefile_path = glob.glob(f"{tmpdir}/*.shp")[0]
    # Read the shapefile using dask-geopandas
    countries = dgpd.read_file(shapefile_path, npartitions = 4)

# Print vector metadata
print("Vector CRS:", countries.crs)
print("Number of features:", len(countries))

# Reproject the vector data to match the raster CRS if necessary
if countries.crs != elevation.rio.crs:
    countries = countries.to_crs(elevation.rio.crs)
    print("Reprojected vector CRS:", countries.crs)

# Perform raster-vector overlay: Clip the raster data to a specific country

# For demonstration, select a country, e.g., France
country_name = 'France'
france = countries[countries['ADMIN'] == country_name].compute()

# Check if the country was found
if france.empty:
    print(f"Country {country_name} not found in the dataset.")
else:
    # Plot the country geometry
    france.plot()
    plt.title(f"{country_name} Geometry")
    plt.show()

    # Clip the raster data to the country's geometry
    # Convert the country geometry to GeoJSON-like mapping
    france_geometry = [mapping(geom) for geom in france.geometry]

    # Clip the raster using rioxarray
    elevation_clipped = elevation.rio.clip(france_geometry, france.crs)

    # Plot the clipped raster
    plt.figure(figsize=(8, 6))
    elevation_clipped.plot(cmap='terrain')
    plt.title(f"Elevation Data Clipped to {country_name}")
    plt.show()

    # Perform zonal statistics: Calculate mean elevation within the country
    from rasterstats import zonal_stats

    # Since rasterstats does not support Dask GeoDataFrames directly, convert to GeoDataFrame
    france_gdf = gpd.GeoDataFrame(france.compute())

    # Calculate zonal statistics
    zs = zonal_stats(
        france_gdf,
        elevation.data[0],
        affine=elevation.rio.transform(),
        stats="mean"
    )

    mean_elevation = zs[0]['mean']
    print(f"Mean elevation in {country_name}: {mean_elevation:.2f} meters")

    # Overlay vector data on raster plot
    fig, ax = plt.subplots(figsize=(8, 6))
    elevation_clipped.plot(ax=ax, cmap='terrain')
    france.boundary.plot(ax=ax, edgecolor='red', linewidth=2)
    plt.title(f"{country_name} Elevation with Country Boundary")
    plt.show()

