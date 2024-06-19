library(dbplyr)
library(DBI)
library(duckdb)
# takes a long time
library(duckplyr)
library(terra)


duckplyr::as_duckplyr_df()

con <- duckdb::duckdb("/home/felix/Documents/spatial_workbench.duckdb")
con <- duckdb::dbConnect(con)

dbListTables(con)
duckdb::dbListTables(con)

# does not work
check <- vect(con, layer = "tract10")

# work but geometry is not read properly
check <- sf::st_read(con, layer = "tract10")
