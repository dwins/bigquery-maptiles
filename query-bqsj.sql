#standardSQL
WITH counties AS (
  SELECT
    county_name AS name,
    county_geom AS geom,
    geo_id as geo_id
  FROM
    `bigquery-public-data.geo_us_boundaries.counties`
),
dl AS (
  SELECT
    tests.*,
    CONCAT(CAST(EXTRACT(YEAR FROM partition_date) AS STRING),"-",CAST(EXTRACT(MONTH FROM partition_date) AS STRING)) AS year_month,
    counties.geo_id AS geo_id
  FROM
    `measurement-lab.ndt.downloads` tests
    JOIN counties ON ST_WITHIN(
      ST_GeogPoint(
        connection_spec.client_geolocation.longitude,
        connection_spec.client_geolocation.latitude
      ),
      geom
    )
  WHERE
    connection_spec.server_geolocation.country_name = "United States"
    AND (
      partition_date BETWEEN '2014-07-01'
      AND '2019-09-30'
    )
),
ul AS (
  SELECT
    tests.*,
    CONCAT(CAST(EXTRACT(YEAR FROM partition_date) AS STRING),"-",CAST(EXTRACT(MONTH FROM partition_date) AS STRING)) AS year_month,
    counties.geo_id AS geo_id
  FROM
    `measurement-lab.ndt.uploads` tests
    JOIN counties ON ST_WITHIN(
      ST_GeogPoint(
        connection_spec.client_geolocation.longitude,
        connection_spec.client_geolocation.latitude
      ),
      geom
    )
  WHERE
    connection_spec.server_geolocation.country_name = "United States"
    AND (
      partition_date BETWEEN '2014-07-01'
      AND '2019-09-30'
    )
)
SELECT
  ARRAY(
    SELECT AS STRUCT
      year_month,
      COUNT(test_id) AS count_tests,
      COUNT(DISTINCT connection_spec.client_ip) AS count_ips,
      APPROX_QUANTILES(
        8 * SAFE_DIVIDE(
          web100_log_entry.snap.HCThruOctetsAcked,
          (
            web100_log_entry.snap.SndLimTimeRwin + web100_log_entry.snap.SndLimTimeCwnd + web100_log_entry.snap.SndLimTimeSnd
          )
        ),
        101
      ) [SAFE_ORDINAL(51)] AS download_Mbps,
      APPROX_QUANTILES(
        CAST(web100_log_entry.snap.MinRTT AS FLOAT64),
        101
      ) [ORDINAL(51)] as min_rtt
    FROM
      dl
    WHERE dl.geo_id = counties.geo_id
    GROUP BY
      year_month
  ) dl,
  ARRAY(
    SELECT AS STRUCT
      year_month,
      COUNT(test_id) AS count_tests,
      COUNT(DISTINCT connection_spec.client_ip) AS count_ips,
      APPROX_QUANTILES(
        8 * SAFE_DIVIDE(
          web100_log_entry.snap.HCThruOctetsReceived,
          (
            web100_log_entry.snap.Duration
          )
        ),
        101
      ) [SAFE_ORDINAL(51)] AS upload_Mbps
    FROM
      ul
    WHERE
      ul.geo_id = counties.geo_id
    GROUP BY
      year_month
  ) AS ul,
  counties.geo_id,
  counties.name,
  counties.geom
FROM
  counties