# Rebuild the real-world Louvre example bundled with the package.
#
# This script reads a dated OpenStreetMap API snapshot and downloads pinned
# Wikimedia Commons derivatives. Generated files are committed so package
# builds remain offline.

library(sf)
library(xml2)

output_directory <- file.path("inst", "examples", "real")
photo_directory <- file.path(output_directory, "photos")
dir.create(photo_directory, recursive = TRUE, showWarnings = FALSE)

osm_snapshot <- file.path("data-raw", "louvre-osm-2026-09-08.osm.gz")
if (!file.exists(osm_snapshot)) {
  stop("The dated OpenStreetMap source snapshot is missing.")
}
osm_connection <- gzfile(osm_snapshot, open = "rb")
document <- read_xml(osm_connection)
close(osm_connection)
node_elements <- xml_find_all(document, ".//node")
node_ids <- xml_attr(node_elements, "id")
node_coordinates <- cbind(
  longitude = as.numeric(xml_attr(node_elements, "lon")),
  latitude = as.numeric(xml_attr(node_elements, "lat"))
)
rownames(node_coordinates) <- node_ids

tag_value <- function(way, key) {
  tag <- xml_find_first(way, sprintf("./tag[@k='%s']", key))
  if (inherits(tag, "xml_missing")) NA_character_ else xml_attr(tag, "v")
}

way_elements <- xml_find_all(document, ".//way")
selected_ways <- way_elements[vapply(way_elements, function(way) {
  indoor <- tag_value(way, "indoor")
  level <- tag_value(way, "level")
  name <- tag_value(way, "name")
  !is.na(name) && nzchar(name) &&
    indoor %in% c("room", "area") &&
    level %in% c("-2", "0", "1")
}, logical(1))]

if (length(selected_ways) != 135L) {
  stop("The dated OpenStreetMap snapshot must contain 135 named indoor spaces.")
}

room_records <- lapply(selected_ways, function(way) {
  way_id <- xml_attr(way, "id")
  way_version <- xml_attr(way, "version")
  node_references <- xml_attr(xml_find_all(way, "./nd"), "ref")
  coordinates <- node_coordinates[node_references, , drop = FALSE]
  if (anyNA(coordinates) || !identical(coordinates[1, ], coordinates[nrow(coordinates), ])) {
    stop(sprintf("OpenStreetMap way %s is incomplete or not closed.", way_id))
  }
  list(
    feature_id = paste0("osm-way-", way_id),
    osm_way_id = way_id,
    osm_version = way_version,
    level = tag_value(way, "level"),
    name = tag_value(way, "name"),
    description = tag_value(way, "description"),
    geometry = st_polygon(list(coordinates))
  )
})

louvre_rooms <- st_sf(
  feature_id = vapply(room_records, `[[`, character(1), "feature_id"),
  osm_way_id = vapply(room_records, `[[`, character(1), "osm_way_id"),
  osm_version = vapply(room_records, `[[`, character(1), "osm_version"),
  level = vapply(room_records, `[[`, character(1), "level"),
  name = vapply(room_records, `[[`, character(1), "name"),
  description = vapply(room_records, function(x) {
    if (is.na(x$description)) "Mapped indoor room at the Louvre Museum." else x$description
  }, character(1)),
  source_url = paste0(
    "https://www.openstreetmap.org/way/",
    vapply(room_records, `[[`, character(1), "osm_way_id")
  ),
  geometry = st_sfc(lapply(room_records, `[[`, "geometry"), crs = 4326)
)
louvre_rooms <- louvre_rooms[order(as.numeric(louvre_rooms$level), louvre_rooms$name), ]

st_write(
  louvre_rooms,
  file.path(output_directory, "louvre-rooms.geojson"),
  delete_dsn = TRUE,
  quiet = TRUE,
  layer_options = "RFC7946=YES"
)

photo_sources <- c(
  "louvre-caryatides-main.jpg" = paste0(
    "https://thumb.wikimedia.org/wikipedia/commons/thumb/3/30/",
    "Salle_des_Caryatides%2C_Louvre%2C_Paris.jpg/",
    "1280px-Salle_des_Caryatides%2C_Louvre%2C_Paris.jpg"
  ),
  "louvre-caryatides-reopening.jpg" = paste0(
    "https://thumb.wikimedia.org/wikipedia/commons/thumb/9/96/",
    "Salle_des_Caryatides_d%C3%A9serte_%C3%A0_la_r%C3%A9ouverture_du_Louvre.jpg/",
    "1280px-Salle_des_Caryatides_d%C3%A9serte_",
    "%C3%A0_la_r%C3%A9ouverture_du_Louvre.jpg"
  )
)

photo_checksums <- c(
  "louvre-caryatides-main.jpg" = "489575dc45072fee2cba3658ba808c68",
  "louvre-caryatides-reopening.jpg" = "68dc4311bf9fc7cb014ac15041a6a2f0"
)

for (file_name in names(photo_sources)) {
  destination <- file.path(photo_directory, file_name)
  download.file(photo_sources[[file_name]], destination, mode = "wb", quiet = FALSE)
  checksum <- unname(tools::md5sum(destination))
  if (!identical(checksum, unname(photo_checksums[[file_name]]))) {
    stop(sprintf("Downloaded photo %s did not match its expected checksum.", file_name))
  }
}
