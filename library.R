
# ==============================================================================
#                            Chargement des packages
# ==============================================================================

library(shiny)
library(shinydashboard)
library(shinycssloaders)
library(shinymanager)
library(DT)
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
library(timevis)
library(tmap)
library(sf)
library(plotly)
library(leaflet)
library(aws.s3)
library(httr2)
library(purrr)

# ==============================================================================
#                           Chatbot
# ==============================================================================



# Extraction robuste de la réponse
gemini_chat <- function(history) {
  body <- list(contents = history)

  # Réessaie jusqu'à 5 fois avec délai exponentiel
  for (i in 1:5) {
    tryCatch({
      resp <- request("https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent") %>%
        req_headers(
          "x-goog-api-key" = Sys.getenv("GEMINI_API_KEY"),
          "Content-Type"   = "application/json"
        ) %>%
        req_body_json(body) %>%
        req_perform()

      result <- resp %>% resp_body_json(simplifyVector = FALSE)

      return(tryCatch(
        result[["candidates"]][[1]][["content"]][["parts"]][[1]][["text"]],
        error = function(e) "Erreur : impossible de lire la réponse"
      ))

    }, error = function(e) {
      if (grepl("429", e$message)) {
        delai <- 2 ^ i  # 2, 4, 8, 16, 32 secondes
        message("429 reçu, attente ", delai, "s (essai ", i, "/5)")
        Sys.sleep(delai)
      } else {
        stop(e)  # autre erreur → on arrête
      }
    })
  }

  "Le service est temporairement surchargé, réessaie dans une minute."
}

# ==============================================================================
#                                  Fonctions
# ==============================================================================

s3_read_xlsx <- function(key) {
  obj <- get_object(object = key, bucket = bucket)
  if (is.null(obj)) return(NULL)  # fichier inexistant
  tmp <- tempfile(fileext = ".xlsx")
  writeBin(obj, tmp)
  read_excel(tmp)
}

s3_write_xlsx <- function(df, key) {
  tmp <- tempfile(fileext = ".xlsx")
  write_xlsx(df, tmp)
  put_object(file = tmp, object = key, bucket = bucket)
}

s3_write_xlsx <- function(wb, key) {
  tmp <- tempfile(fileext = ".xlsx")
  saveWorkbook(wb, tmp, overwrite = TRUE)
  put_object(file = tmp, object = key, bucket = bucket)
}


# ==============================================================================
#                                   Chemins
# ==============================================================================

#setwd(dirname(rstudioapi::getActiveDocumentContext()$path))

config <- fromJSON("www/config.json")

link_to_data = config$link$link_to_data
link_to_css = config$link$link_to_css
link_to_livres = config$link$link_to_livres


# ==============================================================================
#                                   AWS S3
# ==============================================================================

region = config$s3$region
bucket = config$s3$bucket

Sys.setenv(
  AWS_ACCESS_KEY_ID = config$s3_key$key,
  AWS_SECRET_ACCESS_KEY = config$s3_key$private_key,
  AWS_DEFAULT_REGION = region
)


# ==============================================================================
#                                 Credentials
# ==============================================================================

credentials = s3_read_xlsx(config$link$link_to_credentials)


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
world_map$french_shor[which(world_map$french_shor %in% c("French Guiana", "Guadeloupe", "Martinique"))] = "France"


# ==============================================================================
#                                  Variables
# ==============================================================================

# Couleurs pour la roue
wheel_colors <- c("#8b35bc", "#b163da", "#FF5733", "#33FF57", "#3357FF", "#F3FF33", "#FF33F3", "#33FFF3")
wheel_labels <- c("Violet", "Lilas", "Orange", "Vert", "Bleu", "Jaune", "Rose", "Cyan")


second_color = "#818cf8"
bleu_light = "#12121c"

auteur_default="Dante Alighieri"
pays_default="Français"
siecle_default="XXIe"
genre_default="Littérature"

loadingtype = 6
loadingcolor = second_color


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

