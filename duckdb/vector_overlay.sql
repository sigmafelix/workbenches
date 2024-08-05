INSTALL spatial;
CREATE TABLE ecoregion3 AS SELECT * FROM ST_Read("/home/felix/us_eco_l3_state_boundaries/us_eco_l3_state_boundaries.shp");
SELECT * FROM ecoregion3 LIMIT 5;

CREATE TABLE tract10 AS SELECT * FROM ST_Read("/home/felix/USCensusArea/US_tract_2010.shp");
SELECT * FROM ecoregion3 LIMIT 5;
