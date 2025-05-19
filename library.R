
# ==============================================================================
#                            Chargement des packages
# ==============================================================================

library(shiny)
library(shinydashboard)
library(shinycssloaders) # Animations de chargement
library(shinymanager)
library(DT)
library(reticulate)
library(rstudioapi)
library(openxlsx)
library(readxl)
library(dplyr)
library(rlang)
library(ggplot2)
library(tidyverse)
library(shinyjs)
library(reactable)
library(googlesheets4)
library(htmltools)
library(gtools)


# ==============================================================================
#                                  Variables
# ==============================================================================

genres <- c("Album jeunesse", "Art", "Bande dessinée", "Langue", "Littérature", "Manga", "Nouvelle", "Philosophie", "Poésie", "Récit", "Religion", "Roman", "Sciences", "Sport", "Théâtre")

# Couleurs pour la roue
wheel_colors <- c("#8b35bc", "#b163da", "#FF5733", "#33FF57", "#3357FF", "#F3FF33", "#FF33F3", "#33FFF3")
wheel_labels <- c("Violet", "Lilas", "Orange", "Vert", "Bleu", "Jaune", "Rose", "Cyan")

auteur_default="Dante Alighieri"
langue_default="Français"
siecle_default="XXIe"
genre_default="Littérature"


# ==============================================================================
#                                  Fonctions
# ==============================================================================

clean_variable_name <- function(x) {
  x %>%
    tolower() %>%
    stringi::stri_trans_general("Latin-ASCII") %>%  # Supprime accents
    str_replace_all("[^a-z0-9]", "_") %>%           # Remplace tout le reste par des _
    str_replace_all("_+", "_") %>%                  # Évite les doublons de underscores
    str_replace_all("^_|_$", "")                    # Supprime les _ au début/fin
}


#data=list(read.xlsx("C:/Users/theod/OneDrive/Documents/Perso/Livres/library/library.xlsx"))
#names(data)=c("library")

# ==============================================================================
# ------------------------------------------------------------------------------
#                                  Application
# ------------------------------------------------------------------------------
# ==============================================================================

# ==============================================================================
#                             Interface utilisateur
# ==============================================================================

ui <- dashboardPage(
  skin = "blue",
  dashboardHeader(title = "Library"),
  dashboardSidebar(
    sidebarMenu(
      menuItem("Bibliothèque", tabName = "bibliotheque", icon = icon("book")),
      menuItem("Rangement", tabName = "rangement", icon = icon("folder")),
      menuItem("Statistiques", tabName = "statistiques", icon = icon("chart-bar"),
               menuSubItem("Tous les livres", "stat-livres", icon = icon("chart-bar")),
               menuSubItem("Auteur", "stat-auteur", icon = icon("chart-bar")),
               menuSubItem("Genre", "stat-genre", icon = icon("chart-bar")),
               menuSubItem("Langue", "stat-langue", icon = icon("chart-bar")),
               menuSubItem("Siècle", "stat-siecle", icon = icon("chart-bar"))),
      menuItem("Spinner Wheel", tabName = "spinner_wheel", icon = icon("sync"))
    )
  ),
  dashboardBody(
    # Activez shinyjs
    useShinyjs(),

    # Chargez les scripts externes pour Chart.js
    tags$head(
      tags$script(src = "https://cdnjs.cloudflare.com/ajax/libs/Chart.js/3.9.1/chart.min.js"),
      tags$script(src = "https://cdnjs.cloudflare.com/ajax/libs/chartjs-plugin-datalabels/2.1.0/chartjs-plugin-datalabels.min.js"),

      # CSS personnalisé pour la roue
      tags$style(HTML("
        .wheel-container {
          position: relative;
          width: 100%;
          height: 400px;
          display: flex;
          flex-direction: column;
          align-items: center;
          justify-content: center;
          margin-top: 20px;
        }

        .canvas-container {
          position: relative;
          width: 350px;
          height: 350px;
        }

        #wheel {
          max-height: 100%;
          max-width: 100%;
        }

        #spin-btn {
          position: absolute;
          transform: translate(-50%, -50%);
          top: 50%;
          left: 50%;
          height: 80px;
          width: 80px;
          border-radius: 50%;
          cursor: pointer;
          border: 0;
          background: radial-gradient(#fdcf3b 50%, #d88a40 85%);
          color: #c66e16;
          text-transform: uppercase;
          font-size: 1.2em;
          font-weight: 600;
          z-index: 10;
        }

        .arrow {
          position: absolute;
          width: 40px;
          height: 40px;
          top: -20px;
          left: 50%;
          transform: translateX(-50%);
          z-index: 5;
        }

        .arrow:before {
          content: '';
          position: absolute;
          width: 0;
          height: 0;
          border-left: 20px solid transparent;
          border-right: 20px solid transparent;
          border-top: 30px solid black;
          top: 0;
          left: 0;
        }

        #final-value {
          margin-top: 20px;
          font-size: 24px;
          font-weight: bold;
          text-align: center;
        }
        
        .text-stat {
          text-align: center;
          font-family: Baskerville Old;
          font-size: 25px;
        }
        
      "))
    ),

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
            column(6,
              fileInput("library_csv", "Choisissez votre bibliothèque", width = "100%", accept = c(".xlsx", ".csv"), buttonLabel = "Parcourir", placeholder = "Sélectionner une bibliothèque")),
            column(6,
              uiOutput("conditional_choix_feuille")),
            DTOutput("table_data", width = "100%")
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
                selectInput("tri", "Trier par", choices = c("Auteur", "Date", "Genre", "Titre"), selected = "Date")),
              column(4,
                uiOutput("conditional_input_genre_genre")),
              column(4,
                uiOutput("conditional_input_genre_tri"))
              
            ),
            DTOutput("table_tri")
          )
        )
      ),


