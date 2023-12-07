library(dplyr)

df1 <- read.csv("data/cps_schools.csv", stringsAsFactors = FALSE)
df2 <- read.csv("results/min_distance_to_park.csv", stringsAsFactors = FALSE)

names(df1)[names(df1) == "School_Name"] <- "school_name"
merged_df <- merge(df2, df1, by = "school_name")
write.csv(merged_df, "results/complete_merged.csv", row.names = FALSE)

