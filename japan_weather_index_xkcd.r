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

# SAVE our handy dataset so not have to re-run web scraping every time! ####
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

# READ IN DATA >>> DONT RERUN RIEM CODE EVERY TIME ####

summer_weather <- read.csv("summer_weather.csv", stringsAsFactors = FALSE)
winter_weather <- read.csv("winter_weather.csv", stringsAsFactors = FALSE)

glimpse(summer_weather)
glimpse(winter_weather)


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

# Remove Kansai International >>> handles all internatonal flights, ~20 miles away from Osaka
climate_japan <- climate_japan %>% filter(station != "RJBB")

glimpse(climate_japan)

# Ibaraki Aiport from Tokyo to Ibaraki
climate_japan$City[climate_japan$station == "RJAH"] <- "Ibaraki"
# Kochi, Kochi to just Kochi
climate_japan$City[climate_japan$station == "RJOK"] <- "Kochi"

glimpse(climate_japan)

# just use CITY as the labels instead or clog up the graph...
# climate_japan <- climate_japan %>% unite(Label, City, Airport, sep = " - ", remove = TRUE)

glimpse(climate_japan)

# Iwakuni appears twice for some reason...
climate_japan <- climate_japan %>% unique()




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

# need to fix city text >>> elongation vowels symbols in text
# >>> 12 hours later, rerun, elongation vowels not in anymore???

# oddly, the graph looks like a map of Japan... with cities in Hokkaido in the bottom right 
# instead of the top right, vice-versa for Okinawa!
# >>> see this much better on a bigger screen: screenshot



# MAP of JAPAN:
library()

# acquire lon-lat of Japan from map_data()
JPN <- map_data(map = "world", region = "Japan")

# join lon-lat data into climate_japan
lat_lon <- summer_weather %>% 
  group_by(station) %>% 
  summarize(lat = mean(lat), lon = mean(lon))

# i'm sure there is a better way to do this???

climate_japan_map <- left_join(climate_japan, lat_lon, by = "station") 

glimpse(climate_japan_map)

climate_japan_map %>% 
  ggplot(aes(lon, lat)) +
  geom_point(aes(color = winter_avg_temp), size = 2.5) +
  geom_text_repel(aes(label = City),
                  family = "xkcd", size = 3,
                  max.iter = 50000) +
  geom_polygon(data = JPN, aes(x = long, y = lat, group = group), 
               fill = NA, color = "black") +
  coord_map() +
  labs(title = "Avg. Winter Temperature in Japan",
       subtitle = "Data from RIEM 2016-2017",
       x = "", y = "") +
  theme_xkcd() +
  theme(text = element_text(family = "xkcd", size = 14))

# filter out below 30 lat
# >>> make separate for Okinawa + Ryukyu Islands for create space

glimpse(JPN)

# Blues set colors:
colorRampPalette(brewer.pal(n = 9, name = "Blues"))(9)
# Red set colors:



# Winter avg. temp: ####

climate_japan_map %>% 
  filter(lat > 30) %>% 
  ggplot(aes(lon, lat)) +
  geom_point(aes(color = winter_avg_temp), size = 3.5) +
  geom_text_repel(aes(label = City),
                  family = "xkcd", size = 4.5,
                  max.iter = 50000) +
  geom_polygon(data = JPN %>% filter(lat > 30), aes(x = long, y = lat, group = group), 
               fill = NA, color = "black") +
  coord_map() +
  labs(title = "Avg. Winter Temperature in Japan",
       subtitle = "Data from RIEM 2016-2017",
       x = "", y = "") +
  theme_xkcd() +
  theme(text = element_text(family = "xkcd", size = 14)) +
  scale_color_gradient(low = "#08306B")

# Humidex: ####

