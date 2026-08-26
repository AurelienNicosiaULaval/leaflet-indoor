#' Add multi-level indoor features
#'
#' Adds points, lines, and polygons organized by floor to a [leaflet::leaflet()]
#' map. Exactly one floor is visible for each `dataset_id`.
#'
#' @param map A Leaflet map or proxy.
#' @param data An `sf`, `sfc`, optional `SpatVector`, or GeoJSON object. The
#'   default uses the data supplied to [leaflet::leaflet()] or
#'   [leaflet::leafletProxy()].
#' @param level For `sf` and GeoJSON, the floor column or property name. For a
#'   bare `sfc`, an explicit vector or list of floor values.
#' @param dataset_id Non-empty identifier scoped to this map.
#' @param level_order Optional vector containing every observed floor exactly
#'   once, from lowest to highest.
#' @param initial_level Initial floor. The default is `"0"` when present, then
#'   the first floor in `level_order`.
#' @param layerId Optional feature identifiers. Formulas are evaluated against
#'   `data`.
#' @param label,popup Optional tooltip and popup content. Plain strings are
#'   escaped; wrap trusted markup in [htmltools::HTML()].
#' @param style Optional named list of fixed, vector, or formula-driven Leaflet
#'   path options.
#' @param options Options created by [indoorOptions()].
#' @param labelOptions,popupOptions Leaflet tooltip and popup options.
#' @param missing_level Either `"error"` or `"drop"`.
#' @param crs Coordinate interpretation. `"auto"` detects the map CRS for
#'   ordinary maps. Use `"simple"` explicitly for local coordinates sent to a
#'   proxy.
#'
#' @return The input map or proxy, with an indoor method queued.
#' @export
#'
#' @examples
#' leaflet::leaflet(
#'   indoor_demo,
#'   options = leaflet::leafletOptions(
#'     crs = leaflet::leafletCRS("L.CRS.Simple")
#'   )
#' ) |>
#'   leaflet::addMapPane("indoor", 420) |>
#'   addIndoor(
#'     initial_level = "0",
#'     layerId = ~feature_id,
#'     label = ~name,
#'     popup = ~description,
#'     crs = "simple",
#'     options = indoorOptions(pane = "indoor")
#'   ) |>
#'   addIndoorControl(position = "bottomright")
addIndoor <- function(
  map,
  data = leaflet::getMapData(map),
  level = "level",
  dataset_id = "indoor",
  level_order = NULL,
  initial_level = NULL,
  layerId = NULL,
  label = NULL,
  popup = NULL,
  style = NULL,
  options = indoorOptions(),
  labelOptions = leaflet::labelOptions(),
  popupOptions = leaflet::popupOptions(),
  missing_level = c("error", "drop"),
  crs = c("auto", "geographic", "simple")
) {
  level_missing <- missing(level)
  assert_map(map)
  assert_scalar_string(dataset_id, "dataset_id")
  missing_level <- match.arg(missing_level)
  crs <- match.arg(crs)
  if (!inherits(options, "leaflet_indoor_options")) {
    indoor_abort("`options` must be created by `indoorOptions()`.")
  }
  if (!is.list(labelOptions)) indoor_abort("`labelOptions` must be a list.")
  if (!is.list(popupOptions)) indoor_abort("`popupOptions` must be a list.")

  normalized <- normalize_indoor_data(
    data = data,
    map = map,
    level = level,
    level_missing = level_missing,
    level_order = level_order,
    initial_level = initial_level,
    missing_level = missing_level,
    crs = crs
  )
  payload <- build_indoor_payload(
    normalized, dataset_id, layerId, label, popup, style,
    options, labelOptions, popupOptions
  )

  map <- register_indoor_dependency(map)
  if (inherits(map, "leaflet") && nrow(normalized$coords) > 0L) {
    map <- leaflet::expandLimits(
      map,
      lat = normalized$coords[, 2],
      lng = normalized$coords[, 1]
    )
  }
  map <- leaflet::invokeMethod(map, NULL, "leafletIndoor.add", payload)
  meta <- get_indoor_meta(map)
  meta$datasets[[dataset_id]] <- list(
    levels = normalized$level_order,
    active = normalized$initial_level,
    crs = normalized$crs
  )
  set_indoor_meta(map, meta)
}

