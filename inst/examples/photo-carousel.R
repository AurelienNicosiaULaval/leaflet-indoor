# Reproducible photo-carousel example using only package assets.
library(leaflet)
library(leaflet.indoor)

photo_directory <- system.file("examples", "photos", package = "leaflet.indoor")
room_photos <- indoorPhotoCatalog(
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

leaflet(
  indoor_demo,
  options = leafletOptions(crs = leafletCRS("L.CRS.Simple"), minZoom = -2)
) |>
  addIndoor(
    layerId = ~feature_id,
    photos = room_photos,
    label = ~name,
    popup = ~description,
    style = list(fillColor = ~fill),
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
