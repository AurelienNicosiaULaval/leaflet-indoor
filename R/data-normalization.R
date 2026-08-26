normalize_indoor_data <- function(data, map, level, level_missing, level_order,
                                  initial_level, missing_level, crs) {
  if (is.null(data)) {
    indoor_abort("`data` is NULL; supply an sf, sfc, SpatVector, or GeoJSON object.")
  }

  if (inherits(data, "SpatVector")) {
    if (!requireNamespace("terra", quietly = TRUE)) {
      indoor_abort("A `SpatVector` requires the suggested package `terra`.")
    }
    data <- sf::st_as_sf(data)
  }

  if (inherits(data, "sf") || inherits(data, "sfc")) {
    normalized <- normalize_sf_input(data, map, level, level_missing, crs)
  } else {
    normalized <- normalize_geojson_input(data, map, level, crs)
  }

  level_info <- normalize_levels(
    normalized$raw_levels,
    level_order = level_order,
    missing_level = missing_level
  )
  keep <- level_info$keep
  normalized$features <- normalized$features[keep]
  normalized$eval_data <- normalized$eval_data[keep, , drop = FALSE]
  normalized$levels <- level_info$values[keep]
  normalized$level_order <- level_info$order
  normalized$initial_level <- validate_initial_level(initial_level, level_info$order)
  normalized
}

normalize_sf_input <- function(data, map, level, level_missing, crs) {
  bare_sfc <- inherits(data, "sfc") && !inherits(data, "sf")
  if (bare_sfc) {
    n <- length(data)
    if (level_missing) {
      indoor_abort("A bare `sfc` requires explicit `level` values.")
    }
    if (length(level) != n) {
      indoor_abort(sprintf("For a bare `sfc`, `level` must have length %d.", n))
    }
    raw_levels <- level
    eval_data <- data.frame(.feature = seq_len(n))
    sf_data <- sf::st_sf(eval_data, geometry = data)
  } else {
    sf_data <- data
    n <- nrow(sf_data)
    if (!is.character(level) || length(level) != 1L || is.na(level)) {
      indoor_abort("For `sf` data, `level` must name one column.")
    }
    if (!level %in% names(sf_data)) {
      indoor_abort(sprintf("`level` names %s, but that column is not present in `data`.", dQuote(level)))
    }
    raw_levels <- sf_data[[level]]
    eval_data <- sf_data
  }

  geometry <- sf::st_geometry(sf_data)
  has_crs <- !is.na(sf::st_crs(geometry))
  mode <- resolve_crs_mode(map, crs, has_crs, "sf", n)

  if (n > 0L && identical(mode, "simple") && has_crs) {
    indoor_abort("`crs = \"simple\"` requires sf data with an undefined CRS; no spatial transformation is performed.")
  }
  if (n > 0L && identical(mode, "geographic") && !has_crs) {
    indoor_abort("Geographic indoor data require a defined CRS so they can be transformed to EPSG:4326.")
  }
  if (n > 0L && identical(mode, "geographic")) {
    sf_data <- sf::st_transform(sf_data, 4326)
    eval_data <- if (inherits(eval_data, "sf")) sf::st_transform(eval_data, 4326) else eval_data
    geometry <- sf::st_geometry(sf_data)
  }

  if (n > 0L) {
    empty <- sf::st_is_empty(geometry)
    if (any(empty)) {
      indoor_abort(sprintf("`data` contains empty geometries in feature(s): %s.", paste(which(empty), collapse = ", ")))
    }
    types <- as.character(sf::st_geometry_type(geometry, by_geometry = TRUE))
    supported <- c("POINT", "MULTIPOINT", "LINESTRING", "MULTILINESTRING",
                   "POLYGON", "MULTIPOLYGON", "GEOMETRYCOLLECTION")
    if (any(!types %in% supported)) {
      indoor_abort(sprintf("`data` contains unsupported geometry type(s): %s.",
        paste(unique(types[!types %in% supported]), collapse = ", ")
      ))
    }
  }

  features <- sf_geometry_features(geometry)
  coords <- coordinates_from_features(features)
  validate_coordinate_ranges(coords, mode)
  list(
    features = features,
    eval_data = eval_data,
    raw_levels = raw_levels,
    coords = coords,
    crs = mode
  )
}

