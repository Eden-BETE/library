
# ==============================================================================
#                            Chargement des packages
# ==============================================================================

library(shiny)
library(shinydashboard)
library(shinycssloaders)
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
library(jsonlite)
library(gtools)
library(tmap)
library(sf)
library(plotly)
library(leaflet)


# ==============================================================================
#                                   Chemins
# ==============================================================================

setwd(dirname(rstudioapi::getActiveDocumentContext()$path))

config <- fromJSON("www/config.json")

link_to_data = config$link$link_to_data
link_to_css = config$link$link_to_css
link_to_livres = config$link$link_to_livres


# ==============================================================================
#                                 Credentials
# ==============================================================================

credentials = read.xlsx(config$link$link_to_credentials)


# ==============================================================================
#                                 Carte
# ==============================================================================

world_map = read_sf(dsn = "www/World.shp", layer = "World") %>%
  select(french_shor, geometry)

world_map$french_shor[which(world_map$french_shor == "États-Unis d'Amérique")] = "Etats-Unis"
world_map$french_shor[which(world_map$french_shor == "Équateur")] = "Equateur"
world_map$french_shor[which(world_map$french_shor == "République-Unie de Tanzanie")] = "Tanzanie"
world_map$french_shor[which(world_map$french_shor == "République arabe syrienne")] = "Syrie"
world_map$french_shor[which(world_map$french_shor == "Fédération de Russie")] = "Russie"
world_map$french_shor[which(world_map$french_shor == "République de Corée")] = "Corée du sud"
world_map$french_shor[which(world_map$french_shor == "Érythrée")] = "Erythrée"
world_map$french_shor[which(world_map$french_shor == "Royaume-Uni de Grande-Bretagne et d'Irlande du Nord")] = "Royaume-Uni"
world_map$french_shor[which(world_map$french_shor == "Cabo Verde")] = "Cap-Vert"
world_map$french_shor[which(world_map$french_shor == "Émirats arabes unis")] = "Emirats arabes unis"
world_map$french_shor[which(world_map$french_shor == "Éthiopie")] = "Ethiopie"
world_map$french_shor[which(world_map$french_shor == "État de Palestine")] = "Palestine"
world_map$french_shor[which(world_map$french_shor == "Égypte")] = "Egypte"
world_map$french_shor[which(world_map$french_shor == "Greenland")] = "Groënland"
world_map$french_shor[which(world_map$french_shor == "Îles Marshall")] = "Iles Marshall"
world_map$french_shor[which(world_map$french_shor == "Îles Salomon")] = "Iles Salomon"
world_map$french_shor[which(world_map$french_shor == "Îles Cook")] = "Iles Cook"
world_map$french_shor[which(world_map$french_shor == "République de Moldova")] = "Moldavie"
world_map$french_shor[which(world_map$french_shor == "République populaire démocratique de Corée")] = "Corée du nord"
world_map$french_shor[which(world_map$french_shor == "République démocratique populaire lao")] = "Laos"
world_map$french_shor[which(world_map$french_shor == "Bélarus")] = "Biélorussie"


# ==============================================================================
#                                  Variables
# ==============================================================================

# Couleurs pour la roue
wheel_colors <- c("#8b35bc", "#b163da", "#FF5733", "#33FF57", "#3357FF", "#F3FF33", "#FF33F3", "#33FFF3")
wheel_labels <- c("Violet", "Lilas", "Orange", "Vert", "Bleu", "Jaune", "Rose", "Cyan")


bleu_light = rgb(0, 0, 50, maxColorValue = 255)

auteur_default="Dante Alighieri"
pays_default="Français"
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


