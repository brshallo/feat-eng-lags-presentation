## ----load-in-packages------------------------------------------------------------------------
library(tidyverse)
library(lubridate)
library(httr)
library(jsonlite)

## ----load-data-inspections-------------------------------------------------------------------
r_insp <- GET("https://opendata.arcgis.com/datasets/ebe3ae7f76954fad81411612d7c4fb17_1.geojson")

inspections <- content(r_insp, "text") %>% 
  fromJSON() %>% 
  .$features %>%
  .$properties %>% 
  as_tibble()

inspections_clean <- inspections %>% 
  mutate(date = ymd_hms(DATE_) %>% as.Date()) %>% 
  select(-c(DATE_, DESCRIPTION, OBJECTID))


## ----load-data-restaurants-------------------------------------------------------------------
r_rest <- GET("https://opendata.arcgis.com/datasets/124c2187da8c41c59bde04fa67eb2872_0.geojson") #json

restauraunts <- content(r_rest, "text") %>% 
  fromJSON() %>% 
  .$features %>%
  .$properties %>% 
  as_tibble() %>% 
  select(-OBJECTID)

restauraunts <- restauraunts %>% 
  mutate(RESTAURANTOPENDATE = ymd_hms(RESTAURANTOPENDATE) %>% as.Date()) %>% 
  select(-PERMITID)


## ----join-data-restaurants-inspections-------------------------------------------------------
inspections_restaurants <- inspections_clean %>% 
  left_join(restauraunts, by = c("HSISID")) %>% 
  filter(SCORE > 50, FACILITYTYPE == "Restaurant") %>% 
  distinct(HSISID, date, .keep_all = TRUE) %>% 
  select(-c(FACILITYTYPE, PERMITID)) %>% 
  select(-c(NAME, contains("ADDRESS"), CITY, STATE, POSTALCODE, PHONENUMBER, X, Y, GEOCODESTATUS)) %>% 
  filter(date <= ymd(20201012))


## --------------------------------------------------------------------------------------------
inspections_restaurants %>% 
  write_csv(here::here("data", "inspections-restaurants.csv"))
