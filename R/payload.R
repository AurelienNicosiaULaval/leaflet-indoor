resolve_argument <- function(value, data, n, name) {
  if (is.null(value)) return(vector("list", n))
  value <- leaflet::evalFormula(list(value), data)[[1]]
  value_class <- class(value)
  if (n == 0L) return(list())
  if (length(value) == 1L && n > 1L) value <- rep(value, n)
  if (length(value) != n) {
    indoor_abort(sprintf("`%s` must have length 1 or %d, not %d.", name, n, length(value)))
  }
  if (inherits(value, "html")) {
    return(lapply(seq_len(n), function(i) structure(value[i], class = value_class)))
  }
  if (is.list(value)) value else as.list(value)
}

encode_content <- function(value) {
  if (is.null(value) || length(value) == 0L || (length(value) == 1L && is.na(value))) return(NULL)
  if (inherits(value, "html")) return(as.character(value))
  if (inherits(value, "shiny.tag") || inherits(value, "shiny.tag.list")) {
    return(as.character(htmltools::renderTags(value)$html))
  }
  if (length(value) != 1L) indoor_abort("Each `label` and `popup` value must be scalar.")
  htmltools::htmlEscape(as.character(value))
}

resolve_content <- function(value, data, n, name) {
  resolved <- resolve_argument(value, data, n, name)
  lapply(resolved, encode_content)
}

resolve_layer_ids <- function(value, data, n) {
  resolved <- resolve_argument(value, data, n, "layerId")
  ids <- lapply(resolved, function(x) {
    if (is.null(x) || length(x) == 0L || (length(x) == 1L && is.na(x))) return(NULL)
    if (length(x) != 1L) indoor_abort("Each `layerId` value must be scalar.")
    x <- as.character(x)
    if (!nzchar(x)) indoor_abort("`layerId` values must not be empty.")
    x
  })
  non_null <- unlist(ids[!vapply(ids, is.null, logical(1))], use.names = FALSE)
  if (anyDuplicated(non_null)) indoor_abort("`layerId` values must be unique within an indoor data set.")
  ids
}

resolve_styles <- function(style, data, n) {
  if (is.null(style)) return(rep(list(list()), n))
  if (!is.list(style) || is.null(names(style)) || any(!nzchar(names(style)))) {
    indoor_abort("`style` must be a named list.")
  }
  allowed <- c(
    "radius", "stroke", "color", "weight", "opacity", "lineCap", "lineJoin",
    "dashArray", "dashOffset", "fill", "fillColor", "fillOpacity", "fillRule",
    "bubblingMouseEvents", "className"
  )
  unknown <- setdiff(names(style), allowed)
  if (length(unknown)) {
    indoor_abort(sprintf("`style` contains unsupported option(s): %s.", paste(unknown, collapse = ", ")))
  }
  if (n == 0L) return(list())
  columns <- lapply(names(style), function(name) resolve_argument(style[[name]], data, n, paste0("style$", name)))
  names(columns) <- names(style)
  lapply(seq_len(n), function(i) {
    values <- lapply(columns, `[[`, i)
    values[!vapply(values, function(x) is.null(x) || (length(x) == 1L && is.na(x)), logical(1))]
  })
}

build_indoor_payload <- function(normalized, dataset_id, layerId, photos, label, popup,
                                 style, options, labelOptions, popupOptions,
                                 photoOptions, comments, commentOptions) {
  n <- length(normalized$features)
  ids <- resolve_layer_ids(layerId, normalized$eval_data, n)
  labels <- resolve_content(label, normalized$eval_data, n, "label")
  popups <- resolve_content(popup, normalized$eval_data, n, "popup")
  styles <- resolve_styles(style, normalized$eval_data, n)
  galleries <- resolve_photo_galleries(photos, ids)
  room_comments <- resolve_room_comments(comments, ids)

  features <- lapply(seq_len(n), function(i) {
    feature <- normalized$features[[i]]
    feature$properties <- list(
      leafletIndoorLevels = unname(normalized$levels[[i]]),
      leafletIndoorIndex = i,
      leafletIndoorLayerId = ids[[i]],
      leafletIndoorLabel = labels[[i]],
      leafletIndoorPopup = popups[[i]],
      leafletIndoorPhotos = galleries[[i]],
      leafletIndoorComments = room_comments[[i]],
      leafletIndoorCommentPosition = if (!is.null(room_comments[[i]])) comment_position(feature) else NULL,
      leafletIndoorStyle = styles[[i]]
    )
    feature
  })

  list(
    datasetId = dataset_id,
    levels = unname(normalized$level_order),
    initialLevel = normalized$initial_level,
    geojson = list(type = "FeatureCollection", features = features),
    options = unclass(options),
    labelOptions = unclass(labelOptions),
    popupOptions = unclass(popupOptions),
    photoOptions = unclass(photoOptions),
    commentOptions = unclass(commentOptions),
    crs = normalized$crs
  )
}