# ------------------------------------------------------------------------------
#                                    Page 3.1
# ------------------------------------------------------------------------------

      tabItem(
        tabName = "stat-livres",
        br(),
        fluidRow(
          column(3,
            box(
              title = "Nombre de livres",
              status = "primary",
              width = 12,
              solidHeader = TRUE,
              h2(textOutput(outputId = "nb_livres"), class = "text-stat")
            )
          ),
          column(3,
            box(
              title = "Nombre de pages",
              status = "primary",
              width = 12,
              solidHeader = TRUE,
              h2(textOutput(outputId = "nb_pages"), class = "text-stat")
            )
          ),
          column(3,
            box(
              title = "Nombre d'auteurs différents",
              status = "primary",
              width = 12,
              solidHeader = TRUE,
              h2(textOutput(outputId = "nb_auteurs"), class = "text-stat")
            )
          ),
          column(3,
            box(
              title = "Nombre de livres aimés",
              status = "primary",
              width = 12,
              solidHeader = TRUE,
              h2(textOutput(outputId = "nb_livres_aimes"), class = "text-stat")
            )
          )
        ),
        br(), br(),
        fluidRow(
          column(3,
            box(
              title = "Nombre de livres lus",
              status = "primary",
              width = 12,
              solidHeader = TRUE,
              h2(textOutput(outputId = "nb_livres_lus"), class = "text-stat")
            )
          ),
          column(3,
            box(
              title = "Nombre de pages lues",
              status = "primary",
              width = 12,
              solidHeader = TRUE,
              h2(textOutput(outputId = "nb_pages_lues"), class = "text-stat")
            )
          ),
          column(3,
            box(
              title = "Nombre de genres différents",
              status = "primary",
              width = 12,
              solidHeader = TRUE,
              h2(textOutput(outputId = "nb_genres"), class = "text-stat")
            )
          ),
          column(3,
            box(
              title = "Prix total",
              status = "primary",
              width = 12,
              solidHeader = TRUE,
              h2(textOutput(outputId = "prix_total"), class = "text-stat")
            )
          )
        ),
        br(), br(),
        fluidRow(
          column(4,
            box(
              title = "Auteur préféré",
              status = "primary",
              width = 12,
              solidHeader = TRUE,
              h2(textOutput(outputId = "auteur_fav"), class = "text-stat")
            )
          ),
          column(4,
            box(
              title = "Genre préféré",
              status = "primary",
              width = 12,
              solidHeader = TRUE,
              h2(textOutput(outputId = "genre_fav"), class = "text-stat")
            )
          ),
          column(4,
            box(
              title = "Langue préférée",
              status = "primary",
              width = 12,
              solidHeader = TRUE,
              h2(textOutput(outputId = "langue_fav"), class = "text-stat")
            )
          )
        )
      ),


# ------------------------------------------------------------------------------
#                                    Page 3.2
# ------------------------------------------------------------------------------

      tabItem(
        tabName = "stat-auteur",
        fluidRow(
          box(
            title = "Sur l'auteur",
            status = "primary",
            width = 12,
            solidHeader = TRUE,
            column(6,
              box(
                title = "Choix de l'auteur",
                status = "primary",
                width = 12,
                solidHeader = TRUE,
                selectInput(inputId = "choix_auteur", label = "Sélectionner un auteur", width = "100%", choices = NULL)
              ),
              box(
                title = "Nombres de livres",
                status = "primary",
                width = 6,
                solidHeader = TRUE,
                h2(textOutput(outputId = "nb_livres_auteurs"), class = "text-stat")
              ),
              box(
                title = "Nombres de livres lus",
                status = "primary",
                width = 6,
                solidHeader = TRUE,
                h2(textOutput(outputId = "nb_livres_lus_auteurs"), class = "text-stat")
              ),
              box(
                title = "Nombres de pages",
                status = "primary",
                width = 6,
                solidHeader = TRUE,
                h2(textOutput(outputId = "nb_pages_auteurs"), class = "text-stat")
              ),
              box(
                title = "Nombres de pages lues",
                status = "primary",
                width = 6,
                solidHeader = TRUE,
                h2(textOutput(outputId = "nb_pages_lues_auteurs"), class = "text-stat")
              ),
            ),
            column(6,
              DTOutput(outputId = "table_stat_auteurs")
            )
          )
        ),
        fluidRow(
          column(6,
                 box(title = "Taux de livres lus",
                     status = "primary",
                     solidHeader = TRUE,
                     width = 12,
                     plotOutput("plot_livres_auteurs")
                 )
          ),
          column(6,
                 box(title = "Taux de pages lues",
                     status = "primary",
                     solidHeader = TRUE,
                     width = 12,
                     plotOutput("plot_pages_auteurs")
                 )
          )
        )
      ),


# ------------------------------------------------------------------------------
#                                    Page 3.3
# ------------------------------------------------------------------------------

      tabItem(
        tabName = "stat-genre",
        fluidRow(
          box(
            title = "Sur le genre",
            status = "primary",
            width = 12,
            solidHeader = TRUE,
            column(6,
                   box(
                     title = "Choix du genre",
                     status = "primary",
                     width = 12,
                     solidHeader = TRUE,
                     selectInput(inputId = "choix_genre", label = "Sélectionner un genre", width = "100%", choices = NULL)
                   ),
                   box(
                     title = "Nombres de livres",
                     status = "primary",
                     width = 6,
                     solidHeader = TRUE,
                     h2(textOutput(outputId = "nb_livres_genres"), class = "text-stat")
                   ),
                   box(
                     title = "Nombres de livres lus",
                     status = "primary",
                     width = 6,
                     solidHeader = TRUE,
                     h2(textOutput(outputId = "nb_livres_lus_genres"), class = "text-stat")
                   ),
                   box(
                     title = "Nombres de pages",
                     status = "primary",
                     width = 6,
                     solidHeader = TRUE,
                     h2(textOutput(outputId = "nb_pages_genres"), class = "text-stat")
                   ),
                   box(
                     title = "Nombres de pages lues",
                     status = "primary",
                     width = 6,
                     solidHeader = TRUE,
                     h2(textOutput(outputId = "nb_pages_lues_genres"), class = "text-stat")
                   ),
            ),
            column(6,
              DTOutput(outputId = "table_stat_genres")
            )
          )
        ),
        fluidRow(
          column(6,
            box(title = "Taux de livres lus",
                status = "primary",
                solidHeader = TRUE,
                width = 12,
                plotOutput("plot_livres_genres")
            )
          ),
          column(6,
            box(title = "Taux de pages lues",
                status = "primary",
                solidHeader = TRUE,
                width = 12,
                plotOutput("plot_pages_genres")
            )
          )
        )
      ),


