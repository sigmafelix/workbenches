SELECT 
  TMSID,
  DATE_TRUNC('month', "date") AS yearmonth,
  AVG(PM10) AS avg_pm10,
  AVG(PM25) AS avg_pm25,
  AVG(aod) AS avg_aod,
  AVG(blh) AS avg_blh,
  AVG(dsm) AS avg_dsm
FROM
  air
WHERE
  len(TMSID) = 6
GROUP BY
  TMSID,
  yearmonth
HAVING
  NOT isnan(avg_pm10)
ORDER BY
  TMSID,
  yearmonth;

-- 