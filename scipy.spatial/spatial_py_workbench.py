"""
Practice of major functions in scipy.spatial module with realistic spatial data.

This script reads data of US cities from the internet and demonstrates the use of
KDTree, ConvexHull, Delaunay triangulation, Voronoi diagram, and distance computations
from the scipy.spatial module.
"""
import numpy as np
import pandas as pd
import geopandas as gpd
import matplotlib.pyplot as plt
from scipy.spatial import KDTree, ConvexHull, Delaunay, Voronoi, voronoi_plot_2d
from scipy.spatial.distance import pdist, squareform


def load_data():
    """
    Load US city data from the internet
    """
    # Read the dataset from the internet
    url = 'https://raw.githubusercontent.com/plotly/datasets/master/us-cities-top-1k.csv'
    cities_df = pd.read_csv(url)
    print(f"File is download from {url} and loaded.")
    cities_df.head()
    return cities_df

def find_knn(gdf):
    # Extract the coordinates
    latitudes = gdf['lat']
    longitudes = gdf['lon']
    coordinates = np.column_stack((longitudes, latitudes))  # x = longitude, y = latitude

    # Build a KDTree for nearest neighbor queries
    tree = KDTree(coordinates)

    # Find the nearest neighbor for the first city (excluding itself)
    query_point = coordinates[0]
    distance, index = tree.query(query_point, k=2)  # k=2 because first match will be the point itself
    nearest_neighbor_index = index[1]  # index[0] is the point itself
    nearest_neighbor_distance = distance[1]
    print(f"The nearest neighbor to {gdf.iloc[0]['City']}, {gdf.iloc[0]['State']} is {gdf.iloc[nearest_neighbor_index]['City']}, {gdf.iloc[nearest_neighbor_index]['State']} at a distance of {nearest_neighbor_distance:.4f} degrees")

    return coordinates, tree


def find_convexhull(coords):
    # Compute the Convex Hull
    hull = ConvexHull(coords)

    # Plot the Convex Hull
    plt.figure()
    plt.plot(coords[:,0], coords[:,1], 'o', markersize=2)
    for simplex in hull.simplices:
        plt.plot(coords[simplex, 0], coords[simplex, 1], 'k-')
    plt.title('Convex Hull of US Cities')
    plt.xlabel('Longitude')
    plt.ylabel('Latitude')
    plt.show()

    return hull

def find_delaunay(coords):
    # Compute the Delaunay Triangulation
    tri = Delaunay(coords)

    # Plot the Delaunay Triangulation
    plt.figure()
    plt.triplot(coords[:,0], coords[:,1], tri.simplices)
    plt.plot(coords[:,0], coords[:,1], 'o', markersize=2)
    plt.title('Delaunay Triangulation of US Cities')
    plt.xlabel('Longitude')
    plt.ylabel('Latitude')
    plt.show()

    return tri


def find_voronoi(coords):
    # Compute the Voronoi Diagram
    vor = Voronoi(coords)

    # Plot the Voronoi Diagram
    fig = voronoi_plot_2d(vor, show_vertices=False, line_colors='orange', line_width=0.5, point_size=2)
    plt.plot(coords[:,0], coords[:,1], 'o', markersize=2)
    plt.title('Voronoi Diagram of US Cities')
    plt.xlabel('Longitude')
    plt.ylabel('Latitude')
    plt.show()
    return vor


def find_nearest(gdf, coords, rank = 10):
    # Compute the pairwise distance matrix between the first 10 cities
    first_10_coords = coords[:rank]
    dist_matrix = squareform(pdist(first_10_coords))

    print(f"Pairwise distance matrix between the first {rank} cities (in degrees):")
    city_names = gdf.iloc[:rank]['City'] + ', ' + gdf.iloc[:rank]['State']
    dist_df = pd.DataFrame(dist_matrix, columns=city_names, index=city_names)
    print(dist_df)

    return dist_df


if __name__ == "__main__":
    gdf = load_data()
    coords, tree = find_knn(gdf = gdf)
    find_convexhull(coords = coords)
    find_delaunay(coords = coords)
    nearest_df = find_nearest(gdf, coords = coords, rank = 20)
    print(nearest_df)

    gdf_p = gpd.points_from_xy(gdf.lon, gdf.lat, crs = "EPSG:4326")
    gdf_pp = gpd.GeoDataFrame(data = gdf, geometry = gdf_p, crs = "EPSG:4326")
    gdf_rep = gdf_pp.to_crs("EPSG:5070")
    gdf_rep.lon = gdf_rep.geometry.x
    gdf_rep.lat = gdf_rep.geometry.y
    coords_rep, tree_rep = find_knn(gdf = gdf_rep)
    nearest_df_rep = find_nearest(gdf_rep, coords = coords_rep, rank = 20)
    print(nearest_df_rep)