#data=read.xlsx("C:/Users/theod/OneDrive/Documents/Perso/Livres/Bibliothèque/bibliothèques/library.xlsx")
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
      menuItem("Graphiques", tabName = "graph", icon = icon("chart-pie")),
      menuItem("Tous les livres", tabName = "stat_livres", icon = icon("chart-bar")),
      menuItem("Sur les auteurs", tabName = "stat_auteur", icon = icon("user")),
      menuItem("Sur les genres", tabName = "stat_genre", icon = icon("bookmark")),
      menuItem("Sur les pays", tabName = "stat_pays", icon = icon("earth-europe")),
      menuItem("Sur les siècles", tabName = "stat_siecle", icon = icon("calendar")),
      menuItem("Spinner Wheel", tabName = "spinner_wheel", icon = icon("sync")),
      uiOutput("sidebar_user"),
      menuItem("Comment ça marche ?", tabName = "info", icon = icon("question")),
      uiOutput("sidebar_invite")
    )
  ),
  dashboardBody(
    # Activez shinyjs
    useShinyjs(),

    # Chargez les scripts externes pour Chart.js
    tags$head(
      tags$script(src = "https://cdnjs.cloudflare.com/ajax/libs/Chart.js/3.9.1/chart.min.js"),
      tags$script(src = "https://cdnjs.cloudflare.com/ajax/libs/chartjs-plugin-datalabels/2.1.0/chartjs-plugin-datalabels.min.js")
    ),

    tabItems(

      
# ------------------------------------------------------------------------------
#                                    Page 1
# ------------------------------------------------------------------------------

      tabItem(
        tabName = "bibliotheque",
        box(
          title = "Ma bibliothèque",
          status = "primary",
          solidHeader = TRUE,
          width = 12,
          height = "80vh",
        column(12,
          column(12,
            column(12,
              uiOutput(outputId = "conditional_choix_feuille")
            ),
            column(12,
              column(4,
                selectInput(inputId = "choix_tous_livres", label = "Quels livres ?", choices = list("Tous les livres" = 1, "Livres possédés" = 2, "Livres lus" = 3, "Livres aimés" = 4), selected = 1, multiple = FALSE)
              ),
              column(8,
                uiOutput(outputId = "checkbox_genre_ui")
              )
            )
          )
        ),
        withSpinner(DTOutput(outputId = "table_data", width = "100%", height = "47vh"), type = 5, color = "red")
      )
      ),


# ------------------------------------------------------------------------------
#                                    Page 2
# ------------------------------------------------------------------------------

      tabItem(
        tabName = "rangement",
        box(
          title = "Mon rangement",
          status = "primary",
          solidHeader = TRUE,
          width = 12,
        fluidRow(
          column(12, class = "centered-select",
            column(4,
              div(class = "select-input-tri",
                selectInput("tri", "Trier par", choices = c("Auteur", "Date", "Genre", "Titre"), selected = "Date")
              )
            ),
            column(4,
              div(class = "select-input-tri",
                uiOutput("conditional_input_genre_genre")
              )
            ),
            column(4,
              div(class = "select-input-tri",
                uiOutput("conditional_input_genre_tri")
              )
            )
          ),
          column(12,
            column(12,
              DTOutput("table_tri", height = "60vh")
            )
          )
        )
        )
      ),


# ------------------------------------------------------------------------------
#                                    Page 3
# ------------------------------------------------------------------------------

      tabItem(
        tabName = "graph",
        box(
          title = "Statstiques", 
          status = "primary",
          solidHeader = TRUE,
          width = 12,
        fluidRow(
          column(8,
            withSpinner(leafletOutput(outputId = "carte_plot", height = "40vh"), type = 5, color = "red")
          ),
          column(2,
            withSpinner(plotlyOutput(outputId = "violin_plot_pages", height = "40vh"), type = 5, color = "red")
          ),
          column(2,
            withSpinner(plotlyOutput(outputId = "violin_plot_duree", height = "40vh"), type = 5, color = "red")
          ),
          column(12,
            withSpinner(plotlyOutput(outputId = "lus_plot", height = "30vh"), type = 5, color = "red")
          )
        )
        )
      ),


# ------------------------------------------------------------------------------
#                                    Page 4
# ------------------------------------------------------------------------------

      tabItem(
        tabName = "stat_livres",
        box(
          title = "Stats de livres",
          status = "primary",
          solidHeader = TRUE,
          width = 12,
        fluidRow(
          column(3,
            box(
              title = "Nombre de livres",
              status = "primary",
              solidHeader = TRUE,
              width = 12,
              uiOutput(outputId = "nb_livres_ui")
            )
          ),
          column(3,
            box(
              title = "Nombre de livres lus",
              status = "primary",
              solidHeader = TRUE,
              width = 12,
              uiOutput(outputId = "nb_livres_lus_ui")
            )
          ),
          column(3,
            box(
              title = "Nombre de livres aimés",
              status = "primary",
              solidHeader = TRUE,
              width = 12,
              uiOutput(outputId = "nb_livres_aimes_ui")
            )
          ),
          column(3,
            box(
              title = "Nombre de livres possédés",
              status = "primary",
              solidHeader = TRUE,
              width = 12,
              uiOutput(outputId = "nb_livres_a_soi_ui")
            )
          )
        ),
        br(), br(),
        fluidRow(
          column(4,
            box(
              title = "Nombre de pages",
              status = "primary",
              solidHeader = TRUE,
              width = 12,
              uiOutput(outputId = "nb_pages_ui")
            )
          ),
          column(4,
            box(
              title = "Nombre de pages lues",
              status = "primary",
              solidHeader = TRUE,
              width = 12,
              uiOutput(outputId = "nb_pages_lues_ui")
            )
          ),
          column(4,
            box(
              title = "Prix total",
              status = "primary",
              solidHeader = TRUE,
              width = 12,
              uiOutput(outputId = "prix_total_ui")
            )
          )
        ),
        br(), br(), 
        fluidRow(
          column(3,
            box(
              title = "Nombre d'auteurs différents",
              status = "primary",
              solidHeader = TRUE,
              width = 12,
              uiOutput(outputId = "nb_auteurs_ui")
            )
          ),
          column(3,
            box(
              title = "Nombre de genres différents",
              status = "primary",
              solidHeader = TRUE,
              width = 12,
              uiOutput(outputId = "nb_genres_ui")
            )
          ),
          column(3,
            box(
              title = "Nombre de pays d'origine",
              status = "primary",
              solidHeader = TRUE,
              width = 12,
              uiOutput(outputId = "nb_pays_origine_ui")
            )
          ),
          column(3,
            box(
              title = "Nombre de langues d'écriture",
              status = "primary",
              solidHeader = TRUE,
              width = 12,
              uiOutput(outputId = "nb_langue_ecriture_ui")
            )
          )
        ),
        br(), br(),
        fluidRow(
          column(3,
            box(
              title = "Auteur préféré",
              status = "primary",
              solidHeader = TRUE,
              width = 12,
              uiOutput(outputId = "auteur_fav_ui")
            )
          ),
          column(3,
            box(
              title = "Genre préféré",
              status = "primary",
              solidHeader = TRUE,
              width = 12,
              uiOutput(outputId = "genre_fav_ui")
            )
          ),
          column(3,
            box(
              title = "Pays d'origine préféré",
              status = "primary",
              solidHeader = TRUE,
              width = 12,
              uiOutput(outputId = "pays_origine_fav_ui")
            )
          ),
          column(3,
            box(
              title = "Langue d'écriture préférée",
              status = "primary",
              solidHeader = TRUE,
              width = 12,
              uiOutput(outputId = "langue_ecriture_fav_ui")
            )
          )
        )
        )
      ),


# ------------------------------------------------------------------------------
#                                    Page 5
# ------------------------------------------------------------------------------

      tabItem(
        tabName = "stat_auteur",
        box(
          title = "Stats de auteurs",
          status = "primary",
          solidHeader = TRUE,
          width = 12,
        fluidRow(
          column(6,
            br(), br(),
            column(12,
              uiOutput(outputId = "ui_choix_auteur")
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
        ),
        br(), br(), hr(), br(),
        fluidRow(style = "text-align: center;",
          column(6,
            h2("Taux de livres lus", class = "titre-graph"),
            withSpinner(plotOutput("plot_livres_auteurs"), type = 5, color = "red")
          ),
          column(6,
            h2("Taux de pages lues", class = "titre-graph"),
            withSpinner(plotOutput("plot_pages_auteurs"), type = 5, color = "red")
          )
        )
        )
      ),


# ------------------------------------------------------------------------------
#                                    Page 6
# ------------------------------------------------------------------------------

      tabItem(
        tabName = "stat_genre",
        box(
          title = "Stats de genres",
          status = "primary",
          solidHeader = TRUE,
          width = 12,
        fluidRow(
          column(6,
            br(), br(),
            column(12,
              uiOutput(outputId = "ui_choix_genre")
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
        ),
        br(), br(), hr(), br(),
        fluidRow(style = "text-align: center;",
          column(6,
            h2("Taux de livres lus", class = "titre-graph"),
            withSpinner(plotOutput("plot_livres_genres"), type = 5, color = "red")
          ),
          column(6,
            h2("Taux de pages lues", class = "titre-graph"),
            withSpinner(plotOutput("plot_pages_genres"), type = 5, color = "red")
          )
        )
        )
      ),


# ------------------------------------------------------------------------------
#                                    Page 7
# ------------------------------------------------------------------------------

      tabItem(
        tabName = "stat_pays",
        box(
          title = "Stats de pays",
          status = "primary",
          solidHeader = TRUE,
          width = 12,
        fluidRow(
          column(6,
            br(), br(),
            column(12,
              uiOutput(outputId = "ui_choix_pays")
            ),
            box(
              title = "Nombres de livres",
              status = "primary",
              width = 6,
              solidHeader = TRUE,
              h2(textOutput(outputId = "nb_livres_pays"), class = "text-stat")
            ),
            box(
              title = "Nombres de livres lus",
              status = "primary",
              width = 6,
              solidHeader = TRUE,
              h2(textOutput(outputId = "nb_livres_lus_pays"), class = "text-stat")
            ),
            box(
              title = "Nombres de pages",
              status = "primary",
              width = 6,
              solidHeader = TRUE,
              h2(textOutput(outputId = "nb_pages_pays"), class = "text-stat")
            ),
            box(
              title = "Nombres de pages lues",
              status = "primary",
              width = 6,
              solidHeader = TRUE,
              h2(textOutput(outputId = "nb_pages_lues_pays"), class = "text-stat")
            ),
          ),
          column(6,
            DTOutput(outputId = "table_stat_pays")
          )
        ),
        br(), br(), hr(), br(),
        fluidRow(style = "text-align: center;",
          column(6,
            h2("Taux de livres lus", class = "titre-graph"),
            withSpinner(plotOutput("plot_livres_pays"), type = 5, color = "red")
          ),
          column(6,
            h2("Taux de pages lues", class = "titre-graph"),
            withSpinner(plotOutput("plot_pages_pays"), type = 5, color = "red")
          )
        )
        )
      ),


# ------------------------------------------------------------------------------
#                                    Page 8
# ------------------------------------------------------------------------------
        
      tabItem(
        tabName = "stat_siecle",
        box(
          title = "Stats de siècles",
          status = "primary",
          solidHeader = TRUE,
          width = 12,
        fluidRow(
          column(6,
            br(), br(),
            column(12,
              uiOutput(outputId = "ui_choix_siecle")
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
        ),
        br(), br(), hr(), br(),
        fluidRow(style = "text-align: center;",
          column(6,
            h2("Taux de livres lus", class = "titre-graph"),
            withSpinner(plotOutput("plot_livres_siecles"), type = 5, color = "red")
          ),
          column(6,
            h2("Taux de pages lues", class = "titre-graph"),
            withSpinner(plotOutput("plot_pages_siecles"), type = 5, color = "red")
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
      ),


# ------------------------------------------------------------------------------
#                                Page 9.1 - User
# ------------------------------------------------------------------------------

      tabItem(
        tabName = "ajout_livre",
        fluidRow(
          box(
            title = "Vérifier sur le livre est dans la base de données",
            status = "primary",
            solidHeader = TRUE,
            width = 12,
            textInput(inputId = "input_verif_livre_bibliotheque", label = "Entrer l'ISBN du livre"),
            textOutput(outputId = "output_verif_livre_bibliotheque")
          ),
          uiOutput(outputId = "ajout_bibliotheque")
        )
      ),


# ------------------------------------------------------------------------------
#                               Page 9.2 - User
# ------------------------------------------------------------------------------

      tabItem(
        tabName = "modif_livre",
        uiOutput(outputId = "choix_isbn_modif"),
        uiOutput(outputId = "modif_info_livre")
      ),


# ------------------------------------------------------------------------------
#                                   Page 10
# ------------------------------------------------------------------------------

      tabItem(
        tabName = "info",
        fluidRow(
          column(12,
            box(
              title = span(icon("server"), " L'application"),
              status = "primary",
              solidHeader = TRUE,
              width = 12,
              collapsible = TRUE,
              collapsed = TRUE,
              fluidRow(
                column(12,
                  h4("blablabla", class = "text-info")
                )
              )
            )
          )
        ),
        fluidRow(
          column(12,
            box(
              title = span(icon("book"), "Bibliothèque"),
              status = "primary",
              solidHeader = TRUE,
              width = 6,
              collapsible = TRUE,
              collapsed = TRUE,
              fluidRow(
                column(12,
                  h4("blablabla sur la bibliothèque", class = "text-info")
                )
              )
            ),
            box(
              title = span(icon("folder"), "Rangement"),
              status = "primary",
              solidHeader = TRUE,
              width = 6,
              collapsible = TRUE,
              collapsed = TRUE,
              fluidRow(
                column(12,
                  h4("blablabla sur le rangement", class = "text-info")
                )
              )
            )
          )
        ),
        fluidRow(
          column(12,
            box(
              title = span(icon("chart-bar"), "Statistiques"),
              status = "primary",
              solidHeader = TRUE,
              width = 6,
              collapsible = TRUE,
              collapsed = TRUE,
              fluidRow(
                column(12,
                  h4("blablabla sur les stats", class = "text-info")
                )
              )
            )
          )
        )
      ),


# ------------------------------------------------------------------------------
#                               Page 11 - Invité
# ------------------------------------------------------------------------------

      tabItem(
        tabName = "create_library",
        fluidRow(
          column(12,
            box(
              title = "Créer ma bibliothèque",
              status = "primary",
              solidHeader = TRUE,
              width = 12,
              column(3, 
                textInput(inputId = "create_user", label = "Choisissez votre nom d'utilisateur", width = "100%"),
                h4(textOutput(outputId = "create_user_deja_pris"), class = "text-create")
              ),
              column(3,
                passwordInput(inputId = "create_password", label = "Choisissez un mot de passe")
              ),
              column(3,
                passwordInput(inputId = "confirm_password", label = "Confirmez votre mot de passe"),
                h4(textOutput(outputId = "confirm_password_wrong"), class = "text-create")
              ),
              column(3,
                textInput(inputId = "create_library_name", label = "Choisissez le nom de votre bibliothèque")
              )
            ),
            fluidRow(style = "text-align:center;",
              column(12,
                uiOutput("button_create_library_ui")
              )
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
  
  data$livres = read.xlsx(link_to_livres)
  
  
# ------------------------------------------------------------------------------
#                               Authentification
# ------------------------------------------------------------------------------
  
  res_auth <- secure_server(
    check_credentials = check_credentials(credentials)
  )
  
  output$auth_output <- renderPrint({
    reactiveValuesToList(res_auth)
  })
  
  
# ------------------------------------------------------------------------------
#                                Sidebar User
# ------------------------------------------------------------------------------
  
  output$sidebar_user <- renderUI({
    
    if (res_auth$user != "invité") {
      sidebarMenu(
        menuItem("Mise à jour", tabName = "maj", icon = icon("sync"),
          menuSubItem("Ajout d'un livre", tabName = "ajout_livre"),
          menuSubItem("Modification", tabName = "modif_livre")
        )
      )
    }
  })

  
 
# ------------------------------------------------------------------------------
#                               Sidebar Invité
# ------------------------------------------------------------------------------
   
  output$sidebar_invite <- renderUI({
    
    if (res_auth$user == "invité") {
      sidebarMenu(
        menuItem(text = "Créer ma bibliothèque", tabName = "create_library")
      )
    }
  })


# ------------------------------------------------------------------------------
#                                    Page 1
# ------------------------------------------------------------------------------
  
  library_name = reactive(credentials$library[which(credentials$user == res_auth$user)])
  
  
  link_to_library = reactive(paste0(link_to_data, library_name()))

  
  output$conditional_choix_feuille <- renderUI({
    
    if(length(excel_sheets(paste0(link_to_library())))>1) {
      selectInput("choix_feuille", label = "Choisir une feuille du fichier", width = "100%", choices = excel_sheets(paste0(link_to_library())))
    }
  })
  
  output$table_data <- renderDT({
    
      if (length(excel_sheets(paste0(link_to_library())))>1) {
        sheet = input$choix_feuille
      } else {
        sheet = excel_sheets(paste0(link_to_library()))[1]
      }
      data$table_library = read_xlsx(paste0(link_to_library()), col_names = TRUE, sheet = sheet)
    
    data$library = filter(data$table_library, Genre %in% input$checkbox_genre) %>%
      mutate(Longueur = as.numeric(Longueur), Pages = as.numeric(Pages)) %>%
      filter(case_when(input$choix_tous_livres == 2 ~ Bibliothèque == "Oui", input$choix_tous_livres == 3 ~ Lu == "Oui", input$choix_tous_livres == 4 ~ Favori == "Oui", input$choix_tous_livres == 1 ~ !is.null(Titre)))

    
    datatable(data$library, class = "table-library", options = list(scrollX = TRUE, scrollY = "47vh", info = FALSE, searching = FALSE, pageLenght = -1, ordering = FALSE, paging = FALSE, fixedHeader = TRUE, fixedColumns = list(leftColumns = 1), columnDefs = list(list(targets = "_all", className = "dt-center"), list(targets = c(0, 1, 10, 12, 13, 16), width = "400px")), lengthMenu = list(c(-1), c("Tout"))), rownames = FALSE)
  })
  
  
  output$checkbox_genre_ui <- renderUI ({
    fluidRow(
      checkboxGroupInput(inputId = "checkbox_genre", label = "Sélectionner les genres à afficher", choices = sort(unique(data$table_library$Genre)), selected = sort(unique(data$table_library$Genre)), inline = TRUE)
    )
  })
  

# ------------------------------------------------------------------------------
#                                    Page 2
# ------------------------------------------------------------------------------
  
  output$conditional_input_genre_genre <- renderUI({
    if (input$tri == "Genre") {
      selectInput(inputId = "genres", label = "Genre", choices = sort(unique(data$library$Genre)), selected = "Littérature")
    }
  })
  
  output$conditional_input_genre_tri <- renderUI({
    if (input$tri == "Genre") {
      selectInput(inputId = "tri_genres", label = "Trier le genre par", choices = c("Auteur", "Date", "Titre"), selected = "Date")
    }
  })
  
  output$table_tri <- renderDT({
    req(input$tri)
    
    data_library_tri = data$library  %>%
      arrange(!!sym(input$tri))
    
    if (!!sym(input$tri) == "Auteur") {
      data_library_tri = data$library[order(sapply(strsplit(as.character(data$library$Auteur), " "), function(x) ifelse(length(x)>1, x[2], x[1]))),]
    }
    
    if (!!sym(input$tri) == "Genre") {
      req(input$genres, input$tri_genres)
      
      data_library_tri = data_library_tri %>%
        filter(Genre == input$genres) %>%
        arrange(!!sym(input$tri_genres))
      
      if (!!sym(input$tri_genres) == "Auteur") {
        data_library_tri = data_library_tri[order(sapply(strsplit(as.character(data_library_tri$Auteur), " "), function(x) ifelse(length(x)>1, x[2], x[1]))),]
      }
    }
    
    datatable(select(data_library_tri, "Titre", "Auteur", "Date", "Genre"), class = "table-triee", options = list(scrollX = TRUE, scrollY = "60vh", info = FALSE, fixedHeader = TRUE, fixedColumns = list(leftColumns = 1), paging = FALSE, ordering = FALSE, searching = FALSE, pageLenght = -1, columnDefs = list(list(targets = "_all", className = "dt-center")), lengthMenu = list(c(-1, 10,25,50,100), c("Tout", "10", "25", "50", "100"))), rownames = FALSE)
      
  })

  
# ------------------------------------------------------------------------------
#                                    Page 3
# ------------------------------------------------------------------------------
  
  output$carte_plot <- renderLeaflet({
    data$carte = data$library %>%
      group_by(Origine) %>%
      summarize(n = n())
    
    data$data_map = left_join(world_map, data$carte, by = c("french_shor" = "Origine")) %>%
      mutate(n = ifelse(is.na(n), 0, n)) %>%
      rename("Pays" = "french_shor", "Nombre de livres" = "n")
    
    tmap_mode("view")
    tm = tm_shape(data$data_map) + 
    tm_borders() + 
    tm_crs("auto") + 
    tm_polygons(col = "Nombre de livres", palette = colorRampPalette(c("white", "blue"))(100), style = "cont") + 
    tm_scale_continuous() +
    tm_layout(panel.margin = element_blank(), legend.show = FALSE, grid.show = FALSE, frame = FALSE, credits.colors = bleu_light)
    
    tmap_leaflet(tm)
  })
  
  
  output$lus_plot <- renderPlotly({
    
    data$lus = data$library %>%
      filter(Lu == "Oui") %>%
      mutate(Commencé = format(dmy(Commencé), "%d-%m-%Y"), Fini = format(dmy(Fini), "%d-%m-%Y")) %>%
      mutate(month = floor_date(dmy(Fini), "month")) %>%
      count(month) %>%
      complete(month = seq(min(.$month), max(.$month), by = "month"), fill = list(n = 0)) %>%
      rename("Nombre de livres lus" = n, "Mois" = month)
    
    
    graph_livres_plot_mois = ggplotly(ggplot(data$lus, aes(x = Mois, y = `Nombre de livres lus`)) +
                                        geom_line(color = "blue") +
                                        labs(title = "", x = "Mois", y = "Nombre de livres lus"))
    
    graph_livres_plot_mois$x$config$displayModeBar <- FALSE
    
    graph_livres_plot_mois
    
    
  })
  
  
  output$violin_plot_pages <- renderPlotly({
    violin_plot_pages = layout(ggplotly(ggplot(data$library, aes(x = "", y = Pages)) +
                                          geom_violin(fill = "blue", color = "blue") +
                                          theme_bw()),
                               yaxis = list(title = list(text = "Nombre de pages", font = list(color = "blue"))))
    
    violin_plot_pages$x$config$displayModeBar <- FALSE
    
    violin_plot_pages
    
  })
  
  
  output$violin_plot_duree <- renderPlotly({
    
    data$violin_plot_duree = mutate(data$library, Durée = as.numeric(ifelse(!is.na(Fini), as.numeric(difftime(as.Date(Fini, format = "%d-%m-%Y"), as.Date(Commencé, format = "%d-%m-%Y"), unit = "days")), ""))) %>%
      filter(Lu %in% c("Oui"))
    
    violin_plot_duree = layout(ggplotly(ggplot(data$violin_plot_duree, aes(x = "", y = Durée)) +
                                   geom_violin(fill = "blue", color = "blue")),
                               yaxis = list(side = "right", title = list(text = "Durée de lecture", font = list(color = "blue"), angle = 90)))
    
    violin_plot_duree$x$config$displayModeBar <- FALSE
    
    violin_plot_duree
    
  })
  
  
# ------------------------------------------------------------------------------
#                                    Page 4
# ------------------------------------------------------------------------------
  
  output$nb_livres_ui <- renderUI({
    h2(textOutput(outputId = "nb_livres"), class = "text-stat")

  })
  
  output$nb_livres <- renderText({
    
    data$nb_livres = data$library %>%
      nrow()
    
    format(data$nb_livres, big.mark = " ", scientific = FALSE)
  })
  
  
  output$nb_livres_lus_ui <- renderUI({
    if ("Lu" %in% colnames(data$library)) {
      h2(textOutput(outputId = "nb_livres_lus"), class = "text-stat")
    } else {
      h2("[Pas de données indiquant les livres lus]", class = "text-stat-erreur")
    }
  })
  
  output$nb_livres_lus <- renderText({
    
    data$nb_livres_lus <- filter(data$library, .data$Lu=="Oui")
    
    paste0(format(nrow(data$nb_livres_lus), big.mark = " ", scientific = FALSE), " (", round(nrow(data$nb_livres_lus)/nrow(data$library)*100,2), " %)")
  })
  
  
  output$nb_livres_aimes_ui <- renderUI({
    if ("Favori" %in% colnames(data$library)) {
      h2(textOutput(outputId = "nb_livres_aimes"), class = "text-stat")
    } else {
      h2("[Pas de données indiquant les livres préférés]", class = "text-stat-erreur")
    }
  })
  
  output$nb_livres_aimes <- renderText({
    
    data$nb_livres_aimes <- data$library %>%
      filter(.data$Favori=="Oui")
    
    paste0(format(nrow(data$nb_livres_aimes), big.mark = " ", scientific = FALSE), " (", round(nrow(data$nb_livres_aimes)/nrow(data$nb_livres_lus)*100,2), " %)")
  })
  
  
  output$nb_livres_a_soi_ui <- renderUI({
    if ("Bibliothèque" %in% colnames(data$library)) {
      h2(textOutput(outputId = "nb_livres_a_soi"), class = "text-stat")
    } else {
      h2("[Pas de données indiquant les livres possédés]", class = "text-stat-erreur")
    }
  })
  
  output$nb_livres_a_soi <- renderText({
    
    data$nb_livres_a_soi <- data$library %>%
      filter(.data$Bibliothèque=="Oui")
    
    paste0(format(nrow(data$nb_livres_a_soi), big.mark = " ", scientific = FALSE), " (", round(nrow(data$nb_livres_a_soi)/data$nb_livres*100,2), " %)")
  })
  
  
  output$nb_pages_ui <- renderUI({
    if ("Pages" %in% colnames(data$library)) {
      h2(textOutput(outputId = "nb_pages"), class = "text-stat")
    } else {
      h2("[Pas de données indiquant le nombre de pages]", class = "text-stat-erreur")
    }
  })
  
  output$nb_pages <- renderText({
    
    data$nb_pages <- data$library
    
    paste0(format(round(sum(na.omit(data$nb_pages$Pages)), 0), big.mark = " ", scientific = FALSE), ifelse(any(is.na(data$nb_pages$Pages)), " (incomplet)", ""))
  })
  
  
  output$nb_pages_lues_ui <- renderUI({
    if ("Pages" %in% colnames(data$library)) {
      h2(textOutput(outputId = "nb_pages_lues"), class = "text-stat")
    } else {
      h2("[Pas de données indiquant le nombre de pages]", class = "text-stat-erreur")
    }
  })
  
  output$nb_pages_lues <- renderText({
    
    data$nb_pages_lues <- data$library %>%
      filter(.data$Lu == "Oui")
    
    paste0(format(round(sum(na.omit(data$nb_pages_lues$Pages)),0), big.mark = " ", scientific=FALSE), " (", round(sum(na.omit(data$nb_pages_lues$Pages))/sum(na.omit(data$library$Pages))*100,2), " %)", ifelse(any(is.na(data$library$Pages)), " (incomplet)", ""))
  })
  
  
  output$prix_total_ui <- renderUI({
    if ("Prix" %in% colnames(data$library)) {
      h2(textOutput(outputId = "prix_total"), class = "text-stat")
    } else {
      h2("[Pas de données indiquant le prix]", class = "text-stat-erreur")
    }
  })
  
  output$prix_total <- renderText({
    
    paste0(format(sum(as.numeric(gsub(",", ".", data$library$Prix[!is.na(data$library$Prix)])), na.rm = TRUE), big.mark = " ", scientific = FALSE), " €", ifelse(any(is.na(data$library$Prix)), " (incomplet)", ""))
  })
  
  
  output$nb_auteurs_ui <- renderUI({
    if ("Auteur" %in% colnames(data$library)) {
      h2(textOutput(outputId = "nb_auteurs"), class = "text-stat")
    } else {
      h2("[Pas de données indiquant l'auteur]", class = "text-stat-erreur")
    }
  })
  
  output$nb_auteurs <- renderText({
    
    data$nb_auteurs = data$library$Auteur %>%
      unique() %>%
      length()
    
    paste0(format(data$nb_auteurs, big.mark = " ", scientific = FALSE), ifelse(any(is.na(data$library$Auteur)), " (incomplet)", ""))
  })
  
  
  output$nb_genres_ui <- renderUI({
    if ("Genre" %in% colnames(data$library)) {
      h2(textOutput(outputId = "nb_genres"), class = "text-stat")
    } else {
      h2("[Pas de données indiquant le genre]", class = "text-stat-erreur")
    }
  })
  
  output$nb_genres <- renderText({
    
    data$nb_genres = data$library$Genre %>%
      unique() %>%
      length()
    
    paste0(format(data$nb_genres, big.mark = " ", scientific = FALSE), ifelse(any(is.na(data$library$Genre)), " (incomplet)", ""))
  })
  
  
  output$nb_pays_origine_ui <- renderUI({
    if ("Origine" %in% colnames(data$library)) {
      h2(textOutput(outputId = "nb_pays_origine"), class = "text-stat")
    } else {
      h2("[Pas de données indiquant le pays d'origine]", class = "text-stat-erreur")
    }
  })
  
  output$nb_pays_origine <- renderText({
    
    data$nb_pays_origine = data$library$Origine %>%
      unique() %>%
      length()
    
    paste0(format(data$nb_pays_origine, big.mark = " ", scientific = FALSE), ifelse(any(is.na(data$library$Origine)), " (incomplet)", ""))
  })
  
  
  output$nb_langue_ecriture_ui <- renderUI({
    if ("Ecriture" %in% colnames(data$library)) {
      h2(textOutput(outputId = "nb_langue_ecriture"), class = "text-stat")
    } else {
      h2("[Pas de données indiquant la langue d'écriture]", class = "text-stat-erreur")
    }
  })
  
  output$nb_langue_ecriture <- renderText({
    
    data$nb_langue_ecriture = data$library$Ecriture %>%
      unique() %>%
      length()
    
    paste0(format(data$nb_langue_ecriture, big.mark = " ", scientific = FALSE), ifelse(any(is.na(data$library$Ecriture)), " (incomplet)", ""))
  })
  
  
  output$auteur_fav_ui <- renderUI({
    if ("Auteur" %in% colnames(data$library)) {
      h2(textOutput(outputId = "auteur_fav"), class = "text-stat")
    } else {
      h2("[Pas de données indiquant l'auteur]", class = "text-stat-erreur")
    }
  })
  
  output$auteur_fav <- renderText({
    
    data$auteur_fav = data$library %>%
      group_by(across(all_of("Auteur"))) %>%
      summarize(nb_auteur_fav=n())
    
    paste(data$auteur_fav$Auteur[which(data$auteur_fav$nb_auteur_fav == max(data$auteur_fav$nb_auteur_fav))], collapse = ", ")
  })
  
  
  output$genre_fav_ui <- renderUI({
    if ("Genre" %in% colnames(data$library)) {
      h2(textOutput(outputId = "genre_fav"), class = "text-stat")
    } else {
      h2("[Pas de données indiquant le genre]", class = "text-stat-erreur")
    }
  })
  
  output$genre_fav <- renderText({
    
    data$genre_fav = data$library %>%
      group_by(across(all_of("Genre"))) %>%
      summarize(nb_genre_fav=n())
    
    paste(data$genre_fav$Genre[which(data$genre_fav$nb_genre_fav == max(data$genre_fav$nb_genre_fav))], collapse = ", ")
  })
  
  
  output$pays_origine_fav_ui <- renderUI({
    if ("Origine" %in% colnames(data$library)) {
      h2(textOutput(outputId = "pays_origine_fav"), class = "text-stat")
    } else {
      h2("[Pas de données indiquant le pays d'origine]", class = "text-stat-erreur")
    }
  })
  
  output$pays_origine_fav <- renderText({
    
    data$pays_origine_fav = data$library %>%
      group_by(across(all_of("Origine"))) %>%
      summarize(nb_pays_origine_fav=n())
    
    paste(data$pays_origine_fav$Origine[which(data$pays_origine_fav$nb_pays_origine_fav == max(data$pays_origine_fav$nb_pays_origine_fav))], collapse = ", ")
  })
  
  
  output$langue_ecriture_fav_ui <- renderUI({
    if ("Ecriture" %in% colnames(data$library)) {
      h2(textOutput(outputId = "langue_ecriture_fav"), class = "text-stat")
    } else {
      h2("[Pas de données indiquant la langue d'écriture]", class = "text-stat-erreur")
    }
  })
  
  output$langue_ecriture_fav <- renderText({
    
    data$langue_ecriture_fav = data$library %>%
      group_by(across(all_of("Ecriture"))) %>%
      summarize(nb_langue_ecriture_fav=n())
      
    paste(data$langue_ecriture_fav$Ecriture[which(data$langue_ecriture_fav$nb_langue_ecriture_fav == max(data$langue_ecriture_fav$nb_langue_ecriture_fav))], collapse = ", ")
  })

  
# ------------------------------------------------------------------------------
#                                    Page 5
# ------------------------------------------------------------------------------
  
  output$ui_choix_auteur <- renderUI({
    if (auteur_default %in% data$library$Auteur) {
      selectInput(inputId = "choix_auteur", label = "Sélectionner un auteur", width = "100%", choices = unique(data$library$Auteur[order(sapply(strsplit(as.character(data$library$Auteur), " "), function(x) ifelse(length(x)>1, x[2], x[1])))]), selected = auteur_default)
    } else {
      selectInput(inputId = "choix_auteur", label = "Sélectionner un auteur", width = "100%", choices = unique(data$library$Auteur[order(sapply(strsplit(as.character(data$library$Auteur), " "), function(x) ifelse(length(x)>1, x[2], x[1])))]), selected = NULL)
    }
  })
  
  
  output$nb_livres_auteurs <- renderText({
    
    data$nb_livres_auteurs = nrow(filter(data$library, Auteur %in% input$choix_auteur))
    
    paste0(format(data$nb_livres_auteurs, big.mark = " ", scientific = FALSE), " (", round(data$nb_livres_auteurs/nrow(data$library)*100,2), " %)")
  })
  
  
  output$nb_livres_lus_auteurs <- renderText({
    
    data$nb_livres_lus_auteurs = nrow(filter(data$library, Auteur %in% input$choix_auteur, Lu == "Oui"))
    
    paste0(format(data$nb_livres_lus_auteurs, big.mark = " ", scientific = FALSE), " (", round(data$nb_livres_lus_auteurs/data$nb_livres_auteurs*100,2), " %)")
  })
  
  
  output$nb_pages_auteurs <- renderText({
    
    data$nb_pages_auteurs=sum(filter(data$library, Auteur %in% input$choix_auteur)$Pages)
    
    paste0(format(data$nb_pages_auteurs, big.mark = " ", scientific = FALSE), " (", round(data$nb_pages_auteurs/sum(data$library$Pages)*100,2), " %)")
  })
  
  
  output$nb_pages_lues_auteurs <- renderText({
    
    data$nb_pages_lues_auteurs=sum(filter(data$library, Auteur %in% input$choix_auteur, Lu == "Oui")$Pages)
    
    paste0(format(data$nb_pages_lues_auteurs, big.mark = " ", scientific = FALSE), " (", round(data$nb_pages_lues_auteurs/data$nb_pages_auteurs*100,2), " %)")
  })
  
  
  output$table_stat_auteurs <- renderDT({
    
    data$table_stat_auteurs = data$library %>%
      filter(Auteur %in% input$choix_auteur) %>%
      select("Titre", "Auteur", "Date") %>%
      arrange(Date)
      
    datatable(data$table_stat_auteurs, class = "table-auteur", options = list(scrollY = "350px", paging = FALSE, fixedHeader = TRUE, fixedColumns = list(leftColumns = 1), info = FALSE, ordering = FALSE, searching = FALSE, pageLenght = -1, columnDefs = list(list(targets = "_all", className = "dt-center")), lengthMenu = list(c(-1, 10,25,50,100), c("Tout", "10", "25", "50", "100"))), rownames = FALSE)
  })
  
  
  output$plot_livres_auteurs <- renderPlot({
    
    data$plot_livres_auteurs = mutate(inner_join(summarize(group_by(data$library, Auteur), nb_livres=n()), summarize(group_by(data$library, Auteur), nb_livres_lus=sum(na.omit(Lu)=="Oui")), by = "Auteur"), pourc=round(nb_livres_lus/nb_livres*100,2))
    
    ggplot(head(data$plot_livres_auteurs[order(data$plot_livres_auteurs$nb_livres_lus, decreasing = TRUE),],10), aes(x=reorder(Auteur, nb_livres_lus), y=pourc)) + 
      geom_bar(stat = "identity", color = bleu_light, fill = "blue") + 
      coord_flip() +
      labs(x = "") +
      theme_bw() + 
      theme(legend.position = "none", 
            plot.background = element_rect(fill = bleu_light), 
            panel.border = element_blank(), 
            panel.background = element_rect(fill = bleu_light), 
            panel.grid.major = element_blank(), 
            panel.grid.minor = element_blank(), 
            axis.title.x = element_blank(), 
            axis.text.x = element_blank(), 
            axis.ticks = element_blank(), 
            axis.text.y = element_text(color = "blue"), 
            axis.title.y = element_text(color = "blue")) +
      geom_text(label = paste0(format(head(data$plot_livres_auteurs[order(data$plot_livres_auteurs$nb_livres_lus, decreasing = TRUE),],10)$nb_livres_lus, big.mark=" ", digits = 1, scientific=FALSE), " (", head(data$plot_livres_auteurs[order(data$plot_livres_auteurs$nb_livres_lus, decreasing = TRUE),],10)$pourc, " %)"), check_overlap = TRUE, color = bleu_light, position = position_stack(vjust=0.5))
  })
  
  
  output$plot_pages_auteurs <- renderPlot({
    
    data$plot_pages_auteurs = mutate(inner_join(summarize(group_by(data$library, Auteur), nb_pages=sum(Pages)), summarize(group_by(data$library, Auteur), nb_pages_lues=sum(Pages[Lu=="Oui"], na.rm = TRUE)), by = "Auteur"), pourc=round(nb_pages_lues/nb_pages*100,2))
    
    ggplot(head(data$plot_pages_auteurs[order(data$plot_pages_auteurs$nb_pages_lues, decreasing = TRUE),],10), aes(x=reorder(Auteur, nb_pages_lues), y=pourc)) + 
      geom_bar(stat = "identity", fill = "blue", color = bleu_light) + 
      coord_flip() +
      labs(x = "") +
      theme_bw() + 
      theme(legend.position = "none", 
            plot.background = element_rect(fill = bleu_light), 
            panel.border = element_blank(), 
            panel.background = element_rect(fill = bleu_light), 
            panel.grid.major = element_blank(), 
            panel.grid.minor = element_blank(), 
            axis.title.x = element_blank(), 
            axis.text.x = element_blank(), 
            axis.ticks = element_blank(), 
            axis.text.y = element_text(color = "blue"), 
            axis.title.y = element_text(color = "blue")) +
      geom_text(label = paste0(format(head(data$plot_pages_auteurs[order(data$plot_pages_auteurs$nb_pages_lues, decreasing = TRUE),],10)$nb_pages_lues, big.mark=" ", digits = 1, scientific=FALSE), " (", head(data$plot_pages_auteurs[order(data$plot_pages_auteurs$nb_pages_lues, decreasing = TRUE),],10)$pourc, " %)"), check_overlap = TRUE, color = bleu_light, position = position_stack(vjust=0.5))
  })
  
  
# ------------------------------------------------------------------------------
#                                    Page 6
# ------------------------------------------------------------------------------
  
  output$ui_choix_genre <- renderUI({
    if (genre_default %in% data$library$Genre) {
      selectInput(inputId = "choix_genre", label = "Sélectionner un genre", width = "100%", choices = sort(unique(data$library$Genre)), selected = genre_default)
    } else {
      selectInput(inputId = "choix_genre", label = "Sélectionner un genre", width = "100%", choices = sort(unique(data$library$Genre)), selected = NULL)
    }
  })
  
  
  output$nb_livres_genres <- renderText({
    
    data$nb_livres_genres = nrow(filter(data$library, Genre %in% input$choix_genre))
    
    paste0(format(data$nb_livres_genres, big.mark = " ", scientific = FALSE), " (", round(data$nb_livres_genres/nrow(data$library)*100,2), " %)")
  })
  
  
  output$nb_livres_lus_genres <- renderText({
    
    data$nb_livres_lus_genres = nrow(filter(data$library, Genre %in% input$choix_genre, Lu == "Oui"))
    
    paste0(format(data$nb_livres_lus_genres, big.mark = " ", scientific = FALSE), " (", round(data$nb_livres_lus_genres/data$nb_livres_genres*100,2), " %)")
  })
  
  
  output$nb_pages_genres <- renderText({
    
    data$nb_pages_genres=sum(filter(data$library, Genre %in% input$choix_genre)$Pages)
    
    paste0(format(data$nb_pages_genres, big.mark = " ", scientific = FALSE), " (", round(data$nb_pages_genres/sum(data$library$Pages)*100,2), " %)")
  })
  
  
  output$nb_pages_lues_genres <- renderText({
    
    data$nb_pages_lues_genres=sum(filter(data$library, Genre %in% input$choix_genre, Lu == "Oui")$Pages)
    
    paste0(format(data$nb_pages_lues_genres, big.mark = " ", scientific = FALSE), " (", round(data$nb_pages_lues_genres/data$nb_pages_genres*100,2), " %)")
  })
  
  
  output$table_stat_genres <- renderDT({
    req(input$choix_genre)
    
    data$table_stat_genres = data$library %>%
      filter(Genre %in% input$choix_genre) %>%
      select("Titre", "Auteur", "Date") %>%
      arrange(Date)
    
    datatable(data$table_stat_genres, class = "table-genre", options = list(scrollY = "350px", paging = FALSE, info = FALSE, fixedHeader = TRUE, fixedColumns = list(leftColumns = 1), ordering = FALSE, searching = FALSE, columnDefs = list(list(targets = "_all", className = "dt-center")), pageLenght = -1, lengthMenu = list(c(-1, 10,25,50,100), c("Tout", "10", "25", "50", "100"))), rownames = FALSE)
  })
  
  
  output$plot_livres_genres <- renderPlot({
    
      data$plot_livres_genres = mutate(inner_join(summarize(group_by(data$library, Genre), nb_livres=n()), summarize(group_by(data$library, Genre), nb_lus=sum(na.omit(Lu)=="Oui")), by = "Genre"), pourc=round(nb_lus/nb_livres*100,2)) %>%
        rbind(bind_cols("Genre" = "Total", "nb_livres" = sum(mutate(inner_join(summarize(group_by(data$library, Genre), nb_livres = n()), summarize(group_by(data$library, Genre), nb_lus = sum(na.omit(Lu)=="Oui")), by = "Genre"), pourc = round(nb_lus/nb_livres*100,2))$nb_livres), "nb_lus" = sum(mutate(inner_join(summarize(group_by(data$library, Genre), nb_livres = n()), summarize(group_by(data$library, Genre), nb_lus = sum(na.omit(Lu)=="Oui")), by = "Genre"), pourc = round(nb_lus/nb_livres*100,2))$nb_lus), "pourc" = round(sum(mutate(inner_join(summarize(group_by(data$library, Genre), nb_livres = n()), summarize(group_by(data$library, Genre), nb_lus = sum(na.omit(Lu)=="Oui")), by = "Genre"), pourc = round(nb_lus/nb_livres*100,2))$nb_lus)/sum(mutate(inner_join(summarize(group_by(data$library, Genre), nb_livres = n()), summarize(group_by(data$library, Genre), nb_lus = sum(na.omit(Lu)=="Oui")), by = "Genre"), pourc = round(nb_lus/nb_livres*100,2))$nb_livres)*100, 2)))
      
      ggplot(data$plot_livres_genres, aes(x=factor(Genre, levels = c("Total", sort(unique(data$library$Genre), decreasing = TRUE))), y=pourc)) + 
        geom_bar(stat = "identity", fill = "blue", color = bleu_light) + 
        coord_flip() +
        labs(x = "") +
        theme_bw() +
        theme(legend.position = "none", 
              plot.background = element_rect(fill = bleu_light), 
              panel.border = element_blank(), 
              panel.background = element_rect(fill = bleu_light), 
              panel.grid.major = element_blank(), 
              panel.grid.minor = element_blank(), 
              axis.title.x = element_blank(), 
              axis.text.x = element_blank(), 
              axis.ticks = element_blank(), 
              axis.text.y = element_text(color = "blue"), 
              axis.title.y = element_text(color = "blue")) +
        geom_text(label = paste0(format(data$plot_livres_genres$nb_lus, big.mark=" ", digits = 1, scientific=FALSE), " (", data$plot_livres_genres$pourc, " %)"), check_overlap = TRUE, color = bleu_light, position = position_stack(vjust=0.5))
  })
  
  
  output$plot_pages_genres <- renderPlot({
    
    data$plot_pages_genres = mutate(inner_join(summarize(group_by(data$library, Genre), nb_pages=sum(Pages)), summarize(group_by(data$library, Genre), nb_pages_lues=sum(Pages[Lu=="Oui"], na.rm = TRUE)), by = "Genre"), pourc=round(nb_pages_lues/nb_pages*100,2)) %>%
      rbind(bind_cols("Genre" = "Total", "nb_pages" = sum(mutate(inner_join(summarize(group_by(data$library, Genre), nb_pages=sum(Pages)), summarize(group_by(data$library, Genre), nb_pages_lues=sum(Pages[Lu=="Oui"], na.rm = TRUE)), by = "Genre"), pourc=round(nb_pages_lues/nb_pages*100,2))$nb_pages), "nb_pages_lues" = sum(mutate(inner_join(summarize(group_by(data$library, Genre), nb_pages=sum(Pages)), summarize(group_by(data$library, Genre), nb_pages_lues=sum(Pages[Lu=="Oui"], na.rm = TRUE)), by = "Genre"), pourc=round(nb_pages_lues/nb_pages*100,2))$nb_pages_lues), "pourc" = round(sum(mutate(inner_join(summarize(group_by(data$library, Genre), nb_pages=sum(Pages)), summarize(group_by(data$library, Genre), nb_pages_lues=sum(Pages[Lu=="Oui"], na.rm = TRUE)), by = "Genre"), pourc=round(nb_pages_lues/nb_pages*100,2))$nb_pages_lues)/sum(mutate(inner_join(summarize(group_by(data$library, Genre), nb_pages=sum(Pages)), summarize(group_by(data$library, Genre), nb_pages_lues=sum(Pages[Lu=="Oui"], na.rm = TRUE)), by = "Genre"), pourc=round(nb_pages_lues/nb_pages*100,2))$nb_pages)*100,2)))
    
    ggplot(data$plot_pages_genres, aes(x=factor(Genre, levels = c("Total", sort(unique(data$library$Genre), decreasing = TRUE))), y=pourc)) + 
      geom_bar(stat = "identity", fill = "blue", color = bleu_light) + 
      coord_flip() +
      labs(x = "") +
      theme_bw() +
      theme(legend.position = "none", 
            plot.background = element_rect(fill = bleu_light), 
            panel.border = element_blank(), 
            panel.background = element_rect(fill = bleu_light), 
            panel.grid.major = element_blank(), 
            panel.grid.minor = element_blank(), 
            axis.title.x = element_blank(), 
            axis.text.x = element_blank(), 
            axis.ticks = element_blank(), 
            axis.text.y = element_text(color = "blue"), 
            axis.title.y = element_text(color = "blue")) +
      geom_text(label = paste0(format(data$plot_pages_genres$nb_pages_lues, digits = 1, big.mark=" ", scientific=FALSE), " (", data$plot_pages_genres$pourc, " %)"), check_overlap = TRUE, color = bleu_light, position = position_stack(vjust=0.5))
         
   })

  
# ------------------------------------------------------------------------------
#                                    Page 7
# ------------------------------------------------------------------------------
  
  output$ui_choix_pays <- renderUI({
    if (pays_default %in% data$library$Origine) {
      selectInput(inputId = "choix_pays", label = "Sélectionner un pays", width = "100%", choices = sort(unique(data$library$Origine)), selected = pays_default)
    } else {
      selectInput(inputId = "choix_pays", label = "Sélectionner un pays", width = "100%", choices = sort(unique(data$library$Origine)), selected = NULL)
    }
  })
  
  
  output$nb_livres_pays <- renderText({
    
    data$nb_livres_pays = nrow(filter(data$library, Origine %in% input$choix_pays))
    
    paste0(format(data$nb_livres_pays, big.mark = " ", scientific = FALSE), " (", round(data$nb_livres_pays/nrow(data$library)*100,2), " %)")
  })
  
  
  output$nb_livres_lus_pays <- renderText({
    
    data$nb_livres_lus_pays = nrow(filter(data$library, Origine %in% input$choix_pays, Lu == "Oui"))
    
    paste0(format(data$nb_livres_lus_pays, big.mark = " ", scientific = FALSE), " (", round(data$nb_livres_lus_pays/data$nb_livres_pays*100,2), " %)")
  })
  
  
  output$nb_pages_pays <- renderText({
    
    data$nb_pages_pays=sum(filter(data$library, Origine %in% input$choix_pays)$Pages)
    
    paste0(format(data$nb_pages_pays, big.mark = " ", scientific = FALSE), " (", round(data$nb_pages_pays/sum(data$library$Pages)*100,2), " %)")
  })
  
  
  output$nb_pages_lues_pays <- renderText({
    
    data$nb_pages_lues_pays=sum(filter(data$library, Origine %in% input$choix_pays, Lu == "Oui")$Pages)
    
    paste0(format(data$nb_pages_lues_pays, big.mark = " ", scientific = FALSE), " (", round(data$nb_pages_lues_pays/data$nb_pages_pays*100,2), " %)")
  })
  
  
  output$table_stat_pays <- renderDT({
    req(input$choix_pays)
    
    data$table_stat_pays = data$library %>%
      filter(Origine %in% input$choix_pays) %>%
      select("Titre", "Auteur", "Date") %>%
      arrange(Date)
    
    datatable(data$table_stat_pays, class = "table-pays", options = list(scrollY = "350px", paging = FALSE, info = FALSE, ordering = FALSE, fixedHeader = TRUE, fixedColumns = list(leftColumns = 1), searching = FALSE, pageLenght = -1, columnDefs = list(list(targets = "_all", className = "dt-center")), lengthMenu = list(c(-1, 10,25,50,100), c("Tout", "10", "25", "50", "100"))), rownames = FALSE)
  })
  
  
  output$plot_livres_pays <- renderPlot({
    
    data$plot_livres_pays = mutate(inner_join(summarize(group_by(data$library, Origine), nb_livres=n()), summarize(group_by(data$library, Origine), nb_livres_lus=sum(na.omit(Lu)=="Oui")), by = "Origine"), pourc=round(nb_livres_lus/nb_livres*100,2))
    
    ggplot(head(data$plot_livres_pays[order(data$plot_livres_pays$nb_livres_lus, decreasing = TRUE),],10), aes(x=reorder(Origine, nb_livres_lus), y=pourc)) + 
      geom_bar(stat = "identity", fill = "blue", color = bleu_light) +
      coord_flip() +
      labs(x = "") +
      theme_bw() +
      theme(legend.position = "none", 
            plot.background = element_rect(fill = bleu_light), 
            panel.border = element_blank(), 
            panel.background = element_rect(fill = bleu_light), 
            panel.grid.major = element_blank(), 
            panel.grid.minor = element_blank(), 
            axis.title.x = element_blank(), 
            axis.text.x = element_blank(), 
            axis.ticks = element_blank(), 
            axis.text.y = element_text(color = "blue"), 
            axis.title.y = element_text(color = "blue")) +
      geom_text(label = paste0(format(head(data$plot_livres_pays[order(data$plot_livres_pays$nb_livres_lus, decreasing = TRUE),],10)$nb_livres_lus, big.mark=" ", digits = 1, scientific=FALSE), " (", head(data$plot_livres_pays[order(data$plot_livres_pays$nb_livres_lus, decreasing = TRUE),],10)$pourc, " %)"), check_overlap = TRUE, color = bleu_light, position = position_stack(vjust=0.5))
         
 })
  
  
  output$plot_pages_pays <- renderPlot({
    
    data$plot_pages_pays = mutate(inner_join(summarize(group_by(data$library, Origine), nb_pages=sum(Pages)), summarize(group_by(data$library, Origine), nb_pages_lues=sum(Pages[Lu=="Oui"], na.rm = TRUE)), by = "Origine"), pourc=round(nb_pages_lues/nb_pages*100,2))
    
    ggplot(head(data$plot_pages_pays[order(data$plot_pages_pays$nb_pages_lues, decreasing = TRUE),],10), aes(x=reorder(Origine, nb_pages_lues), y=pourc)) + 
      geom_bar(stat = "identity", fill = "blue", color = bleu_light) +
      coord_flip() +
      labs(x = "") +
      theme_bw() +
      theme(legend.position = "none", 
            plot.background = element_rect(fill = bleu_light), 
            panel.border = element_blank(), 
            panel.background = element_rect(fill = bleu_light), 
            panel.grid.major = element_blank(), 
            panel.grid.minor = element_blank(), 
            axis.title.x = element_blank(), 
            axis.text.x = element_blank(), 
            axis.ticks = element_blank(), 
            axis.text.y = element_text(color = "blue"), 
            axis.title.y = element_text(color = "blue")) +
      geom_text(label = paste0(format(head(data$plot_pages_pays[order(data$plot_pages_pays$nb_pages_lues, decreasing = TRUE),],10)$nb_pages_lues, big.mark=" ", digits = 1, scientific=FALSE), " (", head(data$plot_pages_pays[order(data$plot_pages_pays$nb_pages_lues, decreasing = TRUE),],10)$pourc, " %)"), check_overlap = TRUE, color = bleu_light, position = position_stack(vjust=0.5))
  })
  
  
# ------------------------------------------------------------------------------
#                                    Page 8
# ------------------------------------------------------------------------------
  
  output$ui_choix_siecle <- renderUI({
    data$library_siecle = data$library %>%
      mutate(Siècle = case_when(Date>0 ~ paste0(as.roman((Date-1)%/%100+1), "e"), Date<0 ~ paste0(as.roman(substring(Date-100, 2, str_length(Date-100)-2)), "e BC")))
    
    selectInput(inputId = "choix_siecle", label = "Sélectionner un siècle", choices = sort(unique(data$library_siecle$Siècle)), selected = ifelse(siecle_default %in% data$library_siecle$Siècle, siecle_default, NULL), width = "100%")
  })
  
  
  output$nb_livres_siecle <- renderText({
    
    data$nb_livres_siecle = nrow(filter(data$library_siecle, Siècle %in% input$choix_siecle))
    
    paste0(format(data$nb_livres_siecle, big.mark = " ", scientific = FALSE), " (", round(data$nb_livres_siecle/nrow(data$library)*100,2), " %)")
  })
  
  
  output$nb_livres_lus_siecle <- renderText({
    
    data$nb_livres_lus_siecle = nrow(filter(data$library_siecle, Siècle %in% input$choix_siecle, Lu == "Oui"))
    
    paste0(format(data$nb_livres_lus_siecle, big.mark = " ", scientific = FALSE), " (", round(data$nb_livres_lus_siecle/data$nb_livres_siecle*100,2), " %)")
  })
  
  
  output$nb_pages_siecle <- renderText({
    
    data$nb_pages_siecle=sum(filter(data$library_siecle, Siècle %in% input$choix_siecle)$Pages)
    
    paste0(format(data$nb_pages_siecle, big.mark = " ", scientific = FALSE), " (", round(data$nb_pages_siecle/sum(data$library$Pages)*100,2), " %)")
  })
  
  
  output$nb_pages_lues_siecle <- renderText({
    
    data$nb_pages_lues_siecle=sum(filter(data$library_siecle, Siècle %in% input$choix_siecle, Lu == "Oui")$Pages)
    
    paste0(format(data$nb_pages_lues_siecle, big.mark = " ", scientific = FALSE), " (", round(data$nb_pages_lues_siecle/data$nb_pages_siecle*100,2), " %)")
  })
  
  
  output$table_stat_siecle <- renderDT({
    req(input$choix_siecle)
    
    data$table_stat_siecle = data$library_siecle %>%
      filter(Siècle %in% input$choix_siecle) %>%
      select("Titre", "Auteur", "Date") %>%
      arrange(Date)
    
    datatable(data$table_stat_siecle, class = "table-siecle", options = list(scrollX = TRUE, scrollY = "350px", paging = FALSE, fixedHeader = TRUE, fixedColumns = list(leftColumns = 1), ordering = FALSE, info = FALSE, searching = FALSE, pageLenght = -1, columnDefs = list(list(targets = "_all", className = "dt-center")), lengthMenu = list(c(-1, 10,25,50,100), c("Tout", "10", "25", "50", "100"))), rownames = FALSE)
  })
  
  
  output$plot_livres_siecles <- renderPlot({
    
    data$plot_livres_siecles = mutate(inner_join(summarize(group_by(data$library_siecle, Siècle), nb_livres=n()), summarize(group_by(data$library_siecle, Siècle), nb_livres_lus=sum(na.omit(Lu)=="Oui")), by = "Siècle"), pourc=round(nb_livres_lus/nb_livres*100,2))
    
    ggplot(head(data$plot_livres_siecles[order(data$plot_livres_siecles$nb_livres_lus, decreasing = TRUE),],10), aes(x=reorder(Siècle, nb_livres_lus), y=pourc)) + 
      geom_bar(stat = "identity", fill = "blue", color = bleu_light) +
      coord_flip() +
      labs(x = "") +
      theme_bw() +
      theme(legend.position = "none", 
            plot.background = element_rect(fill = bleu_light), 
            panel.border = element_blank(), 
            panel.background = element_rect(fill = bleu_light), 
            panel.grid.major = element_blank(), 
            panel.grid.minor = element_blank(), 
            axis.title.x = element_blank(), 
            axis.text.x = element_blank(), 
            axis.ticks = element_blank(), 
            axis.text.y = element_text(color = "blue"), 
            axis.title.y = element_text(color = "blue")) +
      geom_text(label = paste0(format(head(data$plot_livres_siecles[order(data$plot_livres_siecles$nb_livres_lus, decreasing = TRUE),],10)$nb_livres_lus, big.mark=" ", digits = 1, scientific=FALSE), " (", head(data$plot_livres_siecles[order(data$plot_livres_siecles$nb_livres_lus, decreasing = TRUE),],10)$pourc, " %)"), check_overlap = TRUE, color = bleu_light, position = position_stack(vjust=0.5))
          
  })
  
  
  output$plot_pages_siecles <- renderPlot({
    
    data$plot_pages_siecles = mutate(inner_join(summarize(group_by(data$library_siecle, Siècle), nb_pages=sum(Pages)), summarize(group_by(data$library_siecle, Siècle), nb_pages_lues=sum(Pages[Lu=="Oui"], na.rm = TRUE)), by = "Siècle"), pourc=round(nb_pages_lues/nb_pages*100,2))
    
    ggplot(head(data$plot_pages_siecles[order(data$plot_pages_siecles$nb_pages_lues, decreasing = TRUE),],10), aes(x=reorder(Siècle, nb_pages_lues), y=pourc)) + 
      geom_bar(stat = "identity", fill = "blue", color = bleu_light) +
      coord_flip() +
      labs(x = "") +
      theme_bw() +
      theme(legend.position = "none", 
            plot.background = element_rect(fill = bleu_light), 
            panel.border = element_blank(), 
            panel.background = element_rect(fill = bleu_light), 
            panel.grid.major = element_blank(), 
            panel.grid.minor = element_blank(), 
            axis.title.x = element_blank(), 
            axis.text.x = element_blank(), 
            axis.ticks = element_blank(), 
            axis.text.y = element_text(color = "blue"), 
            axis.title.y = element_text(color = "blue")) +
      geom_text(label = paste0(format(head(data$plot_pages_siecles[order(data$plot_pages_siecles$nb_pages_lues, decreasing = TRUE),],10)$nb_pages_lues, big.mark=" ", digits = 1, scientific=FALSE), " (", head(data$plot_pages_siecles[order(data$plot_pages_siecles$nb_pages_lues, decreasing = TRUE),],10)$pourc, " %)"), check_overlap = TRUE, color = bleu_light, position = position_stack(vjust=0.5))
         
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
  
  
# ------------------------------------------------------------------------------
#                                   Page 9.1
# ------------------------------------------------------------------------------
  
  output$output_verif_livre_bibliotheque <- renderText({
    
    if(str_length(input$input_verif_livre_bibliotheque)==17) {
      if(input$input_verif_livre_bibliotheque %in% data$library$ISBN) {
        paste0("Le livre ", data$library$Titre[data$library$ISBN==input$input_verif_livre_bibliotheque],
               " de ", data$library$Auteur[data$library$ISBN==input$input_verif_livre_bibliotheque],
               " (", data$library$Date[data$library$ISBN==input$input_verif_livre_bibliotheque], ")",
               " est déjà dans la bibliothèque.")
      } else if(input$input_verif_livre_bibliotheque %in% data$livres$ISBN) {
        paste0("Le livre ", data$livres$Titre[data$livres$ISBN==input$input_verif_livre_bibliotheque],
               " de ", data$livres$Auteur[data$livres$ISBN==input$input_verif_livre_bibliotheque], 
               " (",  data$livres$Date[data$livres$ISBN==input$input_verif_livre_bibliotheque], ")",
               " est déjà dans la base de données. Ne remplissez que les informations suivantes :")
      } else {
        paste0("Le livre n'est pas dans la base de données. Merci de remplir les informations suivantes :")
      }
    }
  })
  
  output$ajout_bibliotheque <- renderUI ({
    
    if(str_length(input$input_verif_livre_bibliotheque)!=17) {
      NULL
    } else if(input$input_verif_livre_bibliotheque %in% data$library$ISBN) {
      NULL
    } else if(input$input_verif_livre_bibliotheque %in% data$livres$ISBN) {
      box(
        title = "Ajouter un livre",
        status = "primary", 
        solidHeader = TRUE,
        width = 12,
        column(3, selectInput(inputId = "ajout_lu_isbn", label = "L'avez-vous lu ?", choices = c("Oui", "Non", "En train de lire"), selected = "Non")),
        column(3, selectInput(inputId = "ajout_favori_isbn", label = "L'avez-vous aimé ?", choices = c("Oui", "Non", "Pas lu"), selected = "Pas lu")),
        column(3, selectInput(inputId = "ajout_bibliotheque_isbn", label = "Est-ce votre livre ?", choices = c("Oui", "Non"), selected = "Oui")),
        column(3, selectInput(inputId = "ajout_rachat_isbn", label = "Devez-vous le racheter ?", choices = c("Oui", "Non"), selected = "Non")),
        column(6, uiOutput(outputId = "ajout_date_debut_isbn_ui")),
        column(6, uiOutput(outputId = "ajout_date_fin_isbn_ui")),
        fluidRow(style = "text-align: center;",
          column(12,
            actionButton(inputId = "ajout_bouton_isbn", label = "Ajouter le livre", icon = icon("plus"), class = "bouton")
          )
        )
      )
    } else {
      box(
        title = "Ajouter un livre",
        status = "primary",
        solidHeader = TRUE,
        width = 12,
        column(6, textInput(inputId = "ajout_titre", label = "Titre", placeholder = "Titre...")),
        column(4, selectizeInput(inputId = "ajout_auteur", label = "Auteur", choices = c("", sort(unique(data$livres$Auteur))), selected = "", options = list(create = TRUE, placeholder = "Prénom et nom de l'auteur..."))),
        column(2, numericInput(inputId = "ajout_date", label = "Date d'écriture", value = format(Sys.Date(), "%Y"), step = 1)),
        column(2, selectizeInput(inputId = "ajout_genre", label = "Genre", choices = c("", sort(unique(data$livres$Genre))), selected = "", options = list(create = TRUE, placeholder = "Genre..."))),
        column(3, selectizeInput(inputId = "ajout_pays_origine", label = "Pays d'origine", choices = c("", sort(unique(data$livres$Origine))), selected = "", options = list(create = TRUE, placeholder = "Pays d'origine..."))),
        column(3, selectizeInput(inputId = "ajout_langue_ecriture", label = "Langue d'écriture", choices = c("", sort(unique(data$livres$Ecriture))), selected = "", options = list(create = TRUE, placeholder = "Langue d'écriture..."))),
        column(2, numericInput(inputId = "ajout_nb_pages_hist", label = "Nombre de pages", value = NULL, step = 1)),
        column(2, numericInput(inputId = "ajout_nb_pages_livre", label = "Nombre de pages du livre", value = NULL, step = 1)),
        column(4, selectizeInput(inputId = "ajout_edition", label = "Edition", choices = c("", sort(unique(data$livres$Edition))), selected = "", options = list(create = TRUE, placeholder = "Edition..."))),
        column(2, numericInput(inputId = "ajout_num_edition", label = "Numéro d'édition", value = NULL)),
        column(4, selectizeInput(inputId = "ajout_collection", label = "Collection", choices = c("", sort(unique(data$livres$Collection))), selected = "", options = list(create = TRUE, placeholder = "Collection..."))),
        column(2, textInput(inputId = "ajout_isbn", label = "ISBN", value = input$input_verif_livre_bibliotheque)),
        column(4, selectizeInput(inputId = "ajout_prefacier", label = "Préfacier", choices = c("", sort(unique(data$livres$Préfacier))), selected = "", options = list(create = TRUE, placeholder = "Préfacier..."))),
        column(4, selectizeInput(inputId = "ajout_traducteur", label = "Traducteur", choices = c("", sort(unique(data$livres$Traducteur))), selected = "", options = list(create = TRUE, placeholder = "Traducteur..."))),
        column(4, numericInput(inputId = "ajout_prix", label = "Prix", step = 0.01, value = NULL)),
        column(3, selectInput(inputId = "ajout_lu", label = "L'avez-vous lu ?", choices = c("Oui", "Non", "En train de lire"), selected = "Non")),
        column(3, selectInput(inputId = "ajout_favori", label = "L'avez-vous aimé ?", choices = c("Oui", "Non", "Pas lu"), selected = "Pas lu")),
        column(3, selectInput(inputId = "ajout_bibliotheque", label = "Est-ce votre livre ?", choices = c("Oui", "Non"), selected = "Oui")),
        column(3, selectInput(inputId = "ajout_rachat", label = "Devez-vous le racheter ?", choices = c("Oui", "Non"), selected = "Non")),
        column(6, uiOutput(outputId = "ajout_date_debut_ui")),
        column(6, uiOutput(outputId = "ajout_date_fin_ui")),
        fluidRow(style = "text-align: center;",
          column(12,
            actionButton(inputId = "ajout_bouton", label = "Ajouter le livre", icon = icon("plus"), class = "bouton")
          )
        )
      )
    }
    
  })
  
  output$ajout_date_debut_isbn_ui <- renderUI({
    if (input$ajout_lu_isbn %in% c("Oui", "En train de lire")) {
      dateInput(inputId = "ajout_date_debut_isbn", label = "Date de début de lecture", max = Sys.Date(), format = "dd/mm/yyyy", language = "fr", weekstart = 1)
    } else {
      NULL
    }
  })
  
  output$ajout_date_fin_isbn_ui <- renderUI({
    if (input$ajout_lu_isbn %in% c("Oui")) {
      dateInput(inputId = "ajout_date_fin_isbn", label = "Date de fin de lecture", max = Sys.Date(), format = "dd/mm/yyyy", language = "fr", weekstart = 1)
    } else {
      NULL
    }
  })
  
  output$ajout_date_debut_ui <- renderUI({
    if (input$ajout_lu %in% c("Oui", "En train de lire")) {
      dateInput(inputId = "ajout_date_debut", label = "Date de début de lecture", max = Sys.Date(), format = "dd/mm/yyyy", language = "fr", weekstart = 1)
    } else {
      NULL
    }
  })
  
  output$ajout_date_fin_ui <- renderUI({
    if (input$ajout_lu %in% c("Oui")) {
      dateInput(inputId = "ajout_date_fin", label = "Date de fin de lecture", max = Sys.Date(), format = "dd/mm/yyyy", language = "fr", weekstart = 1)
    } else {
      NULL
    }
  })
  
  
  observeEvent(input$ajout_bouton_isbn, {
    data$new_book = data.frame(data$livres$Titre[data$livres$ISBN==input$input_verif_livre_bibliotheque],
                          data$livres$Auteur[data$livres$ISBN==input$input_verif_livre_bibliotheque],
                          data$livres$Date[data$livres$ISBN==input$input_verif_livre_bibliotheque],
                          data$livres$Genre[data$livres$ISBN==input$input_verif_livre_bibliotheque],
                          data$livres$Origine[data$livres$ISBN==input$input_verif_livre_bibliotheque],
                          data$livres$Longueur[data$livres$ISBN==input$input_verif_livre_bibliotheque],
                          data$livres$Pages[data$livres$ISBN==input$input_verif_livre_bibliotheque],
                          data$livres$Edition[data$livres$ISBN==input$input_verif_livre_bibliotheque],
                          data$livres$Numéro[data$livres$ISBN==input$input_verif_livre_bibliotheque],
                          data$livres$Collection[data$livres$ISBN==input$input_verif_livre_bibliotheque],
                          input$input_verif_livre_bibliotheque,
                          data$livres$Ecriture[data$livres$ISBN==input$input_verif_livre_bibliotheque],
                          data$livres$Préfacier[data$livres$ISBN==input$input_verif_livre_bibliotheque],
                          data$livres$Traducteur[data$livres$ISBN==input$input_verif_livre_bibliotheque],
                          data$livres$Prix[data$livres$ISBN==input$input_verif_livre_bibliotheque],
                          ifelse(input$ajout_lu_isbn %in% c("Oui", "En train de lire"),  as.character(format(input$ajout_date_debut_isbn, "%d-%m-%Y")), NA),
                          ifelse(input$ajout_lu_isbn %in% c("Oui"), as.character(format(input$ajout_date_fin_isbn, "%d-%m-%Y")), NA),
                          input$ajout_lu_isbn, input$ajout_favori_isbn, input$ajout_bibliotheque_isbn,
                          input$ajout_rachat_isbn, stringsAsFactors = FALSE)
    colnames(data$new_book) = colnames(data$library)
    wb_library = createWorkbook()
    addWorksheet(wb_library, "library")
    writeData(wb_library, "library", arrange(rbind(data$library, data$new_book), Titre, Auteur), colNames = TRUE)
    saveWorkbook(wb_library, link_to_library(), overwrite = TRUE)
    data$library = arrange(rbind(data$library, data$new_book), Titre, Auteur, Date)
    
    showModal(modalDialog(
      title = HTML("<b>Confirmation</b>"),
      HTML(paste0("Le livre ", data$livres$Titre[data$livres$ISBN==input$input_verif_livre_bibliotheque], " a bien été ajouté à la bibliothèque")),
      footer = tagList(
        modalButton("Fermer", icon = icon("close"))
      ),
      easyClose = TRUE
    ))
  })
  
  observeEvent(input$ajout_bouton, {
    data$new_book = data.frame(input$ajout_titre, input$ajout_auteur, input$ajout_date, 
                          input$ajout_genre, input$ajout_pays_origine, input$ajout_nb_pages_hist, 
                          input$ajout_nb_pages_livre, input$ajout_edition, input$ajout_num_edition, 
                          input$ajout_collection, input$ajout_isbn, input$ajout_langue_ecriture, 
                          input$ajout_prefacier, input$ajout_traducteur, 
                          input$ajout_prix, 
                          ifelse(input$ajout_lu %in% c("Oui", "En train de lire"), as.character(format(input$ajout_date_debut, "%d-%m-%Y")), NA),
                          ifelse(input$ajout_lu %in% c("Oui"), as.character(format(input$ajout_date_fin, "%d-%m-%Y")), NA), 
                          input$ajout_lu, input$ajout_favori, input$ajout_bibliotheque,
                          input$ajout_rachat)
    colnames(data$new_book) = colnames(data$library)
    
    wb_library = createWorkbook()
    addWorksheet(wb_library, "library")
    writeData(wb_library, "library", arrange(rbind(data$library, data$new_book), Titre, Auteur), colNames = TRUE)
    saveWorkbook(wb_library, link_to_library(), overwrite = TRUE)
    data$library = arrange(rbind(data$library, data$new_book), Titre, Auteur, Date)
    
    wb_livres = createWorkbook()
    addWorksheet(wb_livres, "library")
    writeData(wb_livres, "library", arrange(rbind(data$livres, data$new_book[,c(1:15)]), Titre, Auteur), colNames = TRUE)
    saveWorkbook(wb_livres, link_to_livres, overwrite = TRUE)
    data$livres = arrange(rbind(data$livres, data$new_book[,c(1:15)]), Titre, Auteur, Date)
    
    showModal(modalDialog(
      title = HTML("<b>Confirmation</b>"),
      HTML(paste0("Le livre ", input$ajout_titre, " a bien été ajouté à la bibliothèque.")),
      footer = tagList(
        modalButton("Fermer", icon = icon("close"))
      ),
      easyClose = TRUE
    ))
  })

    
# ------------------------------------------------------------------------------
#                                   Page 9.2
# ------------------------------------------------------------------------------
  
  output$choix_isbn_modif <- renderUI({
    box(
      title = "Rechercher le livre",
      status = "primary", 
      solidHeader = TRUE,
      width = 12,
      column(6, selectizeInput(inputId = "modif_livre_titre", label = "Choisir un livre", choices = setNames(arrange(mutate(data$library, choix = paste(Titre, Auteur, sep = " - ")), choix)$ISBN, arrange(mutate(data$library, choix = paste(Titre, Auteur, sep = " - ")), choix)$choix), selected = "", options = list(placeholder = "Livre...")))
    )
  })
  
  
  output$modif_info_livre <- renderUI({
    box(
      title = "Modifier les informations",
      status = "primary",
      solidHeader = TRUE,
      width = 12,
      column(6, textInput(inputId = "modif_titre", label = "Titre", value = data$library$Titre[which(data$library$ISBN==input$modif_livre_titre)])),
      column(4, selectizeInput(inputId = "modif_auteur", label = "Auteur", choices = c("", sort(unique(data$livres$Auteur))), selected = data$library$Auteur[which(data$library$ISBN==input$modif_livre_titre)], options = list(create = TRUE))),
      column(2, numericInput(inputId = "modif_date", label = "Date d'écriture", value = data$library$Date[which(data$library$ISBN==input$modif_livre_titre)], step = 1)),
      column(2, selectizeInput(inputId = "modif_genre", label = "Genre", choices = c("", sort(unique(data$livres$Genre))), selected = data$library$Genre[which(data$library$ISBN==input$modif_livre_titre)], options = list(create = TRUE))),
      column(3, selectizeInput(inputId = "modif_pays_origine", label = "Pays d'origine", choices = c("", sort(unique(data$livres$Origine))), selected = data$library$Origine[which(data$library$ISBN==input$modif_livre_titre)], options = list(create = TRUE))),
      column(3, selectizeInput(inputId = "modif_langue_ecriture", label = "Langue d'écriture", choices = c("", sort(unique(data$livres$Ecriture))), selected = data$library$Ecriture[which(data$library$ISBN==input$modif_livre_titre)], options = list(create = TRUE))),
      column(2, numericInput(inputId = "modif_nb_pages_hist", label = "Nombre de pages", value = data$library$Longueur[which(data$library$ISBN==input$modif_livre_titre)], step = 1)),
      column(2, numericInput(inputId = "modif_nb_pages_livre", label = "Nombre de pages du livre", value = data$library$Pages[which(data$library$ISBN==input$modif_livre_titre)], step = 1)),
      column(4, selectizeInput(inputId = "modif_edition", label = "Edition", choices = c("", sort(unique(data$livres$Edition))), selected = data$library$Edition[which(data$library$ISBN==input$modif_livre_titre)], options = list(create = TRUE))),
      column(2, numericInput(inputId = "modif_num_edition", label = "Numéro d'édition", value = data$library$Numéro[which(data$library$ISBN==input$modif_livre_titre)])),
      column(4, selectizeInput(inputId = "modif_collection", label = "Collection", choices = c("", sort(unique(data$livres$Collection))), selected = data$library$Collection[which(data$library$ISBN==input$modif_livre_titre)], options = list(create = TRUE))),
      column(2, textInput(inputId = "modif_isbn", label = "ISBN", value = input$modif_livre_titre)),
      column(4, selectizeInput(inputId = "modif_prefacier", label = "Préfacier", choices = c("", sort(unique(data$livres$Préfacier))), selected = data$library$Préfacier[which(data$library$ISBN==input$modif_livre_titre)], options = list(create = TRUE))),
      column(4, selectizeInput(inputId = "modif_traducteur", label = "Traducteur", choices = c("", sort(unique(data$livres$Traducteur))), selected = data$library$Traducteur[which(data$library$ISBN==input$modif_livre_titre)], options = list(create = TRUE))),
      column(4, numericInput(inputId = "modif_prix", label = "Prix", step = 0.01, value = data$library$Prix[which(data$library$ISBN==input$modif_livre_titre)])),
      column(3, selectInput(inputId = "modif_lu", label = "L'avez-vous lu ?", choices = c("Oui", "Non", "En train de lire"), selected = data$library$Lu[which(data$library$ISBN==input$modif_livre_titre)])),
      column(3, selectInput(inputId = "modif_favori", label = "L'avez-vous aimé ?", choices = c("Oui", "Non", "Pas lu"), selected = data$library$Favori[which(data$library$ISBN==input$modif_livre_titre)])),
      column(3, selectInput(inputId = "modif_bibliotheque", label = "Est-ce votre livre ?", choices = c("Oui", "Non"), selected = data$library$Bibliothèque[which(data$library$ISBN==input$modif_livre_titre)])),
      column(3, selectInput(inputId = "modif_rachat", label = "Devez-vous le racheter ?", choices = c("Oui", "Non"), selected = data$library$Rachat[which(data$library$ISBN==input$modif_livre_titre)])),
      column(6, uiOutput(outputId = "modif_date_debut_ui")),
      column(6, uiOutput(outputId = "modif_date_fin_ui")),
      fluidRow(style = "text-align: center;",
        column(12,
          actionButton(inputId = "modif_bouton", label = "Enregistrer les changements", icon = icon("plus"), class = "bouton")
        )
      )
    )
  })
  
  
  output$modif_date_debut_ui <- renderUI ({
    if (input$modif_lu %in% c("Oui", "En train de lire")) {
      dateInput(inputId = "modif_date_debut", label = "Date de début de lecture", max = Sys.Date(), value = dmy(data$library$Commencé[which(data$library$ISBN==input$modif_livre_titre)]), format = "dd-mm-yyyy", language = "fr", weekstart = 1)
    } else {
      NULL
    }
  })
  
  
  output$modif_date_fin_ui <- renderUI ({
    if (input$modif_lu %in% c("Oui")) {
      dateInput(inputId = "modif_date_fin", label = "Date de fin de lecture", max = Sys.Date(), value = dmy(data$library$Fini[which(data$library$ISBN==input$modif_livre_titre)]), format = "dd-mm-yyyy", language = "fr", weekstart = 1)
    } else {
      NULL
    }
  })
  
  
  observeEvent(input$modif_bouton, {
    data$modif_book = data.frame(input$modif_titre, input$modif_auteur, input$modif_date, 
                            input$modif_genre, input$modif_pays_origine, input$modif_nb_pages_hist, 
                            input$modif_nb_pages_livre, input$modif_edition, input$modif_num_edition, 
                            input$modif_collection, input$modif_isbn, input$modif_langue_ecriture, 
                            input$modif_prefacier, input$modif_traducteur, 
                            input$modif_prix, 
                            ifelse(input$modif_lu %in% c("Oui", "En train de lire"), as.character(format(input$modif_date_debut, "%d-%m-%Y")), NA),
                            ifelse(input$modif_lu %in% c("Oui"), as.character(format(input$modif_date_fin, "%d-%m-%Y")), NA),
                            input$modif_lu, input$modif_favori, input$modif_bibliotheque,
                            input$modif_rachat)
    data$modif_library = data$library[-which(data$library$ISBN==input$modif_livre_titre),]
    colnames(data$modif_book) = colnames(data$library)
    colnames(data$modif_library) = colnames(data$library)
    wb_modif_library = createWorkbook()
    addWorksheet(wb_modif_library, "library")
    writeData(wb_modif_library, "library", arrange(rbind(data$modif_library, data$modif_book), Titre, Auteur, Date), colNames = TRUE)
    saveWorkbook(wb_modif_library, link_to_library(), overwrite = TRUE)
    data$library = arrange(rbind(data$modif_library, data$modif_book), Titre, Auteur, Date)
    
    showModal(modalDialog(
      title = HTML("<b>Confirmation</b>"),
      HTML(paste0("Les informations du livre ont bien été modifiées.")),
      footer = tagList(
        modalButton("Fermer", icon = icon("close"))
      ),
      easyClose = TRUE
    ))
  })
  
  
# ------------------------------------------------------------------------------
#                                Page 10 - Invité
# ------------------------------------------------------------------------------
  
  output$create_user_deja_pris <- renderText ({
    
    if (input$create_user %in% credentials$user) {
      paste0("Le nom ", input$create_user, " est déjà pris, veuillez choisir un autre nom d'utilisateur.")
    } else if (input$create_user != "") {
      paste0("Le nom ", input$create_user, " est disponible.")
    } else {
      NULL
    }
    
  })
  
  
  output$confirm_password_wrong <- renderText ({
    
    if (input$confirm_password != "") {
      if (input$confirm_password != input$create_password) {
        paste0("Les mots de passe ne correspondent pas.")
      }
    }
  })
  
  
  output$button_create_library_ui <- renderUI({
    if (input$create_user != "") {
      if (input$create_password != "") {
        if (input$create_library_name != "") {
          if (! input$create_user %in% credentials$user) {
            if (input$confirm_password == input$create_password) {
              fluidRow(style = "text-align: center;",
                actionButton(inputId = "button_create_library", label = "Créer ma bibliothèque", class = "bouton")
              )
            }
          }
        }
      }
    }
  })
  
  
  observeEvent(input$button_create_library, {
    
    data$create_new_user = data.frame(input$create_user, input$create_password, paste0(input$create_library_name, "_", input$create_user, ".xlsx"))
    colnames(data$create_new_user) = colnames(credentials)
    wb_create_library = createWorkbook()
    addWorksheet(wb_create_library, "credentials")
    writeData(wb_create_library, "credentials", rbind(credentials, data$create_new_user), colNames = TRUE)
    saveWorkbook(wb_create_library, config$link$link_to_credentials, overwrite = TRUE)
    
    wb_new_library = createWorkbook()
    addWorksheet(wb_new_library, input$create_library_name)
    writeData(wb_new_library, input$create_library_name, t(data.frame(colnames(data$library))), colNames = FALSE)
    saveWorkbook(wb_new_library, paste0(link_to_data, input$create_library_name, "_", input$create_user, ".xlsx"), overwrite = TRUE)
    
    showModal(modalDialog(
      title = HTML("<b>Confirmation</b>"),
      HTML(paste0("La bibliothèque a bien été créée. Merci de rafraîchir la page et vous connecter sur votre compte.")),
      footer = tagList(
        modalButton("Fermer", icon = icon("close"))
      ),
      easyClose = TRUE
    ))
    
  })
  
  
}


# ==============================================================================
#                          Sécurisation de l'application
# ==============================================================================

ui = secure_app(ui = ui, tags_top = tags$div(tags$head(tags$link(rel = "stylesheet", href = "custom.css"))), language = "fr")


# ==============================================================================
#                           Lancement de l'application
# ==============================================================================

shinyApp(ui = ui, server = server)

