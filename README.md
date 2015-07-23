# shinyapp
Dashboard to explore content trending in social media for RStudio Shiny Server.  

In addition to the normal shiny app server.R and ui.R files, we have data-daemon.R where we load data from db, clean it and save it as a RDS file for the server.R to load when user enters the site. In order to keep the data current the data-daemon needs to be running periodically in the background on the server.

This app does not contain the server that collects the data.
