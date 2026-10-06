# leaflet.indoor (development version)

* Adds optional room comments and attributed testimonials through
  `indoorCommentCatalog()`, with customizable icons and translated labels from
  `indoorCommentOptions()`. Comment icons follow the active floor and support
  mouse, touch, and keyboard interaction while preserving room-photo popups.
* Extends the Louvre example with four attributed excerpts or summaries from
  three published visitor accounts, associated with three named rooms.

* Adds photo catalogues and accessible room-photo carousels with paired
  captions, previous/next navigation, and an enlarged dialog.
* Adds a fully attributed real-world Louvre example using 135 named
  OpenStreetMap indoor spaces and five public-domain Wikimedia Commons photos
  associated with three rooms on two floors.

# leaflet.indoor 0.1.0

Initial experimental release.

* Adds multi-floor point, line, polygon, and compatible multiple-geometry
  rendering for `sf`, GeoJSON, `sfc`, and optional `SpatVector` inputs.
* Adds accessible, map-local floor controls and support for multiple independent
  indoor data sets.
* Adds Shiny events and `leafletProxy()` methods for changing, clearing, and
  replacing indoor data.
* Documents and browser-tests geographic coordinates and local Cartesian plans
  with `L.CRS.Simple`.
