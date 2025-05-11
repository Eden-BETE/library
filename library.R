
# ==============================================================================
#                            Chargement des packages
# ==============================================================================

library(shiny)
library(shinydashboard)
library(shinycssloaders) #Animations de chargement
library(shinymanager)
library(DT)
library(reticulate)
library(rstudioapi)
library(openxlsx)
library(readxl)


# ==============================================================================
#                            Définition des chemins
# ==============================================================================

setwd(dirname(rstudioapi::getActiveDocumentContext()$path))


# ==============================================================================
#                              Lecture des données
# ==============================================================================



# ==============================================================================
#                                  Application
# ==============================================================================

ui <- dashboardPage(
  skin = "yellow",
  
  dashboardHeader(title = "Library"),
  dashboardSidebar(
    sidebarMenu(
      menuItem("Bibliothèque", tabName = "bibliotheque", icon = icon("user")),
      menuItem("Statistiques", tabName = "statistiques", icon = icon("search")),
      menuItem("Spinner Wheel", tabName = "spinner_wheel", icon = icon("search"))
    )
  ),
  dashboardBody(
    tabItems(
    
# ------------------------------------------------------------------------------
#                                    Page 1
# ------------------------------------------------------------------------------
    
      tabItem(
        tabName = "bibliotheque",
        fluidRow(
          box(
            title = "Importer la bibliothèque",
            status = "primary",
            width = 12,
            solidHeader = TRUE,
            fluidRow(
              fileInput("library_csv", "Choisissez votre bibliothèque", accept = c(".xlsx", ".csv")),
              br(), br(),
              DTOutput("table_data", width = "100%")
            )
          )
        )
        
        
      ),

# ------------------------------------------------------------------------------
#                                    Page 2
# ------------------------------------------------------------------------------

      tabItem(
        tabName = "statistiques",
        fluidRow(
          box(
            title = "Statistiques",
            status = "primary",
            width = 12,
            solidHeader = TRUE
            
          )
        )
      ),

# ------------------------------------------------------------------------------
#                                    Page 3
# ------------------------------------------------------------------------------

      tabItem(
        tabName = "spinner_wheel"
      )
    )
  )
)

server <- function(input, output) {
  
  output$table_data <- renderDT({
    req(input$library_csv)
    
    df = read_xlsx(input$library_csv$datapath, col_names = TRUE)
    
    datatable(df, options = list(scrollX = TRUE, pageLength = 10), rownames = FALSE)
  })
  
}



shinyApp(ui, server)
