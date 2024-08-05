INSTALL spatial;
LOAD spatial;
-- CREATE TABLE ecoregion3 AS SELECT * FROM ST_Read("/home/felix/Documents/us_eco_l3_state_boundaries/us_eco_l3_state_boundaries.shp");
-- SELECT * FROM ecoregion3 LIMIT 5;

-- CREATE TABLE tract10 AS SELECT * FROM ST_Read("/home/felix/Documents/USCensusArea/US_tract_2010.shp");
SELECT * FROM ecoregion3 LIMIT 5;


-- SELECT ecoregion3.*, tract10.*, ST_Area(geom) as int_area
-- FROM ecoregion3, tract10
-- WHERE ST_Intersection(ecoregion3.geometry, tract10.geometry);

-- Query to get intersections and calculate areas
WITH intersected_geometries AS (
    SELECT
        p1.pid AS id1,
        p2.pid AS id2,
        ST_Intersection(p1.geometry, p2.geometry) AS intersection_geom
    FROM
        st_transform(tract10, 'EPSG:4269', 'EPSG:5070') p1,
        st_transform(ecoregion3, 'EPSG:2163', 'EPSG:5070') p2
    WHERE
        ST_Intersects(p1, p2)
)
SELECT
    id1,
    id2,
    ST_Area(intersection_geom) AS intersection_area_sqm
FROM
    intersected_geometries
WHERE
    intersection_geom IS NOT NULL;