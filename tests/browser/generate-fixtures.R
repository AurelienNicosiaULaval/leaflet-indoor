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
