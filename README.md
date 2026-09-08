
<!-- README.md is generated from README.Rmd. Edit this file, then render it. -->

# leaflet.indoor

[![R-CMD-check](https://github.com/AurelienNicosiaULaval/leaflet-indoor/actions/workflows/R-CMD-check.yaml/badge.svg)](https://github.com/AurelienNicosiaULaval/leaflet-indoor/actions/workflows/R-CMD-check.yaml)
[![Browser
tests](https://github.com/AurelienNicosiaULaval/leaflet-indoor/actions/workflows/browser-tests.yaml/badge.svg)](https://github.com/AurelienNicosiaULaval/leaflet-indoor/actions/workflows/browser-tests.yaml)
[![pkgdown](https://github.com/AurelienNicosiaULaval/leaflet-indoor/actions/workflows/pkgdown.yaml/badge.svg)](https://github.com/AurelienNicosiaULaval/leaflet-indoor/actions/workflows/pkgdown.yaml)

`leaflet.indoor` adds multi-level indoor vector data and an accessible
floor control to maps created with the R package
[`leaflet`](https://rstudio.github.io/leaflet/). Each indoor data set
displays exactly one active floor while remaining independent from other
maps and indoor data sets on the same page.

Version 0.1.0 is experimental. The public API is tested for regression,
but feedback from additional indoor data models is welcome.

## Installation

Install the development release from GitHub:

``` r
pak::pak("AurelienNicosiaULaval/leaflet-indoor")
```

Git users can clone with SSH:

``` text
git clone git@github.com:AurelienNicosiaULaval/leaflet-indoor.git
```

## Example

The included data are synthetic and do not describe a real building.

``` r
library(leaflet)
library(leaflet.indoor)

leaflet(
  indoor_demo,
  options = leafletOptions(crs = leafletCRS(crsClass = "L.CRS.Simple"))
) |>
  addIndoor(
    level = "level",
    initial_level = "0",
    layerId = ~feature_id,
    label = ~name,
    popup = ~description,
    style = list(fillColor = ~fill),
    crs = "simple"
  ) |>
  addIndoorControl(position = "bottomright")
```

For geographic `sf` data, `addIndoor()` transforms a declared CRS to
EPSG:4326. For local Cartesian plans, use `L.CRS.Simple`, leave the `sf`
CRS undefined, and set `crs = "simple"`. No spatial transformation is
invented for local coordinates.

See the [getting started
article](https://aureliennicosiaulaval.github.io/leaflet-indoor/articles/get-started.html)
for styles, multi-floor features, GeoJSON, coordinate systems, and
Shiny.

## Room photos

Associate room identifiers with images and plain-text captions using one
row per photo. Repeating an identifier creates a carousel in catalogue
order:

``` r
room_photos <- indoorPhotoCatalog(
  layerId = c("feature-01", "feature-01"),
  src = c("entrance.jpg", "windows.jpg"),
  caption = c("Entrance view", "View from the windows")
)

leaflet(indoor_demo, options = leafletOptions(
  crs = leafletCRS("L.CRS.Simple")
)) |>
  addIndoor(
    layerId = ~feature_id,
    photos = room_photos,
    popup = ~description,
    crs = "simple"
  ) |>
  addIndoorControl()
```

Existing local image files are embedded for portable saved widgets.
Features without catalogue rows keep their ordinary popup. The Room
photo carousels article provides a real-world demonstration using a
Leaflet street map, 135 named Louvre indoor spaces from OpenStreetMap,
and public-domain room photographs from Wikimedia Commons. The example
includes complete provenance and is explicitly not an official visitor
or safety plan.

## Shiny

Floor changes made by a user are available as
`input$MAPID_indoor_level`. The value contains `level`, `dataset_id`,
and `control_id`. Update a rendered map with:

``` r
leafletProxy("map") |>
  setIndoorLevel("2")
```

## Issues and security

Report reproducible problems through the [GitHub issue
tracker](https://github.com/AurelienNicosiaULaval/leaflet-indoor/issues).
Plain labels and popups are escaped. Use `htmltools::HTML()` only with
trusted content.

## Related work and license

This is an independent MIT-licensed implementation. It does not
incorporate source code from Christopher Baines’s archived BSD-2-Clause
[`leaflet-indoor`](https://github.com/cbaines/leaflet-indoor) JavaScript
plugin, which established an earlier floor-layer and level-control
pattern for Leaflet.