# ------------------------------------------------------------------------------
#                                    Page 3.4
# ------------------------------------------------------------------------------

      tabItem(
        tabName = "stat-langue",
        fluidRow(
          box(
            title = "Sur la langue",
            status = "primary",
            width = 12,
            solidHeader = TRUE,
            column(6,
                   box(
                     title = "Choix de la langue originale",
                     status = "primary",
                     width = 12,
                     solidHeader = TRUE,
                     selectInput(inputId = "choix_langue", label = "Sélectionner une langue", width = "100%", choices = NULL)
                   ),
                   box(
                     title = "Nombres de livres",
                     status = "primary",
                     width = 6,
                     solidHeader = TRUE,
                     h2(textOutput(outputId = "nb_livres_langues"), class = "text-stat")
                   ),
                   box(
                     title = "Nombres de livres lus",
                     status = "primary",
                     width = 6,
                     solidHeader = TRUE,
                     h2(textOutput(outputId = "nb_livres_lus_langues"), class = "text-stat")
                   ),
                   box(
                     title = "Nombres de pages",
                     status = "primary",
                     width = 6,
                     solidHeader = TRUE,
                     h2(textOutput(outputId = "nb_pages_langues"), class = "text-stat")
                   ),
                   box(
                     title = "Nombres de pages lues",
                     status = "primary",
                     width = 6,
                     solidHeader = TRUE,
                     h2(textOutput(outputId = "nb_pages_lues_langues"), class = "text-stat")
                   ),
            ),
            column(6,
                   DTOutput(outputId = "table_stat_langues")
            )
          )
        ),
        fluidRow(
          column(6,
                 box(title = "Taux de livres lus",
                     status = "primary",
                     solidHeader = TRUE,
                     width = 12,
                     plotOutput("plot_livres_langues")
                 )
          ),
          column(6,
                 box(title = "Taux de pages lues",
                     status = "primary",
                     solidHeader = TRUE,
                     width = 12,
                     plotOutput("plot_pages_langues")
                 )
          )
        )
      ),


# ------------------------------------------------------------------------------
#                                    Page 3.5
# ------------------------------------------------------------------------------
        
      tabItem(
        tabName = "stat-siecle",
        fluidRow(
          box(
            title = "Sur le siècle",
            status = "primary",
            width = 12,
            solidHeader = TRUE,
            column(6,
                   box(
                     title = "Choix du siècle",
                     status = "primary",
                     width = 12,
                     solidHeader = TRUE,
                     selectInput(inputId = "choix_siecle", label = "Sélectionner un siècle", width = "100%", choices = NULL)
                   ),
                   box(
                     title = "Nombres de livres",
                     status = "primary",
                     width = 6,
                     solidHeader = TRUE,
                     h2(textOutput(outputId = "nb_livres_siecle"), class = "text-stat")
                   ),
                   box(
                     title = "Nombres de livres lus",
                     status = "primary",
                     width = 6,
                     solidHeader = TRUE,
                     h2(textOutput(outputId = "nb_livres_lus_siecle"), class = "text-stat")
                   ),
                   box(
                     title = "Nombres de pages",
                     status = "primary",
                     width = 6,
                     solidHeader = TRUE,
                     h2(textOutput(outputId = "nb_pages_siecle"), class = "text-stat")
                   ),
                   box(
                     title = "Nombres de pages lues",
                     status = "primary",
                     width = 6,
                     solidHeader = TRUE,
                     h2(textOutput(outputId = "nb_pages_lues_siecle"), class = "text-stat")
                   ),
            ),
            column(6,
                   DTOutput(outputId = "table_stat_siecle")
            )
          )
        ),
        fluidRow(
          column(6,
                 box(title = "Taux de livre lus",
                     status = "primary",
                     solidHeader = TRUE,
                     width = 12,
                     plotOutput("plot_livres_siecles")
                 )
          ),
          column(6,
                 box(title = "Taux de pages lues",
                     status = "primary",
                     solidHeader = TRUE,
                     width = 12,
                     plotOutput("plot_pages_siecles")
                 )
          )
        )
      ),


# ------------------------------------------------------------------------------
#                                   Page 4
# ------------------------------------------------------------------------------

      tabItem(
        tabName = "spinner_wheel",
        fluidRow(
          box(
            title = "Roue des couleurs",
            status = "primary",
            width = 12,
            solidHeader = TRUE,
            div(class = "wheel-container",
                div(class = "canvas-container",
                    tags$canvas(id = "wheel"),
                    tags$button(id = "spin-btn", "Spin"),
                    div(class = "arrow")
                ),
                div(id = "final-value", "Cliquez sur Spin pour faire tourner la roue")
            )
          )
        )
      )
    )
  )
)


# ==============================================================================
#                                   Server
# ==============================================================================

