library(shiny)
library(ggplot2)
    

    shinyUI(fluidPage(
		#tags$head(tags$script(src = "message-handler.js")),

		tags$head(includeScript("google-analytics.js")),
		title = "Content Trend Explorer and Forecaster",
		fluidRow(
		    column(4,
			selectInput("select", label = h4("Narrow Down to Content Items Shared by"), 
			    choices = list("All",
				"Journalism & Politics Tweeters",
				"Data & CS Tweeters",
				"Tech Media"))),
		    column(2,
			h4("Step 0. Data"),
			actionButton("data", label = "Refresh"),
			br()
			),
		    column(2,
			uiOutput("Box1")
			),
		    column(2,
			h4("The Mind Boggles"),
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
			    h5('Selected share threshold and cap:',
				textOutput("oid1", container=span))

			    ),
			column(2,
			    sliderInput('minsharevel', 'Min Threshold Share Velocity (shares/hr)',value = 25, min = 0, max = 200, step = 1)

			    ),
			column(2,
			    sliderInput('hours_back', 'Timeline: Plot End & Start Points (hrs ago)',value = c(0,4), min = 0, max = 36, step = 1)
			    ) 

			),
		br(), 
		h3("Step 2. Review Selected Content"),
		actionButton("action", label = "Manually Fetch & Refresh Top 10 List of Items Selected"),
		tableOutput("table")
		))

