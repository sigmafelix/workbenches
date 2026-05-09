WITH 

air_res AS (
    SELECT 
        TMSID,
        DATE_TRUNC('week', date_a) AS date_week,
        AVG(PM10) AS avg_pm10,
        AVG(PM25) AS avg_pm25,
        AVG(aod)  AS avg_aod,
        AVG(blh)  AS avg_blh,
        AVG(dsm)  AS avg_dsm
    FROM air
    WHERE len(TMSID) = 6
    GROUP BY
        TMSID,
        DATE_TRUNC('week', date_a)
    HAVING
        NOT isnan(AVG(PM10))
),

lagged AS (
    SELECT
        TMSID,
        date_week,
        avg_pm10,
        avg_pm25,
        avg_pm10 - LAG(avg_pm10) OVER (PARTITION BY TMSID ORDER BY date_week) AS d_pm10,
        avg_pm25 - LAG(avg_pm25) OVER (PARTITION BY TMSID ORDER BY date_week) AS d_pm25,
        avg_aod  - LAG(avg_aod)  OVER (PARTITION BY TMSID ORDER BY date_week) AS d_aod,
        avg_blh  - LAG(avg_blh)  OVER (PARTITION BY TMSID ORDER BY date_week) AS d_blh
    FROM air_res
),

-- Strip NULLs (from LAG boundary) AND NaNs (from data) before any aggregation
lagged_clean AS (
    SELECT *
    FROM lagged
    WHERE
        -- NULL guard (LAG boundary rows)
        d_pm10    IS NOT NULL AND d_pm25    IS NOT NULL AND
        d_aod     IS NOT NULL AND d_blh     IS NOT NULL AND
        -- NaN guard (propagated from source data)
        NOT isnan(d_pm10)    AND NOT isnan(d_pm25)    AND
        NOT isnan(d_aod)     AND NOT isnan(d_blh)     AND
        NOT isnan(avg_pm10)  AND NOT isnan(avg_pm25)
),

variance_check AS (
    SELECT
        TMSID,
        STDDEV_POP(d_pm10)   AS sd_d_pm10,
        STDDEV_POP(avg_pm10) AS sd_avg_pm10,
        STDDEV_POP(d_pm25)   AS sd_d_pm25,
        STDDEV_POP(avg_pm25) AS sd_avg_pm25
    FROM lagged_clean
    GROUP BY TMSID
    HAVING
        -- NULL guard (TMSID had no valid rows after NaN strip)
        sd_d_pm10   IS NOT NULL AND sd_avg_pm10 IS NOT NULL AND
        sd_d_pm25   IS NOT NULL AND sd_avg_pm25 IS NOT NULL AND
        -- NaN guard (should not occur after stripping, but defensive)
        NOT isnan(sd_d_pm10)   AND NOT isnan(sd_avg_pm10) AND
        NOT isnan(sd_d_pm25)   AND NOT isnan(sd_avg_pm25) AND
        -- Zero-variance guard
        sd_d_pm10   > 0 AND sd_avg_pm10 > 0 AND
        sd_d_pm25   > 0 AND sd_avg_pm25 > 0
),

corr_by_id AS (
    SELECT
        lc.TMSID,
        COUNT(*)               AS n_obs,
        CORR(d_pm10, avg_pm10) AS cor_pm10,
        CORR(d_pm25, avg_pm25) AS cor_pm25
    FROM lagged_clean lc
    INNER JOIN variance_check vc USING (TMSID)
    GROUP BY lc.TMSID
)

SELECT *
FROM corr_by_id
-- WHERE n_obs >= 12
ORDER BY TMSID;