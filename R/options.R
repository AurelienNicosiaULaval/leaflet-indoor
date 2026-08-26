#' Options for indoor layers
#'
#' Create the style and interaction options used by [addIndoor()]. The three
#' geometry-specific lists use Leaflet path option names. Values supplied via
#' the `style` argument of [addIndoor()] override these defaults.
#'
#' @param point,line,polygon Named lists of options for point, line, and polygon
#'   geometries.
#' @param pane Optional Leaflet pane name.
#' @param interactive Whether features receive mouse and keyboard events.
#'
#' @return An object of class `leaflet_indoor_options`.
#' @export
indoorOptions <- function(
  point = NULL,
  line = NULL,
  polygon = NULL,
  pane = NULL,
  interactive = TRUE
) {
  point_default <- list(
    radius = 6, stroke = TRUE, color = "#2c3e50", weight = 1,
    opacity = 1, fill = TRUE, fillColor = "#3388ff", fillOpacity = 0.8
  )
  line_default <- list(
    stroke = TRUE, color = "#3388ff", weight = 3, opacity = 1,
    fill = FALSE
  )
  polygon_default <- list(
    stroke = TRUE, color = "#2c3e50", weight = 1, opacity = 1,
    fill = TRUE, fillColor = "#3388ff", fillOpacity = 0.35
  )

  point <- validate_option_list(point %||% point_default, "point")
  line <- validate_option_list(line %||% line_default, "line")
  polygon <- validate_option_list(polygon %||% polygon_default, "polygon")
  assert_scalar_logical(interactive, "interactive")
  if (!is.null(pane)) assert_scalar_string(pane, "pane")

  structure(
    list(
      point = point,
      line = line,
      polygon = polygon,
      pane = pane,
      interactive = interactive
    ),
    class = "leaflet_indoor_options"
  )
}

#' Options for an indoor floor control
#'
#' @param title Accessible title displayed above the floor buttons.
#' @param descending Display higher floors above lower floors.
#' @param max_height Maximum button-list height in CSS pixels.
#' @param empty_label Text displayed when the linked data set has no floors.
#'
#' @return An object of class `leaflet_indoor_control_options`.
#' @export
indoorControlOptions <- function(
  title = "Floor",
  descending = TRUE,
  max_height = 280,
  empty_label = "No levels"
) {
  assert_scalar_string(title, "title")
  assert_scalar_logical(descending, "descending")
  if (!is.numeric(max_height) || length(max_height) != 1L ||
        is.na(max_height) || !is.finite(max_height) || max_height < 80) {
    indoor_abort("`max_height` must be one finite number greater than or equal to 80.")
  }
  assert_scalar_string(empty_label, "empty_label")

  structure(
    list(
      title = title,
      descending = descending,
      maxHeight = unname(max_height),
      emptyLabel = empty_label
    ),
    class = "leaflet_indoor_control_options"
  )
}

validate_option_list <- function(x, name) {
  if (!is.list(x) || is.null(names(x)) || any(!nzchar(names(x)))) {
    indoor_abort(sprintf("`%s` must be a named list.", name))
  }
  x
}
