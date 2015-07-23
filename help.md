

----

Help: Tactical Content Trend Explorer and Forecaster  
===========================

## The Slide Deck
Please check out the [slide deck] (http://skallinen.github.io/assignment_deck) about this project made as part of a Coursera course on Developing Data Products.

### Disclaimer

This is a proof of concept that still contains some bugs, but can be used nonetheless. Please have patience.  

What it does?
-----------
Let's you explore data about how different **content items are shared** on social media. The data is collected in real time from Twitter, and made available for the app in near real-time. You can use different filters and explore different aspects of the trending item. **Filters** include the following:  
- Defining **minimum and maximum** values for item **share count**.  
- Defining **share velocity**, ie. how many times the url has been shared per hour.  
- Defining **time period** by setting how many hours will be displayed.  
- Selecting **sources**. Narrow down the selection to certain predefined **types of tweeters**.  
- From the narrowed down selection you can pick one item and **isolate** its trend plus **forecast** how it will be shared in the future.  

----

How to use it?
-------
**Step 0**  

Start by loading the data. You can use the same button to refresh it. The backend will provide a new batch every 10 minutes.  

**Step 1**  

Use the filters to find a batch of items that you interested in. By toying with the filters you can isolate content items that are extremely popular or that are bubbling under, about to hit big. Use the "Search, isolate and forecast individual items" list to examine a particular item more closely.  

*Pro tip:*  
If you want to have finer controls in the filters you can use the keyboard arrow buttons on the slider controls.

**Please note**
that the legend listing the titles of the urls is shown only when they can fit the screen, i.e. when you have narrowed down the selection to 20 or less urls.




**Step 2**  

Pring out a list of the selected items at the bottom including link, short description and image, when availalbe. You can do this by clicking the "Review Selected Content" button below. Loading the content might take a moment.  

Forecasting
---------------------
The forecasting feature is experimental. We are using exponential smoothing from the forecast R-package with all settings on automatic. We are plotting both observed and fitted values, as well as the calculated forecast including both 95% and 80% confidence intervals.


Have fun!

------------

To do
----
- Fix "argument is of length zero" bug.
- Fix Top10 visually.
- Enable user to explore the content item (like in top10) directly from the forecast.

