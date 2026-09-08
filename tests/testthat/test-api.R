test_that("labels, popups, styles, and layer identifiers are resolved", {
  data <- indoor_demo[1:2, ]
  map <- local_map(data) |>
    addIndoor(
      layerId = ~feature_id,
      label = ~name,
      popup = ~description,
      style = list(fillColor = ~fill, weight = c(2, 3)),
      crs = "simple"
    )
  payload <- indoor_call(map)
  first <- payload$geojson$features[[1]]$properties
  second <- payload$geojson$features[[2]]$properties
  expect_identical(first$leafletIndoorLayerId, "feature-01")
  expect_identical(first$leafletIndoorLabel, "Meeting room")
  expect_match(first$leafletIndoorPopup, "Synthetic meeting room", fixed = TRUE)
  expect_identical(first$leafletIndoorStyle$fillColor, "#8dd3c7")
  expect_identical(first$leafletIndoorStyle$weight, 2)
  expect_identical(second$leafletIndoorStyle$weight, 3)
})
test_that("plain content is escaped and trusted HTML is retained", {
  data <- indoor_demo[1, ]
  plain <- indoor_call(local_map(data) |> addIndoor(label = "<b>plain</b>", crs = "simple"))
  trusted <- indoor_call(local_map(data) |> addIndoor(label = htmltools::HTML("<b>trusted</b>"), crs = "simple"))
  expect_identical(plain$geojson$features[[1]]$properties$leafletIndoorLabel, "&lt;b&gt;plain&lt;/b&gt;")
  expect_identical(trusted$geojson$features[[1]]$properties$leafletIndoorLabel, "<b>trusted</b>")
})

test_that("duplicate layer identifiers and invalid styles are rejected", {
  data <- indoor_demo[1:2, ]
  expect_error(
    local_map(data) |> addIndoor(layerId = "same", crs = "simple"),
    "must be unique",
    fixed = TRUE
  )
  expect_error(
    local_map(data) |> addIndoor(style = list(unknown = 1), crs = "simple"),
    "unsupported option",
    fixed = TRUE
  )
  expect_error(
    local_map(data) |> addIndoor(style = list(weight = 1:3), crs = "simple"),
    "must have length 1 or 2",
    fixed = TRUE
  )
})

test_that("the HTML dependency is attached once and has real files", {
  map <- local_map() |>
    addIndoor(crs = "simple") |>
    addIndoorControl() |>
    setIndoorLevel("1")
  dependencies <- Filter(function(x) identical(x$name, "leaflet-indoor"), map$dependencies)
  expect_length(dependencies, 1L)
  dep <- dependencies[[1]]
  expect_identical(dep$version, as.character(utils::packageVersion("leaflet.indoor")))
  expect_true(file.exists(file.path(dep$src$file, dep$script)))
  expect_true(file.exists(file.path(dep$src$file, dep$stylesheet)))
})

test_that("widget methods and payloads are registered in order", {
  map <- local_map() |>
    addIndoor(dataset_id = "rooms", crs = "simple") |>
    addIndoorControl(dataset_id = "rooms", control_id = "primary") |>
    setIndoorLevel("2", dataset_id = "rooms") |>
    removeIndoorControl("primary") |>
    clearIndoor("rooms")
  methods <- vapply(map$x$calls, `[[`, character(1), "method")
  expect_identical(methods, c(
    "leafletIndoor.add", "leafletIndoor.addControl", "leafletIndoor.setLevel",
    "leafletIndoor.removeControl", "leafletIndoor.clear"
  ))
  expect_identical(map$x$calls[[2]]$args[[1]]$controlId, "primary")
  expect_identical(map$x$calls[[3]]$args[[1]]$level, "2")
})

