library(dplyr)
library(lubridate)
library(RMongo)
library(rjson)

# log console
print(paste(now(), "Starting cache refresh"))

# db info
host <- "127.0.0.1"
#port <- "27014"
port <- "27017"

if(file.exists("top.Rda")) {
	topData <-readRDS("top.Rda")
} else {
	topData <- list(um =0, pr=0)
}


# for grabbing just the url title
titlegrabber <- function(t_url, um) {
	result <- filter(um, url==t_url)$title
		if(length(result)>0){
			result <- as.character(result)
		} else {
			result = "NA"
		}
	result
}

# for finding out the amount of data in pingrecords collection and setting the skip value for a mongo query.
# note, with a simple mongo.collection.count() this would be unnecessary, but could not find the way to do this in RMongo
findTop <- function(host, port, collection, top, limit){
	mongo2 <- mongoDbConnect('twitter-velocity', host=host, port=port)
		count <- 0
		steps <- 15
		i_top <- steps + log(top, 1.1)
		i <- i_top
		while( count == 0 & i >= i_top-steps+1) {
			count <- nrow(dbGetQuery(mongo2, collection,'{}', skip=1.1^i, limit=100000))
				i <- i-1
		}
	dbDisconnect(mongo2)
		round((1.1^i)+count)
}

fetchDataFromDB <- function(host, port, collection, skip, limit){
	mongo <- mongoDbConnect('twitter-velocity', host=host, port=port)
		d <- dbGetQuery(mongo, collection,'{}', skip=skip, limit=limit)
		dbDisconnect(mongo)
		d
}


limit_pr <- 50000 # do not load more than 100K rows from mongo
top_pr <- findTop(host, port, 'pingrecords', topData$pr, limit_pr)# ensure that nrow in cache + limit_pr is enough 
	skip_p <- top_pr - limit_pr
skip_p <- ifelse(skip_p >=0, skip_p, 0)
# fetch new share data from db
pingrecords <- fetchDataFromDB(host, port, 'pingrecords', skip_p, 1.5*limit_pr) 

# log console
print(paste(now(), "Loaded pingrecords", nrow(pingrecords),"rows"))


# clean and format data
pingrecords$timestamp <- gsub('([a-z]{3} [a-z]{3} [0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}) (?:[a-z]{3}|[a-z]{4})( [0-9]{4})', '\\1\\2', pingrecords$timestamp,  ignore.case=TRUE)
pingrecords$timestamp <- as.POSIXct(pingrecords$timestamp, format="%a %b %d %H:%M:%S %Y")
pingrecords$tweet_id <- as.factor(pingrecords$tweet_id)
pingrecords <- mutate(pingrecords, url_short = as.factor(substr(url, 1,35)))
pingrecords$url_short <- as.factor(pingrecords$url_short)
pingrecords$nameList <- as.factor(pingrecords$nameList)


# set parameters for url metadata query
limit_um <- 10000
top_um <- findTop(host, port, 'urlmetadatas', topData$um, limit_um)# ensure that nrow in cache + limit_pr is enough 
skip_u <- top_um - limit_um
skip_u <- ifelse(skip_u >=0, skip_u, 0)

# fetch new url metadata from db
urlmetadatas <- fetchDataFromDB(host, port, 'urlmetadatas', skip_u, 1.5*limit_um) 

# console log
print(paste(now(), "Loaded url metadata", nrow(urlmetadatas),"rows"))

# clean and format data
urlmetadatas <- cbind(urlmetadatas, do.call(rbind.data.frame, lapply(urlmetadatas$meta, fromJSON)))
urlmetadatas <- select(urlmetadatas, url:rel_publisher)
urlmetadatas$og_image <- as.character(urlmetadatas$og_image)
urlmetadatas$og_image[urlmetadatas$og_image == "NA" | is.na(urlmetadatas$og_image)] <- 'https://dl.dropboxusercontent.com/u/19642517/white.png'
urlmetadatas[urlmetadatas == "NA"] <- NA

# add url title variable to share data
pr_titles <- lapply(pingrecords$url, function(x) titlegrabber(x, urlmetadatas))
pingrecords$title <- unlist(pr_titles)
rm("pr_titles")
pingrecords$title[pingrecords$title == "NA"] = NA
pingrecords <- mutate(pingrecords, title_short = as.factor(substr(title, 1,40)))
pingrecords$title_short <- as.factor(pingrecords$title_short)
pingrecords <- pingrecords %>% select(timestamp, velocity:title_short)

topData <- list(um = skip_u + nrow(urlmetadatas), pr = skip_p + nrow(pingrecords))

# print stats to console
print(paste(now(), "Total rows in db", topData))

print(paste(now(), "First row in pingrecords:"))
first_row <- pingrecords %>% arrange(timestamp) %>% head(1)
first_row[1] %>% as.character %>% as.numeric %>% as.POSIXct(origin="1970-01-01",tz="BST") %>% print
first_row %>% paste %>% print

print(paste(now(), "Last row in pingrecords:"))
last_row <- pingrecords %>% arrange(desc(timestamp)) %>% head(1)
last_row[1] %>% as.character %>% as.numeric %>% as.POSIXct(origin="1970-01-01",tz="BST") %>% print
last_row %>% paste %>% print

# save to cache
saveRDS(pingrecords, "pr.Rda")
saveRDS(urlmetadatas, "um.Rda")
saveRDS(topData, "top.Rda")

# print to console
print(paste(now(), "cache refreshed"))
