# Generate the synthetic package data sets.
# Run from the package root with: source("data-raw/indoor_demo.R")

library(sf)

rectangle <- function(xmin, ymin, xmax, ymax) {
  st_polygon(list(matrix(
    c(xmin, ymin, xmax, ymin, xmax, ymax, xmin, ymax, xmin, ymin),
    ncol = 2,
    byrow = TRUE
  )))
}

local_geometry <- st_sfc(
  rectangle(0, 0, 8, 6),
  rectangle(9, 0, 17, 6),
  st_linestring(matrix(c(0, 7, 17, 7), ncol = 2, byrow = TRUE)),
  rectangle(7.5, 6, 9.5, 9),
  st_point(c(12, 8)),
  rectangle(0, 10, 8, 16),
  rectangle(9, 10, 17, 16),
  st_multipolygon(list(
    unclass(rectangle(0, 18, 6, 23)),
    unclass(rectangle(7, 18, 10, 23))
  )),
  st_multilinestring(list(
    matrix(c(0, 17, 17, 17), ncol = 2, byrow = TRUE),
    matrix(c(17, 17, 17, 23), ncol = 2, byrow = TRUE)
  )),
  st_multipoint(matrix(c(3, 3, 14, 3), ncol = 2, byrow = TRUE)),
  crs = NA_crs_
)

indoor_demo <- st_sf(
  feature_id = sprintf("feature-%02d", seq_along(local_geometry)),
  name = c(
    "Meeting room", "Laboratory", "Main corridor", "Stairwell",
    "Elevator", "Reading room", "Workshop", "Service suite",
    "Emergency route", "Environmental sensors"
  ),
  description = c(
    "Synthetic meeting room on floor 0.",
    "Synthetic laboratory on floor 0.",
    "A corridor represented as a line on floor 0.",
    "A stairwell shared by floors 0, 1, and 2.",
    "An elevator point shared by all three floors.",
    "Synthetic reading room on floor 1.",
    "Synthetic workshop on floor 1.",
    "A multipolygon service area on floor 2.",
    "A multiline emergency route on floor 2.",
    "Two sensor locations represented by a multipoint."
  ),
  kind = c(
    "room", "room", "corridor", "stairs", "elevator",
    "room", "room", "service", "route", "sensor"
  ),
  fill = c(
    "#8dd3c7", "#ffffb3", "#80b1d3", "#bebada", "#fb8072",
    "#b3de69", "#fccde5", "#d9d9d9", "#bc80bd", "#fdb462"
  ),
  level = I(list(
    "0", "0", "0", c("0", "1", "2"), c("0", "1", "2"),
    "1", "1", "2", "2", "0"
  )),
  geometry = local_geometry
)

geographic_geometry <- (st_geometry(indoor_demo) / 10000) + c(-71.2800, 46.7800)
st_crs(geographic_geometry) <- 4326
indoor_demo_geo <- indoor_demo
st_geometry(indoor_demo_geo) <- geographic_geometry

usethis::use_data(indoor_demo, overwrite = TRUE, compress = "xz")
usethis::use_data(indoor_demo_geo, overwrite = TRUE, compress = "xz")