server <- function(input, output, session) {
  
  data = reactiveValues()


# ------------------------------------------------------------------------------
#                                    Page 1
# ------------------------------------------------------------------------------
  
  
  
  output$conditional_choix_feuille <- renderUI({
    req(input$library_csv)
    
    if(length(excel_sheets(input$library_csv$datapath))>1) {
      selectInput("choix_feuille", label = "Choisir une feuille du fichier", width = "100%", choices = excel_sheets(input$library_csv$datapath))
    }
  })
  
  output$table_data <- renderDT({
    req(input$library_csv)
    
    ext <- tools::file_ext(input$library_csv$name)
    data$library <- if(ext == "xlsx") {
      if (length(excel_sheets(input$library_csv$datapath)>1)) {
        sheet = input$choix_feuille
      } else {
        sheet = excel_sheets(input$library_csv$datapath)[1]
      }
      read_xlsx(input$library_csv$datapath, col_names = TRUE, sheet = sheet)
    } else {
      read.csv(input$library_csv$datapath, stringsAsFactors = FALSE)
    }
    
    datatable(data$library, options = list(scrollX = TRUE, pageLenght = -1, lengthMenu = list(c(-1,10,25,50,100), c("Tout", "10", "25", "50", "100"))), rownames = FALSE)
  })
  

# ------------------------------------------------------------------------------
#                                    Page 2
# ------------------------------------------------------------------------------
  
  output$conditional_input_genre_genre <- renderUI({
    if (input$tri == "Genre") {
      column(12,
        selectInput(inputId = "genres", label = "Genre", choices = genres, selected = "Littérature")
      )
    }
  })
  
  output$conditional_input_genre_tri <- renderUI({
    if (input$tri == "Genre") {
      column(12,
        selectInput(inputId = "tri_genres", label = "Trier le genre par", choices = c("Auteur", "Date", "Titre"), selected = "Date")
      )
    }
  })
  
  output$table_tri <- renderDT({
    req(input$tri, input$library_csv)
    
    data_library_tri = data$library  %>%
      arrange(!!sym(input$tri))
    
    if (!!sym(input$tri) == "Genre") {
      req(input$genres, input$tri_genres)
      
      data_library_tri = data_library_tri %>%
        filter(Genre == input$genres) %>%
        arrange(!!sym(input$tri_genres))
    }
    
    datatable(select(data_library_tri, "Titre", "Auteur", "Date", "Genre"), options = list(scrollX = TRUE, pageLenght = -1, lengthMenu = list(c(-1, 10,25,50,100), c("Tout", "10", "25", "50", "100"))), rownames = FALSE)
      
  })
  
  
# ------------------------------------------------------------------------------
#                                    Page 3.1
# ------------------------------------------------------------------------------

  output$nb_livres <- renderText({
    req(input$library_csv)
    
    data$nb_livres = data$library %>%
      filter(Histoire == "Oui") %>%
      nrow()
    
    format(data$nb_livres, big.mark = " ", scientific = FALSE)
  })
  
  
  output$nb_livres_lus <- renderText({
    req(input$library_csv)
    
    data$nb_livres_lus <- filter(data$library, Lu=="Oui" & Principal == "Oui")
    
    paste0(format(nrow(data$nb_livres_lus), big.mark = " ", scientific = FALSE), " (", round(nrow(data$nb_livres_lus)/nrow(data$library)*100,2), " %)")
  })
  
  
  output$nb_pages <- renderText({
    req(input$library_csv)
    
    data$nb_pages <- data$library %>%
      filter(Histoire == "Oui")
    
    paste0(format(round(sum(data$nb_pages[["Pages"]]), 0), big.mark = " ", scientific = FALSE))
  })
  
  
  output$nb_pages_lues <- renderText({
    req(input$library_csv)
    
    data$nb_pages_lues <- data$library %>%
      filter(Lu == "Oui", Histoire == "Oui")
    
    paste0(format(round(sum(data$nb_pages_lues[["Pages"]]),0), big.mark = " ", scientific=FALSE), " (", round(sum(data$nb_pages_lues[["Pages"]])/sum(data$library[["Pages"]])*100,2), " %)")
  })
  
  
  output$nb_auteurs <- renderText({
    req(input$library_csv)
    
    data$nb_auteurs = data$library$Auteur %>%
      unique() %>%
      length()
    
    format(data$nb_auteurs, big.mark = " ", scientific = FALSE)
  })
  
  
  output$nb_genres <- renderText({
    req(input$library_csv)
    
    data$nb_genres = data$library$Genre %>%
      unique() %>%
      length()
    
    format(data$nb_genres, big.mark = " ", scientific = FALSE)
  })
  
  
  output$nb_livres_aimes <- renderText({
    req(input$library_csv)
    
    data$library_livres_aimes <- data$library %>%
      filter(Principal == "Oui", Favoris=="Oui")
    
    paste0(format(nrow(data$library_livres_aimes), big.mark = " ", scientific = FALSE), " (", round(nrow(data$library_livres_aimes)/nrow(data$nb_livres_lus)*100,2), " %)")
  })
  
  
  output$prix_total <- renderText({
    req(input$library_csv)
    
    paste0(format(sum(data$library$Prix, big.mark = " ", scientific = FALSE)), " €")
  })
  
  
  output$auteur_fav <- renderText({
    req(input$library_csv)
    
    data$auteur = data$library %>%
      group_by(Auteur) %>%
      summarize(nb_auteur=n())
    
    paste(data$auteur$Auteur[which(data$auteur$nb_auteur == max(data$auteur$nb_auteur))], collapse = ", ")
  })
  
  
  output$genre_fav <- renderText({
    req(input$library_csv)
    
    data$genre = data$library %>%
      group_by(Genre) %>%
      summarize(nb_genre=n())
    
    paste(data$genre$Genre[which(data$genre$nb_genre == max(data$genre$nb_genre))], collapse = ", ")
  })
  
  
  output$langue_fav <- renderText({
    req(input$library_csv)
    
    data$langue = data$library %>%
      group_by(Langue) %>%
      summarize(nb_langue=n())
    
    paste(data$langue$Langue[which(data$langue$nb_langue == max(data$langue$nb_langue))], collapse = ", ")
  })

  
# ------------------------------------------------------------------------------
#                                    Page 3.2
# ------------------------------------------------------------------------------
  
  observeEvent(input$library_csv,{
    if (auteur_default %in% data$library$Auteur) {
      updateSelectInput(inputId = "choix_auteur", choices = sort(unique(data$library$Auteur)), selected = auteur_default)
    }
    else {
      updateSelectInput(inputId = "choix_auteur", choices = sort(unique(data$library$Auteur)), selected = NULL)
    }
  })
  
  
  output$nb_livres_auteurs <- renderText({
    req(input$library_csv)
    
    data$nb_livres_auteurs = nrow(filter(data$library, Auteur == input$choix_auteur))
    
    paste0(format(data$nb_livres_auteurs, big.mark = " ", scientific = FALSE), " (", round(data$nb_livres_auteurs/nrow(filter(data$library, Histoire == "Oui"))*100,2), " %)")
  })
  
  
  output$nb_livres_lus_auteurs <- renderText({
    req(input$library_csv)
    
    data$nb_livres_lus_auteurs = nrow(filter(data$library, Auteur == input$choix_auteur, Lu == "Oui"))
    
    paste0(format(data$nb_livres_lus_auteurs, big.mark = " ", scientific = FALSE), " (", round(data$nb_livres_lus_auteurs/data$nb_livres_auteurs*100,2), " %)")
  })
  
  
  output$nb_pages_auteurs <- renderText({
    req(input$library_csv)
    
    data$nb_pages_auteurs=sum(filter(data$library, Auteur == input$choix_auteur)$Pages)
    
    paste0(format(data$nb_pages_auteurs, big.mark = " ", scientific = FALSE), " (", round(data$nb_pages_auteurs/sum(data$library[["Pages"]])*100,2), " %)")
  })
  
  
  output$nb_pages_lues_auteurs <- renderText({
    req(input$library_csv)
    
    data$nb_pages_lues_auteurs=sum(filter(data$library, Auteur == input$choix_auteur, Lu == "Oui")$Pages)
    
    paste0(format(data$nb_pages_lues_auteurs, big.mark = " ", scientific = FALSE), " (", round(data$nb_pages_lues_auteurs/data$nb_pages_auteurs*100,2), " %)")
  })
  
  
  output$table_stat_auteurs <- renderDT({
    req(input$library_csv, input$choix_auteur)
    
    data$table_stat_auteurs = data$library %>%
      filter(Auteur == input$choix_auteur, Histoire == "Oui") %>%
      select("Titre", "Auteur", "Date") %>%
      arrange(Date)
      
    datatable(data$table_stat_auteurs, options = list(scrollY = "350px", paging = FALSE, searching = FALSE, pageLenght = -1, lengthMenu = list(c(-1, 10,25,50,100), c("Tout", "10", "25", "50", "100"))), rownames = FALSE)
  })
  
  
  output$plot_livres_auteurs <- renderPlot({
    
    req(input$library_csv)
    
    data$plot_livres_auteurs = mutate(inner_join(summarize(group_by(data$library[data$library$Histoire=="Oui",], Auteur), nb_livres=n()), summarize(group_by(data$library[data$library$Histoire=="Oui",], Auteur), nb_livres_lus=sum(na.omit(Lu)=="Oui")), by = "Auteur"), pourc=round(nb_livres_lus/nb_livres*100,2))
    
    ggplot(head(data$plot_livres_auteurs[order(data$plot_livres_auteurs$nb_livres_lus, decreasing = TRUE),],10), aes(x=reorder(Auteur, nb_livres_lus), y=pourc)) + 
      geom_bar(stat = "identity", fill="#00CC33") + 
      coord_flip() +
      labs(x = "Auteurs", title = "Taux de livres lus") +
      theme_bw() + 
      theme(legend.position = "none", panel.grid.major = element_blank(), panel.grid.minor = element_blank(), axis.title.x = element_blank(), axis.text.x = element_blank(), axis.ticks.x = element_blank()) +
      geom_text(label = paste0(format(head(data$plot_livres_auteurs[order(data$plot_livres_auteurs$nb_livres_lus, decreasing = TRUE),],10)$nb_livres_lus, big.mark=" ", digits = 1, scientific=FALSE), " (", head(data$plot_livres_auteurs[order(data$plot_livres_auteurs$nb_livres_lus, decreasing = TRUE),],10)$pourc, " %)"), check_overlap = TRUE, color="white", position = position_stack(vjust=0.5))
  })
  
  
  output$plot_pages_auteurs <- renderPlot({
    req(input$library_csv)
    
    data$plot_pages_auteurs = mutate(inner_join(summarize(group_by(data$library[data$library$Histoire=="Oui",], Auteur), nb_pages=sum(Pages)), summarize(group_by(data$library[data$library$Histoire=="Oui",], Auteur), nb_pages_lues=sum(Pages[Lu=="Oui"], na.rm = TRUE)), by = "Auteur"), pourc=round(nb_pages_lues/nb_pages*100,2))
    
    ggplot(head(data$plot_pages_auteurs[order(data$plot_pages_auteurs$nb_pages_lues, decreasing = TRUE),],10), aes(x=reorder(Auteur, nb_pages_lues), y=pourc)) + 
      geom_bar(stat = "identity", fill="#00CC33") + 
      coord_flip() +
      labs(x = "Auteurs", title = "Taux de pages lues") +
      theme_bw() + 
      theme(legend.position = "none", panel.grid.major = element_blank(), panel.grid.minor = element_blank(), axis.title.x = element_blank(), axis.text.x = element_blank(), axis.ticks.x = element_blank()) +
      geom_text(label = paste0(format(head(data$plot_pages_auteurs[order(data$plot_pages_auteurs$nb_pages_lues, decreasing = TRUE),],10)$nb_pages_lues, big.mark=" ", digits = 1, scientific=FALSE), " (", head(data$plot_pages_auteurs[order(data$plot_pages_auteurs$nb_pages_lues, decreasing = TRUE),],10)$pourc, " %)"), check_overlap = TRUE, color="white", position = position_stack(vjust=0.5))
  })
  
  
# ------------------------------------------------------------------------------
#                                    Page 3.3
# ------------------------------------------------------------------------------
  
  observeEvent(input$library_csv,{
    if (genre_default %in% data$library$Genre) {
      updateSelectInput(inputId = "choix_genre", choices = sort(unique(data$library$Genre)), selected = genre_default)
    }
    else {
      updateSelectInput(inputId = "choix_genre", choices = sort(unique(data$library$Genre)), selected = NULL)
    }
  })
  
  
  output$nb_livres_genres <- renderText({
    req(input$library_csv)
    
    data$nb_livres_genres = nrow(filter(data$library, Genre == input$choix_genre))
    
    paste0(format(data$nb_livres_genres, big.mark = " ", scientific = FALSE), " (", round(data$nb_livres_genres/nrow(filter(data$library, Histoire == "Oui"))*100,2), " %)")
  })
  
  
  output$nb_livres_lus_genres <- renderText({
    req(input$library_csv)
    
    data$nb_livres_lus_genres = nrow(filter(data$library, Genre == input$choix_genre, Lu == "Oui"))
    
    paste0(format(data$nb_livres_lus_genres, big.mark = " ", scientific = FALSE), " (", round(data$nb_livres_lus_genres/data$nb_livres_genres*100,2), " %)")
  })
  
  
  output$nb_pages_genres <- renderText({
    req(input$library_csv)
    
    data$nb_pages_genres=sum(filter(data$library, Genre == input$choix_genre)$Pages)
    
    paste0(format(data$nb_pages_genres, big.mark = " ", scientific = FALSE), " (", round(data$nb_pages_genres/sum(data$library[["Pages"]])*100,2), " %)")
  })
  
  
  output$nb_pages_lues_genres <- renderText({
    req(input$library_csv)
    
    data$nb_pages_lues_genres=sum(filter(data$library, Genre == input$choix_genre, Lu == "Oui")$Pages)
    
    paste0(format(data$nb_pages_lues_genres, big.mark = " ", scientific = FALSE), " (", round(data$nb_pages_lues_genres/data$nb_pages_genres*100,2), " %)")
  })
  
  
  output$table_stat_genres <- renderDT({
    req(input$library_csv, input$choix_genre)
    
    data$table_stat_genres = data$library %>%
      filter(Genre == input$choix_genre, Histoire == "Oui") %>%
      select("Titre", "Auteur", "Date") %>%
      arrange(Date)
    
    datatable(data$table_stat_genres, options = list(scrollY = "350px", paging = FALSE, searching = FALSE, pageLenght = -1, lengthMenu = list(c(-1, 10,25,50,100), c("Tout", "10", "25", "50", "100"))), rownames = FALSE)
  })
  
  
  output$plot_livres_genres <- renderPlot({
    
    req(input$library_csv)
    
      data$plot_livres_genres = mutate(inner_join(summarize(group_by(data$library[data$library$Histoire=="Oui",], Genre), nb_livres=n()), summarize(group_by(data$library[data$library$Histoire=="Oui",], Genre), nb_lus=sum(na.omit(Lu)=="Oui")), by = "Genre"), pourc=round(nb_lus/nb_livres*100,2)) %>%
        rbind(bind_cols("Genre" = "Total", "nb_livres" = sum(mutate(inner_join(summarize(group_by(data$library[data$library$Histoire=="Oui",], Genre), nb_livres=n()), summarize(group_by(data$library[data$library$Histoire=="Oui",], Genre), nb_lus=sum(na.omit(Lu)=="Oui")), by = "Genre"), pourc=round(nb_lus/nb_livres*100,2))$nb_livres), "nb_lus" = sum(mutate(inner_join(summarize(group_by(data$library[data$library$Histoire=="Oui",], Genre), nb_livres=n()), summarize(group_by(data$library[data$library$Histoire=="Oui",], Genre), nb_lus=sum(na.omit(Lu)=="Oui")), by = "Genre"), pourc=round(nb_lus/nb_livres*100,2))$nb_lus), "pourc" = sum(mutate(inner_join(summarize(group_by(data$library[data$library$Histoire=="Oui",], Genre), nb_livres=n()), summarize(group_by(data$library[data$library$Histoire=="Oui",], Genre), nb_lus=sum(na.omit(Lu)=="Oui")), by = "Genre"), pourc=round(nb_lus/nb_livres*100,2))$nb_lus)/sum(mutate(inner_join(summarize(group_by(data$library[data$library$Histoire=="Oui",], Genre), nb_livres=n()), summarize(group_by(data$library[data$library$Histoire=="Oui",], Genre), nb_lus=sum(na.omit(Lu)=="Oui")), by = "Genre"), pourc=round(nb_lus/nb_livres*100,2))$nb_livres)*100))
      
      ggplot(data$plot_livres_genres, aes(x=factor(Genre, levels = c("Total", sort(unique(data$library$Genre), decreasing = TRUE))), y=pourc)) + 
        geom_bar(stat = "identity", fill="#00CC33") + 
        coord_flip() +
        labs(x = "Genres", y = "Pourcentage (%)", title = "Taux de livres lus") +
        theme_bw() + 
        theme(legend.position = "none", panel.grid.major = element_blank(), panel.grid.minor = element_blank(), axis.title.x = element_blank(), axis.text.x = element_blank(), axis.ticks.x = element_blank()) +
        geom_text(label = paste0(format(data$plot_livres_genres$nb_lus, big.mark=" ", digits = 1, scientific=FALSE), " (", data$plot_livres_genres$pourc, " %)"), check_overlap = TRUE, color="white", position = position_stack(vjust=0.5))
  })
  
  
  output$plot_pages_genres <- renderPlot({
    req(input$library_csv)
    
    data$plot_pages_genres = mutate(inner_join(summarize(group_by(data$library[data$library$Histoire=="Oui",], Genre), nb_pages=sum(Pages)), summarize(group_by(data$library[data$library$Histoire=="Oui",], Genre), nb_pages_lues=sum(Pages[Lu=="Oui"], na.rm = TRUE)), by = "Genre"), pourc=round(nb_pages_lues/nb_pages*100,2)) %>%
      rbind(bind_cols("Genre" = "Total", "nb_pages" = sum(mutate(inner_join(summarize(group_by(data$library[data$library$Histoire=="Oui",], Genre), nb_pages=sum(Pages)), summarize(group_by(data$library[data$library$Histoire=="Oui",], Genre), nb_pages_lues=sum(Pages[Lu=="Oui"], na.rm = TRUE)), by = "Genre"), pourc=round(nb_pages_lues/nb_pages*100,2))$nb_pages), "nb_pages_lues" = sum(mutate(inner_join(summarize(group_by(data$library[data$library$Histoire=="Oui",], Genre), nb_pages=sum(Pages)), summarize(group_by(data$library[data$library$Histoire=="Oui",], Genre), nb_pages_lues=sum(Pages[Lu=="Oui"], na.rm = TRUE)), by = "Genre"), pourc=round(nb_pages_lues/nb_pages*100,2))$nb_pages_lues), "pourc" = round(sum(mutate(inner_join(summarize(group_by(data$library[data$library$Histoire=="Oui",], Genre), nb_pages=sum(Pages)), summarize(group_by(data$library[data$library$Histoire=="Oui",], Genre), nb_pages_lues=sum(Pages[Lu=="Oui"], na.rm = TRUE)), by = "Genre"), pourc=round(nb_pages_lues/nb_pages*100,2))$nb_pages_lues)/sum(mutate(inner_join(summarize(group_by(data$library[data$library$Histoire=="Oui",], Genre), nb_pages=sum(Pages)), summarize(group_by(data$library[data$library$Histoire=="Oui",], Genre), nb_pages_lues=sum(Pages[Lu=="Oui"], na.rm = TRUE)), by = "Genre"), pourc=round(nb_pages_lues/nb_pages*100,2))$nb_pages)*100,2)))
    
    ggplot(data$plot_pages_genres, aes(x=factor(Genre, levels = c("Total", sort(unique(data$library$Genre), decreasing = TRUE))), y=pourc)) + 
      geom_bar(stat = "identity", fill="#00CC33") + 
      coord_flip() +
      labs(x = "Genres", title = "Taux de pages lues") +
      theme_bw() + 
      theme(legend.position = "none", panel.grid.major = element_blank(), panel.grid.minor = element_blank(), axis.title.x = element_blank(), axis.text.x = element_blank(), axis.ticks.x = element_blank()) +
      geom_text(label = paste0(format(data$plot_pages_genres$nb_pages_lues, digits = 1, big.mark=" ", scientific=FALSE), " (", data$plot_pages_genres$pourc, " %)"), check_overlap = TRUE, color="white", position = position_stack(vjust=0.5))
 
   })

  
# ------------------------------------------------------------------------------
#                                    Page 3.4
# ------------------------------------------------------------------------------
  
  observeEvent(input$library_csv,{
    updateSelectInput(inputId = "choix_langue", choices = sort(unique(data$library$Langue)), selected = ifelse(langue_default %in% data$library$Langue, langue_default, NULL))
  })
  
  
  output$nb_livres_langues <- renderText({
    req(input$library_csv)
    
    data$nb_livres_langues = nrow(filter(data$library, Langue == input$choix_langue))
    
    paste0(format(data$nb_livres_langues, big.mark = " ", scientific = FALSE), " (", round(data$nb_livres_langues/nrow(filter(data$library, Histoire == "Oui"))*100,2), " %)")
  })
  
  
  output$nb_livres_lus_langues <- renderText({
    req(input$library_csv)
    
    data$nb_livres_lus_langues = nrow(filter(data$library, Langue == input$choix_langue, Lu == "Oui"))
    
    paste0(format(data$nb_livres_lus_langues, big.mark = " ", scientific = FALSE), " (", round(data$nb_livres_lus_langues/data$nb_livres_langues*100,2), " %)")
  })
  
  
  output$nb_pages_langues <- renderText({
    req(input$library_csv)
    
    data$nb_pages_langues=sum(filter(data$library, Langue == input$choix_langue)$Pages)
    
    paste0(format(data$nb_pages_langues, big.mark = " ", scientific = FALSE), " (", round(data$nb_pages_langues/sum(data$library[["Pages"]])*100,2), " %)")
  })
  
  
  output$nb_pages_lues_langues <- renderText({
    req(input$library_csv)
    
    data$nb_pages_lues_langues=sum(filter(data$library, Langue == input$choix_langue, Lu == "Oui")$Pages)
    
    paste0(format(data$nb_pages_lues_langues, big.mark = " ", scientific = FALSE), " (", round(data$nb_pages_lues_langues/data$nb_pages_langues*100,2), " %)")
  })
  
  
  output$table_stat_langues <- renderDT({
    req(input$library_csv, input$choix_auteur)
    
    data$table_stat_langues = data$library %>%
      filter(Langue == input$choix_langue, Histoire == "Oui") %>%
      select("Titre", "Auteur", "Date") %>%
      arrange(Date)
    
    datatable(data$table_stat_langues, options = list(scrollY = "350px", paging = FALSE, searching = FALSE, pageLenght = -1, lengthMenu = list(c(-1, 10,25,50,100), c("Tout", "10", "25", "50", "100"))), rownames = FALSE)
  })
  
  
  output$plot_livres_langues <- renderPlot({
    
    req(input$library_csv)
    
    data$plot_livres_langues = mutate(inner_join(summarize(group_by(data$library[data$library$Histoire=="Oui",], Langue), nb_livres=n()), summarize(group_by(data$library[data$library$Histoire=="Oui",], Langue), nb_livres_lus=sum(na.omit(Lu)=="Oui")), by = "Langue"), pourc=round(nb_livres_lus/nb_livres*100,2))
    
    ggplot(head(data$plot_livres_langues[order(data$plot_livres_langues$nb_livres_lus, decreasing = TRUE),],10), aes(x=reorder(Langue, nb_livres_lus), y=pourc)) + 
      geom_bar(stat = "identity", fill="#00CC33") + 
      coord_flip() +
      labs(x = "langues", title = "Taux de livres lus") +
      theme_bw() + 
      theme(legend.position = "none", panel.grid.major = element_blank(), panel.grid.minor = element_blank(), axis.title.x = element_blank(), axis.text.x = element_blank(), axis.ticks.x = element_blank()) +
      geom_text(label = paste0(format(head(data$plot_livres_langues[order(data$plot_livres_langues$nb_livres_lus, decreasing = TRUE),],10)$nb_livres_lus, big.mark=" ", digits = 1, scientific=FALSE), " (", head(data$plot_livres_langues[order(data$plot_livres_langues$nb_livres_lus, decreasing = TRUE),],10)$pourc, " %)"), check_overlap = TRUE, color="white", position = position_stack(vjust=0.5))
  })
  
  
  output$plot_pages_langues <- renderPlot({
    req(input$library_csv)
    
    data$plot_pages_langues = mutate(inner_join(summarize(group_by(data$library[data$library$Histoire=="Oui",], Langue), nb_pages=sum(Pages)), summarize(group_by(data$library[data$library$Histoire=="Oui",], Langue), nb_pages_lues=sum(Pages[Lu=="Oui"], na.rm = TRUE)), by = "Langue"), pourc=round(nb_pages_lues/nb_pages*100,2))
    
    ggplot(head(data$plot_pages_langues[order(data$plot_pages_langues$nb_pages_lues, decreasing = TRUE),],10), aes(x=reorder(Langue, nb_pages_lues), y=pourc)) + 
      geom_bar(stat = "identity", fill="#00CC33") + 
      coord_flip() +
      labs(x = "langues", title = "Taux de pages lues") +
      theme_bw() + 
      theme(legend.position = "none", panel.grid.major = element_blank(), panel.grid.minor = element_blank(), axis.title.x = element_blank(), axis.text.x = element_blank(), axis.ticks.x = element_blank()) +
      geom_text(label = paste0(format(head(data$plot_pages_langues[order(data$plot_pages_langues$nb_pages_lues, decreasing = TRUE),],10)$nb_pages_lues, big.mark=" ", digits = 1, scientific=FALSE), " (", head(data$plot_pages_langues[order(data$plot_pages_langues$nb_pages_lues, decreasing = TRUE),],10)$pourc, " %)"), check_overlap = TRUE, color="white", position = position_stack(vjust=0.5))
  })
  
  
# ------------------------------------------------------------------------------
#                                    Page 3.5
# ------------------------------------------------------------------------------
  
  observeEvent(input$library_csv,{
    data$library_siecle = data$library %>%
      mutate(Siècle = case_when(Date>0 ~ paste0(as.roman((Date-1)%/%100+1), "e"), Date<0 ~ paste0(as.roman(substring(Date-100, 2, str_length(Date-100)-2)), "e BC")))
    updateSelectInput(inputId = "choix_siecle", choices = sort(unique(data$library_siecle$Siècle)), selected = ifelse(siecle_default %in% data$library_siecle$Siècle, siecle_default, NULL))
  })
  
  
  output$nb_livres_siecle <- renderText({
    req(input$library_csv)
    
    data$nb_livres_siecle = nrow(filter(data$library_siecle, Siècle == input$choix_siecle))
    
    paste0(format(data$nb_livres_siecle, big.mark = " ", scientific = FALSE), " (", round(data$nb_livres_siecle/nrow(filter(data$library, Histoire == "Oui"))*100,2), " %)")
  })
  
  
  output$nb_livres_lus_siecle <- renderText({
    req(input$library_csv)
    
    data$nb_livres_lus_siecle = nrow(filter(data$library_siecle, Siècle == input$choix_siecle, Lu == "Oui"))
    
    paste0(format(data$nb_livres_lus_siecle, big.mark = " ", scientific = FALSE), " (", round(data$nb_livres_lus_siecle/data$nb_livres_siecle*100,2), " %)")
  })
  
  
  output$nb_pages_siecle <- renderText({
    req(input$library_csv)
    
    data$nb_pages_siecle=sum(filter(data$library_siecle, Siècle == input$choix_siecle)$Pages)
    
    paste0(format(data$nb_pages_siecle, big.mark = " ", scientific = FALSE), " (", round(data$nb_pages_siecle/sum(data$library[["Pages"]])*100,2), " %)")
  })
  
  
  output$nb_pages_lues_siecle <- renderText({
    req(input$library_csv)
    
    data$nb_pages_lues_siecle=sum(filter(data$library_siecle, Siècle == input$choix_siecle, Lu == "Oui")$Pages)
    
    paste0(format(data$nb_pages_lues_siecle, big.mark = " ", scientific = FALSE), " (", round(data$nb_pages_lues_siecle/data$nb_pages_siecle*100,2), " %)")
  })
  
  
  output$table_stat_siecle <- renderDT({
    req(input$library_csv, input$choix_siecle)
    
    data$table_stat_siecle = data$library_siecle %>%
      filter(Siècle == input$choix_siecle, Histoire == "Oui") %>%
      select("Titre", "Auteur", "Date") %>%
      arrange(Date)
    
    datatable(data$table_stat_siecle, options = list(scrollY = "350px", paging = FALSE, searching = FALSE, pageLenght = -1, lengthMenu = list(c(-1, 10,25,50,100), c("Tout", "10", "25", "50", "100"))), rownames = FALSE)
  })
  
  
  output$plot_livres_siecles <- renderPlot({
    
    req(input$library_csv)
    
    data$plot_livres_siecles = mutate(inner_join(summarize(group_by(data$library_siecle[data$library_siecle$Histoire=="Oui",], Siècle), nb_livres=n()), summarize(group_by(data$library_siecle[data$library_siecle$Histoire=="Oui",], Siècle), nb_livres_lus=sum(na.omit(Lu)=="Oui")), by = "Siècle"), pourc=round(nb_livres_lus/nb_livres*100,2))
    
    ggplot(head(data$plot_livres_siecles[order(data$plot_livres_siecles$nb_livres_lus, decreasing = TRUE),],10), aes(x=reorder(Siècle, nb_livres_lus), y=pourc)) + 
      geom_bar(stat = "identity", fill="#00CC33") + 
      coord_flip() +
      labs(x = "siecles", title = "Taux de livres lus") +
      theme_bw() + 
      theme(legend.position = "none", panel.grid.major = element_blank(), panel.grid.minor = element_blank(), axis.title.x = element_blank(), axis.text.x = element_blank(), axis.ticks.x = element_blank()) +
      geom_text(label = paste0(format(head(data$plot_livres_siecles[order(data$plot_livres_siecles$nb_livres_lus, decreasing = TRUE),],10)$nb_livres_lus, big.mark=" ", digits = 1, scientific=FALSE), " (", head(data$plot_livres_siecles[order(data$plot_livres_siecles$nb_livres_lus, decreasing = TRUE),],10)$pourc, " %)"), check_overlap = TRUE, color="white", position = position_stack(vjust=0.5))
  })
  
  
  output$plot_pages_siecles <- renderPlot({
    req(input$library_csv)
    
    data$plot_pages_siecles = mutate(inner_join(summarize(group_by(data$library_siecle[data$library_siecle$Histoire=="Oui",], Siècle), nb_pages=sum(Pages)), summarize(group_by(data$library_siecle[data$library$Histoire=="Oui",], Siècle), nb_pages_lues=sum(Pages[Lu=="Oui"], na.rm = TRUE)), by = "Siècle"), pourc=round(nb_pages_lues/nb_pages*100,2))
    
    ggplot(head(data$plot_pages_siecles[order(data$plot_pages_siecles$nb_pages_lues, decreasing = TRUE),],10), aes(x=reorder(Siècle, nb_pages_lues), y=pourc)) + 
      geom_bar(stat = "identity", fill="#00CC33") + 
      coord_flip() +
      labs(x = "siecles", title = "Taux de pages lues") +
      theme_bw() + 
      theme(legend.position = "none", panel.grid.major = element_blank(), panel.grid.minor = element_blank(), axis.title.x = element_blank(), axis.text.x = element_blank(), axis.ticks.x = element_blank()) +
      geom_text(label = paste0(format(head(data$plot_pages_siecles[order(data$plot_pages_siecles$nb_pages_lues, decreasing = TRUE),],10)$nb_pages_lues, big.mark=" ", digits = 1, scientific=FALSE), " (", head(data$plot_pages_siecles[order(data$plot_pages_siecles$nb_pages_lues, decreasing = TRUE),],10)$pourc, " %)"), check_overlap = TRUE, color="white", position = position_stack(vjust=0.5))
  })
  
  
# ------------------------------------------------------------------------------
#                                    Page 4
# ------------------------------------------------------------------------------

  # JavaScript pour initialiser et contrôler la roue
  observe({
    # Initialisation du JavaScript après le chargement de la page
    session$onFlushed(function() {
      js <- paste0('
        // Récupération des éléments HTML
        const wheel = document.getElementById("wheel");
        const spinBtn = document.getElementById("spin-btn");
        const finalValue = document.getElementById("final-value");

        // Valeurs de rotation pour déterminer le résultat
        const rotationValues = [
          { minDegree: 0, maxDegree: 44, value: "', wheel_labels[1], '" },
          { minDegree: 45, maxDegree: 89, value: "', wheel_labels[2], '" },
          { minDegree: 90, maxDegree: 134, value: "', wheel_labels[3], '" },
          { minDegree: 135, maxDegree: 179, value: "', wheel_labels[4], '" },
          { minDegree: 180, maxDegree: 224, value: "', wheel_labels[5], '" },
          { minDegree: 225, maxDegree: 269, value: "', wheel_labels[6], '" },
          { minDegree: 270, maxDegree: 314, value: "', wheel_labels[7], '" },
          { minDegree: 315, maxDegree: 360, value: "', wheel_labels[8], '" }
        ];

        // Taille de chaque section
        const data = [1, 1, 1, 1, 1, 1, 1, 1];

        // Couleurs pour chaque section
        const pieColors = ["', paste(wheel_colors, collapse = '", "'), '"];

        // Création du graphique avec Chart.js
        let myChart = new Chart(wheel, {
          plugins: [ChartDataLabels],
          type: "pie",
          data: {
            labels: ["', paste(wheel_labels, collapse = '", "'), '"],
            datasets: [
              {
                backgroundColor: pieColors,
                data: data,
              },
            ],
          },
          options: {
            responsive: true,
            animation: { duration: 0 },
            plugins: {
              tooltip: false,
              legend: {
                display: false,
              },
              datalabels: {
                color: "#ffffff",
                formatter: (_, context) => context.chart.data.labels[context.dataIndex],
                font: { size: 16 },
              },
            },
          },
        });

        // Fonction pour afficher le résultat
        const valueGenerator = (angleValue) => {
          for (let i of rotationValues) {
            if (angleValue >= i.minDegree && angleValue <= i.maxDegree) {

              spinBtn.disabled = false;
              break;
            }
          }
        };

        // Variables pour la rotation
        let count = 0;
        let resultValue = 101;

        // Gestionnaire d\'événement pour le bouton de rotation
        spinBtn.addEventListener("click", () => {
          spinBtn.disabled = true;
          finalValue.innerHTML = `<p>Bonne chance !</p>`;

          // Angle aléatoire pour s\'arrêter
          let randomDegree = Math.floor(Math.random() * (355 - 0 + 1) + 0);

          // Intervalle pour l\'animation de rotation
          let rotationInterval = window.setInterval(() => {
            myChart.options.rotation = myChart.options.rotation + resultValue;
            myChart.update();

            if (myChart.options.rotation >= 360) {
              count += 1;
              resultValue -= 5;
              myChart.options.rotation = 0;
            } else if (count > 15 && myChart.options.rotation == randomDegree) {
              valueGenerator(randomDegree);
              clearInterval(rotationInterval);
              count = 0;
              resultValue = 101;
            }
          }, 10);
        });
      ')
      
      # Exécution du JavaScript
      shinyjs::runjs(js)
    })
  })
  
  
}


# ==============================================================================
#                           Lancement de l'application
# ==============================================================================

shinyApp(ui = ui, server = server)
