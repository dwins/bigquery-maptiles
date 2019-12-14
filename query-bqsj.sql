#standardSQL
WITH counties AS (
  SELECT
    county_name AS name,
    county_geom AS WKT,
    geo_id as geo_id
  FROM
    `bigquery-public-data.geo_us_boundaries.counties`
),
mlab_dl AS (
  SELECT
    tests.*,
    CONCAT(CAST(EXTRACT(YEAR FROM partition_date) AS STRING),"-",CAST(EXTRACT(MONTH FROM partition_date) AS STRING)) AS year_month,
    counties.geo_id AS geo_id,
    counties.name AS county_name,
    counties.WKT AS WKT
  FROM
    `measurement-lab.ndt.downloads` tests
    JOIN counties ON ST_WITHIN(
      ST_GeogPoint(
        connection_spec.client_geolocation.longitude,
        connection_spec.client_geolocation.latitude
      ), WKT
    )
  WHERE
    connection_spec.server_geolocation.country_name = "United States"
    AND (partition_date BETWEEN '2014-07-01' AND '2019-09-30')
),
mlab_ul AS (
  SELECT
    tests.*,
    counties.geo_id AS geo_id,
    counties.name AS county_name,
    counties.WKT AS WKT
  FROM
    `measurement-lab.ndt.uploads` tests
    JOIN counties ON ST_WITHIN(
      ST_GeogPoint(
        connection_spec.client_geolocation.longitude,
        connection_spec.client_geolocation.latitude
      ),
      WKT
    )
  WHERE
    connection_spec.server_geolocation.country_name = "United States"
    AND (partition_date BETWEEN '2014-07-01' AND '2019-09-30'
    )
),
dl_agg AS (
  SELECT
  mlab_dl.geo_id,
  county_name,
  CONCAT(CAST(EXTRACT(YEAR FROM partition_date) AS STRING),"-",CAST(EXTRACT(MONTH FROM partition_date) AS STRING)) AS year_month,
  MIN(8 * (SAFE_DIVIDE(web100_log_entry.snap.HCThruOctetsAcked,
    web100_log_entry.snap.SndLimTimeRwin +
    web100_log_entry.snap.SndLimTimeCwnd +
    web100_log_entry.snap.SndLimTimeSnd))) AS MIN_download_Mbps,
  APPROX_QUANTILES(
    8 * SAFE_DIVIDE(
      web100_log_entry.snap.HCThruOctetsAcked, (
      web100_log_entry.snap.SndLimTimeRwin + web100_log_entry.snap.SndLimTimeCwnd +
      web100_log_entry.snap.SndLimTimeSnd)
    ), 101) [SAFE_ORDINAL(26)] AS LOWER_QUARTILE_download_Mbps,
  APPROX_QUANTILES(
    8 * SAFE_DIVIDE(
      web100_log_entry.snap.HCThruOctetsAcked, (
      web100_log_entry.snap.SndLimTimeRwin + web100_log_entry.snap.SndLimTimeCwnd +
      web100_log_entry.snap.SndLimTimeSnd)
    ), 101) [SAFE_ORDINAL(51)] AS MED_download_Mbps,
  APPROX_QUANTILES(
    8 * SAFE_DIVIDE(
      web100_log_entry.snap.HCThruOctetsAcked, (
      web100_log_entry.snap.SndLimTimeRwin + web100_log_entry.snap.SndLimTimeCwnd +
      web100_log_entry.snap.SndLimTimeSnd)
    ), 101) [SAFE_ORDINAL(76)] AS UPPER_QUARTILE_download_Mbps,
  MAX(8 * (SAFE_DIVIDE(web100_log_entry.snap.HCThruOctetsAcked,
    web100_log_entry.snap.SndLimTimeRwin +
    web100_log_entry.snap.SndLimTimeCwnd +
    web100_log_entry.snap.SndLimTimeSnd))) AS MAX_download_Mbps,  
  AVG(8 * (SAFE_DIVIDE(web100_log_entry.snap.HCThruOctetsAcked, 
    web100_log_entry.snap.SndLimTimeRwin +
    web100_log_entry.snap.SndLimTimeCwnd +
    web100_log_entry.snap.SndLimTimeSnd))) AS AVG_download_Mbps,
  APPROX_QUANTILES(
    CAST(web100_log_entry.snap.MinRTT AS FLOAT64), 101) [ORDINAL(51)] as MED_min_rtt
  FROM mlab_dl JOIN counties ON mlab_dl.county_name = counties.name
  GROUP BY geo_id, county_name, year_month
),
ul_agg AS (
  SELECT
  mlab_ul.geo_id,
  county_name,
  CONCAT(CAST(EXTRACT(YEAR FROM partition_date) AS STRING),"-",CAST(EXTRACT(MONTH FROM partition_date) AS STRING)) AS year_month,
  MIN(8 * SAFE_DIVIDE(web100_log_entry.snap.HCThruOctetsReceived,
      (web100_log_entry.snap.Duration))) AS MIN_upload_Mbps,
  APPROX_QUANTILES(
    8 * SAFE_DIVIDE(web100_log_entry.snap.HCThruOctetsReceived,
      (web100_log_entry.snap.Duration)),101) [SAFE_ORDINAL(26)] AS LOWER_QUARTILE_upload_Mbps,
  APPROX_QUANTILES(
    8 * SAFE_DIVIDE(web100_log_entry.snap.HCThruOctetsReceived,
      (web100_log_entry.snap.Duration)),101) [SAFE_ORDINAL(51)] AS MED_upload_Mbps,
  APPROX_QUANTILES(
    8 * SAFE_DIVIDE(web100_log_entry.snap.HCThruOctetsReceived,
      (web100_log_entry.snap.Duration)),101) [SAFE_ORDINAL(76)] AS UPPER_QUARTILE_upload_Mbps,     
  MAX(8 * SAFE_DIVIDE(web100_log_entry.snap.HCThruOctetsReceived,
      (web100_log_entry.snap.Duration))) AS MAX_upload_Mbps,   
  AVG(8 * (web100_log_entry.snap.HCThruOctetsReceived/web100_log_entry.snap.Duration)) 
    AS AVG_upload_Mbps
  FROM mlab_ul JOIN counties ON mlab_ul.county_name = counties.name
  GROUP BY geo_id, county_name, year_month
),
summary AS (
  SELECT
    geo_id AS sum_geoid, county_name, year_month, MIN_download_Mbps, LOWER_QUARTILE_download_Mbps, MED_download_Mbps,
    UPPER_QUARTILE_download_Mbps, MAX_download_Mbps, AVG_download_Mbps, MED_min_rtt, MIN_upload_Mbps, LOWER_QUARTILE_upload_Mbps, 
    MED_upload_Mbps, UPPER_QUARTILE_upload_Mbps, MAX_upload_Mbps, AVG_upload_Mbps
  FROM
  dl_agg JOIN ul_agg USING (geo_id, county_name, year_month)
)
SELECT * FROM summary JOIN counties ON summary.sum_geoid = counties.geo_id