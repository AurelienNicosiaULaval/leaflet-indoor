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

#' Options for indoor photo carousels
#'
#' Controls the visible and accessible labels used by photo carousels created
#' when [addIndoor()] receives a non-empty `photos` catalogue. Labels can be
#' translated without changing the catalogue.
#'
#' @param previous_label Label for the previous-photo button.
#' @param next_label Label for the next-photo button.
#' @param enlarge_label Label for the button that opens the current photo and
#'   caption in a larger dialog.
#' @param close_label Label for the dialog close button.
#' @param carousel_label Accessible label for the carousel.
#' @param dialog_label Accessible label for the enlarged-photo dialog.
#' @param counter_label Counter template containing `{current}` and `{total}`.
#' @param unavailable_label Text shown when an image cannot be loaded.
#'
#' @return An object of class `leaflet_indoor_photo_options`.
#' @export
indoorPhotoOptions <- function(
  previous_label = "Previous",
  next_label = "Next",
  enlarge_label = "Enlarge",
  close_label = "Close",
  carousel_label = "Room photos",
  dialog_label = "Enlarged room photo",
  counter_label = "Photo {current} of {total}",
  unavailable_label = "Image unavailable"
) {
  labels <- list(
    previous_label = previous_label,
    next_label = next_label,
    enlarge_label = enlarge_label,
    close_label = close_label,
    carousel_label = carousel_label,
    dialog_label = dialog_label,
    counter_label = counter_label,
    unavailable_label = unavailable_label
  )
  for (name in names(labels)) assert_scalar_string(labels[[name]], name)
  if (!grepl("{current}", counter_label, fixed = TRUE) ||
        !grepl("{total}", counter_label, fixed = TRUE)) {
    indoor_abort("`counter_label` must contain both `{current}` and `{total}`.")
  }
  structure(
    list(
      previousLabel = previous_label,
      nextLabel = next_label,
      enlargeLabel = enlarge_label,
      closeLabel = close_label,
      carouselLabel = carousel_label,
      dialogLabel = dialog_label,
      counterLabel = counter_label,
      unavailableLabel = unavailable_label
    ),
    class = "leaflet_indoor_photo_options"
  )
}

#' Options for room comment icons
#'
#' @param icon One of `"comment"`, `"quote"`, or `"info"` for bundled vector
#'   icons, or a short plain-text symbol such as `"\u2605"` or `"\u270e"`.
#' @param color,background_color Icon foreground and background colors as
#'   hexadecimal `#RGB` or `#RRGGBB` strings.
#' @param show Whether to display comment icons.
#' @param marker_label Accessible action label for a comment icon. The room
#'   label, when supplied, is appended automatically.
#' @param popup_label Heading displayed above the room comments.
#' @param source_label Label for each comment's source link.
#' @param size Maximum visual badge diameter in CSS pixels.
#' @param min_size Minimum visual badge diameter when fitting to a room.
#' @param fit_to_room Scale the badge and its icon with the room's projected
#'   size as the map zoom changes. Point features retain `size`. The clickable
#'   target remains at least 44 pixels for touch and keyboard access.
#' @return An object of class `leaflet_indoor_comment_options`.
#' @export
#' @examples
#' indoorCommentOptions(icon = "quote", background_color = "#7c3aed")
#' indoorCommentOptions(icon = "\u2605", marker_label = "Lire les témoignages",
#'                      popup_label = "Témoignages", source_label = "Source")
indoorCommentOptions <- function(icon = "comment", color = "#ffffff",
                                 background_color = "#7c3aed", show = TRUE,
                                 marker_label = "Read room comments",
                                 popup_label = "Room comments",
                                 source_label = "Read source", size = 36,
                                 min_size = 12, fit_to_room = TRUE) {
  assert_scalar_string(icon, "icon")
  if (nchar(icon, type = "chars") > 16L) {
    indoor_abort("`icon` must be a bundled icon name or a short plain-text symbol (at most 16 characters).")
  }
  for (name in c("color", "background_color")) {
    value <- if (name == "color") color else background_color
    assert_scalar_string(value, name)
    if (!grepl("^#(?:[[:xdigit:]]{3}|[[:xdigit:]]{6})$", value)) {
      indoor_abort(sprintf("`%s` must be a hexadecimal #RGB or #RRGGBB color.", name))
    }
  }
  assert_scalar_logical(show, "show")
  assert_scalar_string(marker_label, "marker_label")
  assert_scalar_string(popup_label, "popup_label")
  assert_scalar_string(source_label, "source_label")
  for (name in c("size", "min_size")) {
    value <- if (name == "size") size else min_size
    if (!is.numeric(value) || length(value) != 1L || is.na(value) ||
        !is.finite(value) || value < 8) {
      indoor_abort(sprintf("`%s` must be one finite number greater than or equal to 8.", name))
    }
  }
  if (min_size > size) indoor_abort("`min_size` must not exceed `size`.")
  assert_scalar_logical(fit_to_room, "fit_to_room")
  structure(list(icon = icon, color = color, backgroundColor = background_color,
                 show = show, markerLabel = marker_label,
                 popupLabel = popup_label, sourceLabel = source_label,
                 size = unname(size), minSize = unname(min_size), fitToRoom = fit_to_room),
            class = "leaflet_indoor_comment_options")
}

validate_option_list <- function(x, name) {
  if (!is.list(x) || is.null(names(x)) || any(!nzchar(names(x)))) {
    indoor_abort(sprintf("`%s` must be a named list.", name))
  }
  x
}
