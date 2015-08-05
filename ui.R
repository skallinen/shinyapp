library(shiny)
library(ggplot2)
    

    shinyUI(fluidPage(

    tags$head(includeScript("google-analytics.js"),
		    tags$style(HTML("
@import url('http://fonts.googleapis.com/css?family=Lato&subset=latin,latin-ext');
      h1,h2,h3,h4 {
	font-family: 'Lato', sans-serif;
      }
body {
	font-family: 'Lato', sans-serif;
    background-color: #DBF5F8;
}

    "))
),
    title = "Tactical Content Trend Explorer and Forecaster",
    fluidRow(
      column(3,
	h1(textOutput("currentTime"))
        ),
      column(3,
	br(),
        selectInput("select", label = strong("Items Shared by"), 
          choices = list("All",
            "Journalism & Politics Tweeters",
            "Data & CS Tweeters",
            "Tech Media"))),
      column(3,
	br(),
        uiOutput("Box1")
        ),
      column(2,
	br(),
        strong("The Mind Boggles"),
	br(),
        checkboxInput("help", "Show/Hide Help", FALSE),
        br()
        )
      ), 
    conditionalPanel(
        condition = "input.help == true",
        includeMarkdown("help.md")
        ),
    plotOutput('newPlot'),

		hr(),

		fluidRow(
			column(2,
			    h3("Step 1.",
				br(),
				"Real-Time Content Explorer")
			    ),
			column(2,
			    sliderInput('range', 'Share Count Min & Cap (log base 10 slider)',value = c(1.4,3), min = 1.4, max = 5, step = 0.01),
			    h5('Currently selected share threshold and cap:',
				textOutput("oid1", container=span))

			    ),
			column(2,
			    sliderInput('sharevel', 'Threshold Share Velocity (shares/hr)',value = c(25,200), min = 0, max = 200, step = 1)

			    ),
			column(2,
			    sliderInput('hours_back', 'Timeline: Plot End & Start Points (hrs ago)',value = c(0,12), min = 0, max = 36, step = 1)
			    ) 

			),
		br(), 
		h3("Step 2. Review Selected Content"),
		actionButton("action", label = "Manually Fetch & Refresh Top 10 List of Items Selected"),
		h4("Loading the content takes a moment, thank you for your patience..."),
		tableOutput("table")
		))