#' Add an accessible floor control
#'
#' @param map A Leaflet map or proxy.
#' @param dataset_id Indoor data set controlled by these buttons.
#' @param control_id Unique control identifier scoped to this map.
#' @param position One of `"topleft"`, `"topright"`, `"bottomleft"`, or
#'   `"bottomright"`.
#' @param options Options created by [indoorControlOptions()].
#'
#' @return The input map or proxy.
#' @export
addIndoorControl <- function(
  map,
  dataset_id = "indoor",
  control_id = dataset_id,
  position = "topright",
  options = indoorControlOptions()
) {
  assert_map(map)
  assert_scalar_string(dataset_id, "dataset_id")
  assert_scalar_string(control_id, "control_id")
  position <- match.arg(position, c("topleft", "topright", "bottomleft", "bottomright"))
  if (!inherits(options, "leaflet_indoor_control_options")) {
    indoor_abort("`options` must be created by `indoorControlOptions()`.")
  }
  payload <- c(
    list(datasetId = dataset_id, controlId = control_id, position = position),
    unclass(options)
  )
  map <- register_indoor_dependency(map)
  map <- leaflet::invokeMethod(map, NULL, "leafletIndoor.addControl", payload)
  meta <- get_indoor_meta(map)
  meta$controls[[control_id]] <- list(dataset_id = dataset_id)
  set_indoor_meta(map, meta)
}

#' Set the active indoor floor
#'
#' @param map A Leaflet map or proxy.
#' @param level One non-missing floor value.
#' @param dataset_id Indoor data set to update.
#'
#' @return The input map or proxy.
#' @export
setIndoorLevel <- function(map, level, dataset_id = "indoor") {
  assert_map(map)
  assert_scalar_string(dataset_id, "dataset_id")
  if (length(level) != 1L || is.na(level) || !nzchar(trimws(as.character(level)))) {
    indoor_abort("`level` must be one non-missing, non-empty value.")
  }
  level <- as.character(level)
  meta <- get_indoor_meta(map)
  known <- meta$datasets[[dataset_id]]
  if (inherits(map, "leaflet")) {
    if (is.null(known)) indoor_abort(sprintf("No indoor data set has `dataset_id = %s`.", dQuote(dataset_id)))
    if (!level %in% known$levels) {
      indoor_abort(sprintf(
        "`level` is %s, but it is not present in indoor data set %s.",
        dQuote(level), dQuote(dataset_id)
      ))
    }
  }
  map <- register_indoor_dependency(map)
  map <- leaflet::invokeMethod(map, NULL, "leafletIndoor.setLevel", list(
    datasetId = dataset_id,
    level = level
  ))
  if (!is.null(known)) {
    meta$datasets[[dataset_id]]$active <- level
    map <- set_indoor_meta(map, meta)
  }
  map
}

#' Remove an indoor floor control
#'
#' @param map A Leaflet map or proxy.
#' @param control_id Control to remove.
#'
#' @return The input map or proxy.
#' @export
removeIndoorControl <- function(map, control_id = "indoor") {
  assert_map(map)
  assert_scalar_string(control_id, "control_id")
  map <- register_indoor_dependency(map)
  map <- leaflet::invokeMethod(map, NULL, "leafletIndoor.removeControl", list(controlId = control_id))
  meta <- get_indoor_meta(map)
  meta$controls[[control_id]] <- NULL
  set_indoor_meta(map, meta)
}

#' Clear an indoor data set
#'
#' Removes all features for one `dataset_id`. Linked controls remain present
#' and show their configured empty state.
#'
#' @param map A Leaflet map or proxy.
#' @param dataset_id Indoor data set to clear.
#'
#' @return The input map or proxy.
#' @export
clearIndoor <- function(map, dataset_id = "indoor") {
  assert_map(map)
  assert_scalar_string(dataset_id, "dataset_id")
  map <- register_indoor_dependency(map)
  map <- leaflet::invokeMethod(map, NULL, "leafletIndoor.clear", list(datasetId = dataset_id))
  meta <- get_indoor_meta(map)
  meta$datasets[[dataset_id]] <- list(levels = character(), active = NULL, crs = NULL)
  set_indoor_meta(map, meta)
}
