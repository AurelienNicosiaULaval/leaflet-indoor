test_that("numeric levels are ordered numerically and stored as text", {
  data <- indoor_demo[rep(1, 4), ]
  data$level <- c(10, 2, 0, -1)
  map <- local_map(data) |> addIndoor(crs = "simple")
  payload <- indoor_call(map)

  expect_identical(payload$levels, c("-1", "0", "2", "10"))
  expect_identical(payload$initialLevel, "0")
  expect_true(all(vapply(payload$geojson$features, function(x) {
    is.character(x$properties$leafletIndoorLevels)
  }, logical(1))))
})
test_that("text levels use deterministic natural ordering", {
  expect_identical(
    leaflet.indoor:::natural_level_order(c("2", "B1", "10", "B2", "0")),
    c("B2", "B1", "0", "2", "10")
  )
  expect_identical(
    leaflet.indoor:::natural_level_order(c("Level 10", "Level 2", "Roof")),
    c("Level 2", "Level 10", "Roof")
  )
})

test_that("observed factor order is preserved", {
  data <- indoor_demo[rep(1, 3), ]
  data$level <- factor(c("Upper", "Ground", "Lower"),
    levels = c("Lower", "Ground", "Upper", "Unused")
  )
  payload <- indoor_call(local_map(data) |> addIndoor(crs = "simple"))
  expect_identical(payload$levels, c("Lower", "Ground", "Upper"))
  expect_identical(payload$initialLevel, "Lower")
})

test_that("explicit order must exactly cover observed levels", {
  expect_error(
    local_map() |> addIndoor(level_order = c("0", "1"), crs = "simple"),
    "each observed level exactly once",
    fixed = TRUE
  )
  expect_error(
    local_map() |> addIndoor(level_order = c("0", "1", "2", "2"), crs = "simple"),
    "unique",
    fixed = TRUE
  )
  payload <- indoor_call(
    local_map() |>
      addIndoor(level_order = c("2", "1", "0"), initial_level = "1", crs = "simple")
  )
  expect_identical(payload$levels, c("2", "1", "0"))
  expect_identical(payload$initialLevel, "1")
})

test_that("invalid initial levels are rejected", {
  expect_error(
    local_map() |> addIndoor(initial_level = "9", crs = "simple"),
    "not present",
    fixed = TRUE
  )
})

test_that("list columns assign a feature to multiple levels", {
  payload <- indoor_call(local_map() |> addIndoor(crs = "simple"))
  stair <- payload$geojson$features[[4]]$properties$leafletIndoorLevels
  elevator <- payload$geojson$features[[5]]$properties$leafletIndoorLevels
  expect_identical(stair, c("0", "1", "2"))
  expect_identical(elevator, c("0", "1", "2"))
})

test_that("missing levels use an explicit policy", {
  data <- indoor_demo[1:3, ]
  data$level <- I(list("0", NA_character_, c("1", NA_character_)))
  expect_error(
    local_map(data) |> addIndoor(crs = "simple"),
    "feature(s): 2, 3",
    fixed = TRUE
  )
  expect_warning(
    map <- local_map(data) |> addIndoor(missing_level = "drop", crs = "simple"),
    "affected 2 feature(s); 1 feature(s)",
    fixed = TRUE
  )
  payload <- indoor_call(map)
  expect_length(payload$geojson$features, 2L)
  expect_identical(payload$levels, c("0", "1"))
})

test_that("empty indoor data create an empty data set", {
  map <- leaflet::leaflet(
    empty_indoor_sf(),
    options = leaflet::leafletOptions(crs = leaflet::leafletCRS("L.CRS.Simple"))
  ) |>
    addIndoor(crs = "simple") |>
    addIndoorControl()
  payload <- indoor_call(map)
  expect_identical(payload$levels, character())
  expect_null(payload$initialLevel)
  expect_length(payload$geojson$features, 0L)
  expect_error(
    leaflet::leaflet(empty_indoor_sf()) |>
      addIndoor(initial_level = "0"),
    "cannot be supplied",
    fixed = TRUE
  )
})
