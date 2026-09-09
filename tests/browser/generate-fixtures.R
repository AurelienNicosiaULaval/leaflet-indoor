library(leaflet)
library(leaflet.indoor)
library(htmltools)
library(htmlwidgets)

file_argument <- grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)
script_path <- normalizePath(sub("^--file=", "", file_argument[[1]]))
package_root <- normalizePath(file.path(dirname(script_path), "..", ".."))
output_dir <- file.path(package_root, "tests", "browser", "output")
if (dir.exists(output_dir)) unlink(output_dir, recursive = TRUE)
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
file.create(file.path(output_dir, "favicon.ico"))

simple_map <- function(data = indoor_demo, element_id = NULL) {
  leaflet(
    data,
    width = "100%",
    height = 520,
    elementId = element_id,
    options = leafletOptions(
      crs = leafletCRS("L.CRS.Simple"),
      minZoom = -2
    )
  ) |>
    addIndoor(
      label = ~name,
      popup = ~description,
      layerId = ~feature_id,
      style = list(fillColor = ~fill),
      crs = "simple"
    ) |>
    addIndoorControl(position = "bottomright")
}

saveWidget(
  simple_map(element_id = "single-map"),
  file.path(output_dir, "single.html"),
  selfcontained = FALSE,
  title = "Single indoor map"
)
saveWidget(
  leaflet(indoor_demo_geo, height = 520, elementId = "geographic-map") |>
    addIndoor(
      label = ~name,
      popup = ~description,
      style = list(fillColor = ~fill)
    ) |>
    addIndoorControl(),
  file.path(output_dir, "geographic.html"),
  selfcontained = FALSE,
  title = "Geographic indoor map"
)

two_maps <- browsable(tagList(
  tags$style(HTML(paste0(
    ".map-grid{display:grid;grid-template-columns:1fr 1fr;gap:1rem}",
    ".html-widget{min-height:420px}",
    "@media(max-width:700px){.map-grid{grid-template-columns:1fr}}"
  ))),
  tags$div(class = "map-grid",
    tags$div(simple_map(element_id = "map-one")),
    tags$div(simple_map(element_id = "map-two"))
  )
))
save_html(two_maps, file.path(output_dir, "two-maps.html"), background = "white")

multi_data <- leaflet(
  indoor_demo,
  width = "100%",
  height = 520,
  elementId = "multi-data-map",
  options = leafletOptions(crs = leafletCRS("L.CRS.Simple"), minZoom = -2)
) |>
  addIndoor(
    dataset_id = "rooms",
    initial_level = "0",
    label = ~name,
    style = list(color = "#0b5cab", fillColor = ~fill),
    crs = "simple"
  ) |>
  addIndoorControl(
    dataset_id = "rooms",
    control_id = "rooms-control",
    position = "bottomright",
    options = indoorControlOptions(title = "Rooms")
  ) |>
  addIndoor(
    data = indoor_demo[4:5, ],
    dataset_id = "services",
    initial_level = "1",
    label = ~name,
    style = list(color = "#a23b00", fillColor = "#f28e2b"),
    crs = "simple"
  ) |>
  addIndoorControl(
    dataset_id = "services",
    control_id = "services-control",
    position = "bottomleft",
    options = indoorControlOptions(title = "Services")
  )

saveWidget(
  multi_data,
  file.path(output_dir, "multi-data.html"),
  selfcontained = FALSE,
  title = "Multiple indoor data sets"
)

photo_directory <- system.file("examples", "photos", package = "leaflet.indoor")
photo_catalogue <- indoorPhotoCatalog(
  layerId = c("feature-01", "feature-01", "feature-02"),
  src = file.path(photo_directory, c(
    "meeting-room-entrance.svg",
    "meeting-room-window.svg",
    "laboratory-workbench.svg"
  )),
  caption = c(
    "Entrance view of the synthetic meeting room.",
    paste(
      "Window-side view. This deliberately longer caption demonstrates that",
      "the popup grows and keeps the complete caption and all controls visible."
    ),
    "Workbench view of the synthetic teaching laboratory."
  )
)

