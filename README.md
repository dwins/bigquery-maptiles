# bigquery-maptiles

Build container:

```sh
docker build -f Dockerfile_ogr_csvkit -t bigquery-maptiles .
```

Generate input data:

```sh
docker run -e PROJECT=mlab-sandbox -v $PWD/geo:/geo \
  -v $PWD/maptiles:/maptiles -v $PWD/queries:/queries \
  -v $PWD/schemas:/schemas -v $PWD/scripts:/scripts \
  -v $PWD/templates:/templates -v /home/critzo/.config/gcloud:/root/.config/gcloud \
  -it bigquery-maptiles scripts/prep-geojson-input-bq2tiles_ogr_csvkit.sh mlab-sandbox
```

NOTE: if the html and tiles are served from different domains we'll need to
apply a CORS policy to GCS.

## CORS

NOTE: may not be needed if served from an iframe.

* create a GCS bucket for the tile data.
* set defacl on bucket:

  ```sh
  gsutil defacl set public-read gs://bigquery-maptiles-mlab-sandbox/
  ```

* set cors policy on bucket, so requests evaluate `Access-Control-Allow-Origin`
  headers correctly.

  ```sh
  gsutil cors set cors.json  gs://bigquery-maptiles-mlab-sandbox
  ```

  `cors.json` contains, a project-specific origin (origin URLs are examples):
  ```
  [
    {
      "origin": ["http://localhost:4000", "https://grafana.mlab-sandbox.measurementlab.net"],
      "responseHeader": ["Content-Type"],
      "method": ["GET", "HEAD", "DELETE"],
      "maxAgeSeconds": 3600
    }
  ]
  ```
