test_that("comments keep text and provenance paired in room and row order", {
  comments <- indoorCommentCatalog(
    c("feature-01", "feature-02", "feature-01"),
    c("First account", "Other room", "Second account"),
    author = c("A", "B", "C"),
    date = "2026-10-06",
    source = c("https://example.org/a", "", "https://example.org/c")
  )
  payload <- indoor_call(local_map(indoor_demo[1:3, ]) |>
    addIndoor(layerId = ~feature_id, comments = comments, crs = "simple"))
  first <- payload$geojson$features[[1]]$properties$leafletIndoorComments
  expect_identical(vapply(first, `[[`, character(1), "text"), c("First account", "Second account"))
  expect_identical(vapply(first, `[[`, character(1), "author"), c("A", "C"))
  expect_identical(first[[2]]$source, "https://example.org/c")
  expect_null(payload$geojson$features[[3]]$properties$leafletIndoorComments)
  expect_equal(nrow(indoorCommentCatalog(character(), character())), 0L)
  expect_error(indoorCommentCatalog(c("a", "b"), c("A", "B", "C")), "length 1 or 3")
  expect_error(indoorCommentCatalog("a", NA_character_), "missing or empty")
  expect_error(indoorCommentCatalog("a", ""), "missing or empty")
  expect_error(normalize_comment_catalog(data.frame(layerId = "a")), "text")
})

test_that("comment sources cannot contain executable or malformed URL schemes", {
  for (source in c("javascript:alert(1)", "data:text/html,test", "//example.org", "https://", "https://example.org\n")) {
    expect_error(indoorCommentCatalog("a", "Text", source = source), "HTTP\\(S\\)")
  }
  expect_no_error(indoorCommentCatalog("a", "Text", source = "https://example.org/path?q=1#entry"))
})

test_that("comments require identifiers and support plain data frames and proxies", {
  comments <- data.frame(layerId = "feature-01", text = "A comment")
  expect_error(local_map() |> addIndoor(comments = comments, crs = "simple"), "requires non-missing")
  comments$layerId <- "absent"
  expect_error(local_map() |> addIndoor(layerId = ~feature_id, comments = comments, crs = "simple"), "not present")
  comments$layerId <- "feature-01"
  proxy <- fake_proxy(indoor_demo)
  expect_no_error(addIndoor(proxy$proxy, layerId = ~feature_id, comments = comments, crs = "simple"))
  payload <- proxy$captured$messages[[1]]$message$calls[[1]]$args[[1]]
  expect_identical(payload$geojson$features[[1]]$properties$leafletIndoorComments[[1]]$text, "A comment")
})

test_that("icons have safe customization and localizable labels", {
  options <- indoorCommentOptions(icon = "\u2605", background_color = "#123",
    marker_label = "Lire les témoignages", popup_label = "Témoignages", source_label = "Source")
  expect_s3_class(options, "leaflet_indoor_comment_options")
  expect_identical(options$markerLabel, "Lire les témoignages")
  expect_error(indoorCommentOptions(icon = ""), "`icon`")
  expect_error(indoorCommentOptions(color = "url(example.org)"), "hexadecimal")
  expect_error(indoorCommentOptions(show = NA), "TRUE or FALSE")
  expect_error(indoorCommentOptions(size = Inf), "finite number")
  expect_error(indoorCommentOptions(min_size = 40), "must not exceed")
  expect_error(indoorCommentOptions(fit_to_room = NA), "TRUE or FALSE")
  expect_identical(indoorCommentOptions(size = 28, min_size = 10)$size, 28)
  expect_identical(indoorCommentOptions()$placement, "edge")
  expect_identical(indoorCommentOptions(placement = "center")$placement, "center")
  expect_error(indoorCommentOptions(placement = "unknown"), "`placement`")
  expect_error(local_map() |> addIndoor(commentOptions = list(), crs = "simple"), "indoorCommentOptions")
})

