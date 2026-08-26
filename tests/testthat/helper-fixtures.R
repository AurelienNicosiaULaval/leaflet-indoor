local_map <- function(data = indoor_demo) {
  leaflet::leaflet(
    data,
    options = leaflet::leafletOptions(
      crs = leaflet::leafletCRS(crsClass = "L.CRS.Simple")
    )
  )
}

geographic_map <- function(data = indoor_demo_geo) {
  leaflet::leaflet(data)
}

indoor_call <- function(map, method = "leafletIndoor.add") {
  calls <- Filter(function(x) identical(x$method, method), map$x$calls)
  expect_length(calls, 1L)
  calls[[1]]$args[[1]]
}

empty_indoor_sf <- function(crs = sf::NA_crs_) {
  sf::st_sf(
    level = character(),
    name = character(),
    geometry = sf::st_sfc(crs = crs)
  )
}

fake_proxy <- function(data = NULL) {
  captured <- new.env(parent = emptyenv())
  captured$messages <- list()
  session <- list(
    sendCustomMessage = function(type, message) {
      captured$messages[[length(captured$messages) + 1L]] <- list(
        type = type,
        message = message
      )
    }
  )
  x <- list()
  attr(x, "leafletData") <- data
  proxy <- structure(
    list(
      session = session,
      id = "map",
      x = x,
      deferUntilFlush = FALSE,
      dependencies = NULL
    ),
    class = "leaflet_proxy"
  )
  list(proxy = proxy, captured = captured)
}
