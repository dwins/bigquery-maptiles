#!/bin/bash

set -eux

PROJECT=${1:?Please provide a GCP project for tile upload}

# TODO: replace use of bq with a custom Go binary that runs the query and
# outputs the right format. Also open an HTTP port for Cloud Run.

# Make a temporary table using a schema definition based on the expected query output fields 
bq mk --table --expiration 3600 --description "temp table for bq2maptiles process" \
	mlab-sandbox:critzo.nc_counties schemas/nc_counties_spjoin.json

# Run bq query with generous row limit. Write results to temp table created above.
# NOTE: bq converts all types to strings, including ints and floats.
cat queries/query-bqsj.sql | bq --project_id measurement-lab query \
	--allow_large_results --destination_table mlab-sandbox:critzo.nc_counties \
    --replace --use_legacy_sql=false --max_rows=4000000 

# Extract contents of the temp table to a gcs storage location, using wildcard sharding
# to accomodate large results.
bq extract --destination_format CSV 'mlab-sandbox:critzo.nc_counties' \
	gs://bigquery-maptiles-mlab-sandbox/csv/nc_counties_*.csv

# Merge sharded results into one CSV
gsutil compose gs://bigquery-maptiles-mlab-sandbox/csv/nc_counties_* \
	gs://bigquery-maptiles-mlab-sandbox/csv/nc_counties_merged.csv

# Download the merged CSV locally to use to generate tiles.
gsutil cp gs://bigquery-maptiles-mlab-sandbox/csv/nc_counties_merged.csv maptiles/results.csv

# Cleanup the files on GCS because we don't need them there anymore.
#sutil rm gs://bigquery-maptiles-mlab-sandbox/csv/nc_counties_*

# For geo-joining using a shapefile and results using ogr2ogr
#ogr2ogr -f GeoJSON nc_2018_county.geojson geo/north_carolina_county_cb2018_500k.shp
#ogr2ogr -f GeoJSON mlab_nc_2018_county.geojson results.csv -sql \
#	"SELECT * FROM results c JOIN 'geo/north_carolina_county_cb2018_500k.shp'.north_carolina_county_cb2018_500k s on c.geo_id = s.GEOID"

# ogr2ogr+tippecanoe to handle the csv > tiles
#ogr2ogr -f GeoJSON /dev/stdout \
#  -oo KEEP_GEOM_COLUMNS=no \
#  results.csv | \
#  tippecanoe -o maptiles/mlab_nc_2018_county.mbtiles \
#  -l mlab_nc_2018_county /dev/stdin -zg
#  tippecanoe -e maptiles/nc_counties -f -l nc_counties /dev/stdin -z6 \
#  --simplification=10 --detect-shared-borders \
#  --coalesce-densest-as-needed --no-tile-compression

#upload to cloud storage box
#gsutil -m -h 'Cache-Control:private, max-age=0, no-transform' \
#  cp -r maptiles/* gs://bigquery-maptiles-${PROJECT}/

# NOTE: if the html and tiles are served from different domains we'll need to
# apply a CORS policy to GCS.
