
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
library(dplyr)
library(rlang)


# ==============================================================================
#                            Définition des chemins
# ==============================================================================

setwd(dirname(rstudioapi::getActiveDocumentContext()$path))


# ==============================================================================
#                                  Variables
# ==============================================================================

genres=c("Album jeunesse", "Art", "Bande dessinée", "Langue", "Littérature", "Manga", "Nouvelle", "Philosophie", "Poésie", "Récit", "Religion", "Roman", "Sciences", "Sport", "Théâtre")


# ==============================================================================
# ------------------------------------------------------------------------------
#                                  Application
# ------------------------------------------------------------------------------
# ==============================================================================


# ==============================================================================
#                              Interface utilisateur
# ==============================================================================


ui <- dashboardPage(
  skin = "blue",
  
  dashboardHeader(title = "Library"),
  dashboardSidebar(
    sidebarMenu(
      menuItem("Bibliothèque", tabName = "bibliotheque", icon = icon("user")),
      menuItem("Rangement", tabName = "rangement", icon = icon("user")),
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
              column(12,
                fileInput("library_csv", "Choisissez votre bibliothèque", accept = c(".xlsx", ".csv"), buttonLabel = "Parcourir", placeholder = "Sélectionner une bibliothèque"),
                br(), br(),
                DTOutput("table_data", width = "100%")
              )
            )
          )
        )
      ),


# ------------------------------------------------------------------------------
#                                    Page 2
# ------------------------------------------------------------------------------

tabItem(
  tabName = "rangement",
  fluidRow(
    box(
      title = "Ranger les livres dans la bibliothèque",
      status = "primary",
      width = 12,
      solidHeader = TRUE,
      fluidRow(
        column(4,
          selectInput(inputId = "tri", label = "Trier par", choices = c("Auteur", "Date", "Genre", "Titre"), selected = "Date")),
        column(4,
          selectInput(inputId = "genres", label = "Genre", choices = genres, selected = "Littérature")),
        column(4,
          selectInput(inputId = "tri_genres", label = "Trier le genre par", choices = c("Auteur", "Date", "Titre"), selected = "Date")),
        br(), br(),
        DTOutput("table_tri")
      )
    ),
  )
),


# ------------------------------------------------------------------------------
#                                    Page 3
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
#                                    Page 4
# ------------------------------------------------------------------------------

      tabItem(
        tabName = "spinner_wheel"
      )
    )
  )
)


# ==============================================================================
#                                   Server
# ==============================================================================

server <- function(input, output) {
  
  
# ------------------------------------------------------------------------------
#                                    Page 1
# ------------------------------------------------------------------------------
  
  output$table_data <- renderDT({
    req(input$library_csv)
    
    df = read_xlsx(input$library_csv$datapath, col_names = TRUE)
    
    datatable(df, options = list(scrollX = TRUE, pageLength = 50), rownames = FALSE)
  })

    
# ------------------------------------------------------------------------------
#                                    Page 2
# ------------------------------------------------------------------------------
  
  output$table_tri <- renderDT({
    req(input$tri, input$library_csv)
    
    df_tri = read_xlsx(input$library_csv$datapath, col_names = TRUE)
    
    df_tri %>%
      select("Titre", "Auteur", "Date") %>%
      arrange(!!rlang::sym(input$tri))
    
    datatable(df_tri, options = list(scrollX = TRUE, pageLenght = 50), rownames = FALSE)
      
    
    
  })
  
  
# ------------------------------------------------------------------------------
#                                    Page 3
# ------------------------------------------------------------------------------
  
  
# ------------------------------------------------------------------------------
#                                    Page 4
# ------------------------------------------------------------------------------
  
  
}


# ==============================================================================
#                           Lancement de l'application
# ==============================================================================

shinyApp(ui, server)
