# Real-world Louvre example using bundled rooms, photographs, and visitor accounts.
library(leaflet)
library(leaflet.indoor)
library(sf)

louvre_rooms <- st_read(
  system.file(
    "examples", "real", "louvre-rooms.geojson",
    package = "leaflet.indoor"
  ),
  quiet = TRUE
)

photo_directory <- system.file(
  "examples", "real", "photos",
  package = "leaflet.indoor"
)
louvre_photos <- indoorPhotoCatalog(
  layerId = c(
    rep("osm-way-394887893", 2),
    "osm-way-453817508",
    rep("osm-way-367790015", 2)
  ),
  src = file.path(photo_directory, c(
    "louvre-caryatides-main.jpg",
    "louvre-caryatides-reopening.jpg",
    "louvre-venus-room.jpg",
    "louvre-apollon-main.jpg",
    "louvre-apollon-ceiling.jpg"
  )),
  caption = c(
    paste(
      "Salle des Caryatides, photographed in 2024.",
      "Photo: Wilfredor, CC0 1.0, via Wikimedia Commons."
    ),
    paste(
      "Salle des Caryatides shortly after the Louvre reopened in 2021.",
      "Photo: Tangopaso, public domain, via Wikimedia Commons."
    ),
    paste(
      "Salle de la Vénus de Milo, photographed in 2016.",
      "Photo: Shonagon, CC0 1.0, via Wikimedia Commons."
    ),
    paste(
      "Galerie d'Apollon, photographed in 2024.",
      "Photo: Wilfredor, CC0 1.0, via Wikimedia Commons."
    ),
    paste(
      "Ceiling of the Galerie d'Apollon, photographed in 2016.",
      "Photo: Gary Todd, CC0 1.0, via Wikimedia Commons."
    )
  ),
  alt = c(
    "Wide interior view of the Salle des Caryatides at the Louvre",
    "Interior of the Salle des Caryatides with few visitors",
    "Salle de la Vénus de Milo with the sculpture centered in the room",
    "Long interior view of the decorated Galerie d'Apollon",
    "Painted and gilded ceiling of the Galerie d'Apollon"
  )
)

louvre_comments <- read.csv(
  system.file("examples", "real", "louvre-comments.csv", package = "leaflet.indoor"),
  stringsAsFactors = FALSE,
  fileEncoding = "UTF-8"
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

leaflet(louvre_rooms, height = 600) |>
  addTiles() |>
  addIndoor(
    level_order = c("-2", "0", "1"),
    initial_level = "0",
    layerId = ~feature_id,
    photos = louvre_photos,
    comments = louvre_comments,
    commentOptions = indoorCommentOptions(
      icon = "quote",
      marker_label = "Read visitor accounts",
      popup_label = "Visitor accounts",
      source_label = "Read the original account"
    ),
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
