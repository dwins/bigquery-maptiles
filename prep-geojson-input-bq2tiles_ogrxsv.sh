#!/bin/bash

set -eux

PROJECT=${1:?Please provide a GCP project for tile upload}

# TODO: replace use of bq with a custom Go binary that runs the query and
# outputs the right format. Also open an HTTP port for Cloud Run.

# Run bq query with generous row limit.
# NOTE: bq converts all types to strings, including ints and floats. 
cat query.sql | bq --project measurement-lab query --format=csv \
    --nouse_legacy_sql --max_rows=4000000 > results.csv

#csvkit for telling ogr&tippecanoe what the field types are
csvcut -C 'WKT' results.csv |  \
  csvstat --csv |  \
  csvcut -c 'type' |  \
  tail -n +2 \
  sed 's/.*/"&"/' | \
  sed 's/Text/String/g' | \
  sed 's/Boolean/String/g' | \
  sed 's/Number/Real/g' | \
  tr '\n' , > results.csvt
$ echo '"WKT"' >> results.csvt

#ogr2ogr+tippecanoe to handle the csv > tiles
ogr2ogr -f GeoJSON /dev/stdout \
  -oo KEEP_GEOM_COLUMNS=no \
  results.csv | \
  tippecanoe -e example -f -l example /dev/stdin -z6 \
  --simplification=10 --detect-shared-borders \
  --coalesce-densest-as-needed --no-tile-compression

#upload to cloud storage box
gsutil -m -h 'Cache-Control:private, max-age=0, no-transform' \
  cp -r example.html example gs://bigquery-maptiles-${PROJECT}/

# NOTE: if the html and tiles are served from different domains we'll need to
# apply a CORS policy to GCS.
