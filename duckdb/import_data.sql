-- import data
CREATE TABLE air AS 
SELECT TMSID, date, PM10, PM25, sp, aod, blh, dsm
FROM "df_feat_calc_daily_full.parquet"
WHERE date <= '2015-02-28'
ORDER BY date DESC;