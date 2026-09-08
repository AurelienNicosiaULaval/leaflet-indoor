test_that("photo catalogues preserve identifier, source, caption, and alt pairs", {
  catalogue <- indoorPhotoCatalog(
    layerId = "feature-01",
    src = c("first.jpg", "second.jpg"),
    caption = c("First view", "Second view"),
    alt = c("First alternative", "Second alternative")
  )
  expect_s3_class(catalogue, "leaflet_indoor_photos")
  expect_identical(names(catalogue), c("layerId", "src", "caption", "alt"))
  expect_identical(catalogue$layerId, rep("feature-01", 2L))
  expect_identical(catalogue$src, c("first.jpg", "second.jpg"))
  expect_identical(catalogue$caption, c("First view", "Second view"))
  expect_identical(catalogue$alt, c("First alternative", "Second alternative"))
  expect_identical(row.names(catalogue), c("1", "2"))
})

test_that("existing local photos are embedded as image data URIs", {
  path <- system.file(
    "examples", "photos", "meeting-room-entrance.svg",
    package = "leaflet.indoor"
  )
  expect_true(nzchar(path))
  catalogue <- indoorPhotoCatalog("feature-01", path, "Entrance")
  expect_match(catalogue$src, "^data:image/svg\\+xml;base64,")
  expect_gt(nchar(catalogue$src), 500L)
})

test_that("photo catalogues validate fields and source schemes", {
  expect_error(
    indoorPhotoCatalog(c("a", "b"), c("a.jpg", "b.jpg", "c.jpg"), c("A", "B", "C")),
    "must have length 1 or 3",
    fixed = TRUE
  )
  expect_error(indoorPhotoCatalog("a", "a.jpg", NA_character_), "caption")
  expect_error(indoorPhotoCatalog("a", "javascript:alert(1)", "Unsafe"), "unsupported URI scheme")
  expect_error(indoorPhotoCatalog("a", "data:text/html;base64,WA==", "Unsafe"), "image/\\*")
  expect_error(
    normalize_photo_catalog(data.frame(layerId = "a", src = "a.jpg")),
    "caption",
    fixed = TRUE
  )
})

test_that("photo options are structured, localizable, and validated", {
  options <- indoorPhotoOptions(
    previous_label = "Précédent",
    next_label = "Suivant",
    enlarge_label = "Agrandir",
    close_label = "Fermer",
    carousel_label = "Photos de la pièce",
    dialog_label = "Photo agrandie",
    counter_label = "Photo {current} sur {total}",
    unavailable_label = "Image indisponible"
  )
  expect_s3_class(options, "leaflet_indoor_photo_options")
  expect_identical(options$enlargeLabel, "Agrandir")
  expect_identical(options$counterLabel, "Photo {current} sur {total}")
  expect_error(indoorPhotoOptions(counter_label = "Photo current"), "{current}", fixed = TRUE)
  expect_error(indoorPhotoOptions(next_label = ""), "`next_label`")
})

test_that("photo galleries are matched to feature layer identifiers in row order", {
  photos <- data.frame(
    layerId = c("feature-01", "feature-02", "feature-01"),
    src = c("one.jpg", "laboratory.jpg", "two.jpg"),
    caption = c("First", "Laboratory", "Second"),
    stringsAsFactors = FALSE
  )
  payload <- indoor_call(
    local_map(indoor_demo[1:3, ]) |>
      addIndoor(
        layerId = ~feature_id,
        photos = photos,
        popup = ~description,
        crs = "simple"
      )
  )
  first <- payload$geojson$features[[1]]$properties
  second <- payload$geojson$features[[2]]$properties
  third <- payload$geojson$features[[3]]$properties
  expect_identical(vapply(first$leafletIndoorPhotos, `[[`, character(1), "src"), c("one.jpg", "two.jpg"))
  expect_identical(
    vapply(first$leafletIndoorPhotos, `[[`, character(1), "caption"),
    c("First", "Second")
  )
  expect_identical(second$leafletIndoorPhotos[[1]]$caption, "Laboratory")
  expect_null(third$leafletIndoorPhotos)
  expect_match(first$leafletIndoorPopup, "Synthetic meeting room", fixed = TRUE)
})

test_that("photos require matching non-missing layer identifiers", {
  photos <- indoorPhotoCatalog("unknown", "one.jpg", "Unknown room")
  expect_error(
    local_map(indoor_demo[1, ]) |>
      addIndoor(layerId = ~feature_id, photos = photos, crs = "simple"),
    "not present in `layerId`",
    fixed = TRUE
  )
  expect_error(
    local_map(indoor_demo[1, ]) |> addIndoor(photos = photos, crs = "simple"),
    "requires non-missing feature identifiers",
    fixed = TRUE
  )
})

test_that("features without a photo catalogue retain null photo metadata", {
  payload <- indoor_call(
    local_map(indoor_demo[1, ]) |>
      addIndoor(layerId = ~feature_id, popup = ~description, crs = "simple")
  )
  properties <- payload$geojson$features[[1]]$properties
  expect_null(properties$leafletIndoorPhotos)
  expect_match(properties$leafletIndoorPopup, "Synthetic meeting room", fixed = TRUE)
})
