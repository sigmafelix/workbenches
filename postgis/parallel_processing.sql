SET max_parallel_workers = 8;
SET max_parallel_workers_per_gather = 4;

-- buffer statistics
SELECT
    g.geom AS sites_buffer,
    r.rid,
    (ST_SummaryStats(ST_Clip(r.rast, ST_Buffer(g.geom, 10000)))).*
FROM
    epa_sites g
JOIN
    elevation r ON ST_Intersects(r.rast, ST_Buffer(g.geom, 10000))
GROUP BY
    g.geom, r.rid;

-- proportion
CREATE TABLE nlcd_proportions_10k AS
SELECT
    b.geom AS sites_buffer,
    c.category,
    COUNT(*) AS cell_count,
    COUNT(*) / ST_NumCells(ST_Clip(c.rast, b.geom))::float AS proportion
FROM
    buffered_sites b
JOIN
    nlcd_2019 c ON ST_Intersects(c.rast, b.geom)
GROUP BY
    b.geom, c.category;
