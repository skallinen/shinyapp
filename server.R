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

# function that reloads the data
reloadData <- function(){
	pr <- readRDS("pr.Rda")
	um <- readRDS("um.Rda")
        list("pr" = pr,"um" = um)
}

# mapping for 
sharer_sources_map <- list(c(1,2,3),1,2,3)
names(sharer_sources_map) <- c("All","Journalism & Politics Tweeters",
                      "Data & CS Tweeters",
                      "Tech Media")

extractForecastData <- function(fcast, ts) {
        tf <- time(fcast$x)
        tf_start <- min(tf)
        tf_end <- max(tf)

        
        to_start <- min(time(ts))
        to_end <- max(time(ts))
        
        step <- (as.numeric(to_end)-as.numeric(to_start))/(as.numeric(tf_end)-as.numeric(tf_start))
        o_time <- fit_time <- lapply(time(ts), function(x) as.POSIXct(as.numeric(x), origin="1970-01-01 UTC", tz="UTC"))

        dt <- data.frame(timestamp=unlist(o_time), count=ts)
        dt$type <- factor("observed")
        
        
        fit_time <- as.numeric(time(tf))*step+as.numeric(to_start)
        fit_time <- as.POSIXct(fit_time, 
                               origin="1970-01-01 UTC", 
                               tz="UTC")
        fit <- data.frame(timestamp=as.POSIXct(fit_time),count=as.numeric(fcast$fitted))
        fit$type <- factor("fitted")        
        dt <- rbind(dt,fit)
        dt$forecast <- NA
        dt$lo80 <- NA
        dt$hi80 <- NA
        dt$lo95 <- NA
        dt$hi95 <- NA
        
        dffcst<-data.frame(fcast)
        dffcst$timestamp<-as.numeric(rownames(dffcst))
        dffcst$timestamp <- as.numeric(dffcst$timestamp)*step+as.numeric(to_start)
        dffcst$timestamp <- as.POSIXct(dffcst$timestamp, 
                   origin="1970-01-01 UTC", 
                   tz="UTC")
        names(dffcst)<-c('forecast',
                         'lo80',
                         'hi80',
                         'lo95',
                         'hi95',
                         'timestamp')
        dffcst$type <- NA
        dffcst$count <- NA
#        dffcst <- select(dffcst,timestamp,count,type,forecast,lo80,hi80,lo95,hi95)
        
        dtm<-rbind(dt,dffcst)
        dtm$timestamp <- as.POSIXct(dtm$timestamp, 
           origin="1970-01-01 UTC", 
           tz="UTC")
        dtm
        
}



calculateSingleUrl <- function(f_title, pr) {
        pr_sel <- pr %>% filter(title == f_title)
        pr_sel$url <- as.factor(pr_sel$url)
        occurances <- table(pr_sel$url)
        o <- data.frame(occurances)
        o <- o %>% filter(Freq == max(occurances))
        pr_sel <- pr_sel %>% filter(url == o$Var1)
        pr_fc <- select(pr_sel, timestamp, shareCount) %>% arrange(timestamp)
        #"timestamp"   "velocity"    "nameList"    "url"         "shareCount" 
        #[6] "url_short"   "title"       "title_short"
#	if(nrow(pr_fc) > 50) {
		cat(paste("Size\n", dim(pr_fc)), file=stderr())
	        ts <- xts(pr_sel$shareCount, order.by = pr_sel$timestamp ) 
	        fit <- ets(ts,model="ZZZ")
	        fcast <- forecast(fit, h=4)
                d <- extractForecastData(fcast, ts)
#	} else {
#		d <- pr_fc 

#	}
        d
}
helpPopup <- function(title, content,
                      placement=c('right', 'top', 'left', 'bottom'),
                      trigger=c('click', 'hover', 'focus', 'manual')) {
tagList(
   singleton(
      tags$head(
        tags$script("$(function() { $(\"[data-toggle='popover']\").popover(); })")
      )
    ),
    tags$a(
      href = "#", class = "btn btn-mini", `data-toggle` = "popover",
      title = title, `data-content` = content, `data-animation` = TRUE,
      `data-placement` = match.arg(placement, several.ok=TRUE)[1],
      `data-trigger` = match.arg(trigger, several.ok=TRUE)[1],
      
      tags$i(class="icon-question-sign")
    )
  )
}


shinyServer(
        
        function(input, output, session) {
                hourstart <- reactive({now()-hours(input$hours_back[2])})
                hourend <- reactive({now()-hours(input$hours_back[1])})
               

		options(digits.secs = 3) # Include milliseconds in time display


		output$currentTime <- renderText({
		# invalidateLater causes this output to automatically
		# become invalidated when input$interval milliseconds
		# have elapsed
			invalidateLater(1000, session)
			format(Sys.time(), "%H:%M:%S")
			})

 
                sharedata <-  eventReactive(input$data, {
                        reloadData()
                })
#		output$Box1 = renderUI(selectInput("sector","select a sector",c(unique(url_selection()$title),"pick one"),"pick one"))

		output$Box1 = renderUI(
				if (is.null(url_selection())){return()
				}else selectInput("single", 
					"Search, isolate and forecast individual items", 
					c(unique(url_selection()$title),"pick one item"),
					"pick one item")
				)                
                sources <- reactive({sharer_sources_map[[input$select]]})
                url_selection <- reactive({filter(sharedata()$pr,
                                                  timestamp > hourstart(),
                                                  timestamp < hourend(),
                                                  as.integer(nameList) %in% sources(),
                                                  !grepl('https://twitter.com.*',
                                                         url),
                                                  shareCount > 10^input$range[1],
                                                  shareCount < 10^input$range[2],
                                                  velocity > input$minsharevel)  %>% 
                                                  arrange(desc(shareCount)) %>%
                                                  head(150*(input$hours_back[2]-input$hours_back[1]))
                })
		forecasting <- reactive({ calculateSingleUrl(input$single,sharedata()$pr) })
		output$newPlot <- renderPlot({
				if (!is.null(input$single) & input$single != "pick one item"){
						input$single
						singleU <- isolate(forecasting())
#						if(ncol(forecasting()> 2)) {
							ggplot(data=singleU, aes(x=timestamp, y=count, col=type)) + 
        						geom_line()+
        						geom_ribbon(aes(x=timestamp, ymin=lo95,ymax=hi95),alpha=.1)+
        						geom_ribbon(aes(x=timestamp,ymin=lo80,ymax=hi80),alpha=.1)+
        						geom_line(aes(y=forecast))
#							}else{
#							qplot(x=forcasting()$timestamp, y=forcasting()$shareCount)
#							}
						}else{

			
                        p<- ggplot(url_selection(), 
                               aes(x=timestamp,
                                   y=shareCount,
                                   colour=title_short,
                                   group=title_short)) +
                                geom_line() +
                                geom_point() + 
                                ggtitle("URL Share Count on Twitter")
                        nurls <- length(unique(url_selection()$url))
                        if(nurls >20 ) p <- p + theme(legend.position="none")

                        p

        }
                })
                output$oid1 <- renderText({c(round(10^as.numeric(input$range[1]),0), 
                                             'and',
                                             round(10^as.numeric(input$range[2]),0)
					)})	
                
               
                 
		observeEvent(input$help, {
	})

               
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