photo_map <- leaflet(
  indoor_demo,
  width = "100%",
  height = 600,
  elementId = "photo-map",
  options = leafletOptions(crs = leafletCRS("L.CRS.Simple"), minZoom = -2)
) |>
  addIndoor(
    layerId = ~feature_id,
    photos = photo_catalogue,
    label = ~name,
    popup = ~description,
    style = list(fillColor = ~fill),
    popupOptions = popupOptions(maxWidth = 360),
    photoOptions = indoorPhotoOptions(
      previous_label = "Précédent",
      next_label = "Suivant",
      enlarge_label = "Agrandir",
      close_label = "Fermer",
      carousel_label = "Photos de la pièce",
      dialog_label = "Photo agrandie de la pièce",
      counter_label = "Photo {current} sur {total}",
      unavailable_label = "Image indisponible"
    ),
    crs = "simple"
  ) |>
  addIndoorControl(position = "bottomright")

saveWidget(
  photo_map,
  file.path(output_dir, "photo-carousel.html"),
  selfcontained = FALSE,
  title = "Indoor room photo carousel"
)

louvre_rooms <- sf::st_read(
  system.file(
    "examples", "real", "louvre-rooms.geojson",
    package = "leaflet.indoor"
  ),
  quiet = TRUE
)
louvre_photo_directory <- system.file(
  "examples", "real", "photos",
  package = "leaflet.indoor"
)
louvre_photos <- indoorPhotoCatalog(
  layerId = c(
    rep("osm-way-394887893", 2),
    "osm-way-453817508",
    rep("osm-way-367790015", 2)
  ),
  src = file.path(louvre_photo_directory, c(
    "louvre-caryatides-main.jpg",
    "louvre-caryatides-reopening.jpg",
    "louvre-venus-room.jpg",
    "louvre-apollon-main.jpg",
    "louvre-apollon-ceiling.jpg"
  )),
  caption = c(
    "Salle des Caryatides. Photo: Wilfredor, CC0 1.0.",
    "Salle des Caryatides. Photo: Tangopaso, public domain.",
    "Salle de la Vénus de Milo. Photo: Shonagon, CC0 1.0.",
    "Galerie d'Apollon. Photo: Wilfredor, CC0 1.0.",
    "Ceiling of the Galerie d'Apollon. Photo: Gary Todd, CC0 1.0."
  )
)
photo_room_names <- c(
  "Salle des Caryatides",
  "Salle de la Vénus de Milo",
  "Galerie d'Apollon"
)
louvre_rooms$fill <- ifelse(
  louvre_rooms$name %in% photo_room_names,
  "#c43c2e",
  c(`-2` = "#6b7280", `0` = "#2f7d65", `1` = "#3568a8")[louvre_rooms$level]
)
louvre_map <- leaflet(
  louvre_rooms,
  width = "100%",
  height = 480,
  elementId = "louvre-map"
) |>
  addTiles() |>
  addIndoor(
    level_order = c("-2", "0", "1"),
    initial_level = "0",
    layerId = ~feature_id,
    photos = louvre_photos,
    label = ~name,
    popup = ~paste0(name, ". Level ", level, ". ", description),
    style = list(
      color = "#17324d",
      weight = 2,
      fillColor = ~fill,
      fillOpacity = 0.72
    ),
    popupOptions = popupOptions(keepInView = TRUE)
  ) |>
  addIndoorControl(
    position = "bottomright",
    options = indoorControlOptions(title = "Louvre level")
  )

saveWidget(
  louvre_map,
  file.path(output_dir, "real-world.html"),
  selfcontained = FALSE,
  title = "Real Louvre indoor map"
)

rmarkdown::render(
  file.path(package_root, "inst", "examples", "rmarkdown", "indoor-map.Rmd"),
  output_file = "rmarkdown-example.html",
  output_dir = output_dir,
  quiet = TRUE,
  envir = new.env(parent = globalenv())
)

quarto::quarto_render(
  file.path(package_root, "inst", "examples", "quarto", "indoor-map.qmd"),
  output_file = "quarto-example.html",
  quarto_args = c("--output-dir", output_dir),
  quiet = TRUE
)
