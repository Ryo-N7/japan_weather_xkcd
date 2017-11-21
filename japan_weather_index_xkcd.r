# Japan weather comfort index 
# >>> which city is most comfortable??

library(riem)
library(dplyr)
library(ggplot2)


riem_stations(network = "JP__ASOS")
# ID is the ICAO code > IATA


# source busiest Japanese airports (total passenger traffic) from Wikipedia:
# https://en.wikipedia.org/wiki/List_of_the_busiest_airports_in_Japan
# 

library(rvest)

# NOTE: 2015 data.
url <- "https://en.wikipedia.org/wiki/List_of_the_busiest_airports_in_Japan"

# css selector: "table.wikitable:nth-child(10)"

japan_airports <- url %>% read_html() %>% 
  html_node("table.wikitable:nth-child(10)") %>% 
  html_table()

glimpse(japan_airports)

# Separate IATA and ICAO codes:
library(tidyr) # use separate() function!

japan_airports <- japan_airports %>% 
  separate(`IATA/ICAO`, c("IATA", "ICAO"), "\\/")

japan_airports <- japan_airports %>% rename(City = `City\nserved`)

glimpse(japan_airports)

# save our handy dataset so not have to re-run web scraping every time!
write.csv(japan_airports, "~/R_materials/japan_weather_xkcd/japan_airports.csv")

japan_airports <- read.csv("~/R_materials/japan_weather_xkcd/japan_airports.csv", 
         stringsAsFactors = FALSE)

# 47 prefectures, top 50 airports, let's just start by looking at the weather data for all
# of them instead of taking only top 25/10/whatever airports.

jp_airport_codes <- japan_airports %>% select(Airport, City, ICAO)

# taking code from Maelle Salmon's post 
# >>> use purrr::map_df to call riem::measures on each airport code!
library(purrr)

# big file, will take a minute or so!
summer_weather <- map_df(jp_airport_codes$ICAO, riem::riem_measures,
                                date_start = "2017-06-01",
                                date_end = "2017-08-31")

write.csv(summer_weather, "~/R_materials/japan_weather_xkcd/summer_weather.csv")
# BIG FILE

winter_weather <- map_df(jp_airport_codes$ICAO, riem::riem_measures,
                                date_start = "2016-12-01",
                                date_end = "2017-02-28")

write.csv(winter_weather, "~/R_materials/japan_weather_xkcd/winter_weather.csv")


glimpse(summer_weather)

# Look more closely at dataset: 
# Recalculate in CELSIUS using weathermetrics package
library(weathermetrics)


summer_weather <- summer_weather %>% 
                    mutate(tmpc = convert_temperature(tmpf,
                                                      old_metric = "f", 
                                                      new_metric = "c"),
                           dwpc = convert_temperature(dwpf,
                                                      old_metric = "f",
                                                      new_metric = "c"))

winter_weather <- winter_weather %>% 
  mutate(tmpc = convert_temperature(tmpf,
                                    old_metric = "f", 
                                    new_metric = "c"))

# calculate the Humidex with the calcHumx() function in the comf package!
library(comf)

summer_weather <- summer_weather %>% 
                    mutate(humidex = calcHumx(ta = tmpc, rh = dwpc))

summer_data <- summer_weather %>% 
                 group_by(station) %>% 
                 summarize(summer_humidex = mean(humidex, na.rm = TRUE))

winter_data <- winter_weather %>% 
                 group_by(station) %>% 
                 summarize(winter_avg_temp = mean(tmpc, na.rm = TRUE))

# join together:

climate_japan <- left_join(summer_data, winter_data, by = "station")

glimpse(climate_japan)

# add in city names through airport code data set
climate_japan <- left_join(climate_japan, jp_airport_codes,
                           by = c("station" = "ICAO"))

glimpse(climate_japan)
# hmm remove Narita as not really TOKYO >>> far out in Chiba
# Haneda is more representative of Tokyo's weather, although it is stuck out in Tokyo Bay

# Remove Narita airport observation row
climate_japan <- climate_japan %>% filter(station != "RJAA")

glimpse(climate_japan)

# Ibaraki Aiport from Tokyo to Ibaraki
climate_japan$City[climate_japan$station == "RJAH"] <- "Ibaraki"

glimpse(climate_japan)

# just use CITY as the labels instead or clog up the graph...
# climate_japan <- climate_japan %>% unite(Label, City, Airport, sep = " - ", remove = TRUE)

glimpse(climate_japan)

# Install XKCD font! ####

library(extrafont)
library(ggplot2)

download.file("http://simonsoftware.se/other/xkcd.ttf", destfile = "xkcd.ttf", mode = "wb")

system("mkdir ~/.fonts")

system("cp xkcd.ttf ~/.fonts")

font_import(pattern = "[X/x]kcd", prompt = FALSE)

fonts()

fonttable()

if(.Platform$OS.type != "unix") {
  loadfonts(device = "win")
} else {
  loadfonts()
}

windowsFonts()


# Plotting! ####
library(xkcd)
library(ggplot2)
library(extrafont)
library(ggrepel)

xrange <- range(climate_japan$summer_humidex)
yrange <- range(climate_japan$winter_avg_temp)

set.seed(42)

climate_japan %>% 
  ggplot(aes(summer_humidex, winter_avg_temp)) +
  geom_point() +
  geom_text_repel(aes(label = City), 
                  family = "xkcd",
                  max.iter = 50000) +
  ggtitle("Where to live based on your temperature preferences",
          subtitle = "Data from airport weather stations 2016-2017") +
  xlab("Humidex: summer heat & humidity") +
  ylab("Avg. winter temperature - Celsius") +
  xkcdaxis(xrange = xrange,
           yrange = yrange) +
  theme_xkcd() +
  theme(text = element_text(size = 16, family = "xkcd"))

