test_that("multiple data sets and controls have independent identifiers", {
  map <- local_map() |>
    addIndoor(dataset_id = "rooms", crs = "simple") |>
    addIndoorControl(dataset_id = "rooms", control_id = "rooms-a") |>
    addIndoorControl(dataset_id = "rooms", control_id = "rooms-b") |>
    addIndoor(data = indoor_demo[1:3, ], dataset_id = "services", crs = "simple") |>
    addIndoorControl(dataset_id = "services", control_id = "services-a")
  add_calls <- Filter(function(x) identical(x$method, "leafletIndoor.add"), map$x$calls)
  control_calls <- Filter(function(x) identical(x$method, "leafletIndoor.addControl"), map$x$calls)
  expect_identical(vapply(add_calls, function(x) x$args[[1]]$datasetId, character(1)), c("rooms", "services"))
  expect_identical(
    vapply(control_calls, function(x) x$args[[1]]$controlId, character(1)),
    c("rooms-a", "rooms-b", "services-a")
  )
})

test_that("separate widgets carry no shared R metadata", {
  first <- local_map() |> addIndoor(dataset_id = "first", crs = "simple")
  second <- local_map() |> addIndoor(dataset_id = "second", crs = "simple")
  expect_named(attr(first, "leaflet.indoor")$datasets, "first")
  expect_named(attr(second, "leaflet.indoor")$datasets, "second")
  expect_null(attr(first, "leaflet.indoor")$datasets$second)
})

test_that("setIndoorLevel validates regular maps", {
  map <- local_map() |> addIndoor(crs = "simple")
  expect_error(setIndoorLevel(map, "9"), "not present")
  expect_error(setIndoorLevel(local_map(), "0"), "No indoor data set")
  updated <- setIndoorLevel(map, 2)
  expect_identical(attr(updated, "leaflet.indoor")$datasets$indoor$active, "2")
})

test_that("proxy methods send structured Leaflet messages", {
  fixture <- fake_proxy()
  proxy <- fixture$proxy |>
    setIndoorLevel("2") |>
    removeIndoorControl() |>
    clearIndoor()
  expect_s3_class(proxy, "leaflet_proxy")
  expect_length(fixture$captured$messages, 3L)
  methods <- vapply(fixture$captured$messages, function(x) {
    x$message$calls[[1]]$method
  }, character(1))
  expect_identical(methods, c(
    "leafletIndoor.setLevel", "leafletIndoor.removeControl", "leafletIndoor.clear"
  ))
  expect_true(length(fixture$captured$messages[[1]]$message$calls[[1]]$dependencies) >= 1L)
})

test_that("proxy addIndoor requires explicit local coordinate mode", {
  fixture <- fake_proxy(indoor_demo)
  expect_error(addIndoor(fixture$proxy, crs = "auto"), "cannot infer local coordinates")
  expect_no_error(addIndoor(fixture$proxy, crs = "simple"))
  expect_identical(
    fixture$captured$messages[[1]]$message$calls[[1]]$method,
    "leafletIndoor.add"
  )
})

test_that("public API signatures retain the 0.1.0 arguments and add photo support", {
  expect_identical(names(formals(addIndoor)), c(
    "map", "data", "level", "dataset_id", "level_order", "initial_level",
    "layerId", "label", "popup", "style", "options", "labelOptions",
    "popupOptions", "missing_level", "crs", "photos", "photoOptions"
  ))
  expect_identical(names(formals(addIndoorControl)), c(
    "map", "dataset_id", "control_id", "position", "options"
  ))
  expect_identical(names(formals(setIndoorLevel)), c("map", "level", "dataset_id"))
  expect_identical(names(formals(removeIndoorControl)), c("map", "control_id"))
  expect_identical(names(formals(clearIndoor)), c("map", "dataset_id"))
  expect_identical(names(formals(indoorPhotoCatalog)), c("layerId", "src", "caption", "alt"))
  expect_identical(names(formals(indoorPhotoOptions)), c(
    "previous_label", "next_label", "enlarge_label", "close_label",
    "carousel_label", "dialog_label", "counter_label", "unavailable_label"
  ))
})
