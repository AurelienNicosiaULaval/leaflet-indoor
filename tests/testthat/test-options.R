test_that("indoorOptions returns validated geometry defaults", {
  options <- indoorOptions(pane = "indoor", interactive = FALSE)
  expect_s3_class(options, "leaflet_indoor_options")
  expect_identical(options$pane, "indoor")
  expect_false(options$interactive)
  expect_identical(options$point$radius, 6)
  expect_identical(options$line$fill, FALSE)
  expect_identical(options$polygon$fillOpacity, 0.35)
  expect_error(indoorOptions(point = list()), "named list")
  expect_error(indoorOptions(interactive = NA), "TRUE or FALSE")
})
test_that("indoorControlOptions returns accessible display options", {
  options <- indoorControlOptions(
    title = "Storey",
    descending = FALSE,
    max_height = 300,
    empty_label = "Empty"
  )
  expect_s3_class(options, "leaflet_indoor_control_options")
  expect_identical(options$title, "Storey")
  expect_false(options$descending)
  expect_identical(options$maxHeight, 300)
  expect_identical(options$emptyLabel, "Empty")
  expect_error(indoorControlOptions(max_height = 40), "greater than or equal to 80")
})

test_that("map and identifier errors name the problematic parameter", {
  expect_error(addIndoor(list()), "`map`")
  expect_error(addIndoorControl(leaflet::leaflet(), dataset_id = ""), "`dataset_id`")
  expect_error(removeIndoorControl(leaflet::leaflet(), control_id = NA_character_), "`control_id`")
  expect_error(clearIndoor(leaflet::leaflet(), dataset_id = ""), "`dataset_id`")
})
