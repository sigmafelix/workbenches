using ArchGDAL
using Shapefile
using DataFrames
using HTTP
using ZipFile
# using IOStreams

# Function to download and extract files
function download_and_extract(url::String, download_path::String, extract_path::String)
    # Download the file from the internet
    println("Downloading: $url")
    response = HTTP.get(url)
    open(download_path, "w") do f
        write(f, response.body)
    end
    
    # If the file is a ZIP, extract it
    if endswith(download_path, ".zip")
        println("Extracting ZIP file")
        ZipFile.extract(download_path, extract_path)
    end
end

# Download example raster and shapefile
raster_url = "https://prd-tnm.s3.amazonaws.com/StagedProducts/Elevation/1/TIFF/n38w077/USGS_1_n38w077.tif"
vector_url = "https://www2.census.gov/geo/tiger/2018/TRACT/2018_36_tract.zip"

# Define file paths
raster_path = "example_raster.tif"
vector_zip_path = "example_vector.zip"
vector_shapefile_path = "example_vector/2018_36_tract.shp"

# Download and extract files
download_and_extract(raster_url, raster_path, "")
download_and_extract(vector_url, vector_zip_path, "example_vector")

# Function to extract raster statistics for a given polygon
function extract_raster_summary(raster, vector_layer)
    # Read the raster's spatial reference system (SRS) and set up the coordinates
    raster_srs = ArchGDAL.getrasterprojection(raster)

    # Initialize a dictionary to store the statistics
    stats = Dict("mean" => NaN, "std" => NaN, "sum" => NaN, "count" => 0)

    # Iterate over each polygon in the vector dataset
    for feature in vector_layer
        # Extract the geometry (polygon)
        geom = Shapefile.getgeometry(feature)

        # Mask the raster using the vector polygon (i.e., extract raster values within the polygon)
        raster_values = ArchGDAL.rasterize(raster, geom)

        if length(raster_values) > 0
            # Compute the statistics for the raster values within this polygon
            stats["mean"] = mean(raster_values)
            stats["std"] = std(raster_values)
            stats["sum"] = sum(raster_values)
            stats["count"] = length(raster_values)
        end
    end

    return stats
end

# Load the raster (multilayer) data
raster = ArchGDAL.read(raster_path)

# Load the vector (polygon) data
vector = Shapefile.Table(vector_shapefile_path)

# Create a DataFrame to store the summary statistics for each polygon
summary_df = DataFrame(Polygon_ID = Int[], Mean = Float64[], StdDev = Float64[], Sum = Float64[], Count = Int[])

# Loop through each polygon feature in the shapefile
for (i, feature) in enumerate(vector)
    # Extract summary statistics for the current polygon
    stats = extract_raster_summary(raster, feature)

    # Append the results to the DataFrame
    push!(summary_df, (Polygon_ID=i, Mean=stats["mean"], StdDev=stats["std"], Sum=stats["sum"], Count=stats["count"]))
end

# Print out the summary
println(summary_df)
