install.packages("packrat")

packrat::init()

#install.packages(c("leaflet", "sf", "lwgeom", "ggplot2","ggpubr", "dplyr"))
library(leaflet)
library(sf)
library(lwgeom)
library(ggplot2)
library(ggpubr)
library(dplyr)

# read files
cps_schools <- read.csv("results/complete_merged.csv")
cpd_parks <- st_read("data/cpd_parks.geojson")
cpd_parks <- st_make_valid(cpd_parks)

cps_schools_sf <- st_as_sf(cps_schools, coords = c("longitude", "latitude"), crs = 4326)
cps_schools$popup_info <- paste("School Name: ", cps_schools$school_name,
                                "<br>Walking Distance to Nearest Park (miles): ", cps_schools$distance_to_nearest_park_miles,
                                "<br>Nearest Park: ", cps_schools$nearest_park,
                                "<br>Time to Walk to Nearest Park (minutes): ", cps_schools$duration,
                                "<br>ELA Proficiency: ", cps_schools$ela_proficiency,
                                "<br>SAT Average Reading Score: ", cps_schools$SAT_average_reading_score,
                                "<br>SAT Average Math Score: ", cps_schools$SAT_average_math_score,
                                "<br>ISA Proficiency: ", cps_schools$isa_proficiency)

# Create a leaflet map with Chicago as the base map
parks_and_schools <- leaflet(options = leafletOptions(title = "Schools and Parks Map")) %>%
  addProviderTiles(providers$CartoDB.Positron) %>%  # You can choose other providers as well
  # add schools
  addCircleMarkers(data = cps_schools, lng = ~longitude, lat = ~latitude,
                   color = "#0000CD", fillOpacity = 0.1, radius = 2,
                   popup = ~popup_info) %>%
  # add parks
  addPolygons(data = cpd_parks, color = "green", fillOpacity = 0.2,
              popup = ~park) %>%
  # add legend
  addLegend("topright", colors = c("#0000CD", "green"),
            labels = c("School", "Park"), title = "Labels")
parks_and_schools


# ============================================
# Coefficient Correlation
test_names <- list("ela_proficiency" = "Ela Proficiency",
                   "SAT_average_reading_score" = "Average SAT Reading Score",
                   "SAT_average_math_score" = "Average SAT Math Score",
                   "isa_proficiency" = "Isa Proficiency")

# Calculate correlation and generate scatter plot for each test
tests <- names(test_names)
for (test in tests) {
  # Remove rows with NA values for the current test
  data <- cps_schools[!is.na(cps_schools[[test]]), ]
  cor_val <- cor(data$distance_to_nearest_park_miles, data[[test]], use = "complete.obs")
  cat(paste("Correlation between distance to nearest park and", test_names[[test]], ":", round(cor_val, 2)), "\n")
  model <- lm(data[[test]] ~ data$distance_to_nearest_park_miles)
  
  # Generate scatter plot
  plot <- ggscatter(data, x = "distance_to_nearest_park_miles", y = test,
                    add = "reg.line", conf.int = TRUE,
                    title = paste("Distance to Nearest Park vs", test_names[[test]]),
                    xlab = "Distance to Nearest Park (miles)", ylab = test_names[[test]],
                    repel = TRUE) +
    stat_cor(method = "pearson", label.x = 1.7, label.y =40) +
    geom_smooth(method = "lm", se = FALSE, color = "blue", formula = y ~ x) +
    coord_cartesian(xlim = c(0, 2)) +
    theme_bw() +
    theme(panel.grid.major = element_line(colour = "grey", linetype = "dashed"),
          panel.grid.minor = element_line(colour = "grey", linetype = "dotted"))
  # Save plot to the results folder
  ggsave(filename = paste("results/", test, "_plot.png", sep = ""), plot = plot, width = 10, height = 10, dpi = 300)
}
#=========================================

# Read the shapefile
chicago_counties <- st_read("data/boundaries/geo_export_71e2b2a2-d368-4907-bab4-02c10aecfbc1.shp")
chicago_counties_df <- as.data.frame(chicago_counties)

census_data <- read.csv("data/census_data/CCA.csv")

# Merge the datasets
joined_data_df <- merge(chicago_counties_df, census_data, by.x = "area_num_1", by.y = "GEOID")
joined_data <- st_as_sf(joined_data_df)

# Calculate the percentage for each racial group
joined_data$PERCENT_BLACK <- joined_data$BLACK / joined_data$TOT_POP * 100
joined_data$PERCENT_WHITE <- joined_data$WHITE / joined_data$TOT_POP * 100
joined_data$PERCENT_HISP <- joined_data$HISP / joined_data$TOT_POP * 100

crs_schools <- st_crs(cps_schools_sf)
crs_counties <- st_crs(chicago_counties)

# If they are not the same, transform the CRS of cps_schools_sf to match chicago_counties
if (crs_schools != crs_counties) {
  cps_schools_sf <- st_transform(cps_schools_sf, crs_counties)
}

schools_in_counties <- st_within(cps_schools_sf, chicago_counties)
avg_distances <- numeric(nrow(chicago_counties))

