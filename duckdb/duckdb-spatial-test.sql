INSTALL spatial;
CREATE TABLE ecoregion3 AS SELECT * FROM ST_Read("/Users/songi2/Downloads/us_eco_l3_state_boundaries/us_eco_l3_state_boundaries.shp");
SELECT * FROM ecoregion3 LIMIT 5;

