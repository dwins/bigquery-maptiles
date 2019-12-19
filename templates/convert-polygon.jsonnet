local rows = import 'results.json';
{
  type: "FeatureCollection",
  features: [
    {
      type: "Feature",
      geometry: {
        type: "Polygon",
        // TODO: eliminate this by using a custom process to run the query and reformat results.
        points: std.join(
          ' ',
          [
            '%s,%s' % coords
          for coords in row.geom
          ]
        ),
      },
      properties: {
        name: row.name,
        geo_id: row.geo_id,
        year_month: row.year_month,
        count_ips: std.parseInt(row.count_ips),
        count_tests: std.parseInt(row.count_tests),
        download_Mbps: std.parseInt(row.download_Mbps) / 1000,
        upload_Mbps: std.parseInt(row.upload_Mbps) / 1000,
      }
    }
    for row in rows
  ]
}