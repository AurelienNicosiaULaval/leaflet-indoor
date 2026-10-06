#' Create a catalogue of room comments or testimonials
#'
#' Each row associates a plain-text comment with a feature identifier supplied
#' to [addIndoor()]. Repeating an identifier displays several comments in row
#' order. Comments open from a separate map icon, leaving room popups and photo
#' carousels available through the room itself.
#'
#' @param layerId Feature identifiers matching `layerId` in [addIndoor()].
#' @param text Non-empty plain-text comments.
#' @param author,date Optional plain-text attribution and date labels. An empty
#'   string omits the field. Dates are displayed as supplied.
#' @param source Optional absolute HTTP(S) source URLs, or empty strings.
#' @param title Optional plain-text headings, for example to distinguish a
#'   published excerpt from a summary.
#'
#' @details Fields of length one are recycled to the number of comments.
#'   Content is rendered as text, including strings wrapped in `HTML()`.
#'   Authors are responsible for permission and accurate attribution when
#'   displaying third-party material.
#' @return A data frame of class `leaflet_indoor_comments`.
#' @export
#' @examples
#' comments <- indoorCommentCatalog(
#'   layerId = c("room-01", "room-01"),
#'   text = c("A quiet place to read.", "The entrance is easy to find."),
#'   author = c("Example visitor A", "Example visitor B")
#' )
#' comments
indoorCommentCatalog <- function(layerId, text, author = "", date = "",
                                 source = "", title = "") {
  fields <- list(layerId = layerId, text = text, author = author, date = date,
                 source = source, title = title)
  if (length(layerId) == 0L && length(text) == 0L) {
    fields <- lapply(fields, function(value) character())
  }
  n <- max(lengths(fields), 0L)
  invalid <- lengths(fields) != n & lengths(fields) != 1L
  if (any(invalid)) {
    indoor_abort(sprintf(
      "Comment catalogue fields must have length 1 or %d; `%s` has length %d.",
      n, names(fields)[which(invalid)[1]], lengths(fields)[which(invalid)[1]]
    ))
  }
  fields <- lapply(names(fields), function(name) {
    value <- fields[[name]]
    if (!is.atomic(value) || is.raw(value) || is.complex(value)) {
      indoor_abort(sprintf("Comment catalogue column `%s` must be an atomic vector.", name))
    }
    value <- as.character(value)
    if (length(value) == 1L && n > 1L) value <- rep(value, n)
    required <- name %in% c("layerId", "text")
    if (anyNA(value) || (required && any(!nzchar(trimws(value))))) {
      indoor_abort(sprintf("Comment catalogue column `%s` contains a missing or empty value.", name))
    }
    unname(value)
  })
  names(fields) <- c("layerId", "text", "author", "date", "source", "title")
  invalid_sources <- nzchar(fields$source) &
    (!grepl("^https?://[^/?#[:space:]]+", fields$source, ignore.case = TRUE) |
       grepl("[[:space:][:cntrl:]]", fields$source))
  if (any(invalid_sources)) {
    indoor_abort("Comment catalogue column `source` must contain absolute HTTP(S) URLs or empty strings.")
  }
  structure(as.data.frame(fields, stringsAsFactors = FALSE),
            class = c("leaflet_indoor_comments", "data.frame"))
}

normalize_comment_catalog <- function(comments) {
  if (is.null(comments)) return(indoorCommentCatalog(character(), character()))
  if (!is.data.frame(comments)) {
    indoor_abort("`comments` must be a data frame created by `indoorCommentCatalog()` or with equivalent columns.")
  }
  required <- c("layerId", "text")
  absent <- setdiff(required, names(comments))
  if (length(absent)) {
    indoor_abort(sprintf("`comments` is missing required column(s): %s.", paste(absent, collapse = ", ")))
  }
  fields <- lapply(c(required, "author", "date", "source", "title"), function(name) {
    if (name %in% names(comments)) comments[[name]] else ""
  })
  names(fields) <- c(required, "author", "date", "source", "title")
  do.call(indoorCommentCatalog, fields)
}

resolve_room_comments <- function(comments, ids) {
  catalogue <- normalize_comment_catalog(comments)
  if (nrow(catalogue) == 0L) return(rep(list(NULL), length(ids)))
  known <- unlist(ids, use.names = FALSE)
  if (!length(known)) {
    indoor_abort("`comments` requires non-missing feature identifiers supplied through `layerId`.")
  }
  unknown <- setdiff(catalogue$layerId, known)
  if (length(unknown)) {
    indoor_abort(sprintf(
      "`comments$layerId` contains identifier(s) not present in `layerId`: %s.",
      paste(dQuote(unknown), collapse = ", ")
    ))
  }
  lapply(ids, function(id) {
    if (is.null(id)) return(NULL)
    rows <- which(catalogue$layerId == id)
    if (!length(rows)) return(NULL)
    lapply(rows, function(row) as.list(catalogue[row, c("text", "author", "date", "source", "title")]))
  })
}

# Compute an anchor on the feature surface, including concave rooms and holes.
# Indoor coordinates use a planar calculation in the normalized map units.
comment_position <- function(feature) {
  geometry_json <- jsonlite::toJSON(feature$geometry, auto_unbox = TRUE, digits = NA)
  geometry <- sf::st_as_sfc(as.character(geometry_json), GeoJSON = TRUE)
  geometry <- sf::st_set_crs(geometry, NA)
  coordinates <- sf::st_coordinates(sf::st_point_on_surface(geometry))
  if (nrow(coordinates) != 1L || any(!is.finite(coordinates[1, 1:2]))) {
    indoor_abort("A comment icon requires a non-empty feature geometry.")
  }
  list(lng = unname(coordinates[1, 1]), lat = unname(coordinates[1, 2]))
}
