
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


# ==============================================================================
#                                  Variables
# ==============================================================================

genres <- c("Album jeunesse", "Art", "Bande dessinée", "Langue", "Littérature", "Manga", "Nouvelle", "Philosophie", "Poésie", "Récit", "Religion", "Roman", "Sciences", "Sport", "Théâtre")

# Couleurs pour la roue
wheel_colors <- c("#8b35bc", "#b163da", "#FF5733", "#33FF57", "#3357FF", "#F3FF33", "#FF33F3", "#33FFF3")
wheel_labels <- c("Violet", "Lilas", "Orange", "Vert", "Bleu", "Jaune", "Rose", "Cyan")


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
      menuItem("Statistiques", tabName = "statistiques", icon = icon("chart-bar")),
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
            fileInput("library_csv", "Choisissez votre bibliothèque", accept = c(".xlsx", ".csv"), buttonLabel = "Parcourir", placeholder = "Sélectionner une bibliothèque"),
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
#                                    Page 3
# ------------------------------------------------------------------------------

      tabItem(
        tabName = "statistiques",
        fluidRow(
          column(4,
            box(
              title = "Nombre de livres",
              status = "primary",
              solidHeader = TRUE,
              width = 12,
              h2(textOutput(outputId = "nb_livres"), class = "text-stat")
            )
          ),
          column(4,
            box(
              title = "Nombre de livres lus",
              status = "primary",
              solidHeader = TRUE,
              width = 12,
              h2(textOutput(outputId = "nb_livres_lus"), class = "text-stat")
            )
          ),
          column(4,
            box(
              title = "Nombre de livres aimés",
              status = "primary",
              solidHeader = TRUE,
              width = 12,
              h2(textOutput(outputId = "nb_livres_aimes"), class = "text-stat")
            ),
          )
        ),
        fluidRow(
          column(4,
                 box(
                   title = "Nombre d'auteurs différents",
                   status = "primary",
                   solidHeader = TRUE,
                   width = 12,
                   h2(textOutput(outputId = "nb_auteurs"), class = "text-stat")
                 )
          ),
          column(4,
                 box(
                   title = "Nombre de genres différents",
                   status = "primary",
                   solidHeader = TRUE,
                   width = 12,
                   h2(textOutput(outputId = "nb_genres"), class = "text-stat")
                 )
          ),
          column(4,
                 box(
                   title = "Nombre de pages lus",
                   status = "primary",
                   solidHeader = TRUE,
                   width = 12,
                   h2(textOutput(outputId = "nb_pages_lues"), class = "text-stat")
                 ),
          )
        ),
        fluidRow(
          column(6,
            plotOutput("plot_livres_genres")
          ),
          column(6,
            plotOutput("plot_pages_genres")
          )
        ),
        fluidRow(
          box(
            title = "Statistiques sur l'auteur",
            status = "primary",
            width = 12,
            solidHeader = TRUE,
            collapsible = TRUE,
            collapsed = TRUE
          )
        ),
        fluidRow(
          box(
            title = "Statistiques sur le genre",
            status = "primary",
            width = 12,
            solidHeader = TRUE,
            collapsible = TRUE,
            collapsed = TRUE
          )
        ),
        fluidRow(
          box(
            title = "Statistiques sur la langue",
            status = "primary",
            width = 12,
            solidHeader = TRUE,
            collapsible = TRUE,
            collapsed = TRUE
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
  
  output$table_data <- renderDT({
    req(input$library_csv)
    ext <- tools::file_ext(input$library_csv$name)
    data$library <- if (ext == "xlsx") {
      read_xlsx(input$library_csv$datapath, col_names = TRUE)
    } else {
      read.csv(input$library_csv$datapath, stringsAsFactors = FALSE)
    }
    datatable(data$library, options = list(scrollX = TRUE, pageLength = 50), rownames = FALSE)
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
    
    datatable(select(data_library_tri, "Titre", "Auteur", "Date"), options = list(scrollX = TRUE, pageLenght = 5), rownames = FALSE)
      
  })
  
  
# ------------------------------------------------------------------------------
#                                    Page 3
# ------------------------------------------------------------------------------
  
  # Ne marche pas
  
  output$nb_livres <- renderText({
    
    paste0(nrow(data$library), " livres")
    
  })
  
  output$nb_livres_lus <- renderText({
    
    data$library_lus <- filter(data$library, Lu=="Oui" & Principal == "Oui")
    
    paste0(nrow(data$library_lus), " livres lus (", round(nrow(data$library_lus)/nrow(data$library)*100,2), " %)")
    
  })
  
  output$nb_livres_aimes <- renderText({
    
    data$library_livres_aimes <- data$library %>%
      filter(Principal == "Oui", Favoris=="Oui")
    
    paste0(nrow(data$library_livres_aimes), " livres aimés (", round(nrow(data$library_livres_aimes)/nrow(data$library_lus)*100,2), " %)")
    
  })
  
  output$nb_auteurs <- renderText({
    
    paste0(length(unique(data$library[["Auteur"]])), " auteurs")
    
  })
  
  output$nb_genres <- renderText({
    
    paste0(length(unique(data$library[["Genre"]])), " genres")
    
  })
  
  output$nb_pages_lues <- renderText({
    
    data$pages_lues <- data$library %>%
      filter(Lu == "Oui")
    
    paste0(round(sum(data$pages_lues[["Pages"]]),0), " pages lues (", round(sum(data$pages_lues[["Pages"]])/sum(data$library[["Pages"]])*100,2), " %)")
    
  })
  
  output$plot_livres_genres <- renderPlot({
    
    data$plot_livres_genres = data.frame("Genre" = character(), "Nombre" = numeric(), "Lus" = numeric())
    
    data$sort_genres = sort(unique(data$library[["Genre"]]), decreasing = TRUE)
    
    for (genre in data$sort_genres) {
      data$plot_livres_genres = rbind(data$plot_livres_genre, cbind(genre, nrow(filter(data$library, Genre == genre)), nrow(filter(data$library, Genre == genre, Lu == "Oui"))))
    }
    
    ggplot(data$plot_livres_genres, aes(x=factor(Genre, levels = sort(unique(livres$Genre), decreasing = TRUE)), y=Nombre)) + 
      geom_bar(stat = "identity", fill="#ca084c") + 
      coord_flip() +
      labs(x = "Genres", y = "Pourcentage de livre lus", title = "") +
      theme_bw() + 
      theme(legend.position = "none") +
      geom_label(label = paste0(data$plot_livres_genres[["Lu"]], " livres"), color="white", fill = "#ca084c")
    
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
