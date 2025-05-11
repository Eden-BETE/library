
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


# ==============================================================================
#                            Définition des chemins
# ==============================================================================

setwd(dirname(rstudioapi::getActiveDocumentContext()$path))


# ==============================================================================
#                              Lecture des données
# ==============================================================================


