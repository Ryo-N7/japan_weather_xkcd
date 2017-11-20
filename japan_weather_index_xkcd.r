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





read.csv("~/R_materials/")













