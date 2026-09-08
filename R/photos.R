#' Create an indoor photo catalogue
#'
#' Creates the tabular association used by [addIndoor()] to attach one or more
#' photos to indoor features. Each row associates a `layerId` with one image and
#' its caption. Repeating a `layerId` creates a carousel in row order.
#'
#' Existing local image files are embedded as data URIs so saved widgets,
#' vignettes, Quarto documents, and Shiny applications do not depend on the
#' original file path. Web URLs and relative URLs are retained unchanged.
#'
#' @param layerId Feature identifiers matching the values supplied to the
#'   `layerId` argument of [addIndoor()]. A scalar is recycled.
#' @param src Image sources. These may be HTTP(S) URLs, relative URLs, image
#'   data URIs, or paths to existing PNG, JPEG, GIF, WebP, or SVG files.
#' @param caption Plain-text captions displayed immediately below their images.
#' @param alt Plain-text alternative text. The default uses `caption`.
#'
#' @return A data frame of class `leaflet_indoor_photos` with columns
#'   `layerId`, `src`, `caption`, and `alt`.
#' @export
#'
#' @examples
#' photos <- indoorPhotoCatalog(
#'   layerId = c("room-01", "room-01"),
#'   src = c(
#'     "https://example.org/room-01-a.jpg",
#'     "https://example.org/room-01-b.jpg"
#'   ),
#'   caption = c("Entrance view", "View from the windows")
#' )
#' photos
indoorPhotoCatalog <- function(layerId, src, caption, alt = caption) {
  fields <- list(layerId = layerId, src = src, caption = caption, alt = alt)
  lengths <- lengths(fields)
  n <- max(lengths, 0L)
  if (n == 0L) {
    return(new_photo_catalog(character(), character(), character(), character()))
  }
  invalid_lengths <- lengths != 1L & lengths != n
  if (any(invalid_lengths)) {
    indoor_abort(sprintf(
      "Photo catalogue fields must have length 1 or %d; `%s` has length %d.",
      n, names(fields)[which(invalid_lengths)[1]], lengths[which(invalid_lengths)[1]]
    ))
  }
  fields <- lapply(fields, function(value) {
    if (length(value) == 1L && n > 1L) rep(value, n) else value
  })
  fields <- lapply(names(fields), function(name) {
    validate_photo_text(fields[[name]], name, allow_empty = identical(name, "alt"))
  })
  names(fields) <- c("layerId", "src", "caption", "alt")
  fields$src <- vapply(
    fields$src,
    normalize_photo_source,
    character(1),
    USE.NAMES = FALSE
  )
  new_photo_catalog(fields$layerId, fields$src, fields$caption, fields$alt)
}

new_photo_catalog <- function(layerId, src, caption, alt) {
  structure(
    data.frame(
      layerId = layerId,
      src = src,
      caption = caption,
      alt = alt,
      stringsAsFactors = FALSE,
      check.names = FALSE
    ),
    class = c("leaflet_indoor_photos", "data.frame")
  )
}

validate_photo_text <- function(value, name, allow_empty = FALSE) {
  if (!is.atomic(value) || is.list(value) || is.raw(value) || is.complex(value)) {
    indoor_abort(sprintf("Photo catalogue column `%s` must be an atomic vector.", name))
  }
  value <- as.character(value)
  invalid <- is.na(value) | (!allow_empty & !nzchar(trimws(value)))
  if (any(invalid)) {
    indoor_abort(sprintf(
      "Photo catalogue column `%s` contains a missing or empty value in row(s): %s.",
      name, paste(which(invalid), collapse = ", ")
    ))
  }
  unname(value)
}

normalize_photo_source <- function(src) {
  if (grepl("[\r\n]", src, perl = TRUE)) {
    indoor_abort("Photo catalogue column `src` must not contain line breaks.")
  }
  if (grepl("^\\s*(?:javascript|vbscript):", src, ignore.case = TRUE, perl = TRUE)) {
    indoor_abort(sprintf("Photo source %s uses an unsupported URI scheme.", dQuote(src)))
  }
  if (grepl("^\\s*data:", src, ignore.case = TRUE, perl = TRUE) &&
        !grepl("^\\s*data:image/", src, ignore.case = TRUE, perl = TRUE)) {
    indoor_abort("Photo data URIs must use an `image/*` media type.")
  }
  if (!file.exists(src)) return(src)

  extension <- tolower(sub("^.*\\.", "", src))
  mime <- switch(
    extension,
    png = "image/png",
    jpg = "image/jpeg",
    jpeg = "image/jpeg",
    gif = "image/gif",
    webp = "image/webp",
    svg = "image/svg+xml",
    NULL
  )
  if (is.null(mime)) {
    indoor_abort(sprintf(
      "Local photo %s must be PNG, JPEG, GIF, WebP, or SVG.",
      dQuote(src)
    ))
  }
  size <- file.info(src)$size
  connection <- file(src, open = "rb")
  on.exit(close(connection), add = TRUE)
  bytes <- readBin(connection, what = "raw", n = size)
  encoded <- gsub("[\r\n]", "", jsonlite::base64_enc(bytes), perl = TRUE)
  paste0("data:", mime, ";base64,", encoded)
}

normalize_photo_catalog <- function(photos) {
  if (is.null(photos)) return(new_photo_catalog(character(), character(), character(), character()))
  if (!is.data.frame(photos)) {
    indoor_abort("`photos` must be a data frame created by `indoorPhotoCatalog()` or with equivalent columns.")
  }
  required <- c("layerId", "src", "caption")
  missing_columns <- setdiff(required, names(photos))
  if (length(missing_columns)) {
    indoor_abort(sprintf(
      "`photos` is missing required column(s): %s.",
      paste(missing_columns, collapse = ", ")
    ))
  }
  alt <- if ("alt" %in% names(photos)) photos$alt else photos$caption
  indoorPhotoCatalog(photos$layerId, photos$src, photos$caption, alt)
}

resolve_photo_galleries <- function(photos, ids) {
  catalog <- normalize_photo_catalog(photos)
  if (nrow(catalog) == 0L) return(rep(list(NULL), length(ids)))
  known <- unlist(ids[!vapply(ids, is.null, logical(1))], use.names = FALSE)
  if (length(known) == 0L) {
    indoor_abort("`photos` requires non-missing feature identifiers supplied through `layerId`.")
  }
  unknown <- unique(catalog$layerId[!catalog$layerId %in% known])
  if (length(unknown)) {
    indoor_abort(sprintf(
      "`photos$layerId` contains identifier(s) not present in `layerId`: %s.",
      paste(dQuote(unknown), collapse = ", ")
    ))
  }
  lapply(ids, function(id) {
    if (is.null(id)) return(NULL)
    rows <- which(catalog$layerId == id)
    if (!length(rows)) return(NULL)
    lapply(rows, function(row) {
      list(
        src = unname(catalog$src[[row]]),
        caption = unname(catalog$caption[[row]]),
        alt = unname(catalog$alt[[row]])
      )
    })
  })
}
