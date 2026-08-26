test_that("sf points, lines, polygons, and multiple geometries are serialized", {
  map <- local_map() |> addIndoor(crs = "simple")
  payload <- indoor_call(map)
  types <- vapply(payload$geojson$features, function(x) x$geometry$type, character(1))
  expect_true(all(c(
    "Point", "LineString", "Polygon", "MultiPoint",
    "MultiLineString", "MultiPolygon"
  ) %in% types))
  expect_equal(map$x$limits$lat, c(0, 23))
  expect_equal(map$x$limits$lng, c(0, 17))
})

test_that("bare sfc data require explicit floor values", {
  geometry <- sf::st_geometry(indoor_demo[1:2, ])
  map <- leaflet::leaflet(
    options = leaflet::leafletOptions(crs = leaflet::leafletCRS("L.CRS.Simple"))
  )
  expect_error(addIndoor(map, data = geometry, crs = "simple"), "requires explicit")
  expect_error(addIndoor(map, data = geometry, level = "0", crs = "simple"), "length 2")
  payload <- indoor_call(addIndoor(map, data = geometry, level = c("0", "1"), crs = "simple"))
  expect_identical(payload$levels, c("0", "1"))
})

test_that("GeoJSON strings, lists, and files are accepted", {
  geo <- list(
    type = "FeatureCollection",
    features = list(
      list(
        type = "Feature",
        properties = list(level = c("0", "1"), name = "Lift"),
        geometry = list(type = "Point", coordinates = list(-71.28, 46.78))
      ),
      list(
        type = "Feature",
        properties = list(level = "1", name = "Room"),
        geometry = list(
          type = "Polygon",
          coordinates = list(list(
            list(-71.281, 46.780), list(-71.280, 46.780),
            list(-71.280, 46.781), list(-71.281, 46.781),
            list(-71.281, 46.780)
          ))
        )
      )
    )
  )
  payload_list <- indoor_call(leaflet::leaflet() |> addIndoor(data = geo, label = ~name))
  expect_identical(payload_list$levels, c("0", "1"))
  expect_identical(payload_list$geojson$features[[1]]$properties$leafletIndoorLabel, "Lift")

  json <- jsonlite::toJSON(geo, auto_unbox = TRUE, null = "null")
  payload_string <- indoor_call(leaflet::leaflet() |> addIndoor(data = json))
  expect_length(payload_string$geojson$features, 2L)

  path <- tempfile(fileext = ".geojson")
  writeLines(json, path)
  payload_file <- indoor_call(leaflet::leaflet() |> addIndoor(data = path))
  expect_identical(payload_file$levels, c("0", "1"))
})

test_that("invalid GeoJSON is rejected with informative errors", {
  expect_error(
    leaflet::leaflet() |> addIndoor(data = "not json"),
    "not valid GeoJSON",
    fixed = TRUE
  )
  expect_error(
    leaflet::leaflet() |> addIndoor(data = "https://example.com/rooms.geojson"),
    "not read automatically",
    fixed = TRUE
  )
  bad <- list(type = "Feature", properties = list(level = "0"), geometry = NULL)
  expect_error(leaflet::leaflet() |> addIndoor(data = bad), "no valid geometry")
})

test_that("SpatVector input is converted when terra is installed", {
  skip_if_not_installed("terra")
  source <- indoor_demo_geo[c(1, 2, 6, 7), ]
  source$level <- c("0", "0", "1", "1")
  vector <- terra::vect(source)
  payload <- indoor_call(leaflet::leaflet() |> addIndoor(data = vector))
  expect_length(payload$geojson$features, nrow(source))
  expect_identical(payload$crs, "geographic")
})

test_that("coordinate modes prevent silent misinterpretation", {
  expect_error(
    leaflet::leaflet(indoor_demo) |> addIndoor(),
    "require a defined CRS",
    fixed = TRUE
  )
  expect_error(
    local_map(indoor_demo_geo) |> addIndoor(crs = "simple"),
    "undefined CRS",
    fixed = TRUE
  )
  expect_error(
    leaflet::leaflet(indoor_demo) |> addIndoor(crs = "simple"),
    "requires a map created with",
    fixed = TRUE
  )
  expect_error(
    local_map(indoor_demo_geo) |> addIndoor(crs = "geographic"),
    "incompatible with a map using",
    fixed = TRUE
  )
  payload <- indoor_call(geographic_map() |> addIndoor())
  expect_identical(payload$crs, "geographic")
  expect_true(all(payload$geojson$features[[1]]$geometry$coordinates[[1]][[1]] >= -180))
})

test_that("empty and unsupported geometries are rejected", {
  empty <- sf::st_sf(
    level = "0",
    geometry = sf::st_sfc(sf::st_point(), crs = sf::NA_crs_)
  )
  expect_error(
    leaflet::leaflet(empty, options = leaflet::leafletOptions(crs = leaflet::leafletCRS("L.CRS.Simple"))) |>
      addIndoor(crs = "simple"),
    "empty geometries",
    fixed = TRUE
  )
})
