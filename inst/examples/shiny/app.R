library(shiny)
library(leaflet)
library(leaflet.indoor)

ui <- fluidPage(
  titlePanel("leaflet.indoor Shiny example"),
  actionButton("floor_zero", "Show floor 0"),
  actionButton("floor_two", "Show floor 2"),
  tags$div(id = "selected-floor", verbatimTextOutput("selected_floor")),
  tags$div(id = "selected-feature", verbatimTextOutput("selected_feature")),
  leafletOutput("map", height = 520)
)

server <- function(input, output, session) {
  output$map <- renderLeaflet({
    leaflet(
      indoor_demo,
      options = leafletOptions(crs = leafletCRS("L.CRS.Simple"))
    ) |>
      addIndoor(
        label = ~name,
        popup = ~description,
        layerId = ~feature_id,
        style = list(fillColor = ~fill),
        crs = "simple"
      ) |>
      addIndoorControl(position = "bottomright")
  })

  observeEvent(input$floor_zero, {
    leafletProxy("map", session) |> setIndoorLevel("0")
  })

  observeEvent(input$floor_two, {
    leafletProxy("map", session) |> setIndoorLevel("2")
  })

  output$selected_floor <- renderPrint(input$map_indoor_level)
  output$selected_feature <- renderPrint(input$map_indoor_feature_click)
}

shinyApp(ui, server)
