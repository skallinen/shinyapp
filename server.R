library(dplyr)
library(ggplot2)
library(lubridate)
library(RMongo)
library(rjson)
library(forecast)
library(xts)

# db info
host <- "127.0.0.1"
#port <- "27014"
port <- "27017"

# shiny app directory
setwd("/srv/shiny-server/shinyapp/")


########
# function used to retrieve url metadata 
metagrabber <- function(t_url, um) {
        um_c <- lapply(um, as.character) %>% data.frame
        result <- filter(um_c, url==t_url)
        if(nrow(result)==0){
                result = c(t_url,replicate(15, NA))
                names(result)<- names(um)
        }
        result <- lapply(result, as.character)
        if(is.na(result$og_image)) result$og_image <- "https://dl.dropboxusercontent.com/u/19642517/white.png"
        result
}


########
# reload data
reloadData <- function(){
	pr <- readRDS("pr.Rda")
	um <- readRDS("um.Rda")
        list("pr" = pr,"um" = um)
}


########
# mapping for sources 
sharer_sources_map <- list(c(1,2,3),1,2,3)
names(sharer_sources_map) <- c("All","Journalism & Politics Tweeters",
                      "Data & CS Tweeters",
                      "Tech Media")

########
# extracting forecast data from broadcast object to use with ggplot
extractForecastData <- function(forecast, timeseries) {
	ts <- timeseries; fcast <- forecast # the data & the forecast object
        tf <- time(fcast$x) # extracting the time data of observations in forecast model 
        tf_start <- min(tf) # finding the start time, need it to syncronize times
        tf_end <- max(tf) # end data

        
        to_start <- min(time(ts)) # timeseries starting point
        to_end <- max(time(ts)) # end point
        
	# timesteps in fcast object
        step <- (as.numeric(to_end)-as.numeric(to_start))/(as.numeric(tf_end)-as.numeric(tf_start)) 
        o_time <- fit_time <- lapply(time(ts), function(x) as.POSIXct(as.numeric(x), origin="1970-01-01 UTC", tz="UTC"))

	# starting to build the responce data frame
        dt <- data.frame(timestamp=unlist(o_time), count=ts) 
        dt$type <- factor("observed")
        
        # "timestamps" of the fitted data & convertine the time
        fit_time <- as.numeric(time(tf))*step+as.numeric(to_start) 
        fit_time <- as.POSIXct(fit_time, 
                               origin="1970-01-01 UTC", 
                               tz="UTC")
        fit <- data.frame(timestamp=as.POSIXct(fit_time),count=as.numeric(fcast$fitted)) 
        fit$type <- factor("fitted")        
        dt <- rbind(dt,fit) # add the fitted time to the response

	# add columns to match all the variables in forecast data
        dt$forecast <- NA 
        dt$lo80 <- NA
        dt$hi80 <- NA
        dt$lo95 <- NA
        dt$hi95 <- NA
        
	# format forecast data
        dffcst<-data.frame(fcast)
	# converting time variables in forecast object into "normal" time
        dffcst$timestamp<-as.numeric(rownames(dffcst)) 
        dffcst$timestamp <- as.numeric(dffcst$timestamp)*step+as.numeric(to_start)
        dffcst$timestamp <- as.POSIXct(dffcst$timestamp, 
                   origin="1970-01-01 UTC", 
                   tz="UTC")
	# formating the data frame
        names(dffcst)<-c('forecast',
                         'lo80',
                         'hi80',
                         'lo95',
                         'hi95',
                         'timestamp')
        dffcst$type <- NA
        dffcst$count <- NA

        # combine the observed, fitted and the forecast data 
        dtm<-rbind(dt,dffcst)
	# format timestamp variable
        dtm$timestamp <- as.POSIXct(dtm$timestamp, 
           origin="1970-01-01 UTC", 
           tz="UTC")
	# return the result
        dtm
        
}


#######
# Formating the data for plotting a single item and calculating the forecast
calculateSingleUrl <- function(f_title, pr) {
	# fitering by title to select the required item
        pr_sel <- pr %>% filter(title == f_title)
	# quick fix: since same title can occur many times, with similar timestamps
	# due to different sources and slight variation in url parameters, 
	# breaking the conversion into a timeseries object. selecting the one with 
	# the most entries  
        pr_sel$url <- as.factor(pr_sel$url)
        occurances <- table(pr_sel$url)
        o <- data.frame(occurances)
        o <- o %>% filter(Freq == max(occurances))
        pr_sel <- pr_sel %>% filter(url == o$Var1)
	# dropping all variables but the timestamp and shareCount
        pr_fc <- select(pr_sel, timestamp, shareCount) %>% arrange(timestamp)
#	if(nrow(pr_fc) > 50) {
		cat(paste("Size\n", dim(pr_fc)), file=stderr())
		# here the magic starts! converting the data to a time-series object
	        ts <- xts(pr_sel$shareCount, order.by = pr_sel$timestamp ) 
		# fitting the model, using exponential smootihg with automatic settings
	        fit <- ets(ts,model="ZZZ")
		# using the model to create the forecast
	        fcast <- forecast(fit, h=4) # magic ands <-
		# reformat the data so that ggplot will eat it.
                d <- extractForecastData(fcast, ts)
#	} else {
#		d <- pr_fc 

#	}
	# returning the data
        d
}