climate_japan_map %>% 
  filter(lat > 30) %>% 
  ggplot(aes(lon, lat)) +
  geom_point(aes(color = summer_humidex), size = 3.5) +
  geom_text_repel(aes(label = City),
                  family = "xkcd", size = 4.5,
                  max.iter = 50000) +
  geom_polygon(data = JPN_1, aes(x = long, y = lat, group = group), 
               fill = NA, color = "black") +
  coord_map() +
  labs(title = "Avg. Winter Temperature in Japan",
       subtitle = "Data from RIEM 2016-2017",
       x = "", y = "") +
  theme_xkcd() +
  theme(text = element_text(family = "xkcd", size = 14)) +
  scale_color_gradient(low = "#08306B")



# Okinawa and Ryukyu Islands
Okinawa_Ryukyu <- JPN %>% filter(lat < 30)

climate_japan_map %>% 
  filter(lat < 30) %>% 
  ggplot(aes(lon, lat)) +
  geom_point(aes(color = winter_avg_temp), size = 3.5) +
  geom_text_repel(aes(label = City),
                  family = "xkcd", size = 4.5,
                  max.iter = 50000) +
  geom_polygon(data = JPN %>% filter(lat < 30), aes(x = long, y = lat, group = group), 
               fill = NA, color = "black") +
  coord_map() +
  labs(title = "Avg. Winter Temperature in Japan",
       subtitle = "Data from RIEM 2016-2017",
       x = "", y = "") +
  theme_xkcd() +
  theme(text = element_text(family = "xkcd", size = 14)) +
  scale_color_gradient(low = "#08306B")


# Leaflet ####

# Tourist areas:

tour <- data_frame(
  location = c("Hokkaido", "Tohoku", "Tokyo", "Osaka", 
               "Kobe", "Shikoku", "Hiroshima", "Kyushu", "Okinawa"),
  City = c("Sapporo", "Aomori", "Tokyo", "Osaka", "Kobe", 
           "Kochi", "Hiroshima", "Matsuyama", "Naha")
)

tour <- left_join(tour, climate_japan_map, by = "City")

# Not have Kanazawa, Kyoto, and Nara >>> just have to manually add in i guess?
# won't let me do all 3 at once...

Kanazawa <- ggmap::geocode("Kanazawa", output = "latlon")
Kyoto <- ggmap::geocode("Kyoto", output = "latlon")
Nara <- ggmap::geocode("Nara", output = "latlon")

missing_tour <- rbind(Kanazawa, Kyoto, Nara)

missing_tour <- missing_tour %>% mutate(City = c("Kanazawa", "Kyoto", "Nara"))

missing_tour

tour <- full_join(missing_tour, tour)

# not have to run geocode each time:
write.csv(tour, "~/R_materials/japan_weather_xkcd/tour.csv")

tour <- read.csv("tour.csv", stringsAsFactors = FALSE)

###################
tour %>% 
  filter(City == c("Kanazawa", "Kyoto", "Nara")) %>% 
  select(lat, lon) %>% 
  merge(missing_tour)

j <- full_join(tour, missing_tour, by = c("City", "lat", "lon")) %>% glimpse()

bind_rows(missing_tour, tour)

tour %>% 
  left_join(missing_tour[c("City", "lat", "lon")], by = c("lat", "lon", "City")) %>% 
  glimpse()
########################

# Try with leaflet instead?

library(leaflet)

leaflet(climate_japan_map) %>% 
  addTiles() %>% 
  setView(lng = 137.7, lat = 36.5, zoom = 6) %>% 
  addCircles(lng = ~lon, lat = ~lat, radius = 5000, color = "#09f") %>% 
  addMarkers(lng = ~lon, lat = ~lat, 
             popup = paste("Winter Avg.(Celsius):",
               round(climate_japan_map$winter_avg_temp, 2), 
               " | ",
               "Summer Humidex:",
               round(climate_japan_map$summer_humidex, 2)),
             label = ~City
             ) %>% 
  addMarkers(lng = ~tour$lon, lat = ~tour$lat)



 















