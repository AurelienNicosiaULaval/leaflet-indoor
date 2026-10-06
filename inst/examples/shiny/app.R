library(shiny)
library(leaflet)
library(leaflet.indoor)

ui <- fluidPage(
  titlePanel("leaflet.indoor Shiny example"),
  actionButton("floor_zero", "Show floor 0"),
  actionButton("floor_two", "Show floor 2"),
  actionButton("hide_comments", "Hide comments"),
  actionButton("clear_indoor", "Clear indoor map"),
  tags$div(id = "selected-floor", verbatimTextOutput("selected_floor")),
  tags$div(id = "selected-feature", verbatimTextOutput("selected_feature")),
  tags$div(id = "selected-comment", verbatimTextOutput("selected_comment")),
  leafletOutput("map", height = 520)
)

server <- function(input, output, session) {
  comments <- indoorCommentCatalog(
    "feature-06", "A fictional visitor comment about the reading room.",
    author = "Example visitor", title = "Fictional demonstration comment"
  )
  add_rooms <- function(map, show_comments = TRUE) {
    addIndoor(map, data = indoor_demo,
      label = ~name, popup = ~description, layerId = ~feature_id,
      comments = comments, commentOptions = indoorCommentOptions(show = show_comments),
      style = list(fillColor = ~fill), crs = "simple")
  }
  output$map <- renderLeaflet({
    leaflet(
      indoor_demo,
      options = leafletOptions(crs = leafletCRS("L.CRS.Simple"))
    ) |>
      add_rooms() |>
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
  output$selected_comment <- renderPrint(input$map_indoor_comment_click)

  observeEvent(input$hide_comments, {
    leafletProxy("map", session) |> add_rooms(show_comments = FALSE) |> setIndoorLevel("1")
  })
  observeEvent(input$clear_indoor, {
    leafletProxy("map", session) |> clearIndoor()
  })
}

shinyApp(ui, server)