#######
# here the main action happens
shinyServer(
        
        function(input, output, session) {
		# get the time variables for the plot
                hourstart <- reactive({now()-hours(input$hours_back[2])})
                hourend <- reactive({now()-hours(input$hours_back[1])})

		# display current server time to the user (need to localize this)			
		output$currentTime <- renderText({
			invalidateLater(1000, session)
			format(Sys.time(), "%H:%M:%S")
			})

 		# reload the latest data every 5 minutes
		sharedata <- reactive({
			invalidateLater(300000, session)
			reloadData()
		})

		# render individual item & forcasting ui selector
		output$Box1 = renderUI(
				if (is.null(url_selection())){return()
				}else selectInput("single", 
					"Forecast individual items", 
					c(unique(url_selection()$title),"pick one item"),
					"pick one item")
				)

		# get sources from ui selector               
                sources <- reactive({sharer_sources_map[[input$select]]})

		# filter the data according to ui slider inputs
                url_selection <- reactive({pr_sel <- sharedata()$pr
				#	if (!is.null(input$single) ) {
				#		if( input$single != "pick one item") pr_sel <- pr_sel %>% filter(title == input$single)
				#	}
					   filter(pr_sel,
                                                  timestamp > hourstart(),
                                                  timestamp < hourend(),
                                                  as.integer(nameList) %in% sources(),
                                                  !grepl('https://twitter.com.*',
                                                         url),
                                                  shareCount > 10^input$range[1],
                                                  shareCount < 10^input$range[2],
                                                  velocity > input$sharevel[1],
                                                  velocity < input$sharevel[2])  %>% 
                                                  arrange(desc(shareCount)) %>%
                                                  head(150*(input$hours_back[2]-input$hours_back[1]))
                })

		# get the individual item with forecast
		forecasting <- reactive({ calculateSingleUrl(input$single,sharedata()$pr) })

		# render the plots
		output$newPlot <- renderPlot({
				# are we going to plot the indivudual item?
				if (!is.null(input$single) & input$single != "pick one item"){
						input$single
						singleU <- isolate(forecasting())
#						if(ncol(forecasting()> 2)) {
							ggplot(data=singleU, aes(x=timestamp, y=count, col=type)) + 
        						geom_line()+
        						geom_ribbon(aes(x=timestamp, ymin=lo95,ymax=hi95),alpha=.1)+
        						geom_ribbon(aes(x=timestamp,ymin=lo80,ymax=hi80),alpha=.1)+
        						geom_line(aes(y=forecast))+ 
        						theme(plot.background = element_rect(fill = '#DBF5F8', 
                                             		colour = '#DBF5F8'))
#							}else{
#							qplot(x=forcasting()$timestamp, y=forcasting()$shareCount)
#							}
						}else{

						# or are we going to plot the main panel?
                        			p<- ggplot(url_selection(), 
                               				   aes(x=timestamp,
                                	                       y=shareCount,
                                   	                       colour=title_short,
                                   	                       group=title_short)) +
                                	  		   geom_line() +
                               		 		   geom_point() + 
                                			ggtitle("Content Items")+ 
        						theme(plot.background = element_rect(fill = '#DBF5F8', 
                                             		colour = '#DBF5F8'))

                        			nurls <- length(unique(url_selection()$url))
						# print legend only if the items fit on the panel
                        			if(nurls >20 ) p <- p + theme(legend.position="none")
						# print the plot
                        			p

        					}
                		})

		# print out the share count selector values in noraml numbers
                output$oid1 <- renderText({c(round(10^as.numeric(input$range[1]),0), 
                                             'and',
                                             round(10^as.numeric(input$range[2]),0)
					)})	
                
               
                # presse clicked help? 
		observeEvent(input$help, {
		})

               # printing the item list at the bottom of the page
                item_list_c <- eventReactive(input$action, { url_selection() })
                
                output$table <- renderTable({
                        item_list <- item_list_c()
                        item_list$url <- as.factor(item_list$url)
                        item_list <- group_by(item_list, url) %>%
                                mutate(shareStart=shareCount) %>% 
                                summarise(shareCount = max(shareCount),
                                          shareStart=min(shareStart)) %>%
                                arrange(desc(shareCount))
                        item_urls <- unique(item_list$url) %>%
                                as.character %>%
                                head(10) %>%
                                unlist
                        Content <- lapply(item_urls, 
                                          function(url) paste0("<div style='padding-left: 10px;'><a href='",
                                                               url,
                                                               "' target='_blank'><img src='",
                                                               metagrabber(url,sharedata()$um)[[7]],
                                                               "' style='float: left; margin-right:10px;' width='180'><h2>", 
                                                               metagrabber(url,sharedata()$um)[[3]] ,
                                                               "</h2></div><p style='float: left;'>",
                                                               substr(metagrabber(url, sharedata()$um)[[4]], 1,250),
                                                               "</p></a>"))
                        
                        Content <- data.frame(Content) %>% t %>% data.frame
                        rownames(Content) <- 1:nrow(Content)
                        names(Content)[1] <- "Top 10 Content at this moment"
                        Content
                        
                        
                }, sanitize.text.function = function(x) x)
               
        }
)