sf_geometry_features <- function(geometry) {
  if (length(geometry) == 0L) return(list())
  index <- seq_along(geometry)
  serialization_geometry <- geometry
  if (is.na(sf::st_crs(serialization_geometry))) {
    sf::st_crs(serialization_geometry) <- 4326
  }
  holder <- sf::st_sf(.leaflet_indoor_index = index, geometry = serialization_geometry)
  path <- tempfile(fileext = ".geojson")
  on.exit(unlink(path), add = TRUE)
  suppressWarnings(sf::st_write(holder, path, driver = "GeoJSON", quiet = TRUE, delete_dsn = TRUE))
  parsed <- jsonlite::read_json(path, simplifyVector = FALSE)
  parsed$features
}

parse_geojson <- function(data) {
  if (is.character(data)) {
    if (length(data) != 1L || is.na(data)) {
      indoor_abort("Character GeoJSON input must be one non-missing string or file path.")
    }
    if (grepl("^https?://", data, ignore.case = TRUE)) {
      indoor_abort("Remote GeoJSON URLs are not read automatically; download the data explicitly first.")
    }
    tryCatch(
      if (file.exists(data)) {
        jsonlite::read_json(data, simplifyVector = FALSE)
      } else {
        jsonlite::fromJSON(data, simplifyVector = FALSE)
      },
      error = function(e) indoor_abort(sprintf("`data` is not valid GeoJSON: %s", conditionMessage(e)))
    )
  } else if (is.list(data)) {
    data
  } else {
    indoor_abort("`data` must be an sf, sfc, SpatVector, or GeoJSON object.")
  }
}

normalize_geojson_input <- function(data, map, level, crs) {
  root <- parse_geojson(data)
  if (identical(root$type, "FeatureCollection")) {
    features <- root$features %||% list()
  } else if (identical(root$type, "Feature")) {
    features <- list(root)
  } else if (is.null(root$type) && is.list(root) &&
               all(vapply(root, function(x) identical(x$type, "Feature"), logical(1)))) {
    features <- root
  } else {
    indoor_abort("GeoJSON `data` must be a Feature, FeatureCollection, or list of Features.")
  }

  for (i in seq_along(features)) {
    feature <- features[[i]]
    if (!identical(feature$type, "Feature") || is.null(feature$geometry)) {
      indoor_abort(sprintf("GeoJSON feature %d has no valid geometry.", i))
    }
    validate_geojson_geometry(feature$geometry, i)
    if (is.null(feature$properties)) feature$properties <- list()
    features[[i]] <- feature
  }

  properties <- lapply(features, function(x) x$properties %||% list())
  eval_data <- properties_data_frame(properties)
  if (!is.character(level) || length(level) != 1L || is.na(level)) {
    indoor_abort("For GeoJSON data, `level` must name one feature property.")
  }
  if (!level %in% names(eval_data)) {
    indoor_abort(sprintf("`level` names %s, but that property is not present in the GeoJSON data.", dQuote(level)))
  }
  raw_levels <- eval_data[[level]]
  if (is.list(raw_levels)) {
    raw_levels <- lapply(raw_levels, function(x) x %||% NA_character_)
  }

  mode <- resolve_crs_mode(map, crs, identical(crs, "geographic"), "geojson", length(features))
  coords <- coordinates_from_features(features)
  validate_coordinate_ranges(coords, mode)
  list(
    features = features,
    eval_data = eval_data,
    raw_levels = raw_levels,
    coords = coords,
    crs = mode
  )
}

