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
  expect_true(all(c(
    "Salle des Caryatides",
    "Salle de la Vénus de Milo",
    "Galerie d'Apollon"
  ) %in% rooms$name))
  expect_true(all(startsWith(rooms$source_url, "https://www.openstreetmap.org/way/")))
})

test_that("the Louvre photos are reproducible and remain paired", {
  photo_directory <- system.file(
    "examples", "real", "photos",
    package = "leaflet.indoor"
  )
  photo_paths <- file.path(photo_directory, c(
    "louvre-caryatides-main.jpg",
    "louvre-caryatides-reopening.jpg",
    "louvre-venus-room.jpg",
    "louvre-apollon-main.jpg",
    "louvre-apollon-ceiling.jpg"
  ))
  expect_true(all(file.exists(photo_paths)))
  expect_identical(
    unname(tools::md5sum(photo_paths)),
    c(
      "489575dc45072fee2cba3658ba808c68",
      "68dc4311bf9fc7cb014ac15041a6a2f0",
      "87f974d7db9a3b80f237a49dbcabace1",
      "cb82ff412d471c2e28226c88f6cb2d41",
      "0961c756d20d0b4ac7e43959ffeefa35"
    )
  )

  photo_ids <- c(
    rep("osm-way-394887893", 2),
    "osm-way-453817508",
    rep("osm-way-367790015", 2)
  )
  photos <- indoorPhotoCatalog(
    layerId = photo_ids,
    src = photo_paths,
    caption = c(
      "Wilfredor, CC0",
      "Tangopaso, public domain",
      "Shonagon, CC0",
      "Wilfredor, CC0",
      "Gary Todd, CC0"
    )
  )
  expect_identical(photos$layerId, photo_ids)
  expect_true(all(startsWith(photos$src, "data:image/jpeg;base64,")))
  expect_identical(
    as.integer(table(factor(photos$layerId, levels = unique(photo_ids)))),
    c(2L, 1L, 2L)
  )
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
  expected_counts <- c(
    "osm-way-394887893" = 2L,
    "osm-way-453817508" = 1L,
    "osm-way-367790015" = 2L
  )
  for (room_id in names(expected_counts)) {
    room_index <- which(vapply(
      payload$geojson$features,
      function(feature) identical(feature$properties$leafletIndoorLayerId, room_id),
      logical(1)
    ))
    expect_length(room_index, 1L)
    expect_length(
      payload$geojson$features[[room_index]]$properties$leafletIndoorPhotos,
      unname(expected_counts[[room_id]])
    )
  }
})
