test_that("the real-world Louvre example has traceable geographic data", {
  room_file <- system.file(
    "examples", "real", "louvre-rooms.geojson",
    package = "leaflet.indoor"
  )
  attribution_file <- system.file(
    "examples", "real", "ATTRIBUTION.md",
    package = "leaflet.indoor"
  )
  expect_true(file.exists(room_file))
  expect_true(file.exists(attribution_file))

  rooms <- sf::st_read(room_file, quiet = TRUE)
  expect_s3_class(rooms, "sf")
  expect_equal(nrow(rooms), 135L)
  expect_identical(sort(unique(rooms$level)), c("-2", "0", "1"))
  expect_identical(as.integer(table(rooms$level)), c(8L, 51L, 76L))
  expect_true(all(sf::st_is_valid(rooms)))
  expect_identical(sf::st_crs(rooms)$epsg, 4326L)
  expect_true("Salle des Caryatides" %in% rooms$name)
  expect_true(all(startsWith(rooms$source_url, "https://www.openstreetmap.org/way/")))
})

test_that("the Louvre photos are reproducible and remain paired", {
  photo_directory <- system.file(
    "examples", "real", "photos",
    package = "leaflet.indoor"
  )
  photo_paths <- file.path(photo_directory, c(
    "louvre-caryatides-main.jpg",
    "louvre-caryatides-reopening.jpg"
  ))
  expect_true(all(file.exists(photo_paths)))
  expect_identical(
    unname(tools::md5sum(photo_paths)),
    c("489575dc45072fee2cba3658ba808c68", "68dc4311bf9fc7cb014ac15041a6a2f0")
  )

  photos <- indoorPhotoCatalog(
    layerId = rep("osm-way-394887893", 2),
    src = photo_paths,
    caption = c("Wilfredor, CC0", "Tangopaso, public domain")
  )
  expect_identical(photos$layerId, rep("osm-way-394887893", 2))
  expect_true(all(startsWith(photos$src, "data:image/jpeg;base64,")))
  expect_identical(photos$caption, c("Wilfredor, CC0", "Tangopaso, public domain"))
})

test_that("the installed real-world example returns a Leaflet widget", {
  example_file <- system.file(
    "examples", "louvre-photo-carousel.R",
    package = "leaflet.indoor"
  )
  expect_true(file.exists(example_file))
  result <- suppressWarnings(
    source(example_file, local = new.env(parent = globalenv()))
  )
  expect_s3_class(result$value, "leaflet")

  payload <- indoor_call(result$value)
  expect_identical(payload$levels, c("-2", "0", "1"))
  room_index <- which(vapply(
    payload$geojson$features,
    function(feature) {
      identical(
        feature$properties$leafletIndoorLayerId,
        "osm-way-394887893"
      )
    },
    logical(1)
  ))
  expect_length(room_index, 1L)
  expect_length(
    payload$geojson$features[[room_index]]$properties$leafletIndoorPhotos,
    2L
  )
})
