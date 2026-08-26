`%||%` <- function(x, y) if (is.null(x)) y else x

indoor_abort <- function(message) {
  stop(message, call. = FALSE)
}

assert_scalar_string <- function(x, name) {
  if (!is.character(x) || length(x) != 1L || is.na(x) || !nzchar(trimws(x))) {
    indoor_abort(sprintf("`%s` must be one non-empty string.", name))
  }
  invisible(x)
}

assert_scalar_logical <- function(x, name) {
  if (!is.logical(x) || length(x) != 1L || is.na(x)) {
    indoor_abort(sprintf("`%s` must be TRUE or FALSE.", name))
  }
  invisible(x)
}

assert_map <- function(map) {
  if (!inherits(map, "leaflet") && !inherits(map, "leaflet_proxy")) {
    indoor_abort("`map` must be a leaflet map or a leaflet proxy.")
  }
  invisible(map)
}

indoor_dependency <- function() {
  htmltools::htmlDependency(
    name = "leaflet-indoor",
    version = "0.1.0",
    src = c(file = system.file("htmlwidgets", package = "leaflet.indoor")),
    script = "leaflet-indoor.js",
    stylesheet = "leaflet-indoor.css",
    all_files = FALSE
  )
}

register_indoor_dependency <- function(map) {
  dep <- indoor_dependency()
  deps <- map$dependencies %||% list()
  existing <- vapply(
    deps,
    function(x) identical(x$name, dep$name),
    logical(1)
  )
  map$dependencies <- c(deps[!existing], list(dep))
  map
}

get_indoor_meta <- function(map) {
  attr(map, "leaflet.indoor", exact = TRUE) %||%
    list(datasets = list(), controls = list())
}

set_indoor_meta <- function(map, meta) {
  attr(map, "leaflet.indoor") <- meta
  map
}

map_crs_class <- function(map) {
  if (!inherits(map, "leaflet")) return(NULL)
  map$x$options$crs$crsClass %||% "L.CRS.EPSG3857"
}

resolve_crs_mode <- function(map, crs, has_sf_crs, data_kind, n_features) {
  crs <- match.arg(crs, c("auto", "geographic", "simple"))
  map_crs <- map_crs_class(map)
  if (!is.null(map_crs) && identical(crs, "simple") &&
        !identical(map_crs, "L.CRS.Simple")) {
    indoor_abort(
      paste0(
        "`crs = \"simple\"` requires a map created with ",
        "`leaflet::leafletOptions(crs = leaflet::leafletCRS(\"L.CRS.Simple\"))`."
      )
    )
  }
  if (!is.null(map_crs) && identical(crs, "geographic") &&
        identical(map_crs, "L.CRS.Simple")) {
    indoor_abort("`crs = \"geographic\"` is incompatible with a map using `L.CRS.Simple`.")
  }
  if (crs != "auto") return(crs)

  if (!is.null(map_crs)) {
    return(if (identical(map_crs, "L.CRS.Simple")) "simple" else "geographic")
  }

  if (identical(data_kind, "geojson")) return("geographic")
  if (n_features == 0L) return("geographic")
  if (has_sf_crs) return("geographic")

  indoor_abort(
    "`crs = \"auto\"` cannot infer local coordinates for a leaflet proxy; use `crs = \"simple\"`."
  )
}

natural_text_key <- function(x) {
  vapply(x, function(value) {
    parts <- regmatches(tolower(value), gregexpr("[0-9]+|[^0-9]+", tolower(value), perl = TRUE))[[1]]
    paste(vapply(parts, function(part) {
      if (grepl("^[0-9]+$", part)) {
        paste0("#", formatC(as.numeric(part), width = 24, format = "f", digits = 0, flag = "0"))
      } else {
        paste0("~", part)
      }
    }, character(1)), collapse = "")
  }, character(1))
}

natural_level_order <- function(levels) {
  levels <- as.character(levels)
  if (length(levels) == 0L) return(character())
  basement <- grepl("^[Bb][0-9]+(?:\\.[0-9]+)?$", levels, perl = TRUE)
  numeric_level <- grepl("^[+-]?(?:[0-9]+(?:\\.[0-9]*)?|\\.[0-9]+)$", levels, perl = TRUE)
  numeric_value <- rep(Inf, length(levels))
  numeric_value[basement] <- -as.numeric(sub("^[Bb]", "", levels[basement]))
  numeric_value[numeric_level] <- as.numeric(levels[numeric_level])
  numeric_like <- basement | numeric_level
  levels[order(
    !numeric_like,
    numeric_value,
    natural_text_key(levels),
    tolower(levels),
    levels,
    method = "radix"
  )]
}