validate_geojson_geometry <- function(geometry, feature_index) {
  supported <- c("Point", "MultiPoint", "LineString", "MultiLineString",
                 "Polygon", "MultiPolygon", "GeometryCollection")
  if (!is.character(geometry$type) || length(geometry$type) != 1L ||
        !geometry$type %in% supported) {
    indoor_abort(sprintf("GeoJSON feature %d has an unsupported geometry type.", feature_index))
  }
  if (identical(geometry$type, "GeometryCollection")) {
    geoms <- geometry$geometries %||% list()
    if (length(geoms) == 0L) {
      indoor_abort(sprintf("GeoJSON feature %d contains an empty GeometryCollection.", feature_index))
    }
    for (geom in geoms) validate_geojson_geometry(geom, feature_index)
  } else if (is.null(geometry$coordinates)) {
    indoor_abort(sprintf("GeoJSON feature %d has no coordinates.", feature_index))
  }
  invisible(geometry)
}

properties_data_frame <- function(properties) {
  n <- length(properties)
  names_all <- unique(unlist(lapply(properties, names), use.names = FALSE))
  if (length(names_all) == 0L) return(data.frame(row.names = seq_len(n)))
  columns <- lapply(names_all, function(name) {
    values <- lapply(properties, function(x) x[[name]] %||% NA)
    scalar <- vapply(values, function(x) !is.list(x) && length(x) <= 1L, logical(1))
    if (all(scalar)) unlist(values, recursive = FALSE, use.names = FALSE) else I(values)
  })
  names(columns) <- names_all
  as.data.frame(columns, optional = TRUE, stringsAsFactors = FALSE)
}

coordinates_from_features <- function(features) {
  matrices <- lapply(features, function(feature) coordinates_from_geometry(feature$geometry))
  matrices <- matrices[vapply(matrices, nrow, integer(1)) > 0L]
  if (length(matrices) == 0L) return(matrix(numeric(), ncol = 2L))
  do.call(rbind, matrices)
}

coordinates_from_geometry <- function(geometry) {
  if (identical(geometry$type, "GeometryCollection")) {
    pieces <- lapply(geometry$geometries %||% list(), coordinates_from_geometry)
    pieces <- pieces[vapply(pieces, nrow, integer(1)) > 0L]
    if (length(pieces) == 0L) return(matrix(numeric(), ncol = 2L))
    return(do.call(rbind, pieces))
  }
  coordinate_pairs(geometry$coordinates)
}

coordinate_pairs <- function(x) {
  if (is.atomic(x) && is.numeric(x)) {
    if (length(x) < 2L) return(matrix(numeric(), ncol = 2L))
    return(matrix(as.numeric(x[1:2]), nrow = 1L))
  }
  if (is.list(x) && length(x) >= 2L &&
        all(vapply(x[1:2], function(v) is.numeric(v) && length(v) == 1L, logical(1)))) {
    return(matrix(c(x[[1]], x[[2]]), nrow = 1L))
  }
  if (!is.list(x) || length(x) == 0L) return(matrix(numeric(), ncol = 2L))
  pieces <- lapply(x, coordinate_pairs)
  pieces <- pieces[vapply(pieces, nrow, integer(1)) > 0L]
  if (length(pieces) == 0L) return(matrix(numeric(), ncol = 2L))
  do.call(rbind, pieces)
}

validate_coordinate_ranges <- function(coords, mode) {
  if (nrow(coords) == 0L) return(invisible(coords))
  if (any(!is.finite(coords))) {
    indoor_abort("`data` contains non-finite coordinates.")
  }
  if (identical(mode, "geographic") &&
        (any(coords[, 1] < -180 | coords[, 1] > 180) ||
           any(coords[, 2] < -90 | coords[, 2] > 90))) {
    indoor_abort("Geographic coordinates must use longitude in [-180, 180] and latitude in [-90, 90].")
  }
  invisible(coords)
}