get_timeline_books = function(df_books, colonne) {

  if (colonne == "Sortie") {
    timeline_items <- bind_rows(
      df_books %>%
        filter(!is.na(Date)) %>%
        mutate(
          id = paste0("s_", row_number()),
          content = paste0("<b>", Titre, "</b><br><i style='opacity:0.7;font-size:0.85em;'>", Auteur, "</i><br><span style='opacity:0.5;font-size:0.8em;'>", Date, "</span>"),
          start = as.Date(paste0(Date, "-01-01"))
        ),
    )
  } else if (colonne == "Lecture") {
    timeline_items <- bind_rows(
      df_books %>%
        filter(!is.na(Commencé)) %>%
        mutate(
          id = paste0("l_", row_number()),
          content = paste0("<b>", Titre, "</b><br><i style='opacity:0.7;font-size:0.85em;'>", Auteur, "</i><br><span style='opacity:0.5;font-size:0.8em;'>", Date, "</span>"),
          start = as.Date(Commencé, format = "%d-%m-%Y"),
          end = dplyr::if_else(is.na(Fini) | Fini == "", Sys.Date(), as.Date(Fini, format = "%d-%m-%Y")),
          end = dplyr::if_else(end == start, end + 1, end)
        )
    )
  }


  timeline_items <- timeline_items %>%
    filter(!is.na(start)) %>%
    mutate(style = "color: #818cf8; background-color: #191927;
                    font-family: 'Baskerville Old';
                    border-radius: 10px; border: 1px solid rgba(129,140,248,0.35);
                    text-align: center; padding: 6px 10px; line-height: 1.5;
                    box-shadow: 0 2px 8px rgba(0,0,0,0.4);")

  return(timeline_items)
}



#data=read.xlsx("C:/Users/theod/OneDrive/Documents/Perso/Livres/Bibliothèque/bibliothèques/library.xlsx")
#names(data)=c("library")

# ==============================================================================
#                          Donnees demo (compte invite)
# ==============================================================================

guest_library_name <- credentials$library[which(credentials$user == "exemple_pour_invité")]
guest_data <- s3_read_xlsx(paste0(link_to_data, guest_library_name)) %>%
  mutate(Longueur = as.numeric(Longueur), Pages = as.numeric(Pages))


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
  dashboardHeader(
    title = "Library",
    tags$li(class = "dropdown",
            tags$div(style = "padding: 10px 8px;",
                     tags$button(
                       id    = "theme-toggle-btn",
                       class = "theme-toggle-btn",
                       title = "Changer le thème",
                       tags$i(class = "fa fa-sun")
                     )
            )
    ),
    tags$li(class = "dropdown", uiOutput("header_filtres_btn")),
    tags$li(class = "dropdown", uiOutput("header_download_btn")),
    tags$li(class = "dropdown", uiOutput("header_login_btn"))

  ),

  dashboardSidebar(
    uiOutput("main_sidebar")
  ),
  dashboardBody(
    # Activez shinyjs
    useShinyjs(),

    # Chargez les scripts externes pour Chart.js
    tags$head(
      tags$script(src = "custom.js"),
      tags$link(rel = "stylesheet", type = "text/css", href = "custom.css"),
      tags$link(rel = "icon", type = "image/png", href = "favicon.png"),
      tags$script(HTML("
        // Theme toggle — appliqué tôt pour éviter le flash
        // Par défaut : mode sombre (initialise localStorage si vide)
        (function() {
          var saved = localStorage.getItem('library-theme');
          if (!saved) {
            localStorage.setItem('library-theme', 'dark');
            saved = 'dark';
          }
          if (saved === 'light') document.documentElement.classList.add('light-mode');
        })();
      ")),
      tags$script(src = "https://cdnjs.cloudflare.com/ajax/libs/Chart.js/3.9.1/chart.min.js"),
      tags$script(src = "https://cdnjs.cloudflare.com/ajax/libs/chartjs-plugin-datalabels/2.1.0/chartjs-plugin-datalabels.min.js"),
      tags$script(HTML("
        $(document).on('shiny:connected', function() {

          // ---- Theme toggle ----
          function applyTheme(isLight) {
            if (isLight) {
              document.body.classList.add('light-mode');
              document.documentElement.classList.add('light-mode');
            } else {
              document.body.classList.remove('light-mode');
              document.documentElement.classList.remove('light-mode');
            }
            var btn = document.getElementById('theme-toggle-btn');
            if (btn) {
              btn.innerHTML = isLight
                ? '<i class=\"fa fa-moon\"></i>'
                : '<i class=\"fa fa-sun\"></i>';
            }
          }

          // Appliquer le thème sauvegardé au démarrage
          var savedTheme = localStorage.getItem('library-theme');
          applyTheme(savedTheme === 'light');

          // Clic sur le bouton
          $(document).on('click', '#theme-toggle-btn', function() {
            var isNowLight = !document.body.classList.contains('light-mode');
            localStorage.setItem('library-theme', isNowLight ? 'light' : 'dark');
            applyTheme(isNowLight);
          });






          // ---- Carousel ----
          var navThrottle = false;
          var throttleMs = 350;

          function navigateCarousel(dir) {
            if (navThrottle) return;
            navThrottle = true;
            Shiny.setInputValue('carousel_nav', {dir: dir, t: Date.now()}, {priority: 'event'});
            setTimeout(function() { navThrottle = false; }, throttleMs);
          }

          // Mouse wheel navigation
          document.addEventListener('wheel', function(e) {
            var wrapper = e.target.closest('.carousel-wrapper');
            if (!wrapper) return;
            e.preventDefault();
            var dir = (e.deltaY > 0 || e.deltaX > 0) ? 'next' : 'prev';
            navigateCarousel(dir);
          }, { passive: false });

          // Mouse drag navigation
          var dragStartX = null;
          var dragThreshold = 60;

          $(document).on('mousedown', '.carousel-wrapper', function(e) {
            if ($(e.target).closest('.book-small').length > 0) return;
            dragStartX = e.clientX;
            e.preventDefault();
          });

          $(document).on('mousemove', function(e) {
            if (dragStartX === null) return;
            var diff = e.clientX - dragStartX;
            if (Math.abs(diff) >= dragThreshold) {
              navigateCarousel(diff < 0 ? 'next' : 'prev');
              dragStartX = e.clientX;
            }
          });

          $(document).on('mouseup', function() {
            dragStartX = null;
          });


        });
      "))
    ),
    tags$input(type = "hidden", id = "chatbot_input_val"),


    tabItems(

      # ------------------------------------------------------------------------------
      #                                   Accueil
      # ------------------------------------------------------------------------------

      tabItem(
        tabName = "accueil",

        # Hero
        div(class = "accueil-hero", style = "text-align: center; padding: 40px 20px 10px;",
            h1(class = "accueil-titre",
               tags$span("Bienvenue sur ", class = "accueil-titre-pre"),
               tags$span("Library", class = "accueil-titre-nom")
            ),
            p("Cataloguez vos livres, suivez vos lectures et explorez vos statistiques.",
              style = "color: var(--blanc); font-family: var(--font); font-size: 16px; opacity: 0.6; max-width: 600px; margin: 0 auto 6px;"),
            p("Un outil gratuit et personnel pour tous les amoureux de la lecture. Ajoutez vos livres, notez vos favoris, et laissez l'application vous révéler vos habitudes de lecteur à travers des graphiques, des cartes et des statistiques détaillées.",
              style = "color: var(--blanc); font-family: var(--font); font-size: 13px; opacity: 0.4; max-width: 650px; margin: 0 auto 25px; line-height: 1.6;"),
            p("De l'analyse de vos habitudes de lecture à la gestion de votre collection, Library rassemble tout en un seul endroit.",
              style = "color: var(--blanc); font-family: var(--font); font-size: 13px; opacity: 0.4; max-width: 650px; margin: 0 auto 8px; line-height: 1.6;")
        ),

        # Intro fonctionnalités
        div(style = "text-align: center; max-width: 680px; margin: 0 auto 4px; padding: 0 20px;",
            tags$h2("Tout ce dont un lecteur a besoin !",
                    style = "font-family: var(--font); font-size: 26px; color: var(--text); font-weight: 700; margin-bottom: 10px;")
        ),

        # Section 1 : Radar genres
        div(class = "accueil-section",
            fluidRow(
              column(5, class = "accueil-text-col",
                     div(class = "accueil-section-text",
                         icon("spider", class = "accueil-section-icon"),
                         h3("Analysez votre profil lecteur !"),
                         p("Découvrez quel type de lecteur vous \u00eates gr\u00e2ce \u00e0 votre radar des genres. Roman, poésie, thé\u00e2tre, science-fiction... quel est votre terrain de jeu ?")
                     )
              ),
              column(7,
                     div(class = "accueil-graph-card",
                         withSpinner(plotlyOutput("demo_radar", height = "320px"), type = loadingtype, color = loadingcolor)
                     )
              )
            )
        ),

        # Section 2 : Livres par annee
        div(class = "accueil-section",
            fluidRow(
              column(7,
                     div(class = "accueil-graph-card",
                         withSpinner(plotlyOutput("demo_livres_annee", height = "280px"), type = loadingtype, color = loadingcolor)
                     )
              ),
              column(5, class = "accueil-text-col",
                     div(class = "accueil-section-text",
                         icon("calendar-check", class = "accueil-section-icon"),
                         h3("Comparez vos années de lecture !"),
                         p("Quelle a été votre meilleure année\u00a0? Visualisez le nombre de livres terminés chaque année et battez vos records.")
                     )
              )
            )
        ),

        # Section 3 : Defis
        div(class = "accueil-section",
            fluidRow(
              column(5, class = "accueil-text-col",
                     div(class = "accueil-section-text",
                         icon("trophy", class = "accueil-section-icon"),
                         h3("Relevez des défis de lecture !"),
                         p("Fixez-vous des objectifs ambitieux et suivez votre progression\u00a0: lire 12 livres dans l'année, découvrir de nouveaux auteurs, terminer une saga\u2026 Chaque défi accompli s'inscrit dans votre profil de lecteur.")
                     )
              ),
              column(7,
                     div(class = "accueil-graph-card",
                         div(class = "accueil-defi-grid",
                             div(class = "accueil-defi-card accueil-defi-card-done",
                                 div(class = "accueil-defi-card-icon", icon("book-open")),
                                 div(class = "accueil-defi-card-label", "Lire 12 livres dans l'année"),
                                 div(class = "accueil-defi-card-badge", icon("check"), " Accompli")
                             ),
                             div(class = "accueil-defi-card accueil-defi-card-done",
                                 div(class = "accueil-defi-card-icon", icon("user-plus")),
                                 div(class = "accueil-defi-card-label", "Découvrir 5 nouveaux auteurs"),
                                 div(class = "accueil-defi-card-badge", icon("check"), " Accompli")
                             ),
                             div(class = "accueil-defi-card",
                                 div(class = "accueil-defi-card-icon", icon("layer-group")),
                                 div(class = "accueil-defi-card-label", "Terminer une saga entière")
                             ),
                             div(class = "accueil-defi-card",
                                 div(class = "accueil-defi-card-icon", icon("hourglass-half")),
                                 div(class = "accueil-defi-card-label", "Lire un classique du XIX\u1d49 siècle")
                             )
                         )
                     )
              )
            )
        ),

        # Section 4 : Top genres
        div(class = "accueil-section",
            fluidRow(
              column(7,
                     div(class = "accueil-graph-card",
                         withSpinner(plotOutput("demo_top_genres", height = "300px"), type = loadingtype, color = loadingcolor)
                     )
              ),
              column(5, class = "accueil-text-col",
                     div(class = "accueil-section-text",
                         icon("ranking-star", class = "accueil-section-icon"),
                         h3("Quels genres dominent votre bibliothèque\u00a0?"),
                         p("Littérature, poésie, philosophie, polar\u2026 Découvrez la répartition de vos lectures par genre et vos préférences.")
                     )
              )
            )
        ),

        # Carousel demo — en dernier
        div(class = "accueil-section", style = "margin-top: 35px;",
            div(style = "text-align: center; margin-bottom: 14px;",
                h3("Parcourez vos livres", style = "color: var(--second-color); font-family: var(--font); font-size: 20px; margin: 0;"),
                p("Feuilletez votre collection dans un carrousel interactif.", style = "color: var(--blanc); font-family: var(--font); font-size: 13px; opacity: 0.4;")
            ),
            uiOutput("demo_carousel")
        ),

        # Call to action
        div(class = "accueil-cta", style = "text-align: center; padding: 40px 20px 50px; max-width: 600px; margin: 0 auto;",
            tags$hr(style = "border: 1px solid rgba(129,140,248,0.15); margin: 0 20% 30px;"),
            h3("Et ce n'est qu'un aper\u00e7u\u00a0!", style = "color: var(--second-color); font-family: var(--font); font-size: 22px; margin-bottom: 8px;"),
            p("Rangez vos livres par auteur, genre ou date. Explorez une frise chronologique de vos lectures. Recevez des suggestions de prochaine lecture. Suivez votre progression avec des barres d'objectifs.",
              style = "color: var(--blanc); font-family: var(--font); font-size: 14px; opacity: 0.5; line-height: 1.7; margin-bottom: 20px;"),
            p("Créez votre compte en quelques secondes et commencez \u00e0 construire votre bibliothèque.",
              style = "color: var(--blanc); font-family: var(--font); font-size: 13px; opacity: 0.35; font-style: italic;")
        )
      ),


      # ------------------------------------------------------------------------------
      #                                    Page 1
      # ------------------------------------------------------------------------------

      tabItem(
        tabName = "bibliotheque",

        # === Hero banner pleine largeur ===
        div(class = "biblio-banner",
            div(class = "biblio-banner-inner",

                # Greeting
                uiOutput("biblio_bienvenue_ui"),

                # Tagline + description
                div(class = "biblio-tagline",
                    "Garde une trace de chaque histoire que tu as traversée."
                ),

                # Stat cards
                div(class = "biblio-stats-grid",
                    div(class = "biblio-stat-card",
                        div(class = "biblio-stat-card-icon biblio-stat-card-icon-lus", icon("circle-check")),
                        div(class = "biblio-stat-card-body",
                            div(class = "biblio-stat-card-num", textOutput("biblio_nb_lus")),
                            div(class = "biblio-stat-card-label", "Livres lus")
                        )
                    ),
                    div(class = "biblio-stat-card",
                        div(class = "biblio-stat-card-icon biblio-stat-card-icon-a-lire", icon("bookmark")),
                        div(class = "biblio-stat-card-body",
                            div(class = "biblio-stat-card-num", textOutput("biblio_nb_a_lire")),
                            div(class = "biblio-stat-card-label", "\u00c0 lire")
                        )
                    ),
                    div(class = "biblio-stat-card",
                        div(class = "biblio-stat-card-icon biblio-stat-card-icon-favoris", icon("star")),
                        div(class = "biblio-stat-card-body",
                            div(class = "biblio-stat-card-num", textOutput("biblio_nb_favoris")),
                            div(class = "biblio-stat-card-label", "Favoris")
                        )
                    )
                )
            )
        ),

        # === Contenu principal — deux colonnes ===
        div(class = "biblio-main",

            # Colonne gauche : En cours de lecture
            div(class = "biblio-main-col biblio-main-encours",
                div(class = "biblio-section-label",
                    icon("book-open"), " En cours de lecture"
                ),
                uiOutput("biblio_en_cours_ui")
            ),

            # Séparateur vertical
            div(class = "biblio-main-sep"),

            # Colonne droite : Dernières lectures
            div(class = "biblio-main-col biblio-main-recents",
                div(class = "biblio-section-label",
                    icon("circle-check"), " Dernières lectures"
                ),
                uiOutput("biblio_recents_ui")
            )
        ),

        # === Boutons d'action ===
        div(class = "biblio-action-row",
            actionButton("btn_ajouter_livre",   "Ajouter un livre",   icon = icon("plus"),  class = "biblio-action-btn"),
            actionButton("btn_modifier_livre",  "Modifier un livre",  icon = icon("pen"),   class = "biblio-action-btn"),
            actionButton("btn_supprimer_livre", "Supprimer un livre", icon = icon("trash"), class = "biblio-action-btn biblio-action-btn-danger")
        ),


        # (filtres déplacés dans le modal "Options" du header)
      ),


      # ------------------------------------------------------------------------------
      #                                    Page 2.1
      # ------------------------------------------------------------------------------

      tabItem(
        tabName = "rangement",
        fluidRow(style = "text-align: center;",
                 h2("Mon rangement", class = "titre-pages"),
                 br(), hr(), br(), br(),
        ),
        fluidRow(
          column(12, class = "modif-search-zone",
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
                        DTOutput("table_tri", height = "40vh")
                 )
          )
        )
      ),


      # ------------------------------------------------------------------------------
      #                                  Page 2.2
      # ------------------------------------------------------------------------------

      tabItem(
        tabName = "rechercher",
        div(style = "text-align: center",
            h2("Rechercher un livre", class = "titre-pages"),
            br(), hr(), br(), br(),
        ),
        fluidRow(
          column(12,
                 div(class = "modif-search-zone",
                     uiOutput("recherche_livre_ui"),
                     selectInput(
                       inputId = "carousel_tri",
                       label = "Ranger par",
                       choices = c("Genre" = "genre", "Date" = "date", "Titre" = "titre", "Auteur" = "auteur"),
                       selected = "genre"
                     )
                 )
          )
        ),
        fluidRow(
          column(12,
                 uiOutput("carousel_livres")
          )
        )
      ),


      # ------------------------------------------------------------------------------
      #                                    Page 3
      # ------------------------------------------------------------------------------

      tabItem(
        tabName = "graph",
        div(style = "text-align: center;",
            h2("Mon Profil", class = "titre-pages"),
            br(), hr(), br(), br(),
        ),
        fluidRow(
          column(5,
                 div(class = "graph-card",
                     h4("Radar des genres", class = "graph-card-title"),
                     withSpinner(plotlyOutput(outputId = "graph_radar_genres", height = "38vh"), type = loadingtype, color = loadingcolor)
                 )
          ),
          column(7,
                 div(class = "graph-card",
                     h4("Carte des origines", class = "graph-card-title"),
                     withSpinner(leafletOutput(outputId = "carte_plot", height = "38vh"), type = loadingtype, color = loadingcolor)
                 )
          )
        ),
        fluidRow(
          column(8,
                 div(class = "graph-card",
                     h4("Livres lus par année", class = "graph-card-title"),
                     withSpinner(plotlyOutput(outputId = "graph_livres_annee", height = "34vh"), type = loadingtype, color = loadingcolor)
                 )
          ),
          column(2,
                 div(class = "graph-card",
                     h4("Pages par livre", class = "graph-card-title"),
                     withSpinner(plotlyOutput(outputId = "violin_plot_pages", height = "34vh"), type = loadingtype, color = loadingcolor)
                 )
          ),
          column(2,
                 div(class = "graph-card",
                     h4("Durée de lecture", class = "graph-card-title"),
                     withSpinner(plotlyOutput(outputId = "violin_plot_duree", height = "34vh"), type = loadingtype, color = loadingcolor)
                 )
          ),
          column(12,
                 div(class = "graph-card graph-card-compact",
                     h4("Livres lus par mois", class = "graph-card-title"),
                     withSpinner(plotlyOutput(outputId = "lus_plot", height = "22vh"), type = loadingtype, color = loadingcolor)
                 )
          ),
          column(12,
                 div(class = "graph-card",
                     h4("Activité de lecture", class = "graph-card-title"),
                     withSpinner(plotlyOutput("act_heatmap", height = "48vh"), type = loadingtype, color = loadingcolor)
                 )
          )
        )
      ),


      # ------------------------------------------------------------------------------
      #                                 Bilan annuel
      # ------------------------------------------------------------------------------

      tabItem(
        tabName = "bilan",
        div(style = "text-align: center;",
            h2("Bilan annuel", class = "titre-pages"),
            br(), hr(), br(),
        ),

        # Sélecteur d'année
        fluidRow(style = "max-width: 960px; margin: 0 auto 6px; text-align: center;",
                 column(12, uiOutput("bilan_annee_ui"))
        ),

        # Stats rapides
        fluidRow(style = "max-width: 960px; margin: 0 auto;",
                 column(3, div(class = "fun-fact-card",
                               div(class = "fun-fact-icon", icon("book-open")),
                               uiOutput("bilan_nb_lus"),
                               div(class = "fun-fact-label", "Livres lus"),
                               div(class = "fun-fact-desc", "cette année"),
                               div(class = "fun-fact-extra", "livres terminés")
                 )),
                 column(3, div(class = "fun-fact-card",
                               div(class = "fun-fact-icon", icon("scroll")),
                               uiOutput("bilan_nb_pages"),
                               div(class = "fun-fact-label", "Pages lues"),
                               div(class = "fun-fact-desc", "au total"),
                               div(class = "fun-fact-extra", "cette année")
                 )),
                 column(3, div(class = "fun-fact-card",
                               div(class = "fun-fact-icon", icon("calendar-check")),
                               uiOutput("bilan_meilleur_mois"),
                               div(class = "fun-fact-label", "Meilleur mois"),
                               div(class = "fun-fact-desc", "le plus actif"),
                               div(class = "fun-fact-extra", "en nombre de livres")
                 )),
                 column(3, div(class = "fun-fact-card",
                               div(class = "fun-fact-icon", icon("clock")),
                               uiOutput("bilan_duree_moy"),
                               div(class = "fun-fact-label", "Durée moyenne"),
                               div(class = "fun-fact-desc", "par livre lu"),
                               div(class = "fun-fact-extra", "en jours")
                 ))
        ),
        br(),

        # Graphique mensuel
        fluidRow(style = "max-width: 960px; margin: 0 auto;",
                 column(12,
                        div(class = "graph-card",
                            h4("Livres lus par mois", class = "graph-card-title"),
                            withSpinner(plotlyOutput("bilan_plot_mois", height = "240px"), type = loadingtype, color = loadingcolor)
                        )
                 )
        ),
        br(),

        # Palmarès + Records
        fluidRow(style = "max-width: 960px; margin: 0 auto;",
                 column(6,
                        div(class = "graph-card",
                            h4(icon("crown"), " Palmarès", class = "graph-card-title"),
                            br(),
                            fluidRow(
                              column(6, div(class = "fun-fact-card fun-fact-card-fav",
                                            div(class = "fun-fact-icon", icon("bookmark")),
                                            uiOutput("bilan_genre_fav"),
                                            div(class = "fun-fact-label", "Genre favori"),
                                            div(class = "fun-fact-desc", "de l'année"),
                                            div(class = "fun-fact-extra", "le plus représenté")
                              )),
                              column(6, div(class = "fun-fact-card fun-fact-card-fav",
                                            div(class = "fun-fact-icon", icon("user")),
                                            uiOutput("bilan_auteur_fav"),
                                            div(class = "fun-fact-label", "Auteur favori"),
                                            div(class = "fun-fact-desc", "de l'année"),
                                            div(class = "fun-fact-extra", "le plus lu")
                              ))
                            )
                        )
                 ),
                 column(6,
                        div(class = "graph-card",
                            h4(icon("trophy"), " Records", class = "graph-card-title"),
                            br(),
                            fluidRow(
                              column(6, div(class = "fun-fact-card fun-fact-card-fav",
                                            div(class = "fun-fact-icon", icon("book")),
                                            uiOutput("bilan_plus_long"),
                                            div(class = "fun-fact-label", "Plus long livre"),
                                            div(class = "fun-fact-desc", "record de pages"),
                                            div(class = "fun-fact-extra", "cette année")
                              )),
                              column(6, div(class = "fun-fact-card fun-fact-card-fav",
                                            div(class = "fun-fact-icon", icon("bolt")),
                                            uiOutput("bilan_plus_rapide"),
                                            div(class = "fun-fact-label", "Lu le plus vite"),
                                            div(class = "fun-fact-desc", "lecture la plus rapide"),
                                            div(class = "fun-fact-extra", "en nombre de jours")
                              ))
                            )
                        )
                 )
        ),
        br(),

        # Premier et dernier livre
        fluidRow(style = "max-width: 960px; margin: 0 auto;",
                 column(6,
                        div(class = "graph-card",
                            h4(icon("flag"), " Premier livre de l'année", class = "graph-card-title"),
                            uiOutput("bilan_premier_livre")
                        )
                 ),
                 column(6,
                        div(class = "graph-card",
                            h4(icon("flag-checkered"), " Dernier livre de l'année", class = "graph-card-title"),
                            uiOutput("bilan_dernier_livre")
                        )
                 )
        ),
        br()
      ),


      # ------------------------------------------------------------------------------
      #                                    Activité
      # ------------------------------------------------------------------------------

      # ------------------------------------------------------------------------------
      #                                    Page 4.1
      # ------------------------------------------------------------------------------

      tabItem(
        tabName = "timeline_sortie",
        div(style = "text-align: center",
            h2("Frise chronologique des publications", class = "titre-pages"),
            br(), hr(), br(), br(),
        ),
        fluidRow(
          column(12,
                 timevisOutput("timeline_vis_sortie")
          )
        )
      ),


      # ------------------------------------------------------------------------------
      #                                    Page 4.2
      # ------------------------------------------------------------------------------

      tabItem(
        tabName = "timeline_lecture",
        div(style = "text-align: center",
            h2("Frise chronologique des lectures", class = "titre-pages"),
            br(), hr(), br(), br(),
        ),
        fluidRow(
          column(12,
                 timevisOutput("timeline_vis_lecture")
          )
        )
      ),


      # ------------------------------------------------------------------------------
      #                                    Page 5.1
      # ------------------------------------------------------------------------------

      tabItem(
        tabName = "stat_livres",
        div(style = "text-align: center;",
            h2("Tous les livres", class = "titre-pages"),
            br(), hr(), br(), br(),
        ),
        fluidRow(
          column(6, uiOutput("progress_livres_ui")),
          column(6, uiOutput("progress_pages_ui"))
        ),
        br(), br(),
        fluidRow(
          column(2, div(class = "fun-fact-card", div(class = "fun-fact-icon", icon("hourglass-half")), uiOutput("fact_restant_a_lire"),         div(class = "fun-fact-label", "Reste \u00e0 lire"),    div(class = "fun-fact-desc", "livres non lus"),             div(class = "fun-fact-extra", "votre pile \u00e0 venir"))),
          column(2, div(class = "fun-fact-card", div(class = "fun-fact-icon", icon("heart")),          uiOutput("nb_livres_aimes_ui"),          div(class = "fun-fact-label", "Coups de c\u0153ur"), div(class = "fun-fact-desc", "livres aimés"),           div(class = "fun-fact-extra", "gardés en mémoire"))),
          column(2, div(class = "fun-fact-card", div(class = "fun-fact-icon", icon("home")),           uiOutput("nb_livres_a_soi_ui"),          div(class = "fun-fact-label", "Possédés"),  div(class = "fun-fact-desc", "dans votre collection"),      div(class = "fun-fact-extra", "achetés ou offerts"))),
          column(2, div(class = "fun-fact-card", div(class = "fun-fact-icon", icon("spell-check")),    uiOutput("fact_mots"),                   div(class = "fun-fact-label", "Mots lus"),             div(class = "fun-fact-desc", "~250 mots par page"),         div(class = "fun-fact-extra", "ordre de grandeur"))),
          column(2, div(class = "fun-fact-card", div(class = "fun-fact-icon", icon("book")),           uiOutput("fact_pages_moyenne"),          div(class = "fun-fact-label", "Taille moyenne"),       div(class = "fun-fact-desc", "d'un livre lu"),         div(class = "fun-fact-extra", "en nombre de pages"))),
          column(2, div(class = "fun-fact-card", div(class = "fun-fact-icon", icon("euro-sign")),      uiOutput("prix_total_ui"),               div(class = "fun-fact-label", "Investissement"),       div(class = "fun-fact-desc", "prix total des livres"),      div(class = "fun-fact-extra", "valeur estimée")))
        ),
        fluidRow(
          column(3, div(class = "fun-fact-card", div(class = "fun-fact-icon", icon("crown")), uiOutput("record_auteur_top"),        div(class = "fun-fact-label", "Auteur le plus lu"),    div(class = "fun-fact-desc", "le plus de livres"),          div(class = "fun-fact-extra", "dans votre bibliothèque"))),
          column(3, div(class = "fun-fact-card", div(class = "fun-fact-icon", icon("crown")), uiOutput("fact_genre_prefere"),       div(class = "fun-fact-label", "Genre favori"),          div(class = "fun-fact-desc", "de prédilection"),       div(class = "fun-fact-extra", "le plus fréquent"))),
          column(3, div(class = "fun-fact-card", div(class = "fun-fact-icon", icon("crown")), uiOutput("pays_origine_fav_ui"),      div(class = "fun-fact-label", "Pays le plus lu"),       div(class = "fun-fact-desc", "nationalité d'auteur"), div(class = "fun-fact-extra", "la plus représentée"))),
          column(3, div(class = "fun-fact-card", div(class = "fun-fact-icon", icon("crown")), uiOutput("langue_ecriture_fav_ui"),   div(class = "fun-fact-label", "Langue la plus lue"),   div(class = "fun-fact-desc", "langue d'écriture"), div(class = "fun-fact-extra", "la plus fréquente")))
        ),
        fluidRow(
          column(2, div(class = "fun-fact-card", div(class = "fun-fact-icon", icon("user")),        uiOutput("nb_auteurs_ui"),          div(class = "fun-fact-label", "Auteurs"),          div(class = "fun-fact-desc", "auteurs différents"),    div(class = "fun-fact-extra", "au fil de vos lectures"))),
          column(2, div(class = "fun-fact-card", div(class = "fun-fact-icon", icon("bookmark")),    uiOutput("nb_genres_ui"),           div(class = "fun-fact-label", "Genres"),           div(class = "fun-fact-desc", "genres différents"),     div(class = "fun-fact-extra", "dans votre collection"))),
          column(2, div(class = "fun-fact-card", div(class = "fun-fact-icon", icon("book-open")),   uiOutput("record_plus_gros"),       div(class = "fun-fact-label", "Plus gros livre"),  div(class = "fun-fact-desc", "record de pages"),            div(class = "fun-fact-extra", "dans vos lectures"))),
          column(2, div(class = "fun-fact-card", div(class = "fun-fact-icon", icon("scroll")),      uiOutput("record_plus_vieux"),      div(class = "fun-fact-label", "Plus vieux livre"), div(class = "fun-fact-desc", "le plus ancien lu"),          div(class = "fun-fact-extra", "par date de parution"))),
          column(2, div(class = "fun-fact-card", div(class = "fun-fact-icon", icon("globe")),       uiOutput("fact_pays"),              div(class = "fun-fact-label", "Pays explorés"), div(class = "fun-fact-desc", "\u00e0 travers vos lectures"), div(class = "fun-fact-extra", "via vos auteurs"))),
          column(2, div(class = "fun-fact-card", div(class = "fun-fact-icon", icon("language")),    uiOutput("nb_langue_ecriture_ui"),  div(class = "fun-fact-label", "Langues"),          div(class = "fun-fact-desc", "langues d'écriture"), div(class = "fun-fact-extra", "dans votre collection")))
        ),
        fluidRow(
          column(3, div(class = "fun-fact-card", div(class = "fun-fact-icon", icon("clock")),         uiOutput("fact_temps_lecture"),  div(class = "fun-fact-label", "Temps de lecture"), div(class = "fun-fact-desc", "heures estimées"),       div(class = "fun-fact-extra", "30 pages par heure"))),
          column(3, div(class = "fun-fact-card", div(class = "fun-fact-icon", icon("calendar-days")), uiOutput("fact_anciennete"),     div(class = "fun-fact-label", "\u00c9cart temporel"), div(class = "fun-fact-desc", "entre vos livres"),         div(class = "fun-fact-extra", "du plus ancien au récent"))),
          column(3, div(class = "fun-fact-card", div(class = "fun-fact-icon", icon("layer-group")),   uiOutput("fact_hauteur_pages"),  div(class = "fun-fact-label", "Pages empilées"), div(class = "fun-fact-desc", "en hauteur"),               div(class = "fun-fact-extra", "livres superposés"))),
          column(3, div(class = "fun-fact-card", div(class = "fun-fact-icon", icon("road")),           uiOutput("fact_distance_pages"), div(class = "fun-fact-label", "Bout \u00e0 bout"),   div(class = "fun-fact-desc", "pages dépliées"),  div(class = "fun-fact-extra", "de toute votre pile")))
        )
      ),


      # ------------------------------------------------------------------------------
      #                                    Page 5.2
      # ------------------------------------------------------------------------------

      tabItem(
        tabName = "stat_auteur",
        div(style = "text-align: center;",
            h2("Auteurs", class = "titre-pages"),
            br(), hr(), br(), br(),
        ),
        fluidRow(
          column(6,
                 div(class = "stat-sub-controls",
                     uiOutput(outputId = "ui_choix_auteur")
                 ),
                 fluidRow(
                   column(6, div(class = "stat-card stat-card-compact",
                                 div(class = "stat-card-icon", icon("book")),
                                 h2(textOutput(outputId = "nb_livres_auteurs"), class = "text-stat"),
                                 div(class = "stat-card-label", "Livres")
                   )),
                   column(6, div(class = "stat-card stat-card-compact",
                                 div(class = "stat-card-icon", icon("check")),
                                 h2(textOutput(outputId = "nb_livres_lus_auteurs"), class = "text-stat"),
                                 div(class = "stat-card-label", "Livres lus")
                   )),
                   column(6, div(class = "stat-card stat-card-compact",
                                 div(class = "stat-card-icon", icon("file")),
                                 h2(textOutput(outputId = "nb_pages_auteurs"), class = "text-stat"),
                                 div(class = "stat-card-label", "Pages")
                   )),
                   column(6, div(class = "stat-card stat-card-compact",
                                 div(class = "stat-card-icon", icon("file-alt")),
                                 h2(textOutput(outputId = "nb_pages_lues_auteurs"), class = "text-stat"),
                                 div(class = "stat-card-label", "Pages lues")
                   ))
                 )
          ),
          column(6,
                 DTOutput(outputId = "table_stat_auteurs")
          )
        ),
        br(), hr(), br(),
        fluidRow(style = "text-align: center;",
                 column(6,
                        div(class = "plot-container",
                            h2("Taux de livres lus", class = "titre-graph"),
                            withSpinner(plotOutput("plot_livres_auteurs"), type = loadingtype, color = loadingcolor)
                        )
                 ),
                 column(6,
                        div(class = "plot-container",
                            h2("Taux de pages lues", class = "titre-graph"),
                            withSpinner(plotOutput("plot_pages_auteurs"), type = loadingtype, color = loadingcolor)
                        )
                 )
        )
      ),


      # ------------------------------------------------------------------------------
      #                                    Page 5.3
      # ------------------------------------------------------------------------------

      tabItem(
        tabName = "stat_genre",
        div(style = "text-align: center;",
            h2("Genres", class = "titre-pages"),
            br(), hr(), br(), br(),
        ),
        fluidRow(
          column(6,
                 div(class = "stat-sub-controls",
                     uiOutput(outputId = "ui_choix_genre")
                 ),
                 fluidRow(
                   column(6, div(class = "stat-card stat-card-compact",
                                 div(class = "stat-card-icon", icon("book")),
                                 h2(textOutput(outputId = "nb_livres_genres"), class = "text-stat"),
                                 div(class = "stat-card-label", "Livres")
                   )),
                   column(6, div(class = "stat-card stat-card-compact",
                                 div(class = "stat-card-icon", icon("check")),
                                 h2(textOutput(outputId = "nb_livres_lus_genres"), class = "text-stat"),
                                 div(class = "stat-card-label", "Livres lus")
                   )),
                   column(6, div(class = "stat-card stat-card-compact",
                                 div(class = "stat-card-icon", icon("file")),
                                 h2(textOutput(outputId = "nb_pages_genres"), class = "text-stat"),
                                 div(class = "stat-card-label", "Pages")
                   )),
                   column(6, div(class = "stat-card stat-card-compact",
                                 div(class = "stat-card-icon", icon("file-alt")),
                                 h2(textOutput(outputId = "nb_pages_lues_genres"), class = "text-stat"),
                                 div(class = "stat-card-label", "Pages lues")
                   ))
                 )
          ),
          column(6,
                 DTOutput(outputId = "table_stat_genres")
          )
        ),
        br(), hr(), br(),
        fluidRow(style = "text-align: center;",
                 column(6,
                        div(class = "plot-container",
                            h2("Taux de livres lus", class = "titre-graph"),
                            withSpinner(plotOutput("plot_livres_genres"), type = loadingtype, color = loadingcolor)
                        )
                 ),
                 column(6,
                        div(class = "plot-container",
                            h2("Taux de pages lues", class = "titre-graph"),
                            withSpinner(plotOutput("plot_pages_genres"), type = loadingtype, color = loadingcolor)
                        )
                 )
        )
      ),


      # ------------------------------------------------------------------------------
      #                                    Page 5.4
      # ------------------------------------------------------------------------------

      tabItem(
        tabName = "stat_pays",
        div(style = "text-align: center;",
            h2("Pays", class = "titre-pages"),
            br(), hr(), br(), br(),
        ),
        fluidRow(
          column(6,
                 div(class = "stat-sub-controls",
                     uiOutput(outputId = "ui_choix_pays")
                 ),
                 fluidRow(
                   column(6, div(class = "stat-card stat-card-compact",
                                 div(class = "stat-card-icon", icon("book")),
                                 h2(textOutput(outputId = "nb_livres_pays"), class = "text-stat"),
                                 div(class = "stat-card-label", "Livres")
                   )),
                   column(6, div(class = "stat-card stat-card-compact",
                                 div(class = "stat-card-icon", icon("check")),
                                 h2(textOutput(outputId = "nb_livres_lus_pays"), class = "text-stat"),
                                 div(class = "stat-card-label", "Livres lus")
                   )),
                   column(6, div(class = "stat-card stat-card-compact",
                                 div(class = "stat-card-icon", icon("file")),
                                 h2(textOutput(outputId = "nb_pages_pays"), class = "text-stat"),
                                 div(class = "stat-card-label", "Pages")
                   )),
                   column(6, div(class = "stat-card stat-card-compact",
                                 div(class = "stat-card-icon", icon("file-alt")),
                                 h2(textOutput(outputId = "nb_pages_lues_pays"), class = "text-stat"),
                                 div(class = "stat-card-label", "Pages lues")
                   ))
                 )
          ),
          column(6,
                 DTOutput(outputId = "table_stat_pays")
          )
        ),
        br(), hr(), br(),
        fluidRow(style = "text-align: center;",
                 column(6,
                        div(class = "plot-container",
                            h2("Taux de livres lus", class = "titre-graph"),
                            withSpinner(plotOutput("plot_livres_pays"), type = loadingtype, color = loadingcolor)
                        )
                 ),
                 column(6,
                        div(class = "plot-container",
                            h2("Taux de pages lues", class = "titre-graph"),
                            withSpinner(plotOutput("plot_pages_pays"), type = loadingtype, color = loadingcolor)
                        )
                 )
        )
      ),


      # ------------------------------------------------------------------------------
      #                                    Page 5.5
      # ------------------------------------------------------------------------------

      tabItem(
        tabName = "stat_siecle",
        div(style = "text-align: center;",
            h2("Siècles", class = "titre-pages"),
            br(), hr(), br(), br(),
        ),
        fluidRow(
          column(6,
                 div(class = "stat-sub-controls",
                     uiOutput(outputId = "ui_choix_siecle")
                 ),
                 fluidRow(
                   column(6, div(class = "stat-card stat-card-compact",
                                 div(class = "stat-card-icon", icon("book")),
                                 h2(textOutput(outputId = "nb_livres_siecle"), class = "text-stat"),
                                 div(class = "stat-card-label", "Livres")
                   )),
                   column(6, div(class = "stat-card stat-card-compact",
                                 div(class = "stat-card-icon", icon("check")),
                                 h2(textOutput(outputId = "nb_livres_lus_siecle"), class = "text-stat"),
                                 div(class = "stat-card-label", "Livres lus")
                   )),
                   column(6, div(class = "stat-card stat-card-compact",
                                 div(class = "stat-card-icon", icon("file")),
                                 h2(textOutput(outputId = "nb_pages_siecle"), class = "text-stat"),
                                 div(class = "stat-card-label", "Pages")
                   )),
                   column(6, div(class = "stat-card stat-card-compact",
                                 div(class = "stat-card-icon", icon("file-alt")),
                                 h2(textOutput(outputId = "nb_pages_lues_siecle"), class = "text-stat"),
                                 div(class = "stat-card-label", "Pages lues")
                   ))
                 )
          ),
          column(6,
                 DTOutput(outputId = "table_stat_siecle")
          )
        ),
        br(), hr(), br(),
        fluidRow(style = "text-align: center;",
                 column(6,
                        div(class = "plot-container",
                            h2("Taux de livres lus", class = "titre-graph"),
                            withSpinner(plotOutput("plot_livres_siecles"), type = loadingtype, color = loadingcolor)
                        )
                 ),
                 column(6,
                        div(class = "plot-container",
                            h2("Taux de pages lues", class = "titre-graph"),
                            withSpinner(plotOutput("plot_pages_siecles"), type = loadingtype, color = loadingcolor)
                        )
                 )
        )
      ),


      # ------------------------------------------------------------------------------
      #                                Page Profil Lecteur
      # ------------------------------------------------------------------------------

      tabItem(
        tabName = "profil_lecteur",
        div(style = "text-align: center;",
            h2("Mon Profil Lecteur", class = "titre-pages"),
            br(), hr(), br(), br(),
        ),
        fluidRow(
          column(5,
                 div(class = "graph-card",
                     h4("Radar des genres", class = "graph-card-title"),
                     withSpinner(plotlyOutput(outputId = "profil_radar_genres", height = "38vh"), type = loadingtype, color = loadingcolor)
                 )
          ),
          column(7,
                 div(class = "graph-card",
                     h4("Livres lus par annee", class = "graph-card-title"),
                     withSpinner(plotlyOutput(outputId = "profil_livres_annee", height = "38vh"), type = loadingtype, color = loadingcolor)
                 )
          )
        ),
        fluidRow(
          column(6,
                 div(class = "graph-card",
                     h4("En cours de lecture", class = "graph-card-title"),
                     br(),
                     uiOutput("profil_en_cours")
                 )
          ),
          column(6,
                 div(class = "graph-card",
                     div(class = "suggestion-header",
                         h4("Prochaine lecture ?", class = "graph-card-title", style = "margin: 0;"),
                         div(class = "suggestion-controls",
                             div(class = "suggestion-select-inline",
                                 uiOutput("suggestion_genre_ui")
                             ),
                             actionButton("suggestion_refresh", label = NULL, icon = icon("shuffle"), class = "suggestion-btn")
                         )
                     ),
                     uiOutput("suggestion_livre")
                 )
          )
        )
      ),


      # ------------------------------------------------------------------------------
      #                                  Page Defis
      # ------------------------------------------------------------------------------

      tabItem(
        tabName = "defis",
        div(style = "text-align: center;",
            h2("Mes Défis", class = "titre-pages"),
            br(), hr(), br(), br(),
        ),
        fluidRow(style = "max-width: 1000px; margin: 0 auto;",
                 column(12,
                        p("Progressez dans vos objectifs de lecture et débloquez de nouveaux paliers.",
                          style = "text-align: center; color: var(--blanc); font-family: var(--font); font-size: 14px; opacity: 0.5; margin-bottom: 25px;")
                 )
        ),

        fluidRow(style = "max-width: 1000px; margin: 0 auto; margin-bottom: 30px;",
                 column(12, uiOutput("defi_progression_globale"))
        ),

        # Defis Bibliotheque
        fluidRow(style = "max-width: 1000px; margin: 0 auto;",
                 column(12,
                        h4(icon("book"), " Bibliothèque", class = "defi-section-title"),
                        uiOutput("defi_livres_biblio")
                 )
        ),
        br(),

        # Defis Lectures
        fluidRow(style = "max-width: 1000px; margin: 0 auto;",
                 column(12,
                        h4(icon("book-open"), " Lectures", class = "defi-section-title"),
                        uiOutput("defi_livres_lus")
                 )
        ),
        br(),

        # Defis Pages
        fluidRow(style = "max-width: 1000px; margin: 0 auto;",
                 column(12,
                        h4(icon("scroll"), " Pages lues", class = "defi-section-title"),
                        uiOutput("defi_pages")
                 )
        ),
        br(),

        # Defis Exploration
        fluidRow(style = "max-width: 1000px; margin: 0 auto;",
                 column(12,
                        h4(icon("compass"), " Exploration", class = "defi-section-title"),
                        uiOutput("defi_exploration")
                 )
        ),
        br(),

        # Defis Regularite
        fluidRow(style = "max-width: 1000px; margin: 0 auto;",
                 column(12,
                        h4(icon("calendar-check"), " Régularité", class = "defi-section-title"),
                        uiOutput("defi_regularite")
                 )
        ),
        br(),

        # Defis Completiste
        fluidRow(style = "max-width: 1000px; margin: 0 auto;",
                 column(12,
                        h4(icon("puzzle-piece"), " Complétiste", class = "defi-section-title"),
                        uiOutput("defi_completiste")
                 )
        ),
        br(),

        # Defis Longueur
        fluidRow(style = "max-width: 1000px; margin: 0 auto;",
                 column(12,
                        h4(icon("ruler"), " Gabarits", class = "defi-section-title"),
                        uiOutput("defi_longueur")
                 )
        ),
        br()
      ),


      # ------------------------------------------------------------------------------
      #                                   Page Option
      # ------------------------------------------------------------------------------

      tabItem(
        tabName = "spinner_wheel",
        div(style = "text-align: center;",
            h2("Tirage au sort", class = "titre-pages"),
            br(), hr(), br(), br(),
        ),

        # --- Prochaine lecture ---
        fluidRow(style = "max-width: 1100px; margin: 0 auto 20px;",
                 column(12,
                        div(class = "graph-card tirage-card",
                            div(class = "tirage-header",
                                div(class = "tirage-header-left",
                                    icon("book-open", class = "tirage-icon"),
                                    div(
                                      h4("Prochaine lecture", class = "graph-card-title",
                                         style = "margin: 0; border: none; padding: 0; text-align: left;"),
                                      p("Tirage au sort parmi vos livres non lus", class = "tirage-sub")
                                    )
                                ),
                                div(class = "tirage-controls",
                                    radioButtons("tirage_lecture_mode", label = NULL,
                                                 choices = list("Genre" = "genre", "Auteur" = "auteur", "\u00c9poque" = "siecle"),
                                                 selected = "genre", inline = TRUE),
                                    div(class = "tirage-filter-wrap",
                                        uiOutput("tirage_lecture_filtre_ui")),
                                    actionButton("tirage_lecture_refresh", label = NULL,
                                                 icon = icon("shuffle"), class = "suggestion-btn")
                                )
                            ),
                            uiOutput("tirage_lecture_ui")
                        )
                 )
        ),

        # --- Prochain achat ---
        fluidRow(style = "max-width: 1100px; margin: 0 auto 20px;",
                 column(12,
                        div(class = "graph-card tirage-card",
                            div(class = "tirage-header",
                                div(class = "tirage-header-left",
                                    icon("cart-shopping", class = "tirage-icon"),
                                    div(
                                      h4("Prochain achat", class = "graph-card-title",
                                         style = "margin: 0; border: none; padding: 0; text-align: left;"),
                                      p("Tirage au sort parmi les livres absents de votre bibliothèque", class = "tirage-sub")
                                    )
                                ),
                                div(class = "tirage-controls",
                                    radioButtons("tirage_achat_mode", label = NULL,
                                                 choices = list("Genre" = "genre", "Auteur" = "auteur", "\u00c9poque" = "siecle"),
                                                 selected = "genre", inline = TRUE),
                                    div(class = "tirage-filter-wrap",
                                        uiOutput("tirage_achat_filtre_ui")),
                                    actionButton("tirage_achat_refresh", label = NULL,
                                                 icon = icon("shuffle"), class = "suggestion-btn")
                                )
                            ),
                            uiOutput("tirage_achat_ui")
                        )
                 )
        ),

        # --- Spinner wheel ---
        fluidRow(style = "max-width: 1100px; margin: 0 auto;",
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
      #                                Page 6.1 - User
      # ------------------------------------------------------------------------------



      # ------------------------------------------------------------------------------
      #                               Page 6.2 - User
      # ------------------------------------------------------------------------------



      # ------------------------------------------------------------------------------
      #                                   Page 6.1
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
      ),

      tabItem(
        tabName = "admin",

        # En-tête
        div(class = "admin-page-header",
            h2("Administration", class = "titre-pages"),
            p("Base de données centrale des livres \u2014 accès réservé \u00e0 l'administrateur.",
              class = "admin-page-subtitle")
        ),

        # Carte principale unifiée
        div(class = "admin-main-card",

            # \u2014 Barre d'outils \u2014
            div(class = "admin-toolbar",
                div(class = "admin-toolbar-search",
                    tags$span(class = "admin-search-icon", icon("magnifying-glass")),
                    selectizeInput(
                      "admin_search_livre", NULL,
                      choices = NULL,
                      options = list(
                        placeholder = "Rechercher un livre pour modifier ses infos\u2026",
                        allowEmptyOption = TRUE
                      ),
                      width = "100%"
                    )
                ),
                div(class = "admin-toolbar-sep"),
                div(class = "admin-toolbar-actions",
                    actionButton("admin_add_row",
                                 tagList(icon("plus"),        " Ajouter"),
                                 class = "admin-btn"),
                    actionButton("admin_delete_rows",
                                 tagList(icon("trash"),       " Supprimer"),
                                 class = "admin-btn admin-btn-danger"),
                    actionButton("admin_save",
                                 tagList(icon("floppy-disk"), " Sauvegarder"),
                                 class = "admin-btn admin-btn-primary"),
                    actionButton("admin_download_btn",
                                 tagList(icon("download"), " Télécharger"),
                                 class = "admin-btn")
                )
            ),

            # \u2014 Barre info tableau \u2014
            div(class = "admin-table-bar",
                div(class = "admin-table-bar-left",
                    tags$span(class = "admin-table-bar-icon", icon("database")),
                    "Base de données"
                ),
                div(class = "admin-table-bar-right",
                    tags$span(class = "admin-count-badge",
                              textOutput("admin_nb_total", inline = TRUE), " livres"
                    ),
                    tags$span(class = "admin-hint",
                              icon("pencil"), " Double-cliquez pour modifier"
                    )
                )
            ),

            # \u2014 Tableau \u2014
            div(class = "admin-table-wrap",
                DTOutput("admin_livres_table")
            )
        )
      )
    ),
    absolutePanel(
      id = "chatbot_panel",
      bottom = 20, right = 20, width = 420,
      draggable = TRUE,

      div(class = "chatbot-wrapper",
          # Header
          div(class = "chatbot-header",
              span("💬 Assistant Bibliothèque"),
              actionButton("chatbot_toggle", "−", class = "chatbot-toggle-btn")
          ),

          # Zone messages
          div(id = "chatbot_body",
              uiOutput("chatbot_ui"),
              # Zone de saisie
              div(class = "chatbot-input-row",
                  textInput("chatbot_input", label = NULL, placeholder = "Votre message..."),
                  actionButton("chatbot_send", "➤", class = "chatbot-send-btn")
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

  data$livres = s3_read_xlsx(link_to_livres)


  # ------------------------------------------------------------------------------
  #                               Authentification manuelle
  # ------------------------------------------------------------------------------

  current_user <- reactiveVal(NULL)
  is_logged_in <- reactive(!is.null(current_user()))

  is_admin <- reactive({
    req(current_user())
    val <- credentials$admin[which(credentials$user == current_user())]
    isTRUE(as.logical(val))
  })

  # Forcer l'onglet accueil au demarrage (apres rendu dynamique de la sidebar)
  observe({
    shinyjs::delay(300, updateTabItems(session, "sidebar_tabs", "accueil"))
  }) |> bindEvent(session$clientData$url_protocol, once = TRUE)


  # ------------------------------------------------------------------------------
  #                              Bouton header login
  # ------------------------------------------------------------------------------

  # Bouton "Options" dans le header (filtres bibliothèque)
  output$header_filtres_btn <- renderUI({
    req(is_logged_in())
    tags$div(style = "padding: 10px 8px;",
             actionButton("show_filtres_modal", NULL,
                          icon  = icon("sliders"),
                          class = "btn-header-login",
                          title = "Options d'affichage",
                          style = "padding: 5px 11px;"
             )
    )
  })

  observeEvent(input$show_filtres_modal, {
    req(data$table_library)
    showModal(modalDialog(
      title = tagList(icon("sliders"),
                      tags$span(" Options d'affichage", style = "font-family: var(--font);")),
      div(class = "filtres-modal-body",
          div(class = "filtres-modal-section",
              tags$span(class = "filtres-modal-label", "Afficher"),
              div(class = "filtres-modal-select-wrap",
                  selectInput(inputId = "choix_tous_livres", label = NULL,
                              choices = list("Tous les livres" = 1, "Livres possédés" = 2,
                                             "Livres lus" = 3, "Livres non lus" = 4, "Livres aimés" = 5),
                              selected = if (!is.null(isolate(input$choix_tous_livres)))
                                isolate(input$choix_tous_livres) else 1,
                              multiple = FALSE
                  )
              )
          ),
          tags$hr(style = "border-color: rgba(129,140,248,0.12); margin: 16px 0;"),
          div(class = "filtres-modal-section",
              tags$span(class = "filtres-modal-label", "Genres \u00e0 afficher"),
              uiOutput(outputId = "checkbox_genre_ui")
          )
      ),
      footer = modalButton("Fermer"),
      easyClose = TRUE,
      size = "m"
    ))
  })


  output$header_download_btn <- renderUI({
    req(is_logged_in())
    tags$div(style = "padding: 10px 8px;",
             actionButton("show_download_modal", NULL,
                          icon  = icon("download"),
                          class = "btn-header-login",
                          title = "Télécharger mes données",
                          style = "padding: 5px 11px;"
             )
    )
  })

  observeEvent(input$show_download_modal, {
    req(data$table_library)
    showModal(modalDialog(
      title = tags$div(icon("download"),
                       tags$span(" Télécharger mes données", style = "font-family: var(--font);")),
      tags$p("Exporte ta bibliothèque complète dans le format de ton choix.",
             style = "font-family: var(--font); font-size: 13px; color: var(--text); opacity: 0.6; margin-bottom: 20px;"),
      div(style = "display: flex; gap: 12px; justify-content: center;",
          downloadButton("download_xlsx", ".xlsx \u2014 Excel",  class = "bouton"),
          downloadButton("download_csv",  ".csv \u2014 Universel", class = "btn-header-login")
      ),
      footer = modalButton("Fermer"),
      easyClose = TRUE,
      size = "s"
    ))
  })

  output$download_xlsx <- downloadHandler(
    filename = function() paste0("bibliotheque_", current_user(), "_", Sys.Date(), ".xlsx"),
    content  = function(file) openxlsx::write.xlsx(data$table_library, file)
  )

  output$download_csv <- downloadHandler(
    filename = function() paste0("bibliotheque_", current_user(), "_", Sys.Date(), ".csv"),
    content  = function(file) write.csv(data$table_library, file, row.names = FALSE, fileEncoding = "UTF-8")
  )

  output$header_login_btn <- renderUI({
    if (is_logged_in()) {
      tags$div(style = "display: inline-flex; align-items: center; gap: 10px; padding: 10px 15px;",
               tags$span(icon("user"), current_user(), style = "color: var(--second-color); font-family: var(--font); font-size: 13px;"),
               actionButton("logout_btn", "Déconnexion", class = "btn-header-login", style = "font-size: 12px; padding: 4px 14px;")
      )
    } else {
      tags$div(style = "display: inline-flex; align-items: center; gap: 10px; padding: 10px 15px;",
               actionButton("show_login_modal", "Se connecter", class = "btn-header-login"),
               actionButton("accueil_create_btn", "Créer ma bibliothèque", class = "btn-header-login")
      )
    }
  })


  # ------------------------------------------------------------------------------
  #                              Modal de connexion
  # ------------------------------------------------------------------------------

  observeEvent(input$show_login_modal, {
    showModal(modalDialog(
      title = tags$div(icon("lock"), "Connexion", style = "color: var(--second-color); font-family: var(--font);"),
      textInput("login_user", "Nom d'utilisateur"),
      passwordInput("login_password", "Mot de passe"),
      tags$div(id = "login_error", style = "color: #e74c3c; text-align: center; font-size: 13px; min-height: 20px;"),
      footer = tagList(
        modalButton("Annuler"),
        actionButton("login_submit", "Valider", class = "bouton")
      ),
      easyClose = TRUE,
      size = "s"
    ))
  })

  observeEvent(input$login_submit, {
    if (input$login_user == "exemple_pour_invité") {
      runjs("document.getElementById('login_error').innerText = 'Ce compte est réservé à la démonstration.';")
      return()
    }
    user_row <- which(credentials$user == input$login_user & credentials$password == input$login_password)
    if (length(user_row) == 1) {
      current_user(input$login_user)
      removeModal()
    } else {
      runjs("document.getElementById('login_error').innerText = 'Identifiants incorrects';")
    }
  })

  observeEvent(input$logout_btn, {
    current_user(NULL)
    data$table_library <- NULL
    data$library <- NULL
    updateTabItems(session, "sidebar_tabs", "accueil")
  })

  # Bouton creer bibliotheque — ouvre le modal de creation
  observeEvent(input$accueil_create_btn, {
    showModal(modalDialog(
      title = tags$div(icon("plus-circle"), "Créer ma bibliothèque", style = "color: var(--second-color); font-family: var(--font);"),
      fluidRow(
        column(6,
               textInput("create_user", "Nom d'utilisateur", width = "100%"),
               tags$div(id = "create_user_msg", style = "color: #e74c3c; font-size: 12px; min-height: 18px;",
                        textOutput("create_user_deja_pris")
               )
        ),
        column(6,
               textInput("create_library_name", "Nom de votre bibliothèque", width = "100%")
        )
      ),
      fluidRow(
        column(6,
               passwordInput("create_password", "Mot de passe")
        ),
        column(6,
               passwordInput("confirm_password", "Confirmer le mot de passe"),
               tags$div(style = "color: #e74c3c; font-size: 12px; min-height: 18px;",
                        textOutput("confirm_password_wrong")
               )
        )
      ),
      footer = tagList(
        modalButton("Annuler"),
        uiOutput("button_create_library_ui")
      ),
      easyClose = TRUE,
      size = "m"
    ))
  })


  # ------------------------------------------------------------------------------
  #                              Sidebar dynamique
  # ------------------------------------------------------------------------------

  output$main_sidebar <- renderUI({
    if (is_logged_in()) {
      sidebarMenu(id = "sidebar_tabs",
                  menuItem("Bibliothèque", tabName = "bibliotheque", icon = icon("book"), selected = TRUE),
                  menuItem("Ma collection", icon = icon("layer-group"),
                           menuSubItem("Mes livres",  tabName = "rangement",  icon = icon("list")),
                           menuSubItem("Rechercher",  tabName = "rechercher", icon = icon("magnifying-glass"))
                  ),
                  menuItem("Statistiques", tabName = "stats", icon = icon("chart-bar"),
                           menuSubItem("Vue d'ensemble", tabName = "stat_livres",  icon = icon("calculator")),
                           menuSubItem("Auteurs",        tabName = "stat_auteur",  icon = icon("user")),
                           menuSubItem("Genres",         tabName = "stat_genre",   icon = icon("bookmark")),
                           menuSubItem("Pays",           tabName = "stat_pays",    icon = icon("earth-europe")),
                           menuSubItem("\u00c9poques",   tabName = "stat_siecle",  icon = icon("hourglass-half"))
                  ),
                  menuItem("Mon profil",   tabName = "graph",     icon = icon("circle-user")),
                  menuItem("Bilan annuel", tabName = "bilan",     icon = icon("calendar")),

                  menuItem("Chronologie",  tabName = "timeline",  icon = icon("clock-rotate-left"),
                           menuSubItem("Sorties",  tabName = "timeline_sortie",   icon = icon("book")),
                           menuSubItem("Lectures", tabName = "timeline_lecture",  icon = icon("book-bookmark"))
                  ),
                  menuItem("Mes défis",  tabName = "defis",          icon = icon("trophy")),
                  menuItem("Tirage au sort",  tabName = "spinner_wheel",  icon = icon("shuffle")),
                  if (is_admin()) menuItem("Administration", tabName = "admin", icon = icon("shield-halved"))
      )
    } else {
      # Cacher la sidebar quand non connecte
      shinyjs::hide(selector = ".left-side, .main-sidebar")
      shinyjs::removeCssClass(selector = "body", class = "sidebar-collapse")
      shinyjs::addCssClass(selector = "body", class = "sidebar-collapse")
      sidebarMenu(id = "sidebar_tabs",
                  menuItem("Accueil", tabName = "accueil", icon = icon("home"), selected = TRUE)
      )
    }
  })

  # Reafficher la sidebar apres login
  observeEvent(current_user(), {
    if (is_logged_in()) {
      shinyjs::show(selector = ".left-side, .main-sidebar")
      shinyjs::removeCssClass(selector = "body", class = "sidebar-collapse")
    }
  })


  # ------------------------------------------------------------------------------
  #                         Chargement donnees apres login
  # ------------------------------------------------------------------------------

  observeEvent(current_user(), {
    req(current_user())
    library_name_val <- credentials$library[which(credentials$user == current_user())]
    data$table_library <- s3_read_xlsx(paste0(link_to_data, library_name_val)) %>%
      mutate(Longueur = as.numeric(Longueur), Pages = as.numeric(Pages))

    shinyjs::delay(200, updateTabItems(session, "sidebar_tabs", "bibliotheque"))
  })


  # ------------------------------------------------------------------------------
  #                           Stats demo pour l'accueil
  # ------------------------------------------------------------------------------

  # Chiffres cles
  output$demo_nb_livres <- renderText({ nrow(guest_data) })
  output$demo_nb_lus <- renderText({ sum(guest_data$Lu == "Oui", na.rm = TRUE) })
  output$demo_nb_auteurs <- renderText({ length(unique(guest_data$Auteur)) })
  output$demo_nb_genres <- renderText({ length(unique(guest_data$Genre)) })
  output$demo_nb_pays <- renderText({
    if ("Origine" %in% colnames(guest_data)) length(unique(guest_data$Origine)) else "\u2014"
  })
  output$demo_nb_pages <- renderText({
    format(sum(guest_data$Pages[guest_data$Lu == "Oui"], na.rm = TRUE), big.mark = " ")
  })

  # Fun facts
  output$demo_fact_auteur_top <- renderUI({
    top <- guest_data %>% filter(Lu == "Oui") %>% count(Auteur, sort = TRUE) %>% slice(1)
    h2(paste0(top$Auteur, " (", top$n, ")"), class = "text-stat", style = "font-size: 14px;")
  })
  output$demo_fact_genre_top <- renderUI({
    top <- guest_data %>% filter(Lu == "Oui") %>% count(Genre, sort = TRUE) %>% slice(1)
    h2(paste0(top$Genre, " (", top$n, ")"), class = "text-stat", style = "font-size: 14px;")
  })
  output$demo_fact_favoris <- renderUI({
    nb_fav <- sum(guest_data$Favori == "Oui", na.rm = TRUE)
    h2(paste0(nb_fav, " livres"), class = "text-stat", style = "font-size: 14px;")
  })
  output$demo_fact_plus_vieux <- renderUI({
    row <- guest_data %>% filter(!is.na(Date)) %>% slice_min(Date, n = 1, with_ties = FALSE)
    h2(paste0(row$Titre, " (", row$Date, ")"), class = "text-stat", style = "font-size: 14px;")
  })

  # Carousel demo (20 livres aléatoires, fixés pour la session)
  demo_carousel_livres <- guest_data %>% filter(Lu == "Oui") %>% slice_sample(n = min(20, nrow(.)))
  demo_carousel_index  <- reactiveVal(10)

  output$demo_carousel <- renderUI({
    livres <- demo_carousel_livres
    req(nrow(livres) >= 5)
    pos <- demo_carousel_index()
    pos <- max(4, min(pos, nrow(livres) - 3))

    livre <- livres[pos, ]

    make_small <- function(row, distance) {
      size_class <- switch(as.character(distance), "1" = "book-near", "2" = "book-mid", "book-far")
      div(class = paste("book-small", size_class),
          onclick = sprintf("Shiny.setInputValue('demo_carousel_go', %d, {priority: 'event'})", which(livres$Titre == row$Titre)),
          div(class = "book-small-spine"),
          div(class = "book-small-face",
              div(class = "book-small-title", row$Titre),
              div(class = "book-small-author", row$Auteur),
              div(class = "book-small-date", row$Date)
          )
      )
    }

    left_covers <- tagList()
    for (i in seq(max(1, pos - 3), pos - 1)) {
      left_covers <- tagAppendChild(left_covers, make_small(livres[i, ], pos - i))
    }

    right_covers <- tagList()
    for (i in seq(pos + 1, min(nrow(livres), pos + 3))) {
      right_covers <- tagAppendChild(right_covers, make_small(livres[i, ], i - pos))
    }

    detail_items <- tagList()
    if (!is.na(livre$Genre) && livre$Genre != "")
      detail_items <- tagAppendChild(detail_items, div(class = "book-detail", icon("bookmark"), " ", livre$Genre))
    if (!is.na(livre$Pages) && !is.na(as.numeric(livre$Pages)))
      detail_items <- tagAppendChild(detail_items, div(class = "book-detail", icon("file"), " ", paste(livre$Pages, "pages")))
    if (!is.na(livre$Origine) && livre$Origine != "")
      detail_items <- tagAppendChild(detail_items, div(class = "book-detail", icon("globe"), " ", livre$Origine))

    lu_class <- if (livre$Lu == "Oui") "badge-lu" else if (livre$Lu == "En train de lire") "badge-en-cours" else "badge-non-lu"
    lu_text <- if (livre$Lu == "Oui") "Lu" else if (livre$Lu == "En train de lire") "En cours" else "Non lu"

    main_cover <- div(class = "book-cover",
                      div(class = "book-spine"),
                      div(class = "book-cover-face",
                          div(class = "book-cover-border",
                              if (!is.na(livre$Favori) && livre$Favori == "Oui") div(class = "book-favori", icon("heart")),
                              div(class = "book-title", livre$Titre),
                              tags$hr(class = "book-separator"),
                              div(class = "book-author", livre$Auteur),
                              div(class = "book-date", livre$Date),
                              br(),
                              div(class = "book-details", detail_items),
                              br(),
                              div(class = paste("book-badge", lu_class), lu_text)
                          )
                      )
    )

    div(class = "carousel-wrapper",
        div(class = "carousel-container",
            div(class = "carousel-side", left_covers),
            main_cover,
            div(class = "carousel-side", right_covers)
        )
    )
  })

  observeEvent(input$demo_carousel_go, {
    demo_carousel_index(input$demo_carousel_go)
  })

  # Carte demo (meme style que onglet Graphiques)
  output$demo_carte <- renderLeaflet({
    data$carte = guest_data %>%
      group_by(Origine) %>%
      summarize(n = n())

    data$data_map = left_join(world_map, data$carte, by = c("french_shor" = "Origine")) %>%
      mutate(n = ifelse(is.na(n), 0, n)) %>%
      rename("Pays" = "french_shor", "Nombre de livres" = "n")

    tmap_mode("view")
    tm = tm_shape(data$data_map) +
      tm_borders() +
      tm_crs("auto") +
      tm_polygons("Nombre de livres",
                  fill.scale = tm_scale_continuous(values = colorRampPalette(c("white", second_color))(100))) +
      tm_layout(legend.show = FALSE, frame = FALSE)

    tmap_leaflet(tm)
  })

  # Radar genres demo
  output$demo_radar <- renderPlotly({
    genre_counts <- guest_data %>%
      group_by(Genre) %>%
      summarise(
        total = n(),
        lus = sum(Lu == "Oui")
      ) %>%
      mutate(
        pourcentage = round(lus / total * 100, 1)
      ) %>%
      arrange(desc(pourcentage)) %>%
      head(10)
    fig <- plot_ly(type = "scatterpolar", mode = "markers+lines",
                   r = c(genre_counts$pourcentage, genre_counts$pourcentage[1]),
                   theta = c(genre_counts$Genre, genre_counts$Genre[1]),
                   fill = "toself", fillcolor = "rgba(129,140,248,0.12)",
                   line = list(color = second_color, width = 2),
                   marker = list(color = second_color, size = 5)
    ) %>% layout(
      polar = list(bgcolor = "transparent",
                   radialaxis = list(visible = TRUE, color = "grey40", gridcolor = "grey25", linecolor = "transparent", ticksuffix = " %", tickfont = list(color = "white", size = 10)),
                   angularaxis = list(color = "white", gridcolor = "grey25", linecolor = "grey25", tickfont = list(color = "white", size = 11))
      ),
      paper_bgcolor = "transparent", plot_bgcolor = "transparent", showlegend = FALSE,
      margin = list(l = 60, r = 60, t = 20, b = 20)
    )
    fig$x$config$displayModeBar <- FALSE
    fig
  })

  # Livres par annee demo
  output$demo_livres_annee <- renderPlotly({
    livres_annee <- guest_data %>%
      filter(Lu == "Oui", !is.na(Fini)) %>%
      mutate(annee = year(dmy(Fini))) %>% filter(!is.na(annee)) %>%
      count(annee) %>% rename("Annee" = annee, "Livres" = n)
    fig <- plot_ly(livres_annee, x = ~Annee, y = ~Livres, type = "bar",
                   marker = list(color = ~Livres, colorscale = list(c(0, "#3730a3"), c(1, "#c084fc")),
                                 line = list(color = "rgba(129,140,248,0.35)", width = 1))
    ) %>% layout(
      paper_bgcolor = "transparent", plot_bgcolor = "transparent",
      xaxis = list(color = "white", gridcolor = "grey25", tickfont = list(color = "white"), dtick = 1, title = ""),
      yaxis = list(color = "white", gridcolor = "grey25", tickfont = list(color = "white"), title = ""),
      margin = list(l = 50, r = 20, t = 10, b = 40)
    )
    fig$x$config$displayModeBar <- FALSE
    fig
  })

  # Top genres demo (meme style que onglet Statistiques > Sur les genres)
  output$demo_top_genres <- renderPlot(bg = "transparent", {
    demo_genres <- mutate(
      inner_join(
        summarize(group_by(guest_data, Genre), nb_livres = n()),
        summarize(group_by(guest_data, Genre), nb_lus = sum(na.omit(Lu) == "Oui")),
        by = "Genre"
      ),
      pourc = round(nb_lus / nb_livres * 100, 2)
    )
    ggplot(demo_genres, aes(x = factor(Genre, levels = sort(unique(guest_data$Genre), decreasing = TRUE)), y = pourc)) +
      geom_col(aes(y = 100), fill = "grey20", alpha = 0.07, width = 0.6) +
      geom_col(aes(fill = pourc), alpha = 0.85, width = 0.6) +
      scale_fill_gradient(low = "#3730a3", high = "#c084fc", guide = "none") +
      coord_flip() +
      labs(x = "") +
      scale_y_continuous(limits = c(0, 110)) +
      theme_void() +
      theme(plot.background = element_rect(fill = "transparent", color = NA),
            panel.background = element_rect(fill = "transparent", color = NA),
            panel.grid.major.x = element_line(color = "grey25", linewidth = 0.2, linetype = "solid"),
            axis.text.y = element_text(color = "white", size = 12, family = "sans", margin = margin(r = 8)),
            plot.margin = margin(15, 25, 15, 10)) +
      geom_label(label = paste0(format(demo_genres$nb_lus, big.mark = " ", digits = 1, scientific = FALSE), " (", demo_genres$pourc, " %)"),
                 color = "white", fill = "transparent", label.size = 0,
                 position = position_stack(vjust = 0.5), fontface = "bold", family = "sans")
  })


  # ------------------------------------------------------------------------------
  #                                    Page 1
  # ------------------------------------------------------------------------------

  library_name = reactive({
    req(current_user())
    credentials$library[which(credentials$user == current_user())]
  })


  link_to_library = reactive(paste0(link_to_data, library_name()))

  # Maintenir data$library filtré selon les contrôles de l'onglet bibliothèque
  observe({
    req(data$table_library)
    genres_sel   <- if (!is.null(input$checkbox_genre))    input$checkbox_genre    else sort(unique(data$table_library$Genre))
    choix_livres <- if (!is.null(input$choix_tous_livres)) input$choix_tous_livres else 1

    df <- filter(data$table_library, Genre %in% genres_sel) %>%
      mutate(Longueur = as.numeric(Longueur), Pages = as.numeric(Pages))

    data$library <- if (choix_livres == 2) filter(df, Bibliothèque == "Oui") else
      if (choix_livres == 3) filter(df, Lu == "Oui") else
        if (choix_livres == 4) filter(df, Lu == "Non") else
          if (choix_livres == 5) filter(df, Favori == "Oui") else df
  })


  output$checkbox_genre_ui <- renderUI ({
    checkboxGroupInput(inputId = "checkbox_genre", label = NULL, choices = sort(unique(data$table_library$Genre)), selected = sort(unique(data$table_library$Genre)), inline = TRUE)
  })


  # ------------------------------------------------------------------------------
  #                    Onglet bibliothèque — livres en cours
  # ------------------------------------------------------------------------------

  output$biblio_en_cours_ui <- renderUI({
    req(data$table_library)
    en_cours <- data$table_library %>% filter(Lu == "En train de lire")

    if (nrow(en_cours) == 0) {
      div(class = "encours-vide", icon("book"), " Aucun livre en cours de lecture")
    } else {
      tagList(lapply(seq_len(nrow(en_cours)), function(i) {
        livre   <- en_cours[i, ]
        isbn_id <- gsub("[^a-zA-Z0-9]", "_", livre$ISBN)

        jours <- tryCatch(
          as.numeric(difftime(Sys.Date(), as.Date(livre$Commencé, "%d-%m-%Y"), units = "days")),
          error = function(e) NA
        )
        pages_info <- if (!is.na(livre$Pages)) paste0(livre$Pages, " p.") else ""
        jours_info <- if (!is.na(jours) && jours >= 0) paste0("Jour ", jours) else ""
        detail     <- paste(c(pages_info, jours_info)[c(pages_info, jours_info) != ""], collapse = " · ")

        div(class = "encours-livre",
            div(class = "encours-livre-inner",
                div(class = "encours-barre"),
                div(class = "encours-contenu",
                    div(class = "encours-titre", livre$Titre),
                    div(class = "encours-auteur", livre$Auteur),
                    if (detail != "") div(class = "encours-detail", detail)
                ),
                div(class = "encours-btn-zone",
                    tags$button(
                      class   = "action-button bouton encours-lu-btn",
                      onclick = sprintf(
                        "Shiny.setInputValue('biblio_isbn_a_marquer', '%s', {priority: 'event'})",
                        livre$ISBN
                      ),
                      icon("check"), " J'ai lu"
                    )
                )
            )
        )
      }))
    }
  })

  # --- Bienvenue ---
  output$biblio_bienvenue_ui <- renderUI({
    req(current_user())
    heure    <- as.integer(format(Sys.time(), "%H"))
    salut    <- if (heure >= 5 && heure < 12) "Bonjour"
    else if (heure >= 12 && heure < 18) "Bon après-midi"
    else "Bonsoir"
    initiale <- toupper(substr(current_user(), 1, 1))
    div(class = "biblio-bienvenue",
        div(class = "biblio-greeting-row",
            div(class = "biblio-greeting-avatar", initiale),
            div(class = "biblio-greeting-text",
                div(class = "biblio-greeting-salut",
                    tags$span(paste0(salut, ",\u00a0"), class = "biblio-greeting-pre"),
                    tags$span(paste0(current_user(), "\u00a0!"), class = "biblio-greeting-name")
                )
            )
        )
    )
  })

  output$biblio_recents_ui <- renderUI({
    req(data$table_library)
    lus <- data$table_library %>%
      filter(Lu == "Oui", !is.na(Fini), Fini != "") %>%
      mutate(date_fini = suppressWarnings(as.Date(Fini, "%d-%m-%Y"))) %>%
      filter(!is.na(date_fini)) %>%
      arrange(desc(date_fini))

    if (nrow(lus) == 0) {
      div(class = "biblio-recents-vide",
          icon("book-open"), " Aucune lecture terminée pour l'instant")
    } else {
      div(class = "biblio-recents-scroll",
          tagList(lapply(seq_len(nrow(lus)), function(i) {
            livre <- lus[i, ]
            jours <- as.numeric(Sys.Date() - livre$date_fini)
            quand <- if      (jours == 0)  "Aujourd'hui"
            else if (jours == 1)  "Hier"
            else if (jours < 7)   paste0("Il y a ", jours, "\u00a0j")
            else if (jours < 14)  "Il y a 1\u00a0sem"
            else if (jours < 31)  paste0("Il y a ", floor(jours / 7), "\u00a0sem")
            else if (jours < 60)  "Il y a 1\u00a0mois"
            else                  paste0("Il y a ", floor(jours / 30), "\u00a0mois")
            div(class = "biblio-recent-item",
                div(class = "biblio-recent-dot"),
                div(class = "biblio-recent-info",
                    div(class = "biblio-recent-titre", livre$Titre),
                    div(class = "biblio-recent-auteur", livre$Auteur)
                ),
                div(class = "biblio-recent-quand", quand)
            )
          })))
    }
  })

  output$biblio_nb_lus <- renderText({
    req(data$table_library)
    format(sum(data$table_library$Lu == "Oui", na.rm = TRUE), big.mark = "\u00a0")
  })

  output$biblio_nb_a_lire <- renderText({
    req(data$table_library)
    format(sum(data$table_library$Lu == "Non", na.rm = TRUE), big.mark = "\u00a0")
  })

  output$biblio_nb_en_cours <- renderText({
    req(data$table_library)
    format(sum(data$table_library$Lu == "En train de lire", na.rm = TRUE), big.mark = "\u00a0")
  })

  output$biblio_nb_favoris <- renderText({
    req(data$table_library)
    format(sum(data$table_library$Favori == "Oui", na.rm = TRUE), big.mark = "\u00a0")
  })

  # Marquer un livre comme lu — étape 1 : ouvrir le modal avec la date
  biblio_isbn_courant <- reactiveVal(NULL)

  observeEvent(input$biblio_isbn_a_marquer, {
    isbn  <- input$biblio_isbn_a_marquer
    idx   <- which(data$table_library$ISBN == isbn)
    titre <- data$table_library$Titre[idx]
    biblio_isbn_courant(isbn)

    showModal(modalDialog(
      title = tags$div(icon("check-circle"), " J'ai lu",
                       style = "color: var(--second-color); font-family: var(--font);"),
      size  = "s",
      div(style = "margin-bottom: 14px; font-family: var(--font); color: var(--text);",
          tags$b(titre)
      ),
      dateInput(
        inputId   = "modal_date_fin_lu",
        label     = "Date de fin de lecture",
        value     = Sys.Date(),
        max       = Sys.Date(),
        format    = "dd/mm/yyyy",
        language  = "fr",
        weekstart = 1
      ),
      footer = tagList(
        modalButton("Annuler"),
        actionButton("modal_confirmer_lu", "Confirmer", icon = icon("check"), class = "bouton")
      ),
      easyClose = TRUE
    ))
  }, ignoreInit = TRUE)

  # Marquer un livre comme lu — étape 2 : confirmer et sauvegarder
  observeEvent(input$modal_confirmer_lu, {
    isbn <- biblio_isbn_courant()
    req(isbn)

    date_fin_val <- input$modal_date_fin_lu
    date_fin_str <- if (!is.null(date_fin_val)) {
      format(date_fin_val, "%d-%m-%Y")
    } else {
      format(Sys.Date(), "%d-%m-%Y")
    }

    idx   <- which(data$table_library$ISBN == isbn)
    titre <- data$table_library$Titre[idx]
    data$table_library$Lu[idx]   <- "Oui"
    data$table_library$Fini[idx] <- date_fin_str

    wb_library <- createWorkbook()
    addWorksheet(wb_library, "library")
    writeData(wb_library, "library", data$table_library, colNames = TRUE)
    s3_write_xlsx(wb_library, link_to_library())

    biblio_isbn_courant(NULL)
    removeModal()
    showModal(modalDialog(
      title = HTML("<b>Confirmation</b>"),
      HTML(paste0("\u00ab", titre, "\u00bb marqué comme lu le ", date_fin_str, "\u00a0!")),
      footer = modalButton("Fermer", icon = icon("close")),
      easyClose = TRUE
    ))
  }, ignoreInit = TRUE)


  # ------------------------------------------------------------------------------
  #              Onglet bibliothèque — modales Ajouter / Modifier
  # ------------------------------------------------------------------------------

  observeEvent(input$btn_ajouter_livre, {
    showModal(modalDialog(
      title = tags$div(icon("plus-circle"), " Ajouter un livre",
                       style = "color: var(--second-color); font-family: var(--font);"),
      size = "l",
      div(class = "verif-isbn-zone",
          textInput(inputId = "input_verif_livre_bibliotheque", label = "Entrer l'ISBN du livre"),
          div(class = "verif-result",
              textOutput(outputId = "output_verif_livre_bibliotheque")
          )
      ),
      uiOutput(outputId = "ajout_bibliotheque"),
      footer = modalButton("Fermer")
    ))
  })

  observeEvent(input$btn_modifier_livre, {
    showModal(modalDialog(
      title = tags$div(icon("pen"), " Modifier un livre",
                       style = "color: var(--second-color); font-family: var(--font);"),
      size = "l",
      uiOutput(outputId = "choix_isbn_modif"),
      uiOutput(outputId = "modif_info_livre"),
      footer = modalButton("Fermer")
    ))
  })


  # ------------------------------------------------------------------------------
  #              Onglet bibliothèque — modal Supprimer un livre
  # ------------------------------------------------------------------------------

  observeEvent(input$btn_supprimer_livre, {
    showModal(modalDialog(
      title = tags$div(icon("trash"), " Supprimer un livre",
                       style = "color: #e74c3c; font-family: var(--font);"),
      size = "m",
      uiOutput("supprimer_livre_ui"),
      footer = tagList(
        modalButton("Annuler"),
        uiOutput("btn_confirmer_suppression_ui")
      )
    ))
  })

  output$supprimer_livre_ui <- renderUI({
    req(data$table_library)
    choix <- setNames(
      arrange(mutate(data$table_library, ch = paste(Titre, Auteur, sep = " — ")), ch)$ISBN,
      arrange(mutate(data$table_library, ch = paste(Titre, Auteur, sep = " — ")), ch)$ch
    )
    selectizeInput(
      inputId  = "supprimer_livre_isbn",
      label    = "Choisir le livre à supprimer",
      choices  = choix,
      selected = "",
      options  = list(placeholder = "Choisir un livre...")
    )
  })

  output$btn_confirmer_suppression_ui <- renderUI({
    req(input$supprimer_livre_isbn, input$supprimer_livre_isbn != "")
    titre <- data$table_library$Titre[data$table_library$ISBN == input$supprimer_livre_isbn][1]
    actionButton(
      "confirmer_suppression",
      paste0("Supprimer définitivement"),
      icon  = icon("trash"),
      class = "bouton",
      style = "background-color: #c0392b; border-color: #c0392b;"
    )
  })

  observeEvent(input$confirmer_suppression, {
    req(input$supprimer_livre_isbn, input$supprimer_livre_isbn != "")
    isbn  <- input$supprimer_livre_isbn
    titre <- data$table_library$Titre[data$table_library$ISBN == isbn][1]

    data$table_library <- data$table_library %>% filter(ISBN != isbn)

    wb_library <- createWorkbook()
    addWorksheet(wb_library, "library")
    writeData(wb_library, "library", data$table_library, colNames = TRUE)
    s3_write_xlsx(wb_library, link_to_library())

    removeModal()
    showModal(modalDialog(
      title = HTML("<b>Confirmation</b>"),
      HTML(paste0("\"", titre, "\" a été supprimé de la bibliothèque.")),
      footer = modalButton("Fermer", icon = icon("close")),
      easyClose = TRUE
    ))
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
      data_library_tri = arrange(data$library, Auteur)
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
  #                                Page 2.2
  # ------------------------------------------------------------------------------

  output$recherche_livre_ui <- renderUI({
    req(data$table_library)
    choix <- setNames(
      arrange(mutate(data$table_library, choix = paste(Titre, Auteur, sep = " - ")), choix)$ISBN,
      arrange(mutate(data$table_library, choix = paste(Titre, Auteur, sep = " - ")), choix)$choix
    )
    selectizeInput(
      inputId = "recherche_livre",
      label = "Choisir un livre",
      choices = c(choix),
      selected = "",
      width = "100%",
      options = list(placeholder = "Rechercher un livre...")
    )
  })


  observeEvent(input$carousel_click, {
    updateSelectizeInput(session, "recherche_livre", selected = input$carousel_click)
  })

  observeEvent(input$carousel_nav, {
    req(input$recherche_livre, input$recherche_livre != "")

    livre <- data$table_library %>% filter(ISBN == input$recherche_livre)
    req(nrow(livre) > 0)
    livre <- livre[1, ]

    tri_mode <- input$carousel_tri
    if (is.null(tri_mode)) tri_mode <- "genre"

    sort_by_lastname <- function(df) {
      df[order(
        sapply(strsplit(as.character(df$Auteur), " "), function(x) x[1]),
        df$Date
      ), ]
    }

    if (tri_mode == "genre") {
      livres_tries <- data$table_library %>% filter(Genre == livre$Genre) %>% arrange(Date)
    } else if (tri_mode == "date") {
      livres_tries <- data$table_library %>% arrange(Date)
    } else if (tri_mode == "titre") {
      livres_tries <- data$table_library %>% arrange(Titre)
    } else {
      livres_tries <- sort_by_lastname(data$table_library)
    }

    pos <- which(livres_tries$ISBN == livre$ISBN)
    if (length(pos) == 0) return()
    pos <- pos[1]

    dir <- input$carousel_nav$dir
    new_pos <- if (dir == "next") min(pos + 1, nrow(livres_tries)) else max(pos - 1, 1)
    if (new_pos != pos) {
      updateSelectizeInput(session, "recherche_livre", selected = livres_tries$ISBN[new_pos])
    }
  })

  output$carousel_livres <- renderUI({
    req(input$recherche_livre, input$recherche_livre != "")

    livre <- data$table_library %>% filter(ISBN == input$recherche_livre)
    req(nrow(livre) > 0)
    livre <- livre[1, ]

    tri_mode <- input$carousel_tri
    if (is.null(tri_mode)) tri_mode <- "genre"

    # Build ordered book list based on sort mode (format: Nom Prénom)
    sort_by_lastname <- function(df) {
      df[order(
        sapply(strsplit(as.character(df$Auteur), " "), function(x) x[1]),
        df$Date
      ), ]
    }

    if (tri_mode == "genre") {
      livres_tries <- data$table_library %>% filter(Genre == livre$Genre) %>% arrange(Date)
    } else if (tri_mode == "date") {
      livres_tries <- data$table_library %>% arrange(Date)
    } else if (tri_mode == "titre") {
      livres_tries <- data$table_library %>% arrange(Titre)
    } else {
      livres_tries <- sort_by_lastname(data$table_library)
    }

    pos <- which(livres_tries$ISBN == livre$ISBN)
    if (length(pos) == 0) return(NULL)
    pos <- pos[1]

    # Helper: build a clickable small neighbor cover with size class
    make_small_cover <- function(row, distance) {
      size_class <- switch(as.character(distance), "1" = "book-near", "2" = "book-mid", "book-far")
      div(class = paste("book-small", size_class),
          onclick = sprintf("Shiny.setInputValue('carousel_click', '%s', {priority: 'event'})", row$ISBN),
          div(class = "book-small-spine"),
          div(class = "book-small-face",
              div(class = "book-small-title", row$Titre),
              div(class = "book-small-author", row$Auteur),
              div(class = "book-small-date", row$Date)
          )
      )
    }

    # Left neighbors (up to 3, farthest first)
    left_covers <- tagList()
    left_indices <- (pos - 3):(pos - 1)
    left_indices <- left_indices[left_indices >= 1]
    for (i in left_indices) {
      left_covers <- tagAppendChild(left_covers, make_small_cover(livres_tries[i, ], pos - i))
    }

    # Right neighbors (up to 3, closest first)
    right_covers <- tagList()
    right_indices <- (pos + 1):(pos + 3)
    right_indices <- right_indices[right_indices <= nrow(livres_tries)]
    for (i in right_indices) {
      right_covers <- tagAppendChild(right_covers, make_small_cover(livres_tries[i, ], i - pos))
    }

    # Main cover details
    detail_items <- tagList()
    if (!is.na(livre$Genre) && livre$Genre != "")
      detail_items <- tagAppendChild(detail_items, div(class = "book-detail", icon("bookmark"), " ", livre$Genre))
    if (!is.na(livre$Edition) && livre$Edition != "")
      detail_items <- tagAppendChild(detail_items, div(class = "book-detail", icon("building"), " ", livre$Edition))
    if (!is.na(livre$Pages) && !is.na(as.numeric(livre$Pages)))
      detail_items <- tagAppendChild(detail_items, div(class = "book-detail", icon("file"), " ", paste(livre$Pages, "pages")))
    if (!is.na(livre$Origine) && livre$Origine != "")
      detail_items <- tagAppendChild(detail_items, div(class = "book-detail", icon("globe"), " ", livre$Origine))
    if (!is.na(livre$Ecriture) && livre$Ecriture != "")
      detail_items <- tagAppendChild(detail_items, div(class = "book-detail", icon("language"), " ", livre$Ecriture))

    lu_class <- switch(as.character(livre$Lu),
                       "Oui" = "badge-lu",
                       "En train de lire" = "badge-en-cours",
                       "badge-non-lu"
    )
    lu_text <- switch(as.character(livre$Lu),
                      "Oui" = "Lu",
                      "En train de lire" = "En cours",
                      "Non lu"
    )

    main_cover <- div(class = "book-cover",
                      div(class = "book-spine"),
                      div(class = "book-cover-face",
                          div(class = "book-cover-border",
                              if (livre$Favori == "Oui") div(class = "book-favori", icon("heart")),
                              div(class = "book-title", livre$Titre),
                              tags$hr(class = "book-separator"),
                              div(class = "book-author", livre$Auteur),
                              div(class = "book-date", livre$Date),
                              br(),
                              div(class = "book-details", detail_items),
                              br(),
                              div(class = paste("book-badge", lu_class), lu_text)
                          )
                      )
    )

    div(class = "carousel-wrapper",
        div(class = "carousel-container",
            div(class = "carousel-side", left_covers),
            main_cover,
            div(class = "carousel-side", right_covers)
        )
    )
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
      tm_polygons("Nombre de livres",
                  fill.scale = tm_scale_continuous(values = colorRampPalette(c("white", second_color))(100))) +
      tm_layout(legend.show = FALSE, frame = FALSE)

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
                                        geom_area(fill = second_color, alpha = 0.08) +
                                        geom_line(color = second_color, linewidth = 0.8) +
                                        geom_point(color = second_color, size = 1.5, alpha = 0.7) +
                                        theme(plot.background = element_rect(fill = "transparent", color = NA),
                                              panel.background = element_rect(fill = "transparent", color = NA),
                                              panel.grid.major = element_line(color = "grey25", linewidth = 0.2),
                                              panel.grid.minor = element_blank(),
                                              panel.border = element_blank(),
                                              axis.title = element_text(color = "white", size = 10),
                                              axis.text = element_text(color = "white")) +
                                        labs(title = "", x = "", y = "Livres lus"))

    graph_livres_plot_mois <- style(graph_livres_plot_mois, hoverinfo = "skip", traces = 1)
    graph_livres_plot_mois$x$config$displayModeBar <- FALSE

    graph_livres_plot_mois


  })


  output$violin_plot_pages <- renderPlotly({
    violin_plot_pages = layout(ggplotly(ggplot(data$library, aes(x = "", y = Pages)) +
                                          geom_violin(fill = second_color, color = second_color, alpha = 0.3) +
                                          stat_summary(fun = median, geom = "point", shape = 18, size = 3, color = "white", alpha = 0.85) +
                                          theme(panel.background = element_rect(fill = "transparent", color = NA),
                                                plot.background = element_rect(fill = "transparent", color = NA),
                                                panel.border = element_blank(),
                                                axis.text = element_text(color = "white"),
                                                panel.grid.major.y = element_line(color = "grey25", linewidth = 0.2),
                                                panel.grid.major.x = element_blank(),
                                                panel.grid.minor = element_blank(),
                                                axis.ticks.y = element_line(color = "grey40"),
                                                axis.ticks.x = element_blank(),
                                                axis.title.y = element_blank(),
                                                axis.title.x = element_blank())),
                               yaxis = list(title = list(text = "Nombre de pages", font = list(color = "white"))))

    violin_plot_pages$x$config$displayModeBar <- FALSE

    violin_plot_pages

  })


  output$violin_plot_duree <- renderPlotly({

    data$violin_plot_duree = mutate(data$library, Durée = as.numeric(ifelse(!is.na(Fini), as.numeric(difftime(as.Date(Fini, format = "%d-%m-%Y"), as.Date(Commencé, format = "%d-%m-%Y"), unit = "days")), ""))) %>%
      filter(Lu %in% c("Oui"))

    violin_plot_duree = layout(ggplotly(ggplot(data$violin_plot_duree, aes(x = "", y = Durée)) +
                                          geom_violin(fill = second_color, color = second_color, alpha = 0.3) +
                                          stat_summary(fun = median, geom = "point", shape = 18, size = 3, color = "white", alpha = 0.85) +
                                          theme(panel.background = element_rect(fill = "transparent", color = NA),
                                                plot.background = element_rect(fill = "transparent", color = NA),
                                                panel.border = element_blank(),
                                                axis.title.y = element_blank(),
                                                axis.title.x = element_blank(),
                                                axis.text = element_text(color = "white"),
                                                panel.grid.major.y = element_line(color = "grey25", linewidth = 0.2),
                                                panel.grid.major.x = element_blank(),
                                                panel.grid.minor = element_blank(),
                                                axis.ticks.y = element_line(color = "grey40"),
                                                axis.ticks.x = element_blank())),
                               yaxis = list(side = "right", title = list(text = "Durée de lecture (jours)", font = list(color = "white"), angle = 90)))

    violin_plot_duree$x$config$displayModeBar <- FALSE

    violin_plot_duree

  })


  # ------------------------------------------------------------------------------
  #                                 Bilan annuel
  # ------------------------------------------------------------------------------

  output$bilan_annee_ui <- renderUI({
    req(data$table_library)
    annees <- data$table_library %>%
      filter(Lu == "Oui", !is.na(Fini), Fini != "") %>%
      mutate(annee = suppressWarnings(format(as.Date(Fini, "%d-%m-%Y"), "%Y"))) %>%
      filter(!is.na(annee)) %>%
      pull(annee) %>% unique() %>% sort(decreasing = TRUE)
    if (length(annees) == 0)
      return(p("Aucune lecture terminée.", style = "color: var(--text); font-family: var(--font); opacity: 0.5;"))
    div(class = "stat-sub-controls", style = "display: inline-block;",
        selectInput("bilan_annee_sel", label = NULL, choices = annees, selected = annees[1], width = "140px")
    )
  })

  bilan_data <- reactive({
    req(data$table_library, input$bilan_annee_sel)
    data$table_library %>%
      filter(Lu == "Oui", !is.na(Fini), Fini != "") %>%
      mutate(
        date_fini  = suppressWarnings(as.Date(Fini, "%d-%m-%Y")),
        date_debut = suppressWarnings(as.Date(`Commencé`, "%d-%m-%Y"))
      ) %>%
      filter(!is.na(date_fini), format(date_fini, "%Y") == input$bilan_annee_sel) %>%
      mutate(duree = as.numeric(date_fini - date_debut))
  })

  output$bilan_nb_lus <- renderUI({
    req(bilan_data())
    h2(nrow(bilan_data()), class = "text-stat")
  })

  output$bilan_nb_pages <- renderUI({
    req(bilan_data())
    h2(format(sum(bilan_data()$Pages, na.rm = TRUE), big.mark = "\u00a0"), class = "text-stat")
  })

  output$bilan_meilleur_mois <- renderUI({
    req(bilan_data())
    mois_fr <- c("Jan","Fév","Mar","Avr","Mai","Juin","Juil","Ao\u00fb","Sep","Oct","Nov","Déc")
    d <- bilan_data() %>%
      mutate(mois = as.integer(format(date_fini, "%m"))) %>%
      count(mois) %>% arrange(desc(n)) %>% slice(1)
    val <- if (nrow(d) == 0) "\u2014" else mois_fr[d$mois[1]]
    h2(val, class = "text-stat")
  })

  output$bilan_duree_moy <- renderUI({
    req(bilan_data())
    df <- bilan_data() %>% filter(!is.na(duree), duree >= 0)
    val <- if (nrow(df) == 0) "\u2014" else paste0(round(mean(df$duree)), "\u00a0j")
    h2(val, class = "text-stat")
  })

  output$bilan_plot_mois <- renderPlotly({
    req(bilan_data())
    mois_fr <- c("Jan","Fév","Mar","Avr","Mai","Juin","Juil","Ao\u00fb","Sep","Oct","Nov","Déc")
    df <- bilan_data() %>%
      mutate(mois = as.integer(format(date_fini, "%m"))) %>%
      count(mois) %>%
      right_join(data.frame(mois = 1:12), by = "mois") %>%
      mutate(
        n          = ifelse(is.na(n), 0L, n),
        mois_label = factor(mois_fr[mois], levels = mois_fr),
        tooltip    = paste0(mois_fr[mois], "\u00a0: ", n, " livre", ifelse(n > 1, "s", ""))
      )
    p <- ggplot(df, aes(x = mois_label, y = n, text = tooltip)) +
      geom_col(fill = second_color, alpha = 0.7, width = 0.6) +
      theme(
        panel.background   = element_rect(fill = "transparent", color = NA),
        plot.background    = element_rect(fill = "transparent", color = NA),
        panel.border       = element_blank(),
        axis.text          = element_text(color = "white", size = 9),
        panel.grid.major.y = element_line(color = "grey25", linewidth = 0.2),
        panel.grid.major.x = element_blank(),
        panel.grid.minor   = element_blank(),
        axis.ticks         = element_blank(),
        axis.title         = element_blank()
      )
    pl <- ggplotly(p, tooltip = "text") %>%
      layout(paper_bgcolor = "transparent", plot_bgcolor = "transparent",
             font = list(color = "white"))
    pl$x$config$displayModeBar <- FALSE
    pl
  })

  output$bilan_genre_fav <- renderUI({
    req(bilan_data())
    d <- bilan_data() %>% count(Genre, sort = TRUE) %>% slice(1)
    val <- if (nrow(d) == 0 || is.na(d$Genre[1])) "\u2014" else d$Genre[1]
    h2(val, class = "text-stat", style = "font-size: 11px;")
  })

  output$bilan_auteur_fav <- renderUI({
    req(bilan_data())
    d <- bilan_data() %>% count(Auteur, sort = TRUE) %>% slice(1)
    val <- if (nrow(d) == 0 || is.na(d$Auteur[1])) "\u2014" else d$Auteur[1]
    h2(val, class = "text-stat", style = "font-size: 11px;")
  })

  output$bilan_plus_long <- renderUI({
    req(bilan_data())
    df <- bilan_data() %>% filter(!is.na(Pages)) %>% arrange(desc(Pages)) %>% slice(1)
    if (nrow(df) == 0) return(h2("\u2014", class = "text-stat"))
    tagList(
      h2(paste0(df$Pages[1], "\u00a0p."), class = "text-stat"),
      div(class = "fun-fact-compare", df$Titre[1])
    )
  })

  output$bilan_plus_rapide <- renderUI({
    req(bilan_data())
    df <- bilan_data() %>% filter(!is.na(duree), duree >= 0) %>% arrange(duree) %>% slice(1)
    if (nrow(df) == 0) return(h2("\u2014", class = "text-stat"))
    tagList(
      h2(paste0(df$duree[1], "\u00a0j"), class = "text-stat"),
      div(class = "fun-fact-compare", df$Titre[1])
    )
  })

  output$bilan_premier_livre <- renderUI({
    req(bilan_data())
    df <- bilan_data() %>% arrange(date_fini) %>% slice(1)
    if (nrow(df) == 0) return(p("\u2014"))
    div(class = "biblio-recent-item",
        div(class = "biblio-recent-dot"),
        div(class = "biblio-recent-info",
            div(class = "biblio-recent-titre", df$Titre[1]),
            div(class = "biblio-recent-auteur", df$Auteur[1])
        ),
        div(class = "biblio-recent-quand", format(df$date_fini[1], "%d %b"))
    )
  })

  output$bilan_dernier_livre <- renderUI({
    req(bilan_data())
    df <- bilan_data() %>% arrange(desc(date_fini)) %>% slice(1)
    if (nrow(df) == 0) return(p("\u2014"))
    div(class = "biblio-recent-item",
        div(class = "biblio-recent-dot"),
        div(class = "biblio-recent-info",
            div(class = "biblio-recent-titre", df$Titre[1]),
            div(class = "biblio-recent-auteur", df$Auteur[1])
        ),
        div(class = "biblio-recent-quand", format(df$date_fini[1], "%d %b"))
    )
  })


  # ------------------------------------------------------------------------------
  #                                    Activité
  # ------------------------------------------------------------------------------

  act_data <- reactive({
    req(data$table_library)
    data$table_library %>%
      filter(Lu == "Oui", !is.na(Fini), Fini != "") %>%
      mutate(date_fini = suppressWarnings(as.Date(Fini, "%d-%m-%Y"))) %>%
      filter(!is.na(date_fini)) %>%
      mutate(
        annee = as.integer(format(date_fini, "%Y")),
        mois  = as.integer(format(date_fini, "%m"))
      ) %>%
      count(annee, mois)
  })

  output$act_heatmap <- renderPlotly({
    req(act_data())
    mois_fr <- c("Jan","Fév","Mar","Avr","Mai","Juin","Juil","Ao\u00fb","Sep","Oct","Nov","Déc")
    annees  <- sort(unique(act_data()$annee), decreasing = TRUE)

    grid <- expand.grid(annee = annees, mois = 1:12) %>%
      left_join(act_data(), by = c("annee","mois")) %>%
      mutate(n = ifelse(is.na(n), 0L, n))

    mat <- matrix(0L, nrow = length(annees), ncol = 12)
    tip <- matrix("", nrow = length(annees), ncol = 12)
    for (r in seq_along(annees)) {
      for (c in 1:12) {
        v <- grid$n[grid$annee == annees[r] & grid$mois == c]
        mat[r, c] <- if (length(v)) v else 0L
        tip[r, c] <- paste0(mois_fr[c], " ", annees[r], "\u00a0: ",
                            mat[r, c], " livre", if (mat[r, c] > 1) "s" else "")
      }
    }

    plot_ly(
      z         = mat,
      x         = mois_fr,
      y         = as.character(annees),
      type      = "heatmap",
      colorscale = list(list(0, "rgba(129,140,248,0.07)"), list(1, second_color)),
      hovertext = tip,
      hoverinfo = "text",
      showscale = FALSE,
      xgap = 3, ygap = 3
    ) %>%
      layout(
        paper_bgcolor = "transparent",
        plot_bgcolor  = "transparent",
        font  = list(color = "white"),
        xaxis = list(title = "", tickfont = list(color = "white", size = 10), side = "top",
                     showgrid = FALSE, zeroline = FALSE),
        yaxis = list(title = "", tickfont = list(color = "white", size = 10),
                     showgrid = FALSE, zeroline = FALSE)
      ) %>%
      config(displayModeBar = FALSE)
  })


  # ------------------------------------------------------------------------------
  #                                   Page 4.1
  # ------------------------------------------------------------------------------

  output$timeline_vis_sortie = renderTimevis({
    timevis(get_timeline_books(data$library, "Sortie"),
            options = list(start = format(Sys.Date() - years(300), "%Y-%m-%d"),
                           end   = format(Sys.Date(), "%Y-%m-%d"),
                           verticalScroll = TRUE,
                           horizontalScroll = TRUE
            ),
            height = "500px"
    )
  })


  # ------------------------------------------------------------------------------
  #                                   Page 4.2
  # ------------------------------------------------------------------------------

  output$timeline_vis_lecture = renderTimevis({
    timevis(get_timeline_books(data$library, "Lecture"),
            options = list(start = format(Sys.Date() - months(1), "%Y-%m-%d"),
                           end   = format(Sys.Date(), "%Y-%m-%d"),
                           verticalScroll = TRUE,
                           horizontalScroll = TRUE
            ),
            height = "500px"
    )
  })


  # ------------------------------------------------------------------------------
  #                                    Page 5.1
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

    paste0(format(nrow(data$nb_livres_aimes), big.mark = " ", scientific = FALSE), " (", round(nrow(data$nb_livres_aimes)/nrow(data$library[data$library$Lu == "Oui",])*100,2), " %)")
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

    paste0(format(nrow(data$nb_livres_a_soi), big.mark = " ", scientific = FALSE), " (", round(nrow(data$nb_livres_a_soi)/nrow(data$library)*100,2), " %)")
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
    top_pays <- data$library %>% filter(Lu == "Oui") %>% count(Origine, sort = TRUE) %>% head(1)
    total_lus <- nrow(data$library %>% filter(Lu == "Oui"))
    pourc <- round(top_pays$n[1] / total_lus * 100, 0)
    div(class = "fun-fact-value",
        paste0(top_pays$Origine[1]),
        br(), tags$span(class = "fun-fact-compare", paste0(top_pays$n[1], " livres — ", pourc, " % de vos lectures"))
    )
  })

  output$pays_origine_fav <- renderText({

    data$pays_origine_fav = data$library %>%
      group_by(across(all_of("Origine"))) %>%
      summarize(nb_pays_origine_fav=n())

    paste(data$pays_origine_fav$Origine[which(data$pays_origine_fav$nb_pays_origine_fav == max(data$pays_origine_fav$nb_pays_origine_fav))], collapse = ", ")
  })


  output$langue_ecriture_fav_ui <- renderUI({
    top_langue <- data$library %>% filter(Lu == "Oui") %>% count(Ecriture, sort = TRUE) %>% head(1)
    total_lus <- nrow(data$library %>% filter(Lu == "Oui"))
    pourc <- round(top_langue$n[1] / total_lus * 100, 0)
    div(class = "fun-fact-value",
        paste0(top_langue$Ecriture[1]),
        br(), tags$span(class = "fun-fact-compare", paste0(top_langue$n[1], " livres — ", pourc, " % de vos lectures"))
    )
  })

  output$langue_ecriture_fav <- renderText({

    data$langue_ecriture_fav = data$library %>%
      group_by(across(all_of("Ecriture"))) %>%
      summarize(nb_langue_ecriture_fav=n())

    paste(data$langue_ecriture_fav$Ecriture[which(data$langue_ecriture_fav$nb_langue_ecriture_fav == max(data$langue_ecriture_fav$nb_langue_ecriture_fav))], collapse = ", ")
  })


  output$progress_livres_ui <- renderUI({
    nb_total <- nrow(data$library)
    nb_lus <- nrow(filter(data$library, Lu == "Oui"))
    pct <- round(nb_lus / nb_total * 100, 2)

    div(class = "progress-section",
        h3("Taux de livres lus", class = "progress-title"),
        div(class = "progress-bar-outer",
            div(class = "progress-bar-fill", style = paste0("width: ", pct, "%;"),
                span(class = "progress-bar-text", paste0(format(nb_lus, big.mark = " "), " / ", format(nb_total, big.mark = " "), " (", pct, " %)"))
            )
        )
    )
  })

  output$progress_pages_ui <- renderUI({
    nb_total <- sum(na.omit(data$library$Pages))
    nb_lues <- sum(na.omit(filter(data$library, Lu == "Oui")$Pages))
    pct <- round(nb_lues / nb_total * 100, 2)

    div(class = "progress-section",
        h3("Taux de pages lues", class = "progress-title"),
        div(class = "progress-bar-outer",
            div(class = "progress-bar-fill", style = paste0("width: ", pct, "%;"),
                span(class = "progress-bar-text", paste0(format(nb_lues, big.mark = " "), " / ", format(nb_total, big.mark = " "), " (", pct, " %)"))
            )
        )
    )
  })


  # ------------------------------------------------------------------------------
  #                                    Page 5.2
  # ------------------------------------------------------------------------------

  output$ui_choix_auteur <- renderUI({
    if (auteur_default %in% data$library$Auteur) {
      selectInput(inputId = "choix_auteur", label = "Sélectionner un auteur", width = "100%", choices = unique(data$library$Auteur[order(data$library$Auteur)]), selected = auteur_default)
    } else {
      selectInput(inputId = "choix_auteur", label = "Sélectionner un auteur", width = "100%", choices = unique(data$library$Auteur[order(data$library$Auteur)]), selected = NULL)
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

    datatable(data$table_stat_auteurs, class = "table-auteur", options = list(scrollY = "220px", paging = FALSE, fixedHeader = TRUE, fixedColumns = list(leftColumns = 1), info = FALSE, ordering = FALSE, searching = FALSE, pageLenght = -1, columnDefs = list(list(targets = "_all", className = "dt-center")), lengthMenu = list(c(-1, 10,25,50,100), c("Tout", "10", "25", "50", "100"))), rownames = FALSE)
  })


  output$plot_livres_auteurs <- renderPlot(bg = "transparent", {
    data$plot_livres_auteurs = mutate(inner_join(summarize(group_by(data$library, Auteur), nb_livres=n()), summarize(group_by(data$library, Auteur), nb_livres_lus=sum(na.omit(Lu)=="Oui")), by = "Auteur"), pourc=round(nb_livres_lus/nb_livres*100,2))
    top10 = head(data$plot_livres_auteurs[order(data$plot_livres_auteurs$nb_livres_lus, decreasing = TRUE),], 10)

    ggplot(top10, aes(x=reorder(Auteur, nb_livres_lus), y=pourc)) +
      geom_col(aes(y = 100), fill = "grey20", alpha = 0.07, width = 0.6) +
      geom_col(aes(fill = pourc), alpha = 0.85, width = 0.6) +
      scale_fill_gradient(low = "#3730a3", high = "#c084fc", guide = "none") +
      coord_flip() +
      labs(x = "") +
      scale_y_continuous(limits = c(0, 110)) +
      theme_void() +
      theme(plot.background = element_rect(fill = "transparent", color = NA),
            panel.background = element_rect(fill = "transparent", color = NA),
            panel.grid.major.x = element_line(color = "grey25", linewidth = 0.2, linetype = "solid"),
            axis.text.y = element_text(color = "white", size = 12, family = "sans", margin = margin(r = 8)),
            plot.margin = margin(15, 25, 15, 10)) +
      geom_label(label = paste0(top10$nb_livres_lus, " (", top10$pourc, " %)"), color = "white", fill = "transparent", label.size = 0, position = position_stack(vjust = 0.5), fontface = "bold", size = 3.5, family = "sans")
  })


  output$plot_pages_auteurs <- renderPlot(bg = "transparent", {
    data$plot_pages_auteurs = mutate(inner_join(summarize(group_by(data$library, Auteur), nb_pages=sum(Pages)), summarize(group_by(data$library, Auteur), nb_pages_lues=sum(Pages[Lu=="Oui"], na.rm = TRUE)), by = "Auteur"), pourc=round(nb_pages_lues/nb_pages*100,2))
    top10 = head(data$plot_pages_auteurs[order(data$plot_pages_auteurs$nb_pages_lues, decreasing = TRUE),], 10)

    ggplot(top10, aes(x=reorder(Auteur, nb_pages_lues), y=pourc)) +
      geom_col(aes(y = 100), fill = "grey20", alpha = 0.07, width = 0.6) +
      geom_col(aes(fill = pourc), alpha = 0.85, width = 0.6) +
      scale_fill_gradient(low = "#3730a3", high = "#c084fc", guide = "none") +
      coord_flip() +
      labs(x = "") +
      scale_y_continuous(limits = c(0, 110)) +
      theme_void() +
      theme(plot.background = element_rect(fill = "transparent", color = NA),
            panel.background = element_rect(fill = "transparent", color = NA),
            panel.grid.major.x = element_line(color = "grey25", linewidth = 0.2, linetype = "solid"),
            axis.text.y = element_text(color = "white", size = 12, family = "sans", margin = margin(r = 8)),
            plot.margin = margin(15, 25, 15, 10)) +
      geom_label(label = paste0(format(top10$nb_pages_lues, big.mark = " ", scientific = FALSE), " (", top10$pourc, " %)"), color = "white", fill = "transparent", label.size = 0, position = position_stack(vjust = 0.5), fontface = "bold", size = 3.5, family = "sans")
  })


  # ------------------------------------------------------------------------------
  #                                    Page 5.3
  # ------------------------------------------------------------------------------

  output$ui_choix_genre <- renderUI({
    if (genre_default %in% data$library$Genre) {
      selectInput(inputId = "choix_genre", label = "Sélectionner un genre", width = "100%", choices = sort(unique(data$library$Genre)), selected = genre_default)
    } else {
      selectInput(inputId = "choix_genre", label = "Sélectionner un genre", width = "100%", choices = sort(unique(data$library$Genre)), selected = NULL)
    }
  })


  output$nb_livres_genres <- renderText({
    req(data$library)
    data$nb_livres_genres = nrow(filter(data$library, Genre %in% input$choix_genre))

    paste0(format(data$nb_livres_genres, big.mark = " ", scientific = FALSE), " (", round(data$nb_livres_genres/nrow(data$library)*100,2), " %)")
  })


  output$nb_livres_lus_genres <- renderText({
    req(data$library)
    data$nb_livres_lus_genres = nrow(filter(data$library, Genre %in% input$choix_genre, Lu == "Oui"))

    paste0(format(data$nb_livres_lus_genres, big.mark = " ", scientific = FALSE), " (", round(data$nb_livres_lus_genres/data$nb_livres_genres*100,2), " %)")
  })


  output$nb_pages_genres <- renderText({
    req(data$library)
    data$nb_pages_genres=sum(filter(data$library, Genre %in% input$choix_genre)$Pages)

    paste0(format(data$nb_pages_genres, big.mark = " ", scientific = FALSE), " (", round(data$nb_pages_genres/sum(data$library$Pages)*100,2), " %)")
  })


  output$nb_pages_lues_genres <- renderText({
    req(data$library)
    data$nb_pages_lues_genres=sum(filter(data$library, Genre %in% input$choix_genre, Lu == "Oui")$Pages)

    paste0(format(data$nb_pages_lues_genres, big.mark = " ", scientific = FALSE), " (", round(data$nb_pages_lues_genres/data$nb_pages_genres*100,2), " %)")
  })


  output$table_stat_genres <- renderDT({
    req(data$library, input$choix_genre)

    data$table_stat_genres = data$library %>%
      filter(Genre %in% input$choix_genre) %>%
      select("Titre", "Auteur", "Date") %>%
      arrange(Date)

    datatable(data$table_stat_genres, class = "table-genre", options = list(scrollY = "220px", paging = FALSE, info = FALSE, fixedHeader = TRUE, fixedColumns = list(leftColumns = 1), ordering = FALSE, searching = FALSE, columnDefs = list(list(targets = "_all", className = "dt-center")), pageLenght = -1, lengthMenu = list(c(-1, 10,25,50,100), c("Tout", "10", "25", "50", "100"))), rownames = FALSE)
  })


  output$plot_livres_genres <- renderPlot(bg = "transparent", {
    req(data$library)
    data$plot_livres_genres = mutate(inner_join(summarize(group_by(data$library, Genre), nb_livres=n()), summarize(group_by(data$library, Genre), nb_lus=sum(na.omit(Lu)=="Oui")), by = "Genre"), pourc=round(nb_lus/nb_livres*100,2))

    ggplot(data$plot_livres_genres, aes(x=factor(Genre, levels = sort(unique(data$library$Genre), decreasing = TRUE)), y=pourc)) +
      geom_col(aes(y = 100), fill = "grey20", alpha = 0.07, width = 0.6) +
      geom_col(aes(fill = pourc), alpha = 0.85, width = 0.6) +
      scale_fill_gradient(low = "#3730a3", high = "#c084fc", guide = "none") +
      coord_flip() +
      labs(x = "") +
      scale_y_continuous(limits = c(0, 110)) +
      theme_void() +
      theme(plot.background = element_rect(fill = "transparent", color = NA),
            panel.background = element_rect(fill = "transparent", color = NA),
            panel.grid.major.x = element_line(color = "grey25", linewidth = 0.2, linetype = "solid"),
            axis.text.y = element_text(color = "white", size = 12, family = "sans", margin = margin(r = 8)),
            plot.margin = margin(15, 25, 15, 10)) +
      geom_label(label = paste0(format(data$plot_livres_genres$nb_lus, big.mark=" ", digits = 1, scientific=FALSE), " (", data$plot_livres_genres$pourc, " %)"), color = "white", fill = "transparent", label.size = 0, position = position_stack(vjust=0.5), fontface = "bold", family = "sans")
  })


  output$plot_pages_genres <- renderPlot(bg = "transparent", {
    req(data$library)
    data$plot_pages_genres = mutate(inner_join(summarize(group_by(data$library, Genre), nb_pages=sum(Pages)), summarize(group_by(data$library, Genre), nb_pages_lues=sum(Pages[Lu=="Oui"], na.rm = TRUE)), by = "Genre"), pourc=round(nb_pages_lues/nb_pages*100,2))

    ggplot(data$plot_pages_genres, aes(x=factor(Genre, levels = sort(unique(data$library$Genre), decreasing = TRUE)), y=pourc)) +
      geom_col(aes(y = 100), fill = "grey20", alpha = 0.07, width = 0.6) +
      geom_col(aes(fill = pourc), alpha = 0.85, width = 0.6) +
      scale_fill_gradient(low = "#3730a3", high = "#c084fc", guide = "none") +
      coord_flip() +
      labs(x = "") +
      scale_y_continuous(limits = c(0, 110)) +
      theme_void() +
      theme(plot.background = element_rect(fill = "transparent", color = NA),
            panel.background = element_rect(fill = "transparent", color = NA),
            panel.grid.major.x = element_line(color = "grey25", linewidth = 0.2, linetype = "solid"),
            axis.text.y = element_text(color = "white", size = 12, family = "sans", margin = margin(r = 8)),
            plot.margin = margin(15, 25, 15, 10)) +
      geom_label(label = paste0(format(data$plot_pages_genres$nb_pages_lues, digits = 1, big.mark=" ", scientific=FALSE), " (", data$plot_pages_genres$pourc, " %)"), color = "white", fill = "transparent", label.size = 0, position = position_stack(vjust=0.5), fontface = "bold", family = "sans")

  })


  # ------------------------------------------------------------------------------
  #                                    Page 5.4
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

    datatable(data$table_stat_pays, class = "table-pays", options = list(scrollY = "220px", paging = FALSE, info = FALSE, ordering = FALSE, fixedHeader = TRUE, fixedColumns = list(leftColumns = 1), searching = FALSE, pageLenght = -1, columnDefs = list(list(targets = "_all", className = "dt-center")), lengthMenu = list(c(-1, 10,25,50,100), c("Tout", "10", "25", "50", "100"))), rownames = FALSE)
  })


  output$plot_livres_pays <- renderPlot(bg = "transparent", {

    data$plot_livres_pays = mutate(inner_join(summarize(group_by(data$library, Origine), nb_livres=n()), summarize(group_by(data$library, Origine), nb_livres_lus=sum(na.omit(Lu)=="Oui")), by = "Origine"), pourc=round(nb_livres_lus/nb_livres*100,2))

    top10_pays = head(data$plot_livres_pays[order(data$plot_livres_pays$nb_livres_lus, decreasing = TRUE),],10)
    ggplot(top10_pays, aes(x=reorder(Origine, nb_livres_lus), y=pourc)) +
      geom_col(aes(y = 100), fill = "grey20", alpha = 0.07, width = 0.6) +
      geom_col(aes(fill = pourc), alpha = 0.85, width = 0.6) +
      scale_fill_gradient(low = "#3730a3", high = "#c084fc", guide = "none") +
      coord_flip() +
      labs(x = "") +
      scale_y_continuous(limits = c(0, 110)) +
      theme_void() +
      theme(plot.background = element_rect(fill = "transparent", color = NA),
            panel.background = element_rect(fill = "transparent", color = NA),
            panel.grid.major.x = element_line(color = "grey25", linewidth = 0.2, linetype = "solid"),
            axis.text.y = element_text(color = "white", size = 12, family = "sans", margin = margin(r = 8)),
            plot.margin = margin(15, 25, 15, 10)) +
      geom_label(label = paste0(format(top10_pays$nb_livres_lus, big.mark=" ", digits = 1, scientific=FALSE), " (", top10_pays$pourc, " %)"), color = "white", fill = "transparent", label.size = 0, position = position_stack(vjust=0.5), fontface = "bold", family = "sans")

  })


  output$plot_pages_pays <- renderPlot(bg = "transparent", {

    data$plot_pages_pays = mutate(inner_join(summarize(group_by(data$library, Origine), nb_pages=sum(Pages)), summarize(group_by(data$library, Origine), nb_pages_lues=sum(Pages[Lu=="Oui"], na.rm = TRUE)), by = "Origine"), pourc=round(nb_pages_lues/nb_pages*100,2))

    top10_pays_p = head(data$plot_pages_pays[order(data$plot_pages_pays$nb_pages_lues, decreasing = TRUE),],10)
    ggplot(top10_pays_p, aes(x=reorder(Origine, nb_pages_lues), y=pourc)) +
      geom_col(aes(y = 100), fill = "grey20", alpha = 0.07, width = 0.6) +
      geom_col(aes(fill = pourc), alpha = 0.85, width = 0.6) +
      scale_fill_gradient(low = "#3730a3", high = "#c084fc", guide = "none") +
      coord_flip() +
      labs(x = "") +
      scale_y_continuous(limits = c(0, 110)) +
      theme_void() +
      theme(plot.background = element_rect(fill = "transparent", color = NA),
            panel.background = element_rect(fill = "transparent", color = NA),
            panel.grid.major.x = element_line(color = "grey25", linewidth = 0.2, linetype = "solid"),
            axis.text.y = element_text(color = "white", size = 12, family = "sans", margin = margin(r = 8)),
            plot.margin = margin(15, 25, 15, 10)) +
      geom_label(label = paste0(format(top10_pays_p$nb_pages_lues, big.mark=" ", digits = 1, scientific=FALSE), " (", top10_pays_p$pourc, " %)"), color = "white", fill = "transparent", label.size = 0, position = position_stack(vjust=0.5), fontface = "bold", family = "sans")
  })


  # ------------------------------------------------------------------------------
  #                                    Page 5.5
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

    datatable(data$table_stat_siecle, class = "table-siecle", options = list(scrollX = TRUE, scrollY = "220px", paging = FALSE, fixedHeader = TRUE, fixedColumns = list(leftColumns = 1), ordering = FALSE, info = FALSE, searching = FALSE, pageLenght = -1, columnDefs = list(list(targets = "_all", className = "dt-center")), lengthMenu = list(c(-1, 10,25,50,100), c("Tout", "10", "25", "50", "100"))), rownames = FALSE)
  })


  output$plot_livres_siecles <- renderPlot(bg = "transparent", {

    data$plot_livres_siecles = mutate(inner_join(summarize(group_by(data$library_siecle, Siècle), nb_livres=n()), summarize(group_by(data$library_siecle, Siècle), nb_livres_lus=sum(na.omit(Lu)=="Oui")), by = "Siècle"), pourc=round(nb_livres_lus/nb_livres*100,2))

    top10_siecles = head(data$plot_livres_siecles[order(data$plot_livres_siecles$nb_livres_lus, decreasing = TRUE),],10)
    ggplot(top10_siecles, aes(x=reorder(Siècle, nb_livres_lus), y=pourc)) +
      geom_col(aes(y = 100), fill = "grey20", alpha = 0.07, width = 0.6) +
      geom_col(aes(fill = pourc), alpha = 0.85, width = 0.6) +
      scale_fill_gradient(low = "#3730a3", high = "#c084fc", guide = "none") +
      coord_flip() +
      labs(x = "") +
      scale_y_continuous(limits = c(0, 110)) +
      theme_void() +
      theme(plot.background = element_rect(fill = "transparent", color = NA),
            panel.background = element_rect(fill = "transparent", color = NA),
            panel.grid.major.x = element_line(color = "grey25", linewidth = 0.2, linetype = "solid"),
            axis.text.y = element_text(color = "white", size = 12, family = "sans", margin = margin(r = 8)),
            plot.margin = margin(15, 25, 15, 10)) +
      geom_label(label = paste0(format(top10_siecles$nb_livres_lus, big.mark=" ", digits = 1, scientific=FALSE), " (", top10_siecles$pourc, " %)"), color = "white", fill = "transparent", label.size = 0, position = position_stack(vjust=0.5), fontface = "bold", family = "sans")

  })


  output$plot_pages_siecles <- renderPlot(bg = "transparent", {

    data$plot_pages_siecles = mutate(inner_join(summarize(group_by(data$library_siecle, Siècle), nb_pages=sum(Pages)), summarize(group_by(data$library_siecle, Siècle), nb_pages_lues=sum(Pages[Lu=="Oui"], na.rm = TRUE)), by = "Siècle"), pourc=round(nb_pages_lues/nb_pages*100,2))

    top10_siecles_p = head(data$plot_pages_siecles[order(data$plot_pages_siecles$nb_pages_lues, decreasing = TRUE),],10)
    ggplot(top10_siecles_p, aes(x=reorder(Siècle, nb_pages_lues), y=pourc)) +
      geom_col(aes(y = 100), fill = "grey20", alpha = 0.07, width = 0.6) +
      geom_col(aes(fill = pourc), alpha = 0.85, width = 0.6) +
      scale_fill_gradient(low = "#3730a3", high = "#c084fc", guide = "none") +
      coord_flip() +
      labs(x = "") +
      scale_y_continuous(limits = c(0, 110)) +
      theme_void() +
      theme(plot.background = element_rect(fill = "transparent", color = NA),
            panel.background = element_rect(fill = "transparent", color = NA),
            panel.grid.major.x = element_line(color = "grey25", linewidth = 0.2, linetype = "solid"),
            axis.text.y = element_text(color = "white", size = 12, family = "sans", margin = margin(r = 8)),
            plot.margin = margin(15, 25, 15, 10)) +
      geom_label(label = paste0(format(top10_siecles_p$nb_pages_lues, big.mark=" ", digits = 1, scientific=FALSE), " (", top10_siecles_p$pourc, " %)"), color = "white", fill = "transparent", label.size = 0, position = position_stack(vjust=0.5), fontface = "bold", family = "sans")

  })


  # ------------------------------------------------------------------------------
  #                                Page Profil Lecteur
  # ------------------------------------------------------------------------------

  # Radar des genres
  output$profil_radar_genres <- renderPlotly({
    livres_lus <- data$library %>% filter(Lu == "Oui")
    genre_counts <- livres_lus %>%
      count(Genre, sort = TRUE) %>%
      head(10) %>%
      mutate(pourcentage = round(n / sum(n) * 100, 1))

    fig <- plot_ly(
      type = "scatterpolar", mode = "markers+lines",
      r = c(genre_counts$pourcentage, genre_counts$pourcentage[1]),
      theta = c(genre_counts$Genre, genre_counts$Genre[1]),
      fill = "toself",
      fillcolor = "rgba(129,140,248,0.12)",
      line = list(color = second_color, width = 2),
      marker = list(color = second_color, size = 5),
      text = c(paste0(genre_counts$Genre, " : ", genre_counts$pourcentage, " %"), paste0(genre_counts$Genre[1], " : ", genre_counts$pourcentage[1], " %")),
      hovertemplate = "Genre : %{theta}<br>Pourcentage : %{r} %<extra></extra>"
    ) %>%
      layout(
        polar = list(
          bgcolor = "transparent",
          radialaxis = list(visible = TRUE, color = "grey40", gridcolor = "grey25", linecolor = "transparent", ticksuffix = " %", tickfont = list(color = "white", size = 10)),
          angularaxis = list(color = "white", gridcolor = "grey25", linecolor = "grey25", tickfont = list(color = "white", size = 11))
        ),
        paper_bgcolor = "transparent",
        plot_bgcolor = "transparent",
        showlegend = FALSE,
        margin = list(l = 60, r = 60, t = 20, b = 20)
      )
    fig$x$config$displayModeBar <- FALSE
    fig
  })

  # Copies pour le tab "graph" (IDs distincts pour éviter les doublons DOM)
  output$graph_radar_genres <- renderPlotly({
    livres_lus <- data$library %>% filter(Lu == "Oui")
    genre_counts <- livres_lus %>%
      count(Genre, sort = TRUE) %>%
      head(10) %>%
      mutate(pourcentage = round(n / sum(n) * 100, 1))

    fig <- plot_ly(
      type = "scatterpolar", mode = "markers+lines",
      r = c(genre_counts$pourcentage, genre_counts$pourcentage[1]),
      theta = c(genre_counts$Genre, genre_counts$Genre[1]),
      fill = "toself",
      fillcolor = "rgba(129,140,248,0.12)",
      line = list(color = second_color, width = 2),
      marker = list(color = second_color, size = 5),
      hovertemplate = "Genre : %{theta}<br>Pourcentage : %{r} %<extra></extra>"
    ) %>%
      layout(
        polar = list(
          bgcolor = "transparent",
          radialaxis = list(visible = TRUE, color = "grey40", gridcolor = "grey25", linecolor = "transparent", ticksuffix = " %", tickfont = list(color = "white", size = 10)),
          angularaxis = list(color = "white", gridcolor = "grey25", linecolor = "grey25", tickfont = list(color = "white", size = 11))
        ),
        paper_bgcolor = "transparent",
        plot_bgcolor = "transparent",
        showlegend = FALSE,
        margin = list(l = 60, r = 60, t = 20, b = 20)
      )
    fig$x$config$displayModeBar <- FALSE
    fig
  })

  # Livres lus par année
  output$profil_livres_annee <- renderPlotly({
    livres_lus <- data$library %>%
      filter(Lu == "Oui", !is.na(Fini)) %>%
      mutate(annee = year(dmy(Fini))) %>%
      filter(!is.na(annee)) %>%
      count(annee) %>%
      rename("Année" = annee, "Livres" = n)

    fig <- plot_ly(livres_lus, x = ~Année, y = ~Livres, type = "bar",
                   marker = list(
                     color = ~Livres,
                     colorscale = list(c(0, "#3730a3"), c(1, "#c084fc")),
                     line = list(color = "rgba(129,140,248,0.35)", width = 1)
                   ),
                   hovertemplate = "%{x} : %{y} livres<extra></extra>"
    ) %>%
      layout(
        paper_bgcolor = "transparent",
        plot_bgcolor = "transparent",
        xaxis = list(color = "white", gridcolor = "grey25", tickfont = list(color = "white"), dtick = 1, title = list(text = "")),
        yaxis = list(color = "white", gridcolor = "grey25", tickfont = list(color = "white"), title = list(text = "", font = list(color = "white"))),
        margin = list(l = 50, r = 20, t = 10, b = 40)
      )
    fig$x$config$displayModeBar <- FALSE
    fig
  })

  output$graph_livres_annee <- renderPlotly({
    livres_lus <- data$library %>%
      filter(Lu == "Oui", !is.na(Fini)) %>%
      mutate(annee = year(dmy(Fini))) %>%
      filter(!is.na(annee)) %>%
      count(annee) %>%
      rename("Année" = annee, "Livres" = n)

    fig <- plot_ly(livres_lus, x = ~Année, y = ~Livres, type = "bar",
                   marker = list(
                     color = ~Livres,
                     colorscale = list(c(0, "#3730a3"), c(1, "#c084fc")),
                     line = list(color = "rgba(129,140,248,0.35)", width = 1)
                   ),
                   hovertemplate = "%{x} : %{y} livres<extra></extra>"
    ) %>%
      layout(
        paper_bgcolor = "transparent",
        plot_bgcolor = "transparent",
        xaxis = list(color = "white", gridcolor = "grey25", tickfont = list(color = "white"), dtick = 1, title = list(text = "")),
        yaxis = list(color = "white", gridcolor = "grey25", tickfont = list(color = "white"), title = list(text = "", font = list(color = "white"))),
        margin = list(l = 50, r = 20, t = 10, b = 40)
      )
    fig$x$config$displayModeBar <- FALSE
    fig
  })

  # En cours de lecture
  output$profil_en_cours <- renderUI({
    en_cours <- data$library %>% filter(Lu == "En train de lire")
    if (nrow(en_cours) == 0) {
      div(class = "encours-vide", icon("book"), "Aucun livre en cours")
    } else {
      tagList(lapply(seq_len(nrow(en_cours)), function(i) {
        livre <- en_cours[i, ]
        jours <- if (!is.na(livre$Commencé) && livre$Commencé != "") {
          as.numeric(difftime(Sys.Date(), as.Date(livre$Commencé, "%d-%m-%Y"), units = "days"))
        } else { NA }
        pages_info <- if (!is.na(livre$Pages)) paste0(livre$Pages, " pages") else ""
        jours_info <- if (!is.na(jours) && jours >= 0) paste0("Jour ", jours) else ""
        detail <- paste(c(pages_info, jours_info)[c(pages_info, jours_info) != ""], collapse = "  ·  ")

        div(class = "encours-livre",
            div(class = "encours-livre-inner",
                div(class = "encours-barre"),
                div(class = "encours-contenu",
                    div(class = "encours-titre", livre$Titre),
                    div(class = "encours-auteur", livre$Auteur),
                    if (detail != "") div(class = "encours-detail", detail)
                )
            )
        )
      }))
    }
  })

  # Records personnels
  output$record_plus_gros <- renderUI({
    livre <- data$library %>% filter(Lu == "Oui") %>% slice_max(Pages, n = 1, with_ties = FALSE)
    div(class = "fun-fact-value", paste0(livre$Titre[1]), br(), tags$span(class = "fun-fact-compare", paste0(livre$Pages[1], " pages")))
  })

  output$record_plus_vieux <- renderUI({
    livre <- data$library %>% filter(Lu == "Oui", !is.na(Date)) %>% slice_min(Date, n = 1, with_ties = FALSE)
    div(class = "fun-fact-value", paste0(livre$Titre[1]), br(), tags$span(class = "fun-fact-compare", paste0(livre$Auteur[1], " (", livre$Date[1], ")")))
  })

  output$record_auteur_top <- renderUI({
    top_auteur <- data$library %>% filter(Lu == "Oui") %>% count(Auteur, sort = TRUE) %>% head(1)
    total_lus <- nrow(data$library %>% filter(Lu == "Oui"))
    pourc <- round(top_auteur$n[1] / total_lus * 100, 0)
    div(class = "fun-fact-value",
        paste0(top_auteur$Auteur[1]),
        br(), tags$span(class = "fun-fact-compare", paste0(top_auteur$n[1], " livres — ", pourc, " % de vos lectures"))
    )
  })


  # ------------------------------------------------------------------------------
  #                              Page Le Saviez-Vous ?
  # ------------------------------------------------------------------------------

  # Hauteur des pages empilées
  output$fact_hauteur_pages <- renderUI({
    pages_lues <- sum(data$library %>% filter(Lu == "Oui") %>% pull(Pages), na.rm = TRUE)
    hauteur_m <- round(pages_lues * 0.0001, 1)
    etages <- round(hauteur_m / 3, 0)
    div(class = "fun-fact-value",
        paste0(format(hauteur_m, big.mark = " "), " m"),
        br(), tags$span(class = "fun-fact-compare", paste0("soit un immeuble de ", etages, " étages"))
    )
  })

  # Temps passé à lire (estimation : ~1 page/min)
  output$fact_temps_lecture <- renderUI({
    pages_lues <- sum(data$library %>% filter(Lu == "Oui") %>% pull(Pages), na.rm = TRUE)
    heures <- round(pages_lues / 60, 0)
    jours <- round(heures / 24, 1)
    div(class = "fun-fact-value",
        paste0(format(heures, big.mark = " "), " heures"),
        br(), tags$span(class = "fun-fact-compare", paste0("soit ", jours, " jours non-stop"))
    )
  })

  # Distance bout à bout (page A5 ~ 21cm)
  output$fact_distance_pages <- renderUI({
    pages_lues <- sum(data$library %>% filter(Lu == "Oui") %>% pull(Pages), na.rm = TRUE)
    km <- round(pages_lues * 0.21 / 1000, 1)
    div(class = "fun-fact-value",
        paste0(format(km, big.mark = " "), " km"),
        br(), tags$span(class = "fun-fact-compare",
                        if (km < 1) "quelques pas"
                        else if (km < 42.2) paste0("soit ", round(km / 42.2 * 100), " % d'un marathon")
                        else paste0("soit ", round(km / 42.2, 1), " marathon(s)")
        )
    )
  })

  # Pays explorés
  output$fact_pays <- renderUI({
    nb_pays <- n_distinct(data$library$Origine, na.rm = TRUE)
    div(class = "fun-fact-value",
        paste0(nb_pays, " pays"),
        br(), tags$span(class = "fun-fact-compare", paste0("sur 195 (", round(nb_pays / 195 * 100), " %)"))
    )
  })

  # Écart temporel
  output$fact_anciennete <- renderUI({
    dates <- data$library$Date[!is.na(data$library$Date)]
    ecart <- max(dates) - min(dates)
    div(class = "fun-fact-value",
        paste0(format(ecart, big.mark = " "), " ans"),
        br(), tags$span(class = "fun-fact-compare", paste0("de ", min(dates), " à ", max(dates)))
    )
  })

  # Rythme de lecture
  output$fact_regularite <- renderUI({
    livres_lus <- data$library %>%
      filter(Lu == "Oui", !is.na(Fini), Fini != "") %>%
      mutate(date_fin = dmy(Fini)) %>%
      filter(!is.na(date_fin))
    if (nrow(livres_lus) > 1) {
      nb_mois <- as.numeric(difftime(max(livres_lus$date_fin), min(livres_lus$date_fin), units = "days")) / 30.44
      par_mois <- round(nrow(livres_lus) / max(nb_mois, 1), 1)
      par_an <- round(par_mois * 12, 0)
      div(class = "fun-fact-value",
          paste0(par_mois, " livres/mois"),
          br(), tags$span(class = "fun-fact-compare", paste0("soit ~", par_an, " par an"))
      )
    } else {
      div(class = "fun-fact-value", "—")
    }
  })

  # Auteurs découverts
  output$fact_genre_prefere <- renderUI({
    top_genre <- data$library %>% filter(Lu == "Oui") %>% count(Genre, sort = TRUE) %>% head(1)
    total_lus <- nrow(data$library %>% filter(Lu == "Oui"))
    pourc <- round(top_genre$n[1] / total_lus * 100, 0)
    div(class = "fun-fact-value",
        paste0(top_genre$Genre[1]),
        br(), tags$span(class = "fun-fact-compare", paste0(top_genre$n[1], " livres — ", pourc, " % de vos lectures"))
    )
  })

  # Mots lus (estimation ~250 mots/page)
  output$fact_mots <- renderUI({
    pages_lues <- sum(data$library %>% filter(Lu == "Oui") %>% pull(Pages), na.rm = TRUE)
    mots <- pages_lues * 250
    millions <- round(mots / 1e6, 1)
    div(class = "fun-fact-value",
        paste0(format(millions, big.mark = " "), " millions de mots")
    )
  })

  # Meilleure année
  output$fact_meilleure_annee <- renderUI({
    livres_lus <- data$library %>% filter(Lu == "Oui", !is.na(Fini))
    livres_lus$annee <- format(as.Date(livres_lus$Fini), "%Y")
    top_annee <- livres_lus %>% count(annee, sort = TRUE) %>% head(1)
    pages_annee <- livres_lus %>% filter(annee == top_annee$annee[1]) %>% pull(Pages) %>% sum(na.rm = TRUE)
    div(class = "fun-fact-value",
        paste0(top_annee$annee[1]),
        br(), tags$span(class = "fun-fact-compare", paste0(top_annee$n[1], " livres — ", format(pages_annee, big.mark = " "), " pages"))
    )
  })

  # Taille moyenne
  output$fact_pages_moyenne <- renderUI({
    moy <- round(mean(data$library %>% filter(Lu == "Oui") %>% pull(Pages), na.rm = TRUE), 0)
    med <- round(median(data$library %>% filter(Lu == "Oui") %>% pull(Pages), na.rm = TRUE), 0)
    div(class = "fun-fact-value",
        paste0(moy, " pages"),
        br(), tags$span(class = "fun-fact-compare", paste0("médiane : ", med, " pages"))
    )
  })

  # Reste à lire
  output$fact_restant_a_lire <- renderUI({
    total <- nrow(data$library)
    lus <- nrow(data$library %>% filter(Lu == "Oui"))
    restants <- total - lus
    pourc <- round(restants / total * 100, 0)
    div(class = "fun-fact-value",
        paste0(restants, " livres"),
        br(), tags$span(class = "fun-fact-compare", paste0(pourc, " % de la bibliothèque"))
    )
  })

  # Suggestion de prochaine lecture (dans Profil Lecteur — conservé pour rétrocompatibilité)
  data$suggestion_seed <- reactiveVal(1)
  observeEvent(input$suggestion_refresh, { data$suggestion_seed(data$suggestion_seed() + 1) })

  output$suggestion_genre_ui <- renderUI({
    genres_non_lus <- sort(unique(data$library %>% filter(Lu == "Non") %>% pull(Genre)))
    selectizeInput("suggestion_genre", label = NULL, choices = c("Tous les genres" = "", genres_non_lus), selected = "")
  })

  output$suggestion_livre <- renderUI({
    data$suggestion_seed()
    non_lus <- data$library %>% filter(Lu == "Non")
    if (!is.null(input$suggestion_genre) && input$suggestion_genre != "") {
      non_lus <- non_lus %>% filter(Genre == input$suggestion_genre)
    }
    if (nrow(non_lus) == 0) {
      div(class = "suggestion-vide", "Aucun livre non lu dans ce genre")
    } else {
      livre <- non_lus[sample(nrow(non_lus), 1), ]
      div(class = "suggestion-livre-inner",
          div(class = "suggestion-livre-barre"),
          div(class = "suggestion-contenu",
              div(class = "suggestion-titre", livre$Titre),
              div(class = "suggestion-auteur", livre$Auteur),
              div(class = "suggestion-meta",
                  paste0(c(
                    if (!is.na(livre$Genre) && livre$Genre != "") livre$Genre,
                    if (!is.na(livre$Pages)) paste0(livre$Pages, " pages"),
                    if (!is.na(livre$Origine) && livre$Origine != "") livre$Origine,
                    if (!is.na(livre$Date)) livre$Date
                  ), collapse = "  ·  ")
              )
          )
      )
    }
  })


  # ------------------------------------------------------------------------------
  #                              Tirage au sort — lecture & achat
  # ------------------------------------------------------------------------------

  tirage_lecture_seed <- reactiveVal(1)
  observeEvent(input$tirage_lecture_refresh, { tirage_lecture_seed(tirage_lecture_seed() + 1) })

  output$tirage_lecture_filtre_ui <- renderUI({
    req(data$table_library)
    mode    <- if (!is.null(input$tirage_lecture_mode)) input$tirage_lecture_mode else "genre"
    non_lus <- data$library %>% filter(Lu == "Non")

    choices <- switch(mode,
                      "genre"  = c("Tous" = "", sort(unique(na.omit(non_lus$Genre)))),
                      "auteur" = c("Tous" = "", sort(unique(na.omit(non_lus$Auteur)))),
                      "siecle" = {
                        siecles <- non_lus %>%
                          filter(!is.na(Date)) %>%
                          mutate(siecle = dplyr::case_when(
                            as.numeric(Date) >= 2000 ~ "XXI\u1d49",
                            as.numeric(Date) >= 1900 ~ "XX\u1d49",
                            as.numeric(Date) >= 1800 ~ "XIX\u1d49",
                            TRUE ~ "Avant XIX\u1d49"
                          )) %>% pull(siecle) %>% unique() %>% sort()
                        c("Toutes" = "", siecles)
                      }
    )
    selectizeInput("tirage_lecture_filtre", label = NULL, choices = choices, selected = "")
  })

  output$tirage_lecture_ui <- renderUI({
    tirage_lecture_seed()
    req(data$table_library)
    mode   <- if (!is.null(input$tirage_lecture_mode)) input$tirage_lecture_mode else "genre"
    filtre <- input$tirage_lecture_filtre

    non_lus <- data$library %>% filter(Lu == "Non")

    if (!is.null(filtre) && filtre != "") {
      if (mode == "genre")  non_lus <- non_lus %>% filter(Genre  == filtre)
      if (mode == "auteur") non_lus <- non_lus %>% filter(Auteur == filtre)
      if (mode == "siecle") {
        non_lus <- non_lus %>%
          filter(!is.na(Date)) %>%
          mutate(siecle = dplyr::case_when(
            as.numeric(Date) >= 2000 ~ "XXI\u1d49",
            as.numeric(Date) >= 1900 ~ "XX\u1d49",
            as.numeric(Date) >= 1800 ~ "XIX\u1d49",
            TRUE ~ "Avant XIX\u1d49"
          )) %>% filter(siecle == filtre)
      }
    }

    if (nrow(non_lus) == 0) {
      div(class = "suggestion-vide", "Aucun livre non lu dans cette sélection")
    } else {
      livre <- non_lus[sample(nrow(non_lus), 1), ]
      div(class = "suggestion-livre-inner",
          div(class = "suggestion-livre-barre"),
          div(class = "suggestion-contenu",
              div(class = "suggestion-titre", livre$Titre),
              div(class = "suggestion-auteur", livre$Auteur),
              div(class = "suggestion-meta",
                  paste0(na.omit(c(
                    if (!is.na(livre$Genre)  && livre$Genre  != "") livre$Genre,
                    if (!is.na(livre$Pages)) paste0(livre$Pages, " pages"),
                    if (!is.na(livre$Origine) && livre$Origine != "") livre$Origine,
                    if (!is.na(livre$Date))  as.character(livre$Date)
                  )), collapse = "  \u00b7  ")
              )
          )
      )
    }
  })

  tirage_achat_seed <- reactiveVal(1)
  observeEvent(input$tirage_achat_refresh, { tirage_achat_seed(tirage_achat_seed() + 1) })

  output$tirage_achat_filtre_ui <- renderUI({
    req(data$livres, data$table_library)
    mode      <- if (!is.null(input$tirage_achat_mode)) input$tirage_achat_mode else "genre"
    isbn_pos  <- data$table_library$ISBN
    candidats <- data$livres %>% filter(!(ISBN %in% isbn_pos))

    choices <- switch(mode,
                      "genre"  = c("Tous" = "", sort(unique(na.omit(candidats$Genre)))),
                      "auteur" = c("Tous" = "", sort(unique(na.omit(candidats$Auteur)))),
                      "siecle" = {
                        siecles <- candidats %>%
                          filter(!is.na(Date)) %>%
                          mutate(siecle = dplyr::case_when(
                            as.numeric(Date) >= 2000 ~ "XXI\u1d49",
                            as.numeric(Date) >= 1900 ~ "XX\u1d49",
                            as.numeric(Date) >= 1800 ~ "XIX\u1d49",
                            TRUE ~ "Avant XIX\u1d49"
                          )) %>% pull(siecle) %>% unique() %>% sort()
                        c("Toutes" = "", siecles)
                      }
    )
    selectizeInput("tirage_achat_filtre", label = NULL, choices = choices, selected = "")
  })

  output$tirage_achat_ui <- renderUI({
    tirage_achat_seed()
    req(data$livres, data$table_library)

    isbn_possedes <- data$table_library$ISBN
    candidats     <- data$livres %>% filter(!(ISBN %in% isbn_possedes))

    mode   <- if (!is.null(input$tirage_achat_mode)) input$tirage_achat_mode else "genre"
    filtre <- input$tirage_achat_filtre
    if (!is.null(filtre) && filtre != "") {
      if (mode == "genre")  candidats <- candidats %>% filter(Genre  == filtre)
      if (mode == "auteur") candidats <- candidats %>% filter(Auteur == filtre)
      if (mode == "siecle") {
        candidats <- candidats %>%
          filter(!is.na(Date)) %>%
          mutate(siecle = dplyr::case_when(
            as.numeric(Date) >= 2000 ~ "XXI\u1d49",
            as.numeric(Date) >= 1900 ~ "XX\u1d49",
            as.numeric(Date) >= 1800 ~ "XIX\u1d49",
            TRUE ~ "Avant XIX\u1d49"
          )) %>% filter(siecle == filtre)
      }
    }

    if (nrow(candidats) == 0) {
      div(class = "suggestion-vide", "Aucun livre disponible hors de votre bibliothèque")
    } else {
      livre <- candidats[sample(nrow(candidats), 1), ]
      div(class = "suggestion-livre-inner",
          div(class = "suggestion-livre-barre"),
          div(class = "suggestion-contenu",
              div(class = "suggestion-titre", livre$Titre),
              div(class = "suggestion-auteur", livre$Auteur),
              div(class = "suggestion-meta",
                  paste0(na.omit(c(
                    if (!is.na(livre$Genre)   && livre$Genre   != "") livre$Genre,
                    if (!is.na(livre$Pages))  paste0(livre$Pages, " pages"),
                    if (!is.na(livre$Origine) && livre$Origine != "") livre$Origine,
                    if (!is.na(livre$Date))   as.character(livre$Date)
                  )), collapse = "  \u00b7  ")
              )
          )
      )
    }
  })

  #-----CHATBOT-----
  #--------------

  # Réactif pour stocker l'historique
  # Initialise avec un historique vide (sans données encore)
  chat_history <- reactiveVal(list())

  # Dès que data$table_library est prêt, injecte le contexte
  observe({
    req(data$table_library)

    df <- data$table_library

    contexte <- if (nrow(df) > 0) {
      paste(
        apply(df, 1, function(row) {
          paste(names(row), row, sep = ": ", collapse = " | ")
        }),
        collapse = "\n"
      )
    } else {
      "Bibliothèque vide."
    }

    # System prompt invisible — jamais affiché dans le renderUI
    chat_history(list(
      list(
        role  = "user",
        parts = list(list(text = paste0(
          "Tu es un assistant bibliothèque personnel strict. ",
          "Tu réponds UNIQUEMENT aux questions sur les livres, auteurs, et la lecture. ",
          "Si la question n'est pas liée aux livres, réponds exactement : ",
          "'Je suis uniquement disponible pour parler de livres et de ta bibliothèque.' ",
          "Sois concis : maximum 3-4 phrases par réponse, pas de listes à rallonge. ",
          "Tu peux suggérer des livres extérieurs à la bibliothèque UNIQUEMENT si l'utilisateur le demande explicitement. ",
          "Bibliothèque actuelle :\n", contexte
        )))
      ),
      list(
        role  = "model",
        parts = list(list(text = "Compris."))
      )
    ))
  })
  observeEvent(input$chatbot_send, {
    req(input$chatbot_input)

    # Ajouter le message utilisateur à l'historique
    history <- chat_history()
    history <- append(history, list(list(role = "user", parts = list(list(text = input$chatbot_input)))))

    # Appel à l'API Gemini
    reply <- tryCatch(
      gemini_chat(history),
      error = function(e) {
        if (grepl("429", e$message)) {
          "Trop de requêtes, patiente quelques secondes et réessaie."
        } else {
          paste("Erreur :", e$message)
        }
      }
    )
    # Ajouter la réponse du modèle à l'historique
    history <- append(history, list(list(role = "model", parts = list(list(text = reply)))))
    chat_history(history)

    # Affichage de l'historique
    output$chatbot_ui <- renderUI({
      history <- chat_history()

      # Ignore les 2 premiers messages (system prompt invisible)
      visible <- if (length(history) > 2) history[3:length(history)] else list()

      if (length(visible) == 0) {
        return(div(
          style = "text-align:center; opacity:0.35; padding:20px 0; font-size:13px;",
          "Pose-moi une question sur ta bibliothèque…"
        ))
      }

      div(class = "chat-messages",
          lapply(visible, function(msg) {
            is_user <- msg$role == "user"
            div(
              class = paste("chat-bubble", ifelse(is_user, "user", "assistant")),
              if (is_user) {
                msg$parts[[1]]$text
              } else {
                HTML(commonmark::markdown_html(msg$parts[[1]]$text))
              }
            )
          })
      )
    })

    # Réinitialiser l'input
    updateTextInput(session, "chatbot_input", value = "")
  })


  # ------------------------------------------------------------------------------
  #                                    Page Option
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
  #                                   Page 6.1
  # ------------------------------------------------------------------------------

  output$output_verif_livre_bibliotheque <- renderText({

    if(str_length(input$input_verif_livre_bibliotheque)==17) {
      if(input$input_verif_livre_bibliotheque %in% data$table_library$ISBN) {
        paste0("Le livre ", data$table_library$Titre[data$table_library$ISBN==input$input_verif_livre_bibliotheque],
               " de ", data$table_library$Auteur[data$table_library$ISBN==input$input_verif_livre_bibliotheque],
               " (", data$table_library$Date[data$table_library$ISBN==input$input_verif_livre_bibliotheque], ")",
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
    } else if(input$input_verif_livre_bibliotheque %in% data$table_library$ISBN) {
      NULL
    } else if(input$input_verif_livre_bibliotheque %in% data$livres$ISBN) {
      div(class = "trio-form",
          fluidRow(
            column(4, offset = 4,
                   div(class = "trio-card trio-card--avis",
                       div(class = "trio-card-header", icon("star"), "Mon avis"),
                       fluidRow(
                         column(6, selectInput(inputId = "ajout_lu_isbn", label = "Lu ?", choices = c("Oui", "Non", "En train de lire"), selected = "Non")),
                         column(6, selectInput(inputId = "ajout_favori_isbn", label = "Aimé ?", choices = c("Oui", "Non", "Pas lu"), selected = "Pas lu"))
                       ),
                       fluidRow(
                         column(6, selectInput(inputId = "ajout_bibliotheque_isbn", label = "Votre livre ?", choices = c("Oui", "Non"), selected = "Oui")),
                         column(6, selectInput(inputId = "ajout_rachat_isbn", label = "À racheter ?", choices = c("Oui", "Non"), selected = "Non"))
                       ),
                       fluidRow(
                         column(6, uiOutput(outputId = "ajout_date_debut_isbn_ui")),
                         column(6, uiOutput(outputId = "ajout_date_fin_isbn_ui"))
                       )
                   )
            )
          ),
          div(class = "trio-form-btn",
              actionButton(inputId = "ajout_bouton_isbn", label = "Ajouter le livre", icon = icon("plus"))
          )
      )
    } else {
      div(class = "trio-form",
          fluidRow(
            column(4,
                   div(class = "trio-card trio-card--livre",
                       div(class = "trio-card-header", icon("book-open"), "Le livre"),
                       textInput(inputId = "ajout_titre", label = "Titre", placeholder = "Titre..."),
                       selectizeInput(inputId = "ajout_auteur", label = "Auteur", choices = c("", sort(unique(data$livres$Auteur))), selected = "", options = list(create = TRUE, placeholder = "Auteur...")),
                       fluidRow(
                         column(5, numericInput(inputId = "ajout_date", label = "Année", value = format(Sys.Date(), "%Y"), step = 1)),
                         column(7, selectizeInput(inputId = "ajout_genre", label = "Genre", choices = c("", sort(unique(data$livres$Genre))), selected = "", options = list(create = TRUE, placeholder = "Genre...")))
                       ),
                       fluidRow(
                         column(6, selectizeInput(inputId = "ajout_pays_origine", label = "Pays", choices = c("", sort(unique(data$livres$Origine))), selected = "", options = list(create = TRUE, placeholder = "Pays..."))),
                         column(6, selectizeInput(inputId = "ajout_langue_ecriture", label = "Langue", choices = c("", sort(unique(data$livres$Ecriture))), selected = "", options = list(create = TRUE, placeholder = "Langue...")))
                       ),
                       fluidRow(
                         column(6, numericInput(inputId = "ajout_nb_pages_hist", label = "Pages (hist.)", value = NULL, step = 1)),
                         column(6, numericInput(inputId = "ajout_nb_pages_livre", label = "Pages (livre)", value = NULL, step = 1))
                       )
                   )
            ),
            column(4,
                   div(class = "trio-card trio-card--edition",
                       div(class = "trio-card-header", icon("bookmark"), "L'édition"),
                       fluidRow(
                         column(8, selectizeInput(inputId = "ajout_edition", label = "Éditeur", choices = c("", sort(unique(data$livres$Edition))), selected = "", options = list(create = TRUE, placeholder = "Éditeur..."))),
                         column(4, numericInput(inputId = "ajout_num_edition", label = "N°", value = NULL))
                       ),
                       selectizeInput(inputId = "ajout_collection", label = "Collection", choices = c("", sort(unique(data$livres$Collection))), selected = "", options = list(create = TRUE, placeholder = "Collection...")),
                       textInput(inputId = "ajout_isbn", label = "ISBN", value = input$input_verif_livre_bibliotheque),
                       fluidRow(
                         column(6, selectizeInput(inputId = "ajout_prefacier", label = "Préfacier", choices = c("", sort(unique(data$livres$Préfacier))), selected = "", options = list(create = TRUE, placeholder = "Préfacier..."))),
                         column(6, selectizeInput(inputId = "ajout_traducteur", label = "Traducteur", choices = c("", sort(unique(data$livres$Traducteur))), selected = "", options = list(create = TRUE, placeholder = "Traducteur...")))
                       ),
                       numericInput(inputId = "ajout_prix", label = "Prix", step = 0.01, value = NULL)
                   )
            ),
            column(4,
                   div(class = "trio-card trio-card--avis",
                       div(class = "trio-card-header", icon("star"), "Mon avis"),
                       fluidRow(
                         column(6, selectInput(inputId = "ajout_lu", label = "Lu ?", choices = c("Oui", "Non", "En train de lire"), selected = "Non")),
                         column(6, selectInput(inputId = "ajout_favori", label = "Aimé ?", choices = c("Oui", "Non", "Pas lu"), selected = "Pas lu"))
                       ),
                       fluidRow(
                         column(6, selectInput(inputId = "ajout_bibliotheque", label = "Votre livre ?", choices = c("Oui", "Non"), selected = "Oui")),
                         column(6, selectInput(inputId = "ajout_rachat", label = "À racheter ?", choices = c("Oui", "Non"), selected = "Non"))
                       ),
                       fluidRow(
                         column(6, uiOutput(outputId = "ajout_date_debut_ui")),
                         column(6, uiOutput(outputId = "ajout_date_fin_ui"))
                       )
                   )
            )
          ),
          div(class = "trio-form-btn",
              actionButton(inputId = "ajout_bouton", label = "Ajouter le livre", icon = icon("plus"))
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
      dateInput(inputId = "ajout_date_fin_isbn", label = "Date de fin de lecture", min = input$ajout_date_debut_isbn, max = Sys.Date(), format = "dd/mm/yyyy", language = "fr", weekstart = 1)
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
      dateInput(inputId = "ajout_date_fin", label = "Date de fin de lecture", min = input$ajout_date_debut, max = Sys.Date(), format = "dd/mm/yyyy", language = "fr", weekstart = 1)
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
    colnames(data$new_book) = colnames(data$table_library)
    wb_library = createWorkbook()
    addWorksheet(wb_library, "library")
    writeData(wb_library, "library", arrange(rbind(data$table_library, data$new_book), Titre, Auteur), colNames = TRUE)
    s3_write_xlsx(wb_library, link_to_library())
    data$table_library = arrange(rbind(data$table_library, data$new_book), Titre, Auteur, Date)

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
    writeData(wb_library, "library", arrange(rbind(data$table_library, data$new_book), Titre, Auteur), colNames = TRUE)
    s3_write_xlsx(wb_library, link_to_library())
    data$table_library = arrange(rbind(data$table_library, data$new_book), Titre, Auteur, Date)

    wb_livres = createWorkbook()
    addWorksheet(wb_livres, "library")
    writeData(wb_livres, "library", arrange(rbind(data$livres, data$new_book[,c(1:15)]), Titre, Auteur), colNames = TRUE)
    s3_write_xlsx(wb_livres, link_to_livres)
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
  #                                   Page 6.2
  # ------------------------------------------------------------------------------

  output$choix_isbn_modif <- renderUI({
    div(class = "modif-search-zone",
        selectizeInput(inputId = "modif_livre_titre", label = "Choisir un livre", width = "700px", choices = setNames(arrange(mutate(data$table_library, choix = paste(Titre, Auteur, sep = " - ")), choix)$ISBN, arrange(mutate(data$table_library, choix = paste(Titre, Auteur, sep = " - ")), choix)$choix), selected = "", options = list(placeholder = "Livre..."))
    )
  })


  output$modif_info_livre <- renderUI({
    div(class = "trio-form",
        fluidRow(
          column(4,
                 div(class = "trio-card trio-card--livre",
                     div(class = "trio-card-header", icon("book-open"), "Le livre"),
                     textInput(inputId = "modif_titre", label = "Titre", value = data$table_library$Titre[which(data$table_library$ISBN==input$modif_livre_titre)]),
                     selectizeInput(inputId = "modif_auteur", label = "Auteur", choices = c("", sort(unique(data$livres$Auteur))), selected = data$table_library$Auteur[which(data$table_library$ISBN==input$modif_livre_titre)], options = list(create = TRUE)),
                     fluidRow(
                       column(5, numericInput(inputId = "modif_date", label = "Année", value = data$table_library$Date[which(data$table_library$ISBN==input$modif_livre_titre)], step = 1)),
                       column(7, selectizeInput(inputId = "modif_genre", label = "Genre", choices = c("", sort(unique(data$livres$Genre))), selected = data$table_library$Genre[which(data$table_library$ISBN==input$modif_livre_titre)], options = list(create = TRUE)))
                     ),
                     fluidRow(
                       column(6, selectizeInput(inputId = "modif_pays_origine", label = "Pays", choices = c("", sort(unique(data$livres$Origine))), selected = data$table_library$Origine[which(data$table_library$ISBN==input$modif_livre_titre)], options = list(create = TRUE))),
                       column(6, selectizeInput(inputId = "modif_langue_ecriture", label = "Langue", choices = c("", sort(unique(data$livres$Ecriture))), selected = data$table_library$Ecriture[which(data$table_library$ISBN==input$modif_livre_titre)], options = list(create = TRUE)))
                     ),
                     fluidRow(
                       column(6, numericInput(inputId = "modif_nb_pages_hist", label = "Pages (hist.)", value = data$table_library$Longueur[which(data$table_library$ISBN==input$modif_livre_titre)], step = 1)),
                       column(6, numericInput(inputId = "modif_nb_pages_livre", label = "Pages (livre)", value = data$table_library$Pages[which(data$table_library$ISBN==input$modif_livre_titre)], step = 1))
                     )
                 )
          ),
          column(4,
                 div(class = "trio-card trio-card--edition",
                     div(class = "trio-card-header", icon("bookmark"), "L'édition"),
                     fluidRow(
                       column(8, selectizeInput(inputId = "modif_edition", label = "Éditeur", choices = c("", sort(unique(data$livres$Edition))), selected = data$table_library$Edition[which(data$table_library$ISBN==input$modif_livre_titre)], options = list(create = TRUE))),
                       column(4, numericInput(inputId = "modif_num_edition", label = "N°", value = data$table_library$Numéro[which(data$table_library$ISBN==input$modif_livre_titre)]))
                     ),
                     selectizeInput(inputId = "modif_collection", label = "Collection", choices = c("", sort(unique(data$livres$Collection))), selected = data$table_library$Collection[which(data$table_library$ISBN==input$modif_livre_titre)], options = list(create = TRUE)),
                     textInput(inputId = "modif_isbn", label = "ISBN", value = input$modif_livre_titre),
                     fluidRow(
                       column(6, selectizeInput(inputId = "modif_prefacier", label = "Préfacier", choices = c("", sort(unique(data$livres$Préfacier))), selected = data$table_library$Préfacier[which(data$table_library$ISBN==input$modif_livre_titre)], options = list(create = TRUE))),
                       column(6, selectizeInput(inputId = "modif_traducteur", label = "Traducteur", choices = c("", sort(unique(data$livres$Traducteur))), selected = data$table_library$Traducteur[which(data$table_library$ISBN==input$modif_livre_titre)], options = list(create = TRUE)))
                     ),
                     numericInput(inputId = "modif_prix", label = "Prix", step = 0.01, value = data$table_library$Prix[which(data$table_library$ISBN==input$modif_livre_titre)])
                 )
          ),
          column(4,
                 div(class = "trio-card trio-card--avis",
                     div(class = "trio-card-header", icon("star"), "Mon avis"),
                     fluidRow(
                       column(6, selectInput(inputId = "modif_lu", label = "Lu ?", choices = c("Oui", "Non", "En train de lire"), selected = data$table_library$Lu[which(data$table_library$ISBN==input$modif_livre_titre)])),
                       column(6, selectInput(inputId = "modif_favori", label = "Aimé ?", choices = c("Oui", "Non", "Pas lu"), selected = data$table_library$Favori[which(data$table_library$ISBN==input$modif_livre_titre)]))
                     ),
                     fluidRow(
                       column(6, selectInput(inputId = "modif_bibliotheque", label = "Votre livre ?", choices = c("Oui", "Non"), selected = data$table_library$Bibliothèque[which(data$table_library$ISBN==input$modif_livre_titre)])),
                       column(6, selectInput(inputId = "modif_rachat", label = "À racheter ?", choices = c("Oui", "Non"), selected = data$table_library$Rachat[which(data$table_library$ISBN==input$modif_livre_titre)]))
                     ),
                     fluidRow(
                       column(6, uiOutput(outputId = "modif_date_debut_ui")),
                       column(6, uiOutput(outputId = "modif_date_fin_ui"))
                     )
                 )
          )
        ),
        div(class = "trio-form-btn",
            actionButton(inputId = "modif_bouton", label = "Enregistrer les changements", icon = icon("floppy-disk"))
        )
    )
  })


  output$modif_date_debut_ui <- renderUI ({
    if (input$modif_lu %in% c("Oui", "En train de lire")) {
      dateInput(inputId = "modif_date_debut", label = "Date de début de lecture", max = Sys.Date(), value = dmy(data$table_library$Commencé[which(data$table_library$ISBN==input$modif_livre_titre)]), format = "dd-mm-yyyy", language = "fr", weekstart = 1)
    } else {
      NULL
    }
  })


  output$modif_date_fin_ui <- renderUI ({
    if (input$modif_lu %in% c("Oui")) {
      dateInput(inputId = "modif_date_fin", label = "Date de fin de lecture", min = input$modif_date_debut, max = Sys.Date(), value = dmy(data$table_library$Fini[which(data$table_library$ISBN==input$modif_livre_titre)]), format = "dd-mm-yyyy", language = "fr", weekstart = 1)
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
    data$modif_library = data$table_library[-which(data$table_library$ISBN==input$modif_livre_titre),]
    colnames(data$modif_book) = colnames(data$table_library)
    colnames(data$modif_library) = colnames(data$table_library)
    wb_modif_library = createWorkbook()
    addWorksheet(wb_modif_library, "library")
    writeData(wb_modif_library, "library", arrange(rbind(data$modif_library, data$modif_book), Titre, Auteur, Date), colNames = TRUE)
    s3_write_xlsx(wb_modif_library, link_to_library())
    data$table_library = arrange(rbind(data$modif_library, data$modif_book), Titre, Auteur, Date)

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
  #                                  Page Defis
  # ------------------------------------------------------------------------------

  output$defi_progression_globale <- renderUI({
    req(data$table_library)
    d <- data$table_library
    lus <- d %>% filter(Lu == "Oui")
    nb_biblio <- nrow(d)
    nb_lus <- nrow(lus)
    nb_pages <- sum(lus$Pages, na.rm = TRUE)
    nb_auteurs <- length(unique(lus$Auteur))
    nb_genres <- length(unique(lus$Genre))
    nb_pays <- if ("Origine" %in% colnames(lus)) length(unique(lus$Origine)) else 0
    nb_favoris <- sum(d$Favori == "Oui", na.rm = TRUE)

    lus_fini <- lus %>% filter(!is.na(Fini), Fini != "")
    annees_actives <- tryCatch({ lus_fini %>% mutate(a = year(dmy(Fini))) %>% filter(!is.na(a)) %>% pull(a) %>% unique() %>% length() }, error = function(e) 0)
    mois_actifs <- tryCatch({ lus_fini %>% mutate(m = floor_date(dmy(Fini), "month")) %>% filter(!is.na(m)) %>% pull(m) %>% unique() %>% length() }, error = function(e) 0)
    max_annee <- tryCatch({ lus_fini %>% mutate(a = year(dmy(Fini))) %>% filter(!is.na(a)) %>% count(a) %>% pull(n) %>% max() }, error = function(e) 0)
    max_mois <- tryCatch({ lus_fini %>% mutate(m = floor_date(dmy(Fini), "month")) %>% filter(!is.na(m)) %>% count(m) %>% pull(n) %>% max() }, error = function(e) 0)

    auteurs_3plus <- lus %>% count(Auteur) %>% filter(n >= 3) %>% nrow()
    auteurs_5plus <- lus %>% count(Auteur) %>% filter(n >= 5) %>% nrow()
    auteurs_10plus <- lus %>% count(Auteur) %>% filter(n >= 10) %>% nrow()
    genres_10plus <- lus %>% count(Genre) %>% filter(n >= 10) %>% nrow()
    genres_25plus <- lus %>% count(Genre) %>% filter(n >= 25) %>% nrow()
    pct_lu <- if (nb_biblio > 0) round(nb_lus / nb_biblio * 100) else 0

    nb_courts <- sum(lus$Pages < 150, na.rm = TRUE)
    nb_longs <- sum(lus$Pages > 500, na.rm = TRUE)
    nb_tres_longs <- sum(lus$Pages > 800, na.rm = TRUE)
    nb_monstres <- sum(lus$Pages > 1000, na.rm = TRUE)
    max_p <- max(lus$Pages, na.rm = TRUE)
    max_p <- if (is.finite(max_p)) max_p else 0

    # Liste de tous les defis : c(current, objectif)
    all_defis <- list(
      # Bibliotheque
      c(nb_biblio, 50), c(nb_biblio, 200), c(nb_biblio, 500), c(nb_biblio, 1000),
      c(nb_biblio, 2500), c(nb_biblio, 5000), c(nb_biblio, 10000), c(nb_biblio, 25000),
      # Lectures
      c(nb_lus, 1), c(nb_lus, 50), c(nb_lus, 200), c(nb_lus, 500),
      c(nb_lus, 1000), c(nb_lus, 2500), c(nb_lus, 5000), c(nb_lus, 10000),
      # Pages
      c(nb_pages, 5000), c(nb_pages, 25000), c(nb_pages, 100000), c(nb_pages, 500000),
      c(nb_pages, 1000000), c(nb_pages, 2000000), c(nb_pages, 5000000), c(nb_pages, 10000000),
      # Exploration
      c(nb_auteurs, 25), c(nb_auteurs, 100), c(nb_auteurs, 250), c(nb_auteurs, 500),
      c(nb_genres, 10), c(nb_genres, 20), c(nb_genres, 35),
      c(nb_pays, 20), c(nb_pays, 50), c(nb_pays, 100),
      c(nb_favoris, 50), c(nb_favoris, 150), c(nb_favoris, 300), c(nb_favoris, 500),
      # Regularite
      c(annees_actives, 1), c(annees_actives, 5), c(annees_actives, 10), c(annees_actives, 25), c(annees_actives, 50),
      c(max_mois, 10), c(max_mois, 20), c(max_mois, 30),
      c(max_annee, 52), c(max_annee, 100), c(max_annee, 200), c(max_annee, 365),
      c(mois_actifs, 24), c(mois_actifs, 60), c(mois_actifs, 120),
      # Completiste
      c(if (pct_lu >= 50) 1 else 0, 1), c(if (pct_lu >= 75) 1 else 0, 1), c(if (pct_lu >= 100) 1 else 0, 1),
      c(auteurs_3plus, 1), c(auteurs_3plus, 5), c(auteurs_5plus, 1), c(auteurs_5plus, 3),
      c(auteurs_10plus, 1), c(genres_10plus, 1), c(genres_10plus, 3), c(genres_25plus, 1),
      # Gabarits
      c(nb_courts, 10), c(nb_courts, 25),
      c(nb_longs, 5), c(nb_longs, 15), c(nb_tres_longs, 5),
      c(nb_monstres, 1), c(nb_monstres, 5),
      c(if (max_p >= 600) 1 else 0, 1), c(if (max_p >= 1200) 1 else 0, 1)
    )

    nb_total <- length(all_defis)
    nb_done <- sum(sapply(all_defis, function(x) x[1] >= x[2]))
    pct <- round(nb_done / nb_total * 100, 1)

    div(class = "defi-global-bar",
        div(class = "defi-global-label",
            icon("trophy"), paste0(" ", nb_done, "/", nb_total, " défis (", pct, " %)")
        ),
        div(class = "defi-bar-outer defi-global-outer",
            div(class = "defi-bar-fill defi-global-fill", style = paste0("width: ", pct, "%;"))
        )
    )
  })

  # Helper : genere une carte de defi (dans une column)
  make_defi <- function(titre, description, current, objectif, icone = "star", col_width = 4) {
    pct <- min(round(current / objectif * 100, 1), 100)
    achieved <- current >= objectif
    column(col_width,
           div(class = paste0("defi-card", if (achieved) " defi-card-achieved" else ""),
               div(class = if (achieved) "defi-card-icon-achieved" else "defi-card-icon-locked", icon(icone)),
               div(class = "defi-card-titre", titre),
               div(class = "defi-card-desc", description),
               div(class = "defi-card-count", paste0(format(current, big.mark = " "), " / ", format(objectif, big.mark = " "))),
               div(class = "defi-bar-outer",
                   div(class = "defi-bar-fill", style = paste0("width: ", pct, "%;"),
                       if (pct >= 12) span(class = "defi-bar-text", paste0(pct, " %"))
                   )
               )
           )
    )
  }

  output$defi_livres_biblio <- renderUI({
    req(data$table_library)
    nb <- nrow(data$table_library)
    fluidRow(
      make_defi("Collectionneur débutant", "Ajoutez 50 livres à votre bibliothèque.", nb, 50, "seedling"),
      make_defi("Belle étagère", "Rassemblez 200 ouvrages dans votre collection.", nb, 200, "bookmark"),
      make_defi("Bibliothèque garnie", "Atteignez le cap des 500 livres.", nb, 500, "book"),
      make_defi("Grand collectionneur", "Possédez 800 livres.", nb, 800, "book-open"),
      make_defi("Bibliothèque monumentale", "1 000 livres : une vraie passion.", nb, 1000, "landmark"),
      make_defi("Trésor national", "2 500 livres : un patrimoine littéraire.", nb, 2500, "scroll"),
      make_defi("Alexandrie moderne", "5 000 livres. Votre propre bibliothèque d'Alexandrie.", nb, 5000, "building-columns"),
      make_defi("Huitième merveille", "10 000 livres. Une collection légendaire.", nb, 10000, "crown"),
      make_defi("Mémoire du monde", "20 000 livres. Un héritage littéraire hors du temps.", nb, 20000, "infinity")
    )
  })

  output$defi_livres_lus <- renderUI({
    req(data$table_library)
    nb <- sum(data$table_library$Lu == "Oui", na.rm = TRUE)
    fluidRow(
      make_defi("Premiere lecture", "Lisez votre tout premier livre.", nb, 1, "feather"),
      make_defi("Lecteur curieux", "Terminez 50 livres.", nb, 50, "glasses"),
      make_defi("Lecteur assidu", "200 livres lus : la lecture est une habitude.", nb, 200, "fire"),
      make_defi("Dévoreur de livres", "500 livres : vous êtes insatiable.", nb, 500, "bolt"),
      make_defi("Lecteur infatigable", "1 000 livres : rien ne vous arrête.", nb, 1000, "meteor"),
      make_defi("Maître des pages", "1 500 livres lus : votre bibliothèque intérieure grandit.", nb, 1500, "book-open-reader"),
      make_defi("Légende de la lecture", "2 500 livres lus. Le panthéon des lecteurs.", nb, 2500, "gem"),
      make_defi("Demi-dieu littéraire", "5 000 livres lus. L'humanité vous remercie.", nb, 5000, "hat-wizard"),
      make_defi("Omniscient", "10 000 livres. Vous avez tout lu.", nb, 10000, "infinity")
    )
  })

  output$defi_pages <- renderUI({
    req(data$table_library)
    nb <- sum(data$table_library$Pages[data$table_library$Lu == "Oui"], na.rm = TRUE)
    fluidRow(
      make_defi("Premiers pas", "Lisez vos 5 000 premières pages.", nb, 5000, "shoe-prints"),
      make_defi("Marathonien", "Franchissez le cap des 25 000 pages.", nb, 25000, "person-running"),
      make_defi("Avaleur de pages", "100 000 pages parcourues. Impressionnant.", nb, 100000, "star"),
      make_defi("Géant des pages", "300 000 pages : chaque livre compte.", nb, 300000, "mountain"),
      make_defi("Demi-million", "500 000 pages : un exploit monumental.", nb, 500000, "flag-checkered"),
      make_defi("Millionnaire", "1 000 000 de pages lues.", nb, 1000000, "trophy"),
      make_defi("Deux millions", "2 000 000 de pages. L'équivalent d'une vie de lecture.", nb, 2000000, "medal"),
      make_defi("Cinq millions", "5 000 000 de pages. Un record du monde.", nb, 5000000, "crown"),
      make_defi("Dix millions", "10 000 000 de pages. Le sommet absolu.", nb, 10000000, "infinity")
    )
  })

  output$defi_exploration <- renderUI({
    req(data$table_library)
    lus <- data$table_library %>% filter(Lu == "Oui")
    nb_auteurs <- length(unique(lus$Auteur))
    nb_genres <- length(unique(lus$Genre))
    nb_pays <- if ("Origine" %in% colnames(lus)) length(unique(lus$Origine)) else 0
    nb_favoris <- sum(data$table_library$Favori == "Oui", na.rm = TRUE)
    fluidRow(
      make_defi("Plumes variées", "Découvrez 25 auteurs différents.", nb_auteurs, 25, "user"),
      make_defi("Explorateur littéraire", "Lisez 100 auteurs différents.", nb_auteurs, 100, "users"),
      make_defi("Boulimique de plumes", "500 auteurs au compteur.", nb_auteurs, 500, "people-group"),
      make_defi("Curieux de tout", "Explorez au moins 10 genres différents.", nb_genres, 10, "bookmark"),
      make_defi("Lecteur éclectique", "20 genres explorés : aucune frontière.", nb_genres, 20, "layer-group"),
      make_defi("Maître des genres", "35 genres dans votre répertoire.", nb_genres, 35, "masks-theater"),
      make_defi("Globe-trotteur", "Lisez des auteurs de 20 pays différents.", nb_pays, 20, "globe"),
      make_defi("Citoyen du monde", "50 pays représentés dans vos lectures.", nb_pays, 50, "earth-europe"),
      make_defi("Ambassadeur universel", "150 pays différents. Tour du monde littéraire.", nb_pays, 100, "earth-americas"),
      make_defi("Amateur éclair", "Marquez 50 livres comme coups de coeur.", nb_favoris, 50, "heart"),
      make_defi("Collectionneur de pépites", "150 coups de coeur dans votre bibliothèque.", nb_favoris, 150, "heart"),
      make_defi("Coeur de diamant", "500 coups de coeur. Votre bibliothèque est un tresor.", nb_favoris, 500, "gem")
    )
  })

  output$defi_regularite <- renderUI({
    req(data$table_library)
    lus <- data$table_library %>% filter(Lu == "Oui", !is.na(Fini), Fini != "")

    # Nombre d'annees distinctes avec au moins un livre lu
    annees_actives <- tryCatch({
      lus %>% mutate(annee = year(dmy(Fini))) %>% filter(!is.na(annee)) %>%
        pull(annee) %>% unique() %>% length()
    }, error = function(e) 0)

    # Nombre de mois distincts avec au moins un livre lu
    mois_actifs <- tryCatch({
      lus %>% mutate(mois = floor_date(dmy(Fini), "month")) %>% filter(!is.na(mois)) %>%
        pull(mois) %>% unique() %>% length()
    }, error = function(e) 0)

    # Max livres lus en une annee
    max_annee <- tryCatch({
      lus %>% mutate(annee = year(dmy(Fini))) %>% filter(!is.na(annee)) %>%
        count(annee) %>% pull(n) %>% max()
    }, error = function(e) 0)

    # Max livres lus en un mois
    max_mois <- tryCatch({
      lus %>% mutate(mois = floor_date(dmy(Fini), "month")) %>% filter(!is.na(mois)) %>%
        count(mois) %>% pull(n) %>% max()
    }, error = function(e) 0)

    fluidRow(
      make_defi("Fidèle lecteur", "Lisez des livres sur 5 années différentes.", annees_actives, 5, "calendar-check"),
      make_defi("Décennie de lecture", "Soyez actif sur 10 années.", annees_actives, 10, "calendar-days"),
      make_defi("Demi-siècle", "50 années. La lecture d'une vie entière.", annees_actives, 50, "hourglass"),
      make_defi("Mois prolifique", "Lisez 10 livres en un seul mois.", max_mois, 10, "bolt"),
      make_defi("Mois légendaire", "20 livres en un seul mois.", max_mois, 20, "fire"),
      make_defi("Mois surhumain", "30 livres en un mois. Un par jour.", max_mois, 30, "explosion"),
      make_defi("Année faste", "Lisez 52 livres en une année : un par semaine.", max_annee, 52, "star"),
      make_defi("Année record", "100 livres en une seule année.", max_annee, 100, "rocket"),
      make_defi("Année impossible", "365 livres. Un livre par jour pendant un an.", max_annee, 365, "skull-crossbones"),
      make_defi("Lecture continue", "Lisez au moins un livre sur 24 mois différents.", mois_actifs, 24, "clock-rotate-left"),
      make_defi("Habitude ancrée", "60 mois avec au moins une lecture.", mois_actifs, 60, "repeat"),
      make_defi("Marathonien des mois", "120 mois de lecture. 10 ans de régularité.", mois_actifs, 120, "person-running")
    )
  })

  output$defi_completiste <- renderUI({
    req(data$table_library)
    total <- nrow(data$table_library)
    lus <- sum(data$table_library$Lu == "Oui", na.rm = TRUE)
    pct_lu <- if (total > 0) round(lus / total * 100) else 0

    # Auteurs avec 3+ livres lus
    lus_df <- data$table_library %>% filter(Lu == "Oui")
    auteurs_3plus <- lus_df %>% count(Auteur) %>% filter(n >= 3) %>% nrow()
    auteurs_5plus <- lus_df %>% count(Auteur) %>% filter(n >= 5) %>% nrow()
    auteurs_10plus <- lus_df %>% count(Auteur) %>% filter(n >= 10) %>% nrow()

    # Genres avec 10+ livres
    genres_10plus <- lus_df %>% count(Genre) %>% filter(n >= 10) %>% nrow()
    genres_25plus <- lus_df %>% count(Genre) %>% filter(n >= 25) %>% nrow()
    genres_100plus <- lus_df %>% count(Genre) %>% filter(n >= 100) %>% nrow()

    # Pourcentage de la biblio lue
    pct_50 <- if (pct_lu >= 50) 1 else 0
    pct_75 <- if (pct_lu >= 75) 1 else 0
    pct_100 <- if (pct_lu >= 100) 1 else 0

    fluidRow(
      make_defi("A moitié lu", "Lisez 50 % de votre bibliothèque.", pct_50, 1, "battery-half"),
      make_defi("Presque tout lu", "Lisez 75 % de votre bibliothèque.", pct_75, 1, "battery-three-quarters"),
      make_defi("Tout lu !", "Lisez 100 % de votre bibliothèque.", pct_100, 1, "battery-full"),
      make_defi("Fan fidèle", "Lisez 3 livres ou plus d'un même auteur.", auteurs_3plus, 1, "pen-nib"),
      make_defi("Expert d'un auteur", "Lisez 5+ livres d'un même auteur.", auteurs_5plus, 1, "award"),
      make_defi("Spécialiste absolu", "Lisez 10+ livres d'un même auteur.", auteurs_10plus, 1, "graduation-cap"),
      make_defi("Genre maitrisé", "Lisez 10+ livres d'un même genre.", genres_10plus, 1, "crosshairs"),
      make_defi("Genre dominé", "25+ livres dans un seul genre.", genres_25plus, 1, "chess-queen"),
      make_defi("Maître du genre", "100+ livres lus dans un seul genre. Une vraie référence !", genres_100plus, 1, "crown")
    )
  })

  output$defi_longueur <- renderUI({
    req(data$table_library)
    lus <- data$table_library %>% filter(Lu == "Oui")

    # Livres courts (< 150 pages) et longs (> 500 pages)
    nb_courts <- sum(lus$Pages < 150, na.rm = TRUE)
    nb_longs <- sum(lus$Pages > 500, na.rm = TRUE)
    nb_tres_longs <- sum(lus$Pages > 800, na.rm = TRUE)
    nb_monstres <- sum(lus$Pages > 1000, na.rm = TRUE)

    # Plus gros livre lu
    max_pages <- max(lus$Pages, na.rm = TRUE)
    max_pages <- if (is.finite(max_pages)) max_pages else 0

    fluidRow(
      make_defi("Nouvelliste", "Lisez 10 livres de moins de 150 pages.", nb_courts, 10, "file-lines"),
      make_defi("Amateur de brèves", "Lisez 25 livres courts.", nb_courts, 25, "note-sticky"),
      make_defi("Collectionneur de nouvelles", "Lisez 50 livres courts.", nb_courts, 50, "book-open"),
      make_defi("Endurant", "Lisez 5 livres de plus de 500 pages.", nb_longs, 5, "book-open-reader"),
      make_defi("Grand format", "Lisez 15 livres de plus de 500 pages.", nb_longs, 15, "book-bookmark"),
      make_defi("Marathonien", "Lisez 30 livres de plus de 500 pages.", nb_longs, 30, "person-running"),
      make_defi("Pavé après pavé", "Lisez 5 livres de plus de 800 pages.", nb_tres_longs, 5, "dumbbell"),
      make_defi("Indestructible", "Lisez un livre de plus de 1 000 pages.", nb_monstres, 1, "mountain-sun"),
      make_defi("Collecteur de pavés", "5 livres de plus de 1 000 pages.", nb_monstres, 5, "dragon"),
      make_defi("Livre record", "Lisez un livre de plus de 600 pages.", if (max_pages >= 600) 1 else 0, 1, "arrow-up-9-1"),
      make_defi("Géant des pages", "Lisez un livre de plus de 900 pages.", if (max_pages >= 900) 1 else 0, 1, "arrow-up-9-1"),
      make_defi("Record personnel", "Lisez un livre de plus de 1 200 pages.", if (max_pages >= 1200) 1 else 0, 1, "ranking-star")
    )
  })


  # ------------------------------------------------------------------------------
  #                                Page 7 - Invité
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

    data$create_new_user = data.frame(input$create_user, input$create_password, paste0(input$create_library_name, "_", input$create_user, ".xlsx"), FALSE)
    colnames(data$create_new_user) = colnames(credentials)

    # Mettre a jour les credentials en memoire
    credentials <<- rbind(credentials, data$create_new_user)

    wb_create_library = createWorkbook()
    addWorksheet(wb_create_library, "credentials")
    writeData(wb_create_library, "credentials", credentials, colNames = TRUE)
    s3_write_xlsx(wb_create_library, config$link$link_to_credentials)

    wb_new_library = createWorkbook()
    addWorksheet(wb_new_library, input$create_library_name)
    writeData(wb_new_library, input$create_library_name, t(data.frame(colnames(guest_data))), colNames = FALSE)
    s3_write_xlsx(wb_new_library, paste0(link_to_data, input$create_library_name, "_", input$create_user, ".xlsx"))

    # Connecter automatiquement le nouvel utilisateur
    current_user(input$create_user)
    removeModal()
  })


  # ------------------------------------------------------------------------------
  #                            Onglet Administration (admin)
  # ------------------------------------------------------------------------------

  # --- Stats admin ---
  output$admin_nb_total <- renderText({
    req(data$livres, is_admin())
    format(nrow(data$livres), big.mark = "\u00a0")
  })

  # --- Mise à jour des choix du selectize ---
  observeEvent(list(data$livres, is_admin()), {
    req(data$livres, is_admin())
    df <- data$livres
    if ("ISBN" %in% colnames(df)) {
      df  <- df %>% filter(!is.na(ISBN) & ISBN != "")
      ch  <- setNames(df$ISBN, paste0(df$Titre, " \u2014 ", df$Auteur, " \u2014 ", df$Date))
    } else {
      ch  <- setNames(as.character(seq_len(nrow(df))),
                      paste0(df$Titre, " \u2014 ", df$Auteur))
    }
    updateSelectizeInput(session, "admin_search_livre",
                         choices = ch, selected = character(0), server = TRUE)
  }, ignoreNULL = TRUE)

  # --- Sélection d'un livre → ouvrir le modal trio-form ---
  observeEvent(input$admin_search_livre, {
    req(is_admin(), nzchar(input$admin_search_livre))
    showModal(modalDialog(
      title = tags$div(icon("pen"), " Modifier un livre",
                       style = "color: var(--second-color); font-family: var(--font);"),
      size      = "l",
      uiOutput("admin_modif_form_ui"),
      footer    = modalButton("Fermer")
    ))
  }, ignoreInit = TRUE)

  # --- Contenu du modal (trio-form) ---
  output$admin_modif_form_ui <- renderUI({
    req(input$admin_search_livre, nzchar(input$admin_search_livre), data$livres, is_admin())
    isbn <- input$admin_search_livre
    idx  <- which(data$livres$ISBN == isbn)
    if (length(idx) == 0) return(NULL)
    l <- data$livres[idx[1], , drop = FALSE]

    g <- function(col) {
      if (!col %in% colnames(l)) return("")
      v <- as.character(l[[col]])
      if (is.na(v) || v == "NA") "" else v
    }
    gn <- function(col) {
      if (!col %in% colnames(l)) return(NA_real_)
      suppressWarnings(as.numeric(l[[col]]))
    }
    ch <- function(col) {
      if (!col %in% colnames(data$livres)) return("")
      c("", sort(unique(na.omit(data$livres[[col]]))))
    }

    div(class = "trio-form",
        fluidRow(
          column(6,
                 div(class = "trio-card trio-card--livre",
                     div(class = "trio-card-header", icon("book-open"), " Le livre"),
                     textInput("admin_modif_titre",  "Titre",  value = g("Titre")),
                     selectizeInput("admin_modif_auteur", "Auteur",
                                    choices = ch("Auteur"), selected = g("Auteur"), options = list(create = TRUE)),
                     fluidRow(
                       column(5, numericInput("admin_modif_date", "Année",
                                              value = gn("Date"), step = 1)),
                       column(7, selectizeInput("admin_modif_genre", "Genre",
                                                choices = ch("Genre"), selected = g("Genre"), options = list(create = TRUE)))
                     ),
                     fluidRow(
                       column(6, selectizeInput("admin_modif_origine", "Pays",
                                                choices = ch("Origine"), selected = g("Origine"), options = list(create = TRUE))),
                       column(6, selectizeInput("admin_modif_ecriture", "Langue",
                                                choices = ch("Ecriture"), selected = g("Ecriture"), options = list(create = TRUE)))
                     ),
                     fluidRow(
                       column(6, numericInput("admin_modif_longueur", "Pages (hist.)",
                                              value = gn("Longueur"), step = 1)),
                       column(6, numericInput("admin_modif_pages", "Pages (livre)",
                                              value = gn("Pages"), step = 1))
                     )
                 )
          ),
          column(6,
                 div(class = "trio-card trio-card--edition",
                     div(class = "trio-card-header", icon("bookmark"), " L'édition"),
                     fluidRow(
                       column(8, selectizeInput("admin_modif_edition", "Editeur",
                                                choices = ch("Edition"), selected = g("Edition"), options = list(create = TRUE))),
                       column(4, numericInput("admin_modif_num_edition", "Numéro",
                                              value = gn("Numéro")))
                     ),
                     selectizeInput("admin_modif_collection", "Collection",
                                    choices = ch("Collection"), selected = g("Collection"), options = list(create = TRUE)),
                     textInput("admin_modif_isbn", "ISBN", value = isbn),
                     fluidRow(
                       column(6, selectizeInput("admin_modif_prefacier", "Préfacier",
                                                choices = ch("Préfacier"), selected = g("Préfacier"), options = list(create = TRUE))),
                       column(6, selectizeInput("admin_modif_traducteur", "Traducteur",
                                                choices = ch("Traducteur"), selected = g("Traducteur"), options = list(create = TRUE)))
                     ),
                     numericInput("admin_modif_prix", "Prix", step = 0.01, value = gn("Prix"))
                 )
          )
        ),
        div(class = "trio-form-btn",
            actionButton("admin_modif_save", "Enregistrer les modifications",
                         icon = icon("floppy-disk"))
        )
    )
  })

  # --- Sauvegarde du modal ---
  observeEvent(input$admin_modif_save, {
    req(is_admin(), input$admin_search_livre, nzchar(input$admin_search_livre))
    isbn_old <- input$admin_search_livre
    idx      <- which(data$livres$ISBN == isbn_old)
    if (length(idx) == 0) return()

    tmp <- data$livres
    s <- function(col, val) {
      if (!col %in% colnames(tmp)) return()
      tmp[idx, col] <<- if (!is.null(val) && !is.na(val) &&
                            nzchar(trimws(as.character(val)))) as.character(val) else NA_character_
    }
    sn <- function(col, val) {
      if (!col %in% colnames(tmp)) return()
      v <- suppressWarnings(as.numeric(val))
      tmp[idx, col] <<- if (!is.null(v) && length(v) > 0 && !is.na(v)) v else NA_real_
    }
    s("Titre",           input$admin_modif_titre)
    s("Auteur",          input$admin_modif_auteur)
    sn("Date",           input$admin_modif_date)
    s("Genre",           input$admin_modif_genre)
    s("Origine",         input$admin_modif_origine)
    s("Ecriture",        input$admin_modif_ecriture)
    sn("Longueur",       input$admin_modif_longueur)
    sn("Pages",          input$admin_modif_pages)
    s("Edition",         input$admin_modif_edition)
    sn("Numéro",    input$admin_modif_num_edition)
    s("Collection",      input$admin_modif_collection)
    s("ISBN",            input$admin_modif_isbn)
    s("Préfacier",  input$admin_modif_prefacier)
    s("Traducteur",      input$admin_modif_traducteur)
    sn("Prix",           input$admin_modif_prix)
    data$livres <- tmp

    removeModal()
    updateSelectizeInput(session, "admin_search_livre", selected = character(0))
  })

  # --- Tableau admin ---
  output$admin_livres_table <- renderDT({
    req(data$livres, is_admin())
    datatable(
      data$livres,
      editable  = list(target = "cell"),
      selection = "multiple",
      rownames  = FALSE,
      filter    = "none",
      class     = "admin-table",
      options   = list(
        pageLength    = -1,
        scrollY       = "calc(100vh - 460px)",
        scrollX       = TRUE,
        scrollCollapse = TRUE,
        dom           = "t"
      )
    )
  }, server = TRUE)

  observeEvent(input$admin_livres_table_cell_edit, {
    req(is_admin())
    data$livres <- editData(data$livres, input$admin_livres_table_cell_edit,
                            "admin_livres_table", rownames = FALSE)
  })

  observeEvent(input$admin_add_row, {
    req(data$livres, is_admin())
    new_row           <- as.data.frame(matrix(NA_character_, nrow = 1, ncol = ncol(data$livres)))
    colnames(new_row) <- colnames(data$livres)
    data$livres       <- rbind(data$livres, new_row)
  })

  observeEvent(input$admin_delete_rows, {
    req(data$livres, is_admin())
    selected <- input$admin_livres_table_rows_selected
    if (length(selected) > 0) {
      data$livres <- data$livres[-selected, ]
    }
  })

  observeEvent(input$admin_download_btn, {
    req(is_admin())
    showModal(modalDialog(
      title = tagList(icon("download"), " Télécharger la base de données"),
      p("Choisissez le format d'export :", style = "font-family: var(--font); color: var(--text); margin-bottom: 16px;"),
      div(style = "display: flex; gap: 12px; justify-content: center;",
          downloadButton("admin_dl_xlsx", ".xlsx \u2014 Excel",    class = "bouton"),
          downloadButton("admin_dl_csv",  ".csv \u2014 Universel", class = "btn-header-login")
      ),
      easyClose = TRUE,
      footer = modalButton("Fermer")
    ))
  })



  output$admin_dl_xlsx <- downloadHandler(
    filename = function() paste0("livres_", Sys.Date(), ".xlsx"),
    content  = function(file) {
      wb <- openxlsx::createWorkbook()
      openxlsx::addWorksheet(wb, "livres")
      openxlsx::writeData(wb, "livres", data$livres, colNames = TRUE)
      openxlsx::saveWorkbook(wb, file, overwrite = TRUE)
    }
  )

  output$admin_dl_csv <- downloadHandler(
    filename = function() paste0("livres_", Sys.Date(), ".csv"),
    content  = function(file) write.csv(data$livres, file, row.names = FALSE, fileEncoding = "UTF-8")
  )

  observeEvent(input$admin_save, {
    req(data$livres, is_admin())
    wb_admin <- createWorkbook()
    addWorksheet(wb_admin, "library")
    writeData(wb_admin, "library", data$livres, colNames = TRUE)
    s3_write_xlsx(wb_admin, link_to_livres)
    showModal(modalDialog(
      title     = tagList(icon("check-circle"), " Sauvegarde réussie"),
      "La base de données centrale des livres a bien été enregistrée sur S3.",
      easyClose = TRUE,
      footer    = modalButton("Fermer")
    ))
  })

  observeEvent(input$chatbot_input_val, {
    req(input$chatbot_input_val)
    user_msg <- input$chatbot_input_val

    history <- chat_history()
    history <- append(history, list(
      list(role = "user", parts = list(list(text = user_msg)))
    ))

    reply <- tryCatch(
      gemini_chat(history),
      error = function(e) {
        if (grepl("429", e$message)) {
          "Trop de requêtes, patiente quelques secondes."
        } else {
          paste("Erreur :", e$message)
        }
      }
    )

    history <- append(history, list(
      list(role = "model", parts = list(list(text = reply)))
    ))
    chat_history(history)
  })


}


# ==============================================================================
#                           Lancement de l'application
# ==============================================================================

shinyApp(ui = ui, server = server)