test_that("comment anchors stay on concave polygon surfaces outside holes", {
  outer <- matrix(c(0,0, 8,0, 8,1, 1,1, 1,8, 0,8, 0,0), ncol = 2, byrow = TRUE)
  concave <- sf::st_polygon(list(outer))
  shell <- matrix(c(10,0, 20,0, 20,10, 10,10, 10,0), ncol = 2, byrow = TRUE)
  hole <- matrix(c(12,2, 12,8, 18,8, 18,2, 12,2), ncol = 2, byrow = TRUE)
  rooms <- sf::st_sf(feature_id = c("concave", "hole"), level = "0",
    geometry = sf::st_sfc(concave, sf::st_polygon(list(shell, hole))))
  payload <- indoor_call(local_map(rooms) |> addIndoor(layerId = ~feature_id,
    comments = indoorCommentCatalog(rooms$feature_id, "A comment"), crs = "simple"))
  for (i in seq_len(nrow(rooms))) {
    position <- payload$geojson$features[[i]]$properties$leafletIndoorCommentPosition
    point <- sf::st_sfc(sf::st_point(c(position$lng, position$lat)))
    expect_true(sf::st_within(point, sf::st_geometry(rooms[i, ]), sparse = FALSE)[1, 1])
    edge <- sf::st_sfc(sf::st_point(c(position$edge$lng, position$edge$lat)))
    exterior <- sf::st_sfc(sf::st_linestring(sf::st_geometry(rooms)[[i]][[1]]))
    expect_equal(as.numeric(sf::st_distance(edge, exterior)), 0, tolerance = 1e-10)
    expect_gt(as.numeric(sf::st_distance(point, edge)), 0)
  }
})

test_that("multipolygon comment edges belong to the component containing the reference point", {
  parts <- unclass(sf::st_geometry(indoor_demo)[[8]])
  parts <- sf::st_sfc(lapply(parts, sf::st_polygon))
  room <- indoor_demo[8, ]
  payload <- indoor_call(local_map(room) |> addIndoor(layerId = ~feature_id,
    comments = indoorCommentCatalog(room$feature_id, "A comment"), crs = "simple"))
  position <- payload$geojson$features[[1]]$properties$leafletIndoorCommentPosition
  point <- sf::st_sfc(sf::st_point(c(position$lng, position$lat)))
  containing <- sf::st_intersects(point, parts)[[1]]
  edge <- sf::st_sfc(sf::st_point(c(position$edge$lng, position$edge$lat)))
  expect_equal(as.numeric(sf::st_distance(edge, sf::st_boundary(parts[containing]))), 0,
    tolerance = 1e-10)
})

test_that("comments work with geographic, GeoJSON, and mixed geometry inputs", {
  for (data in list(indoor_demo, indoor_demo_geo)) {
    map <- if (is.na(sf::st_crs(data))) local_map(data) else geographic_map(data)
    payload <- indoor_call(addIndoor(map, layerId = ~feature_id,
      comments = indoorCommentCatalog(data$feature_id, "A comment")))
    expect_true(all(vapply(payload$geojson$features, function(feature) {
      position <- feature$properties$leafletIndoorCommentPosition
      is.finite(position$lat) && is.finite(position$lng)
    }, logical(1))))
  }
  geojson <- list(type = "Feature", properties = list(level = "0", id = "a"),
    geometry = list(type = "Point", coordinates = c(2, 48)))
  payload <- indoor_call(leaflet::leaflet() |> addIndoor(data = geojson, layerId = ~id,
    comments = indoorCommentCatalog("a", "A comment")))
  expect_identical(payload$geojson$features[[1]]$properties$leafletIndoorCommentPosition,
    list(lng = 2, lat = 48))
})

test_that("Louvre visitor accounts match the intended floors and retain sources", {
  comments <- read.csv(system.file("examples", "real", "louvre-comments.csv", package = "leaflet.indoor"))
  rooms <- sf::st_read(system.file("examples", "real", "louvre-rooms.geojson", package = "leaflet.indoor"), quiet = TRUE)
  expect_equal(nrow(comments), 4L)
  expect_setequal(unique(comments$layerId), c("osm-way-453817508", "osm-way-492611500", "osm-way-367790015"))
  expect_true(all(comments$layerId %in% rooms$feature_id))
  expect_true(all(grepl("^https://", comments$source)))
  expect_true(all(nzchar(comments$author)))
  expect_true(all(grepl("^Published ", comments$date)))
  expect_equal(sum(comments$layerId == "osm-way-492611500"), 2L)
  expect_true(file.exists(system.file("examples", "real", "COMMENT-SOURCES.md", package = "leaflet.indoor")))
})