# Calculate the average distance to a park for the schools in each county
for (i in seq_len(nrow(chicago_counties))) {
  schools_in_this_county <- cps_schools[schools_in_counties[[i]], ]
  if (nrow(schools_in_this_county) > 0) {
    avg_distances[i] <- mean(schools_in_this_county$distance_to_nearest_park_miles, na.rm = TRUE)
  } else {
    avg_distances[i] <- NA
  }
}

joined_data$avg_distance_to_park <- avg_distances

# color palette for each group
colorpal_black <- colorNumeric(palette = "PuBuGn", domain = joined_data$PERCENT_BLACK)
colorpal_white <- colorNumeric(palette = "PuBuGn", domain = joined_data$PERCENT_WHITE)
colorpal_hisp <- colorNumeric(palette = "PuBuGn", domain = joined_data$PERCENT_HISP)


pal <- colorNumeric(palette = "PuBuGn", domain = joined_data$PERCENT_BLACK)
perc_black <- joined_data$PERCENT_BLACK
map_black <- parks_and_schools %>%
  addPolygons(data = joined_data, weight=1, color = "black",fillColor = ~colorpal_black(joined_data$PERCENT_BLACK), fillOpacity = 0.5
              ,popup = ~paste0("County: ", GEOG, "<br>",
                               "Percent Black: ", PERCENT_BLACK, "%", "<br>",
                               "Average Distance to Park: ", avg_distance_to_park, " miles")) %>%
  addLegend(position = "bottomright",
            pal = pal,
            values = perc_black,
            title = "Percentage Black",
            opacity = 1)

map_black


pal <- colorNumeric(palette = "PuBuGn", domain = joined_data$PERCENT_HISP)
perc_hisp <- joined_data$PERCENT_HISP
map_hisp <- parks_and_schools %>%
  addPolygons(data = joined_data, weight=1, color = "black",fillColor = ~colorpal_hisp(PERCENT_HISP), fillOpacity = 0.5
              ,popup = ~paste0("County: ", GEOG, "<br>",
                               "Percent Hispanic: ", PERCENT_BLACK, "%", "<br>",
                               "Average Distance to Park: ", avg_distance_to_park, " miles"))%>%
  addLegend(position = "bottomright",
            pal = pal,
            values = perc_hisp,
            title = "Percentage Hispanic",
            opacity = 1)
map_hisp


pal <- colorNumeric(palette = "PuBuGn", domain = joined_data$PERCENT_WHITE)
perc_white <- joined_data$PERCENT_WHITE
map_white <- parks_and_schools %>%
  addPolygons(data = joined_data, weight=1, color = "black",fillColor = ~colorpal_white(PERCENT_WHITE), fillOpacity = 0.5
              ,popup = ~paste0("County: ", GEOG, "<br>",
                               "Percent White: ", PERCENT_BLACK, "%", "<br>",
                               "Average Distance to Park: ", avg_distance_to_park, " miles")) %>%
  addLegend(position = "bottomright",
            pal = pal,
            values = perc_white,
            title = "Percentage White",
            opacity = 1)
map_white

#===========================
# What role race plays in park access

# For Black population
model_black <- lm(joined_data$avg_distance_to_park ~ joined_data$PERCENT_BLACK)
summary(model_black)

# For White population
model_white <- lm(joined_data$avg_distance_to_park ~ joined_data$PERCENT_WHITE)
summary(model_white)

# For Hispanic population
model_hisp <- lm(joined_data$avg_distance_to_park ~ joined_data$PERCENT_HISP)
summary(model_hisp)

# For Black population
cor_black <- cor(joined_data$PERCENT_BLACK, joined_data$avg_distance_to_park)
plot_black <- ggplot(joined_data, aes(x = PERCENT_BLACK, y = avg_distance_to_park)) +
  geom_point() +
  geom_smooth(method = "lm", se = FALSE, color = "red") +
  labs(x = "Percentage of Black Population", y = "Average Distance to Park") +
  annotate("text", x = Inf, y = Inf, label = paste("Correlation: ", round(cor_black, 2)), vjust = 2, hjust = 2)
plot_black
ggsave("results/black_pop_access_to_park.png", plot_black)

cor_white <- cor(joined_data$PERCENT_WHITE, joined_data$avg_distance_to_park)
plot_white <- ggplot(joined_data, aes(x = PERCENT_WHITE, y = avg_distance_to_park)) +
  geom_point() +
  geom_smooth(method = "lm", se = FALSE, color = "blue") +
  labs(x = "Percentage of White Population", y = "Average Distance to Park") +
  annotate("text", x = Inf, y = Inf, label = paste("Correlation: ", round(cor_white, 2)), vjust = 2, hjust = 1)
plot_white
ggsave("results/white_pop_access_to_park.png", plot_white)


# For Hispanic population
cor_hisp <- cor(joined_data$PERCENT_HISP, joined_data$avg_distance_to_park)
plot_hisp <-ggplot(joined_data, aes(x = PERCENT_HISP, y = avg_distance_to_park)) +
  geom_point() +
  geom_smooth(method = "lm", se = FALSE, color = "green") +
  labs(x = "Percentage of Hispanic Population", y = "Average Distance to Park") +
  annotate("text", x = Inf, y = Inf, label = paste("Correlation: ", round(cor_hisp, 2)), vjust = 2, hjust = 2)
plot_hisp
ggsave("results/hisp_pop_access_to_park.png", plot_hisp)