normalize_level_value <- function(x, row) {
  if (is.factor(x)) x <- as.character(x)
  if (is.list(x)) {
    flat <- vapply(x, function(value) !is.list(value) && length(value) <= 1L, logical(1))
    if (!all(flat)) {
      indoor_abort(sprintf("`level` contains an unsupported value in feature %d.", row))
    }
    x <- unlist(x, recursive = FALSE, use.names = FALSE)
  }
  if (is.logical(x) || is.raw(x) || is.complex(x)) {
    indoor_abort(sprintf("`level` contains an unsupported value in feature %d.", row))
  }
  if (!is.character(x) && !is.numeric(x) && !is.integer(x)) {
    indoor_abort(sprintf("`level` contains an unsupported value in feature %d.", row))
  }
  if (is.numeric(x) && any(!is.na(x) & !is.finite(x))) {
    indoor_abort(sprintf("`level` contains a non-finite value in feature %d.", row))
  }
  as.character(x)
}

normalize_levels <- function(raw, level_order = NULL, missing_level = "error") {
  n <- length(raw)
  is_factor_column <- is.factor(raw)
  factor_levels <- if (is_factor_column) levels(raw) else NULL
  entries <- if (is.list(raw) && !is.data.frame(raw)) raw else as.list(raw)
  normalized <- vector("list", n)
  affected <- logical(n)

  for (i in seq_len(n)) {
    value <- normalize_level_value(entries[[i]], i)
    missing <- is.na(value) | !nzchar(trimws(value))
    affected[i] <- any(missing) || length(value) == 0L
    value <- unique(value[!missing])
    normalized[[i]] <- value
  }

  if (any(affected) && identical(missing_level, "error")) {
    rows <- paste(which(affected), collapse = ", ")
    indoor_abort(sprintf("`level` contains missing or empty values in feature(s): %s.", rows))
  }

  keep <- lengths(normalized) > 0L
  if (any(affected) && identical(missing_level, "drop")) {
    warning(
      sprintf("`missing_level = \"drop\"` affected %d feature(s); %d feature(s) had no valid level and were removed.",
        sum(affected), sum(!keep)
      ),
      call. = FALSE
    )
  }

  observed <- as.character(unique(unlist(normalized[keep], use.names = FALSE)))
  if (!is.null(level_order)) {
    if (is.factor(level_order)) level_order <- as.character(level_order)
    if (!is.atomic(level_order) || is.list(level_order)) {
      indoor_abort("`level_order` must be an atomic vector.")
    }
    level_order <- as.character(level_order)
    if (anyNA(level_order) || any(!nzchar(trimws(level_order))) || anyDuplicated(level_order)) {
      indoor_abort("`level_order` must contain unique, non-missing, non-empty values.")
    }
    if (!setequal(level_order, observed) || length(level_order) != length(observed)) {
      indoor_abort("`level_order` must contain each observed level exactly once.")
    }
    ordered <- level_order
  } else if (is_factor_column) {
    ordered <- factor_levels[factor_levels %in% observed]
  } else if (is.numeric(raw) || is.integer(raw)) {
    values <- sort(unique(raw[!is.na(raw)]))
    ordered <- as.character(values)
  } else {
    ordered <- natural_level_order(observed)
  }

  list(values = normalized, keep = keep, order = ordered)
}

validate_initial_level <- function(initial_level, levels) {
  if (length(levels) == 0L) {
    if (!is.null(initial_level)) {
      indoor_abort("`initial_level` cannot be supplied when the indoor data are empty.")
    }
    return(NULL)
  }
  if (is.null(initial_level)) {
    return(if ("0" %in% levels) "0" else levels[[1]])
  }
  if (length(initial_level) != 1L || is.na(initial_level)) {
    indoor_abort("`initial_level` must be one non-missing level.")
  }
  initial_level <- as.character(initial_level)
  if (!initial_level %in% levels) {
    indoor_abort(sprintf("`initial_level` is %s, but that level is not present.", dQuote(initial_level)))
  }
  initial_level
}
