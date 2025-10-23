# -*- coding: utf-8 -*-
"""
Rusterize Workflow
====================
"""

from rusterize import rusterize
import geopandas as gpd
from glob import glob

# gdf = <import/modify dataframe as needed>
basepath = "/mnt/d/swm-work"
full_pattern = f"{basepath}/*/*/bnd_sigungu_00_*_4Q.shp"
files = glob(full_pattern)
gdf = gpd.read_file(files[2])
gdf['sggcd'] = gdf['SIGUNGU_CD'].astype(int)

# rusterize
gdf_rasterized = rusterize(
    gdf,
    like=None,
    res=(100, 100),
    #out_shape=(10, 10),
    #extent=(0, 10, 10, 20),
    field="sggcd",
    by=None,
    burn=None,
    fun="sum",
    background=0,
    dtype="uint16"
)

gdf_rasterized = gdf_rasterized.squeeze()
gdf_rasterized.plot.imshow()

from matplotlib import pyplot as plt
plt.show()

